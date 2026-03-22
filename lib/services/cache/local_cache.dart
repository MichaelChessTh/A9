import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Key constants
const _kMessages = 'messages'; // box: roomId → List<Map> (last 50)
const _kProfiles = 'profiles'; // box: uid → Map
const _kMedia = 'media'; // box: messageId -> local file path
const _kSettings = 'settings'; // box: key -> value

/// One-stop local cache for messages and user/group profiles.
/// All values are stored as plain JSON (Map / List) — no generated adapters needed.
class LocalCache {
  static late Box _messages;
  static late Box _profiles;
  static late Box _media;
  static late Box _settings;

  static Future<void> init() async {
    await Hive.initFlutter();
    _messages = await Hive.openBox(_kMessages);
    _profiles = await Hive.openBox(_kProfiles);
    _media = await Hive.openBox(_kMedia);
    _settings = await Hive.openBox(_kSettings);
  }

  // ─── Media Paths ────────────────────────────────────────────────
  static String? getMediaPath(String messageId) {
    return _media.get(messageId) as String?;
  }

  static Future<void> saveMediaPath(String messageId, String path) async {
    await _media.put(messageId, path);
  }

  // ─── Settings ──────────────────────────────────────────────────
  static bool? getIsDarkMode() {
    return _settings.get('isDarkMode') as bool?;
  }

  static Future<void> setIsDarkMode(bool isDark) async {
    await _settings.put('isDarkMode', isDark);
  }

  // ─── Messages ──────────────────────────────────────────────────

  /// Returns the cached list of messages for [roomId] (newest-first order preserved).
  static List<Map<String, dynamic>> getMessages(String roomId) {
    final raw = _messages.get(roomId);
    if (raw == null) return [];
    return (raw as List).cast<Map<dynamic, dynamic>>().map((m) {
      return m.map((k, v) => MapEntry(k.toString(), v));
    }).toList();
  }

  /// Merges [incoming] messages into the cache for [roomId],
  /// keeping only the last [limit] sorted by timestamp ascending.
  static Future<void> saveMessages(
    String roomId,
    List<Map<String, dynamic>> incoming, {
    int limit = 50,
  }) async {
    // Start with what we have
    final existing = getMessages(roomId);

    // Merge by id deduplication
    final byId = <String, Map<String, dynamic>>{};
    for (final m in existing) {
      final id = m['_id'] as String?;
      if (id != null) byId[id] = m;
    }
    for (final m in incoming) {
      final id = m['_id'] as String?;
      if (id != null) byId[id] = m;
    }

    // Sort by timestamp string (ISO 8601 or ms-since-epoch int)
    var sorted =
        byId.values.toList()..sort((a, b) {
          final ta = _tsVal(a['timestamp']);
          final tb = _tsVal(b['timestamp']);
          return ta.compareTo(tb);
        });

    // Keep last 50
    if (sorted.length > limit) {
      sorted = sorted.sublist(sorted.length - limit);
    }

    await _messages.put(roomId, sorted);
  }

  static int _tsVal(dynamic ts) {
    if (ts == null) return 0;
    if (ts is int) return ts;
    if (ts is String) {
      return DateTime.tryParse(ts)?.millisecondsSinceEpoch ?? 0;
    }
    return 0;
  }

  // ─── Profiles ──────────────────────────────────────────────────

  static Map<String, dynamic>? getProfile(String uid) {
    final raw = _profiles.get(uid);
    if (raw == null) return null;
    return (raw as Map).map((k, v) => MapEntry(k.toString(), v));
  }

  static Future<void> saveProfile(String uid, Map<String, dynamic> data) async {
    await _profiles.put(uid, data);
  }

  // ─── Helpers ───────────────────────────────────────────────────

  /// Converts a Firestore snapshot doc to a cache-safe map.
  /// Replaces Timestamp with milliseconds int and recurses.
  static Map<String, dynamic> firestoreDocToCache(
    Map<String, dynamic> data,
    String docId,
  ) {
    final result = <String, dynamic>{'_id': docId};
    data.forEach((key, value) {
      result[key] = _convertValue(value);
    });
    return result;
  }

  static dynamic _convertValue(dynamic v) {
    if (v == null) return null;
    // Firestore Timestamp — convert to ms since epoch (int) for simple storage
    if (v.runtimeType.toString().contains('Timestamp')) {
      try {
        // cloud_firestore Timestamp has .millisecondsSinceEpoch
        return (v as dynamic).millisecondsSinceEpoch as int;
      } catch (_) {
        return v.toString();
      }
    }
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _convertValue(val)));
    }
    if (v is List) return v.map(_convertValue).toList();
    return v;
  }

  static String encodeForCache(Map<String, dynamic> m) => jsonEncode(m);
}
