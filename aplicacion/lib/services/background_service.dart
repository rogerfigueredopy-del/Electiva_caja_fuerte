import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  static const _storage = FlutterSecureStorage();
  static const _backgroundKey = 'custom_background_path';
  
  String? _currentBackgroundPath;
  ImageProvider? _currentBackground;

  /// Obtiene el fondo actual o null si no hay uno personalizado
  ImageProvider? get currentBackground => _currentBackground;

  /// Inicializa el servicio cargando el fondo guardado
  Future<void> init() async {
    final savedPath = await _storage.read(key: _backgroundKey);
    if (savedPath != null && savedPath.isNotEmpty) {
      final file = File(savedPath);
      if (await file.exists()) {
        _currentBackgroundPath = savedPath;
        _currentBackground = FileImage(file);
      } else {
        // El archivo ya no existe, limpiar la configuración
        await clearBackground();
      }
    }
  }

  /// Permite al usuario seleccionar una nueva imagen de fondo
  Future<bool> selectBackground() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return false;
      }

      final file = result.files.first;
      if (file.path == null) {
        return false;
      }

      return await setBackground(File(file.path!));
    } catch (e) {
      print('Error seleccionando fondo: $e');
      return false;
    }
  }

  /// Establece una imagen específica como fondo
  Future<bool> setBackground(File imageFile) async {
    try {
      if (!await imageFile.exists()) {
        return false;
      }

      // Crear directorio para fondos personalizados
      final appDir = await getApplicationSupportDirectory();
      final backgroundsDir = Directory('${appDir.path}/backgrounds');
      if (!await backgroundsDir.exists()) {
        await backgroundsDir.create(recursive: true);
      }

      // Copiar la imagen al directorio de la aplicación
      final fileName = 'custom_background_${DateTime.now().millisecondsSinceEpoch}.${_getFileExtension(imageFile.path)}';
      final newPath = '${backgroundsDir.path}/$fileName';
      final newFile = await imageFile.copy(newPath);

      // Eliminar el fondo anterior si existe
      if (_currentBackgroundPath != null) {
        try {
          await File(_currentBackgroundPath!).delete();
        } catch (_) {}
      }

      // Guardar la nueva ruta
      await _storage.write(key: _backgroundKey, value: newPath);
      _currentBackgroundPath = newPath;
      _currentBackground = FileImage(newFile);

      return true;
    } catch (e) {
      print('Error estableciendo fondo: $e');
      return false;
    }
  }

  /// Elimina el fondo personalizado y vuelve al predeterminado
  Future<void> clearBackground() async {
    try {
      if (_currentBackgroundPath != null) {
        final file = File(_currentBackgroundPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}

    await _storage.delete(key: _backgroundKey);
    _currentBackgroundPath = null;
    _currentBackground = null;
  }

  /// Obtiene la extensión del archivo
  String _getFileExtension(String path) {
    final parts = path.split('.');
    return parts.isNotEmpty ? parts.last.toLowerCase() : 'jpg';
  }

  /// Verifica si hay un fondo personalizado configurado
  bool get hasCustomBackground => _currentBackground != null;

  /// Crea un widget de fondo que se puede usar en las pantallas
  Widget createBackgroundWidget({
    required Widget child,
    Color? overlayColor,
    double overlayOpacity = 0.3,
  }) {
    if (_currentBackground == null) {
      // Fondo predeterminado con gradiente
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3C72),
              Color(0xFF2A5298),
              Color(0xFF3F51B5),
            ],
          ),
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: _currentBackground!,
          fit: BoxFit.cover,
        ),
      ),
      child: overlayColor != null
          ? Container(
              color: overlayColor.withOpacity(overlayOpacity),
              child: child,
            )
          : child,
    );
  }
}