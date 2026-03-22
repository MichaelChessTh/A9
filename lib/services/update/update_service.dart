import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UpdateService with ChangeNotifier {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  bool _isUpdateAvailable = false;
  bool get isUpdateAvailable => _isUpdateAvailable;

  String _currentVersion = "";
  String get currentVersion => _currentVersion;

  String _latestVersion = "";
  String get latestVersion => _latestVersion;

  String _reviewText = "Checking for updates...";
  String get reviewText => _reviewText;

  double _downloadProgress = 0;
  double get downloadProgress => _downloadProgress;

  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  bool _isDownloaded = false;
  bool get isDownloaded => _isDownloaded;

  String? _localApkPath;

  Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    await checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    try {
      final storage = FirebaseStorage.instance;

      // 1. Get latest version from updates/version.txt
      try {
        final versionRef = storage.ref('updates/version.txt');
        final versionData = await versionRef.getData();
        if (versionData != null) {
          _latestVersion = utf8.decode(versionData).trim();
        }
      } catch (e) {
        debugPrint("Version file not found: $e");
        _latestVersion = _currentVersion; // Default to current if not found
      }

      // 2. Get review text from updates/review.txt
      try {
        final reviewRef = storage.ref('updates/review.txt');
        final reviewData = await reviewRef.getData();
        if (reviewData != null) {
          _reviewText = utf8.decode(reviewData);
        }
      } catch (e) {
        debugPrint("Review file not found: $e");
        _reviewText = "No description available.";
      }

      // 3. Compare versions
      if (_latestVersion.isNotEmpty && _latestVersion != _currentVersion) {
        _isUpdateAvailable = true;
        _showLocalUpdateNotification();
      } else {
        _isUpdateAvailable = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  Future<void> _showLocalUpdateNotification() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'app_updates',
        'App Updates',
        description: 'Notifications for new app versions',
        importance: Importance.high,
      );
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    const androidDetails = AndroidNotificationDetails(
      'app_updates',
      'App Updates',
      channelDescription: 'Notifications for new app versions',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    flutterLocalNotificationsPlugin.show(
      999,
      'New version available!',
      'Version $latestVersion is ready to download.',
      notificationDetails,
    );
  }

  Future<void> downloadUpdate() async {
    if (_isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0;
    notifyListeners();

    try {
      final storage = FirebaseStorage.instance;
      final apkRef = storage.ref('updates/app-release.apk');
      final downloadUrl = await apkRef.getDownloadURL();

      final downloadsDir =
          await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final apkDir = Directory('${downloadsDir.path}/updates');
      if (!await apkDir.exists()) {
        await apkDir.create(recursive: true);
      }
      _localApkPath = "${apkDir.path}/A9_v$latestVersion.apk";

      final dio = Dio();
      await dio.download(
        downloadUrl,
        _localApkPath,
        onReceiveProgress: (count, total) {
          if (total > 0) {
            _downloadProgress = (count / total).clamp(0.0, 1.0);
          } else {
            // If total is -1, we just notify that something is happening (e.g. 0.01)
            _downloadProgress = 0.01;
          }
          notifyListeners();
        },
      );

      _isDownloading = false;
      _isDownloaded = true;
      notifyListeners();
    } catch (e) {
      _isDownloading = false;
      debugPrint("Download failed: $e");
      notifyListeners();
    }
  }

  Future<void> installUpdate() async {
    if (_localApkPath == null) return;
    final file = File(_localApkPath!);
    if (await file.exists()) {
      await OpenFilex.open(_localApkPath!);
    } else {
      debugPrint("APK file not found at $_localApkPath");
      _isDownloaded = false;
      notifyListeners();
    }
  }
}
