import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart' hide Key;

/// AES-256-CBC message encryption.
///
/// KEY: shared symmetric key (32 bytes).
///      TODO v2.0: replace with per-chat ECDH derived key.
///
/// IV:  randomly generated per-message (16 bytes), prepended to ciphertext.
///      Format: base64( iv_16_bytes + ciphertext )
///      Prefix: "enc:"
///
/// MIGRATION NOTE: The old static-IV format ("enc:" + plain-base64) is still
/// decryptable via the legacy path. New messages always use the random-IV path.
class EncryptionService {
  // ── Key ──────────────────────────────────────────────────────────────────
  // The key is the same as before so existing messages remain readable.
  // To harden further, provide at build time:
  //   flutter build apk --dart-define=AES_KEY=<your-32-char-key>
  static const String _rawKey = String.fromEnvironment(
    'AES_KEY',
    defaultValue: 'my32characterslongsecretkeyA9!!!',
  );

  static final Key _key = Key.fromUtf8(_rawKey);

  // Legacy static IV — only used for DECRYPTING old messages.
  static final IV _legacyIV = IV.fromUtf8('a9_iv_static_16b');

  static const String prefix = 'enc:';

  // ── Random IV generation ─────────────────────────────────────────────────
  static final Random _rng = Random.secure();

  static IV _randomIV() {
    final bytes = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      bytes[i] = _rng.nextInt(256);
    }
    return IV(bytes);
  }

  // ── Encrypt ──────────────────────────────────────────────────────────────
  /// Encrypts [text] and returns "enc:<base64(iv+ciphertext)>"
  static String encrypt(String text) {
    if (text.startsWith(prefix)) return text; // already encrypted
    try {
      final iv = _randomIV();
      final encrypter = Encrypter(AES(_key));
      final encrypted = encrypter.encrypt(text, iv: iv);

      // Prepend the 16-byte IV to the ciphertext so we can recover it on decrypt
      final combined = Uint8List(16 + encrypted.bytes.length);
      combined.setAll(0, iv.bytes);
      combined.setAll(16, encrypted.bytes);

      return '$prefix${base64.encode(combined)}';
    } catch (e) {
      debugPrint('Encryption error: $e');
      return text;
    }
  }

  // ── Decrypt ──────────────────────────────────────────────────────────────
  /// Decrypts a value produced by [encrypt].
  /// Also handles legacy messages encrypted with the old static IV.
  static String decrypt(String encryptedText) {
    if (!encryptedText.startsWith(prefix)) return encryptedText;
    try {
      final combined = base64.decode(encryptedText.substring(prefix.length));

      if (combined.length < 16) {
        // Corrupt / too short — return as-is
        return encryptedText;
      }

      // Try new format first: first 16 bytes = IV
      final ivBytes = Uint8List.fromList(combined.sublist(0, 16));
      final cipherBytes = Uint8List.fromList(combined.sublist(16));

      // Heuristic: if remiaining bytes are not a multiple of 16, this is a
      // legacy message (AES-CBC always produces block-aligned output).
      // Fall back to the old static-IV path.
      if (cipherBytes.length % 16 != 0) {
        return _decryptLegacy(encryptedText);
      }

      final iv = IV(ivBytes);
      final encrypter = Encrypter(AES(_key));
      return encrypter.decrypt(Encrypted(cipherBytes), iv: iv);
    } catch (_) {
      // If new format fails, try legacy (static IV) so old messages still show
      return _decryptLegacy(encryptedText);
    }
  }

  static String _decryptLegacy(String encryptedText) {
    try {
      final base64String = encryptedText.substring(prefix.length);
      final encrypter = Encrypter(AES(_key));
      return encrypter.decrypt64(base64String, iv: _legacyIV);
    } catch (e) {
      debugPrint('Decryption error (legacy): $e');
      return encryptedText;
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  static String encryptBase64(String base64Str) => encrypt(base64Str);
  static String decryptBase64(String encrypted) => decrypt(encrypted);
}
