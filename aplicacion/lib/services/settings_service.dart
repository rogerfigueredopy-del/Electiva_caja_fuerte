import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _screenProtectionKey = 'screen_protection_enabled';
  static const String _biometricAuthKey = 'biometric_auth_enabled';
  static const String _autoLockTimeKey = 'auto_lock_time';
  
  static SettingsService? _instance;
  static SettingsService get instance => _instance ??= SettingsService._();
  
  SettingsService._();
  
  SharedPreferences? _prefs;
  
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }
  
  // Protección de pantalla (screenshot y grabación)
  bool get isScreenProtectionEnabled {
    final value = _prefs?.getBool(_screenProtectionKey) ?? true; // Por defecto activado
    print('🔧 SettingsService.isScreenProtectionEnabled: $value');
    return value;
  }
  
  Future<void> setScreenProtectionEnabled(bool enabled) async {
    print('🔧 SettingsService.setScreenProtectionEnabled: $enabled');
    await _prefs?.setBool(_screenProtectionKey, enabled);
    print('🔧 SettingsService.setScreenProtectionEnabled guardado: $enabled');
  }
  
  // Autenticación biométrica
  bool get isBiometricAuthEnabled {
    final value = _prefs?.getBool(_biometricAuthKey) ?? true; // Por defecto activado
    print('🔧 SettingsService.isBiometricAuthEnabled: $value');
    return value;
  }
  
  Future<void> setBiometricAuthEnabled(bool enabled) async {
    print('🔧 SettingsService.setBiometricAuthEnabled: $enabled');
    await _prefs?.setBool(_biometricAuthKey, enabled);
    print('🔧 SettingsService.setBiometricAuthEnabled guardado: $enabled');
  }
  
  // Tiempo de auto-bloqueo (en minutos)
  int get autoLockTime {
    return _prefs?.getInt(_autoLockTimeKey) ?? 5; // Por defecto 5 minutos
  }
  
  Future<void> setAutoLockTime(int minutes) async {
    await _prefs?.setInt(_autoLockTimeKey, minutes);
  }
  
  // Método para resetear todas las configuraciones
  Future<void> resetSettings() async {
    await _prefs?.remove(_screenProtectionKey);
    await _prefs?.remove(_biometricAuthKey);
    await _prefs?.remove(_autoLockTimeKey);
  }
}