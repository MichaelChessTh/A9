import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googlechat/models/group_chat.dart';
import 'package:googlechat/models/message.dart';
import 'package:googlechat/services/cache/local_cache.dart';
import 'package:googlechat/services/chat/encryption_service.dart';

class GroupService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─── Create group ───────────────────────────────────────────────
  static Future<String> createGroup({
    required String name,
    required List<String> memberUIDs,
    Uint8List? imageBytes,
  }) async {
    final admin = _auth.currentUser!;
    final all = [admin.uid, ...memberUIDs.where((id) => id != admin.uid)];

    String? imageBase64;
    if (imageBytes != null) {
      imageBase64 = 'data:image/webp;base64,${base64Encode(imageBytes)}';
    }

    final ref = _db.collection('group_rooms').doc();
    final group = GroupChat(
      id: ref.id,
      name: name,
      imageBase64: imageBase64,
      adminUID: admin.uid,
      memberUIDs: all,
    );
    await ref.set(group.toMap());
    return ref.id;
  }

  // ─── Send group message ─────────────────────────────────────────
  static Future<void> sendGroupMessage(
    String groupId,
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
    final user = _auth.currentUser!;
    final ts = Timestamp.now();

    // E2E Encryption for text/base64
    String encryptedMessage = message;
    if (messageType == MessageType.text) {
      encryptedMessage = EncryptionService.encrypt(message);
    } else if (messageType == MessageType.image && message.startsWith('enc:')) {
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

    final msg = Message(
      senderID: user.uid,
      senderEmail: user.email!,
      receiverID: groupId, // use groupId as receiverID
      message: encryptedMessage,
      timestamp: ts,
      replyToMessageId: replyToMessageId,
      replyToMessage: replyToMessage,
      replyToSenderEmail: replyToSenderEmail,
      messageType: messageType,
      fileUrl: finalFileUrl,
      fileName: fileName,
      fileSize: fileSize,
      status: MessageStatus.seen,
      isForwarded: isForwarded,
    );

    String preview = message;
    if (messageType == MessageType.image) preview = '📷 Photo';
    if (messageType == MessageType.file) preview = '📁 File';
    if (messageType == MessageType.audio) preview = '🎤 Voice message';

    final groupRef = _db.collection('group_rooms').doc(groupId);
    await groupRef.collection('messages').add(msg.toMap());
    await groupRef.update({
      'lastMessage': preview,
      'lastMessageTimestamp': ts,
      'lastMessageSenderID': user.uid,
    });
  }

  // ─── Stream: group messages ─────────────────────────────────────
  static Stream<QuerySnapshot> getGroupMessages(String groupId) {
    return _db
        .collection('group_rooms')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Cache-aware: emits cached last 50 first, then live updates.
  static Stream<List<Map<String, dynamic>>> getGroupMessagesCached(
    String groupId,
  ) async* {
    final roomKey = 'group_$groupId';
    // 1. Emit cache instantly
    final cached = LocalCache.getMessages(roomKey);
    if (cached.isNotEmpty) yield cached;

    // 2. Stream live
    await for (final snap
        in _db
            .collection('group_rooms')
            .doc(groupId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .snapshots()) {
      final docs =
          snap.docs.map((doc) {
            return LocalCache.firestoreDocToCache(doc.data(), doc.id);
          }).toList();
      LocalCache.saveMessages(roomKey, docs).ignore();
      yield docs;
    }
  }

  // ─── Stream: user's groups ──────────────────────────────────────
  static Stream<QuerySnapshot> getGroupsStream(String uid) {
    return _db
        .collection('group_rooms')
        .where('memberUIDs', arrayContains: uid)
        .snapshots();
  }

  // ─── Stream: single group ───────────────────────────────────────
  static Stream<DocumentSnapshot> getGroupStream(String groupId) {
    return _db.collection('group_rooms').doc(groupId).snapshots();
  }

  // ─── Edit message ───────────────────────────────────────────────
  static Future<void> editGroupMessage(
    String groupId,
    String messageId,
    String newText,
  ) async {
    // Encrypt edit
    final encryptedText = EncryptionService.encrypt(newText);

    await _db
        .collection('group_rooms')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({'message': encryptedText, 'isEdited': true});
  }

  // ─── Delete message ─────────────────────────────────────────────
  static Future<void> deleteGroupMessage(
    String groupId,
    String messageId,
  ) async {
    await _db
        .collection('group_rooms')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({
          'isDeletedForEveryone': true,
          'message': 'This message was deleted',
          'fileUrl': null,
          'fileName': null,
        });
  }

  // ─── Delete message for me ────────────────────────────────────
  static Future<void> deleteGroupMessageForMe(
    String groupId,
    String messageId,
  ) async {
    final currentUserID = _auth.currentUser!.uid;
    await _db
        .collection('group_rooms')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({
          'deletedBy': FieldValue.arrayUnion([currentUserID]),
        });
  }

  // ─── Add/Remove Reaction ──────────────────────────────────────
  static Future<void> toggleGroupReaction(String groupId, String messageId, String emoji) async {
    final currentUserID = _auth.currentUser!.uid;
    
    final docRef = _db
        .collection('group_rooms')
        .doc(groupId)
        .collection('messages')
        .doc(messageId);
        
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final Map<String, dynamic> reactions = Map<String, dynamic>.from(snapshot.data()?['reactions'] ?? {});
      
      if (reactions[currentUserID] == emoji) {
        reactions.remove(currentUserID);
      } else {
        reactions[currentUserID] = emoji;
      }
      
      transaction.update(docRef, {'reactions': reactions});
    });
  }

  // ─── Leave group ────────────────────────────────────────────────
  static Future<void> leaveGroup(String groupId) async {
    final uid = _auth.currentUser!.uid;
    await _db.collection('group_rooms').doc(groupId).update({
      'memberUIDs': FieldValue.arrayRemove([uid]),
    });
  }

  // ─── Remove member (admin only) ─────────────────────────────────
  static Future<void> removeMember(String groupId, String targetUID) async {
    await _db.collection('group_rooms').doc(groupId).update({
      'memberUIDs': FieldValue.arrayRemove([targetUID]),
    });
  }

  // ─── Update group info (admin only) ─────────────────────────────
  static Future<void> updateGroup(
    String groupId, {
    String? name,
    Uint8List? imageBytes,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (imageBytes != null) {
      updates['imageBase64'] =
          'data:image/webp;base64,${base64Encode(imageBytes)}';
    }
    if (updates.isEmpty) return;
    await _db.collection('group_rooms').doc(groupId).update(updates);
  }

  // ─── Add members (admin only) ───────────────────────────────────
  static Future<void> addMembers(String groupId, List<String> uids) async {
    await _db.collection('group_rooms').doc(groupId).update({
      'memberUIDs': FieldValue.arrayUnion(uids),
    });
  }

  // ─── Promote to Admin (admin only) ──────────────────────────────
  static Future<void> updateAdmin(String groupId, String targetUID) async {
    await _db.collection('group_rooms').doc(groupId).update({
      'adminUID': targetUID,
    });
  }

  // ─── Delete group (admin only) ──────────────────────────────────
  static Future<void> deleteGroup(String groupId) async {
    // Delete all messages first in a batch
    final msgs =
        await _db
            .collection('group_rooms')
            .doc(groupId)
            .collection('messages')
            .get();
    final batch = _db.batch();
    for (final doc in msgs.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection('group_rooms').doc(groupId));
    await batch.commit();
  }
}
