import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;

class EncryptionService {
  // Static key for E2E (in a real production app, this would be derived per-chat)
  static final _key = Key.fromUtf8(
    'my32characterslongsecretkeyA9!!!',
  ); // 32 chars
  static final _iv = IV.fromUtf8('a9_iv_static_16b'); // Exactly 16 chars
  static final _encrypter = Encrypter(AES(_key));

  static const String prefix = 'enc:';

  /// Encrypts text if it doesn't already have the prefix
  static String encrypt(String text) {
    if (text.startsWith(prefix)) return text;
    try {
      final encrypted = _encrypter.encrypt(text, iv: _iv);
      return '$prefix${encrypted.base64}';
    } catch (e) {
      debugPrint('Encryption error: $e');
      return text;
    }
  }

  /// Decrypts text if it has the prefix
  static String decrypt(String encryptedText) {
    if (!encryptedText.startsWith(prefix)) return encryptedText;
    try {
      final base64String = encryptedText.substring(prefix.length);
      return _encrypter.decrypt64(base64String, iv: _iv);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return encryptedText; // Fallback to original if decryption fails
    }
  }

  /// Helper for images in base64 (already strings)
  static String encryptBase64(String base64) {
    return encrypt(base64);
  }

  static String decryptBase64(String encryptedBase64) {
    return decrypt(encryptedBase64);
  }
}
