import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:googlechat/models/user_profile.dart';
import 'package:googlechat/pages/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/foldable_shell.dart';
import 'login_or_register.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static String _prefKey(String uid) => 'profile_completed_$uid';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (!authSnapshot.hasData) {
          return const LoginOrRegister();
        }

        final uid = authSnapshot.data!.uid;

        // Watch the user's Firestore profile document
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(uid)
              .snapshots(includeMetadataChanges: true),
          builder: (context, profileSnapshot) {
            // Show loader only on very first connect (no cached data yet)
            if (profileSnapshot.connectionState == ConnectionState.waiting &&
                !profileSnapshot.hasData) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0084FF),
                    strokeWidth: 2,
                  ),
                ),
              );
            }

            final data = profileSnapshot.data?.data() as Map<String, dynamic>?;
            final username = (data?['username'] as String? ?? '').trim();
            final profile = data != null ? UserProfile.fromMap(data) : null;

            // ── If username is empty → first login/registration, MUST set up ──
            if (username.isEmpty) {
              // No need to wait for server if we know username is empty.
              // Just show ProfilePage.

              return ProfilePage(
                isEditing: false,
                existingProfile: profile,
                onProfileChecked: () async {
                  // Mark this uid as having completed profile setup
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_prefKey(uid), true);
                },
              );
            }

            // ── Username exists — check if this uid has ever been flagged ──
            // We check the persisted flag asynchronously. While checking, show Home.
            // The ProfilePage is ONLY shown if username is empty (first time).
            return const FoldableShell();
          },
        );
      },
    );
  }
}
