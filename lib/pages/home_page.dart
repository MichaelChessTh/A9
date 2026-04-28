import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:googlechat/components/my_drawer.dart';
import 'package:googlechat/components/user_avatar.dart';
import 'package:googlechat/models/group_chat.dart';
import 'package:googlechat/models/message.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/pages/chat_page.dart';
import 'package:googlechat/pages/create_group_page.dart';
import 'package:googlechat/pages/group_chat_page.dart';
import 'package:googlechat/services/auth/auth_service.dart';
import 'package:googlechat/services/chat/chat_service.dart';
import 'package:googlechat/services/group/group_service.dart';
import 'dart:io';
import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:intl/intl.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Message;
import 'package:provider/provider.dart';
import 'package:googlechat/services/update/update_service.dart';

class HomePage extends StatefulWidget {
  final List<Message>? forwardedMessages;

  /// Foldable-mode callbacks. When set the home page updates the right pane
  /// instead of pushing a new route.
  final void Function(String email, String uid)? onOpenDirectChat;
  final void Function(String groupId, String groupName)? onOpenGroupChat;

  const HomePage({
    super.key,
    this.forwardedMessages,
    this.onOpenDirectChat,
    this.onOpenGroupChat,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  bool _searchLoading = false;

  late final String _currentUID;
  StreamSubscription? _chatSubscription;

  // Contact UIDs cache for group creation
  final Set<String> _contactUIDs = {};

  @override
  void initState() {
    super.initState();
    _currentUID = _authService.getCurrentUser()!.uid;
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addObserver(this);
    UserService.updatePresence(true);
    _chatService.markMessagesAsDelivered();
    _setupChatListener();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestBackgroundPermissions();
    });
  }

