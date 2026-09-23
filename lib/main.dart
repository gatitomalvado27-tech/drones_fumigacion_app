import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/agro_theme.dart';
import 'theme/theme_controller.dart';
import 'screens/home_screen.dart';
import 'screens/pin_login_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Habilitar soporte offline para trabajar en el campo sin internet
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await initializeDateFormatting('es', null);
  await initializeDateFormatting('es_CO', null);

  // Inicializar servicio de notificaciones locales para el piloto
  await NotificationService.instance.inicializar();

  // Cargar preferencia de tema (Oscuro o Blanco)
  await ThemeController.instance.inicializar();

  // Verificar si el dispositivo ya fue autorizado con el PIN
  final prefs = await SharedPreferences.getInstance();
  final bool estaAutorizado = prefs.getBool('proicaro_dispositivo_autorizado') ?? false;

  runApp(MyApp(estaAutorizado: estaAutorizado));
}

class MyApp extends StatelessWidget {
  final bool estaAutorizado;
  const MyApp({super.key, required this.estaAutorizado});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Icaro Proagro',
          debugShowCheckedModeBanner: false,
          theme: AgroTheme.lightTheme,
          darkTheme: AgroTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          locale: const Locale('es', 'CO'),
          supportedLocales: const [
            Locale('es', 'CO'),
            Locale('es', ''),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: estaAutorizado ? const HomeScreen() : const PinLoginScreen(),
        );
      },
    );
  }
}