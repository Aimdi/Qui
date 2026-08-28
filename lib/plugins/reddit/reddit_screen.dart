import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/plugins/reddit/reddit_actions.dart';
import 'package:qui/plugins/reddit/reddit_client.dart';
import 'package:qui/plugins/reddit/reddit_feed_list.dart';
import 'package:qui/plugins/reddit/reddit_search_screen.dart';
import 'package:qui/plugins/reddit/reddit_sort_sheet.dart';
import 'package:qui/plugins/reddit/reddit_store.dart';
import 'package:qui/ui/tab_app_bar.dart';

String redditErrorMessage(L10n l10n, Object error) {
  if (error is RedditException) {
    final explanation = switch (error.kind) {
      RedditErrorKind.notConfigured => l10n.plugin_reddit_not_configured,
      RedditErrorKind.unauthorized => l10n.plugin_reddit_error_client_id,
      RedditErrorKind.blocked => l10n.plugin_reddit_error_blocked,
      RedditErrorKind.notFound => l10n.plugin_reddit_error_not_found,
      RedditErrorKind.rateLimited => l10n.plugin_reddit_error_rate_limited,
      RedditErrorKind.badResponse => l10n.plugin_reddit_error_response,
      RedditErrorKind.network => l10n.plugin_reddit_error_network,
    };

    // The translated sentence says what to do; the detail says what actually
    // happened. Without it a refusal, a timeout and a reshaped response all
    // read the same, and "it doesn't work" is all anyone can report back.
    return error.detail.isEmpty
        ? explanation
        : '$explanation\n\n${error.detail}';
  }
  return '$error';
}

/// Account-free Reddit reading: the subreddits you follow, newest first.
class RedditScreen extends StatefulWidget {
  final ScrollController scrollController;

  const RedditScreen({super.key, required this.scrollController});

  @override
  State<RedditScreen> createState() => _RedditScreenState();
}

class _RedditScreenState extends State<RedditScreen> {
  /// Which route Reddit is read through.
  ///
  /// The client would otherwise decide silently from whatever credentials
  /// happen to be stored, so a reader who would rather not be identified had no
  /// way to say so while a sign-in existed.
  Widget _sourceMenu(BuildContext context) {
    final prefs = PrefService.of(context);
    final l10n = L10n.of(context);

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: l10n.plugin_reddit_source,
      onSelected: (value) => _onMenuSelected(value, prefs),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: redditSourceAuto,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.plugin_reddit_source_auto),
            subtitle: Text(l10n.plugin_reddit_source_auto_description),
          ),
        ),
        PopupMenuItem(
          value: redditSourcePublic,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.plugin_reddit_source_public),
            subtitle: Text(l10n.plugin_reddit_source_public_description),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _menuSignIn,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_signedIn ? Icons.logout : Icons.login),
            title: Text(
              _signedIn
                  ? l10n.plugin_reddit_sign_out
                  : l10n.plugin_reddit_sign_in,
            ),
          ),
        ),
        PopupMenuItem(
          value: _menuClientId,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key),
            title: Text(l10n.plugin_reddit_client_id),
          ),
        ),
      ],
    );
  }

  /// Values the menu uses for the actions that are not a source choice.
  static const _menuSignIn = '_signIn';
  static const _menuClientId = '_clientId';

  Future<void> _onMenuSelected(String value, BasePrefService prefs) async {
    if (value == _menuSignIn) {
      if (_signedIn) {
        await signOutReddit(context);
      } else {
        await signInReddit(context);
      }
      if (mounted) setState(() {});
      return;
    }
    if (value == _menuClientId) {
      await editRedditClientId(context);
      if (mounted) setState(() {});
      return;
    }

    await prefs.set(optionPluginRedditSource, value);
    if (mounted) {
      await context.read<RedditFeedStore>().refresh();
    }
  }

  bool get _signedIn => redditSignedIn(PrefService.of(context, listen: false));

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: tabAppBar(
        context: context,
        title: Text(l10n.plugin_reddit_title),
        actions: [
          IconButton(
            tooltip: l10n.plugin_reddit_sort,
            icon: Icon(
              redditSortLabel(
                context,
                storedRedditSort(PrefService.of(context)),
              ).icon,
            ),
            onPressed: () async {
              final chosen = await openRedditSortSheet(context);
              if (chosen == null || !context.mounted) return;
              await context.read<RedditFeedStore>().refresh();
            },
          ),
          IconButton(
            tooltip: l10n.plugin_reddit_search_hint,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RedditSearchScreen()),
            ),
          ),
          IconButton(
            tooltip: l10n.plugin_reddit_add,
            icon: const Icon(Icons.add),
            onPressed: () async {
              await addRedditSubreddit(context);
              if (mounted) setState(() {});
            },
          ),
          IconButton(
            tooltip: l10n.subscriptions,
            icon: const Icon(Icons.list),
            onPressed: () async {
              await manageRedditSubreddits(context);
              if (mounted) setState(() {});
            },
          ),
          _sourceMenu(context),
        ],
      ),
      body: RedditFeedList(
        scrollController: widget.scrollController,
        onAddSubreddit: () => addRedditSubreddit(context),
      ),
    );
  }
}
