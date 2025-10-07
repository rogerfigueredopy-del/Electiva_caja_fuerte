import 'dart:typed_data';
import 'auth_service.dart';

/// LockManager manages the master KEK (Key Encryption Key).
/// Ahora usa AuthService para una autenticación biométrica más robusta.
class LockManager {
  LockManager._();
  static final LockManager instance = LockManager._();

  bool get isUnlocked => AuthService.instance.isUnlocked;

  Future<void> init() async {
    await AuthService.instance.init();
  }

  Future<bool> unlock() async {
    try {
      return await AuthService.instance.authenticate(
        reason: 'Autentica para acceder a tus archivos seguros'
      );
    } catch (e) {
      // Re-lanzar la excepción para que la UI pueda manejarla
      rethrow;
    }
  }

  void lock() {
    AuthService.instance.lock();
  }

  Uint8List? get kek => AuthService.instance.kek;

  bool get isSessionExpired => AuthService.instance.isSessionExpired;

  void extendSession() => AuthService.instance.extendSession();

  Duration get sessionTimeout => AuthService.instance.sessionTimeout;

  set sessionTimeout(Duration timeout) => AuthService.instance.sessionTimeout = timeout;
}
