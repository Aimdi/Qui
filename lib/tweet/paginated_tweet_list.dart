import 'package:flutter/services.dart';
import 'package:qui/search/loaded_feed_search.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'package:qui/client/client.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/group/feed_refresh_controller.dart';
import 'package:qui/tweet/cached_tweet_list.dart';
import 'package:qui/tweet/conversation.dart';
import 'package:qui/tweet/interleaved_items.dart';
import 'package:qui/tweet/tweet_skeleton.dart';
import 'package:qui/ui/caught_up_divider.dart';
import 'package:qui/ui/errors.dart';
import 'package:qui/utils/paging.dart';

typedef TweetPageResult = ({List<TweetChain> chains, String? nextCursor});
typedef TweetPageLoader = Future<TweetPageResult> Function(String? cursor);

/// Owns a [CursorPagingController] for cursor-paginated tweet chains, bridging
/// it onto the app's `(chains, nextCursor)` loaders.
///
/// v5 bakes the fetch callback into the controller at construction, yet several
/// feeds create the controller away from the loader (and cache it across widget
/// remounts — see [FeedSessionCache]). So the loader lives in a rebindable field
/// that [PaginatedTweetList] sets on mount.
class TweetFeedController {
  late final CursorPagingController<String, TweetChain> _paging;
  TweetPageLoader? _loader;
  final Duration requestTimeout;
  int _loadGeneration = 0;
  bool _disposed = false;
  Future<void>? _refreshing;
  bool _refreshFailed = false;

  /// When set, pagination pauses after this many pages per session instead of
  /// scrolling forever (`null` result → no cap). Feeds bind this to the
  /// zen-mode preference; search and quotes leave it unset.
  int? Function()? pageCapProvider;
  int _pagesFetched = 0;
  // The real next cursor stashed when the page cap paused pagination, so
  // "load more anyway" can resume where the feed stopped.
  String? _cappedCursor;

  TweetFeedController({this.requestTimeout = const Duration(seconds: 45)}) {
    _paging = CursorPagingController<String, TweetChain>(_fetch, requestTimeout: requestTimeout);
  }

  PagingController<int, TweetChain> get controller => _paging.pagingController;

  set loader(TweetPageLoader loader) => _loader = loader;

  bool get hasItems => _paging.items != null;

  /// The chains loaded so far, or `null` before the first page.
  List<TweetChain>? get items => _paging.items;

  String? get nextCursor => _paging.nextCursor;

  bool get pausedByPageCap => _cappedCursor != null;

  /// Resumes pagination past the page cap, granting another cap's worth of
  /// pages before pausing again.
  void continuePastCap() {
    final cursor = _cappedCursor;
    if (cursor == null) {
      return;
    }
    _cappedCursor = null;
    _pagesFetched = 0;
    _paging.resume(cursor);
  }

  String? _applyPageCap(String? next) {
    final cap = pageCapProvider?.call();
    if (next == null || cap == null || _pagesFetched < cap) {
      _cappedCursor = null;
      return next;
    }
    _cappedCursor = next;
    return null;
  }

  Future<CursorPage<String, TweetChain>> _fetch(String? cursor) async {
    _refreshFailed = false;
    final generation = ++_loadGeneration;
    final pagingGeneration = _paging.generation;
    final result = await _paging.startRead(() => _loader!(cursor));
    if (_disposed || generation != _loadGeneration || pagingGeneration != _paging.generation) {
      return (items: const <TweetChain>[], nextCursor: null);
    }
    final next = result.nextCursor;
    // Later pages can overlap earlier ones (search cursors aren't exact
    // boundaries), so drop chains that are already displayed. Last-page
    // detection stays on the unfiltered page: an all-duplicates page still
    // carries a cursor worth following.
    final seen = cursor == null ? <String>{} : (_paging.items ?? const <TweetChain>[]).map((e) => e.id).toSet();
    final items = result.chains.where((c) => seen.add(c.id)).toList();
    if (cursor == null) {
      _pagesFetched = 0;
    }
    _pagesFetched++;
    final naturalNext = _isLastPage(result.chains, next, cursor) ? null : next;
    return (items: items, nextCursor: _applyPageCap(naturalNext));
  }

  // Pagination ends on an empty page, a missing/blank cursor, or a cursor that
  // didn't advance (which would otherwise loop forever).
  bool _isLastPage(List<TweetChain> chains, String? next, String? cursor) =>
      chains.isEmpty || next == null || next.isEmpty || next == cursor;

