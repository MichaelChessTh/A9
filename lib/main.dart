import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:googlechat/firebase_options.dart';
import 'package:googlechat/services/auth/auth_gate.dart';
import 'package:googlechat/services/cache/local_cache.dart';
import 'package:googlechat/services/notifications/notification_service.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:googlechat/services/call/call_log_service.dart';
import 'package:googlechat/services/language/language_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:googlechat/services/update/update_service.dart';
import 'package:googlechat/services/share/share_service.dart';
import 'package:googlechat/services/navigation/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googlechat/pages/welcome_page.dart';

// ZegoCloud project credentials from Zego Console
const int zegoAppId = 1499295270;
const String zegoAppSign =
    'ad2c9d82a2390c376a9e88e2ba9dd83a71f116d848b586d91b4e2104fef40527';

// ─── Используемые цвета экрана звонка ────────────────────────────────────────
const _kPrimary = Color(0xFF4285F4); // Google Blue
const _kGreen = Color(0xFF34A853); // принять звонок

// Note: navigatorKey moved to NavigationService

// ─────────────────────────────────────────────────────────────────────────────
// КАСТОМНАЯ КОНФИГУРАЦИЯ ЭКРАНА ЗВОНКА
// ─────────────────────────────────────────────────────────────────────────────
ZegoUIKitPrebuiltCallConfig _buildCallConfig({required bool isVideoCall}) {
  final cfg =
      isVideoCall
          ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

  // ── Кастомный фон ──────────────────────────────────────────────────────────
  cfg.background = const _CallBackground();

  // ── Аватар пользователя (когда видео выключено / голосовой звонок) ─────────
  cfg.avatarBuilder = (
    BuildContext context,
    Size size,
    ZegoUIKitUser? user,
    Map<String, dynamic> extraInfo,
  ) {
    return _CallAvatar(name: user?.name ?? '?', size: size);
  };

  // ── Топбар — скрываем для 1:1 чтобы было чище ─────────────────────────────
  cfg.topMenuBar = ZegoCallTopMenuBarConfig(isVisible: false, buttons: []);

  // ── Нижняя панель кнопок ───────────────────────────────────────────────────
  cfg.bottomMenuBar = ZegoCallBottomMenuBarConfig(
    style: ZegoCallMenuBarStyle.dark,
    backgroundColor: Colors.transparent,
    height: 140,
    padding: const EdgeInsets.only(bottom: 24),
    buttons:
        isVideoCall
            ? [
              ZegoCallMenuBarButtonName.toggleCameraButton,
              ZegoCallMenuBarButtonName.hangUpButton,
              ZegoCallMenuBarButtonName.toggleMicrophoneButton,
            ]
            : [
              ZegoCallMenuBarButtonName.toggleMicrophoneButton,
              ZegoCallMenuBarButtonName.hangUpButton,
              ZegoCallMenuBarButtonName.switchAudioOutputButton,
            ],
  );

  // ── Диалог подтверждения завершения ────────────────────────────────────────
  cfg.hangUpConfirmDialog = ZegoCallHangUpConfirmDialogConfig(
    info: ZegoCallHangUpConfirmDialogInfo(
      title: 'Завершить звонок',
      message: 'Вы уверены, что хотите завершить звонок?',
    ),
  );

  return cfg;
}

