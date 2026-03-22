import 'package:flutter/material.dart';
import '../services/auth/auth_service.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/language/language_provider.dart';
import '../components/a9_logo.dart';

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;
  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  Future<void> register() async {
    final l10n = AppLocalizations.of(context)!;
    if (_pwController.text != _confirmPwController.text) {
      _showError(l10n.passwordsDontMatch, l10n);
      return;
    }
    if (_emailController.text.trim().isEmpty || _pwController.text.isEmpty) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().signUpWithEmailPassword(
        _emailController.text.trim(),
        _pwController.text,
      );
    } catch (e) {
      _showError(e.toString(), l10n);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              l10n.error,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(message),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.primary,
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
                l10n.createAccount,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.signUpAndChat,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
              ),
              const SizedBox(height: 40),
              _buildLabel(l10n.email, isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'your@email.com',
                icon: Icons.email_outlined,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildLabel(l10n.password, isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _pwController,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                obscure: _obscurePw,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePw
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePw = !_obscurePw),
                ),
              ),
              const SizedBox(height: 20),
              _buildLabel(l10n.confirmPassword, isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _confirmPwController,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                isDark: isDark,
                obscure: _obscureConfirm,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed:
                      () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : register,
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
                            l10n.createAccount,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${l10n.alreadyHaveAccount} ',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  GestureDetector(
                    onTap: widget.onTap,
                    child: Text(
                      l10n.login,
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