  Future<void> _requestBackgroundPermissions() async {
    if (!Platform.isAndroid) return;
    try {
      // Request notification permission via flutter_local_notifications (SPM-compatible)
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      bool? isAutoStartReq =
          await DisableBatteryOptimization.isAutoStartEnabled;
      if (isAutoStartReq == false) {
        await DisableBatteryOptimization.showEnableAutoStartSettings(
          "Enable AutoStart",
          "Please enable AutoStart to receive background notifications promptly.",
        );
      }

      bool? isManBatteryEnabled =
          await DisableBatteryOptimization.isBatteryOptimizationDisabled;
      if (isManBatteryEnabled == false) {
        await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  void _setupChatListener() {
    _chatSubscription = _chatService.getActiveChatsStream(_currentUID).listen((
      snapshot,
    ) {
      if (mounted) {
        _chatService.markMessagesAsDelivered();
        // Collect contact UIDs for group creation
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          for (final uid in participants) {
            if (uid != _currentUID) _contactUIDs.add(uid);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    UserService.updatePresence(false);
    _chatSubscription?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UserService.updatePresence(true);
      _chatService.markMessagesAsDelivered();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      UserService.updatePresence(false);
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    setState(() {
      _isSearching = q.isNotEmpty;
    });
    if (q.isNotEmpty) _runSearch(q);
  }

  Future<void> _runSearch(String q) async {
    setState(() => _searchLoading = true);
    final results = await UserService.searchUsers(q);
    if (mounted && _searchController.text.trim() == q) {
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    }
  }

  Future<void> _openChat(UserProfile profile) async {
    _searchController.clear();
    _searchFocus.unfocus();

    // ── Foldable mode: delegate to the shell's right pane ───────
    if (widget.onOpenDirectChat != null && widget.forwardedMessages == null) {
      widget.onOpenDirectChat!(profile.email, profile.uid);
      return;
    }

    if (widget.forwardedMessages != null &&
        widget.forwardedMessages!.isNotEmpty) {
      for (final msg in widget.forwardedMessages!) {
        await _chatService.sendMessage(
          profile.uid,
          msg.message,
          messageType: msg.messageType,
          fileUrl: msg.fileUrl,
          fileName: msg.fileName,
          fileSize: msg.fileSize,
          isForwarded: true,
        );
      }
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChatPage(
                  receiverEmail: profile.email,
                  receiverID: profile.uid,
                ),
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) =>
                ChatPage(receiverEmail: profile.email, receiverID: profile.uid),
      ),
    );
  }

  void _openCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => CreateGroupPage(availableContactUIDs: _contactUIDs.toList()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Builder(
          builder: (context) {
            final hasUpdate = context.watch<UpdateService>().isUpdateAvailable;
            return IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface),
                  if (hasUpdate)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0084FF),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () => Scaffold.of(context).openDrawer(),
            );
          },
        ),
        title: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback:
              (bounds) => const LinearGradient(
                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
          child: Text(
            widget.forwardedMessages != null
                ? AppLocalizations.of(context)!.forward
                : 'A9',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 29,
              letterSpacing: -0.5,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: IconButton(
              tooltip: 'New Group',
              onPressed: _openCreateGroup,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.secondary.withValues(alpha: 0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group_add_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      drawer: const MyDrawer(),
      body: StreamBuilder<UserProfile?>(
        stream: UserService.currentUserProfileStream(),
        builder: (context, currentUserSnap) {
          final currentUserProfile = currentUserSnap.data;
          final blockedUsers = currentUserProfile?.blockedUsers ?? [];
          final nicknames = currentUserProfile?.nicknames ?? {};

          return Column(
            children: [
              _buildSearchBar(isDark, theme),
              Expanded(
                child:
                    _isSearching
                        ? _buildSearchResults(
                          theme,
                          isDark,
                          blockedUsers,
                          nicknames,
                        )
                        : _buildCombinedList(
                          theme,
                          isDark,
                          blockedUsers,
                          nicknames,
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Search bar ────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.searchPlaceholder,
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: false,
                  contentPadding: const EdgeInsets.only(left: 25),
                ),
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
              ),
            ),
            if (_isSearching)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _searchFocus.unfocus();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Search results ────────────────────────────────────────────
  Widget _buildSearchResults(
    ThemeData theme,
    bool isDark,
    List<String> blockedUsers,
    Map<String, String> nicknames,
  ) {
    if (_searchLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF0084FF),
          strokeWidth: 2,
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No users found',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: _searchResults.length,
      itemBuilder:
          (_, i) => _buildSearchResultItem(
            _searchResults[i],
            theme,
            isDark,
            blockedUsers,
            nicknames,
          ),
    );
  }

  Widget _buildSearchResultItem(
    UserProfile profile,
    ThemeData theme,
    bool isDark,
    List<String> blockedUsers,
    Map<String, String> nicknames,
  ) {
    final nickname = nicknames[profile.uid];
    final displayUsername =
        nickname != null && nickname.isNotEmpty ? nickname : profile.username;
    return InkWell(
      onTap: () => _openChat(profile),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            UserAvatar(
              displayName: displayUsername,
              avatarBase64: profile.avatarBase64,
              radius: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayUsername,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (nickname != null && nickname.isNotEmpty && profile.username.isNotEmpty)
                    Text(
                      '~${profile.username}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  if (profile.email.isNotEmpty || profile.phoneNumber.isNotEmpty)
                    Text(
                      [if (profile.email.isNotEmpty) profile.email, if (profile.phoneNumber.isNotEmpty) profile.phoneNumber].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  if (profile.status.isNotEmpty)
                    Text(
                      profile.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (blockedUsers.contains(profile.uid))
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  Icons.block_rounded,
                  color: Colors.red.shade400,
                  size: 20,
                ),
              ),
            Icon(
              Icons.chat_bubble_outline_rounded,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Combined direct + group chat list ─────────────────────────
  Widget _buildCombinedList(
    ThemeData theme,
    bool isDark,
    List<String> blockedUsers,
    Map<String, String> nicknames,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.getActiveChatsStream(_currentUID),
      builder: (context, dmSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: GroupService.getGroupsStream(_currentUID),
          builder: (context, groupSnap) {
            final isLoading =
                dmSnap.connectionState == ConnectionState.waiting ||
                groupSnap.connectionState == ConnectionState.waiting;
            final hasData = dmSnap.hasData || groupSnap.hasData;

            if (isLoading && !hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0084FF),
                  strokeWidth: 2,
                ),
              );
            }

            // Build unified items list
            final items = <_ChatItem>[];

            // Direct messages
            for (final doc in (dmSnap.data?.docs ?? [])) {
              final data = doc.data() as Map<String, dynamic>;

              final hiddenBy = List<String>.from(data['hiddenBy'] ?? []);
              if (hiddenBy.contains(_currentUID)) continue; // skip hidden chats

              final ts =
                  (data['lastMessageTimestamp'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              items.add(_ChatItem(type: _ChatType.direct, doc: doc, ts: ts));
            }

            // Group chats
            for (final doc in (groupSnap.data?.docs ?? [])) {
              final data = doc.data() as Map<String, dynamic>;
              final ts =
                  (data['lastMessageTimestamp'] as Timestamp?)
                      ?.millisecondsSinceEpoch ??
                  0;
              items.add(_ChatItem(type: _ChatType.group, doc: doc, ts: ts));
            }

            // Sort by timestamp descending
            items.sort((a, b) => b.ts.compareTo(a.ts));

            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.noConversations,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.noConversationsHint,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _openCreateGroup,
                      icon: const Icon(Icons.group_add_rounded, size: 18),
                      label: Text(AppLocalizations.of(context)!.newGroup),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0084FF),
                        side: const BorderSide(color: Color(0xFF0084FF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                if (item.type == _ChatType.direct) {
                  final data = item.doc.data() as Map<String, dynamic>;
                  final participants = List<String>.from(
                    data['participants'] ?? [],
                  );
                  final otherUID = ChatService.getOtherUserID(
                    participants,
                    _currentUID,
                  );
                  return Dismissible(
                    key: Key(item.doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              title: Text(
                                AppLocalizations.of(context)!.deleteChatTitle,
                              ),
                              content: Text(
                                AppLocalizations.of(context)!.deleteChatContent,
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: Text(
                                    AppLocalizations.of(context)!.cancel,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(
                                    AppLocalizations.of(context)!.delete,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                    },
                    onDismissed: (direction) {
                      _chatService.hideChat(otherUID);
                    },
                    child: _ChatTile(
                      key: ValueKey('tile_${item.doc.id}'),
                      otherUID: otherUID,
                      lastMessage: data['lastMessage'] as String? ?? '',
                      lastMessageTimestamp:
                          data['lastMessageTimestamp'] as Timestamp?,
                      currentUID: _currentUID,
                      isBlocked: blockedUsers.contains(otherUID),
                      nickname: nicknames[otherUID],
                      onTap: (profile) => _openChat(profile),
                      onLongPress:
                          () => _showDirectChatMenu(
                            context,
                            otherUID: otherUID,
                            isBlocked: blockedUsers.contains(otherUID),
                          ),
                    ),
                  );
                } else {
                  final data = item.doc.data() as Map<String, dynamic>;
                  final group = GroupChat.fromMap(data, item.doc.id);
                  return _GroupChatTile(
                    key: ValueKey('group_${item.doc.id}'),
                    group: group,
                    onTap: () async {
                      // ── Foldable mode ────────────────────────────
                      if (widget.onOpenGroupChat != null) {
                        widget.onOpenGroupChat!(group.id, group.name);
                        return;
                      }
                      if (widget.forwardedMessages != null &&
                          widget.forwardedMessages!.isNotEmpty) {
                        for (final msg in widget.forwardedMessages!) {
                          await GroupService.sendGroupMessage(
                            group.id,
                            msg.message,
                            messageType: msg.messageType,
                            fileUrl: msg.fileUrl,
                            fileName: msg.fileName,
                            fileSize: msg.fileSize,
                            isForwarded: true,
                          );
                        }
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => GroupChatPage(
                                    groupId: group.id,
                                    initialGroupName: group.name,
                                  ),
                            ),
                          );
                        }
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) => GroupChatPage(
                                  groupId: group.id,
                                  initialGroupName: group.name,
                                ),
                          ),
                        );
                      }
                    },
                    onLongPress: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              title: Text(
                                AppLocalizations.of(context)!.deleteGroupTitle,
                              ),
                              content: Text(
                                AppLocalizations.of(context)!.leaveGroupContent,
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: Text(
                                    AppLocalizations.of(context)!.cancel,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(
                                    AppLocalizations.of(context)!.delete,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                      );
                      if (ok == true) {
                        GroupService.leaveGroup(group.id);
                      }
                    },
                    theme: theme,
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  /// Shows a bottom sheet with Delete and Block/Unblock options for a direct chat.
  void _showDirectChatMenu(
    BuildContext context, {
    required String otherUID,
    required bool isBlocked,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                    color: isBlocked ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    isBlocked
                        ? AppLocalizations.of(context)!.unblockUser
                        : AppLocalizations.of(context)!.blockUser,
                    style: TextStyle(
                      color: isBlocked ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    UserService.toggleBlockUser(otherUID, !isBlocked);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: Text(
                    AppLocalizations.of(context)!.deleteChat,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _chatService.hideChat(otherUID);
                  },
                ),
              ],
            ),
          ),
    );
  }
}

enum _ChatType { direct, group }

class _ChatItem {
  final _ChatType type;
  final DocumentSnapshot doc;
  final int ts;
  _ChatItem({required this.type, required this.doc, required this.ts});
}

// ─── Group chat tile ───────────────────────────────────────────────
class _GroupChatTile extends StatelessWidget {
  final GroupChat group;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ThemeData theme;

  const _GroupChatTile({
    super.key,
    required this.group,
    required this.onTap,
    this.onLongPress,
    required this.theme,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (dt.year == now.year && now.difference(dt).inDays < 7) {
      return DateFormat('EEE').format(dt);
    }
    return DateFormat('dd.MM.yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(group.lastMessageTimestamp);
    final preview =
        group.lastMessage.length > 35
            ? '${group.lastMessage.substring(0, 35)}…'
            : group.lastMessage;

    Widget avatar;
    if (group.imageBase64 != null && group.imageBase64!.startsWith('data:')) {
      try {
        final bytes = base64Decode(group.imageBase64!.split(',').last);
        avatar = CircleAvatar(radius: 28, backgroundImage: MemoryImage(bytes));
      } catch (_) {
        avatar = _defaultGroupAvatar();
      }
    } else {
      avatar = _defaultGroupAvatar();
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Group avatar with group badge
            Stack(
              children: [
                avatar,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B5EFF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.group_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 12,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Group chat',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  if (preview.isNotEmpty)
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultGroupAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.group_rounded, color: Colors.white, size: 28),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String otherUID;
  final String lastMessage;
  final Timestamp? lastMessageTimestamp;
  final String currentUID;
  final bool isBlocked;
  final String? nickname;
  final void Function(UserProfile) onTap;
  final VoidCallback? onLongPress;

  const _ChatTile({
    super.key,
    required this.otherUID,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    required this.currentUID,
    required this.isBlocked,
    this.nickname,
    required this.onTap,
    this.onLongPress,
  });

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return DateFormat('HH:mm').format(dt);
    }
    if (dt.year == now.year && now.difference(dt).inDays < 7) {
      return DateFormat('EEE').format(dt);
    }
    return DateFormat('dd.MM.yy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<UserProfile?>(
      stream: UserService.getUserProfileStream(otherUID),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final baseUsername = profile?.username ?? '…';
        final displayUsername =
            nickname != null && nickname!.isNotEmpty ? nickname! : baseUsername;
        final timeStr = _formatTime(lastMessageTimestamp);
        final preview =
            lastMessage.length > 35
                ? '${lastMessage.substring(0, 35)}…'
                : lastMessage;

        return StreamBuilder<({bool isOnline, DateTime? lastActive})>(
          stream: UserService.getUserPresenceStream(otherUID),
          builder: (context, presenceSnap) {
            final isOnline = presenceSnap.data?.isOnline == true;

            return InkWell(
              onTap: () {
                // If full profile loaded → use it; otherwise create a minimal stub
                // so the chat is always openable even before Firestore responds.
                final target = profile ?? UserProfile(
                  uid: otherUID,
                  email: '',
                  username: nickname ?? displayUsername,
                  usernameLower: (nickname ?? displayUsername).toLowerCase(),
                  status: '',
                  blockedUsers: [],
                  nicknames: {},
                );
                onTap(target);
              },
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Avatar with online dot / block badge
                    Stack(
                      children: [
                        UserAvatar(
                          displayName: displayUsername,
                          avatarBase64: profile?.avatarBase64,
                          radius: 28,
                        ),
                        if (isBlocked)
                          Positioned(
                            right: 1,
                            bottom: 1,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.block_rounded,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else if (isOnline)
                          Positioned(
                            right: 1,
                            bottom: 1,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Content
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayUsername,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                StreamBuilder<bool>(
                                  stream: ChatService().getTypingStatus(
                                    otherUID,
                                  ),
                                  builder: (context, typingSnap) {
                                    final isTyping = typingSnap.data == true;
                                    if (isTyping) {
                                      return Text(
                                        'Печатает...',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    }
                                    return Text(
                                      preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(153), // 0.6 opacity
                                        fontSize: 14,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StreamBuilder<int>(
                            stream: ChatService().getUnreadCountStream(
                              otherUID,
                            ),
                            builder: (context, snapshot) {
                              final unreadCount = snapshot.data ?? 0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color:
                                          unreadCount > 0
                                              ? const Color(0xFF0084FF)
                                              : Colors.grey.shade500,
                                      fontSize: 12,
                                      fontWeight:
                                          unreadCount > 0
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0084FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 20,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
