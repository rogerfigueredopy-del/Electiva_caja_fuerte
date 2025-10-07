import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/vault_file.dart';
import 'crypto_service.dart';

class VaultRepository {
  VaultRepository._();
  static final VaultRepository instance = VaultRepository._();

  final _uuid = const Uuid();

  Future<Directory> _ensureVaultDir() async {
    final dir = await getApplicationSupportDirectory();
    final vault = Directory('${dir.path}/vault');
    if (!await vault.exists()) {
      await vault.create(recursive: true);
    }
    return vault;
  }

  Future<File> _metaFile(Directory vault, String id) async =>
      File('${vault.path}/$id.json');
  Future<File> _dataFile(Directory vault, String id) async =>
      File('${vault.path}/$id.enc');

  Future<List<VaultFileMeta>> listAll() async {
    try {
      final vault = await _ensureVaultDir();
      final files = vault
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();

      final out = <VaultFileMeta>[];
      for (final metaFile in files) {
        try {
          final txt = await metaFile.readAsString();
          final j = jsonDecode(txt) as Map<String, dynamic>;
          out.add(VaultFileMeta.fromJson(j));
        } catch (e) {
          // Log corrupted metadata files but continue processing
          print('Advertencia: Archivo de metadatos corrupto: ${metaFile.path} - $e');
        }
      }
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    } catch (e) {
      print('Error al listar archivos del vault: $e');
      return [];
    }
  }

  Future<VaultFileMeta> importFile({
    required File source,
    required String mimeType,
    required Uint8List kek,
    bool moveFile = true, // Por defecto mueve el archivo
  }) async {
    // Validaciones de entrada
    if (!await source.exists()) {
      throw ArgumentError('El archivo fuente no existe: ${source.path}');
    }
    
    if (kek.length != 32) {
      throw ArgumentError('KEK debe tener exactamente 32 bytes');
    }

    try {
      final vault = await _ensureVaultDir();
      final id = _uuid.v4();
      final bytes = await source.readAsBytes();

      // Validar que el archivo no esté vacío
      if (bytes.isEmpty) {
        throw ArgumentError('El archivo está vacío');
      }

      final crypto = CryptoService.instance;
      final bundle = await crypto.encryptWithWrappedKey(data: bytes, kek: kek);

      final originalName = source.uri.pathSegments.isNotEmpty 
          ? source.uri.pathSegments.last 
          : 'archivo_sin_nombre';

      final meta = VaultFileMeta(
        id: id,
        originalName: originalName,
        mimeType: mimeType,
        originalSize: bytes.length,
        createdAt: DateTime.now(),
        dekWrappedB64: CryptoService.b64(bundle['dekWrapped']!),
        dekWrapIvB64: CryptoService.b64(bundle['dekWrapIv']!),
        fileIvB64: CryptoService.b64(bundle['fileIv']!),
      );

      // Escribir archivos de forma atómica
      final dataFile = await _dataFile(vault, id);
      final metaFile = await _metaFile(vault, id);
      
      await dataFile.writeAsBytes(bundle['cipher']!, flush: true);
      await metaFile.writeAsString(jsonEncode(meta.toJson()), flush: true);

      // Mover o eliminar el archivo original según la configuración
      if (moveFile) {
        try {
          print('🔄 [VAULT] Intentando mover archivo: ${source.path}');
          print('🔍 [VAULT] Verificando propiedades del archivo...');
          
          // Verificar propiedades del archivo antes de eliminarlo
          if (await source.exists()) {
            final stat = await source.stat();
            print('📊 [VAULT] Tamaño del archivo: ${stat.size} bytes');
            print('📊 [VAULT] Tipo: ${stat.type}');
            print('📊 [VAULT] Modificado: ${stat.modified}');
            
            // Verificar permisos intentando leer el archivo
            try {
              await source.readAsBytes();
              print('✅ [VAULT] Archivo legible, procediendo con eliminación...');
            } catch (readError) {
              print('❌ [VAULT] Error al leer archivo: $readError');
              throw Exception('No se puede acceder al archivo para eliminarlo: $readError');
            }
            
            // Intentar eliminar el archivo original
            print('🗑️ [VAULT] Eliminando archivo original...');
            await source.delete();
            print('✅ [VAULT] Comando de eliminación ejecutado');
            
            // Verificar que realmente se eliminó con múltiples intentos
            bool stillExists = false;
            for (int attempt = 1; attempt <= 3; attempt++) {
              await Future.delayed(Duration(milliseconds: 50 * attempt));
              stillExists = await source.exists();
              print('🔍 [VAULT] Verificación $attempt/3: archivo ${stillExists ? "AÚN EXISTE" : "ELIMINADO"}');
              if (!stillExists) break;
            }
            
            if (stillExists) {
              // Intentar métodos alternativos de eliminación
              print('⚠️ [VAULT] Método estándar falló, intentando métodos alternativos...');
              
              try {
                // Método 1: Intentar renombrar el archivo primero
                final tempPath = '${source.path}.temp_delete_${DateTime.now().millisecondsSinceEpoch}';
                final tempFile = await source.rename(tempPath);
                print('🔄 [VAULT] Archivo renombrado a: $tempPath');
                
                await tempFile.delete();
                print('✅ [VAULT] Archivo eliminado después de renombrar');
                
                // Verificar eliminación final
                if (await tempFile.exists()) {
                  throw Exception('Archivo temporal aún existe después de eliminación');
                }
              } catch (renameError) {
                print('❌ [VAULT] Error con método de renombrado: $renameError');
                
                try {
                  // Método 2: Intentar sobrescribir el archivo con contenido vacío
                  print('🔄 [VAULT] Intentando sobrescribir archivo...');
                  await source.writeAsBytes([]);
                  await source.delete();
                  print('✅ [VAULT] Archivo sobrescrito y eliminado');
                  
                  if (await source.exists()) {
                    throw Exception('Archivo aún existe después de sobrescribir');
                  }
                } catch (overwriteError) {
                  print('❌ [VAULT] Error con método de sobrescritura: $overwriteError');
                  throw Exception('No se pudo eliminar el archivo original con ningún método disponible');
                }
              }
            }
            
            print('✅ [VAULT] Archivo original eliminado exitosamente: ${source.path}');
          } else {
            print('⚠️ [VAULT] El archivo original ya no existe: ${source.path}');
          }
        } catch (e) {
          print('❌ [VAULT] Error al eliminar el archivo original: $e');
          print('📍 [VAULT] Ruta del archivo: ${source.path}');
          print('📍 [VAULT] Tipo de error: ${e.runtimeType}');
          
          // En caso de error, intentar limpiar los archivos creados
          try {
            if (await dataFile.exists()) {
              await dataFile.delete();
              print('🧹 [VAULT] Archivo de datos limpiado');
            }
            if (await metaFile.exists()) {
              await metaFile.delete();
              print('🧹 [VAULT] Archivo de metadatos limpiado');
            }
          } catch (cleanupError) {
            print('❌ [VAULT] Error durante limpieza: $cleanupError');
          }
          
          // Re-lanzar el error original para que el import falle
          throw Exception('No se pudo mover el archivo: $e');
        }
      } else {
        print('📋 [VAULT] Archivo copiado (no movido): ${source.path}');
      }

      return meta;
    } catch (e) {
      print('Error al importar archivo: $e');
      rethrow;
    }
  }

