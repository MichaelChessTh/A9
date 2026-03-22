import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googlechat/services/chat/encryption_service.dart';

enum MessageType { text, image, file, audio, video }

enum MessageStatus { sent, delivered, seen }

enum SelectionMode { none, delete, forward }

class Message {
  final String id;
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message;
  final Timestamp timestamp;
  final bool isEdited;
  final String? replyToMessageId;
  final String? replyToMessage;
  final String? replyToSenderEmail;
  final bool isDeletedForEveryone;

  // New fields for media
  final MessageType messageType;
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;
  final MessageStatus status;
  final bool isForwarded;
  final Map<String, dynamic> reactions;

  Message({
    this.id = '',
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.message,
    required this.timestamp,
    this.isEdited = false,
    this.replyToMessageId,
    this.replyToMessage,
    this.replyToSenderEmail,
    this.messageType = MessageType.text,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.status = MessageStatus.sent,
    this.isDeletedForEveryone = false,
    this.isForwarded = false,
    this.reactions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': senderEmail,
      'receiverID': receiverID,
      'message': message,
      'timestamp': timestamp,
      'isEdited': isEdited,
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage,
      'replyToSenderEmail': replyToSenderEmail,
      'messageType': messageType.name,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'status': status.name,
      'isDeletedForEveryone': isDeletedForEveryone,
      'isForwarded': isForwarded,
      'reactions': reactions,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map, {String? docId}) {
    // Decrypt message text if encrypted
    final rawMessage = map['message'] as String? ?? '';
    final decryptedMessage = EncryptionService.decrypt(rawMessage);

    // Decrypt fileUrl if it's an encrypted base64 image
    final rawFileUrl = map['fileUrl'] as String?;
    String? decryptedFileUrl;
    if (rawFileUrl != null) {
      if (rawFileUrl.startsWith('enc:')) {
        // It's an encrypted base64 — decrypt it back to data:image/...
        decryptedFileUrl = EncryptionService.decryptBase64(rawFileUrl);
      } else {
        decryptedFileUrl = rawFileUrl;
      }
    }

    return Message(
      id: docId ?? '',
      senderID: map['senderID'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      receiverID: map['receiverID'] ?? '',
      message: decryptedMessage,
      timestamp: map['timestamp'] ?? Timestamp.now(),
      isEdited: map['isEdited'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      replyToMessage: map['replyToMessage'],
      replyToSenderEmail: map['replyToSenderEmail'],
      messageType: MessageType.values.firstWhere(
        (e) => e.name == (map['messageType'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      fileUrl: decryptedFileUrl,
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      status: MessageStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'sent'),
        orElse: () => MessageStatus.sent,
      ),
      isDeletedForEveryone: map['isDeletedForEveryone'] as bool? ?? false,
      isForwarded: map['isForwarded'] as bool? ?? false,
      reactions: map['reactions'] as Map<String, dynamic>? ?? {},
    );
  }
}
