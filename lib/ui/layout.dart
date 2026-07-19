import 'package:flutter/material.dart';

/// Breakpoints inspired by Flare’s desktop shell and common Material adaptive
/// sizes. Qui keeps a phone-style bottom bar under [compact], and a Flare-like
/// left rail above it.
class QuiBreakpoints {
  static const double compact = 700;
  static const double medium = 1000;
  static const double expanded = 1280;
}

/// Flare keeps the primary timeline around this width on desktop.
const double quiTimelineMaxWidth = 640;

/// Secondary column (trends / discover) width on expanded desktops.
const double quiSidePanelWidth = 320;

/// Rail width matches Flare’s ~72dp icon strip.
const double quiNavRailWidth = 72;

/// Width of one deck column (Flare uses ~360; slightly roomier for Qui cards).
const double quiDeckColumnWidth = 380;

bool isCompactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < QuiBreakpoints.compact;

bool isMediumLayout(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= QuiBreakpoints.compact && w < QuiBreakpoints.expanded;
}

bool isExpandedLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= QuiBreakpoints.expanded;

/// Whether to use the Flare-style left rail instead of a bottom navigation bar.
bool useDesktopShell(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= QuiBreakpoints.compact;

/// Centers [child] and caps its width — Flare-style main timeline column.
class ContentFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ContentFrame({
    super.key,
    required this.child,
    this.maxWidth = quiTimelineMaxWidth,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