  /// Reloads the first page and replaces the items in place, *without* resetting
  /// to the first-page spinner the way [PagingController.refresh] does. Used by
  /// pull-to-refresh so the existing tweets stay visible under the indicator.
  Future<void> softRefresh() => _refreshing ??= _softRefresh().whenComplete(() => _refreshing = null);

  Future<void> _softRefresh() async {
    if (_disposed) return;
    _refreshFailed = false;
    final generation = ++_loadGeneration;
    _paging.beginReplacement();
    final pagingGeneration = _paging.generation;
    bool current() => !_disposed && generation == _loadGeneration && pagingGeneration == _paging.generation;
    try {
      final result = await _paging.startRead(() => _loader!(null));
      if (!current()) return;
      final next = result.nextCursor;
      final seen = <String>{};
      final items = result.chains.where((chain) => seen.add(chain.id)).toList();
      _pagesFetched = 1;
      _paging.replaceFirstPage(items, _applyPageCap(_isLastPage(result.chains, next, null) ? null : next));
    } catch (e, stackTrace) {
      if (current()) {
        _refreshFailed = true;
        _paging.setError(e, stackTrace);
      }
    }
  }

  Future<void> retryFailedRead() async {
    if (_refreshFailed) {
      await softRefresh();
    } else {
      controller.fetchNextPage();
    }
  }

  void reportRefreshError(Object error, StackTrace stackTrace) {
    if (_disposed) return;
    _paging.cancel();
    _paging.setError(error, stackTrace);
  }

  void dispose() {
    _disposed = true;
    _loadGeneration++;
    _paging.dispose();
  }
}

/// Shared paginated tweet list used by the For-you feed, the group feed and
/// the tweet search results. Drives a [TweetFeedController]'s v5 controller
/// through the standard `PagedListView` shell with error / empty widgets.
///
/// The controller's lifecycle (creation, disposal, cross-mount caching) stays
/// at the call site — this widget only binds the loader and, while a cached
/// preview is shown, kicks off the first page itself.
class PaginatedTweetList extends StatefulWidget {
  final TweetFeedController feed;
  final TweetPageLoader loadPage;
  final String? username;
  final Future<void> Function()? onRefresh;
  final String firstPageErrorPrefix;
  final String newPageErrorPrefix;
  final String emptyMessage;
  // Cached tweets shown in place of the first-page spinner while the initial
  // load is in flight, so a feed reveals its cached content instead of a
  // full-screen progress indicator.
  final List<TweetChain>? firstPagePreview;
  // Reading-position support: when set, a "You're caught up" divider is drawn
  // above the first chain this predicate marks as already seen. The predicate
  // must stay frozen for the mount so the divider doesn't move mid-session.
  final bool Function(TweetChain chain)? isSeen;
  final Key? caughtUpDividerKey;

  /// Posts from somewhere other than X, slotted among the chains by date.
  final List<InterleavedItem> interleaved;

  const PaginatedTweetList({
    super.key,
    required this.feed,
    required this.loadPage,
    required this.username,
    required this.firstPageErrorPrefix,
    required this.newPageErrorPrefix,
    required this.emptyMessage,
    this.onRefresh,
    this.firstPagePreview,
    this.isSeen,
    this.caughtUpDividerKey,
    this.interleaved = const [],
  });

  @override
  State<PaginatedTweetList> createState() => _PaginatedTweetListState();
}

class _PaginatedTweetListState extends State<PaginatedTweetList> {
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  FeedRefreshController? _refreshController;
  final _feedFocus = FocusNode();
  bool _firstLoadStarted = false;
  bool _pendingInitialLoad = false;
  bool _refreshPreparationFailed = false;
  Future<void>? _refreshTask;

  PagingController<int, TweetChain> get _controller => widget.feed.controller;

  @override
  void initState() {
    super.initState();
    widget.feed.loader = widget.loadPage;
    // While we show the cached preview the PagedListView isn't mounted, so it
    // can't trigger the first page itself — we rebuild to swap it in once items
    // arrive, so listen for that.
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only feeds that support pull-to-refresh expose their refresh to the
    // app-bar button. Outside a GroupFeedShell there is no controller to bind.
    if (widget.onRefresh == null) return;
    FeedRefreshController? controller;
    try {
      controller = context.read<FeedRefreshController>();
    } on ProviderNotFoundException {
      controller = null;
    }
    if (!identical(controller, _refreshController)) {
      _refreshController?.unregister(_showRefresh);
      _refreshController?.unregisterSearch(_searchLoaded);
      _refreshController = controller;
      _refreshController?.register(_showRefresh);
      _refreshController?.registerSearch(_searchLoaded);
    }
  }

