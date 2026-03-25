import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googlechat/components/a9_logo.dart';
import 'package:googlechat/services/update/update_service.dart';
import 'package:provider/provider.dart';
import 'package:googlechat/l10n/app_localizations.dart';

class UpdatePage extends StatelessWidget {
  const UpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.softwareUpdate,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<UpdateService>(
        builder: (context, updateService, child) {
          final isUpdateAvailable = updateService.isUpdateAvailable;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const A9Logo(width: 120, height: 120, borderRadius: 32),
                const SizedBox(height: 32),

                // Version Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(10)
                        : Colors.black.withAlpha(5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(10)
                          : Colors.black.withAlpha(5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isUpdateAvailable
                            ? AppLocalizations.of(context)!.newVersionAvailable
                            : AppLocalizations.of(context)!.systemUpToDate,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isUpdateAvailable
                              ? const Color(0xFF0072FF)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isUpdateAvailable
                            ? AppLocalizations.of(context)!
                                .versionReady(updateService.latestVersion)
                            : AppLocalizations.of(context)!.latestVersionNotice,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withAlpha(150),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!
                              .currentVersionLabel(updateService.currentVersion),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // iOS info banner
                if (Platform.isIOS && isUpdateAvailable) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0072FF).withAlpha(15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF0072FF).withAlpha(40),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF0072FF),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'iOS updates are distributed via the App Store. '
                            'Tap below to open the App Store and update the app.',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  theme.colorScheme.onSurface.withAlpha(200),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Review/Changelog Header
                Row(
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.whatsNew,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Changelog content
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 100),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(5)
                        : Colors.black.withAlpha(3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    updateService.reviewText,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: _buildActionButton(context, updateService),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, UpdateService service) {
    // ── iOS: redirect to App Store ──────────────────────────────────
    if (Platform.isIOS) {
      if (!service.isUpdateAvailable) {
        return ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            disabledBackgroundColor: Colors.grey.withAlpha(30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            AppLocalizations.of(context)!.systemUpToDate,
            style: const TextStyle(color: Colors.white60),
          ),
        );
      }
      return _gradientButton(
        label: 'Open App Store',
        icon: Icons.open_in_new_rounded,
        onTap: () => service.openAppStore(),
      );
    }

    // ── Android: download / install flow ────────────────────────────
    if (!service.isUpdateAvailable && !service.isDownloaded) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          disabledBackgroundColor: Colors.grey.withAlpha(30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          AppLocalizations.of(context)!.systemUpToDate,
          style: const TextStyle(color: Colors.white60),
        ),
      );
    }

    if (service.isDownloaded) {
      return _gradientButton(
        label: AppLocalizations.of(context)!.installNow,
        onTap: () => service.installUpdate(),
      );
    }

    if (service.isDownloading) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.downloading,
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurface.withAlpha(150),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${(service.downloadProgress * 100).toInt()}%",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: service.downloadProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary.withAlpha(40),
                ),
                minHeight: 64,
              ),
            ),
          ),
        ],
      );
    }

    return _gradientButton(
      label: AppLocalizations.of(context)!.downloadUpdate,
      onTap: () => service.downloadUpdate(),
    );
  }

  Widget _gradientButton({
    required String label,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0072FF).withAlpha(80),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: icon != null
            ? Icon(icon, color: Colors.white, size: 18)
            : const SizedBox.shrink(),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
