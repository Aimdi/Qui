import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:qui/constants.dart';
import 'package:qui/status.dart';
import 'package:qui/ui/layout.dart';

/// Holds the post currently shown in the desktop master/detail reading pane.
///
/// Folo-style desktop reading: tapping a post in the timeline opens its thread
/// in a persistent right-hand pane instead of pushing a full-screen route, so
/// the timeline stays put. A small navigation stack lets the reader drill into
/// replies/quoted posts inside the pane and step back out again.
class DetailPaneController extends ChangeNotifier {
  final List<StatusScreenArguments> _stack = [];

  StatusScreenArguments? get current => _stack.isEmpty ? null : _stack.last;
  bool get hasSelection => _stack.isNotEmpty;
  bool get canGoBack => _stack.length > 1;

  void open(StatusScreenArguments args) {
    // Re-tapping the post that's already on top is a no-op; it would otherwise
    // stack a duplicate and turn the close button into a pointless "back".
    if (_stack.isNotEmpty && _stack.last.id == args.id) return;
    _stack.add(args);
    notifyListeners();
  }

  void back() {
    if (_stack.length <= 1) return;
    _stack.removeLast();
    notifyListeners();
  }

  void close() {
    if (_stack.isEmpty) return;
    _stack.clear();
    notifyListeners();
  }
}

/// Exposes the [DetailPaneController] to the widget subtree of the desktop
/// shell. Only mounted for the desktop shell, so its absence (mobile/compact,
/// or a pushed full-screen route) is how [openStatus] decides to fall back to
/// normal route navigation.
class DetailPaneScope extends InheritedNotifier<DetailPaneController> {
  const DetailPaneScope({
    super.key,
    required DetailPaneController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Subscribes the caller to changes (use from `build`).
  static DetailPaneController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailPaneScope>()?.notifier;

  /// Reads without creating a dependency (use from callbacks/handlers).
  static DetailPaneController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DetailPaneScope>()?.notifier;
}

/// Opens a post's thread. On expanded desktop (and outside deck mode) it opens
/// in the reading pane; everywhere else it pushes the usual full-screen route.
void openStatus(BuildContext context, StatusScreenArguments args) {
  final controller = DetailPaneScope.read(context);
  final deckMode = PrefService.of(context, listen: false).get(optionDeckMode) == true;
  if (controller != null && isExpandedLayout(context) && !deckMode) {
    controller.open(args);
  } else {
    Navigator.pushNamed(context, routeStatus, arguments: args);
  }
}

/// The reading pane itself: renders the selected thread via [StatusScreen] with
/// a back/close affordance in place of the route back button.
class DetailPane extends StatelessWidget {
  final DetailPaneController controller;

  const DetailPane({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final args = controller.current;
    if (args == null) return const SizedBox.shrink();
    return StatusScreen(
      // Rebuild the whole thread view when the selected post changes.
      key: ValueKey(args.id),
      arguments: args,
      leading: IconButton(
        tooltip: controller.canGoBack
            ? MaterialLocalizations.of(context).backButtonTooltip
            : MaterialLocalizations.of(context).closeButtonTooltip,
        icon: Icon(controller.canGoBack ? Icons.arrow_back_rounded : Icons.close_rounded),
        onPressed: controller.canGoBack ? controller.back : controller.close,
      ),
    );
  }
}
