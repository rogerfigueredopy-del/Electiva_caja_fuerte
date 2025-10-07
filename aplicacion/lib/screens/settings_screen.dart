import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService.instance;
  bool _screenProtectionEnabled = true;
  bool _biometricAuthEnabled = true;
  int _autoLockTime = 5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    print('🔧 Cargando configuraciones...');
    await _settingsService.init();
    
    final screenProtection = _settingsService.isScreenProtectionEnabled;
    final biometricAuth = _settingsService.isBiometricAuthEnabled;
    final autoLock = _settingsService.autoLockTime;
    
    print('🔧 Valores cargados desde SharedPreferences:');
    print('🔧 - Protección de pantalla: $screenProtection');
    print('🔧 - Autenticación biométrica: $biometricAuth');
    print('🔧 - Auto-bloqueo: $autoLock minutos');
    
    setState(() {
      _screenProtectionEnabled = screenProtection;
      _biometricAuthEnabled = biometricAuth;
      _autoLockTime = autoLock;
      _isLoading = false;
    });
    
    print('🔧 Estado después de setState:');
    print('🔧 - _screenProtectionEnabled: $_screenProtectionEnabled');
    print('🔧 - _biometricAuthEnabled: $_biometricAuthEnabled');
    print('🔧 - _autoLockTime: $_autoLockTime');
  }

  Future<void> _updateScreenProtection(bool value) async {
    print('🔧 Actualizando protección de pantalla: $value');
    print('🔧 Estado anterior: $_screenProtectionEnabled');
    
    try {
      // Primero guardar en SharedPreferences
      await _settingsService.setScreenProtectionEnabled(value);
      
      // Verificar que se guardó correctamente
      final savedValue = _settingsService.isScreenProtectionEnabled;
      print('🔧 Valor guardado en SharedPreferences: $savedValue');
      
      // Luego actualizar el estado local
      setState(() {
        _screenProtectionEnabled = value;
      });
      
      print('🔧 Estado después de setState: $_screenProtectionEnabled');
      
      // Aplicar inmediatamente la configuración
      if (value) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
      } else {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
      }
      
      _showSnackBar(value 
        ? 'Protección de pantalla activada' 
        : 'Protección de pantalla desactivada');
    } catch (e) {
      print('🔧 Error actualizando protección de pantalla: $e');
      _showSnackBar('Error al actualizar la configuración');
    }
  }

  Future<void> _updateBiometricAuth(bool value) async {
    print('🔧 Actualizando autenticación biométrica: $value');
    print('🔧 Estado anterior: $_biometricAuthEnabled');
    
    try {
      // Primero guardar en SharedPreferences
      await _settingsService.setBiometricAuthEnabled(value);
      
      // Verificar que se guardó correctamente
      final savedValue = _settingsService.isBiometricAuthEnabled;
      print('🔧 Valor guardado en SharedPreferences: $savedValue');
      
      // Luego actualizar el estado local
      setState(() {
        _biometricAuthEnabled = value;
      });
      
      print('🔧 Estado después de setState: $_biometricAuthEnabled');
      
      _showSnackBar(value 
        ? 'Autenticación biométrica activada' 
        : 'Autenticación biométrica desactivada');
    } catch (e) {
      print('🔧 Error actualizando autenticación biométrica: $e');
      _showSnackBar('Error al actualizar la configuración');
    }
  }

  Future<void> _updateAutoLockTime(int minutes) async {
    setState(() {
      _autoLockTime = minutes;
    });
    await _settingsService.setAutoLockTime(minutes);
    _showSnackBar('Tiempo de auto-bloqueo actualizado: $minutes minutos');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAutoLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tiempo de Auto-bloqueo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Selecciona el tiempo después del cual la aplicación se bloqueará automáticamente:'),
            const SizedBox(height: 16),
            ...([1, 2, 5, 10, 15, 30].map((minutes) => RadioListTile<int>(
              title: Text('$minutes ${minutes == 1 ? 'minuto' : 'minutos'}'),
              value: minutes,
              groupValue: _autoLockTime,
              onChanged: (value) {
                if (value != null) {
                  Navigator.pop(context);
                  _updateAutoLockTime(value);
                }
              },
            ))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetear Configuración'),
        content: const Text('¿Estás seguro de que quieres resetear todas las configuraciones a sus valores por defecto?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _settingsService.resetSettings();
      _loadSettings();
      _showSnackBar('Configuración reseteada');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Seguridad
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Seguridad',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Protección de pantalla
                  SwitchListTile(
                    title: const Text('Protección de Pantalla'),
                    subtitle: const Text('Bloquea capturas de pantalla y grabación'),
                    value: _screenProtectionEnabled,
                    onChanged: _updateScreenProtection,
                    secondary: const Icon(Icons.screen_lock_portrait),
                  ),
                  
                  const Divider(),
                  
                  // Autenticación biométrica
                  SwitchListTile(
                    title: const Text('Autenticación Biométrica'),
                    subtitle: const Text('Usar huella dactilar o reconocimiento facial'),
                    value: _biometricAuthEnabled,
                    onChanged: _updateBiometricAuth,
                    secondary: const Icon(Icons.fingerprint),
                  ),
                  
                  const Divider(),
                  
                  // Auto-bloqueo
                  ListTile(
                    title: const Text('Auto-bloqueo'),
                    subtitle: Text('Bloquear después de $_autoLockTime ${_autoLockTime == 1 ? 'minuto' : 'minutos'} de inactividad'),
                    leading: const Icon(Icons.timer),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: _showAutoLockDialog,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Sección de Información
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Información',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  ListTile(
                    title: const Text('Versión de la App'),
                    subtitle: const Text('1.0.0'),
                    leading: const Icon(Icons.info_outline),
                  ),
                  
                  const Divider(),
                  
                  ListTile(
                    title: const Text('Acerca de'),
                    subtitle: const Text('Caja Segura Local - Protege tus archivos'),
                    leading: const Icon(Icons.help_outline),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Caja Segura',
                        applicationVersion: '1.0.0',
                        applicationIcon: const Icon(Icons.security, size: 48),
                        children: const [
                          Text('Una aplicación segura para proteger y gestionar tus archivos importantes.'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Botón de resetear
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restore, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Acciones',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  ListTile(
                    title: const Text('Resetear Configuración'),
                    subtitle: const Text('Restaurar todas las configuraciones por defecto'),
                    leading: const Icon(Icons.restore, color: Colors.red),
                    onTap: _resetSettings,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}