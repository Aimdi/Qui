import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/plugins/reddit/reddit_actions.dart';
import 'package:qui/plugins/reddit/reddit_sort_sheet.dart';
import 'package:qui/plugins/reddit/reddit_store.dart';

/// What Reddit does outside its own tab.
///
/// Sign-in, client id, source and followed subreddits used to live only in the
/// Reddit tab's overflow menu. With "Show as a tab" off there was no way to
/// reach them on desktop. Everything the tab can configure is here too.
class RedditSettingsScreen extends StatefulWidget {
  const RedditSettingsScreen({super.key});

  @override
  State<RedditSettingsScreen> createState() => _RedditSettingsScreenState();
}

class _RedditSettingsScreenState extends State<RedditSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RedditSubredditsStore>().load();
    });
  }

  Future<void> _setSource(String value) async {
    final feed = context.read<RedditFeedStore>();
    await PrefService.of(
      context,
      listen: false,
    ).set(optionPluginRedditSource, value);
    if (!mounted) return;
    setState(() {});
    await feed.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final prefs = PrefService.of(context);
    final sort = storedRedditSort(prefs);
    final entry = redditSortLabel(context, sort);
    final source =
        prefs.get<String>(optionPluginRedditSource) ?? redditSourceAuto;
    final signedIn = redditSignedIn(prefs);
    final clientId = prefs.get<String>(optionPluginRedditClientId) ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plugin_reddit_title)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.plugin_reddit_in_home_feed),
            subtitle: Text(l10n.plugin_reddit_in_home_feed_description),
            value: prefs.get<bool>(optionPluginRedditInHomeFeed) == true,
            onChanged: (value) async {
              await prefs.set(optionPluginRedditInHomeFeed, value);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: Icon(entry.icon),
            title: Text(l10n.plugin_reddit_sort),
            subtitle: Text(entry.label),
            onTap: () async {
              await openRedditSortSheet(context);
              if (mounted) setState(() {});
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              source == redditSourceAuto
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(l10n.plugin_reddit_source_auto),
            subtitle: Text(l10n.plugin_reddit_source_auto_description),
            onTap: () => _setSource(redditSourceAuto),
          ),
          ListTile(
            leading: Icon(
              source == redditSourcePublic
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
            ),
            title: Text(l10n.plugin_reddit_source_public),
            subtitle: Text(l10n.plugin_reddit_source_public_description),
            onTap: () => _setSource(redditSourcePublic),
          ),
          ListTile(
            leading: Icon(signedIn ? Icons.logout : Icons.login),
            title: Text(
              signedIn
                  ? l10n.plugin_reddit_sign_out
                  : l10n.plugin_reddit_sign_in,
            ),
            onTap: () async {
              if (signedIn) {
                await signOutReddit(context);
              } else {
                await signInReddit(context);
              }
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: Text(l10n.plugin_reddit_client_id),
            subtitle: clientId.isEmpty ? null : Text(clientId),
            onTap: () async {
              await editRedditClientId(context);
              if (mounted) setState(() {});
            },
          ),
          const Divider(),
          ListTile(
            title: Text(l10n.subscriptions),
            trailing: IconButton(
              tooltip: l10n.plugin_reddit_add,
              icon: const Icon(Icons.add),
              onPressed: () async {
                await addRedditSubreddit(context);
                if (mounted) setState(() {});
              },
            ),
          ),
          ScopedBuilder<RedditSubredditsStore, List<String>>(
            store: context.read<RedditSubredditsStore>(),
            onState: (context, names) {
              if (names.isEmpty) {
                return ListTile(subtitle: Text(l10n.plugin_reddit_empty));
              }
              return Column(
                children: [
                  for (final name in names)
                    ListTile(
                      title: Text('r/$name'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await context.read<RedditSubredditsStore>().remove(
                            name,
                          );
                          if (context.mounted) {
                            await refreshRedditAfterChange(context);
                          }
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