// ─── Виджет фона экрана звонка ────────────────────────────────────────────────
class _CallBackground extends StatelessWidget {
  const _CallBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0E1A), Color(0xFF101840), Color(0xFF0A1628)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Декоративные световые блобы
          Positioned(
            top: -80,
            left: -60,
            child: _GlowBlob(
              color: _kPrimary.withValues(alpha: 0.18),
              size: 300,
            ),
          ),
          Positioned(
            bottom: 100,
            right: -80,
            child: _GlowBlob(
              color: _kPrimary.withValues(alpha: 0.12),
              size: 250,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: MediaQuery.of(context).size.width * 0.3,
            child: _GlowBlob(color: _kGreen.withValues(alpha: 0.07), size: 200),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

// ─── Кастомный аватар на экране звонка ────────────────────────────────────────
class _CallAvatar extends StatelessWidget {
  final String name;
  final Size size;
  const _CallAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final List<Color> palette = [
      const Color(0xFF4285F4),
      const Color(0xFF44BEC7),
      const Color(0xFFFFC300),
      const Color(0xFFFA3C4C),
      const Color(0xFF7B68EE),
      const Color(0xFF20B2AA),
    ];
    final idx =
        name.isEmpty
            ? 0
            : name.codeUnits.fold(0, (a, b) => a + b) % palette.length;
    final color = palette[idx];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final avatarSize = size.width * 0.7;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Пульсирующее кольцо
          Container(
            width: avatarSize + 24,
            height: avatarSize + 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Container(
                width: avatarSize + 8,
                height: avatarSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.2),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: avatarSize * 0.38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

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

  // ───── ZegoCloud: обязательная пре-инициализация ДО runApp() ─────
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(
    NavigationService.navigatorKey,
  );

  await ZegoUIKit().initLog().then((_) async {
    await ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI([
      ZegoUIKitSignalingPlugin(),
    ]);
  });
  // ─────────────────────────────────────────────────────────────────

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

        final doc =
            await FirebaseFirestore.instance
                .collection('Users')
                .doc(user.uid)
                .get();
        final username =
            doc.data()?['username'] ?? user.email!.split('@').first;

        await ZegoUIKitPrebuiltCallInvitationService().init(
          appID: zegoAppId,
          appSign: zegoAppSign,
          userID: user.uid,
          userName: username,
          plugins: [ZegoUIKitSignalingPlugin()],

          // ─── Кастомный UI активного звонка ──────────────────────────────
          requireConfig: (ZegoCallInvitationData data) {
            final isVideo = data.type == ZegoCallInvitationType.videoCall;
            return _buildCallConfig(isVideoCall: isVideo);
          },

          // ─── Кастомный UI вызова (ожидание ответа) ─────────────────────────
          uiConfig: ZegoCallInvitationUIConfig(
            inviter: ZegoCallInvitationInviterUIConfig(
              backgroundBuilder:
                  (context, size, info) => const _CallBackground(),
            ),
            invitee: ZegoCallInvitationInviteeUIConfig(
              backgroundBuilder:
                  (context, size, info) => const _CallBackground(),
              // всплывающее окно входящего звонка, когда мы внутри приложения
              popUp: ZegoCallInvitationNotifyPopUpUIConfig(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Настройки offline-уведомлений (фоновые звонки) ─────────────
          notificationConfig: ZegoCallInvitationNotificationConfig(
            androidNotificationConfig: ZegoCallAndroidNotificationConfig(
              // Показывать полноэкранное уведомление поверх локскрина
              callIDVisibility: true,
              // Канал уведомлений — должен совпадать с Zego Console > Push Notification
              callChannel: ZegoCallAndroidNotificationChannelConfig(
                channelID: 'ZegoUIKit',
                channelName: 'Call Notifications',
                sound: 'zego_incoming',
                icon: 'ic_launcher',
                vibrate: true,
              ),
            ),
          ),

          invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
            onIncomingCallReceived: (
              callID,
              caller,
              callType,
              callees,
              customData,
            ) {
              CallLogService().saveCallLog(
                callID: callID,
                callerId: caller.id,
                callerName: caller.name,
                calleeId: user.uid,
                calleeName: username,
                status: 'Incoming',
              );
            },
            onOutgoingCallAccepted: (callID, callee) {
              CallLogService().saveCallLog(
                callID: callID,
                callerId: user.uid,
                callerName: username,
                calleeId: callee.id,
                calleeName: callee.name,
                status: 'Accepted',
              );
            },
            onOutgoingCallDeclined: (callID, callee, customData) {
              CallLogService().saveCallLog(
                callID: callID,
                callerId: user.uid,
                callerName: username,
                calleeId: callee.id,
                calleeName: callee.name,
                status: 'Declined',
              );
            },
            onIncomingCallTimeout: (callID, caller) {
              CallLogService().saveCallLog(
                callID: callID,
                callerId: caller.id,
                callerName: caller.name,
                calleeId: user.uid,
                calleeName: username,
                status: 'Missed',
              );
            },
          ),
        );
      } else {
        await ZegoUIKitPrebuiltCallInvitationService().uninit();
      }
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
