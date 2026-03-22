import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/l10n/app_localizations.dart';

/// Shown after first login/registration (isEditing=false)
/// or from Settings to edit profile (isEditing=true).
class ProfilePage extends StatefulWidget {
  final bool isEditing;
  final UserProfile? existingProfile;
  final VoidCallback? onProfileChecked;

  const ProfilePage({
    super.key,
    this.isEditing = false,
    this.existingProfile,
    this.onProfileChecked,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  final _statusController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _avatarBase64;
  Uint8List? _avatarBytes;
  bool _isSaving = false;
  bool _avatarChanged = false;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  void _loadExistingProfile() {
    final p = widget.existingProfile;
    if (p != null) {
      _usernameController.text = p.username;
      _statusController.text = p.status;
      _phoneController.text = p.phoneNumber;
      _avatarBase64 = p.avatarBase64;
      _avatarBytes = UserService.decodeAvatar(p.avatarBase64);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _statusController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final base64 = await UserService.pickAndEncodeAvatar();
    if (base64 == null) return;
    setState(() {
      _avatarBase64 = base64;
      _avatarBytes = UserService.decodeAvatar(base64);
      _avatarChanged = true;
    });
  }

  void _removeAvatar() {
    setState(() {
      _avatarBase64 = null;
      _avatarBytes = null;
      _avatarChanged = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final newUsername = _usernameController.text.trim();

      // Check if username is already taken by someone else
      final isTaken = await UserService.isUsernameTaken(newUsername);
      if (isTaken) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.usernameTaken),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      await UserService.saveProfile(
        username: newUsername,
        status: _statusController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        avatarBase64: _avatarChanged ? _avatarBase64 : null,
      );

      // If avatar was cleared, explicitly remove it
      if (_avatarChanged && _avatarBase64 == null) {
        await UserService.removeAvatar();
      }

      if (mounted && widget.isEditing) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.profileUpdated),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else if (mounted) {
        // Just finished login check
        widget.onProfileChecked?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.error}: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      // Prevent back on first-time setup
      canPop: widget.isEditing,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar:
            widget.isEditing
                ? AppBar(
                  backgroundColor: theme.scaffoldBackgroundColor,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
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
                      AppLocalizations.of(context)!.editProfile,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Divider(
                      height: 1,
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                )
                : null,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: widget.isEditing ? 32 : 48),

                  // ── Avatar picker ──
                  _buildAvatarPicker(isDark, theme),
                  const SizedBox(height: 36),

                  // ── Username field ──
                  _buildLabel(
                    '${AppLocalizations.of(context)!.username} *',
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _usernameController,
                    hint: AppLocalizations.of(context)!.usernameHint,
                    icon: Icons.alternate_email_rounded,
                    isDark: isDark,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return AppLocalizations.of(context)!.usernameRequired;
                      }
                      if (v.trim().length < 2) {
                        return AppLocalizations.of(context)!.usernameTooShort;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Status field ──
                  _buildLabel(
                    AppLocalizations.of(context)!.statusLabelOptional,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _statusController,
                    hint: AppLocalizations.of(context)!.statusHint,
                    icon: Icons.info_outline_rounded,
                    isDark: isDark,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // ── Phone field ──
                  _buildLabel(
                    AppLocalizations.of(context)!.phoneNumber,
                    isDark,
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _phoneController,
                    hint: AppLocalizations.of(context)!.phoneHint,
                    icon: Icons.phone_rounded,
                    isDark: isDark,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v != null && v.isNotEmpty && !v.startsWith('+')) {
                        return AppLocalizations.of(context)!.phoneRequiredPlus;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 36),

                  // ── Save button ──
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.colorScheme.primary
                            .withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                widget.isEditing
                                    ? AppLocalizations.of(context)!.saveChanges
                                    : AppLocalizations.of(
                                      context,
                                    )!.continueText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker(bool isDark, ThemeData theme) {
    return GestureDetector(
      onTap: _pickAvatar,
      onLongPress: _avatarBytes != null ? _removeAvatar : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Avatar circle
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: ClipOval(
              child:
                  _avatarBytes != null
                      ? Image.memory(
                        _avatarBytes!,
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110,
                      )
                      : Icon(
                        Icons.person_rounded,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
            ),
          ),
          // Camera badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1C1E21),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1C1E21),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
