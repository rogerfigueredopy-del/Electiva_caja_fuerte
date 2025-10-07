import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_windowmanager/flutter_windowmanager.dart'; // Comentado temporalmente

import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'services/lock_manager.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configurar orientación de pantalla
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Configurar barra de estado
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Inicializar servicios
  try {
    await SettingsService.instance.init();
    await LockManager.instance.init();
  } catch (e) {
    debugPrint('Error inicializando servicios: $e');
    // Continuar con la aplicación aunque falle la inicialización
  }
  
  // Configurar protección de pantalla según configuración del usuario
  try {
    final settingsService = SettingsService.instance;
    if (settingsService.isScreenProtectionEnabled) {
      //await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
    }
  } catch (e) {
    debugPrint('Error configurando seguridad de pantalla: $e');
  }
  
  runApp(const CajaSeguraApp());
}

class CajaSeguraApp extends StatefulWidget {
  const CajaSeguraApp({super.key});

  @override
  State<CajaSeguraApp> createState() => _CajaSeguraAppState();
}

class _CajaSeguraAppState extends State<CajaSeguraApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caja Segura',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      initialRoute: '/lock',
      routes: {
        '/lock': (_) => const LockScreen(),
        '/home': (_) => const HomeScreen(),
      },
      builder: (context, child) {
        // Configurar el texto para que no se escale automáticamente
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor: 1.0,
          ),
          child: child!,
        );
      },
    );
  }
}
