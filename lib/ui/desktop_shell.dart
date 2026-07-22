import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/home/home_screen.dart';
import 'package:qui/search/search.dart';
import 'package:qui/trends/_list.dart';
import 'package:qui/ui/layout.dart';
import 'package:qui/ui/deck.dart';
import 'package:qui/ui/detail_pane.dart';

/// Flare-inspired adaptive chrome for Qui.
///
/// * **Compact** (phone): bottom [NavigationBar] + drawer.
/// * **Medium+** (desktop): left icon rail (~72px), centered main column, and
///   on wide screens a trends side panel — same idea as Flare’s desktop shell.
class QuiShell extends StatefulWidget {
  final List<NavigationPage> pages;
  final BasePrefService prefs;
  final int initialPage;
  final List<Widget> Function(
    Map<int, ScrollController> scrollControllers,
    Map<int, FocusNode> focusNodes,
  ) builder;

  const QuiShell({
    super.key,
    required this.pages,
    required this.prefs,
    required this.initialPage,
    required this.builder,
  });

  @override
  State<QuiShell> createState() => _QuiShellState();
}

class _QuiShellState extends State<QuiShell> {
  late PageController _pageController;
  late int _currentPage;
  final Map<int, ScrollController> _scrollControllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  late final ScrollController _sideTrendsController;
  late final ScrollController _deckScrollController;
  final GlobalKey<DeckBodyState> _deckKey = GlobalKey<DeckBodyState>();
  final DetailPaneController _detailPaneController = DetailPaneController();
  bool _deckMode = false;

  void unfocusOtherPages() {
    _focusNodes.forEach((index, focusNode) {
      if (index != _currentPage) {
        focusNode.unfocus();
      }
    });
  }

  void _onDeckModePref() {
    if (!mounted) return;
    final enabled = widget.prefs.get(optionDeckMode) == true;
    if (enabled != _deckMode) {
      setState(() => _deckMode = enabled);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage);
    _sideTrendsController = ScrollController();
    _deckScrollController = ScrollController();
    _deckMode = widget.prefs.get(optionDeckMode) == true;
    widget.prefs.addKeyListener(optionDeckMode, _onDeckModePref);
    _ensureControllers(widget.pages.length);
  }

  void _ensureControllers(int count) {
    for (int i = 0; i < count; i++) {
      _scrollControllers.putIfAbsent(i, ScrollController.new);
      _focusNodes.putIfAbsent(i, FocusNode.new);
    }
    final stale = _scrollControllers.keys.where((k) => k >= count).toList();
    for (final k in stale) {
      _scrollControllers.remove(k)?.dispose();
      _focusNodes.remove(k)?.dispose();
    }
  }

