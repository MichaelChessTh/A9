import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:googlechat/models/message.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:googlechat/components/video_widget.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:googlechat/services/chat/media_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatBubble extends StatefulWidget {
  final String messageId;
  final String message;
  final bool isCurrentUser;
  final bool isEdited;
  final DateTime timestamp;
  final String? replyToMessage;
  final String? replyToSenderEmail;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Called when user taps Delete inside the context menu to enter selection mode
  final VoidCallback? onSelectForDelete;
  final VoidCallback? onSelectForForward;
  final String chatId;

  // Multimedia support
  final MessageType messageType;
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;
  final MessageStatus status;
  final bool isDeletedForEveryone;
  final bool isSelected;
  final SelectionMode selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isForwarded;
  final Map<String, dynamic> reactions;
  final ValueChanged<String>? onReactionTap;

  const ChatBubble({
    super.key,
    required this.messageId,
    required this.message,
    required this.isCurrentUser,
    required this.timestamp,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    this.onSelectForDelete,
    this.onSelectForForward,
    required this.chatId,
    this.isEdited = false,
    this.replyToMessage,
    this.replyToSenderEmail,
    this.messageType = MessageType.text,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.status = MessageStatus.sent,
    this.isDeletedForEveryone = false,
    this.isSelected = false,
    this.selectionMode = SelectionMode.none,
    required this.onTap,
    required this.onLongPress,
    this.isForwarded = false,
    this.reactions = const {},
    this.onReactionTap,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _replyTriggered = false;
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;

  // Cache for decoded base64 bytes to prevent repeated decoding on rebuild
  Uint8List? _cachedBase64Bytes;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _snapAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    );
    _snapController.addListener(() {
      setState(() {
        _dragOffset = _snapAnimation.value;
      });
    });
    // Pre-decode base64 image bytes asynchronously to avoid UI jank
    if (widget.messageType == MessageType.image &&
        widget.fileUrl != null &&
        widget.fileUrl!.startsWith('data:image')) {
      _decodeBase64Async();
    }
    _initMedia();
  }

  Future<void> _decodeBase64Async() async {
    final String base64Content =
        widget.fileUrl!.contains(',')
            ? widget.fileUrl!.split(',').last
            : widget.fileUrl!;
    try {
      final bytes = await compute(base64Decode, base64Content);
      if (mounted) {
        setState(() {
          _cachedBase64Bytes = bytes;
        });
      }
    } catch (_) {}
  }

  String? _localPath;
  bool _isDownloading = false;

  Future<void> _initMedia() async {
    final fileUrl = widget.fileUrl;
    if (fileUrl == null ||
        fileUrl.isEmpty ||
        fileUrl.startsWith('data:image')) {
      return;
    }

    final existingPath = MediaService.getLocalPath(widget.messageId);
    if (existingPath != null && File(existingPath).existsSync()) {
      if (mounted) setState(() => _localPath = existingPath);
      return;
    }

    if (mounted) {
      setState(() => _isDownloading = true);
      final newPath = await MediaService.downloadAndSaveMedia(
        messageId: widget.messageId,
        url: fileUrl,
        fileName: widget.fileName ?? 'media',
        type: widget.messageType,
        chatId: widget.chatId,
        isReceiver: !widget.isCurrentUser,
      );
      if (mounted) {
        setState(() {
          _localPath = newPath;
          _isDownloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx > 0) {
      setState(() {
        _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 72.0);
        if (_dragOffset >= 55 && !_replyTriggered) {
          _replyTriggered = true;
          HapticFeedback.mediumImpact();
        }
      });
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_replyTriggered) widget.onReply();
    _replyTriggered = false;
    _snapAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.elasticOut),
    );
    _snapController.forward(from: 0);
  }

  void _showContextMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    HapticFeedback.mediumImpact();
    // If message is deleted for everyone, only show "Delete for me" option
    if (widget.isDeletedForEveryone) {
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
                    leading: const Icon(Icons.delete_outline),
                    title: Text(l10n.deleteForMe),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _ContextMenu(
            isCurrentUser: widget.isCurrentUser,
            message: widget.message,
            messageType: widget.messageType,
            onReply: () {
              Navigator.pop(ctx);
              widget.onReply();
            },
            onEdit:
                widget.isCurrentUser
                    ? () {
                      Navigator.pop(ctx);
                      widget.onEdit();
                    }
                    : null,
            onDelete: () {
              Navigator.pop(ctx);
              if (widget.onSelectForDelete != null) {
                widget.onSelectForDelete!();
              } else {
                widget.onDelete();
              }
            },
            onForward:
                widget.onSelectForForward != null
                    ? () {
                      Navigator.pop(ctx);
                      widget.onSelectForForward!();
                    }
                    : null,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: widget.message));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.messageCopied),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
    );
  }

  void _showReactionMenu(BuildContext context) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    HapticFeedback.lightImpact();

    void removeOverlay() {
      overlayEntry.remove();
    }

    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: removeOverlay,
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            top: offset.dy > 60 ? offset.dy - 60 : offset.dy + size.height + 10,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...emojis.map((e) => GestureDetector(
                            onTap: () {
                              removeOverlay();
                              if (widget.onReactionTap != null) widget.onReactionTap!(e);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(e, style: const TextStyle(fontSize: 22)),
                            ),
                          )),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          removeOverlay();
                          _showEmojiPicker(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: Icon(Icons.add, size: 18, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlayState.insert(overlayEntry);
  }

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: EmojiPicker(
            onEmojiSelected: (category, emoji) {
              Navigator.pop(ctx);
              if (widget.onReactionTap != null) widget.onReactionTap!(emoji.emoji);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsDisplay() {
    // Count occurrences of each emoji
    final Map<String, int> counts = {};
    for (final emoji in widget.reactions.values) {
      final strEmoji = emoji.toString();
      counts[strEmoji] = (counts[strEmoji] ?? 0) + 1;
    }
    
    final sortedEmojis = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    
    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: sortedEmojis.map((emoji) {
        return GestureDetector(
          onTap: () {
            if (widget.onReactionTap != null) widget.onReactionTap!(emoji);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                if (counts[emoji]! > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${counts[emoji]}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    Color bubbleColor =
        widget.isCurrentUser ? primary : theme.colorScheme.surfaceContainer;

    BoxBorder? border;
    List<BoxShadow>? shadows;
    if (widget.isSelected) {
      final neonColor =
          widget.selectionMode == SelectionMode.forward
              ? const Color(
                0xFF00FFEE,
              ) // bright neon cyan — visible on any bubble
              : const Color(0xFFFF3B3B); // bright neon red
      border = Border.all(color: neonColor, width: 2.5);
      shadows = [
        BoxShadow(
          color: neonColor.withValues(alpha: 0.75),
          blurRadius: 14,
          spreadRadius: 3,
        ),
        BoxShadow(
          color: neonColor.withValues(alpha: 0.35),
          blurRadius: 28,
          spreadRadius: 6,
        ),
      ];
    } else {
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }

    final textColor =
        widget.isCurrentUser ? Colors.white : theme.colorScheme.onSurface;

    final timeStr = DateFormat('HH:mm').format(widget.timestamp);

    // Reply border color — contrasting on bubble
    final replyBarColor =
        widget.isCurrentUser
            ? Colors.white.withValues(alpha: 0.6)
            : theme.colorScheme.primary;
    final replyTextColor =
        widget.isCurrentUser
            ? Colors.white.withValues(alpha: 0.85)
            : textColor.withValues(alpha: 0.65);
    final replyNameColor =
        widget.isCurrentUser ? Colors.white : theme.colorScheme.primary;

    return GestureDetector(
      onHorizontalDragUpdate:
          (widget.isSelected || widget.isDeletedForEveryone)
              ? null
              : _onHorizontalDragUpdate,
      onHorizontalDragEnd:
          (widget.isSelected || widget.isDeletedForEveryone)
              ? null
              : _onHorizontalDragEnd,
      onLongPress: () {
        if (widget.selectionMode == SelectionMode.none) {
          _showContextMenu(context);
        } else {
          widget.onLongPress();
        }
      },
      onDoubleTap: (widget.isSelected || widget.isDeletedForEveryone || widget.selectionMode != SelectionMode.none)
          ? null
          : () => _showReactionMenu(context),
      onTap: widget.selectionMode != SelectionMode.none ? widget.onTap : null,
      child: Container(
        color: Colors.transparent,
        child: Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: Stack(
            children: [
              // Swipe reply icon
              if (_dragOffset > 10)
                Positioned(
                  left: widget.isCurrentUser ? null : 0,
                  right: widget.isCurrentUser ? 0 : null,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: (_dragOffset / 55).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.reply_rounded,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              // Bubble column
              Column(
                crossAxisAlignment:
                    widget.isCurrentUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply snippet
                  if (widget.replyToMessage != null)
                    _buildReplySnippet(
                      bubbleColor,
                      replyBarColor,
                      replyNameColor,
                      replyTextColor,
                    ),

                  // Main bubble
                  Container(
                    constraints: BoxConstraints(
                      maxWidth:
                          widget.messageType == MessageType.image ? 250 : 280,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      border: border,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft:
                            widget.isCurrentUser
                                ? const Radius.circular(18)
                                : const Radius.circular(4),
                        bottomRight:
                            widget.isCurrentUser
                                ? const Radius.circular(4)
                                : const Radius.circular(18),
                      ),
                      boxShadow: shadows,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMessageContent(textColor),
                        if (widget.messageType != MessageType.text)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Text(
                              widget.message,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isForwarded) ...[
                                Icon(
                                  Icons.forward_rounded,
                                  size: 10,
                                  color: textColor.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${AppLocalizations.of(context)!.forwardedMessage} · ',
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                              if (widget.isEdited)
                                Text(
                                  '${AppLocalizations.of(context)!.edited} · ',
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                              ),
                              if (widget.isCurrentUser) ...[
                                const SizedBox(width: 4),
                                _buildStatusIcon(textColor),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Reactions display
                  if (widget.reactions.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        left: widget.isCurrentUser ? 0 : 8,
                        right: widget.isCurrentUser ? 8 : 0,
                      ),
                      child: _buildReactionsDisplay(),
                    ),
                ],
              ),
            ],
          ),
        ), // close Transform.translate
      ), // close Container
    ); // close GestureDetector
  }

  Widget _buildReplySnippet(
    Color bubbleColor,
    Color barColor,
    Color nameColor,
    Color textColor,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      margin: EdgeInsets.only(
        bottom: 2,
        left: widget.isCurrentUser ? 32 : 0,
        right: widget.isCurrentUser ? 0 : 32,
      ),
      decoration: BoxDecoration(
        color: bubbleColor.withValues(alpha: 0.45),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.replyToSenderEmail?.split('@').first ?? '',
                      style: TextStyle(
                        color: nameColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.replyToMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(Color textColor) {
    if (widget.isDeletedForEveryone) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block_rounded,
              size: 16,
              color: textColor.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              "This message was deleted.",
              style: TextStyle(
                color: textColor.withValues(alpha: 0.8),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    switch (widget.messageType) {
      case MessageType.image:
        if (widget.fileUrl == null || widget.fileUrl!.isEmpty) {
          return const SizedBox.shrink();
        }

        final bool isBase64 = widget.fileUrl!.startsWith('data:image');

        if (isBase64) {
          // Use cached bytes to prevent repeated base64 decoding on each rebuild
          final bytes = _cachedBase64Bytes;
          if (bytes == null) {
            return Container(
              height: 200,
              width: 250,
              color: Colors.grey.withValues(alpha: 0.1),
              child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
            );
          }
          return GestureDetector(
            onTap: () => _viewImage(context),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              height: 200,
              width: 250,
              cacheWidth: 800, // Optimize memory for the image thumbnail
              gaplessPlayback: true,
              errorBuilder:
                  (context, error, stackTrace) => Container(
                    height: 200,
                    width: 250,
                    color: Colors.grey.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.grey,
                    ),
                  ),
            ),
          );
        }

        if (_localPath != null && File(_localPath!).existsSync()) {
          return GestureDetector(
            onTap: () => _viewImage(context, localPath: _localPath),
            child: Image.file(
              File(_localPath!),
              fit: BoxFit.cover,
              height: 200,
              width: 250,
              cacheWidth: 800,
            ),
          );
        }

        if (_isDownloading) {
          return Container(
            height: 200,
            width: 250,
            color: Colors.grey.withValues(alpha: 0.1),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return GestureDetector(
          onTap: () => _viewImage(context),
          child: Image.network(
            widget.fileUrl!,
            fit: BoxFit.cover,
            height: 200,
            width: 250,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                width: 250,
                color: Colors.grey.withValues(alpha: 0.1),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder:
                (context, error, stackTrace) => Container(
                  height: 200,
                  width: 250,
                  color: Colors.grey.withValues(alpha: 0.1),
                  child: Center(
                    child: Text(
                      AppLocalizations.of(context)?.mediaRemoved ??
                          'Media removed',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
          ),
        );
      case MessageType.video:
        return _buildVideoItem(textColor);
      case MessageType.file:
        return _buildFileItem(textColor);
      case MessageType.audio:
        return VoiceMessagePlayer(
          url: widget.fileUrl!,
          localPath: _localPath,
          isCurrentUser: widget.isCurrentUser,
        );
      case MessageType.text:
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Linkify(
            text: widget.message,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
            linkStyle: TextStyle(
              color:
                  widget.isCurrentUser
                      ? Colors.lightBlueAccent
                      : Theme.of(context).colorScheme.primary,
              fontSize: 15,
              height: 1.35,
              decoration: TextDecoration.underline,
            ),
            onOpen: (link) async {
              final uri = Uri.tryParse(link.url);
              if (uri != null && await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        );
    }
  }

  Widget _buildVideoItem(Color textColor) {
    if (_isDownloading) {
      return Container(
        height: 200,
        width: 250,
        color: Colors.grey.withValues(alpha: 0.1),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_localPath != null && File(_localPath!).existsSync()) {
      return VideoWidget(localPath: _localPath!);
    }
    return Container(
      height: 200,
      width: 250,
      color: Colors.grey.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          AppLocalizations.of(context)?.videoUnavailable ?? 'Video unavailable',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildFileItem(Color textColor) {
    return InkWell(
      onTap: _openFile,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.insert_drive_file_rounded,
                color: textColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fileName ?? 'File',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (widget.fileSize != null)
                    Text(
                      widget.fileSize!,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_for_offline_rounded,
              color: textColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _viewImage(BuildContext context, {String? localPath}) {
    final bool isBase64 = widget.fileUrl?.startsWith('data:image') ?? false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: _openFile,
                  ),
                ],
              ),
              body: Center(
                child: InteractiveViewer(
                  child:
                      isBase64
                          ? Image.memory(
                            base64Decode(widget.fileUrl!.split(',').last),
                          )
                          : (localPath != null
                              ? Image.file(File(localPath))
                              : Image.network(widget.fileUrl!)),
                ),
              ),
            ),
      ),
    );
  }

  Future<void> _openFile() async {
    if (widget.fileUrl == null || widget.fileUrl!.isEmpty) return;

    try {
      if (_localPath != null && File(_localPath!).existsSync()) {
        await OpenFilex.open(_localPath!);
        return;
      }
      final String url = widget.fileUrl!;
      final bool isBase64 = url.startsWith('data:image');
      String name =
          widget.fileName ?? "file_${DateTime.now().millisecondsSinceEpoch}";

      // Ensure extension for images if missing and Base64
      if (widget.messageType == MessageType.image && !name.contains('.')) {
        name += ".jpg";
      }

      // --- WEB DOWNLOAD ---
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloads on Web: Open image in new tab to save.'),
          ),
        );
        return;
      }

      // --- NATIVE DOWNLOAD (Windows/Android/iOS) ---
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$name';
      final file = File(savePath);

      if (isBase64) {
        final bytes = base64Decode(url.split(',').last);
        await file.writeAsBytes(bytes);
      } else {
        final dio = Dio();
        await dio.download(url, savePath);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Downloaded to: $savePath')));
      }

      await OpenFilex.open(savePath);
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        String errorMsg = 'Download failed: $e';
        // Specifically catch the MissingPluginException to help the user
        if (e.toString().contains('MissingPluginException')) {
          errorMsg =
              'Plugin Error: You must STOP and START the app (Full Restart) to register the download plugin.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    }
  }

  Widget _buildStatusIcon(Color textColor) {
    switch (widget.status) {
      case MessageStatus.sent:
        return Icon(
          Icons.check_rounded,
          size: 16,
          color: textColor.withValues(alpha: 0.6),
        );
      case MessageStatus.delivered:
        return _DoubleCheckIcon(color: textColor.withValues(alpha: 0.6));
      case MessageStatus.seen:
        return const _DoubleCheckIcon(
          color: Color(0xFF4FC3F7), // bright sky-blue ticks
        );
    }
  }
}

/// Two overlapping check marks (mimicking WhatsApp double-tick style)
class _DoubleCheckIcon extends StatelessWidget {
  final Color color;
  const _DoubleCheckIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 16,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            child: Icon(Icons.check_rounded, size: 14, color: color),
          ),
          Positioned(
            left: 6,
            child: Icon(Icons.check_rounded, size: 14, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Voice Message Player Component ──────────────────────────────
class VoiceMessagePlayer extends StatefulWidget {
  final String url;
  final String? localPath;
  final bool isCurrentUser;
  const VoiceMessagePlayer({
    super.key,
    required this.url,
    this.localPath,
    required this.isCurrentUser,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late final audioPlayer = AudioPlayer();
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Force media routing instead of call volume
    audioPlayer.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.media,
          contentType: AndroidContentType.music,
          isSpeakerphoneOn: true,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
          },
        ),
      ),
    );

    audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playerState = s);
    });
    audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.completed;
          _position = Duration.zero;
        });
      }
    });

    // Preload source to fetch duration correctly without playing
    _initSource();
  }

  Future<void> _initSource() async {
    if (widget.localPath != null && File(widget.localPath!).existsSync()) {
      await audioPlayer.setSource(DeviceFileSource(widget.localPath!));
    } else {
      await audioPlayer.setSource(UrlSource(widget.url));
    }
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  void _playPause() async {
    try {
      if (_playerState == PlayerState.playing) {
        await audioPlayer.pause();
      } else {
        // When completed or stopped, the source must be re-set before resume
        // because some platforms release the player resources after completion.
        if (_playerState == PlayerState.completed ||
            _playerState == PlayerState.stopped) {
          await _initSource();
          await audioPlayer.seek(Duration.zero);
        }
        await audioPlayer.resume();
      }
    } catch (e) {
      debugPrint("Error playing audio: $e");
      // Fallback: re-init source and play from scratch
      try {
        await _initSource();
        await audioPlayer.seek(Duration.zero);
        await audioPlayer.resume();
      } catch (e2) {
        debugPrint("Fallback play error: $e2");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // User wants: for sender -> white. for receiver -> white if dark theme, black if light theme.
    final textColor =
        widget.isCurrentUser
            ? Colors.white
            : (isDark ? Colors.white : Colors.black87);

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _playerState == PlayerState.playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              size: 36,
              color: textColor,
            ),
            onPressed: _playPause,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max:
                      _duration.inMilliseconds.toDouble() > 0
                          ? _duration.inMilliseconds.toDouble()
                          : 1.0,
                  activeColor: textColor,
                  inactiveColor: textColor.withValues(alpha: 0.3),
                  onChanged: (value) {
                    audioPlayer.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(color: textColor, fontSize: 10),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(color: textColor, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────
// Context menu bottom sheet
// ─────────────────────────────────────────────────────────
class _ContextMenu extends StatelessWidget {
  final bool isCurrentUser;
  final String message;
  final MessageType messageType;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onForward;
  final VoidCallback onCopy;

  const _ContextMenu({
    required this.isCurrentUser,
    required this.message,
    required this.messageType,
    required this.onReply,
    this.onEdit,
    this.onDelete,
    this.onForward,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.scaffoldBackgroundColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              messageType == MessageType.text
                  ? message
                  : (AppLocalizations.of(context)?.audioMessage ??
                      'Voice message'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _MenuItem(
            icon: Icons.reply_rounded,
            label: AppLocalizations.of(context)?.reply ?? 'Reply',
            color: theme.colorScheme.primary,
            onTap: onReply,
          ),
          if (messageType == MessageType.text)
            _MenuItem(
              icon: Icons.copy_rounded,
              label: AppLocalizations.of(context)?.copy ?? 'Copy',
              color: theme.colorScheme.onSurface,
              onTap: onCopy,
            ),
          if (onEdit != null)
            _MenuItem(
              icon: Icons.edit_rounded,
              label: AppLocalizations.of(context)?.edit ?? 'Edit',
              color: theme.colorScheme.onSurface,
              onTap: onEdit!,
            ),
          if (onForward != null)
            _MenuItem(
              icon: Icons.forward_to_inbox_rounded,
              label: AppLocalizations.of(context)?.forward ?? 'Forward',
              color: theme.colorScheme.onSurface,
              onTap: onForward!,
            ),
          if (onDelete != null)
            _MenuItem(
              icon: Icons.delete_outline_rounded,
              label: AppLocalizations.of(context)?.delete ?? 'Delete',
              color: Colors.red,
              onTap: onDelete!,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
