import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:qui/constants.dart';
import 'package:qui/database/entities.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/profile/profile.dart';
import 'package:qui/search/advanced_search.dart';
import 'package:qui/search/search_media_grid.dart';
import 'package:qui/search/search_model.dart';
import 'package:qui/tweet/_video.dart';
import 'package:qui/tweet/paginated_tweet_list.dart';
import 'package:qui/ui/errors.dart';
import 'package:qui/ui/layout.dart';
import 'package:qui/search/recent_searches_bar.dart';
import 'package:qui/search/search_history.dart';
import 'package:qui/user.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class SearchArguments {
  final int initialTab;
  final String? query;
  final bool focusInputOnOpen;

  SearchArguments(this.initialTab, {this.query, this.focusInputOnOpen = false});
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as SearchArguments;

    return _ResultsScreen(
      initialTab: arguments.initialTab,
      query: arguments.query,
      focusInputOnOpen: arguments.focusInputOnOpen,
    );
  }
}

class _ResultsScreen extends StatefulWidget {
  final int initialTab;
  final String? query;
  final bool focusInputOnOpen;

  const _ResultsScreen({required this.initialTab, this.query, this.focusInputOnOpen = false});

  @override
  State<_ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<_ResultsScreen> with SingleTickerProviderStateMixin {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();
  final _history = SearchHistory();
  late final TabController _tabController;
  late final SearchTweetsPagination _topTweets;
  late final SearchTweetsPagination _latestTweets;
  late final SearchMediaPagination _mediaResults;
  final _searchUsersModel = SearchUsersModel();
  Timer? _debounce;
  String _query = '';
  String? _peopleQuery;

  @override
  void initState() {
    super.initState();
    _query = widget.query?.trim() ?? '';
    _queryController.text = _query;
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
    _tabController.addListener(_searchPeopleIfVisible);
    _topTweets = SearchTweetsPagination(product: 'Top', initialQuery: _query);
    _latestTweets = SearchTweetsPagination(product: 'Latest', initialQuery: _query);
    _mediaResults = SearchMediaPagination(initialQuery: _query);
    _queryController.addListener(_onQueryChanged);
    _history.load();
    _searchPeopleIfVisible();
    if (widget.focusInputOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusNode.requestFocus();
        _queryController.selection = TextSelection.collapsed(offset: _queryController.text.length);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _topTweets.dispose();
    _latestTweets.dispose();
    _mediaResults.dispose();
    _searchUsersModel.destroy();
    _history.destroy();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    if (_queryController.text.trim() == _query) return;
    _debounce = Timer(const Duration(milliseconds: 750), _dispatchQuery);
  }

  void _searchPeopleIfVisible({bool force = false}) {
    if (_tabController.index != 3 || _query.isEmpty) return;
    if (!force && _peopleQuery == _query) return;
    _peopleQuery = _query;
    _searchUsersModel.searchUsers(_query);
  }

  void _dispatchQuery() {
    if (!mounted) return;
    _debounce?.cancel();
    final query = _queryController.text.trim();
    if (query == _query) return;
    _topTweets.updateQuery(query);
    _latestTweets.updateQuery(query);
    _mediaResults.updateQuery(query);
    _searchUsersModel.clear();
    _peopleQuery = null;
    setState(() => _query = query);
    _searchPeopleIfVisible();
  }

  void _submit(String value) {
    _queryController.text = value;
    _dispatchQuery();
    _history.remember(value);
    _focusNode.unfocus();
  }

  Widget _recentSearches(BuildContext context) => Column(
    children: [
      RecentSearchesBar(store: _history, onSelected: _submit),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              L10n.of(context).reader_search_hint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final prefs = PrefService.of(context, listen: false);
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 72,
        title: ContentFrame(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: SearchBar(
              controller: _queryController,
              focusNode: _focusNode,
              hintText: l10n.search,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              leading: const Icon(Icons.search),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.reader_clear_search,
                    onPressed: () {
                      _queryController.clear();
                      _dispatchQuery();
                      _focusNode.requestFocus();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: l10n.advanced_search,
                  onPressed: () async {
                    final query = await Navigator.push<String>(
                      context,
                      MaterialPageRoute(builder: (_) => const AdvancedSearchScreen()),
                    );
                    if (mounted && query != null && query.trim().isNotEmpty) _submit(query);
                  },
                ),
                if (_query.isNotEmpty)
                  FollowButton(
                    user: SearchSubscription(id: _query, createdAt: DateTime.now()),
                  ),
              ],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.reader_search_top),
            Tab(text: l10n.reader_search_latest),
            Tab(text: l10n.media),
            Tab(text: l10n.reader_search_people),
          ],
        ),
      ),
      body: ContentFrame(
        child: _query.isEmpty
            ? _recentSearches(context)
            : MultiProvider(
                providers: [
                  ChangeNotifierProvider<TweetContextState>(
                    create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive)),
                  ),
                  ChangeNotifierProvider<VideoContextState>(
                    create: (_) => VideoContextState(prefs.get(optionMediaDefaultMute)),
                  ),
                ],
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    for (final pagination in [_topTweets, _latestTweets])
                      PaginatedTweetList(
                        key: ValueKey(pagination.product),
                        feed: pagination.feed,
                        loadPage: pagination.loadPage,
                        username: null,
                        firstPageErrorPrefix: l10n.unable_to_load_the_search_results,
                        newPageErrorPrefix: l10n.unable_to_load_the_next_page_of_tweets,
                        emptyMessage: l10n.no_results,
                      ),
                    SearchMediaGrid(model: _mediaResults),
                    _UserSearchResultList(store: _searchUsersModel, onRetry: () => _searchPeopleIfVisible(force: true)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _UserSearchResultList extends StatelessWidget {
  final SearchUsersModel store;
  final VoidCallback onRetry;

  const _UserSearchResultList({required this.store, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<SearchUsersModel, List<UserWithExtra>>.transition(
      store: store,
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (_, error) => FullPageErrorWidget(
        error: error,
        stackTrace: null,
        prefix: L10n.of(context).unable_to_load_the_search_results,
        onRetry: onRetry,
      ),
      onState: (_, items) {
        if (items.isEmpty) {
          return Center(child: Text(L10n.of(context).no_results));
        }
        return ListView.builder(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return UserTile(user: UserSubscription.fromUser(items[index]));
          },
        );
      },
    );
  }
}
