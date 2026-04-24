import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              'Privacy Policy for A9 Chat',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: April 2026\n\n'
              'Welcome to A9 Chat. We are committed to protecting your privacy and ensuring your data is secure. This Privacy Policy explains how we collect, use, and safeguard your information.\n\n'
              '1. Information We Collect\n'
              '• Account Data: When you sign up, we collect your email address, username, and an optional profile picture (avatar).\n'
              '• Messages & Media: Messages, photos, videos, and files you send. All messages are protected by End-to-End Encryption (E2EE), meaning we cannot read your message contents.\n'
              '• Usage Data: We collect standard diagnostic data (like crash reports) to improve the stability of the application.\n\n'
              '2. How We Use Information\n'
              '• To provide and maintain our communication service.\n'
              '• To sync your account seamlessly across multiple devices.\n'
              '• To notify you about new messages via push notifications.\n\n'
              '3. Data Storage & Security\n'
              'Your data is securely stored on Google Cloud (Firebase) servers. We employ industry-standard security measures including AES-256 encryption. Nobody, including the developers of A9, can decrypt or read your secure chats.\n\n'
              '4. Third-Party Sharing\n'
              'We do not sell, rent, or trade your personal information to third parties. Data is only shared with infrastructure providers (like Firebase) strictly to operate the app.\n\n'
              '5. Account Deletion\n'
              'You have the right to delete your data at any time. You can do this directly from within the app by navigating to Settings -> Delete Account. This action permanently deletes your profile, messages, media, and revokes our access to your email.\n\n'
              '6. Contact Us\n'
              'If you have any questions about this Privacy Policy, please contact the developer via the official repository or support email.',
              style: TextStyle(fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 40),
            Center(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
