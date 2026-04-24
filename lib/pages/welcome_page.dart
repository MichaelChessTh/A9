import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:googlechat/pages/privacy_policy_page.dart';
import 'package:googlechat/components/a9_logo.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:googlechat/services/language/language_provider.dart';
import 'package:googlechat/services/auth/auth_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _acceptedPolicy = false;

  void _onContinue() async {
    if (!_acceptedPolicy) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome', true);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final langProvider = Provider.of<LanguageProvider>(
          context,
          listen: false,
        );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: const Text('English'),
                onTap: () {
                  langProvider.setLocale(const Locale('en'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Русский'),
                onTap: () {
                  langProvider.setLocale(const Locale('ru'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Español'),
                onTap: () {
                  langProvider.setLocale(const Locale('es'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Français'),
                onTap: () {
                  langProvider.setLocale(const Locale('fr'));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Deutsch'),
                onTap: () {
                  langProvider.setLocale(const Locale('de'));
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.language_rounded),
                  onPressed: () => _showLanguageSelector(context),
                  tooltip: 'Language',
                ),
              ),
              const SizedBox(height: 20),
              const Center(child: A9Logo()),
              const SizedBox(height: 36),
              Text(
                AppLocalizations.of(context)?.welcomeTitle ?? 'Welcome to A9',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)?.welcomeDescription ??
                    'A9 is a free, independent messenger with end-to-end encryption...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Checkbox(
                    value: _acceptedPolicy,
                    onChanged: (val) {
                      setState(() {
                        _acceptedPolicy = val ?? false;
                      });
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _acceptedPolicy = !_acceptedPolicy;
                        });
                      },
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: AppLocalizations.of(context)?.acceptPolicy ?? 'I accept the ',
                              style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                            ),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: theme.colorScheme.primary, 
                                fontSize: 14, 
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _acceptedPolicy ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _acceptedPolicy ? 4 : 0,
                ),
                child: Text(
                  AppLocalizations.of(context)?.continueText ?? 'Continue',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
