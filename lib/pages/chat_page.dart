import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:googlechat/components/chat_bubble.dart';
import 'package:googlechat/components/user_avatar.dart';
import 'package:googlechat/models/message.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    hide
        EmojiViewConfig,
        CategoryViewConfig,
        SearchViewConfig,
        BottomActionBarConfig,
        SkinToneConfig;
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/pages/home_page.dart';
import 'package:googlechat/services/auth/auth_service.dart';
import 'package:googlechat/services/chat/chat_service.dart';
import 'package:googlechat/services/chat/encryption_service.dart';
import 'package:googlechat/services/chat/media_service.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:intl/intl.dart';

import 'package:googlechat/l10n/app_localizations.dart';

import 'package:googlechat/services/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  final String receiverEmail;
  final String receiverID;
  final String? initialText;
  final List<dynamic>? initialFiles;

  const ChatPage({
    super.key,
    required this.receiverEmail,
    required this.receiverID,
    this.initialText,
    this.initialFiles,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _editController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String _currentUserName = 'You';
  String _receiverName = '';

  final ValueNotifier<bool> _isComposing = ValueNotifier(false);

  // Reply state
  String? _replyToMessageId;
  String? _replyToMessage;
  String? _replyToSenderEmail;

  // Selection state
  final Set<String> _selectedMessageIds = {};
  final List<Message> _selectedMessages = [];
  SelectionMode _selectionMode = SelectionMode.none;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _showEmojiPicker = false;
  bool _isRecording = false;
  double _recordingDragOffset = 0;
  bool _isCancelingRecording = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  File? _wallpaperImage;

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('wallpaper_${widget.receiverID}');
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists() && mounted) {
        setState(() => _wallpaperImage = file);
      }
    }
  }

  Future<void> _pickWallpaper() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'wallpaper_${widget.receiverID}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(
        image.path,
      ).copy('${appDir.path}/$fileName');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallpaper_${widget.receiverID}', savedImage.path);
      if (mounted) setState(() => _wallpaperImage = savedImage);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWallpaper();
    _receiverName = widget.receiverEmail.split('@').first;

    UserService.currentUserProfileStream().listen((profile) {
      if (mounted && profile?.username != null) {
        if (_currentUserName != profile!.username) {
          setState(() => _currentUserName = profile.username);
        }
      }
    });

    UserService.getUserProfileStream(widget.receiverID).listen((profile) {
      if (mounted && profile != null) {
        if (_receiverName != profile.username) {
          setState(() => _receiverName = profile.username);
        }
      }
    });

    WidgetsBinding.instance.addObserver(this);
    _chatService.markMessagesAsSeen(widget.receiverID);
    // Dismiss any active notifications now that the user opened this chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.clearAllNotifications();
    });
    _messageController.addListener(() {
      _isComposing.value = _messageController.text.trim().isNotEmpty;
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showEmojiPicker = false);
        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
      }
    });

    // Handle shared content
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialText != null) {
        _messageController.text = widget.initialText!;
      }
      if (widget.initialFiles != null && widget.initialFiles!.isNotEmpty) {
        _handleSharedFiles(widget.initialFiles!);
      }
    });

    // Scroll to bottom after first build
    Future.delayed(const Duration(milliseconds: 500), _scrollToBottom);
    _setupMessageListener();
  }

  Future<void> _handleSharedFiles(List<dynamic> files) async {
    for (var file in files) {
      // Files may be passed as Map<String,String> with 'path' and 'type' keys
      // (from ShareService) or as raw file paths (String).
      String? path;
      MessageType type = MessageType.file;
      if (file is Map) {
        path = file['path'] as String?;
        final t = file['type'] as String?;
        if (t == 'image') type = MessageType.image;
        if (t == 'video') type = MessageType.video;
      } else if (file is String) {
        path = file;
        final lower = path.toLowerCase();
        if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
            lower.endsWith('.png') || lower.endsWith('.gif') ||
            lower.endsWith('.webp')) {
          type = MessageType.image;
        } else if (lower.endsWith('.mp4') || lower.endsWith('.mov') ||
            lower.endsWith('.avi') || lower.endsWith('.mkv')) {
          type = MessageType.video;
        }
      }
      if (path != null && path.isNotEmpty) {
        await _sendSharedFile(path, path.split('/').last, type);
      }
    }
  }

  Future<void> _sendSharedFile(
    String path,
    String name,
    MessageType type,
  ) async {
    setState(() => _isUploading = true);
    _scrollToBottom();
    try {
      final f = File(path);
      final bytes = await f.readAsBytes();
      final size = _formatBytes(bytes.length);
      final url = await _chatService.uploadFile(
        bytes: bytes,
        fileName: name,
        type: type,
        isHD: true,
      );

      final docRef = await _chatService.sendMessage(
        widget.receiverID,
        'enc:',
        messageType: type,
        fileUrl: url,
        fileName: name,
        fileSize: size,
      );

      // Pre-register path for immediate display
      await MediaService.preRegisterSenderPath(
        messageId: docRef.id,
        tempPath: path,
      );
      MediaService.saveSenderMedia(
        messageId: docRef.id,
        fileName: name,
        tempPath: path,
        type: type,
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _messageController.dispose();
    _editController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _isComposing.dispose();
    _audioRecorder.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _chatService.markMessagesAsSeen(widget.receiverID);
      _chatService.markMessagesAsDelivered();
    }
  }

  StreamSubscription? _messageSubscription;

  void _setupMessageListener() {
    final senderID = _authService.getCurrentUser()?.uid;
    if (senderID == null) return;

    _messageSubscription = _chatService
        .getMessages(widget.receiverID, senderID)
        .listen((snapshot) {
          if (mounted) {
            if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed) {
              _chatService.markMessagesAsSeen(widget.receiverID);
            }
          }
        });
  }

  void _scrollToBottom() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─ Typing indicator ──────────────────────────────────────────────────
  Timer? _typingTimer;

  void _onTypingChanged(String val) {
    _isComposing.value = val.trim().isNotEmpty;
    _setTypingStatus(true);
    _typingTimer?.cancel();
    _typingTimer = Timer(
      const Duration(seconds: 3),
      () => _setTypingStatus(false),
    );
  }

  void _setTypingStatus(bool isTyping) {
    final uid = _authService.getCurrentUser()?.uid;
    if (uid == null) return;
    final ids = [uid, widget.receiverID]..sort();
    final chatRoomId = ids.join('_');
    FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .set({'typing_$uid': isTyping}, SetOptions(merge: true))
        .catchError((_) {});
  }

  Stream<bool> _remoteTypingStream() {
    final uid = _authService.getCurrentUser()?.uid ?? '';
    final ids = [uid, widget.receiverID]..sort();
    final chatRoomId = ids.join('_');
    return FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(chatRoomId)
        .snapshots()
        .map((snap) => snap.data()?['typing_${widget.receiverID}'] == true);
  }

  void _toggleSelection(
    String id,
    Message message, {
    SelectionMode? requestedMode,
  }) {
    setState(() {
      if (_selectedMessageIds.isEmpty && requestedMode != null) {
        _selectionMode = requestedMode;
      }

      if (_selectedMessageIds.contains(id)) {
        _selectedMessageIds.remove(id);
        _selectedMessages.removeWhere((m) => m.id == id);
      } else {
        _selectedMessageIds.add(id);
        _selectedMessages.add(message);
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
          await _chatService.deleteMessage(widget.receiverID, msgId);
        } else {
          await _chatService.deleteMessageForMe(widget.receiverID, msgId);
        }
      }
      _clearSelection();
    }
  }

  void _handleForwardSelected() {
    final messagesToForward = List<Message>.from(_selectedMessages);
    // Sort chronologically
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
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyId = _replyToMessageId;
    final replyMsg = _replyToMessage;
    final replySender = _replyToSenderEmail;

    _messageController.clear();
    _clearReply();
    _setTypingStatus(false);

    await _chatService.sendMessage(
      widget.receiverID,
      text,
      replyToMessageId: replyId,
      replyToMessage: replyMsg,
      replyToSenderEmail: replySender,
    );
  }

  void _clearReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToMessage = null;
      _replyToSenderEmail = null;
    });
  }

  void _setReply(String messageId, String message, String senderEmail) {
    setState(() {
      _replyToMessageId = messageId;
      _replyToMessage = message;
      _replyToSenderEmail = senderEmail;
    });
    _focusNode.requestFocus();
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      _focusNode.requestFocus();
      setState(() => _showEmojiPicker = false);
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
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
      _uploadAndSend(
        bytes,
        image.name,
        MessageType.image,
        localFilePath: image.path,
      );
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
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (image != null) {
      _editAndSendImage(image, isHD: true);
    }
  }

  Future<void> _editAndSendImage(XFile imageFile, {bool isHD = false}) async {
    final editedBytes = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProImageEditor.file(
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
      _uploadAndSend(
        editedBytes,
        imageFile.name,
        MessageType.image,
        isHD: isHD,
        localFilePath: imageFile.path,
      );
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final bytes = await video.readAsBytes();
      _uploadAndSend(
        bytes,
        video.name,
        MessageType.video,
        localFilePath: video.path,
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      final platformFile = result.files.single;
      Uint8List? bytes = platformFile.bytes;
      if (bytes == null && platformFile.path != null) {
        bytes = await File(platformFile.path!).readAsBytes();
      }
      if (bytes != null) {
        _uploadAndSend(
          bytes,
          platformFile.name,
          MessageType.file,
          localFilePath: platformFile.path,
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? recordingPath;
        if (!foundation.kIsWeb) {
          final tempDir = await getTemporaryDirectory();
          recordingPath =
              '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        const config = RecordConfig();
        await _audioRecorder.start(config, path: recordingPath ?? '');
        setState(() {
          _isRecording = true;
          _showEmojiPicker = false;
          _recordingDragOffset = 0;
          _isCancelingRecording = false;
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    try {
      final path = await _audioRecorder.stop();
      if (cancel) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording failed: no file path')));
        return;
      }
      Uint8List bytes;
      if (foundation.kIsWeb) {
        final response = await Dio().get(
          path,
          options: Options(responseType: ResponseType.bytes),
        );
        bytes = Uint8List.fromList(response.data);
      } else {
        final file = File(path);
        if (!await file.exists()) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording error: file not found')));
          return;
        }
        bytes = await file.readAsBytes();
      }
      _uploadAndSend(
        bytes,
        'voice_message.m4a',
        MessageType.audio,
        localFilePath: path,
      );
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recording error: $e')));
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _uploadAndSend(
    Uint8List bytes,
    String fileName,
    MessageType type, {
    bool isHD = false,
    String? localFilePath,
  }) async {
    _scrollToBottom();
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sending attachment...'), duration: Duration(seconds: 1)),
      );
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
      final sizeStr = _formatBytes(bytes.length);
      final docRef = await _chatService.sendMessage(
        widget.receiverID,
        type == MessageType.image
            ? (isHD ? '🖼️ HD Photo' : '📷 Photo')
            : (type == MessageType.video
                ? '🎥 Video'
                : (type == MessageType.audio
                    ? '🎤 Voice Message'
                    : '📁 $fileName')),
        messageType: type,
        fileUrl: url,
        fileName: fileName,
        fileSize: sizeStr,
        replyToMessageId: _replyToMessageId,
        replyToMessage: _replyToMessage,
        replyToSenderEmail: _replyToSenderEmail,
      );
      if (localFilePath != null && localFilePath.isNotEmpty) {
        await MediaService.preRegisterSenderPath(
          messageId: docRef.id,
          tempPath: localFilePath,
        );
        // Also save a permanent copy so the sender can still display the media
        // after Firebase Storage deletes the original (group chats).
        MediaService.saveSenderMedia(
          messageId: docRef.id,
          fileName: fileName,
          tempPath: localFilePath,
          type: type,
        ).ignore();
      }
      _clearReply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e'), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    double size = bytes.toDouble();
    int index = 0;
    while (size >= 1024 && index < suffixes.length - 1) {
      size /= 1024;
      index++;
    }
    return "${size.toStringAsFixed(1)} ${suffixes[index]}";
  }

  Future<void> _showEditDialog(String messageId, String currentText) async {
    _editController.text = currentText;
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Edit Message',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: _editController,
              autofocus: true,
              maxLines: null,
              decoration: InputDecoration(
                hintText: 'Edit your message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newText = _editController.text.trim();
                  if (newText.isNotEmpty && newText != currentText) {
                    await _chatService.editMessage(
                      widget.receiverID,
                      messageId,
                      newText,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0084FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _showDeleteDialog(
    String messageId,
    bool isCurrentUser,
    bool isDeletedForEveryone,
  ) async {
    if (isDeletedForEveryone) {
      await _chatService.deleteMessageForMe(widget.receiverID, messageId);
      return;
    }
    await showModalBottomSheet(
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
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete for me'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _chatService.deleteMessageForMe(
                      widget.receiverID,
                      messageId,
                    );
                  },
                ),
                if (isCurrentUser)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Delete for everyone',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _chatService.deleteMessage(
                        widget.receiverID,
                        messageId,
                      );
                    },
                  ),
              ],
            ),
          ),
    );
  }

  // Calls feature removed — Zego SDK stripped from this build.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUID = _authService.getCurrentUser()?.uid ?? '';
    final allSelectedAreMine = _selectedMessages.every(
      (m) => m.senderID == currentUID,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        leading:
            _selectionMode != SelectionMode.none
                ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSelection,
                )
                : IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
        titleSpacing: 0,
        title:
            _selectionMode != SelectionMode.none
                ? Text(
                  '${_selectedMessageIds.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                )
                : (_isSearching
                    ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Search messages...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    )
                    : StreamBuilder<UserProfile?>(
                      stream: UserService.currentUserProfileStream(),
                      builder: (context, currentUserSnap) {
                        final nicknames = currentUserSnap.data?.nicknames ?? {};
                        return StreamBuilder<UserProfile?>(
                          stream: UserService.getUserProfileStream(
                            widget.receiverID,
                          ),
                          builder: (context, profileSnap) {
                            final profile = profileSnap.data;
                            final originalUsername =
                                profile?.username ??
                                widget.receiverEmail.split('@').first;
                            final nickname = nicknames[widget.receiverID];
                            final displayName =
                                (nickname != null && nickname.isNotEmpty)
                                    ? nickname
                                    : originalUsername;
                            final avatarBase64 = profile?.avatarBase64;
                            final statusText = profile?.status ?? '';

                            return StreamBuilder<
                              ({bool isOnline, DateTime? lastActive})
                            >(
                              stream: UserService.getUserPresenceStream(
                                widget.receiverID,
                              ),
                              builder: (context, presenceSnap) {
                                final l10n = AppLocalizations.of(context)!;
                                final presence = presenceSnap.data;
                                final bool isOnline =
                                    presence?.isOnline == true;
                                final DateTime? lastActive =
                                    presence?.lastActive;

                                String subtitleText =
                                    isOnline
                                        ? l10n.online
                                        : (lastActive != null
                                            ? '${l10n.wasActive} ${_formatLastActive(Timestamp.fromDate(lastActive))}'
                                            : (statusText.isNotEmpty
                                                ? statusText
                                                : l10n.offline));

                                return StreamBuilder<bool>(
                                  stream: _remoteTypingStream(),
                                  builder: (context, typingSnap) {
                                    final isTyping = typingSnap.data == true;
                                    final subtitleFinal =
                                        isTyping ? l10n.typing : subtitleText;
                                    final subtitleColor =
                                        isTyping
                                            ? const Color(0xFF0084FF)
                                            : (isOnline
                                                ? Colors.green.shade400
                                                : Colors.grey.shade500);
                                    return GestureDetector(
                                      onTap:
                                          () => _showUserDetails(
                                            context,
                                            displayName,
                                            originalUsername,
                                            statusText,
                                            widget.receiverEmail,
                                            avatarBase64,
                                          ),
                                      child: Row(
                                        children: [
                                          Stack(
                                            children: [
                                              UserAvatar(
                                                displayName: displayName,
                                                avatarBase64: avatarBase64,
                                                radius: 20,
                                              ),
                                              if (isOnline)
                                                Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.green.shade400,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color:
                                                            theme
                                                                .scaffoldBackgroundColor,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  displayName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color:
                                                        theme
                                                            .colorScheme
                                                            .onSurface,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                AnimatedSwitcher(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  child: Text(
                                                    subtitleFinal,
                                                    key: ValueKey(
                                                      subtitleFinal,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: subtitleColor,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    )),
        actions:
            _selectionMode != SelectionMode.none
                ? [
                  if (_selectionMode == SelectionMode.forward)
                    IconButton(
                      icon: const Icon(Icons.forward_to_inbox_rounded),
                      onPressed: _handleForwardSelected,
                    )
                  else ...[
                    if (allSelectedAreMine) ...[
                      // Red trash = delete for everyone
                      IconButton(
                        icon: const Icon(
                          Icons.delete_rounded,
                          color: Colors.red,
                        ),
                        tooltip:
                            AppLocalizations.of(context)!.deleteForEveryoneTip,
                        onPressed: () => _handleDeleteSelected(true),
                      ),
                    ],
                    // White/outline trash = delete for me
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      tooltip: AppLocalizations.of(context)!.deleteForMeTip,
                      onPressed: () => _handleDeleteSelected(false),
                    ),
                  ],
                ]
                : [
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        if (_isSearching) {
                          _isSearching = false;
                          _searchQuery = '';
                          _searchController.clear();
                        } else {
                          _isSearching = true;
                        }
                      });
                    },
                  ),
                  if (!_isSearching) const SizedBox(width: 4),
                ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: theme.colorScheme.outline.withOpacity(0.25),
          ),
        ),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: UserService.currentUserProfileStream(),
        builder: (context, currentUserSnap) {
          final l10n = AppLocalizations.of(context)!;
          final currentUser = currentUserSnap.data;
          final currentUID = currentUser?.uid ?? '';
          return StreamBuilder<UserProfile?>(
            stream: UserService.getUserProfileStream(widget.receiverID),
            builder: (context, receiverSnap) {
              final receiver = receiverSnap.data;
              final blockedByThem =
                  receiver?.blockedUsers.contains(currentUID) ?? false;
              final blockedByMe =
                  currentUser?.blockedUsers.contains(widget.receiverID) ??
                  false;
              final isBlocked = blockedByThem || blockedByMe;

              return Stack(
                children: [
                  if (_wallpaperImage != null)
                    Positioned.fill(
                      child: Image.file(
                        _wallpaperImage!,
                        fit: BoxFit.cover,
                        color:
                            isDark
                                ? Colors.black.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.6),
                        colorBlendMode:
                            isDark ? BlendMode.darken : BlendMode.lighten,
                      ),
                    ),
                  Column(
                    children: [
                      if (blockedByMe && !blockedByThem)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          color: Colors.red.shade50.withOpacity(0.8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.block_rounded,
                                size: 16,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.youBlockedUser,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed:
                                    () => UserService.toggleBlockUser(
                                      widget.receiverID,
                                      false,
                                    ),
                                child: Text(l10n.unblock),
                              ),
                            ],
                          ),
                        ),
                      if (blockedByThem)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: Colors.orange.shade50,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.block_rounded,
                                size: 16,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.youAreBlocked,
                                style: TextStyle(
                                  color: Colors.orange.shade800,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: _MessageList(
                          senderID: currentUID,
                          senderName: _currentUserName,
                          chatService: _chatService,
                          receiverID: widget.receiverID,
                          receiverName: _receiverName,
                          searchQuery: _searchQuery,
                          scrollController: _scrollController,
                          onReply: _setReply,
                          onEdit: (id, text) async {
                            setState(() {
                              _editController.text = text;
                            });
                            _showEditDialog(id, text);
                          },
                          onDelete: (
                            id,
                            isCurrentUser,
                            isDeletedForEveryone,
                          ) async {
                            _showDeleteDialog(
                              id,
                              isCurrentUser,
                              isDeletedForEveryone,
                            );
                          },
                          selectedMessageIds: _selectedMessageIds,
                          selectionMode: _selectionMode,
                          onToggleSelection: _toggleSelection,
                        ),
                      ),
                      if (_replyToMessage != null) _buildReplyPreview(theme),
                      if (_isUploading)
                        LinearProgressIndicator(
                          value: _uploadProgress > 0 ? _uploadProgress : null,
                        ),
                      SafeArea(
                        bottom: true,
                        child: IgnorePointer(
                          ignoring: isBlocked,
                          child: Opacity(
                            opacity: isBlocked ? 0.5 : 1.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildInputBar(theme, isDark),
                                if (_showEmojiPicker) _buildEmojiPicker(isDark),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildReplyPreview(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final displaySender = _replyToSenderEmail ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withOpacity(0.5),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
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
                  l10n.replyingTo(displaySender),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToMessage!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: _clearReply,
            color: Colors.grey,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      color: Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child:
                _isRecording
                    ? _buildRecordingStatus(theme)
                    : _buildWhatsAppTextField(theme, isDark),
          ),
          const SizedBox(width: 8),
          _buildMicOrSendButton(theme),
        ],
      ),
    );
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

  Widget _buildWhatsAppTextField(ThemeData theme, bool isDark) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              _showEmojiPicker
                  ? Icons.keyboard_rounded
                  : Icons.emoji_emotions_outlined,
              color: Colors.grey.shade600,
              size: 24,
            ),
            onPressed: _toggleEmojiPicker,
            constraints: const BoxConstraints(minWidth: 40),
            splashRadius: 20,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.messageHint,
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: _onTypingChanged,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.attach_file_rounded,
              color: Colors.grey.shade600,
              size: 24,
            ),
            onPressed: _showAttachmentMenu,
            constraints: const BoxConstraints(minWidth: 40),
            splashRadius: 20,
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isComposing,
            builder: (context, isComposing, child) {
              if (isComposing) return const SizedBox.shrink();
              return IconButton(
                padding: const EdgeInsets.only(right: 4),
                icon: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.grey.shade600,
                  size: 24,
                ),
                onPressed: _takePhoto,
                constraints: const BoxConstraints(minWidth: 40),
                splashRadius: 20,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingStatus(ThemeData theme) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:
            _isCancelingRecording
                ? Colors.red.withOpacity(0.1)
                : (theme.brightness == Brightness.dark
                    ? const Color(0xFF2C2C2C)
                    : Colors.white),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return Text(
                  _isCancelingRecording ? l10n.cancel : 'Recording...',
                  style: TextStyle(
                    color:
                        _isCancelingRecording
                            ? Colors.red
                            : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicOrSendButton(ThemeData theme) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isComposing,
      builder: (_, composing, __) {
        if (composing && !_isRecording) {
          return GestureDetector(
            onTap: () {
              _sendMessage();
              _scrollToBottom();
            },
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          );
        }
        return GestureDetector(
          onLongPressStart: (_) => _startRecording(),
          onLongPressMoveUpdate: (details) {
            setState(() {
              _recordingDragOffset = details.localPosition.dy;
              _isCancelingRecording = _recordingDragOffset < -80;
            });
          },
          onLongPressEnd: (_) {
            _stopRecording(cancel: _isCancelingRecording);
            _scrollToBottom();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              gradient:
                  _isRecording
                      ? null
                      : const LinearGradient(
                        colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              color: _isRecording ? Colors.red : null,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmojiPicker(bool isDark) {
    return SizedBox(
      height: 280,
      child: EmojiPicker(
        textEditingController: _messageController,
        onEmojiSelected: (_, __) {},
        config: Config(
          height: 280,
          emojiViewConfig: EmojiViewConfig(
            backgroundColor:
                isDark ? const Color(0xFF242526) : const Color(0xFFF8F9FA),
            emojiSizeMax:
                28 *
                (foundation.defaultTargetPlatform == TargetPlatform.iOS
                    ? 1.2
                    : 1.0),
          ),
          categoryViewConfig: CategoryViewConfig(
            backgroundColor:
                isDark ? const Color(0xFF242526) : const Color(0xFFF0F2F5),
            iconColorSelected: const Color(0xFF0084FF),
            indicatorColor: const Color(0xFF0084FF),
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: isDark ? const Color(0xFF3A3B3C) : Colors.white,
            buttonIconColor: const Color(0xFF0084FF),
          ),
          skinToneConfig: const SkinToneConfig(),
          bottomActionBarConfig: BottomActionBarConfig(
            backgroundColor:
                isDark ? const Color(0xFF242526) : const Color(0xFFF0F2F5),
            buttonIconColor: const Color(0xFF0084FF),
          ),
        ),
      ),
    );
  }

  void _showUserDetails(
    BuildContext context,
    String displayName,
    String originalUsername,
    String status,
    String email,
    String? avatarBase64,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            shape: BoxShape.circle,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              if (avatarBase64 != null &&
                                  avatarBase64.isNotEmpty) {
                                _showFullAvatar(
                                  context,
                                  avatarBase64,
                                  displayName,
                                );
                              }
                            },
                            child: UserAvatar(
                              displayName: displayName,
                              avatarBase64: avatarBase64,
                              radius: 50,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (displayName != originalUsername)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.usernameLabel(originalUsername),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  status.isNotEmpty
                      ? status
                      : AppLocalizations.of(context)!.statusAvailable,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Divider(),
                ),
                ListTile(
                  leading: const Icon(Icons.wallpaper_rounded),
                  title: const Text('Set Wallpaper'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickWallpaper();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(AppLocalizations.of(context)!.emailLabel),
                  subtitle: Text(email),
                ),
                StreamBuilder<UserProfile?>(
                  stream: UserService.currentUserProfileStream(),
                  builder: (context, currentUserSnap) {
                    final currentUser = currentUserSnap.data;
                    final isBlocked =
                        currentUser?.blockedUsers.contains(widget.receiverID) ??
                        false;
                    return Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.edit_note_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.setNickname,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showSetNicknameDialog(
                              context,
                              originalUsername,
                              displayName,
                            );
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            isBlocked
                                ? Icons.check_circle_outline_rounded
                                : Icons.block_rounded,
                            color: Colors.red.shade400,
                          ),
                          title: Text(
                            isBlocked
                                ? AppLocalizations.of(context)!.unblock
                                : AppLocalizations.of(context)!.blockUser,
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () {
                            UserService.toggleBlockUser(
                              widget.receiverID,
                              !isBlocked,
                            );
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.orange.shade700,
                          ),
                          title: Text(
                            AppLocalizations.of(context)!.deleteChatLabel,
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder:
                                  (_) => AlertDialog(
                                    title: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.deleteChatTitle,
                                    ),
                                    content: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.deleteChatContent,
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
                                        onPressed:
                                            () => Navigator.pop(context, true),
                                        child: Text(
                                          AppLocalizations.of(context)!.remove,
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                            );
                            if (ok == true && context.mounted) {
                              _chatService.hideChat(widget.receiverID);
                              Navigator.pop(context);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );
  }

  void _showSetNicknameDialog(
    BuildContext context,
    String originalUsername,
    String currentDisplay,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController(
          text: currentDisplay == originalUsername ? '' : currentDisplay,
        );
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.setNickname),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.nicknameHint,
              labelText: AppLocalizations.of(context)!.nickname,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                await UserService.setNickname(widget.receiverID, ctrl.text);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.save),
            ),
          ],
        );
      },
    );
  }

  void _showFullAvatar(
    BuildContext context,
    String base64String,
    String displayName,
  ) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                InteractiveViewer(
                  clipBehavior: Clip.none,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(
                      base64Decode(base64String),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  String _formatLastActive(Timestamp timestamp) {
    DateTime lastActive = timestamp.toDate();
    DateTime now = DateTime.now();
    if (lastActive.year == now.year &&
        lastActive.month == now.month &&
        lastActive.day == now.day) {
      return 'в ${DateFormat('HH:mm').format(lastActive)}';
    }
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (lastActive.year == yesterday.year &&
        lastActive.month == yesterday.month &&
        lastActive.day == yesterday.day) {
      return 'вчера в ${DateFormat('HH:mm').format(lastActive)}';
    }
    return '${DateFormat('dd.MM.yy').format(lastActive)} в ${DateFormat('HH:mm').format(lastActive)}';
  }
}

class _MessageList extends StatefulWidget {
  final String senderID;
  final String senderName;
  final ChatService chatService;
  final String receiverID;
  final String receiverName;
  final String searchQuery;
  final ScrollController scrollController;
  final void Function(String, String, String) onReply;
  final Future<void> Function(String, String) onEdit;
  final Future<void> Function(String, bool, bool) onDelete;
  final Set<String> selectedMessageIds;
  final SelectionMode selectionMode;
  final void Function(String, Message, {SelectionMode? requestedMode})
  onToggleSelection;

  const _MessageList({
    required this.senderID,
    required this.senderName,
    required this.chatService,
    required this.receiverID,
    required this.receiverName,
    required this.searchQuery,
    required this.scrollController,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.selectedMessageIds,
    required this.selectionMode,
    required this.onToggleSelection,
  });

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  String? _lastDocId;
  late Stream<QuerySnapshot> _messagesStream;

  /// True when the user has scrolled away from the bottom.
  /// Auto-scroll is completely suppressed while this is true.
  bool _isUserScrolledUp = false;

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;
    final offset = widget.scrollController.offset;
    // reverse: true list — offset 0 = bottom, large offset = older messages
    final scrolledUp = offset > 1000.0;
    if (scrolledUp != _isUserScrolledUp) {
      _isUserScrolledUp = scrolledUp;
    }
  }

  @override
  void initState() {
    super.initState();
    _messagesStream = widget.chatService.getMessages(
      widget.receiverID,
      widget.senderID,
    );
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiverID != widget.receiverID ||
        oldWidget.senderID != widget.senderID) {
      _messagesStream = widget.chatService.getMessages(
        widget.receiverID,
        widget.senderID,
      );
    }
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _scrollToBottom({bool instant = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.scrollController.hasClients) return;
      final sc = widget.scrollController;
      if (!sc.position.hasContentDimensions) return;

      if (instant) {
        sc.jumpTo(0.0);
      } else {
        sc.animateTo(
          0.0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Something went wrong',
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
                final raw =
                    (doc.data() as Map<String, dynamic>)['message']
                        as String? ??
                    '';
                // Decrypt before searching
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
                  Icons.chat_bubble_outline_rounded,
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
        final isNewMessage = latestId != _lastDocId;

        // Create reversed list for native bottom anchoring
        final reversedDocs = docs.reversed.toList();

        if (isNewMessage) {
          _lastDocId = latestId;
          if (isFirstLoad) {
            // First load: jump after layout so images have a frame to measure
            Future.delayed(const Duration(milliseconds: 150), () {
              if (widget.scrollController.hasClients) {
                widget.scrollController.jumpTo(0.0);
              }
            });
          } else if (!_isUserScrolledUp) {
            // A new message arrived and user is at (or near) the bottom — auto-scroll.
            // This covers BOTH sent and received messages.
            _scrollToBottom(instant: true);
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
              child: _buildMessageItem(context, doc, index, reversedDocs),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageItem(
    BuildContext context,
    DocumentSnapshot doc,
    int index,
    List<DocumentSnapshot> docs,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final messageObj = Message.fromMap(data, docId: doc.id);
    final bool isCurrentUser = messageObj.senderID == widget.senderID;
    final timestamp = messageObj.timestamp.toDate();

    bool showDate =
        index ==
        docs.length - 1; // Used reversed logic: oldest message has date
    if (!showDate && index + 1 < docs.length) {
      final nextData =
          docs[index + 1].data()
              as Map<
                String,
                dynamic
              >; // This is chronologically the older message
      final nextTs = (nextData['timestamp'] as Timestamp).toDate();
      if (timestamp.year != nextTs.year ||
          timestamp.month != nextTs.month ||
          timestamp.day != nextTs.day) {
        showDate = true;
      }
    }

    return Column(
      crossAxisAlignment:
          isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showDate) _buildDateSeparator(timestamp),
        Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: ChatBubble(
            messageId: doc.id,
            message: messageObj.message,
            isCurrentUser: isCurrentUser,
            isEdited: messageObj.isEdited,
            timestamp: timestamp,
            replyToMessage: messageObj.replyToMessage,
            replyToSenderEmail: messageObj.replyToSenderEmail,
            messageType: messageObj.messageType,
            fileUrl: messageObj.fileUrl,
            fileName: messageObj.fileName,
            fileSize: messageObj.fileSize,
            status: messageObj.status,
            isDeletedForEveryone: messageObj.isDeletedForEveryone,
            isForwarded: messageObj.isForwarded,
            reactions: messageObj.reactions,
            onReactionTap:
                (emoji) => widget.chatService.toggleReaction(
                  widget.receiverID,
                  doc.id,
                  emoji,
                ),
            chatId: '${[widget.senderID, widget.receiverID]..sort()}'
                .replaceAll('[', '')
                .replaceAll(']', '')
                .replaceAll(', ', '_'),
            onReply:
                () => widget.onReply(
                  doc.id,
                  messageObj.message,
                  isCurrentUser ? widget.senderName : widget.receiverName,
                ),
            onEdit: () => widget.onEdit(doc.id, messageObj.message),
            onDelete:
                () => widget.onDelete(
                  doc.id,
                  isCurrentUser,
                  messageObj.isDeletedForEveryone,
                ),
            onSelectForDelete:
                () => widget.onToggleSelection(
                  doc.id,
                  messageObj,
                  requestedMode: SelectionMode.delete,
                ),
            onSelectForForward:
                () => widget.onToggleSelection(
                  doc.id,
                  messageObj,
                  requestedMode: SelectionMode.forward,
                ),
            isSelected: widget.selectedMessageIds.contains(doc.id),
            selectionMode: widget.selectionMode,
            onTap: () => widget.onToggleSelection(doc.id, messageObj),
            onLongPress: () => widget.onToggleSelection(doc.id, messageObj),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday =
        now.difference(date).inDays == 1 &&
        !isToday &&
        date.day == now.subtract(const Duration(days: 1)).day;
    String label =
        isToday
            ? l10n.today
            : (isYesterday
                ? l10n.yesterday
                : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.grey.withValues(alpha: 0.25),
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: Colors.grey.withValues(alpha: 0.25),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
