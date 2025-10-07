import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/lock_manager.dart';
import '../services/background_service.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with TickerProviderStateMixin {
  bool _busy = false;
  String? _error;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    
    setState(() { _busy = true; _error = null; });
    
    // Vibración ligera para feedback táctil
    HapticFeedback.lightImpact();
    
    try {
      await LockManager.instance.init();
      final ok = await LockManager.instance.unlock();
      
      if (ok && mounted) {
        // Vibración de éxito
        HapticFeedback.mediumImpact();
        
        // Animación de éxito antes de navegar
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Vibración de error
        HapticFeedback.heavyImpact();
        
        // Animación de shake para error
        _shakeController.forward().then((_) => _shakeController.reset());
        
        if (mounted) {
          setState(() { 
            _error = 'Autenticación cancelada.\nIntenta nuevamente.'; 
          });
        }
      }
    } catch (e) {
      // Vibración de error
      HapticFeedback.heavyImpact();
      
      // Animación de shake para error
      _shakeController.forward().then((_) => _shakeController.reset());
      
      if (mounted) {
        String errorMessage = 'Error de autenticación';
        
        // Personalizar mensaje según el tipo de error
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('no disponible')) {
          errorMessage = 'Autenticación biométrica no disponible.\nConfigura huella dactilar o Face ID.';
        } else if (errorStr.contains('no hay biometría')) {
          errorMessage = 'No hay biometría configurada.\nConfigura huella dactilar o Face ID.';
        } else if (errorStr.contains('bloqueada')) {
          errorMessage = 'Autenticación bloqueada.\nIntenta más tarde o usa tu PIN.';
        } else if (errorStr.contains('no se encontró')) {
          errorMessage = 'Error de configuración.\nReinstala la aplicación.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }
        
        setState(() { 
          _error = errorMessage; 
        });
      }
    } finally {
      if (mounted) {
        setState(() { _busy = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundService.instance.createBackgroundWidget(
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseAnimation.value,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _busy ? Icons.lock_clock : Icons.lock_outline,
                                        size: 80,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Caja Segura', 
                                style: TextStyle(
                                  fontSize: 28, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Protege tus archivos importantes',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _busy ? null : _unlock,
                                  icon: _busy 
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.fingerprint, size: 24),
                                  label: Text(
                                    _busy ? 'Autenticando...' : 'Desbloquear con biometría',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 3,
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Usa tu huella dactilar, Face ID o PIN para acceder',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
