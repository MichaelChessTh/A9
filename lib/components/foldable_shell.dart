import 'dart:ui' show DisplayFeatureType;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:googlechat/l10n/app_localizations.dart';
import 'package:googlechat/pages/chat_page.dart';
import 'package:googlechat/pages/group_chat_page.dart';
import 'package:googlechat/pages/home_page.dart';
import 'package:googlechat/services/layout/foldable_controller.dart';

/// Returns true when the device is a foldable / large tablet.
bool isFoldableDevice(BuildContext context) {
  final mq = MediaQuery.of(context);
  final hasFold = mq.displayFeatures.any(
    (f) =>
        f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge,
  );
  if (hasFold) return true;
  final size = mq.size;
  return size.width >= 600 && size.width > size.height;
}

/// Top-level shell: transparent on phones, two-pane split on foldables.
class FoldableShell extends StatelessWidget {
  const FoldableShell({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FoldableController(),
      child: const _FoldableShellBody(),
    );
  }
}

class _FoldableShellBody extends StatelessWidget {
  const _FoldableShellBody();

  @override
  Widget build(BuildContext context) {
    if (!isFoldableDevice(context)) {
      return const HomePage();
    }
    return const _SplitLayout();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Two-pane layout with draggable divider
// ─────────────────────────────────────────────────────────────────────────────

class _SplitLayout extends StatefulWidget {
  const _SplitLayout();

  @override
  State<_SplitLayout> createState() => _SplitLayoutState();
}

class _SplitLayoutState extends State<_SplitLayout> {
  // leftFlex : rightFlex — starts at 40:60; user can flip to 60:40
  double _leftRatio = 0.40; // fraction [0.25 … 0.75]

  static const double _minRatio = 0.25;
  static const double _maxRatio = 0.75;
  static const double _handleWidth = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ctrl = context.watch<FoldableController>();
    final totalWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ── Main row ──────────────────────────────────────────────
          Row(
            children: [
              // Left pane
              SizedBox(
                width: totalWidth * _leftRatio,
                child: ClipRect(
                  child: Navigator(
                    key: const ValueKey('home_nav'),
                    onGenerateRoute:
                        (_) => MaterialPageRoute(
                          builder: (_) => const _HomeAdapter(),
                        ),
                  ),
                ),
              ),

              // Thin divider line
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.25),
              ),

              // Right pane
              Expanded(
                child: ClipRect(
                  child:
                      ctrl.hasChat
                          ? _buildChatPane(ctrl)
                          : _buildEmptyPane(context, theme),
                ),
              ),
            ],
          ),

          // ── Draggable handle (centered on the divider) ─────────────
          Positioned(
            left: totalWidth * _leftRatio - _handleWidth / 2,
            top: 0,
            bottom: 0,
            width: _handleWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _leftRatio = (_leftRatio + details.delta.dx / totalWidth)
                      .clamp(_minRatio, _maxRatio);
                });
              },
              child: Center(
                child: Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPane(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 72,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              l10n?.selectChatHint ?? 'Select a chat to open',
              style: TextStyle(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPane(FoldableController ctrl) {
    if (ctrl.isGroupChat) {
      return KeyedSubtree(
        key: ValueKey('group_${ctrl.groupId}'),
        child: Navigator(
          onGenerateRoute:
              (_) => MaterialPageRoute(
                builder:
                    (_) => GroupChatPage(
                      groupId: ctrl.groupId!,
                      initialGroupName: ctrl.groupName!,
                    ),
              ),
        ),
      );
    } else {
      return KeyedSubtree(
        key: ValueKey('dm_${ctrl.receiverID}'),
        child: Navigator(
          onGenerateRoute:
              (_) => MaterialPageRoute(
                builder:
                    (_) => ChatPage(
                      receiverEmail: ctrl.receiverEmail!,
                      receiverID: ctrl.receiverID!,
                    ),
              ),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home adapter — intercepts chat-open in foldable mode
// ─────────────────────────────────────────────────────────────────────────────

class _HomeAdapter extends StatelessWidget {
  const _HomeAdapter();

  @override
  Widget build(BuildContext context) {
    // Use listen:false because we only need to call methods, not rebuild
    final ctrl = context.read<FoldableController>();

    return HomePage(
      onOpenDirectChat: (email, uid) {
        ctrl.openDirectChat(receiverEmail: email, receiverID: uid);
      },
      onOpenGroupChat: (groupId, groupName) {
        ctrl.openGroupChat(groupId: groupId, groupName: groupName);
      },
    );
  }
}