  @override
  void didUpdateWidget(PaginatedTweetList oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.feed.loader = widget.loadPage;
    if (!identical(oldWidget.feed, widget.feed)) {
      oldWidget.feed.controller.removeListener(_onControllerChanged);
      _controller.addListener(_onControllerChanged);
      // A fresh feed may need its first page kicked off again from the preview.
      _firstLoadStarted = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _feedFocus.dispose();
    _refreshController?.unregister(_showRefresh);
    _refreshController?.unregisterSearch(_searchLoaded);
    super.dispose();
  }

  void _onControllerChanged() {
    // Loading/preview placeholders live outside PagingListener and must be
    // replaced when the first result, failure or new query arrives.
    final state = _controller.value;
    if (state.items == null && state.error == null && !state.isLoading) _firstLoadStarted = false;
    if (mounted) setState(() {});
  }

  // Drives the same RefreshIndicator the user pulls down, so the app-bar refresh
  // button shows the top spinner and runs the soft refresh identically.
  Future<void> _showRefresh() async {
    await _refreshKey.currentState?.show();
  }

  Widget _buildChain(BuildContext context, TweetChain chain) =>
      TweetConversation(id: chain.id, tweets: chain.tweets, username: widget.username, isPinned: chain.isPinned);

  /// Soft refresh used by the pull-to-refresh gesture. Runs the caller's
  /// [onRefresh] side effects, then reloads the first page while keeping the
  /// current tweets visible (the RefreshIndicator shows its own small spinner on
  /// top). Awaited so the spinner stays until done.
  Future<void> _handleRefresh() => _refreshTask ??= _refresh().whenComplete(() => _refreshTask = null);

  Future<void> _refresh() async {
    _refreshPreparationFailed = false;
    try {
      await widget.onRefresh?.call().timeout(widget.feed.requestTimeout);
      if (!mounted) return;
      await widget.feed.softRefresh();
    } catch (error, stackTrace) {
      if (mounted) {
        _refreshPreparationFailed = true;
        widget.feed.reportRefreshError(error, stackTrace);
      }
    }
  }

  Future<void> _retry() => _refreshPreparationFailed ? _handleRefresh() : widget.feed.retryFailedRead();

  // True while we should display the cached preview: the first page hasn't
  // loaded yet. Keep this copy visible even if the live read fails.
  bool get _showingPreview {
    final preview = widget.firstPagePreview;
    final state = _controller.value;
    return preview != null && preview.isNotEmpty && state.items == null;
  }

  // The PagedListView normally kicks off the first page when it mounts. While
  // the preview replaces it, nothing does — so trigger the load ourselves once.
  void _maybeStartFirstLoad() {
    if (_firstLoadStarted) return;
    final state = _controller.value;
    if (state.items != null || state.error != null) return;
    _firstLoadStarted = true;
    // Deferred: we're called from build() and fetchNextPage() mutates the
    // controller synchronously, which would setState() mid-build via our listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.onRefresh == null) {
        _controller.fetchNextPage();
        return;
      }
      final refreshState = _refreshKey.currentState;
      if (refreshState != null) {
        _pendingInitialLoad = true;
        refreshState.show();
      } else {
        _controller.fetchNextPage();
      }
    });
  }

  Future<void> _onRefreshTriggered() async {
    if (_pendingInitialLoad) {
      _pendingInitialLoad = false;
      await widget.feed.softRefresh();
      return;
    }
    await _handleRefresh();
  }

  Future<void> _searchLoaded() => showLoadedFeedSearch(
    context,
    loadedFeedEntries(widget.feed.items ?? widget.firstPagePreview ?? const [], widget.username),
  );

  Widget _wrapWithRefresh(Widget child) {
    child = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _searchLoaded,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _searchLoaded,
      },
      child: Focus(
        focusNode: _feedFocus,
        skipTraversal: true,
        child: Listener(
          onPointerDown: (_) {
            if (!_feedFocus.hasFocus) _feedFocus.requestFocus();
          },
          child: child,
        ),
      ),
    );
    if (widget.onRefresh == null) return child;
    return RefreshIndicator(key: _refreshKey, onRefresh: _onRefreshTriggered, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (_showingPreview) {
      _maybeStartFirstLoad();
      final preview = _wrapWithRefresh(CachedTweetList(widget.firstPagePreview!, username: widget.username));
      if (_controller.value.error == null) return preview;
      return Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: ListTile(
              dense: true,
              title: Text(L10n.of(context).reader_refresh_failed),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: L10n.of(context).refresh,
                onPressed: _retry,
              ),
            ),
          ),
          Expanded(child: preview),
        ],
      );
    }

    if (pagingAwaitingFirstPage(_controller.value)) {
      _maybeStartFirstLoad();
      return _wrapWithRefresh(
        ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [TweetFeedSkeleton()]),
      );
    }

    final list = PagingListener<int, TweetChain>(
      controller: _controller,
      builder: (context, state, fetchNextPage) {
        // Recomputed per build from the loaded items, so the boundary shows
        // up even when the first seen chain only arrives on a later page.
        final seen = widget.isSeen;
        final loaded = state.items ?? const <TweetChain>[];
        final boundary = seen == null ? null : _caughtUpBoundaryOf(loaded, seen);
        final buckets = placeInterleaved(loaded, widget.interleaved);
        if (state.items == null && state.error != null) {
          return pagingFill(
            child: FullPageErrorWidget(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: widget.firstPageErrorPrefix,
              onRetry: _retry,
            ),
          );
        }
        if (loaded.isEmpty) {
          if (widget.interleaved.isNotEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [for (final item in widget.interleaved) item.build(context)],
            );
          }
          return pagingFill(child: Center(child: Text(widget.emptyMessage)));
        }
        return PagedListView<int, TweetChain>(
          padding: EdgeInsets.only(top: 4, bottom: MediaQuery.of(context).padding.bottom),
          state: state,
          fetchNextPage: fetchNextPage,
          addAutomaticKeepAlives: false,
          builderDelegate: PagedChildBuilderDelegate(
            itemBuilder: (context, chain, index) {
              final conversation = _buildChain(context, chain);
              final above = index < buckets.length ? buckets[index] : const <InterleavedItem>[];
              // Anything older than every chain loaded so far rides along with
              // the last one, so it is on screen rather than waiting for a page
              // that may never be asked for.
              final below = index == loaded.length - 1 ? buckets.last : const <InterleavedItem>[];
              final showsDivider = boundary != null && index == boundary;

              if (above.isEmpty && below.isEmpty && !showsDivider) {
                return conversation;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showsDivider) CaughtUpDivider(key: widget.caughtUpDividerKey),
                  for (final item in above) item.build(context),
                  conversation,
                  for (final item in below) item.build(context),
                ],
              );
            },
            firstPageProgressIndicatorBuilder: (context) => const TweetFeedSkeleton(),
            newPageProgressIndicatorBuilder: (context) => const TweetSkeletonTile(),
            firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: widget.firstPageErrorPrefix,
              onRetry: _retry,
            ),
            newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: widget.newPageErrorPrefix,
              onRetry: _retry,
            ),
            // A group can hold nothing but subreddits or publications. Its
            // posts are all interleaved items, and X having no chains for it is
            // not the same as the feed being empty — reporting "no posts" over
            // the top of them is what made such a group look broken.
            noItemsFoundIndicatorBuilder: (context) => buckets.last.isEmpty
                ? Center(child: Text(widget.emptyMessage))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [for (final item in buckets.last) item.build(context)],
                  ),
            noMoreItemsIndicatorBuilder: (context) => widget.feed.pausedByPageCap
                ? _ZenFeedEndCard(onLoadMore: widget.feed.continuePastCap)
                : const SizedBox.shrink(),
          ),
        );
      },
    );

    return _wrapWithRefresh(list);
  }

  // Index of the first already-seen chain, when at least one new chain sits
  // above it. Index 0 means nothing is new; no boundary yet means the seen
  // chains haven't been loaded — both draw no divider.
  static int? _caughtUpBoundaryOf(List<TweetChain> chains, bool Function(TweetChain) isSeen) {
    final index = chains.indexWhere(isSeen);
    return index <= 0 ? null : index;
  }
}

/// Calm end-of-feed card shown when the zen-mode page cap paused pagination,
/// offering a deliberate way to keep reading instead of an infinite scroll.
class _ZenFeedEndCard extends StatelessWidget {
  final VoidCallback onLoadMore;

  const _ZenFeedEndCard({required this.onLoadMore});

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.self_improvement, size: 36, color: hintColor),
          const SizedBox(height: 12),
          Text(
            L10n.of(context).zen_mode_feed_end,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: hintColor),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onLoadMore, child: Text(L10n.of(context).zen_mode_load_more)),
        ],
      ),
    );
  }
}
