import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:googlechat/components/chat_bubble.dart';
import 'package:googlechat/components/user_avatar.dart';
import 'package:googlechat/models/group_chat.dart';
import 'package:googlechat/models/message.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/pages/home_page.dart';
import 'package:googlechat/services/auth/auth_service.dart';
import 'package:googlechat/services/chat/chat_service.dart';
import 'package:googlechat/services/group/group_service.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:googlechat/services/chat/encryption_service.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String initialGroupName;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.initialGroupName,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _authService = AuthService();
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();

  late final String _currentUID;
  String? _replyToMessageId;
  String? _replyToMessage;
  String? _replyToSenderEmail;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Multi-selection state
  final Set<String> _selectedMessageIds = {};
  final List<Message> _selectedMessages = [];
  SelectionMode _selectionMode = SelectionMode.none;
  bool get _isSelectionMode => _selectionMode != SelectionMode.none;

  bool _isAdmin = false;
  File? _wallpaperImage;

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('wallpaper_${widget.groupId}');
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists() && mounted) {
        setState(() => _wallpaperImage = file);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
    _currentUID = _authService.getCurrentUser()!.uid;
    // We'll update _isAdmin from the stream in build()
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setReply(String msgId, String msg, String senderEmail) {
    setState(() {
      _replyToMessageId = msgId;
      _replyToMessage = msg;
      _replyToSenderEmail = senderEmail;
    });
  }

  void _clearReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToMessage = null;
      _replyToSenderEmail = null;
    });
  }

  void _toggleSelection(
    String msgId,
    Message msg, {
    SelectionMode? requestedMode,
  }) {
    setState(() {
      if (_selectedMessageIds.isEmpty && requestedMode != null) {
        _selectionMode = requestedMode;
      }

      if (_selectedMessageIds.contains(msgId)) {
        _selectedMessageIds.remove(msgId);
        _selectedMessages.removeWhere(
          (m) =>
              m.senderID == msg.senderID &&
              m.message == msg.message &&
              m.timestamp == msg.timestamp,
        ); // This is risky, use a better way to find the message
      } else {
        _selectedMessageIds.add(msgId);
        _selectedMessages.add(msg);
      }

      if (_selectedMessageIds.isEmpty) {
        _selectionMode = SelectionMode.none;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMessageIds.clear();
      _selectedMessages.clear();
      _selectionMode = SelectionMode.none;
    });
  }

  Future<void> _handleDeleteSelected(bool forEveryone) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              forEveryone ? l10n.deleteForEveryone : l10n.deleteForMe,
            ),
            content: Text(
              forEveryone
                  ? l10n.deleteForEveryoneQuestion
                  : l10n.deleteForMeQuestion,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  l10n.delete,
                  style: TextStyle(
                    color: forEveryone ? Colors.red : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      for (final msgId in _selectedMessageIds) {
        if (forEveryone) {
          await GroupService.deleteGroupMessage(widget.groupId, msgId);
        } else {
          await GroupService.deleteGroupMessageForMe(widget.groupId, msgId);
        }
      }
      _clearSelection();
    }
  }

  void _handleForwardSelected() {
    final messagesToForward = List<Message>.from(_selectedMessages);
    messagesToForward.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    _clearSelection();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(forwardedMessages: messagesToForward),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _messageCtrl.clear();

    await GroupService.sendGroupMessage(
      widget.groupId,
      text,
      replyToMessageId: _replyToMessageId,
      replyToMessage: _replyToMessage,
      replyToSenderEmail: _replyToSenderEmail,
    );
    _clearReply();
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image_rounded),
                  title: Text(
                    AppLocalizations.of(ctx)?.encryptedImageLowQuality ??
                        'Encrypted Image (low quality)',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.hd_rounded),
                  title: Text(AppLocalizations.of(ctx)?.hdPhoto ?? 'HD Image'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickHDImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: Text(AppLocalizations.of(ctx)?.video ?? 'Video'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_rounded),
                  title: Text(AppLocalizations.of(ctx)?.file ?? 'File'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFile();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      await _uploadAndSend(bytes, image.name, MessageType.image);
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (image != null) {
      _editAndSendImage(image, isHD: true);
    }
  }

  Future<void> _pickHDImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (image != null) {
      _editAndSendImage(image, isHD: true);
    }
  }

  Future<void> _editAndSendImage(XFile imageFile, {bool isHD = false}) async {
    final editedBytes = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.file(
          File(imageFile.path),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              Navigator.pop(context, bytes);
            },
            onCloseEditor: (mode) => Navigator.pop(context),
          ),
        ),
      ),
    );

    if (editedBytes != null && editedBytes is Uint8List) {
      await _uploadAndSend(
        editedBytes,
        imageFile.name,
        MessageType.image,
        isHD: isHD,
      );
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final bytes = await video.readAsBytes();
      await _uploadAndSend(bytes, video.name, MessageType.video);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    final bytes = await File(file.path!).readAsBytes();
    await _uploadAndSend(bytes, file.name, MessageType.file);
  }

  Future<void> _uploadAndSend(
    Uint8List bytes,
    String fileName,
    MessageType type, {
    bool isHD = false,
  }) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    try {
      final url = await _chatService.uploadFile(
        bytes: bytes,
        fileName: fileName,
        type: type,
        isHD: isHD,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
            });
          }
        },
      );

      await GroupService.sendGroupMessage(
        widget.groupId,
        type == MessageType.image ? '' : fileName,
        messageType: type,
        fileUrl: url,
        fileName: fileName,
        fileSize: _formatSize(bytes.length),
        replyToMessageId: _replyToMessageId,
        replyToMessage: _replyToMessage,
        replyToSenderEmail: _replyToSenderEmail,
      );
      _clearReply();
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Future<void> _showEditDialog(String messageId, String currentText) async {
    final ctrl = TextEditingController(text: currentText);
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.editMessage),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: null,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context)!.save),
              ),
            ],
          ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await GroupService.editGroupMessage(
        widget.groupId,
        messageId,
        ctrl.text.trim(),
      );
    }
    ctrl.dispose();
  }

  Future<void> _showDeleteDialog(
    String messageId,
    bool isCurrentUser,
    bool isDeletedForEveryone,
  ) async {
    if (isDeletedForEveryone) {
      await GroupService.deleteGroupMessageForMe(widget.groupId, messageId);
      return;
    }
    // Admin can delete any message, regular users only their own
    final canDeleteForEveryone = isCurrentUser || _isAdmin;

    final ok = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(AppLocalizations.of(context)!.deleteForMe),
                  onTap: () => Navigator.pop(context, 'me'),
                ),
                if (canDeleteForEveryone)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.deleteForEveryone,
                      style: const TextStyle(color: Colors.red),
                    ),
                    onTap: () => Navigator.pop(context, 'everyone'),
                  ),
              ],
            ),
          ),
    );
    if (ok == 'me') {
      await GroupService.deleteGroupMessageForMe(widget.groupId, messageId);
    } else if (ok == 'everyone') {
      await GroupService.deleteGroupMessage(widget.groupId, messageId);
    }
  }

  /// Shows WhatsApp-style call type selector
  void _showCallTypeMenu(BuildContext context, String groupName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF34A853), Color(0xFF22963F)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.call_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    '\u0413\u043e\u043b\u043e\u0441\u043e\u0432\u043e\u0439 \u0437\u0432\u043e\u043d\u043e\u043a',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(groupName),
                  onTap: () {
                    Navigator.pop(ctx);
                    ZegoUIKitPrebuiltCallInvitationService().send(
                      isVideoCall: false,
                      resourceID: 'zegouikit_call',
                      invitees: [],
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0084FF), Color(0xFF0073E6)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  title: const Text(
                    '\u0412\u0438\u0434\u0435\u043e\u0437\u0432\u043e\u043d\u043e\u043a',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(groupName),
                  onTap: () {
                    Navigator.pop(ctx);
                    ZegoUIKitPrebuiltCallInvitationService().send(
                      isVideoCall: true,
                      resourceID: 'zegouikit_call',
                      invitees: [],
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openGroupInfo(GroupChat group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupInfoSheet(group: group, currentUID: _currentUID),
    ).then((result) {
      if (result == 'left' || result == 'deleted') {
        if (mounted) Navigator.pop(context);
      } else if (result == 'wallpaper_changed') {
        _loadWallpaper();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: GroupService.getGroupStream(widget.groupId),
      builder: (context, groupSnap) {
        if (!groupSnap.hasData || !groupSnap.data!.exists) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final group = GroupChat.fromMap(
          groupSnap.data!.data() as Map<String, dynamic>,
          widget.groupId,
        );

        // Update admin status
        _isAdmin = group.adminUID == _currentUID;

        // If current user no longer a member, pop automatically
        if (!group.memberUIDs.contains(_currentUID)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 0,
            leading:
                _isSelectionMode
                    ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _clearSelection,
                    )
                    : null,
            title:
                _isSelectionMode
                    ? Text(
                      '${_selectedMessageIds.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                    : (_isSearching
                        ? TextField(
                          controller: _searchController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText:
                                AppLocalizations.of(context)!.searchMessages,
                            border: InputBorder.none,
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        )
                        : InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openGroupInfo(group),
                          child: Row(
                            children: [
                              _GroupAvatar(
                                imageBase64: group.imageBase64,
                                radius: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    StreamBuilder<QuerySnapshot>(
                                      stream:
                                          FirebaseFirestore.instance
                                              .collection('users')
                                              .where(
                                                FieldPath.documentId,
                                                whereIn:
                                                    group.memberUIDs.isEmpty
                                                        ? ['__none__']
                                                        : group.memberUIDs,
                                              )
                                              .where(
                                                'isOnline',
                                                isEqualTo: true,
                                              )
                                              .snapshots(),
                                      builder: (context, onlineSnap) {
                                        final onlineCount =
                                            onlineSnap.data?.docs.length ?? 0;
                                        final subtitle =
                                            onlineCount > 0
                                                ? AppLocalizations.of(
                                                  context,
                                                )!.onlineMembersCount(
                                                  onlineCount,
                                                )
                                                : AppLocalizations.of(
                                                  context,
                                                )!.groupChatMembers(
                                                  group.memberUIDs.length,
                                                );
                                        return Text(
                                          subtitle,
                                          style: TextStyle(
                                            color:
                                                onlineCount > 0
                                                    ? Colors.green.shade400
                                                    : Colors.grey.shade500,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
            actions:
                _isSelectionMode
                    ? [
                      if (_selectionMode == SelectionMode.forward)
                        IconButton(
                          icon: const Icon(Icons.forward_to_inbox_rounded),
                          onPressed: _handleForwardSelected,
                        )
                      else ...[
                        // Show red (delete for all) only if all selected msgs are mine OR admin
                        if (_selectedMessages.every(
                              (m) => m.senderID == _currentUID,
                            ) ||
                            _isAdmin)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: Colors.red,
                            ),
                            onPressed: () => _handleDeleteSelected(true),
                            tooltip:
                                AppLocalizations.of(
                                  context,
                                )!.deleteForEveryoneTip,
                          ),
                        // White outline trash for "delete for me" always available
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () => _handleDeleteSelected(false),
                          tooltip: AppLocalizations.of(context)!.deleteForMeTip,
                        ),
                      ],
                      const SizedBox(width: 8),
                    ]
                    : [
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close : Icons.search),
                        onPressed: () {
                          setState(() {
                            if (_isSearching) {
                              _isSearching = false;
                              _searchController.clear();
                              _searchQuery = '';
                            } else {
                              _isSearching = true;
                            }
                          });
                        },
                      ),
                      // Single styled call button
                      if (!_isSearching)
                        IconButton(
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0084FF), Color(0xFF0073E6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0084FF).withAlpha(80),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.call_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          onPressed:
                              () => _showCallTypeMenu(context, group.name),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                        onPressed: () => _openGroupInfo(group),
                      ),
                      const SizedBox(width: 4),
                    ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),
            ),
          ),
          body: Stack(
            children: [
              if (_wallpaperImage != null)
                Positioned.fill(
                  child: Image.file(
                    _wallpaperImage!,
                    fit: BoxFit.cover,
                    color: isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.6),
                    colorBlendMode: isDark ? BlendMode.darken : BlendMode.lighten,
                  ),
                ),
              Column(
                children: [
                  Expanded(
                child: _GroupMessageList(
                  groupId: widget.groupId,
                  senderID: _currentUID,
                  scrollController: _scrollController,
                  onReply: _setReply,
                  onEdit: _showEditDialog,
                  onDelete: _showDeleteDialog,
                  searchQuery: _searchQuery,
                  selectedMessageIds: _selectedMessageIds,
                  selectionMode: _selectionMode,
                  onToggleSelection: _toggleSelection,
                ),
              ),
              if (_replyToMessage != null) _buildReplyPreview(theme),
              _buildInputBar(theme, isDark),
            ],
          ),
        ],
        ),
      );
      },
    );
  }

  Widget _buildReplyPreview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.5),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyToSenderEmail?.split('@').first ?? '',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: _clearReply,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      color: Colors.transparent,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      padding: const EdgeInsets.only(bottom: 2),
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                      onPressed: () {},
                      constraints: const BoxConstraints(minWidth: 40),
                      splashRadius: 20,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageCtrl,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)!.messageHint,
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(top: 12, bottom: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.only(bottom: 2),
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                      onPressed: _isUploading ? null : _showAttachmentMenu,
                      constraints: const BoxConstraints(minWidth: 40),
                      splashRadius: 20,
                    ),
                    IconButton(
                      padding: const EdgeInsets.only(bottom: 2, right: 4),
                      icon: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.grey.shade600,
                        size: 24,
                      ),
                      onPressed: _isUploading ? null : _takePhoto,
                      constraints: const BoxConstraints(minWidth: 40),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: _isUploading
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Group message list ────────────────────────────────────────────
class _GroupMessageList extends StatefulWidget {
  final String groupId;
  final String senderID;
  final ScrollController scrollController;
  final Function(String, String, String) onReply;
  final Function(String, String) onEdit;
  final Function(String, bool, bool) onDelete;
  final String searchQuery;
  final Set<String> selectedMessageIds;
  final SelectionMode selectionMode;
  final void Function(String, Message, {SelectionMode? requestedMode})
  onToggleSelection;

  const _GroupMessageList({
    required this.groupId,
    required this.senderID,
    required this.scrollController,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.searchQuery,
    required this.selectedMessageIds,
    required this.selectionMode,
    required this.onToggleSelection,
  });

  @override
  State<_GroupMessageList> createState() => _GroupMessageListState();
}

class _GroupMessageListState extends State<_GroupMessageList> {
  String? _lastDocId;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.scrollController.hasClients) return;
      final sc = widget.scrollController;
      if (!sc.position.hasContentDimensions) return;

      void jump() {
        if (sc.hasClients) sc.jumpTo(0.0);
      }

      void animate() {
        if (sc.hasClients) {
          sc.animateTo(
            0.0,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
          );
        }
      }

      if (instant) {
        jump();
        Future.delayed(const Duration(milliseconds: 50), jump);
        Future.delayed(const Duration(milliseconds: 150), jump);
      } else {
        animate();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (sc.hasClients && sc.offset > 0.0) {
            sc.animateTo(
              0.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: GroupService.getGroupMessages(widget.groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.somethingWentWrong,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF0084FF),
              strokeWidth: 2,
            ),
          );
        }

        final allDocs = snapshot.data!.docs;
        var docs =
            allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final deletedBy = data['deletedBy'] as List<dynamic>?;
              return deletedBy == null || !deletedBy.contains(widget.senderID);
            }).toList();

        if (widget.searchQuery.isNotEmpty) {
          final q = widget.searchQuery.toLowerCase();
          docs =
              docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final raw = data['message'] as String? ?? '';
                final plain =
                    raw.startsWith('enc:')
                        ? EncryptionService.decrypt(raw)
                        : raw;
                return plain.toLowerCase().contains(q);
              }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noMessagesYet,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.sayHello,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),
              ],
            ),
          );
        }

        final latestId = docs.last.id;
        final isFirstLoad = _lastDocId == null;
        final isNew = latestId != _lastDocId;

        // Use reversed docs so `ListView` will naturally snap and anchor to the bottom.
        final reversedDocs = docs.reversed.toList();

        if (isNew) {
          _lastDocId = latestId;
          if (isFirstLoad) {
            _scrollToBottom(instant: true);
          } else {
            if (widget.scrollController.hasClients &&
                widget.scrollController.offset < 1000.0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom(instant: true);
              });
            }
          }
        }

        return ListView.builder(
          reverse: true,
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          itemCount: reversedDocs.length,
          itemBuilder: (context, index) {
            final doc = reversedDocs[index];
            return KeyedSubtree(
              key: ValueKey(doc.id),
              child: _buildItem(context, doc, index, reversedDocs),
            );
          },
        );
      },
    );
  }

  Widget _buildItem(
    BuildContext context,
    DocumentSnapshot doc,
    int index,
    List<DocumentSnapshot> docs,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final msg = Message.fromMap(data, docId: doc.id);
    final isMe = msg.senderID == widget.senderID;
    final ts = msg.timestamp.toDate();

    bool showDate =
        index ==
        docs.length - 1; // Since it's reversed, the oldest message has the date
    if (!showDate && index + 1 < docs.length) {
      final prev =
          (docs[index + 1].data()
              as Map<String, dynamic>); // chronologically older
      final prevTs = (prev['timestamp'] as Timestamp).toDate();
      if (ts.year != prevTs.year ||
          ts.month != prevTs.month ||
          ts.day != prevTs.day) {
        showDate = true;
      }
    }

    return StreamBuilder<UserProfile?>(
      stream: UserService.currentUserProfileStream(),
      builder: (context, currentSnap) {
        final myNicknames = currentSnap.data?.nicknames ?? {};
        return StreamBuilder<UserProfile?>(
          stream: UserService.getUserProfileStream(msg.senderID),
          builder: (context, snap) {
            final profile = snap.data;
            // Use current user's nickname for sender, else sender's own username
            final senderName =
                myNicknames.containsKey(msg.senderID)
                    ? myNicknames[msg.senderID]!
                    : (profile?.username ?? msg.senderEmail.split('@').first);

            Widget bubble = ChatBubble(
              messageId: doc.id,
              message: msg.message,
              isCurrentUser: isMe,
              isEdited: msg.isEdited,
              timestamp: ts,
              replyToMessage: msg.replyToMessage,
              replyToSenderEmail: msg.replyToSenderEmail,
              messageType: msg.messageType,
              fileUrl: msg.fileUrl,
              fileName: msg.fileName,
              fileSize: msg.fileSize,
              status: msg.status,
              isDeletedForEveryone: msg.isDeletedForEveryone,
              isForwarded: msg.isForwarded,
              reactions: msg.reactions,
              onReactionTap: (emoji) => GroupService.toggleGroupReaction(
                widget.groupId,
                doc.id,
                emoji,
              ),
              chatId: widget.groupId,
              onReply: () => widget.onReply(doc.id, msg.message, senderName),
              onEdit: () => widget.onEdit(doc.id, msg.message),
              onDelete:
                  () => widget.onDelete(doc.id, isMe, msg.isDeletedForEveryone),
              onSelectForDelete:
                  () => widget.onToggleSelection(
                    doc.id,
                    msg,
                    requestedMode: SelectionMode.delete,
                  ),
              onSelectForForward:
                  () => widget.onToggleSelection(
                    doc.id,
                    msg,
                    requestedMode: SelectionMode.forward,
                  ),
              isSelected: widget.selectedMessageIds.contains(doc.id),
              selectionMode: widget.selectionMode,
              onLongPress: () => widget.onToggleSelection(doc.id, msg),
              onTap: () => widget.onToggleSelection(doc.id, msg),
            );

            return Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showDate) _buildDateSeparator(context, ts),
                // Show sender name for others' messages in group
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2, top: 4),
                    child: Text(
                      senderName,
                      style: const TextStyle(
                        color: Color(0xFF0084FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: isMe ? 60 : 0,
                      right: isMe ? 0 : 60,
                      top: 4,
                      bottom: 4,
                    ),
                    child: bubble,
                  ),
                ),
              ],
            );
          }, // inner StreamBuilder builder
        ); // inner StreamBuilder
      }, // outer StreamBuilder builder
    ); // outer StreamBuilder
  }

  Widget _buildDateSeparator(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    String label;
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      label = AppLocalizations.of(context)!.today;
    } else if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day - 1) {
      label = AppLocalizations.of(context)!.yesterday;
    } else {
      label =
          '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300, height: 1)),
        ],
      ),
    );
  }
}

