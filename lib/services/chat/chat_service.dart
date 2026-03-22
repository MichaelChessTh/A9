import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googlechat/models/message.dart';
import 'package:googlechat/services/cache/local_cache.dart';
import 'package:googlechat/services/chat/encryption_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _getChatRoomID(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  // ─── File Upload ──────────
  Future<String> uploadFile({
    Uint8List? bytes,
    String? filePath,
    required String fileName,
    required MessageType type,
    bool isHD = false,
    void Function(double)? onProgress,
  }) async {
    // For small images that are not HD, we still use base64 for "instant" low-res preview in Firestore
    if (type == MessageType.image && !isHD && bytes != null) {
      if (onProgress != null) onProgress(1.0);
      final base64 = base64Encode(bytes);
      return 'data:image/webp;base64,$base64';
    }

    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'chat_files/${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );

      UploadTask uploadTask;
      if (filePath != null) {
        uploadTask = storageRef.putFile(File(filePath));
      } else if (bytes != null) {
        uploadTask = storageRef.putData(bytes);
      } else {
        throw Exception('No data or file path provided for upload');
      }

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress =
              snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  // ─── All users stream (for legacy use) ───────────────────────
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // ─── Active chats for current user ───────────────────────────
  /// Returns all chat_room documents where currentUser is a participant,
  /// ordered by lastMessageTimestamp descending (client-side sort).
  Stream<QuerySnapshot> getActiveChatsStream(String userID) {
    return _firestore
        .collection('chat_rooms')
        .where('participants', arrayContains: userID)
        .snapshots();
  }

  // ─── Send message ─────────────────────────────────────────────
  Future<DocumentReference> sendMessage(
    String receiverID,
    String message, {
    String? replyToMessageId,
    String? replyToMessage,
    String? replyToSenderEmail,
    MessageType messageType = MessageType.text,
    String? fileUrl,
    String? fileName,
    String? fileSize,
    bool isForwarded = false,
  }) async {
    final String currentUserID = _auth.currentUser!.uid;
    final String currentUserEmail = _auth.currentUser!.email!;
    final Timestamp timestamp = Timestamp.now();

    // E2E Encryption for text/base64
    String encryptedMessage = message;
    if (messageType == MessageType.text) {
      encryptedMessage = EncryptionService.encrypt(message);
    } else if (messageType == MessageType.image && message.startsWith('enc:')) {
      // message is already encrypted (e.g. from a previous call or internal logic)
      encryptedMessage = message;
    } else if (messageType == MessageType.image &&
        message.startsWith('data:')) {
      encryptedMessage = EncryptionService.encryptBase64(message);
    }

    // Also encrypt fileUrl if it is base64
    String? finalFileUrl = fileUrl;
    if (fileUrl != null && fileUrl.startsWith('data:')) {
      finalFileUrl = EncryptionService.encryptBase64(fileUrl);
    }

    final newMessage = Message(
      senderID: currentUserID,
      senderEmail: currentUserEmail,
      receiverID: receiverID,
      message: encryptedMessage,
      timestamp: timestamp,
      replyToMessageId: replyToMessageId,
      replyToMessage: replyToMessage,
      replyToSenderEmail: replyToSenderEmail,
      messageType: messageType,
      fileUrl: finalFileUrl,
      fileName: fileName,
      fileSize: fileSize,
      isForwarded: isForwarded,
    );

    final chatRoomID = _getChatRoomID(currentUserID, receiverID);

    // Update last message preview for the list
    String lastMessagePreview = message;
    if (messageType == MessageType.image) lastMessagePreview = '📷 Photo';
    if (messageType == MessageType.file) lastMessagePreview = '📁 File';
    if (messageType == MessageType.audio) {
      lastMessagePreview = '🎤 Voice message';
    }
    if (messageType == MessageType.video) lastMessagePreview = '🎥 Video';

    // Write message
    final docRef = await _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .add(newMessage.toMap());

    // Update chat room metadata (participants + last message)
    await _firestore.collection('chat_rooms').doc(chatRoomID).set({
      'participants': [currentUserID, receiverID],
      'lastMessage': lastMessagePreview,
      'lastMessageTimestamp': timestamp,
      'lastMessageSenderID': currentUserID,
      'hiddenBy': FieldValue.arrayRemove([currentUserID, receiverID]),
    }, SetOptions(merge: true));

    return docRef;
  }

  // ─── Edit message ─────────────────────────────────────────────
  Future<void> editMessage(
    String receiverID,
    String messageID,
    String newText,
  ) async {
    final currentUserID = _auth.currentUser!.uid;
    final chatRoomID = _getChatRoomID(currentUserID, receiverID);

    // Encrypt edit
    final encryptedText = EncryptionService.encrypt(newText);

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .doc(messageID)
        .update({'message': encryptedText, 'isEdited': true});
  }

  // ─── Delete message ───────────────────────────────────────────
  Future<void> deleteMessage(String receiverID, String messageID) async {
    final currentUserID = _auth.currentUser!.uid;
    final chatRoomID = _getChatRoomID(currentUserID, receiverID);
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .doc(messageID)
        .update({
          'isDeletedForEveryone': true,
          'message': 'This message was deleted',
          'fileUrl': null,
          'fileName': null,
        });
  }

  // ─── Hide Chat ────────────────────────────────────────────────
  Future<void> hideChat(String receiverID) async {
    final currentUserID = _auth.currentUser!.uid;
    final chatRoomID = _getChatRoomID(currentUserID, receiverID);
    await _firestore.collection('chat_rooms').doc(chatRoomID).set({
      'hiddenBy': FieldValue.arrayUnion([currentUserID]),
    }, SetOptions(merge: true));
  }

  // ─── Add/Remove Reaction ──────────────────────────────────────
  Future<void> toggleReaction(String receiverID, String messageID, String emoji) async {
    final currentUserID = _auth.currentUser!.uid;
    final chatRoomID = _getChatRoomID(currentUserID, receiverID);
    
    final docRef = _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .doc(messageID);
        
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final Map<String, dynamic> reactions = Map<String, dynamic>.from(snapshot.data()?['reactions'] ?? {});
      
      if (reactions[currentUserID] == emoji) {
        reactions.remove(currentUserID); // Toggle off if same emoji
      } else {
        reactions[currentUserID] = emoji; // Update or add
      }
      
      transaction.update(docRef, {'reactions': reactions});
    });
  }

  // ─── Delete message for me ────────────────────────────────────
  Future<void> deleteMessageForMe(String receiverID, String messageID) async {
    final currentUserID = _auth.currentUser!.uid;
    final chatRoomID = _getChatRoomID(currentUserID, receiverID);
    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .doc(messageID)
        .update({
          'deletedBy': FieldValue.arrayUnion([currentUserID]),
        });
  }

  // ─── Message stream for a chat room (cache-first) ───────────
  Stream<QuerySnapshot> getMessages(String userID, String otherUserID) {
    final chatRoomID = _getChatRoomID(userID, otherUserID);
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Cache-aware variant: emits cached docs first, then live Firestore updates.
  /// Use this in the UI for instant display.
  Stream<List<Map<String, dynamic>>> getMessagesCached(
    String userID,
    String otherUserID,
  ) async* {
    final roomId = _getChatRoomID(userID, otherUserID);

    // 1. Emit cached messages instantly
    final cached = LocalCache.getMessages(roomId);
    if (cached.isNotEmpty) yield cached;

    // 2. Stream live Firestore updates, update cache
    await for (final snap
        in _firestore
            .collection('chat_rooms')
            .doc(roomId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .snapshots()) {
      final docs =
          snap.docs.map((doc) {
            return LocalCache.firestoreDocToCache(doc.data(), doc.id);
          }).toList();
      // Persist last 50 to local cache
      LocalCache.saveMessages(roomId, docs).ignore();
      yield docs;
    }
  }

  // ─── Mark messages as seen ────────────────────────────────────
  Future<void> markMessagesAsSeen(String otherUserID) async {
    final currentUserID = _auth.currentUser?.uid;
    if (currentUserID == null) return;
    final chatRoomID = _getChatRoomID(currentUserID, otherUserID);

    try {
      // Find messages for this user that are not seen yet
      // We check for 'sent' and 'delivered' explicitly to avoid isNotEqualTo index issues
      final unseenSent =
          await _firestore
              .collection('chat_rooms')
              .doc(chatRoomID)
              .collection('messages')
              .where('receiverID', isEqualTo: currentUserID)
              .where('status', isEqualTo: 'sent')
              .get();

      final unseenDelivered =
          await _firestore
              .collection('chat_rooms')
              .doc(chatRoomID)
              .collection('messages')
              .where('receiverID', isEqualTo: currentUserID)
              .where('status', isEqualTo: 'delivered')
              .get();

      final allUnseen = [...unseenSent.docs, ...unseenDelivered.docs];

      if (allUnseen.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in allUnseen) {
        batch.update(doc.reference, {'status': 'seen'});
      }
      await batch.commit();
      // print('Marked ${allUnseen.length} messages as seen');
    } catch (e) {
      // print('Mark as seen failed: $e');
    }
  }

  // ─── Typing Status ─────────────────────────────────────────────
  Future<void> updateTypingStatus(String otherUserID, bool isTyping) async {
    final currentUserID = _auth.currentUser?.uid;
    if (currentUserID == null) return;
    final chatRoomID = _getChatRoomID(currentUserID, otherUserID);

    await _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('typing')
        .doc(currentUserID)
        .set({'isTyping': isTyping});
  }

  Stream<bool> getTypingStatus(String otherUserID) {
    final currentUserID = _auth.currentUser?.uid;
    if (currentUserID == null) return Stream.value(false);
    final chatRoomID = _getChatRoomID(currentUserID, otherUserID);

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('typing')
        .doc(otherUserID)
        .snapshots()
        .map((snapshot) => snapshot.data()?['isTyping'] == true);
  }

  // ─── Unread Message Count ─────────────────────────────────────
  Stream<int> getUnreadCountStream(String otherUserID) {
    final currentUserID = _auth.currentUser?.uid;
    if (currentUserID == null) return Stream.value(0);
    final chatRoomID = _getChatRoomID(currentUserID, otherUserID);

    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomID)
        .collection('messages')
        .where('receiverID', isEqualTo: currentUserID)
        .where('status', whereIn: ['sent', 'delivered'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ─── Mark messages as delivered ───────────────────────────────
  Future<void> markMessagesAsDelivered() async {
    final currentUserID = _auth.currentUser?.uid;
    if (currentUserID == null) return;

    try {
      // Note: collectionGroup requires a composite index: messages (receiverID: ASC, status: ASC)
      // If this fails, double check index in Firebase Console
      final unseenMessages =
          await _firestore
              .collectionGroup('messages')
              .where('receiverID', isEqualTo: currentUserID)
              .where('status', isEqualTo: 'sent')
              .get();

      if (unseenMessages.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in unseenMessages.docs) {
        batch.update(doc.reference, {'status': 'delivered'});
      }
      await batch.commit();
      // print('Marked ${unseenMessages.docs.length} messages as delivered');
    } catch (e) {
      /* print(
        'Delivery status update failed: $e. You might need to create a Firestore index.',
      ); */
    }
  }

  // ─── Get other user's ID from a chat room ─────────────────────
  static String getOtherUserID(
    List<dynamic> participants,
    String currentUserID,
  ) {
    return participants.firstWhere(
      (id) => id != currentUserID,
      orElse: () => '',
    );
  }
}
