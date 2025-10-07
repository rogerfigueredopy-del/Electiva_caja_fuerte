import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'crypto_service.dart';

/// AuthService maneja la autenticación biométrica y el almacenamiento seguro
/// de la clave maestra (KEK) usando local_auth y flutter_secure_storage.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kekKey = 'caja_segura_kek_v2';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final LocalAuthentication _localAuth = LocalAuthentication();
  Uint8List? _kek;
  DateTime? _lastUnlock;
  Duration sessionTimeout = const Duration(minutes: 5);

  bool get isUnlocked {
    if (_kek == null) return false;
    if (_lastUnlock == null) return false;
    return DateTime.now().difference(_lastUnlock!) < sessionTimeout;
  }

  /// Inicializa el servicio de autenticación
  Future<void> init() async {
    try {
      // Verificar si ya existe una KEK almacenada
      final existingKek = await _storage.read(key: _kekKey);
      if (existingKek == null || existingKek.isEmpty) {
        print('Generando nueva KEK...');
        // Generar nueva KEK y almacenarla
        final kek = await CryptoService.instance.randomBytes(32);
        final kekString = base64Encode(kek);
        await _storage.write(key: _kekKey, value: kekString);
        
        // Verificar que se guardó correctamente
        final verification = await _storage.read(key: _kekKey);
        if (verification == null || verification.isEmpty) {
          throw Exception('No se pudo almacenar la clave de cifrado');
        }
        print('KEK generada y almacenada exitosamente');
      } else {
        print('KEK existente encontrada');
      }
    } catch (e) {
      print('Error inicializando AuthService: $e');
      throw Exception('Error inicializando AuthService: $e');
    }
  }

  /// Verifica si la autenticación biométrica está disponible
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.isDeviceSupported();
      if (!isAvailable) return false;

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) return false;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene los tipos de biometría disponibles
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Autentica al usuario y desbloquea la KEK
  Future<bool> authenticate({String? reason}) async {
    try {
      print('🔐 [AuthService] Iniciando autenticación...');
      
      // Verificar si la biometría está disponible
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('🔐 [AuthService] ❌ Dispositivo no soporta autenticación biométrica');
        throw Exception('Autenticación biométrica no disponible en este dispositivo');
      }

      // Realizar autenticación biométrica
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason ?? 'Autentica para acceder a tus archivos seguros',
        options: const AuthenticationOptions(
          biometricOnly: false, // Permite PIN/patrón como fallback
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (!authenticated) {
        print('🔐 [AuthService] ❌ Autenticación fallida');
        return false;
      }

      print('🔐 [AuthService] ✅ Autenticación exitosa');
      
      // Recuperar y decodificar la KEK
      final kekString = await _storage.read(key: _kekKey);
      print('🔐 [AuthService] KEK recuperada del storage: ${kekString != null ? "✅ Sí" : "❌ No"}');
      
      if (kekString == null || kekString.isEmpty) {
        // Intentar regenerar la KEK si no existe
        print('🔐 [AuthService] KEK no encontrada, regenerando...');
        await init(); // Regenerar KEK
        final newKekString = await _storage.read(key: _kekKey);
        print('🔐 [AuthService] Nueva KEK generada: ${newKekString != null ? "✅ Sí" : "❌ No"}');
        if (newKekString == null || newKekString.isEmpty) {
          throw Exception('No se pudo generar la clave de cifrado');
        }
        _kek = base64Decode(newKekString);
      } else {
        _kek = base64Decode(kekString);
      }

      _lastUnlock = DateTime.now();
      print('🔐 [AuthService] ✅ Autenticación completada exitosamente');
      print('🔐 [AuthService] KEK status: ${_kek != null ? "✅ Disponible (${_kek!.length} bytes)" : "❌ No disponible"}');
      
      // Verificación adicional
      if (_kek == null) {
        print('🔐 [AuthService] ⚠️ KEK sigue siendo null, intentando regenerar una vez más...');
        await init();
        final finalKekString = await _storage.read(key: _kekKey);
        if (finalKekString != null) {
          _kek = base64Decode(finalKekString);
          print('🔐 [AuthService] KEK final: ${_kek != null ? "✅ Disponible" : "❌ Falló"}');
        }
      }
      
      return true;

    } on PlatformException catch (e) {
      print('🔐 [AuthService] ❌ Error de plataforma: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'NotAvailable':
          throw Exception('Autenticación biométrica no disponible');
        case 'NotEnrolled':
          throw Exception('No hay biometría configurada en el dispositivo');
        case 'LockedOut':
          throw Exception('Autenticación bloqueada temporalmente');
        case 'PermanentlyLockedOut':
          throw Exception('Autenticación bloqueada permanentemente');
        case 'UserCancel':
          return false; // Usuario canceló, no es un error
        case 'UserFallback':
          return false; // Usuario eligió método alternativo
        case 'BiometricOnlyNotSupported':
          throw Exception('Solo biometría no soportada');
        default:
          throw Exception('Error de autenticación: ${e.message}');
      }
    } catch (e) {
      print('🔐 [AuthService] ❌ Error durante autenticación: $e');
      if (e is Exception) rethrow;
      throw Exception('Error inesperado durante la autenticación: $e');
    }
  }

  /// Bloquea la aplicación limpiando la KEK de memoria
  void lock() {
    _kek?.fillRange(0, _kek!.length, 0); // Limpiar memoria
    _kek = null;
    _lastUnlock = null;
  }

  /// Obtiene la KEK actual (solo si está desbloqueada)
  Uint8List? get kek {
    print('🔑 [AuthService] Solicitando KEK...');
    print('🔑 [AuthService] - isUnlocked: $isUnlocked');
    print('🔑 [AuthService] - _kek != null: ${_kek != null}');
    print('🔑 [AuthService] - isSessionExpired: $isSessionExpired');
    
    if (!isUnlocked) {
      print('🔑 [AuthService] ❌ Sesión no válida, devolviendo null');
      return null;
    }
    
    if (_kek == null) {
      print('🔑 [AuthService] ❌ _kek es null aunque isUnlocked es true');
      return null;
    }
    
    print('🔑 [AuthService] ✅ Devolviendo KEK válida');
    return _kek;
  }

  /// Verifica si la sesión ha expirado
  bool get isSessionExpired {
    if (_lastUnlock == null) return true;
    return DateTime.now().difference(_lastUnlock!) >= sessionTimeout;
  }

  /// Extiende la sesión actual
  void extendSession() {
    if (_kek != null) {
      _lastUnlock = DateTime.now();
    }
  }

  /// Limpia todos los datos almacenados (para reset completo)
  Future<void> clearAllData() async {
    try {
      lock();
      await _storage.delete(key: _kekKey);
    } catch (e) {
      throw Exception('Error limpiando datos: $e');
    }
  }
}