// ─── Group avatar widget ─────────────────────────────────────────
class _GroupAvatar extends StatelessWidget {
  final String? imageBase64;
  final double radius;

  const _GroupAvatar({this.imageBase64, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (imageBase64 != null && imageBase64!.startsWith('data:')) {
      try {
        final bytes = base64Decode(imageBase64!.split(',').last);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }
    return CircleAvatar(
      radius: radius,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(Icons.group_rounded, color: Colors.white, size: radius),
      ),
    );
  }
}

// ─── Group info bottom sheet ──────────────────────────────────────
class GroupInfoSheet extends StatefulWidget {
  final GroupChat group;
  final String currentUID;

  const GroupInfoSheet({
    super.key,
    required this.group,
    required this.currentUID,
  });

  @override
  State<GroupInfoSheet> createState() => _GroupInfoSheetState();
}

class _GroupInfoSheetState extends State<GroupInfoSheet> {
  // isAdmin is now computed from the LIVE group in the StreamBuilder,
  // not from widget.group (which is the initial snapshot).
  bool _editingName = false;
  late final _nameCtrl = TextEditingController(text: widget.group.name);
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    final base64String = await UserService.pickAndEncodeAvatar();
    if (base64String == null) return;
    final bytes = base64Decode(base64String);

    setState(() => _saving = true);
    await GroupService.updateGroup(widget.group.id, imageBytes: bytes);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickWallpaper() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'wallpaper_${widget.group.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallpaper_${widget.group.id}', savedImage.path);
      if (mounted) Navigator.pop(context, 'wallpaper_changed');
    }
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await GroupService.updateGroup(widget.group.id, name: name);
    if (mounted) {
      setState(() {
        _saving = false;
        _editingName = false;
      });
    }
  }

  Future<void> _removeMember(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.removeMember),
            content: Text(
              AppLocalizations.of(context)!.removeMemberDescription,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  AppLocalizations.of(context)!.remove,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (ok == true) {
      await GroupService.removeMember(widget.group.id, uid);
    }
  }

  Future<void> _leaveGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.leaveGroupConfirm),
            content: Text(AppLocalizations.of(context)!.leaveGroupDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  AppLocalizations.of(context)!.leave,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (ok == true) {
      await GroupService.leaveGroup(widget.group.id);
      if (mounted) Navigator.pop(context, 'left');
    }
  }

  Future<void> _promoteToAdmin(String uid) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.promoteToAdmin),
            content: Text(
              AppLocalizations.of(context)!.promoteToAdminDescription,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context)!.promote),
              ),
            ],
          ),
    );
    if (ok == true) {
      await GroupService.updateAdmin(widget.group.id, uid);
    }
  }

  Future<void> _showInviteDialog() async {
    // Show a simple search dialog to pick a user
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _InviteSheet(
            theme: Theme.of(context),
            existingMemberUIDs: widget.group.memberUIDs,
          ),
    );

    if (result != null && mounted) {
      await GroupService.addMembers(widget.group.id, [result]);
    }
  }

  Future<void> _deleteGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.deleteGroupConfirm),
            content: Text(AppLocalizations.of(context)!.deleteGroupDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  AppLocalizations.of(context)!.deleteGroupEveryone,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
    if (ok == true) {
      await GroupService.deleteGroup(widget.group.id);
      if (mounted) Navigator.pop(context, 'deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF8F9FA);
    final surface = isDark ? const Color(0xFF242536) : Colors.white;

    return StreamBuilder<DocumentSnapshot>(
      stream: GroupService.getGroupStream(widget.group.id),
      builder: (context, snap) {
        final group =
            snap.hasData && snap.data!.exists
                ? GroupChat.fromMap(
                  snap.data!.data() as Map<String, dynamic>,
                  widget.group.id,
                )
                : widget.group;

        // Compute isAdmin from the LIVE group, not the stale widget.group.
        // This ensures that when admin rights are transferred, the new admin
        // immediately sees all management options without re-opening the sheet.
        final isAdmin = group.adminUID == widget.currentUID;

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  // Header
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        // Group image
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildGroupHeaderImage(group),
                            if (isAdmin)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: _saving ? null : _pickNewImage,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0084FF),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Group name
                        if (_editingName && isAdmin)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  autofocus: true,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                  decoration: const InputDecoration(
                                    border: UnderlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.check_rounded,
                                  color: Color(0xFF0084FF),
                                ),
                                onPressed: _saving ? null : _saveName,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed:
                                    () => setState(() => _editingName = false),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                group.name,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap:
                                      () => setState(() => _editingName = true),
                                  child: Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        const SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.groupChatMembers(group.memberUIDs.length),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Members list header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.members,
                          style: const TextStyle(
                            color: Color(0xFF0084FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        if (isAdmin)
                          IconButton(
                            onPressed: _showInviteDialog,
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Color(0xFF0084FF),
                              size: 18,
                            ),
                            tooltip:
                                AppLocalizations.of(context)!.inviteMembers,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Members list
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ListView.separated(
                          controller: scrollCtrl,
                          itemCount: group.memberUIDs.length,
                          separatorBuilder:
                              (_, __) => Divider(
                                height: 1,
                                indent: 72,
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                          itemBuilder: (context, i) {
                            final uid = group.memberUIDs[i];
                            return _MemberTile(
                              uid: uid,
                              isAdmin: uid == group.adminUID,
                              canRemove: isAdmin && uid != widget.currentUID,
                              onRemove: () => _removeMember(uid),
                              onPromote:
                                  isAdmin && uid != widget.currentUID
                                      ? () => _promoteToAdmin(uid)
                                      : null,
                              theme: theme,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        _ActionButton(
                          label: 'Set Wallpaper',
                          icon: Icons.wallpaper_rounded,
                          color: theme.colorScheme.primary,
                          onTap: _pickWallpaper,
                          surface: surface,
                        ),
                        if (!isAdmin)
                          _ActionButton(
                            label: AppLocalizations.of(context)!.leaveGroup,
                            icon: Icons.exit_to_app_rounded,
                            color: Colors.red.shade400,
                            onTap: _leaveGroup,
                            surface: surface,
                          ),
                        if (isAdmin) ...[
                          _ActionButton(
                            label:
                                AppLocalizations.of(
                                  context,
                                )!.deleteGroupEveryone,
                            icon: Icons.delete_forever_rounded,
                            color: Colors.red.shade400,
                            onTap: _deleteGroup,
                            surface: surface,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupHeaderImage(GroupChat group) {
    if (group.imageBase64 != null && group.imageBase64!.startsWith('data:')) {
      try {
        final bytes = base64Decode(group.imageBase64!.split(',').last);
        return CircleAvatar(radius: 52, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    return Container(
      width: 104,
      height: 104,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.group_rounded, color: Colors.white, size: 52),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String uid;
  final bool isAdmin;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback? onPromote;
  final ThemeData theme;

  const _MemberTile({
    required this.uid,
    required this.isAdmin,
    required this.canRemove,
    required this.onRemove,
    this.onPromote,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserService.getUserProfileStream(uid),
      builder: (context, snap) {
        final profile = snap.data;
        final name = profile?.username ?? '…';
        final email = profile?.email ?? '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: UserAvatar(
            displayName: name,
            avatarBase64: profile?.avatarBase64,
            radius: 22,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0084FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.admin,
                    style: const TextStyle(
                      color: Color(0xFF0084FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            email,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onPromote != null)
                IconButton(
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF0084FF),
                    size: 20,
                  ),
                  tooltip: AppLocalizations.of(context)!.makeAdmin,
                  onPressed: onPromote,
                ),
              if (canRemove)
                IconButton(
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: onRemove,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final Color surface;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  final ThemeData theme;
  final List<String> existingMemberUIDs;

  const _InviteSheet({required this.theme, required this.existingMemberUIDs});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final TextEditingController _queryController = TextEditingController();
  List<UserProfile> _results = [];
  bool _loading = false;

  void _onSearch(String val) async {
    if (val.trim().isEmpty) {
      if (mounted) setState(() => _results = []);
      return;
    }
    if (mounted) setState(() => _loading = true);
    final users = await UserService.searchUsers(val);
    if (mounted) {
      setState(() {
        _results =
            users
                .where((u) => !widget.existingMemberUIDs.contains(u.uid))
                .toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.theme.brightness == Brightness.dark;
    final surface = isDark ? Colors.grey.shade900 : Colors.white;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context)!.inviteMembers,
                style: TextStyle(
                  color: widget.theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _queryController,
            onChanged: _onSearch,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchByUsernameOrEmail,
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                    ? Center(
                      child: Text(
                        _queryController.text.isEmpty
                            ? AppLocalizations.of(context)!.typeToSearch
                            : AppLocalizations.of(context)!.noResults,
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final u = _results[i];
                        return ListTile(
                          leading: UserAvatar(
                            displayName: u.username,
                            avatarBase64: u.avatarBase64,
                            radius: 20,
                          ),
                          title: Text(u.username),
                          subtitle: Text(u.email),
                          onTap: () => Navigator.pop(context, u.uid),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
