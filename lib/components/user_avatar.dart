import 'package:flutter/material.dart';
import 'package:googlechat/services/user/user_service.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarBase64;
  final String displayName;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    required this.displayName,
    this.avatarBase64,
    this.radius = 24,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = UserService.decodeAvatar(avatarBase64);

    if (bytes != null) {
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      );
    }

    // Deterministic color from name
    final List<Color> palette = [
      const Color(0xFF0084FF),
      const Color(0xFF44BEC7),
      const Color(0xFFFFC300),
      const Color(0xFFFA3C4C),
      const Color(0xFFD696BB),
      const Color(0xFF6699CC),
      const Color(0xFF7B68EE),
      const Color(0xFF20B2AA),
    ];
    final int colorIdx =
        displayName.isEmpty
            ? 0
            : displayName.codeUnits.fold(0, (a, b) => a + b) % palette.length;
    final avatarColor = backgroundColor ?? palette[colorIdx];
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: avatarColor.withValues(alpha: 0.18),
      child: Text(
        initial,
        style: TextStyle(
          color: avatarColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
