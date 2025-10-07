import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/vault_file.dart';
import '../services/lock_manager.dart';
import '../services/vault_repository.dart';
import '../services/background_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<VaultFileMeta> _items = [];
  bool _busy = false;
  String? _error;
  final _fmt = DateFormat('yyyy-MM-dd HH:mm');
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  Future<void> _load() async {
    if (_busy) return; // Evitar múltiples cargas simultáneas
    
    print('🔄 [LOAD] Iniciando carga de archivos...');
    
    setState(() { 
      _busy = true; 
      _error = null; 
    });
    
    try {
      final all = await VaultRepository.instance.listAll();
      print('🔄 [LOAD] Archivos obtenidos del repositorio: ${all.length}');
      
      if (mounted) {
        setState(() { 
          _items = all;
          _items.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Ordenar por fecha
        });
        print('🔄 [LOAD] ✅ Vista actualizada con ${_items.length} archivos');
      } else {
        print('🔄 [LOAD] ⚠️ Widget no montado, no se actualiza la vista');
      }
    } catch (e) {
      print('🔄 [LOAD] ❌ Error cargando archivos: $e');
      if (mounted) {
        setState(() { 
          _error = 'Error cargando archivos: ${e.toString()}'; 
        });
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; });
      }
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    
    print('🔍 [IMPORT] Iniciando importación...');
    print('🔍 [IMPORT] Estado inicial - isUnlocked: ${LockManager.instance.isUnlocked}');
    
    if (!LockManager.instance.isUnlocked) {
      print('🔍 [IMPORT] No está desbloqueado, solicitando autenticación...');
      final ok = await LockManager.instance.unlock();
      print('🔍 [IMPORT] Resultado de autenticación: $ok');
      if (!ok) return;
    }
    
    print('🔍 [IMPORT] Estado después de autenticación - isUnlocked: ${LockManager.instance.isUnlocked}');
    
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true, 
      withData: false,
      dialogTitle: 'Seleccionar archivos para importar',
    );
    if (result == null || result.files.isEmpty) return;

    setState(() { _busy = true; _error = null; });
    
    int importedCount = 0;
    int totalFiles = result.files.length;
    
    try {
      print('🔍 [IMPORT] Verificando KEK...');
      print('🔍 [IMPORT] isUnlocked antes de obtener KEK: ${LockManager.instance.isUnlocked}');
      
      // Verificar que tenemos la clave de cifrado
      final kek = LockManager.instance.kek;
      print('🔍 [IMPORT] KEK obtenida: ${kek != null ? "✅ Sí" : "❌ No"}');
      
      if (kek == null) {
        print('🔍 [IMPORT] KEK es null, intentando reautenticar...');
        final reauth = await LockManager.instance.unlock();
        print('🔍 [IMPORT] Resultado de reautenticación: $reauth');
        
        if (reauth) {
          final kekRetry = LockManager.instance.kek;
          print('🔍 [IMPORT] KEK después de reautenticación: ${kekRetry != null ? "✅ Sí" : "❌ No"}');
          if (kekRetry == null) {
            throw Exception('No se pudo obtener la clave de cifrado después de reautenticación. Intenta reiniciar la aplicación.');
          }
        } else {
          throw Exception('No se pudo obtener la clave de cifrado. Intenta autenticarte nuevamente.');
        }
      }
      
      // Obtener la KEK final después de todas las verificaciones
      final finalKek = LockManager.instance.kek;
      if (finalKek == null) {
        throw Exception('No se pudo obtener la clave de cifrado después de todos los intentos. Intenta reiniciar la aplicación.');
      }
      
      print('🔍 [IMPORT] ✅ KEK final obtenida, iniciando importación de ${result.files.length} archivos...');
      
      for (final f in result.files) {
        final path = f.path;
        if (path == null) continue;
        
        final file = File(path);
        if (!await file.exists()) continue;
        
        // Determinar MIME type básico basado en la extensión
        String mimeType = _getMimeType(path);
        
        await VaultRepository.instance.importFile(
          source: file,
          mimeType: mimeType,
          kek: finalKek,
          moveFile: true, // Mover archivo en lugar de copiarlo
        );
        importedCount++;
      }
      }
      
      print('📥 [IMPORT] ✅ Importación completada, recargando lista...');
      await _load();
      
      if (mounted) {
        final message = importedCount == totalFiles 
            ? 'Se importaron $importedCount archivos exitosamente'
            : 'Se importaron $importedCount de $totalFiles archivos';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Error importando archivos: ${e.toString()}'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; });
      }
    }
  }

  String _getMimeType(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _export(VaultFileMeta meta) async {
    if (_busy) return;
    
    if (!LockManager.instance.isUnlocked) {
      final ok = await LockManager.instance.unlock();
      if (!ok) return;
    }
    
    setState(() { _busy = true; _error = null; });
    
    try {
      final bytes = await VaultRepository.instance.exportClear(
        id: meta.id, 
        kek: LockManager.instance.kek!,
      );
      
      if (bytes.isEmpty) {
        throw StateError('El archivo está vacío');
      }
      
      // Share/save dialog
      final xFile = XFile.fromData(
        bytes, 
        name: meta.originalName, 
        mimeType: meta.mimeType,
      );
      
      await Share.shareXFiles(
        [xFile], 
        text: 'Archivo exportado desde Caja Segura',
        subject: 'Archivo: ${meta.originalName}',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo "${meta.originalName}" exportado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Error exportando "${meta.originalName}": ${e.toString()}'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; });
      }
    }
  }

  Future<void> _delete(VaultFileMeta meta) async {
    if (_busy) return;
    
    print('🗑️ [DELETE] Iniciando eliminación de archivo: ${meta.originalName}');
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que deseas eliminar definitivamente este archivo?'),
            const SizedBox(height: 8),
            Text(
              '"${meta.originalName}"',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), 
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    
    if (ok != true) {
      print('🗑️ [DELETE] ❌ Usuario canceló la eliminación');
      return;
    }
    
    print('🗑️ [DELETE] ✅ Usuario confirmó eliminación, procediendo...');
    setState(() { _busy = true; _error = null; });
    
    try {
      print('🗑️ [DELETE] Eliminando archivo del repositorio...');
      await VaultRepository.instance.deleteById(meta.id);
      print('🗑️ [DELETE] ✅ Archivo eliminado del repositorio, recargando lista...');
      await _load();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo "${meta.originalName}" eliminado'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Error eliminando "${meta.originalName}": ${e.toString()}'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      LockManager.instance.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caja Segura'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: () => _showBackgroundSelector(context),
            icon: const Icon(Icons.wallpaper),
            tooltip: 'Cambiar fondo',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _import,
        icon: const Icon(Icons.add),
        label: const Text('Importar'),
      ),
      body: BackgroundService.instance.createBackgroundWidget(
        overlayColor: Colors.white,
        overlayOpacity: 0.8,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ),
                if (_busy) Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: const LinearProgressIndicator(),
                ),
                Expanded(
                  child: RefreshIndicator(
                    key: _refreshKey,
                    onRefresh: _load,
                    child: _items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(24.0),
                                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.folder_open, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'No hay archivos',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Usa "Importar" para agregar archivos seguros',
                                        style: TextStyle(color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'Desliza hacia abajo para actualizar',
                                        style: TextStyle(color: Colors.grey, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final m = _items[i];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.insert_drive_file_outlined, color: Colors.indigo),
                                  title: Text(m.originalName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${m.mimeType} • ${_fmt.format(m.createdAt)} • ${(m.originalSize / 1024).toStringAsFixed(1)} KB'),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'export') _export(m);
                                      if (v == 'delete') _delete(m);
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'export', child: Text('Exportar (descifrado)')),
                                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBackgroundSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seleccionar Fondo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Seleccionar imagen'),
              onTap: () async {
                Navigator.pop(context);
                await BackgroundService.instance.selectBackground();
                setState(() {}); // Refresh to show new background
              },
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('Usar fondo por defecto'),
              onTap: () async {
                Navigator.pop(context);
                await BackgroundService.instance.clearBackground();
                setState(() {}); // Refresh to show default background
              },
            ),
          ],
        ),
      ),
    );
  }
}
