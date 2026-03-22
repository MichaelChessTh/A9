import 'package:flutter/material.dart';
import 'package:googlechat/components/user_avatar.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/services/user/user_service.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import '../pages/settings_page.dart';
import '../pages/call_log_page.dart';
import '../services/auth/auth_service.dart';
import '../services/update/update_service.dart';
import '../pages/update_page.dart';
import 'package:provider/provider.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  void logout() {
    final auth = AuthService();
    auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = AuthService().getCurrentUser();
    final email = user?.email ?? '';

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header showing real user profile
          StreamBuilder<UserProfile?>(
            stream: UserService.currentUserProfileStream(),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              final username = profile?.username ?? email.split('@').first;
              final avatarBase64 = profile?.avatarBase64;

              return Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 24,
                  right: 24,
                  bottom: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      displayName: username,
                      avatarBase64: avatarBase64,
                      radius: 32,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.home_rounded,
                  label: AppLocalizations.of(context)!.home,
                  onTap: () => Navigator.pop(context),
                ),
                _DrawerItem(
                  icon: Icons.history_rounded,
                  label: AppLocalizations.of(context)!.callLog,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CallLogPage()),
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_rounded,
                  label: AppLocalizations.of(context)!.settings,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SettingsPage()),
                    );
                  },
                ),
                Consumer<UpdateService>(
                  builder: (context, updateService, child) {
                    return _DrawerItem(
                      icon: Icons.system_update_rounded,
                      label: AppLocalizations.of(context)!.update,
                      showDot: updateService.isUpdateAvailable,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UpdatePage()),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          // Logout
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
            ),
            child: _DrawerItem(
              icon: Icons.logout_rounded,
              label: AppLocalizations.of(context)!.logout,
              color: Colors.red.shade400,
              onTap: logout,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool showDot;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemColor = color ?? theme.colorScheme.onSurface;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: itemColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: itemColor, size: 22),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: itemColor,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          if (showDot)
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF0072FF),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}
