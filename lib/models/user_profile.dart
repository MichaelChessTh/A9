import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String usernameLower;
  final String status;
  final String? avatarBase64;
  final bool isOnline;
  final Timestamp? lastActive;
  final List<String> blockedUsers;
  final String phoneNumber;
  final Map<String, String> nicknames;

  UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.usernameLower,
    this.status = 'I am using A9!',
    this.phoneNumber = '',
    this.avatarBase64,
    this.isOnline = false,
    this.lastActive,
    this.blockedUsers = const [],
    this.nicknames = const {},
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'username': username,
    'usernameLower': usernameLower,
    'status': status,
    'phoneNumber': phoneNumber,
    'avatarBase64': avatarBase64,
    'isOnline': isOnline,
    'lastActive': lastActive,
    'blockedUsers': blockedUsers,
    'nicknames': nicknames,
  };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    uid: map['uid'] ?? '',
    email: map['email'] ?? '',
    username: map['username'] ?? '',
    usernameLower: map['usernameLower'] ?? '',
    status: map['status'] ?? 'I am using A9!',
    phoneNumber: map['phoneNumber'] ?? '',
    avatarBase64: map['avatarBase64'],
    isOnline: map['isOnline'] ?? false,
    lastActive: map['lastActive'],
    blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
    nicknames: Map<String, String>.from(map['nicknames'] ?? {}),
  );

  UserProfile copyWith({
    String? username,
    String? status,
    String? phoneNumber,
    String? avatarBase64,
    bool clearAvatar = false,
    bool? isOnline,
    Timestamp? lastActive,
  }) => UserProfile(
    uid: uid,
    email: email,
    username: username ?? this.username,
    usernameLower: (username ?? this.username).toLowerCase(),
    status: status ?? this.status,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    avatarBase64: clearAvatar ? null : (avatarBase64 ?? this.avatarBase64),
    isOnline: isOnline ?? this.isOnline,
    lastActive: lastActive ?? this.lastActive,
    blockedUsers:
        blockedUsers, // usually we don't need copyWith for lists, but pass it if needed
    nicknames: nicknames,
  );
}
