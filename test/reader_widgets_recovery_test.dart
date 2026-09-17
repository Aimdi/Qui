import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/client/client.dart';
import 'package:qui/plugins/plugin.dart';
import 'package:qui/plugins/plugin_reader.dart';
import 'package:qui/tweet/paginated_tweet_list.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: const [
    L10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: L10n.delegate.supportedLocales,
  home: Scaffold(body: child),
);

class _Plugin extends QuaxPlugin {
  @override
  String get id => 'test';
  @override
  String get enabledPrefKey => 'test.enabled';
  @override
  IconData get icon => Icons.article;
  @override
  String title(BuildContext context) => 'Reader';
  @override
  String description(BuildContext context) => 'Test';
  @override
  Widget homeScreen({required ScrollController scrollController}) =>
      ListView(controller: scrollController, children: const [Text('Reader content')]);
  @override
  Widget settingsScreen(BuildContext context) => const Scaffold(body: Text('Reader settings'));
}

void main() {
  testWidgets('an empty search refetches after its query invalidates the controller', (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);
    var calls = 0;
    await tester.pumpWidget(
      _app(
        PaginatedTweetList(
          feed: feed,
          username: null,
          loadPage: (_) async {
            calls++;
            return (chains: <TweetChain>[], nextCursor: null);
          },
          firstPageErrorPrefix: 'Could not load',
          newPageErrorPrefix: 'Could not load more',
          emptyMessage: 'No matches',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('No matches'), findsOneWidget);
    feed.controller.refresh();
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('No matches'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('stalled initial page leaves loading and exposes a retry', (tester) async {
    final feed = TweetFeedController(requestTimeout: const Duration(seconds: 1));
    addTearDown(feed.dispose);
    await tester.pumpWidget(
      _app(
        PaginatedTweetList(
          feed: feed,
          username: null,
          loadPage: (_) => Completer<TweetPageResult>().future,
          firstPageErrorPrefix: 'Could not load',
          newPageErrorPrefix: 'Could not load more',
          emptyMessage: 'No matches',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(feed.controller.value.isLoading, isFalse);
    expect(feed.controller.value.error, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('standalone plugin reader opens settings and returns through Back', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.push(context, MaterialPageRoute(builder: (_) => PluginReader(plugin: _Plugin()))),
            child: const Text('Open reader'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reader'));
    await tester.pumpAndSettle();
    expect(find.text('Reader content'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Reader settings'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open reader'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
