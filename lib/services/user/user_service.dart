import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/services/cache/local_cache.dart';
import 'package:image_picker/image_picker.dart';

class UserService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ─── Get profile once (cache-first) ─────────────────────────
  static Future<UserProfile?> getUserProfile(String uid) async {
    // 1. Return cached immediately if available
    final cached = LocalCache.getProfile(uid);
    if (cached != null) {
      _fetchAndCacheProfile(uid); // refresh in background
      return UserProfile.fromMap(cached);
    }
    // 2. Fetch from Firestore
    return _fetchAndCacheProfile(uid);
  }

  static Future<UserProfile?> _fetchAndCacheProfile(String uid) async {
    try {
      final doc = await _firestore.collection('Users').doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      await LocalCache.saveProfile(uid, data);
      return UserProfile.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  // ─── Watch profile as stream (cache → live) ───────────────────
  static Stream<UserProfile?> getUserProfileStream(String uid) async* {
    // Emit cached value instantly (zero latency)
    final cached = LocalCache.getProfile(uid);
    if (cached != null) yield UserProfile.fromMap(cached);

    // Then stream live Firestore updates
    await for (final doc
        in _firestore.collection('Users').doc(uid).snapshots()) {
      if (!doc.exists || doc.data() == null) {
        yield null;
      } else {
        final data = doc.data()!;
        // Update cache silently
        LocalCache.saveProfile(uid, data).ignore();
        yield UserProfile.fromMap(data);
      }
    }
  }

  // ─── Watch presence (isOnline + lastActive) ──
  static Stream<({bool isOnline, DateTime? lastActive})> getUserPresenceStream(
    String uid,
  ) async* {
    DateTime? lastKnownActive;

    // Create a local controller that merges Firestore updates and a 5s ticker
    final streamController =
        StreamController<({bool isOnline, DateTime? lastActive})>();

    final sub = _firestore.collection('Users').doc(uid).snapshots().listen((
      doc,
    ) {
      if (!doc.exists || doc.data() == null) {
        streamController.add((isOnline: false, lastActive: null));
        return;
      }
      final data = doc.data()!;
      final ts = data['lastActive'] as Timestamp?;
      lastKnownActive = ts?.toDate();

      // Explicit offline state or timeout
      bool isOnline = data['isOnline'] == true;
      if (lastKnownActive != null) {
        final diff = DateTime.now().difference(lastKnownActive!);
        if (diff.inSeconds > 30) {
          isOnline = false;
        }
      } else {
        isOnline = false;
      }

      streamController.add((isOnline: isOnline, lastActive: lastKnownActive));
    });

    final timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (lastKnownActive != null) {
        final diff = DateTime.now().difference(lastKnownActive!);
        if (diff.inSeconds > 30) {
          if (!streamController.isClosed) {
            streamController.add((
              isOnline: false,
              lastActive: lastKnownActive,
            ));
          }
        }
      }
    });

    streamController.onCancel = () {
      sub.cancel();
      timer.cancel();
    };

    yield* streamController.stream;
  }

  // ─── Watch current user profile ──────────────────────────────
  static Stream<UserProfile?> currentUserProfileStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return getUserProfileStream(uid);
  }

  // ─── Save profile (first time or update) ──────────────────────
  static Future<void> saveProfile({
    required String username,
    String status = '',
    String phoneNumber = '',
    String? avatarBase64,
  }) async {
    final uid = _auth.currentUser!.uid;
    final email = _auth.currentUser!.email!;

    final Map<String, dynamic> data = {
      'uid': uid,
      'email': email,
      'username': username.trim(),
      'usernameLower': username.trim().toLowerCase(),
      'status': status.trim(),
      'phoneNumber': phoneNumber.trim(),
    };
    if (avatarBase64 != null) {
      data['avatarBase64'] = avatarBase64;
    }

    await _firestore
        .collection('Users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // ─── Check if username is already taken ────────────────────────
  static Future<bool> isUsernameTaken(String username) async {
    final q = username.trim().toLowerCase();
    final snapshot =
        await _firestore
            .collection('Users')
            .where('usernameLower', isEqualTo: q)
            .limit(1)
            .get();

    // If docs found, check if it's not the current user
    if (snapshot.docs.isNotEmpty) {
      final existingUid = snapshot.docs.first.id;
      return existingUid != _auth.currentUser?.uid;
    }
    return false;
  }

  // ─── Remove avatar ────────────────────────────────────────────
  static Future<void> removeAvatar() async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('Users').doc(uid).update({
      'avatarBase64': FieldValue.delete(),
    });
  }

  // ─── Block / Unblock ──────────────────────────────────────────
  static Future<void> toggleBlockUser(String targetUID, bool block) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('Users').doc(uid).update({
      'blockedUsers':
          block
              ? FieldValue.arrayUnion([targetUID])
              : FieldValue.arrayRemove([targetUID]),
    });
  }

  // ─── Delete Account ───────────────────────────────────────────
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final uid = user.uid;
    
    // 1. Delete user's Firestore profile
    await _firestore.collection('Users').doc(uid).delete();
    
    // 2. Delete Firebase Auth user
    // Note: this may throw FirebaseAuthException if the user hasn't signed in recently
    await user.delete();
  }

  // ─── Set Nickname ──────────────────────────────────────────
  static Future<void> setNickname(String targetUID, String nickname) async {
    final uid = _auth.currentUser!.uid;
    await _firestore.collection('Users').doc(uid).update({
      'nicknames.$targetUID':
          nickname.trim().isEmpty ? FieldValue.delete() : nickname.trim(),
    });
  }

  // ─── Pick image and convert to base64 ─────────────────────────
  static Future<String?> pickAndEncodeAvatar() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300,
      maxHeight: 300,
      imageQuality: 75,
    );
    if (file == null) return null;
    final Uint8List bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  static Timer? _presenceTimer;

  static void _startPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final user = _auth.currentUser;
      if (user != null) {
        _firestore
            .collection('Users')
            .doc(user.uid)
            .update({
              'isOnline': true,
              'lastActive': FieldValue.serverTimestamp(),
            })
            .catchError((_) {});
      }
    });
  }

  static void _stopPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  // ─── Presence via Firestore ──────────────────────────────────────────
  static Future<void> initPresence() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('Users')
        .doc(user.uid)
        .update({'isOnline': true, 'lastActive': FieldValue.serverTimestamp()})
        .catchError((_) {});

    _startPresenceTimer();
  }

  // ─── Update Presence ──────────────────────────────────────────
  /// Manually set online/offline (app resume / pause from lifecycle observer).
  static Future<void> updatePresence(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (isOnline) {
      _startPresenceTimer();
    } else {
      _stopPresenceTimer();
    }

    await _firestore
        .collection('Users')
        .doc(user.uid)
        .update({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(),
        })
        .catchError((e) => debugPrint('Presence Firestore update error: $e'));
  }

  // ─── Search users by username, email, or phone ─────────────────
  static String normalizePhone(String phone) {
    String p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.isEmpty) return p;
    // If it starts with 8 or 7 (and is 11 digits), treat as +7
    if (p.length == 11 && (p.startsWith('8') || p.startsWith('7'))) {
      return '+7${p.substring(1)}';
    }
    // Otherwise just prepend + if not there
    if (!phone.startsWith('+')) return '+$p';
    return phone;
  }

  static Future<List<UserProfile>> searchUsers(String query) async {
    final currentUID = _auth.currentUser?.uid;
    if (currentUID == null) return [];

    if (query.trim().isEmpty) {
      // Use active chat users as default for empty query
      return getActiveChatUsers();
    }

    final q = query.trim().toLowerCase();

    // Search by lowercase username (prefix)
    final byUsername =
        await _firestore
            .collection('Users')
            .where('usernameLower', isGreaterThanOrEqualTo: q)
            .where('usernameLower', isLessThanOrEqualTo: '$q\uf8ff')
            .limit(20)
            .get();

    // Search by email (prefix)
    final byEmail =
        await _firestore
            .collection('Users')
            .where('email', isGreaterThanOrEqualTo: q)
            .where('email', isLessThanOrEqualTo: '$q\uf8ff')
            .limit(20)
            .get();

    // Search by phone
    final normalized = normalizePhone(query);
    final byPhone =
        await _firestore
            .collection('Users')
            .where('phoneNumber', isEqualTo: normalized)
            .limit(10)
            .get();

    final Map<String, UserProfile> results = {};
    for (final doc in [...byUsername.docs, ...byEmail.docs, ...byPhone.docs]) {
      final profile = UserProfile.fromMap(doc.data());
      if (profile.uid != currentUID) {
        results[profile.uid] = profile;
      }
    }
    return results.values.toList();
  }

  // ─── Get Active Chat Users ──────────────────────────────────
  static Future<List<UserProfile>> getActiveChatUsers() async {
    final currentUID = _auth.currentUser?.uid;
    if (currentUID == null) return [];

    final chatRooms =
        await _firestore
            .collection('chat_rooms')
            .where('participants', arrayContains: currentUID)
            .get();

    final otherUserIDs = <String>{};
    for (var doc in chatRooms.docs) {
      final data = doc.data();
      final hiddenBy = List<String>.from(data['hiddenBy'] ?? []);
      if (hiddenBy.contains(currentUID)) continue;

      final participants = List<String>.from(data['participants'] ?? []);
      final otherUID = participants.firstWhere(
        (id) => id != currentUID,
        orElse: () => '',
      );
      if (otherUID.isNotEmpty) {
        otherUserIDs.add(otherUID);
      }
    }

    if (otherUserIDs.isEmpty) return [];

    final List<UserProfile> activeUsers = [];
    final idList = otherUserIDs.toList();

    // Chunk by 30 for whereIn limit
    for (var i = 0; i < idList.length; i += 30) {
      final chunk = idList.sublist(
        i,
        i + 30 > idList.length ? idList.length : i + 30,
      );
      final usersSnap =
          await _firestore
              .collection('Users')
              .where('uid', whereIn: chunk)
              .get();
      for (var doc in usersSnap.docs) {
        activeUsers.add(UserProfile.fromMap(doc.data()));
      }
    }

    return activeUsers;
  }

  // ─── Decode base64 avatar to bytes (null-safe) ────────────────
  static Uint8List? decodeAvatar(String? base64) {
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }
}
