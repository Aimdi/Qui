import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/database/entities.dart';
import 'package:qui/group/_settings.dart';
import 'package:qui/group/feed_refresh_controller.dart';
import 'package:qui/group/group_model.dart';
import 'package:qui/subscriptions/users_model.dart';
import 'package:qui/ui/layout.dart';

class GroupFeedShell extends StatefulWidget {
  final ScrollController scrollController;
  final String groupId;
  final WidgetBuilder titleBuilder;
  final WidgetBuilder bodyBuilder;
  final List<Widget> Function(BuildContext) actionsBuilder;
  // Whether the body's feed keeps its PagingController in the FeedSessionCache.
  // Only then does a subscription change require remounting the body (to drop
  // the just-invalidated cached controller); other feeds refresh on their own
  // when their group state actually changes.
  final bool usesFeedCache;

  const GroupFeedShell({
    super.key,
    required this.scrollController,
    required this.groupId,
    required this.titleBuilder,
    required this.bodyBuilder,
    required this.actionsBuilder,
    this.usesFeedCache = false,
  });

  @override
  State<GroupFeedShell> createState() => _GroupFeedShellState();
}

class _GroupFeedShellState extends State<GroupFeedShell> with AutomaticKeepAliveClientMixin<GroupFeedShell> {
  late final GroupModel _groupModel;
  final FeedRefreshController _feedRefreshController = FeedRefreshController();
  int _refreshCounter = 0;
  // Cached refs captured in didChangeDependencies — accessing the InheritedWidget
  // tree via context.read in dispose() triggers a framework warning, since
  // ancestors may already be unmounted by then.
  SubscriptionsModel? _subscriptionsModel;
  GroupsModel? _groupsModel;

  late final String _callbackKey = 'GroupFeedShell-${widget.groupId}-${identityHashCode(this)}';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _groupModel = GroupModel(widget.groupId)..loadGroup();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSubs = context.read<SubscriptionsModel>();
    final newGroups = context.read<GroupsModel>();
    if (!identical(newSubs, _subscriptionsModel) || !identical(newGroups, _groupsModel)) {
      _subscriptionsModel?.removeReloadListener(_callbackKey);
      _groupsModel?.removeReloadListener(_callbackKey);
      _subscriptionsModel = newSubs;
      _groupsModel = newGroups;
      _subscriptionsModel!.addReloadListener(_callbackKey, _onReload);
      _groupsModel!.addReloadListener(_callbackKey, _onReload);
    }
  }

  // What the feed actually shows; a reload only warrants remounting the body
  // when this changes, otherwise following someone unrelated would needlessly
  // reload the open timeline.
  String _fingerprint(SubscriptionGroupGet group) {
    final members = group.subscriptions.map((s) => '${s.id}:${s.inFeed}').join(',');
    return '$members|${group.includeReplies}|${group.includeRetweets}|${group.popular}|${group.custom}|${group.contentFilter}';
  }

  // Triggered when subscriptions or group memberships change. A single user
  // action can fire this several times in a row (subscriptions and groups both
  // reload), so the reaction is debounced into one refresh. The body is only
  // remounted for cache-backed feeds whose content actually changed; everything
  // else just reloads its group state and the feed decides on its own.
  void _onReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      final before = _fingerprint(_groupModel.state);
      await _groupModel.loadGroup();
      if (!mounted) return;
      setState(() {
        if (widget.usesFeedCache && _fingerprint(_groupModel.state) != before) {
          _refreshCounter++;
        }
      });
    });
  }

  Timer? _reloadDebounce;

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _subscriptionsModel?.removeReloadListener(_callbackKey);
    _groupsModel?.removeReloadListener(_callbackKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final prefs = PrefService.of(context);
    final deckMode = useDesktopShell(context) && prefs.get(optionDeckMode) == true;

    return Provider<GroupModel>.value(
      value: _groupModel,
      builder: (context, child) {
        return Provider<FeedRefreshController>.value(
          value: _feedRefreshController,
          builder: (context, child) {
            // Actions must be built below both providers — they read GroupModel
            // at build time and FeedRefreshController from tap callbacks.
            final actions = widget.actionsBuilder(context);
            // Deck columns already show a title strip — only keep action icons.
            return deckMode
              ? Column(
                  children: [
                    if (actions.isNotEmpty)
                      Material(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                        child: SizedBox(
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: actions,
                          ),
                        ),
                      ),
                    Expanded(
                      // Feeds attach to PrimaryScrollController (normally from
                      // NestedScrollView). Wire the shell controller in deck mode.
                      child: PrimaryScrollController(
                        controller: widget.scrollController,
                        child: KeyedSubtree(
                          key: ValueKey(_refreshCounter),
                          child: widget.bodyBuilder(context),
                        ),
                      ),
                    ),
                  ],
                )
              : NestedScrollView(
                  controller: widget.scrollController,
                  floatHeaderSlivers: true,
                  headerSliverBuilder: (context, innerBoxIsScrolled) {
                    return [
                      SliverAppBar(
                        backgroundColor:
                            Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                        surfaceTintColor: Colors.transparent,
                        pinned: useDesktopShell(context),
                        snap: !useDesktopShell(context),
                        floating: !useDesktopShell(context),
                        centerTitle: false,
                        title: widget.titleBuilder(context),
                        actions: actions,
                      ),
                    ];
                  },
                  body: KeyedSubtree(
                    key: ValueKey(_refreshCounter),
                    child: widget.bodyBuilder(context),
                  ),
                );
          },
        );
      },
    );
  }
}

/// Builds the standard action-bar icons shared by group feeds:
/// optional "more" (group settings), optional "scroll-to-top", refresh, and
/// the global settings button.
List<Widget> defaultGroupActions(
  BuildContext context, {
  required GroupModel model,
  ScrollController? scrollToTopController,
  bool showMore = true,
  bool showRefresh = true,
  bool showSettings = true,
  VoidCallback? onRefresh,
  List<Widget> extra = const [],
}) {
  return [
    if (showMore)
      IconButton(icon: const Icon(Icons.build_outlined), onPressed: () => showFeedSettings(context, model)),
    if (scrollToTopController != null)
      IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () async {
            final disableAnimations = PrefService.of(context).get(optionDisableAnimations) == true;
            await scrollToTopController.animateTo(0,
                duration: disableAnimations ? Duration.zero : const Duration(seconds: 1),
                curve: Curves.easeInOut);
          }),
    if (showRefresh)
      IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh',
          onPressed: onRefresh ?? () async => await context.read<FeedRefreshController>().refresh()),
    // Settings lives on the desktop rail; keep the AppBar action on compact only.
    if (showSettings && !useDesktopShell(context))
      IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.pushNamed(context, routeSettings)),
    ...extra,
  ];
}