  @override
  void didUpdateWidget(covariant QuiShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pages.length != oldWidget.pages.length) {
      _ensureControllers(widget.pages.length);
      if (_currentPage >= widget.pages.length && widget.pages.isNotEmpty) {
        _currentPage = widget.pages.length - 1;
      }
    }
  }

  Future<void> _selectPage(int index) async {
    if (index < 0 || index >= widget.pages.length) return;
    if (index == _currentPage) {
      final tappedId = widget.pages[index].id;
      if (tappedId == 'feed' || tappedId.startsWith('group-')) {
        final scrollController = _scrollControllers[_currentPage];
        if (scrollController != null && scrollController.hasClients) {
          await scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      }
      if (tappedId == 'trending') {
        _focusNodes[_currentPage]?.requestFocus();
      }
      return;
    }
    unfocusOtherPages();
    setState(() => _currentPage = index);
    if (_deckMode && useDesktopShell(context)) {
      _deckKey.currentState?.scrollToIndex(index);
    } else if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    }
  }

  void _openSearch() {
    Navigator.pushNamed(
      context,
      routeSearch,
      arguments: SearchArguments(0, focusInputOnOpen: true),
    );
  }

  void _openSettings() {
    Navigator.pushNamed(context, routeSettings);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = useDesktopShell(context);
    final pages = widget.builder(_scrollControllers, _focusNodes);

    if (!desktop) {
      return _MobileShell(
        pages: widget.pages,
        prefs: widget.prefs,
        currentPage: _currentPage,
        pageController: _pageController,
        pageChildren: pages,
        onPageChanged: (page) => setState(() => _currentPage = page),
        onDestinationSelected: _selectPage,
        onSearch: _openSearch,
        onSettings: _openSettings,
      );
    }

    return DetailPaneScope(
      controller: _detailPaneController,
      child: _DesktopShell(
        pages: widget.pages,
        prefs: widget.prefs,
        currentPage: _currentPage,
        pageController: _pageController,
        pageChildren: pages,
        sideTrendsController: _sideTrendsController,
        deckScrollController: _deckScrollController,
        deckKey: _deckKey,
        deckMode: _deckMode,
        onPageChanged: (page) => setState(() => _currentPage = page),
        onDestinationSelected: _selectPage,
        onSearch: _openSearch,
        onSettings: _openSettings,
      ),
    );
  }

  @override
  void dispose() {
    widget.prefs.removeKeyListener(optionDeckMode, _onDeckModePref);
    _pageController.dispose();
    _sideTrendsController.dispose();
    _deckScrollController.dispose();
    _detailPaneController.dispose();
    for (final c in _scrollControllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }
}

class _MobileShell extends StatelessWidget {
  final List<NavigationPage> pages;
  final BasePrefService prefs;
  final int currentPage;
  final PageController pageController;
  final List<Widget> pageChildren;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(int) onDestinationSelected;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  const _MobileShell({
    required this.pages,
    required this.prefs,
    required this.currentPage,
    required this.pageController,
    required this.pageChildren,
    required this.onPageChanged,
    required this.onDestinationSelected,
    required this.onSearch,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final safeIndex = pages.isEmpty ? 0 : currentPage.clamp(0, pages.length - 1);
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: Text(l10n.search),
              onTap: () {
                Navigator.pop(context);
                onSearch();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: Text(l10n.settings),
              onTap: () {
                Navigator.pop(context);
                onSettings();
              },
            ),
          ],
        ),
      ),
      body: PageView(
        controller: pageController,
        onPageChanged: onPageChanged,
        children: pageChildren,
      ),
      bottomNavigationBar: pages.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: safeIndex,
              labelBehavior: prefs.get(optionShowNavigationLabels)
                  ? NavigationDestinationLabelBehavior.alwaysShow
                  : NavigationDestinationLabelBehavior.alwaysHide,
              shadowColor: Colors.transparent,
              backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              height: 64,
              destinations: pages
                  .map(
                    (page) => NavigationDestination(
                      icon: page.icon,
                      selectedIcon: page.selectedIcon,
                      label: page.titleBuilder(context),
                    ),
                  )
                  .toList(),
              onDestinationSelected: (i) => onDestinationSelected(i),
            ),
    );
  }
}

class _DesktopShell extends StatelessWidget {
  final List<NavigationPage> pages;
  final BasePrefService prefs;
  final int currentPage;
  final PageController pageController;
  final List<Widget> pageChildren;
  final ScrollController sideTrendsController;
  final ScrollController deckScrollController;
  final GlobalKey<DeckBodyState> deckKey;
  final bool deckMode;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function(int) onDestinationSelected;
  final VoidCallback onSearch;
  final VoidCallback onSettings;

