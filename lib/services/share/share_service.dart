import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/pages/chat_page.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/services/navigation/navigation_service.dart';
import 'package:googlechat/components/user_avatar.dart';
import 'package:googlechat/l10n/app_localizations.dart';

class ShareService {
  static final ShareService _instance = ShareService._internal();
  factory ShareService() => _instance;
  ShareService._internal();

  StreamSubscription? _intentDataStreamSubscription;
  List<SharedMediaFile>? _sharedFiles;
  String? _sharedText;
  bool _isProcessing = false;

  void init() {
    // For sharing while app is in memory
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (value) {
            if (value.isNotEmpty) {
              _handleSharedData(value);
            }
          },
          onError: (err) {
            debugPrint("getMediaStream error: $err");
          },
        );

    // For sharing when app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedData(value);
      }
    });
  }

  void _handleSharedData(List<SharedMediaFile> value) async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final mediaFiles = <SharedMediaFile>[];
      String? sharedText;

      for (var file in value) {
        if (file.type == SharedMediaType.text ||
            file.type == SharedMediaType.url) {
          sharedText = file.path;
        } else {
          mediaFiles.add(file);
        }
      }

      _sharedFiles = mediaFiles.isNotEmpty ? mediaFiles : null;
      _sharedText = sharedText;

      if (_sharedFiles != null || _sharedText != null) {
        // Wait for app state to stabilize (e.g. context availability)
        await Future.delayed(const Duration(milliseconds: 800));

        final currentContext = NavigationService.navigatorKey.currentContext;
        if (currentContext != null && currentContext.mounted) {
          await _showShareSelectionDialog(currentContext);
        }
      }
    } catch (e) {
      debugPrint("Sharing processing error: $e");
    } finally {
      // Clear data and allow next share after the dialog is closed
      _sharedFiles = null;
      _sharedText = null;
      _isProcessing = false;
    }
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }

  Future<void> _showShareSelectionDialog(BuildContext context) async {
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
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
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4,
                              ),
                              leading: UserAvatar(
                                displayName: displayUsername,
                                avatarBase64: user.avatarBase64,
                                radius: 20,
                              ),
                              title: Text(
                                displayUsername,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                // IMPORTANT: Capture shared data BEFORE closing the dialog,
                                // because _handleSharedData clears it in its 'finally' block when the dialog closes.
                                final textToShare = _sharedText;
                                final filesToShare =
                                    _sharedFiles != null
                                        ? List<SharedMediaFile>.from(
                                          _sharedFiles!,
                                        )
                                        : null;

                                // Close the bottom sheet immediately
                                Navigator.of(ctx).pop();

                                // Navigate after a tiny delay to allow pop animation to finish
                                Future.delayed(
                                  const Duration(milliseconds: 200),
                                  () {
                                    _navigateToChatAndSend(
                                      user,
                                      text: textToShare,
                                      files: filesToShare,
                                    );
                                  },
                                );
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
    List<SharedMediaFile>? files,
  }) {
    final navigatorAction = NavigationService.navigatorKey.currentState;
    if (navigatorAction == null) return;

    navigatorAction.push(
      MaterialPageRoute(
        builder:
            (context) => ChatPage(
              receiverEmail: user.email,
              receiverID: user.uid,
              initialText: text,
              initialFiles: files,
            ),
      ),
    );
  }
}
