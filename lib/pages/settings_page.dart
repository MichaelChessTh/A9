import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:googlechat/components/user_avatar.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/pages/profile_page.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/themes/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import '../services/language/language_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            AppLocalizations.of(context)!.settings,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Profile Section ───
            Text(
              AppLocalizations.of(context)!.editProfile,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<UserProfile?>(
              stream: UserService.currentUserProfileStream(),
              builder: (context, snapshot) {
                final profile = snapshot.data;
                final username = profile?.username ?? 'Setting up...';
                final status = profile?.status ?? '';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        displayName: username,
                        avatarBase64: profile?.avatarBase64,
                        radius: 30,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            if (status.isNotEmpty)
                              Text(
                                status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ProfilePage(
                                    isEditing: true,
                                    existingProfile: profile,
                                  ),
                            ),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ─── Appearance Section ───
            Text(
              AppLocalizations.of(context)!.theme,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)!.darkMode,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  isDark
                      ? AppLocalizations.of(context)!.darkModeEnabled
                      : AppLocalizations.of(context)!.lightModeEnabled,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                trailing: CupertinoSwitch(
                  value: Provider.of<ThemeProvider>(context).isDarkMode,
                  activeTrackColor: theme.colorScheme.primary,
                  onChanged:
                      (_) =>
                          Provider.of<ThemeProvider>(
                            context,
                            listen: false,
                          ).toggleTheme(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Language Section ───
            Text(
              AppLocalizations.of(context)!.language,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.language_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)!.pickLanguage,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                trailing: DropdownButton<Locale>(
                  value: Provider.of<LanguageProvider>(context).locale,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  underline: const SizedBox(),
                  onChanged: (Locale? locale) {
                    if (locale != null) {
                      Provider.of<LanguageProvider>(
                        context,
                        listen: false,
                      ).setLocale(locale);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: Locale('en'),
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: Locale('fr'),
                      child: Text('Français'),
                    ),
                    DropdownMenuItem(
                      value: Locale('de'),
                      child: Text('Deutsch'),
                    ),
                    DropdownMenuItem(
                      value: Locale('ru'),
                      child: Text('Русский'),
                    ),
                    DropdownMenuItem(
                      value: Locale('es'),
                      child: Text('Español'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ─── Account Section ───
            Text(
              AppLocalizations.of(context)!.account,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.orange,
                    size: 22,
                  ),
                ),
                title: Text(
                  AppLocalizations.of(context)!.changePassword,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                onTap: () => _showChangePasswordDialog(context),
              ),
            ),

            const SizedBox(height: 12),

            // ─── Delete Account Section ───
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.changePassword),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)!.changePasswordDescription,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.newPassword,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pwd = ctrl.text.trim();
                  if (pwd.length < 6) {
                    Fluttertoast.showToast(
                      msg: AppLocalizations.of(context)!.passwordLengthError,
                    );
                    return;
                  }
                  try {
                    await FirebaseAuth.instance.currentUser?.updatePassword(
                      pwd,
                    );
                    Fluttertoast.showToast(
                      msg: AppLocalizations.of(context)!.passwordUpdated,
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    Fluttertoast.showToast(
                      msg: AppLocalizations.of(context)!.passwordUpdateError,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                 child: Text(AppLocalizations.of(context)!.update),
              ),
            ],
          ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            content: const Text(
              'Are you sure you want to delete your account? This action is permanent and cannot be undone. All your messages and profile data will be destroyed.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await UserService.deleteAccount();
                    Fluttertoast.showToast(msg: 'Account deleted successfully.');
                    // Navigation to welcome page handled by auth listener in main
                    if (context.mounted) Navigator.pop(context); 
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'requires-recent-login') {
                      Fluttertoast.showToast(
                        msg: 'Please log out and log in again to verify your identity before deleting.',
                        toastLength: Toast.LENGTH_LONG,
                      );
                    } else {
                      Fluttertoast.showToast(msg: 'Error: ${e.message}');
                    }
                  } catch (e) {
                    Fluttertoast.showToast(msg: 'Failed to delete account.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