  Future<Uint8List> exportClear({
    required String id,
    required Uint8List kek,
  }) async {
    // Validaciones de entrada
    if (id.isEmpty) {
      throw ArgumentError('ID no puede estar vacío');
    }
    
    if (kek.length != 32) {
      throw ArgumentError('KEK debe tener exactamente 32 bytes');
    }

    try {
      final vault = await _ensureVaultDir();
      final metaFile = await _metaFile(vault, id);
      
      if (!await metaFile.exists()) {
        throw FileSystemException('Archivo de metadatos no encontrado', metaFile.path);
      }
      
      final dataFile = await _dataFile(vault, id);
      if (!await dataFile.exists()) {
        throw FileSystemException('Archivo de datos no encontrado', dataFile.path);
      }

      final metaContent = await metaFile.readAsString();
      final meta = VaultFileMeta.fromJson(
          jsonDecode(metaContent) as Map<String, dynamic>);

      final cipher = await dataFile.readAsBytes();
      
      if (cipher.isEmpty) {
        throw StateError('El archivo de datos está vacío');
      }

      final clear = await CryptoService.instance.decryptWithWrappedKey(
        cipherWithTag: cipher,
        fileIv: CryptoService.b64d(meta.fileIvB64),
        dekWrappedWithTag: CryptoService.b64d(meta.dekWrappedB64),
        dekWrapIv: CryptoService.b64d(meta.dekWrapIvB64),
        kek: kek,
      );
      
      return clear;
    } catch (e) {
      print('Error al exportar archivo: $e');
      rethrow;
    }
  }

  Future<void> deleteById(String id) async {
    if (id.isEmpty) {
      throw ArgumentError('ID no puede estar vacío');
    }

    try {
      final vault = await _ensureVaultDir();
      final metaFile = await _metaFile(vault, id);
      final dataFile = await _dataFile(vault, id);
      
      bool metaExists = await metaFile.exists();
      bool dataExists = await dataFile.exists();
      
      if (!metaExists && !dataExists) {
        print('Advertencia: No se encontraron archivos para el ID: $id');
        return;
      }
      
      // Eliminar archivos de forma segura
      if (metaExists) {
        await metaFile.delete();
      }
      
      if (dataExists) {
        await dataFile.delete();
      }
      
      print('Archivo eliminado exitosamente: $id');
    } catch (e) {
      print('Error al eliminar archivo: $e');
      rethrow;
    }
  }

  Future<void> wipeAll() async {
    final vault = await _ensureVaultDir();
    if (await vault.exists()) {
      await for (final e in vault.list(recursive: false)) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
  }
}