  const _DesktopShell({
    required this.pages,
    required this.prefs,
    required this.currentPage,
    required this.pageController,
    required this.pageChildren,
    required this.sideTrendsController,
    required this.deckScrollController,
    required this.deckKey,
    required this.deckMode,
    required this.onPageChanged,
    required this.onDestinationSelected,
    required this.onSearch,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showLabels = prefs.get(optionShowNavigationLabels) == true;
    final safeIndex = pages.isEmpty ? 0 : currentPage.clamp(0, pages.length - 1);
    // The right column hosts either the opened thread (master/detail reading
    // pane) or, on the home feed with nothing selected, the trends panel.
    final pane = DetailPaneScope.maybeOf(context);
    final hasDetail = pane != null && pane.hasSelection;
    final showFeedTrends = !deckMode &&
        isExpandedLayout(context) &&
        pages.isNotEmpty &&
        pages[safeIndex].id == 'feed';
    final showRightPane =
        !deckMode && isExpandedLayout(context) && (hasDetail || showFeedTrends);

    final railBg = scheme.surfaceContainerLow;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Row(
        children: [
          Material(
            color: railBg,
            child: SafeArea(
              right: false,
              child: SizedBox(
                width: quiNavRailWidth,
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Tooltip(
                      message: 'Qui',
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primary,
                              scheme.tertiary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(Icons.bolt_rounded, color: scheme.onPrimary, size: 22),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: pages.length,
                        itemBuilder: (context, index) {
                          final page = pages[index];
                          final selected = index == safeIndex;
                          return _RailDestination(
                            selected: selected,
                            icon: selected ? page.selectedIcon : page.icon,
                            label: showLabels ? page.titleBuilder(context) : null,
                            tooltip: page.titleBuilder(context),
                            onTap: () => onDestinationSelected(index),
                          );
                        },
                      ),
                    ),
                    _RailDestination(
                      selected: false,
                      icon: const Icon(Icons.search_rounded),
                      label: showLabels ? L10n.of(context).search : null,
                      tooltip: L10n.of(context).search,
                      onTap: onSearch,
                    ),
                    _RailDestination(
                      selected: deckMode,
                      icon: Icon(deckMode ? Icons.view_column_rounded : Icons.view_column_outlined),
                      label: showLabels ? L10n.of(context).deck_mode : null,
                      tooltip: L10n.of(context).deck_mode,
                      onTap: () {
                        prefs.set(optionDeckMode, !deckMode);
                      },
                    ),
                    _RailDestination(
                      selected: false,
                      icon: const Icon(Icons.settings_outlined),
                      label: showLabels ? L10n.of(context).settings : null,
                      tooltip: L10n.of(context).settings,
                      onTap: onSettings,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: ColoredBox(
              color: scheme.surface,
              child: deckMode
                  ? DeckBody(
                      key: deckKey,
                      pages: pages,
                      children: pageChildren,
                      focusedIndex: safeIndex,
                      scrollController: deckScrollController,
                      onFocusChanged: onPageChanged,
                    )
                  : ContentFrame(
                      maxWidth: showRightPane ? quiTimelineMaxWidth + 16 : quiTimelineMaxWidth + 40,
                      child: PageView(
                        controller: pageController,
                        onPageChanged: onPageChanged,
                        physics: const NeverScrollableScrollPhysics(),
                        children: pageChildren,
                      ),
                    ),
            ),
          ),
          if (showRightPane) ...[
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            SizedBox(
              width: hasDetail ? quiDetailPaneWidth : quiSidePanelWidth,
              child: Material(
                color: hasDetail ? scheme.surface : railBg,
                child: SafeArea(
                  left: false,
                  child: hasDetail
                      ? DetailPane(controller: pane)
                      : _SideDiscoverPanel(
                          onOpenSearch: onSearch,
                          scrollController: sideTrendsController,
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RailDestination extends StatelessWidget {
  final bool selected;
  final Widget icon;
  final String? label;
  final String tooltip;
  final VoidCallback onTap;

  const _RailDestination({
    required this.selected,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: 48,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? scheme.secondaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconTheme(
              data: IconThemeData(
                size: 22,
                color: selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
              ),
              child: Center(child: icon),
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 10,
                  ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}

class _SideDiscoverPanel extends StatelessWidget {
  final VoidCallback onOpenSearch;
  final ScrollController scrollController;

  const _SideDiscoverPanel({
    required this.onOpenSearch,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onOpenSearch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.search,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.trending,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: TrendsList(scrollController: scrollController),
        ),
      ],
    );
  }
}
