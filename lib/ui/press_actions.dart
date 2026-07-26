import 'package:flutter/material.dart';

/// Keeps a touch-first "long-press" action reachable on desktop.
///
/// QuaX-fix (the mobile app) hides several actions behind a long-press — quick
/// image download, save-to-folder, reveal replies, delete, edit, translate a
/// whole thread, etc. On the PC port those gestures are undiscoverable with a
/// mouse, so [PressActions] fires [onInvoke] on BOTH long-press (touch) and
/// secondary tap / right-click (mouse), while [onTap] keeps the primary tap.
class PressActions extends StatelessWidget {
  final Widget child;
  final VoidCallback? onInvoke;
  final GestureTapCallback? onTap;
  final HitTestBehavior? behavior;

  const PressActions({
    super.key,
    required this.child,
    this.onInvoke,
    this.onTap,
    this.behavior,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: onTap,
      onLongPress: onInvoke,
      onSecondaryTap: onInvoke,
      child: child,
    );
  }
}
