import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:watertracker/l10n/app_localizations.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/screens/login_screen.dart';
import 'package:watertracker/screens/main_screen.dart';
import 'package:watertracker/services/auth_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:watertracker/providers/user_provider.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:watertracker/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:watertracker/services/local_storage_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialize Local Storage (Critical)
  try {
    await LocalStorageService.init();
    print('Hive initialized');
  } catch (e) {
    print('CRITICAL: Hive initialization failed: $e');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized');
  } catch (e) {
    print('Firebase initialization error: $e');
  }

  // Initialize Date Formatting
  try {
    await initializeDateFormatting('id_ID', null);
    print('Date formatting initialized');
  } catch (e) {
    print('Date formatting initialization error: $e');
  }

  // Initialize Notifications
  try {
    await NotificationService().init();
    print('Notification service initialized');
  } catch (e) {
    print('Notification service initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
  print('App started');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'SipSip!',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF65C9F6)),
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF65C9F6),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          themeMode: themeProvider.themeMode,
          locale: themeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('id', ''), // Indonesian
            Locale('en', ''), // English
          ],
          home: const InitialScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// Simple initial screen that checks auth and navigates
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // No artificial delay needed, native splash covers init
    if (!mounted) return;

    final isLoggedIn = await AuthService().isLoggedIn();
    
    if (mounted) {
      if (isLoggedIn) {
        // Reschedule reminders on startup to ensure alarms are active
        NotificationService().rescheduleAllReminders();
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
      FlutterNativeSplash.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash logo with blue background for seamless transition (fallback)
    return Scaffold(
      backgroundColor: const Color(0xFF3BAFDA),
      body: Center(
        child: SvgPicture.asset(
          'assets/images/ic_splashscreen.svg',
          width: 200,
        ),
      ),
    );
  }
}

