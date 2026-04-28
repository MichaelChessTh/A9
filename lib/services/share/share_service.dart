import 'dart:async';
import 'package:flutter/material.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/pages/chat_page.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/services/navigation/navigation_service.dart';
import 'package:googlechat/components/user_avatar.dart';
import 'package:googlechat/l10n/app_localizations.dart';

/// ShareService handles incoming shared content from other apps.
/// Native "Share to A9" via system share sheet requires platform-specific
/// setup (Android Intents / iOS Share Extension) and is currently disabled
/// to maintain a clean, CocoaPods-free iOS build.
class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  bool _isProcessing = false;

  /// Call from main.dart after the app starts.
  void init() {
    // Native share-intent receiving is disabled.
    // To re-enable on Android, add receive_sharing_intent back to pubspec
    // and wrap all usage in Platform.isAndroid guards.
  }

  void dispose() {}

  /// Manually trigger the contact picker to share [text] or [files] to a user.
  Future<void> showShareDialog({String? text, List<Map<String, String>>? files}) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      final context = NavigationService.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await _showShareSelectionDialog(context, text: text, files: files);
      }
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _showShareSelectionDialog(
    BuildContext context, {
    String? text,
    List<Map<String, String>>? files,
  }) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (ctx) {
        final theme = Theme.of(context);
        final l10n = AppLocalizations.of(context)!;

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.shareTo,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: StreamBuilder<UserProfile?>(
                  stream: UserService.currentUserProfileStream(),
                  builder: (context, userSnap) {
                    final nicknames = userSnap.data?.nicknames ?? {};
                    return StreamBuilder<List<UserProfile>>(
                      stream: Stream.fromFuture(UserService.searchUsers("")),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final users = snapshot.data ?? [];
                        if (users.isEmpty) {
                          return SizedBox(
                            height: 200,
                            child: Center(child: Text(l10n.noUsersFound)),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            final nickname = nicknames[user.uid];
                            final displayUsername =
                                nickname != null && nickname.isNotEmpty
                                    ? nickname
                                    : user.username;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4),
                              leading: UserAvatar(
                                displayName: displayUsername,
                                avatarBase64: user.avatarBase64,
                                radius: 20,
                              ),
                              title: Text(
                                displayUsername,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              onTap: () {
                                Navigator.of(ctx).pop();
                                Future.delayed(const Duration(milliseconds: 200), () {
                                  _navigateToChatAndSend(
                                    user,
                                    text: text,
                                    files: files,
                                  );
                                });
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  void _navigateToChatAndSend(
    UserProfile user, {
    String? text,
    List<Map<String, String>>? files,
  }) {
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          receiverEmail: user.email,
          receiverID: user.uid,
          initialText: text,
          initialFiles: files,
        ),
      ),
    );
  }
}
