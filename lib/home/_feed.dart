import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/group/_feed_shell.dart';
import 'package:qui/group/group_model.dart';
import 'package:qui/group/group_screen.dart';
import 'package:qui/home/_for_you.dart';
import 'package:qui/home/home_timeline_controls.dart';
import 'package:qui/plugins/reddit/reddit_feed_list.dart';
import 'package:qui/tweet/paginated_tweet_list.dart';

typedef FeedTabTitleBuilder = String Function(BuildContext context);

enum FeedTab { following, foryou, reddit }

IconData feedTabIcon(FeedTab tab) => switch (tab) {
  FeedTab.following => Icons.home_outlined,
  FeedTab.foryou => Icons.auto_awesome_outlined,
  FeedTab.reddit => Icons.forum_outlined,
};

class FeedTabOption {
  final FeedTab id;
  final FeedTabTitleBuilder titleBuilder;

  FeedTabOption(this.id, this.titleBuilder);
}

final List<FeedTabOption> feedTabs = [
  FeedTabOption(FeedTab.following, (c) => L10n.of(c).following),
  FeedTabOption(FeedTab.foryou, (c) => L10n.of(c).foryou),
  FeedTabOption(FeedTab.reddit, (c) => L10n.of(c).plugin_reddit_title),
];

/// The feeds the switcher currently offers.
///
/// Reddit is one of them only while its plugin is on — an entry that led to an
/// empty screen would be worse than no entry, and the choice is stored by name
/// so turning the plugin off simply stops offering it.
List<FeedTabOption> availableFeedTabs(BasePrefService prefs) => feedTabs
    .where(
      (e) =>
          e.id != FeedTab.reddit ||
          prefs.get<bool>(optionPluginRedditEnabled) == true,
    )
    .toList(growable: false);

FeedTab feedTabFromId(String? id) => FeedTab.values.firstWhere(
      (e) => e.name == id,
      orElse: () => FeedTab.following,
    );

class FeedScreen extends StatefulWidget {
  final ScrollController scrollController;
  final String id;
  final String name;

  const FeedScreen({
    super.key,
    required this.scrollController,
    required this.id,
    required this.name,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin<FeedScreen> {
  final TweetFeedController _feedController = TweetFeedController();
  FeedTab? _tab;
  bool _followingMediaOnly = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _selectTab(BasePrefService prefs, FeedTab value) async {
    if (_tab == value) return;

    setState(() => _tab = value);
    await prefs.set(optionHomeDefaultFeedTab, value.name);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final BasePrefService prefs = PrefService.of(context);
    final available = availableFeedTabs(prefs);
    var tab =
        _tab ??= feedTabFromId(prefs.get<String>(optionHomeDefaultFeedTab));

    // The plugin can be turned off while its feed is the one being shown.
    if (!available.any((e) => e.id == tab)) {
      tab = _tab = FeedTab.following;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        prefs.set(optionHomeDefaultFeedTab, FeedTab.following.name);
      });
    }

    final sourceOptions = [
      for (final option in available)
        HomeSourceOption<FeedTab>(
          value: option.id,
          label: option.titleBuilder(context),
          icon: feedTabIcon(option.id),
        ),
    ];

    return GroupFeedShell(
      scrollController: widget.scrollController,
      groupId: widget.id,
      titleBuilder: (context) => HomeSourceSwitcher<FeedTab>(
        selected: tab,
        options: sourceOptions,
        onSelected: (value) => _selectTab(prefs, value),
      ),
      actionsBuilder: (context) {
        final model = context.read<GroupModel>();
        return defaultGroupActions(
          context,
          model: model,
          showMore: tab == FeedTab.following,
          scrollToTopController: widget.scrollController,
        );
      },
      bodyBuilder: (context) {
        final body = switch (tab) {
          FeedTab.following => SubscriptionGroupScreenContent(
              id: widget.id,
              mediaOnly: _followingMediaOnly,
            ),
          FeedTab.reddit => RedditFeedList(
              scrollController: widget.scrollController,
            ),
          FeedTab.foryou => ForYouTweets(
              _feedController,
              type: 'profile',
              includeReplies: false,
              pref: prefs,
            ),
        };

        return Column(
          children: [
            if (tab == FeedTab.following)
              HomeReadingControls(
                mediaOnly: _followingMediaOnly,
                onMediaToggle: () => setState(
                  () => _followingMediaOnly = !_followingMediaOnly,
                ),
              ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}
