import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/plugins/reddit/reddit_auth.dart';
import 'package:qui/plugins/reddit/reddit_client.dart';
import 'package:qui/plugins/reddit/reddit_login_desktop.dart';
import 'package:qui/plugins/reddit/reddit_login_webview.dart';
import 'package:qui/plugins/reddit/reddit_store.dart';
import 'package:qui/subscriptions/users_model.dart';
import 'package:qui/ui/adaptive_sheet.dart';
import 'package:qui/ui/errors.dart';
import 'package:qui/utils/desktop_files.dart';

bool redditSignedIn(BasePrefService prefs) =>
    (prefs.get<String>(optionPluginRedditRefreshToken) ?? '').isNotEmpty;

/// The feed and the subscription list both have to hear about it: a subreddit
/// is a group member now, and the group editor reads that list rather than
/// the store the Reddit screen keeps.
Future<void> refreshRedditAfterChange(BuildContext context) async {
  final subscriptions = context.read<SubscriptionsModel>();
  await context.read<RedditFeedStore>().refresh();
  await subscriptions.reloadSubscriptions();
}

Future<void> editRedditClientId(BuildContext context) async {
  final prefs = PrefService.of(context, listen: false);
  final controller = TextEditingController(
    text: prefs.get<String>(optionPluginRedditClientId) ?? '',
  );

  final saved = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = L10n.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.plugin_reddit_client_id),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.plugin_reddit_client_id_help,
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // Reddit rejects the login unless the registered app carries this
            // exact redirect, and it is not guessable — so it is stated here
            // rather than left to be discovered.
            Text(
              l10n.plugin_reddit_redirect_uri_help(RedditAuth.redirectUri),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: l10n.plugin_reddit_client_id,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );

  if (saved == null || !context.mounted) return;
  await prefs.set(optionPluginRedditClientId, saved);
  if (!context.mounted) return;
  context.read<RedditClient>().forgetToken();
  await context.read<RedditFeedStore>().refresh();
}

/// Signing in gets the reader their own account's rate limits, which is the
/// most reliable route Reddit offers. It still needs a client id: the login
/// authorises *this app*, and Reddit has to know which app that is.
Future<void> signInReddit(BuildContext context) async {
  final prefs = PrefService.of(context, listen: false);
  final clientId = prefs.get<String>(optionPluginRedditClientId) ?? '';
  if (clientId.trim().isEmpty) {
    await editRedditClientId(context);
    return;
  }

  // Echoed back by Reddit and checked on return, so a code from anywhere
  // else is refused.
  final state = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  // webview_flutter has no Linux/Windows implementation, so desktop opens
  // the system browser and takes the redirect back by paste instead. Both
  // screens pop the same authorization code, so everything after this line
  // is shared.
  final code = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => isDesktop
          ? RedditLoginDesktop(clientId: clientId, state: state)
          : RedditLoginWebview(clientId: clientId, state: state),
    ),
  );

  if (code == null || !context.mounted) return;

  try {
    final refreshToken = await context.read<RedditAuth>().exchangeCode(
      clientId: clientId,
      code: code,
    );
    await prefs.set(optionPluginRedditRefreshToken, refreshToken);
    if (context.mounted) {
      showSnackBar(
        context,
        icon: '✅',
        message: L10n.of(context).plugin_reddit_signed_in,
      );
      await context.read<RedditFeedStore>().refresh();
    }
  } on RedditException catch (e) {
    if (context.mounted) {
      showSnackBar(
        context,
        icon: '🔒',
        message:
            '${L10n.of(context).plugin_reddit_sign_in_failed}\n${e.detail}',
      );
    }
  }
}

Future<void> signOutReddit(BuildContext context) async {
  final prefs = PrefService.of(context, listen: false);
  await prefs.set(optionPluginRedditRefreshToken, '');
  if (context.mounted) {
    await context.read<RedditFeedStore>().refresh();
  }
}

Future<void> addRedditSubreddit(BuildContext context) async {
  final controller = TextEditingController();
  final entered = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final l10n = L10n.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.plugin_reddit_add),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'r/dartlang'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.ok),
          ),
        ],
      );
    },
  );

  if (entered == null || entered.isEmpty || !context.mounted) return;

  if (normaliseSubreddit(entered) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.of(context).plugin_reddit_error_not_found)),
    );
    return;
  }

  await context.read<RedditSubredditsStore>().add(entered);
  if (context.mounted) {
    await refreshRedditAfterChange(context);
  }
}

Future<void> manageRedditSubreddits(BuildContext context) async {
  await showAdaptiveSheet(
    context: context,
    builder: (sheetContext) {
      final store = sheetContext.read<RedditSubredditsStore>();
      return SafeArea(
        child: ScopedBuilder<RedditSubredditsStore, List<String>>(
          store: store,
          onState: (_, names) => ListView(
            shrinkWrap: true,
            children: [
              for (final name in names)
                ListTile(
                  title: Text('r/$name'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await store.remove(name);
                      if (sheetContext.mounted) {
                        await refreshRedditAfterChange(sheetContext);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
