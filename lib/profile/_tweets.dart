import 'package:qui/utils/read_request_scope.dart';
import 'package:qui/utils/cached_page.dart';
import 'package:qui/search/loaded_feed_search.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:qui/client/client.dart';
import 'package:qui/constants.dart';
import 'package:qui/database/repository.dart';
import 'package:qui/database/timeline_cache.dart';
import 'package:qui/profile/profile.dart';
import 'package:qui/tweet/conversation.dart';
import 'package:qui/tweet/tweet_skeleton.dart';
import 'package:qui/ui/errors.dart';
import 'package:qui/user.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/utils/paging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class ProfileTweets extends StatefulWidget {
  final UserWithExtra user;
  final String type;
  final bool includeReplies;
  final List<String> pinnedTweets;
  final BasePrefService pref;

  const ProfileTweets({
    super.key,
    required this.user,
    required this.type,
    required this.includeReplies,
    required this.pinnedTweets,
    required this.pref,
  });

  @override
  State<ProfileTweets> createState() => _ProfileTweetsState();
}

class _ProfileTweetsState extends State<ProfileTweets> with AutomaticKeepAliveClientMixin<ProfileTweets> {
  late final CursorPagingController<String, TweetChain> _paging;
  PagingController<int, TweetChain> get _pagingController => _paging.pagingController;

  static const int pageSize = 20;
  int loadTweetsCounter = 0;
  bool _bypassCache = false;
  bool _firstLoadStarted = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _paging = CursorPagingController<String, TweetChain>(_fetchPage);
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  void incrementLoadTweetsCounter() {
    ++loadTweetsCounter;
  }

  int getLoadTweetsCounter() {
    return loadTweetsCounter;
  }

  Future<TweetStatus> _load(String? cursor) => Twitter.getTweets(
    widget.user.idStr!,
    widget.type,
    widget.pinnedTweets,
    cursor: cursor,
    count: pageSize,
    includeReplies: widget.includeReplies,
    getTweetsCounter: getLoadTweetsCounter,
    incrementTweetsCounter: incrementLoadTweetsCounter,
  );

  /// The first page of a profile, from cache when it is fresh enough, and from
  /// cache at any age when the request fails. Opening the same profile twice in
  /// a session used to cost two requests; now the second one paints instantly
  /// and still shows something while rate limited or offline.
  ///
  /// Only the first page is cached — see [TimelineCache].
  Future<TweetStatus> _loadFirstPage() async {
    final key = TimelineCache.profileKey(widget.user.idStr!, widget.type, includeReplies: widget.includeReplies);
    Future<TimelineCache> cache() async => TimelineCache(await Repository.writable());
    final bypass = _bypassCache;
    _bypassCache = false;
    return loadCachedPage<TweetStatus>(
      bypassCache: bypass,
      readFresh: () async => (await cache()).read(key, maxAge: profileCacheMaxAge),
      readStale: () async => (await cache()).readStale(key),
      fetch: () => _load(null).timeout(const Duration(seconds: 30)),
      write: (result) async => (await cache()).write(key, result),
    );
  }

  Future<CursorPage<String, TweetChain>> _fetchPage(String? cursor) async {
    var result = cursor == null ? await _loadFirstPage() : await _load(cursor);

    ReadWork.checkpoint();

    // Stop when the cursor doesn't advance (or is gone), keeping the chains.
    final next = result.cursorBottom;
    return (items: result.chains, nextCursor: next == cursor ? null : next);
  }

  Future<void> _refresh() async {
    _bypassCache = true;
    _paging.beginReplacement();
    final generation = _paging.generation;
    try {
      final result = await _paging.startRead(() => _fetchPage(null));
      if (mounted && generation == _paging.generation) {
        _paging.replaceFirstPage(result.items, result.nextCursor);
      }
    } catch (error, stackTrace) {
      if (mounted && generation == _paging.generation) _paging.setError(error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<TweetContextState>(
      builder: (context, model, child) {
        if (model.hideSensitive && (widget.user.possiblySensitive ?? false)) {
          return EmojiErrorWidget(
            emoji: '🍆🙈🍆',
            message: L10n.current.possibly_sensitive,
            errorMessage: L10n.current.possibly_sensitive_profile,
            onRetry: () async => model.setHideSensitive(false),
            retryText: L10n.current.yes_please,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: PagingListener<int, TweetChain>(
            controller: _pagingController,
            builder: (context, state, fetchNextPage) {
              if (pagingAwaitingFirstPage(state)) {
                scheduleFirstPageFetch(
                  _pagingController,
                  alreadyStarted: _firstLoadStarted,
                  markStarted: () => _firstLoadStarted = true,
                  isMounted: () => mounted,
                );
                return ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [TweetFeedSkeleton()]);
              }
              if (state.items == null && state.error != null) {
                return pagingFill(
                  child: FullPageErrorWidget(
                    error: pagingErrorOf(state)?.error,
                    stackTrace: pagingErrorOf(state)?.stackTrace,
                    prefix: L10n.of(context).unable_to_load_the_tweets,
                    onRetry: _refresh,
                  ),
                );
              }
              if (state.items?.isEmpty ?? false) {
                return pagingFill(child: Center(child: Text(L10n.of(context).could_not_find_any_tweets_by_this_user)));
              }
              return CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                      showLoadedFeedSearch(context, loadedFeedEntries(_paging.items ?? [], widget.user.screenName)),
                  const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () =>
                      showLoadedFeedSearch(context, loadedFeedEntries(_paging.items ?? [], widget.user.screenName)),
                },
                child: Focus(
                  skipTraversal: true,
                  child: PagedListView<int, TweetChain>(
                    padding: EdgeInsets.zero,
                    state: state,
                    fetchNextPage: fetchNextPage,
                    addAutomaticKeepAlives: false,
                    builderDelegate: PagedChildBuilderDelegate(
                      itemBuilder: (context, chain, index) {
                        return TweetConversation(
                          id: chain.id,
                          tweets: chain.tweets,
                          username: widget.user.screenName!,
                          isPinned: chain.isPinned,
                        );
                      },
                      firstPageProgressIndicatorBuilder: (context) => const TweetFeedSkeleton(),
                      newPageProgressIndicatorBuilder: (context) => const TweetSkeletonTile(),
                      firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
                        error: pagingErrorOf(state)?.error,
                        stackTrace: pagingErrorOf(state)?.stackTrace,
                        prefix: L10n.of(context).unable_to_load_the_tweets,
                        onRetry: fetchNextPage,
                      ),
                      newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
                        error: pagingErrorOf(state)?.error,
                        stackTrace: pagingErrorOf(state)?.stackTrace,
                        prefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
                        onRetry: fetchNextPage,
                      ),
                      noItemsFoundIndicatorBuilder: (context) {
                        return Center(child: Text(L10n.of(context).could_not_find_any_tweets_by_this_user));
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
