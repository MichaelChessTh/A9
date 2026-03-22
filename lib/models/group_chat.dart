import 'package:cloud_firestore/cloud_firestore.dart';

class GroupChat {
  final String id;
  final String name;
  final String? imageBase64;
  final String adminUID;
  final List<String> memberUIDs;
  final String lastMessage;
  final Timestamp? lastMessageTimestamp;
  final String? lastMessageSenderID;

  GroupChat({
    required this.id,
    required this.name,
    this.imageBase64,
    required this.adminUID,
    required this.memberUIDs,
    this.lastMessage = '',
    this.lastMessageTimestamp,
    this.lastMessageSenderID,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'imageBase64': imageBase64,
    'adminUID': adminUID,
    'memberUIDs': memberUIDs,
    'lastMessage': lastMessage,
    'lastMessageTimestamp': lastMessageTimestamp,
    'lastMessageSenderID': lastMessageSenderID,
  };

  factory GroupChat.fromMap(Map<String, dynamic> map, String docId) =>
      GroupChat(
        id: docId,
        name: map['name'] ?? '',
        imageBase64: map['imageBase64'],
        adminUID: map['adminUID'] ?? '',
        memberUIDs: List<String>.from(map['memberUIDs'] ?? []),
        lastMessage: map['lastMessage'] ?? '',
        lastMessageTimestamp: map['lastMessageTimestamp'],
        lastMessageSenderID: map['lastMessageSenderID'],
      );
}
