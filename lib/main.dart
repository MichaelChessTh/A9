import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:googlechat/firebase_options.dart';
import 'package:googlechat/services/auth/auth_gate.dart';
import 'package:googlechat/services/cache/local_cache.dart';
import 'package:googlechat/services/notifications/notification_service.dart';
// Notification dismiss on group chat open is handled by the lifecycle observer in main.dart
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:googlechat/services/language/language_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:googlechat/services/update/update_service.dart';
import 'package:googlechat/services/share/share_service.dart';
import 'package:googlechat/services/navigation/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googlechat/pages/welcome_page.dart';

// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  // Enable Firestore offline persistence with a generous cache size (100 MB)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 104857600, // 100 MB
  );

  // Init Hive-based local cache
  await LocalCache.init();

  // Check if first launch
  final prefs = await SharedPreferences.getInstance();
  final bool hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => LanguageProvider()),
        ChangeNotifierProvider(create: (context) => UpdateService()),
      ],
      child: MyApp(hasSeenWelcome: hasSeenWelcome),
    ),
  );
}

class MyApp extends StatefulWidget {
  final bool hasSeenWelcome;

  const MyApp({super.key, required this.hasSeenWelcome});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    NotificationService.instance.init();
    UpdateService().init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ShareService().init();
    });

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        UserService.initPresence();
        NotificationService.instance.onUserSignedIn();
      }
      // No call service to init/uninit (Zego removed)
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        UserService.updatePresence(true);
        // Dismiss any stale notifications from the notification tray
        NotificationService.instance.clearAllNotifications();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        UserService.updatePresence(false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      title: 'A9',
      theme: Provider.of<ThemeProvider>(context).themeData,
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('de'),
        Locale('ru'),
        Locale('es'),
      ],
      home: widget.hasSeenWelcome ? const AuthGate() : const WelcomePage(),
      builder: (context, child) => child!,
    );
  }
}
