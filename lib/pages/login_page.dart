import 'package:flutter/material.dart';
import '../services/auth/auth_service.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/language/language_provider.dart';
import '../components/a9_logo.dart';

class LoginPage extends StatefulWidget {
  final void Function()? onTap;
  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> login() async {
    if (_emailController.text.trim().isEmpty ||
        _pwController.text.trim().isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithEmailPassword(
        _emailController.text.trim(),
        _pwController.text,
      );
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Text(
                  l10n.loginFailed,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                content: Text(e.toString()),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0084FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.ok),
                  ),
                ],
              ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          PopupMenuButton<Locale>(
            icon: Icon(Icons.language, color: theme.colorScheme.primary),
            onSelected: (Locale locale) {
              Provider.of<LanguageProvider>(
                context,
                listen: false,
              ).setLocale(locale);
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: Locale('en'),
                    child: Text('English'),
                  ),
                  const PopupMenuItem(
                    value: Locale('fr'),
                    child: Text('Français'),
                  ),
                  const PopupMenuItem(
                    value: Locale('de'),
                    child: Text('Deutsch'),
                  ),
                  const PopupMenuItem(
                    value: Locale('ru'),
                    child: Text('Русский'),
                  ),
                  const PopupMenuItem(
                    value: Locale('es'),
                    child: Text('Español'),
                  ),
                ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Logo
              const Center(child: A9Logo()),
              const SizedBox(height: 36),
              Text(
                l10n.welcomeBack,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.signInToContinue,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              ),
              const SizedBox(height: 40),
              // Email field
              _buildLabel(l10n.email, isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'your@email.com',
                icon: Icons.email_outlined,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              // Password field
              _buildLabel(l10n.password, isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _pwController,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                obscure: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 32),
              // Login button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : login,
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
                      _isLoading
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            l10n.login,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 32),
              // Register link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${l10n.dontHaveAccount} ",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Text(
                      l10n.signUp,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF1C1E21),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1C1E21),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
