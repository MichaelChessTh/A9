import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googlechat/services/cache/local_cache.dart';
import 'package:path_provider/path_provider.dart';
import 'package:googlechat/models/message.dart';

class MediaService {
  static final Dio _dio = Dio();

  /// Checks if a file is already downloaded
  static String? getLocalPath(String messageId) {
    return LocalCache.getMediaPath(messageId);
  }

  /// Immediately registers the temp path in LocalCache so the sender's
  /// ChatBubble can display media right away, before the permanent copy is made.
  static Future<void> preRegisterSenderPath({
    required String messageId,
    required String tempPath,
  }) async {
    if (kIsWeb) return;
    final file = File(tempPath);
    if (file.existsSync()) {
      await LocalCache.saveMediaPath(messageId, tempPath);
    }
  }

  /// Save sender's local media file permanently to avoid issues when temp/cache gets cleared.
  static Future<String?> saveSenderMedia({
    required String messageId,
    required String fileName,
    required String tempPath,
    required MessageType type,
  }) async {
    if (kIsWeb) return null;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${appDir.path}/GoogleChatMedia');
      if (!mediaDir.existsSync()) {
        mediaDir.createSync(recursive: true);
      }
      final savePath = '${mediaDir.path}/${messageId}_$fileName';

      final tempFile = File(tempPath);
      if (tempFile.existsSync()) {
        await tempFile.copy(savePath);
        await LocalCache.saveMediaPath(messageId, savePath);
        return savePath;
      }
    } catch (e) {
      debugPrint('Error saving sender media: $e');
    }
    return null;
  }

  static Future<String?> downloadAndSaveMedia({
    required String messageId,
    required String url,
    required String fileName,
    required MessageType type,
    required String chatId, // To potentially nullify URL
    bool isReceiver = false,
  }) async {
    // Check cache
    final existingPath = LocalCache.getMediaPath(messageId);
    if (existingPath != null && File(existingPath).existsSync()) {
      return existingPath;
    }

    if (kIsWeb) {
      return null; // Can't easily do local file management & gallery on Web
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();

      final mediaDir = Directory('${appDir.path}/GoogleChatMedia');
      if (!mediaDir.existsSync()) {
        mediaDir.createSync(recursive: true);
      }

      final savePath = '${mediaDir.path}/${messageId}_$fileName';

      if (!File(savePath).existsSync()) {
        // Download
        await _dio.download(url, savePath);

        // Save to Gallery if it's an image or video
        if (type == MessageType.image) {
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) await Gal.requestAccess();
          await Gal.putImage(savePath);
        } else if (type == MessageType.video) {
          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) await Gal.requestAccess();
          await Gal.putVideo(savePath);
        }

        // Save local path to Hive
        await LocalCache.saveMediaPath(messageId, savePath);

        // Delete from Firebase Storage after successful gallery save
        if (isReceiver && chatId.isNotEmpty) {
          try {
            final isGroupChat = !chatId.contains('_');

            if (isGroupChat) {
              final uid = FirebaseAuth.instance.currentUser!.uid;
              final msgRef = FirebaseFirestore.instance
                  .collection('group_rooms')
                  .doc(chatId)
                  .collection('messages')
                  .doc(messageId);

              // Register this user as downloaded
              await msgRef.update({
                'downloadedBy': FieldValue.arrayUnion([uid]),
              });

              // Check if all other members have downloaded
              final msgSnap = await msgRef.get();
              final groupSnap =
                  await FirebaseFirestore.instance
                      .collection('group_rooms')
                      .doc(chatId)
                      .get();

              if (msgSnap.exists && groupSnap.exists) {
                final downloadedBy = List<String>.from(
                  msgSnap.data()!['downloadedBy'] ?? [],
                );
                final members = List<String>.from(
                  groupSnap.data()!['memberUIDs'] ?? [],
                );
                final senderId = msgSnap.data()!['senderID'];

                bool allDownloaded = true;
                for (final member in members) {
                  if (member != senderId && !downloadedBy.contains(member)) {
                    allDownloaded = false;
                    break;
                  }
                }

                if (allDownloaded) {
                  final storageRef = FirebaseStorage.instance.refFromURL(url);
                  await storageRef.delete();
                  debugPrint('Deleted $fileName from Firebase Storage (Group)');
                }
              }
            } else {
              // Priority 1-on-1 chat
              final storageRef = FirebaseStorage.instance.refFromURL(url);
              await storageRef.delete();
              debugPrint('Deleted $fileName from Firebase Storage (1-on-1)');
            }
          } catch (e) {
            debugPrint('Error deleting from storage: $e');
          }
        }

        // Update Firestore to clear the fileUrl if we don't need it?
        // Actually, let's keep it nullified locally or globally?
        // If we nullify globally, other group chat members won't get it.
        // For 1:1, we could nullify. Let's not nullify in DB unless requested, because other devices of same user.
        // Wait, user said "после того, как конечный пользователь получил файлы, они должны загрузиться к нему на телефон и удалиться из firebase"
        // Let's delete the file from Storage but NOT clear fileUrl from Firestore. It will just 404 later.
        // Or we can leave a flag in db.
      }

      return savePath;
    } catch (e) {
      debugPrint('Media download error: $e');
      return null;
    }
  }
}
