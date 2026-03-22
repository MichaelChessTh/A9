import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/services/group/group_service.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/components/user_avatar.dart';
import 'package:googlechat/l10n/app_localizations.dart';

class CreateGroupPage extends StatefulWidget {
  /// UIDs of existing chat contacts the current user can invite
  final List<String> availableContactUIDs;

  const CreateGroupPage({super.key, required this.availableContactUIDs});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _nameCtrl = TextEditingController();
  final _selectedUIDs = <String>{};
  Uint8List? _imageBytes;
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.first.bytes != null) {
      setState(() => _imageBytes = result.files.first.bytes);
    }
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseEnterGroupName),
        ),
      );
      return;
    }
    if (_selectedUIDs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectOneMember),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await GroupService.createGroup(
        name: name,
        memberUIDs: _selectedUIDs.toList(),
        imageBytes: _imageBytes,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.failedToCreateGroup}: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor;
    final surface = theme.colorScheme.surfaceContainerHighest;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
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
            AppLocalizations.of(context)!.newGroup,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
        ),
        actions: [
          _loading
              ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0072FF),
                    ),
                  ),
                ),
              )
              : TextButton(
                onPressed: _create,
                child: Text(
                  AppLocalizations.of(context)!.create,
                  style: const TextStyle(
                    color: Color(0xFF0072FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Group image + name ──────────────────────────────────
          Container(
            color: surface,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              _imageBytes == null
                                  ? const LinearGradient(
                                    colors: [
                                      Color(0xFF00C6FF),
                                      Color(0xFF0072FF),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                  : null,
                        ),
                        child:
                            _imageBytes != null
                                ? ClipOval(
                                  child: Image.memory(
                                    _imageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                                : const Icon(
                                  Icons.group_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: surface, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.groupName,
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
          ),
          // ── Members section ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Text(
                  AppLocalizations.of(context)!.addMembers,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.countSelected(_selectedUIDs.length),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                widget.availableContactUIDs.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 56,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context)!.noExistingContacts,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context)!.startChatFirst,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: widget.availableContactUIDs.length,
                      itemBuilder: (context, i) {
                        final uid = widget.availableContactUIDs[i];
                        return _ContactPickerTile(
                          uid: uid,
                          selected: _selectedUIDs.contains(uid),
                          onToggle: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedUIDs.add(uid);
                              } else {
                                _selectedUIDs.remove(uid);
                              }
                            });
                          },
                          theme: theme,
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _ContactPickerTile extends StatelessWidget {
  final String uid;
  final bool selected;
  final void Function(bool) onToggle;
  final ThemeData theme;

  const _ContactPickerTile({
    required this.uid,
    required this.selected,
    required this.onToggle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserService.getUserProfileStream(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.username ?? '…';
        final email = profile?.email ?? '';

        return InkWell(
          onTap: () => onToggle(!selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                UserAvatar(
                  displayName: name,
                  avatarBase64: profile?.avatarBase64,
                  radius: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        selected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                    border: Border.all(
                      color:
                          selected
                              ? theme.colorScheme.primary
                              : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child:
                      selected
                          ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                          : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
