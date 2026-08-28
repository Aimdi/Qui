import 'package:flutter/material.dart';
import 'package:qui/ui/layout.dart';

/// A bottom sheet on a phone, a dialog on desktop.
///
/// XTA is a phone app, so its extra actions live in sheets. On a PC those
/// sheets hug the bottom of a tall window and feel like a leftover. A dialog
/// sits where the mouse is looking.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool showDragHandle = true,
  bool isScrollControlled = false,
}) {
  if (useDesktopShell(context)) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: isScrollControlled ? 640 : 560,
          ),
          child: builder(dialogContext),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    useSafeArea: isScrollControlled,
    builder: builder,
  );
}
