import 'package:flutter/material.dart';
import 'package:qui/home/home_screen.dart';
import 'package:qui/ui/layout.dart';

/// Horizontal multi-column body used by deck mode (Flare / TweetDeck style).
///
/// Each selected home tab is a fixed-width column. Tapping the rail scrolls
/// the deck so that column is visible and focused.
class DeckBody extends StatefulWidget {
  final List<NavigationPage> pages;
  final List<Widget> children;
  final int focusedIndex;
  final ValueChanged<int> onFocusChanged;
  final ScrollController? scrollController;

  const DeckBody({
    super.key,
    required this.pages,
    required this.children,
    required this.focusedIndex,
    required this.onFocusChanged,
    this.scrollController,
  });

  @override
  State<DeckBody> createState() => DeckBodyState();
}

class DeckBodyState extends State<DeckBody> {
  late ScrollController _scrollController;
  bool _ownedController = false;

  double get _extent => quiDeckColumnWidth + 1; // column + divider

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownedController = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToIndex(widget.focusedIndex, animate: false);
    });
  }

  @override
  void didUpdateWidget(covariant DeckBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedIndex != widget.focusedIndex) {
      scrollToIndex(widget.focusedIndex);
    }
  }

  /// Bring [index] into view (rail navigation).
  void scrollToIndex(int index, {bool animate = true}) {
    if (!_scrollController.hasClients) return;
    if (widget.children.isEmpty) return;
    final max = _scrollController.position.maxScrollExtent;
    final target = (index * _extent).clamp(0.0, max);
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || widget.children.isEmpty) return;
    final offset = _scrollController.offset;
    final index = (offset / _extent).round().clamp(0, widget.children.length - 1);
    if (index != widget.focusedIndex) {
      widget.onFocusChanged(index);
    }
  }

  @override
  void dispose() {
    if (_ownedController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    assert(widget.pages.length == widget.children.length);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification && n.metrics.axis == Axis.horizontal) {
          _onScroll();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        // Keep all columns alive so feeds keep their scroll position / cache.
        itemCount: widget.children.length,
        itemExtent: _extent,
        itemBuilder: (context, index) {
          final page = widget.pages[index];
          final focused = index == widget.focusedIndex;
          return DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: quiDeckColumnWidth,
              child: DeckColumn(
                title: page.titleBuilder(context),
                icon: focused ? page.selectedIcon : page.icon,
                focused: focused,
                child: widget.children[index],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One deck column: compact header strip + the tab body.
class DeckColumn extends StatelessWidget {
  final String title;
  final Widget icon;
  final bool focused;
  final Widget child;

  const DeckColumn({
    super.key,
    required this.title,
    required this.icon,
    required this.focused,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: focused ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
          child: SafeArea(
            bottom: false,
            left: false,
            right: false,
            child: SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconTheme(
                      data: IconThemeData(
                        size: 18,
                        color: focused ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      child: icon,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: focused ? FontWeight.w700 : FontWeight.w600,
                          color: focused ? scheme.onSurface : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
        Expanded(
          // Isolate each column so nested Scaffolds / NestedScrollViews
          // don't fight for the primary scroll position.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
