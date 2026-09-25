import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:qui/client/client.dart';
import 'package:qui/tweet/paginated_tweet_list.dart';
import 'package:qui/utils/paging.dart';

TweetChain _chain(String id) => TweetChain(id: id, tweets: [], isPinned: false);

void main() {
  testWidgets('leaving a stalled feed cancels its wait and deadline', (tester) async {
    final feed = TweetFeedController();
    feed.loader = (_) => Completer<TweetPageResult>().future;
    feed.controller.fetchNextPage();
    await tester.pump();
    feed.dispose();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('stalled page unlocks retry and a late result cannot change its cursor', (tester) async {
    final old = Completer<CursorPage<String, String>>();
    var calls = 0;
    final paging = CursorPagingController<String, String>(
      (_) => ++calls == 1 ? old.future : Future.value((items: ['new'], nextCursor: 'new-cursor')),
    );
    addTearDown(paging.dispose);
    paging.pagingController.fetchNextPage();
    await tester.pump(const Duration(seconds: 46));
    expect(paging.pagingController.value.isLoading, isFalse);
    expect(pagingErrorOf(paging.pagingController.value)?.error, isA<TimeoutException>());
    paging.pagingController.fetchNextPage();
    await tester.pump();
    old.complete((items: ['old'], nextCursor: 'old-cursor'));
    await tester.pump();
    expect(paging.items, ['new']);
    expect(paging.nextCursor, 'new-cursor');
  });

  testWidgets('refresh invalidates the old cursor even when the old page finishes last', (tester) async {
    final old = Completer<CursorPage<String, String>>();
    var calls = 0;
    final paging = CursorPagingController<String, String>(
      (_) => ++calls == 1 ? old.future : Future.value((items: ['new'], nextCursor: 'new-cursor')),
    );
    addTearDown(paging.dispose);
    paging.pagingController.fetchNextPage();
    paging.pagingController.refresh();
    paging.pagingController.fetchNextPage();
    await tester.pump();
    old.complete((items: ['old'], nextCursor: null));
    await tester.pump();
    expect(paging.items, ['new']);
    expect(paging.nextCursor, 'new-cursor');
    paging.pagingController.fetchNextPage();
    await tester.pump();
    expect(calls, 3);
  });

  testWidgets('soft refresh times out without losing posts and can retry', (tester) async {
    final feed = TweetFeedController(requestTimeout: const Duration(seconds: 1));
    addTearDown(feed.dispose);
    feed.loader = (_) async => (chains: [_chain('saved')], nextCursor: 'next');
    feed.controller.fetchNextPage();
    await tester.pump();
    final old = Completer<TweetPageResult>();
    feed.loader = (_) => old.future;
    final refresh = feed.softRefresh();
    await tester.pump(const Duration(seconds: 2));
    await refresh;
    expect(feed.items!.single.id, 'saved');
    expect(feed.controller.value.isLoading, isFalse);
    expect(pagingErrorOf(feed.controller.value)?.error, isA<TimeoutException>());
    feed.loader = (_) async => (chains: [_chain('new')], nextCursor: 'fresh');
    await feed.softRefresh();
    old.complete((chains: [_chain('old')], nextCursor: null));
    await tester.pump();
    expect(feed.items!.single.id, 'new');
    expect(feed.nextCursor, 'fresh');
    expect(feed.controller.value.error, isNull);
  });

  testWidgets('refresh coalesces toolbar/pull requests and blocks old-cursor pagination', (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);
    feed.loader = (_) async => (chains: [_chain('visible')], nextCursor: 'old-cursor');
    feed.controller.fetchNextPage();
    await tester.pump();
    final result = Completer<TweetPageResult>();
    final cursors = <String?>[];
    feed.loader = (cursor) {
      cursors.add(cursor);
      return result.future;
    };
    final toolbar = feed.softRefresh();
    final pull = feed.softRefresh();
    expect(identical(toolbar, pull), isTrue);
    expect(feed.controller.value.isLoading, isTrue);
    expect(feed.items!.single.id, 'visible');
    feed.controller.fetchNextPage();
    await tester.pump();
    expect(cursors, [null]);
    result.complete((chains: [_chain('fresh')], nextCursor: 'new-cursor'));
    await toolbar;
    expect(feed.items!.single.id, 'fresh');
    expect(feed.nextCursor, 'new-cursor');
    expect(feed.controller.value.isLoading, isFalse);
  });

  testWidgets('retry repeats the failed refresh before using the pagination cursor', (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);
    feed.loader = (_) async => (chains: [_chain('visible')], nextCursor: 'old-cursor');
    feed.controller.fetchNextPage();
    await tester.pump();
    feed.loader = (_) async => throw TimeoutException('refresh failed');
    await feed.softRefresh();
    final cursors = <String?>[];
    feed.loader = (cursor) async {
      cursors.add(cursor);
      return (chains: [_chain('fresh')], nextCursor: 'new-cursor');
    };
    await feed.retryFailedRead();
    expect(cursors, [null]);
    expect(feed.items!.single.id, 'fresh');
    feed.loader = (_) async => throw TimeoutException('next page failed');
    feed.controller.fetchNextPage();
    await tester.pump();
    feed.loader = (cursor) async {
      cursors.add(cursor);
      return (chains: [_chain('older')], nextCursor: null);
    };
    await feed.retryFailedRead();
    await tester.pump();
    expect(cursors, [null, 'new-cursor']);
    expect(feed.items!.map((item) => item.id), ['fresh', 'older']);
  });

  testWidgets('soft refresh cancels an older in-flight page', (tester) async {
    final old = Completer<TweetPageResult>();
    final feed = TweetFeedController();
    addTearDown(feed.dispose);
    feed.loader = (_) => old.future;
    feed.controller.fetchNextPage();
    feed.loader = (_) async => (chains: [_chain('new')], nextCursor: 'fresh');
    await feed.softRefresh();
    old.complete((chains: [_chain('old')], nextCursor: null));
    await tester.pump();
    expect(feed.items!.map((e) => e.id), ['new']);
    expect(feed.nextCursor, 'fresh');
    expect(feed.controller.value.isLoading, isFalse);
  });
}
