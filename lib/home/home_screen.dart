import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/group/group_screen.dart';
import 'package:qui/home/_feed.dart';
import 'package:qui/home/_missing.dart';
import 'package:qui/home/_saved.dart';
import 'package:qui/home/home_model.dart';
import 'package:qui/substack/substack_screen.dart';
import 'package:qui/subscriptions/subscriptions.dart';
import 'package:qui/trends/trends_screen.dart';
import 'package:qui/ui/desktop_shell.dart';
import 'package:qui/ui/errors.dart';

typedef NavigationTitleBuilder = String Function(BuildContext context);

class NavigationPage {
  final String id;
  final NavigationTitleBuilder titleBuilder;
  final Widget icon;
  final Widget selectedIcon;

  NavigationPage(this.id, this.titleBuilder, this.icon, this.selectedIcon);
}

final List<NavigationPage> defaultHomePages = [
  // Icons lean toward Flare’s solid rail feel (outline when idle, filled when selected).
  NavigationPage('feed', (c) => L10n.of(c).home, const Icon(Icons.home_outlined), const Icon(Icons.home_rounded)),
  NavigationPage('subscriptions', (c) => L10n.of(c).subscriptions, const Icon(Icons.people_outline_rounded),
      const Icon(Icons.people_rounded)),
  NavigationPage(
      'trending', (c) => L10n.of(c).trending, const Icon(Icons.tag_outlined), const Icon(Icons.tag_rounded)),
  NavigationPage(
      'saved', (c) => L10n.of(c).saved, const Icon(Icons.bookmark_border_rounded), const Icon(Icons.bookmark_rounded)),
  NavigationPage('substack', (c) => L10n.of(c).substack, const Icon(Icons.newspaper_outlined),
      const Icon(Icons.newspaper_rounded)),
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context);
    var model = context.read<HomeModel>();

    return _HomeScreen(prefs: prefs, model: model);
  }
}

class _HomeScreen extends StatefulWidget {
  final BasePrefService prefs;
  final HomeModel model;

  const _HomeScreen({required this.prefs, required this.model});

  @override
  State<_HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_HomeScreen> {
  int _initialPage = 0;
  List<NavigationPage> _pages = [];

  @override
  void initState() {
    super.initState();

    _buildPages(widget.model.state);
    widget.model.observer(onState: _buildPages);
  }

  void _buildPages(List<HomePage> state) {
    var pages = state.where((element) => element.selected).map((e) => e.page).toList();

    if (widget.prefs.getKeys().contains(optionHomeInitialTab)) {
      _initialPage = max(0, pages.indexWhere((element) => element.id == widget.prefs.get(optionHomeInitialTab)));
    }

    setState(() {
      _pages = pages;
    });
  }

  final trendsFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<HomeModel, List<HomePage>>.transition(
      store: widget.model,
      onError: (_, e) => ScaffoldErrorWidget(
        prefix: L10n.current.unable_to_load_home_pages,
        error: e,
        stackTrace: null,
        onRetry: () async => await widget.model.resetPages(),
        retryText: L10n.current.reset_home_pages,
      ),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onState: (_, state) {
        return QuiShell(
          pages: _pages,
          prefs: widget.prefs,
          initialPage: _initialPage,
          builder: (scrollControllers, focusNodes) {
            return List.generate(_pages.length, (index) {
              final page = _pages[index];
              if (page.id.startsWith('group-')) {
                return SubscriptionGroupScreen(
                  scrollController: scrollControllers[index]!,
                  id: page.id.replaceAll('group-', ''),
                  name: '',
                );
              }
              switch (page.id) {
                case 'feed':
                  return FeedScreen(
                    scrollController: scrollControllers[index]!,
                    id: '-1',
                    name: L10n.current.feed,
                  );
                case 'subscriptions':
                  return SubscriptionsScreen(
                    scrollController: scrollControllers[index]!,
                  );
                case 'trending':
                  return TrendsScreen(
                    scrollController: scrollControllers[index]!,
                    focusNode: focusNodes[index]!,
                  );
                case 'saved':
                  return SavedScreen(
                    scrollController: scrollControllers[index]!,
                  );
                case 'substack':
                  return SubstackScreen(
                    scrollController: scrollControllers[index]!,
                  );
                default:
                  return const MissingScreen();
              }
            });
          },
        );
      },
    );
  }
}
