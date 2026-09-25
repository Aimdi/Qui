import 'package:qui/saved/saved_chrome.dart';
import 'package:qui/saved/saved_post_content.dart';
import 'package:qui/saved/saved_view_store.dart';
import 'package:qui/status.dart';
import 'package:qui/ui/detail_pane.dart';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_triple/flutter_triple.dart';

import 'package:qui/client/client.dart';
import 'package:qui/constants.dart';
import 'package:qui/database/entities.dart';
import 'package:qui/group/group_model.dart';
import 'package:qui/saved/likes_by_group.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/profile/media_grid/media_grid.dart';
import 'package:qui/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:qui/profile/profile.dart';
import 'package:qui/saved/folder_picker.dart';
import 'package:qui/saved/liked_tweet_model.dart';
import 'package:qui/saved/saved_cleanup.dart';
import 'package:qui/saved/saved_tab_order.dart';
import 'package:qui/saved/saved_tweet_folder_model.dart';
import 'package:qui/saved/saved_tweet_model.dart';
import 'package:qui/tweet/tweet.dart';
import 'package:qui/ui/errors.dart';
import 'package:qui/ui/layout.dart';
import 'package:qui/ui/press_actions.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class SavedScreen extends StatefulWidget {
  final ScrollController scrollController;
  final bool? showTitle;

  const SavedScreen({super.key, required this.scrollController, this.showTitle});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with AutomaticKeepAliveClientMixin<SavedScreen> {
  // Selected folder filter: savedTabAll, savedTabUnfiled, or a folder id.
  String _filter = savedTabAll;
  bool _mediaOnly = false;
  bool _searching = false;
  String _query = '';
  final SavedViewStore _view = SavedViewStore();
  List<String> _visibleSavedIds = const [];

  /// Whether likes are broken out by the group their author belongs to.
  bool _likesByGroup = false;

  /// Group membership and group names, read once so the breakdown does not
  /// query per like.
  List<SubscriptionGroupMember> _groupMembers = const [];
  List<SubscriptionGroup> _groups = const [];

  /// Focused when the search button opens the field, rather than by `autofocus`.
  ///
  /// This screen is kept alive, so the field's subtree is re-inserted whenever
  /// the folder strip or a filter chip rebuilds — with `autofocus` that raised
  /// the keyboard again each time, unasked.
  final FocusNode _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    context.read<SavedTweetModel>().listSavedTweets();
    context.read<SavedTweetFolderModel>().listFolders();
    context.read<LikedTweetModel>().listLikedTweets();
    _loadGroupMembership();
  }

  Future<void> _loadGroupMembership() async {
    final model = context.read<GroupsModel>();
    final members = await model.listGroupMembers();
    if (!mounted) return;

    setState(() {
      _groupMembers = members;
      _groups = model.state;
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    _view.destroy();
    super.dispose();
  }

  // If the selected tab is no longer reachable (folder deleted elsewhere, or its
  // built-in tab was hidden in settings), fall back to "All".
  void _reconcileFilter(List<SavedTweetFolder> folders, {required bool showUnfiled, required bool showFavorites}) {
    var reachable =
        _filter == savedTabAll ||
        (_filter == savedTabUnfiled && showUnfiled && folders.isNotEmpty) ||
        (_filter == savedTabFavorites && showFavorites) ||
        folders.any((f) => f.id == _filter);
    if (reachable) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _filter = savedTabAll);
      }
    });
  }

  Future<void> _refresh() async {
    // Silent reload: keeps the current list on screen while the RefreshIndicator
    // spinner runs, and swaps in the fresh data only once it is ready.
    if (_filter == savedTabFavorites) {
      await context.read<LikedTweetModel>().refreshLikedTweets();
    } else {
      await context.read<SavedTweetModel>().refreshSavedTweets();
    }
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Text(
              _query.isNotEmpty
                  ? L10n.of(context).no_posts_match_your_search
                  : switch (_filter) {
                      savedTabAll => L10n.of(context).you_have_not_saved_any_tweets_yet,
                      savedTabFavorites => L10n.of(context).no_liked_posts_yet,
                      _ => L10n.of(context).folder_is_empty,
                    },
            ),
          ),
        ),
      ),
    );
  }

  /// Case-insensitive match of a stored tweet's JSON against the search query:
  /// post text (including long-post note text) plus author name and handle.
  bool _matchesQuery(String? content) {
    return savedPostMatches(content, _query);
  }

  List<T> _applySearch<T>(List<T> items, String? Function(T) contentOf) {
    if (_query.isEmpty) {
      return items;
    }
    return items.where((e) => _matchesQuery(contentOf(e))).toList();
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: L10n.of(context).search_saved_posts,
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
        ),
        onChanged: (value) => setState(() => _query = value.trim()),
      ),
    );
  }

  Widget _buildList({required int itemCount, required Widget Function(int) tileAt}) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      itemCount: itemCount,
      itemBuilder: (context, index) => tileAt(index),
    );
  }

  /// Media entries of the given saved posts, for the media-only grid.
  List<MediaGridItem> _mediaItemsOf(Iterable<String?> contents) {
    var chains = <TweetChain>[];
    for (var content in contents) {
      if (content == null) {
        continue;
      }
      final tweet = decodeSavedPost(content);
      if (tweet == null || tweet.idStr == null) {
        continue;
      }
      chains.add(TweetChain(id: tweet.idStr!, tweets: [tweet], isPinned: false));
    }
    return mediaItemsFromChains(chains);
  }

  Widget _buildMediaGrid(Iterable<String?> contents, {required Future<void> Function(String id) onDelete}) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: StaticMediaGrid(
        items: _mediaItemsOf(contents),
        emptyMessage: L10n.of(context).could_not_find_any_posts_with_media,
        onLongPressItem: (item) => _confirmRemoveFromGallery(item.tweetId, onDelete),
      ),
    );
  }

  // Long-pressing a tile in the saved gallery removes that post — handy for
  // clearing the dead "not available" ones without leaving gallery mode.
  Future<void> _confirmRemoveFromGallery(String id, Future<void> Function(String id) onDelete) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).are_you_sure),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(L10n.of(context).cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(L10n.of(context).delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await onDelete(id);
    }
  }

  List<SavedTweet> _applyFilter(List<SavedTweet> tweets) {
    switch (_filter) {
      case savedTabAll:
        return tweets;
      case savedTabUnfiled:
        return tweets.where((e) => e.folderId == null).toList();
      default:
        return tweets.where((e) => e.folderId == _filter).toList();
    }
  }

  Widget _buildFolderStrip() {
    var prefs = PrefService.of(context, listen: false);
    var showAll = prefs.get<bool>(optionSavedShowAllTab) ?? true;
    var showUnfiled = prefs.get<bool>(optionSavedShowUnfiledTab) ?? true;
    var showFavorites = prefs.get<bool>(optionSavedShowFavoritesTab) ?? true;
    var storedOrder = prefs.get<String>(optionSavedTabOrder);

    return ScopedBuilder<SavedTweetFolderModel, List<SavedTweetFolder>>(
      store: context.read<SavedTweetFolderModel>(),
      onState: (context, folders) {
        // Reconcile before the empty check, otherwise deleting the last folder would
        // leave `_filter` stranded on a now-deleted id (the strip returns early).
        _reconcileFilter(folders, showUnfiled: showUnfiled, showFavorites: showFavorites);

        // With no folders, only show the strip when the Favorites tab is available to
        // switch to — otherwise there is nothing to switch between (just "All").
        if (folders.isEmpty && !showFavorites) {
          return const SizedBox.shrink();
        }

        var chips = <Widget>[];
        for (var token in orderedSavedTabs(folders, storedOrder)) {
          if (token == savedTabAll) {
            if (showAll) chips.add(_folderChip(label: L10n.of(context).all, value: savedTabAll));
          } else if (token == savedTabUnfiled) {
            // "Unfiled" only makes sense with folders — otherwise it duplicates "All".
            if (showUnfiled && folders.isNotEmpty) {
              chips.add(_folderChip(label: L10n.of(context).unfiled, value: savedTabUnfiled));
            }
          } else if (token == savedTabFavorites) {
            if (showFavorites) chips.add(_folderChip(label: L10n.of(context).favorites, value: savedTabFavorites));
          } else {
            var matches = folders.where((f) => f.id == token);
            if (matches.isNotEmpty) chips.add(_folderChip(label: matches.first.name, value: token));
          }
        }

        return SizedBox(
          height: 52,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: chips),
            ),
          ),
        );
      },
    );
  }

  Widget _folderChip({required String label, required String value}) {
    var isFolder = value != savedTabAll && value != savedTabUnfiled;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PressActions(
        onInvoke: isFolder ? () => _showFolderMenu(value, label) : null,
        child: Theme(
          data: Theme.of(context).copyWith(
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ChoiceChip(
            // Likes carry a chevron once they are the chip you are on: tapping
            // the chip shows them flat, the chevron breaks them out by the
            // group each author belongs to.
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label),
                if (value == savedTabFavorites && _filter == savedTabFavorites) ...[
                  const SizedBox(width: 4),
                  Icon(_likesByGroup ? Icons.expand_less : Icons.expand_more, size: 18),
                ],
              ],
            ),
            selected: _filter == value,
            showCheckmark: false,
            shape: const StadiumBorder(),
            side: BorderSide.none,
            onSelected: (_) => setState(() {
              _view.finishSelection();
              // A second tap on the likes chip toggles the breakdown; landing
              // on it for the first time always shows them flat.
              if (value == savedTabFavorites && _filter == savedTabFavorites) {
                _likesByGroup = !_likesByGroup;
              } else {
                _likesByGroup = false;
                _filter = value;
              }
            }),
          ),
        ),
      ),
    );
  }

  Future<void> _showFolderMenu(String folderId, String label) async {
    var folderModel = context.read<SavedTweetFolderModel>();
    var matches = folderModel.state.where((f) => f.id == folderId);
    if (matches.isEmpty) {
      return;
    }
    var folder = matches.first;

    await HapticFeedback.lightImpact();
    if (!mounted) {
      return;
    }

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.edit_outlined),
              title: Text(L10n.of(sheetContext).rename),
              onTap: () {
                Navigator.pop(sheetContext);
                showCreateFolderDialog(context, folderModel, existing: folder);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.delete_outline),
              title: Text(L10n.of(sheetContext).delete),
              onTap: () async {
                Navigator.pop(sheetContext);
                var deleted = await showDeleteFolderDialog(context, folderModel, folder);
                if (deleted && mounted && _filter == folderId) {
                  setState(() => _filter = savedTabAll);
                }
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.folder_copy_outlined),
              title: Text(L10n.of(sheetContext).manage_folders),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Navigator.pushNamed(context, routeSavedFolders);
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleLibraryAction(SavedLibraryAction action) {
    setState(() {
      switch (action) {
        case SavedLibraryAction.sortNewest:
          _view.setSort(SavedSort.newest);
          break;
        case SavedLibraryAction.sortOldest:
          _view.setSort(SavedSort.oldest);
          break;
        case SavedLibraryAction.select:
          _mediaOnly = false;
          _view.beginSelection();
          break;
      }
    });
  }

  Future<void> _moveSelected() async {
    final ids = _view.state.selectedIds;
    if (ids.isEmpty) return;

    final folderModel = context.read<SavedTweetFolderModel>();
    await folderModel.listFolders();
    if (!mounted) return;

    final destination = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(L10n.of(dialogContext).library_move_selected),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, ''),
            child: Row(
              children: [
                const Icon(Icons.folder_off_outlined),
                const SizedBox(width: 12),
                Text(L10n.of(dialogContext).unfiled),
              ],
            ),
          ),
          for (final folder in folderModel.state)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, folder.id),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(folder.name)),
                ],
              ),
            ),
        ],
      ),
    );
    if (destination == null || !mounted) return;

    await context.read<SavedTweetModel>().setFolders(ids, destination.isEmpty ? null : destination);
    if (!mounted) return;
    setState(_view.finishSelection);
  }

  Future<void> _deleteSelected() async {
    final ids = _view.state.selectedIds;
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(L10n.of(dialogContext).library_delete_selected_title),
        content: Text(L10n.of(dialogContext).library_delete_selected_description(ids.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(L10n.of(dialogContext).cancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(L10n.of(dialogContext).delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<SavedTweetModel>().removeSavedTweets(ids.toList());
    if (!mounted) return;
    setState(_view.finishSelection);
  }

  Widget _savedTile(SavedTweet saved) {
    final child = SavedTweetTile(id: saved.id, content: saved.content);
    final view = _view.state;
    if (!view.selecting) return child;

    return SavedSelectableTile(
      id: saved.id,
      selected: view.selectedIds.contains(saved.id),
      onToggle: () => setState(() => _view.toggleSelected(saved.id)),
      child: child,
    );
  }

  Widget _buildSavedBody(SavedTweetModel model) {
    return ScopedBuilder<SavedTweetModel, List<SavedTweet>>.transition(
      store: model,
      onError: (_, e) => FullPageErrorWidget(
        error: e,
        stackTrace: null,
        prefix: L10n.current.unable_to_load_the_tweets,
        onRetry: () => model.listSavedTweets(),
      ),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onState: (_, data) {
        var filtered = applySavedSort(_applySearch(_applyFilter(data), (SavedTweet e) => e.content), _view.state.sort);
        _visibleSavedIds = filtered.map((e) => e.id).toList(growable: false);

        if (_mediaOnly && filtered.isNotEmpty) {
          return _buildMediaGrid(
            filtered.map((e) => e.content),
            onDelete: (id) => context.read<SavedTweetModel>().deleteSavedTweet(id),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: filtered.isEmpty
              ? _buildEmptyState()
              : _buildList(itemCount: filtered.length, tileAt: (i) => _savedTile(filtered[i])),
        );
      },
    );
  }

  /// Likes under one heading per group their author belongs to.
  ///
  /// One flat list with headings rather than a list of lists: the reader is
  /// still scrolling their likes, just with the feeds they came from marked.
  Widget _buildLikesByGroup(List<LikedTweet> likes) {
    final sections = likesByGroup<LikedTweet>(
      likes,
      authorOf: (like) => like.user,
      members: _groupMembers,
      groupIds: _groups.map((g) => g.id).toList(growable: false),
    );

    final nameOf = {for (final group in _groups) group.id: group.name};
    final rows = <Widget>[];
    for (final section in sections) {
      rows.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            section.isUngrouped ? L10n.of(context).likes_without_a_group : nameOf[section.groupId] ?? '',
            style: Theme.of(context).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
      rows.addAll(section.items.map((like) => SavedTweetTile(id: like.id, content: like.content)));
    }

    return ListView(physics: const AlwaysScrollableScrollPhysics(), children: rows);
  }

  Widget _buildFavoritesBody() {
    var model = context.read<LikedTweetModel>();

    return ScopedBuilder<LikedTweetModel, List<LikedTweet>>.transition(
      store: model,
      onError: (_, e) => FullPageErrorWidget(
        error: e,
        stackTrace: null,
        prefix: L10n.current.unable_to_load_the_tweets,
        onRetry: () => model.listLikedTweets(),
      ),
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onState: (_, data) {
        var filtered = applySavedSort(_applySearch(data, (LikedTweet e) => e.content), _view.state.sort);
        _visibleSavedIds = const [];

        if (_mediaOnly && filtered.isNotEmpty) {
          return _buildMediaGrid(
            filtered.map((e) => e.content),
            onDelete: (id) => context.read<LikedTweetModel>().unlikeTweet(id),
          );
        }

        if (_likesByGroup && filtered.isNotEmpty) {
          return RefreshIndicator(onRefresh: _refresh, child: _buildLikesByGroup(filtered));
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: filtered.isEmpty
              ? _buildEmptyState()
              : _buildList(
                  itemCount: filtered.length,
                  tileAt: (i) => SavedTweetTile(id: filtered[i].id, content: filtered[i].content),
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var model = context.read<SavedTweetModel>();

    var prefs = PrefService.of(context, listen: false);
    final view = _view.state;
    final allSelected = _visibleSavedIds.isNotEmpty && _visibleSavedIds.every(view.selectedIds.contains);

    return NestedScrollView(
      controller: widget.scrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          if (widget.showTitle != false)
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: useDesktopShell(context),
              snap: !useDesktopShell(context),
              floating: !useDesktopShell(context),
              title: view.selecting
                  ? Text(L10n.current.library_selected_count(view.selectedIds.length))
                  : (useDesktopShell(context) ? null : Text(L10n.current.saved)),
              actions: view.selecting
                  ? [
                      IconButton(
                        tooltip: L10n.current.close,
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_view.finishSelection),
                      ),
                      IconButton(
                        key: const ValueKey('saved-select-all'),
                        tooltip: allSelected ? L10n.current.library_clear_selection : L10n.current.library_select_all,
                        icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                        onPressed: () =>
                            setState(() => _view.selectVisible(allSelected ? const <String>[] : _visibleSavedIds)),
                      ),
                      IconButton(
                        key: const ValueKey('saved-move-selected'),
                        tooltip: L10n.current.library_move_selected,
                        icon: const Icon(Icons.drive_file_move_outline),
                        onPressed: view.selectedIds.isEmpty ? null : _moveSelected,
                      ),
                      IconButton(
                        key: const ValueKey('saved-delete-selected'),
                        tooltip: L10n.current.delete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: view.selectedIds.isEmpty ? null : _deleteSelected,
                      ),
                    ]
                  : [
                      SavedLibraryActionButton(
                        sort: view.sort,
                        canSelect: _filter != savedTabFavorites,
                        onSelected: _handleLibraryAction,
                      ),
                      IconButton(
                        isSelected: _searching,
                        icon: const Icon(Icons.search),
                        tooltip: L10n.current.search_saved_posts,
                        onPressed: () => setState(() {
                          _searching = !_searching;
                          if (_searching) {
                            WidgetsBinding.instance.addPostFrameCallback((_) => _searchFocusNode.requestFocus());
                          } else {
                            _query = '';
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                          }
                        }),
                      ),
                      IconButton(
                        isSelected: _mediaOnly,
                        icon: const Icon(Icons.photo_library_outlined),
                        selectedIcon: const Icon(Icons.photo_library),
                        tooltip: L10n.current.only_show_posts_with_media,
                        onPressed: () => setState(() => _mediaOnly = !_mediaOnly),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_copy_outlined),
                        tooltip: L10n.current.manage_folders,
                        onPressed: () async {
                          await Navigator.pushNamed(context, routeSavedFolders);
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: L10n.current.find_broken_bookmarks,
                        onPressed: () => showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => const BrokenBookmarksDialog(),
                        ),
                      ),
                      if (!useDesktopShell(context))
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () async {
                            Navigator.pushNamed(context, routeSettings);
                          },
                        ),
                    ],
            ),
        ];
      },
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider<TweetContextState>(
            create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive)),
          ),
        ],
        child: Column(
          children: [
            _buildFolderStrip(),
            if (_searching) _buildSearchField(),
            Expanded(child: _filter == savedTabFavorites ? _buildFavoritesBody() : _buildSavedBody(model)),
          ],
        ),
      ),
    );
  }
}

