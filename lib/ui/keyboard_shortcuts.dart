import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// How far j/k jump the current feed. Roughly one post card.
const double desktopFeedStep = 420;

/// True when a text field currently has keyboard focus, so character shortcuts
/// must not steal keystrokes the reader is typing.
bool shortcutTargetIsTextInput() {
  final focus = FocusManager.instance.primaryFocus;
  final context = focus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null ||
      context.findAncestorWidgetOfExactType<TextField>() != null ||
      context.findAncestorWidgetOfExactType<TextFormField>() != null;
}

/// Desktop keys that XTA never needed: the phone has no keyboard.
///
/// * `j` / `k` — next / previous post (scroll the current feed)
/// * `/` — search
/// * `Escape` — close the reading pane
/// * `1`–`9` — switch rail tabs
/// * Ctrl/Cmd+, — settings
class DesktopKeyboardShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onClosePane;
  final VoidCallback onScrollNext;
  final VoidCallback onScrollPrevious;
  final ValueChanged<int> onSelectTab;

  const DesktopKeyboardShortcuts({
    super.key,
    required this.child,
    required this.onSearch,
    required this.onSettings,
    required this.onClosePane,
    required this.onScrollNext,
    required this.onScrollPrevious,
    required this.onSelectTab,
  });

  void _unlessEditing(VoidCallback action) {
    if (shortcutTargetIsTextInput()) return;
    action();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash): () =>
            _unlessEditing(onSearch),
        const SingleActivator(LogicalKeyboardKey.keyJ): () =>
            _unlessEditing(onScrollNext),
        const SingleActivator(LogicalKeyboardKey.keyK): () =>
            _unlessEditing(onScrollPrevious),
        const SingleActivator(LogicalKeyboardKey.escape): onClosePane,
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            onSettings,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true): onSettings,
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _unlessEditing(() => onSelectTab(0)),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _unlessEditing(() => onSelectTab(1)),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _unlessEditing(() => onSelectTab(2)),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _unlessEditing(() => onSelectTab(3)),
        const SingleActivator(LogicalKeyboardKey.digit5): () =>
            _unlessEditing(() => onSelectTab(4)),
        const SingleActivator(LogicalKeyboardKey.digit6): () =>
            _unlessEditing(() => onSelectTab(5)),
        const SingleActivator(LogicalKeyboardKey.digit7): () =>
            _unlessEditing(() => onSelectTab(6)),
        const SingleActivator(LogicalKeyboardKey.digit8): () =>
            _unlessEditing(() => onSelectTab(7)),
        const SingleActivator(LogicalKeyboardKey.digit9): () =>
            _unlessEditing(() => onSelectTab(8)),
      },
      child: Focus(
        autofocus: true,
        canRequestFocus: true,
        skipTraversal: true,
        child: child,
      ),
    );
  }
}

/// Scrolls [controller] by one feed step. Negative [direction] goes up.
void scrollFeedByStep(ScrollController? controller, {required int direction}) {
  if (controller == null || !controller.hasClients) return;
  final position = controller.position;
  final target = (position.pixels + direction * desktopFeedStep).clamp(
    position.minScrollExtent,
    position.maxScrollExtent,
  );
  controller.animateTo(
    target,
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
  );
}
