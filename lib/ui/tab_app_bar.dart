import 'package:flutter/material.dart';
import 'package:qui/ui/layout.dart';

/// App bar for a home tab that already sits inside the desktop rail.
///
/// The rail names the tab, so a second title and a back button read as a
/// leftover phone screen. Actions and [bottom] stay — those are the actual
/// controls.
AppBar tabAppBar({
  required BuildContext context,
  Widget? title,
  List<Widget>? actions,
  PreferredSizeWidget? bottom,
  Widget? flexibleSpace,
  double? toolbarHeight,
  bool hideTitleOnDesktop = true,
}) {
  final desktop = useDesktopShell(context);
  return AppBar(
    automaticallyImplyLeading: false,
    title: (desktop && hideTitleOnDesktop) ? null : title,
    actions: actions,
    bottom: bottom,
    flexibleSpace: flexibleSpace,
    toolbarHeight: toolbarHeight,
  );
}
