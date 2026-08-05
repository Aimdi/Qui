import 'dart:math';

import 'package:flutter/material.dart';
import 'package:qui/home/home_screen.dart';
import 'package:qui/ui/layout.dart';

/// Multi-column body used by deck mode (Flare / TweetDeck style).
///
/// Each selected home tab is a fixed-width column. With [rows] == 1 the columns
/// form a single horizontal strip; with [rows] > 1 they wrap into that many
/// stacked, independently-scrolling rows (a grid). Tapping the rail scrolls the
/// column into view and focuses it.
class DeckBody extends StatefulWidget {
  final List<NavigationPage> pages;
  final List<Widget> children;
  final int focusedIndex;
  final ValueChanged<int> onFocusChanged;
  final ScrollController? scrollController;

  /// Number of stacked rows the columns wrap into (clamped to 1..4).
  final int rows;

  const DeckBody({
    super.key,
    required this.pages,
    required this.children,
    required this.focusedIndex,
    required this.onFocusChanged,
    this.scrollController,
    this.rows = 1,
  });

  @override
  State<DeckBody> createState() => DeckBodyState();
}

class DeckBodyState extends State<DeckBody> {
  // Single-row scroll controller (rows == 1), possibly provided by the shell.
  late ScrollController _scrollController;
  bool _ownedController = false;
  // One controller per row when rows > 1.
  final List<ScrollController> _rowControllers = [];

  double get _extent => quiDeckColumnWidth + 1; // column + divider

  int get _rows => widget.rows.clamp(1, 4);

  // Columns per row (ceil), so rows fill left-to-right, top-to-bottom.
  int get _perRow {
    final n = widget.children.length;
    if (_rows <= 1 || n == 0) return n;
    return (n + _rows - 1) ~/ _rows;
  }

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownedController = true;
    }
    _ensureRowControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToIndex(widget.focusedIndex, animate: false);
    });
  }

  void _ensureRowControllers() {
    final needed = _rows <= 1 ? 0 : _rows;
    if (_rowControllers.length == needed) return;
    for (final c in _rowControllers) {
      c.dispose();
    }
    _rowControllers
      ..clear()
      ..addAll(List.generate(needed, (_) => ScrollController()));
  }

  @override
  void didUpdateWidget(covariant DeckBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final layoutChanged = oldWidget.rows != widget.rows ||
        oldWidget.children.length != widget.children.length;
    if (layoutChanged) {
      _ensureRowControllers();
      // Controllers/strips only attach next frame; scroll once they exist.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) scrollToIndex(widget.focusedIndex, animate: false);
      });
    } else if (oldWidget.focusedIndex != widget.focusedIndex) {
      scrollToIndex(widget.focusedIndex);
    }
  }

  /// Bring [index] into view (rail navigation).
  void scrollToIndex(int index, {bool animate = true}) {
    if (widget.children.isEmpty) return;

    if (_rows <= 1) {
      _scrollController_scrollTo(_scrollController, index * _extent, animate);
      return;
    }

    final perRow = _perRow;
    if (perRow <= 0) return;
    final row = (index ~/ perRow).clamp(0, _rowControllers.length - 1);
    final local = index % perRow;
    _scrollController_scrollTo(_rowControllers[row], local * _extent, animate);
  }

  void _scrollController_scrollTo(ScrollController controller, double raw, bool animate) {
    if (!controller.hasClients) return;
    final target = raw.clamp(0.0, controller.position.maxScrollExtent);
    if (animate) {
      controller.animateTo(target,
          duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      controller.jumpTo(target);
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
    for (final c in _rowControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildColumn(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
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
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.pages.length == widget.children.length);
    if (_rows <= 1) return _buildSingleRow(context);
    return _buildGrid(context);
  }

  Widget _buildSingleRow(BuildContext context) {
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
        itemBuilder: (context, index) => _buildColumn(context, index),
      ),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final perRow = _perRow;
    final n = widget.children.length;

    final strips = <Widget>[];
    for (var r = 0; r < _rows; r++) {
      final start = r * perRow;
      if (start >= n) break;
      final end = min(start + perRow, n);
      if (strips.isNotEmpty) {
        strips.add(Divider(
            height: 1, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.45)));
      }
      strips.add(Expanded(
        child: ListView.builder(
          controller: _rowControllers[r],
          scrollDirection: Axis.horizontal,
          itemCount: end - start,
          itemExtent: _extent,
          itemBuilder: (context, i) => _buildColumn(context, start + i),
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: strips);
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