class SavedTweetTile extends StatelessWidget {
  final String id;
  final String? content;

  const SavedTweetTile({super.key, required this.id, this.content});

  @override
  Widget build(BuildContext context) {
    var content = this.content;
    if (content == null) {
      // The tweet is probably too big to fit inside the cursor and has been removed from the result set
      return SavedTweetTooLarge(id: id);
    }

    final tweet = decodeSavedPost(content);
    if (tweet == null || tweet.idStr == null) return SavedTweetTooLarge(id: id);

    return TweetTile(key: Key(tweet.idStr!), tweet: tweet, clickable: true);
  }
}

class SavedTweetTooLarge extends StatelessWidget {
  final String id;

  const SavedTweetTooLarge({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(
                Icons.error_outline,
                color: Colors.red.harmonizeWith(Theme.of(context).colorScheme.primary),
              ),
              title: Text(L10n.current.oops_something_went_wrong),
              subtitle: Text(L10n.current.reader_saved_unreadable),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: L10n.current.reader_open_post,
                onPressed: () => openStatus(context, StatusScreenArguments(id: id, username: null)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SavedTweetTooLargeException implements Exception {
  final String id;

  SavedTweetTooLargeException(this.id);

  @override
  String toString() {
    return 'The saved tweet with the ID $id was too large';
  }
}
