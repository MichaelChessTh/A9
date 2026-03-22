import 'package:flutter/material.dart';

/// Holds the currently open chat for the foldable split-screen layout.
class FoldableController extends ChangeNotifier {
  // ─── Direct‑chat state ─────────────────────────────────────────
  String? _receiverEmail;
  String? _receiverID;

  // ─── Group‑chat state ──────────────────────────────────────────
  String? _groupId;
  String? _groupName;

  bool get hasChat => _receiverID != null || _groupId != null;
  bool get isGroupChat => _groupId != null;

  String? get receiverEmail => _receiverEmail;
  String? get receiverID => _receiverID;
  String? get groupId => _groupId;
  String? get groupName => _groupName;

  void openDirectChat({
    required String receiverEmail,
    required String receiverID,
  }) {
    _groupId = null;
    _groupName = null;
    _receiverEmail = receiverEmail;
    _receiverID = receiverID;
    notifyListeners();
  }

  void openGroupChat({required String groupId, required String groupName}) {
    _receiverEmail = null;
    _receiverID = null;
    _groupId = groupId;
    _groupName = groupName;
    notifyListeners();
  }

  void closeChat() {
    _receiverEmail = null;
    _receiverID = null;
    _groupId = null;
    _groupName = null;
    notifyListeners();
  }
}
