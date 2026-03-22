import 'package:flutter/material.dart';

class A9Logo extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const A9Logo({
    super.key,
    this.width = 80,
    this.height = 80,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          isDark
              ? 'assets/icon/a9-logo-dark.png'
              : 'assets/icon/a9-logo-light.png',
          fit: BoxFit.cover,
          // Handle cases where assets might be missing or renamed
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              'assets/icon/a9-logo-light.png',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.chat_rounded, size: 40);
              },
            );
          },
        ),
      ),
    );
  }
}
