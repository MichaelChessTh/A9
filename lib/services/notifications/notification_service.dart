import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googlechat/services/navigation/navigation_service.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:googlechat/services/chat/encryption_service.dart';
import 'package:googlechat/pages/chat_page.dart';
import 'package:googlechat/pages/group_chat_page.dart';

// ─── Background handler — top-level function required by FCM ─────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM SDK + OS renders the notification automatically for background/terminated.
  debugPrint('FCM background message: ${message.messageId}');
}

// ─── Android notification channel ────────────────────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'a9_messages',
  'Messages',
  description: 'New messages from A9',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Central notification service:
///  • Requests permissions
///  • Creates the Android channel
///  • Saves FCM token in Firestore
///  • Shows rich local notification while app is in foreground
///  • Background / terminated: handled by FCM SDK + OS automatically
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  bool _initialised = false;
  
  StreamSubscription<QuerySnapshot>? _localFirestoreSub;
  final Map<String, Timestamp> _notifiedTimestamps = {};

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // ВНИМАНИЕ: мы удалили FirebaseMessaging.onBackgroundMessage,
    // так как он перезаписывал фоновый обработчик ZegoCloud, из-за чего звонки не приходили в убитое приложение!
    // Обычные текстовые уведомления Firebase все равно будут показываться системой.

    // ② Request permissions (iOS / Android 13+)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // ③ iOS foreground presentation
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // ④ Create Android high-priority channel
    if (Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    }

    // ⑤ Init flutter_local_notifications (v17 positional-param API)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const macOSInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
        macOS: macOSInit,
      ),
      onDidReceiveNotificationResponse: _onTap,
    );

    // ⑥ Save FCM token
    await _saveFcmToken();
    _fcm.onTokenRefresh.listen(_persistToken);

    // ⑦ Foreground messages → local notification
    FirebaseMessaging.onMessage.listen(_showLocal);

    // ⑧ Notification tapped while app in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    // ⑨ App launched from terminated via notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleOpen(initial);
  }

  // ─── Token ───────────────────────────────────────────────────
  Future<void> _saveFcmToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await _fcm.getToken();
      if (token != null) await _persistToken(token);
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  Future<void> _persistToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .update({
          'fcmToken': token,
          'fcmUpdatedAt': FieldValue.serverTimestamp(),
        })
        .catchError((e) => debugPrint('Token persist error: $e'));
  }

  // ─── Foreground notification ──────────────────────────────────
  void _showLocal(RemoteMessage message) {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return; // Do not show UI notification when app is active/open
    }

    final notif = message.notification;
    if (notif == null) return;
    final data = message.data;

    // Decrypt body if it's encrypted
    final body = EncryptionService.decrypt(notif.body ?? '');

    final context = NavigationService.navigatorKey.currentContext;
    final l10n = context != null ? AppLocalizations.of(context) : null;
    final defaultTitle = l10n?.newMessage ?? 'New message';

    _local.show(
      notif.hashCode,
      notif.title ?? defaultTitle,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF0084FF),
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: notif.title,
            summaryText: data['senderName'] as String?,
          ),
          groupKey: data['chatRoomId'] as String?,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  void _handleOpen(RemoteMessage message) {
    debugPrint('Notification opened: ${message.data}');
    _navigateToChatFromData(message.data);
  }

  void _onTap(NotificationResponse r) {
    debugPrint('Local notification tapped: ${r.payload}');
    if (r.payload == null || r.payload!.isEmpty) return;
    try {
      final data = jsonDecode(r.payload!) as Map<String, dynamic>;
      _navigateToChatFromData(data);
    } catch (e) {
      debugPrint('Payload parse error: $e');
    }
  }

  void _navigateToChatFromData(Map<String, dynamic> data) {
    _processNavigationWithRetry(data, 0);
  }

  void _processNavigationWithRetry(Map<String, dynamic> data, int attempts) {
    if (attempts > 10) return; // Give up after 5 seconds

    final nav = NavigationService.navigatorKey.currentState;
    if (nav == null) {
      Future.delayed(
          const Duration(milliseconds: 500), 
          () => _processNavigationWithRetry(data, attempts + 1));
      return;
    }

    final groupId = data['groupId'] as String?;
    final groupName = data['groupName'] as String?;
    final senderID = data['senderID'] as String?;
    final senderEmail = data['senderEmail'] as String?;

    if (groupId != null && groupId.isNotEmpty) {
      nav.push(
        MaterialPageRoute(
          builder:
              (_) => GroupChatPage(
                groupId: groupId,
                initialGroupName: groupName ?? groupId,
              ),
        ),
      );
    } else if (senderID != null && senderID.isNotEmpty) {
      nav.push(
        MaterialPageRoute(
          builder:
              (_) => ChatPage(
                receiverID: senderID,
                receiverEmail: senderEmail ?? senderID,
              ),
        ),
      );
    }
  }

  // ─── Lifecycle ────────────────────────────────────────────────
  Future<void> onUserSignedIn() async {
    await _saveFcmToken();
    if (Platform.isMacOS) {
      _startLocalFirestoreListener();
    }
  }

  void _startLocalFirestoreListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _localFirestoreSub?.cancel();
    _notifiedTimestamps.clear();
    final initTime = Timestamp.now();
    
    _localFirestoreSub = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snapshot) async {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) return;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified || change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;
          
          final roomId = change.doc.id;
          final lastMsgTime = data['lastMessageTimestamp'] as Timestamp?;
          
          if (lastMsgTime == null) continue;
          if (lastMsgTime.compareTo(initTime) <= 0) continue;
          
          final lastNotified = _notifiedTimestamps[roomId];
          if (lastNotified != null && lastMsgTime.compareTo(lastNotified) <= 0) continue;
          
          final senderID = data['lastMessageSenderID'];
          if (senderID == uid) continue;
          
          _notifiedTimestamps[roomId] = lastMsgTime;
          
          final text = data['lastMessage'] as String?;
          final decryptedText = EncryptionService.decrypt(text ?? '');
          
          String title = data['groupName'] ?? 'New Message';
          if (data['isGroup'] != true && senderID != null) {
            try {
              final userDoc = await FirebaseFirestore.instance.collection('Users').doc(senderID).get();
              if (userDoc.exists) title = userDoc.data()?['name'] ?? title;
            } catch (_) {}
          }
          
          final payloadData = {
            'chatRoomId': roomId,
            'senderID': senderID,
            'groupName': data['groupName'],
            'groupId': data['isGroup'] == true ? roomId : null,
          };

          _local.show(
            roomId.hashCode,
            title,
            decryptedText,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id, _channel.name,
                channelDescription: _channel.description,
                importance: Importance.high,
              ),
              iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
              macOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
            ),
            payload: jsonEncode(payloadData),
          );
        }
      }
    });
  }

  Future<void> onUserSignedOut() async {
    _localFirestoreSub?.cancel();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .update({'fcmToken': FieldValue.delete()})
        .catchError((_) {});
    await _fcm.deleteToken();
  }
}
