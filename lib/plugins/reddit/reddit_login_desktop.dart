import 'package:flutter/material.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/plugins/reddit/reddit_auth.dart';
import 'package:qui/utils/urls.dart';

/// Desktop Reddit sign-in: webview_flutter has no Linux/Windows implementation,
/// so the authorization page opens in the system browser and the reader pastes
/// the redirect back — the same paste pattern as the cookie login in
/// `lib/client/desktop_login.dart`.
///
/// Pops the authorization code, or null when the reader backs out or declines.
/// The contract matches `RedditLoginWebview`, so the caller trades the code for
/// a refresh token the same way on every platform and nothing is stored here.
class RedditLoginDesktop extends StatefulWidget {
  final String clientId;

  /// Echoed back by Reddit and checked on return, so a code from anywhere else
  /// is ignored.
  final String state;

  const RedditLoginDesktop({super.key, required this.clientId, required this.state});

  @override
  State<RedditLoginDesktop> createState() => _RedditLoginDesktopState();
}

class _RedditLoginDesktopState extends State<RedditLoginDesktop> {
  final _redirectController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _redirectController.dispose();
    super.dispose();
  }

  Future<void> _openAuthorizePage() async {
    await openInDefaultBrowser(
      RedditAuth.authorizeUrl(clientId: widget.clientId, state: widget.state).toString(),
    );
  }

  void _submit() {
    final pasted = _redirectController.text.trim();
    final uri = Uri.tryParse(pasted);
    if (pasted.isEmpty || uri == null) {
      setState(() => _error = 'Paste the whole ${RedditAuth.redirectUri}… address');
      return;
    }

    // The reader declined on Reddit's page; close quietly, exactly as the
    // webview path does, rather than reporting a failure.
    if (RedditAuth.deniedIn(uri)) {
      Navigator.of(context).pop(null);
      return;
    }

    final code = RedditAuth.codeFrom(uri, expectedState: widget.state);
    if (code == null) {
      setState(() => _error =
          'That is not the redirect for this sign-in attempt. Paste the ${RedditAuth.redirectUri}… address the browser was sent to.');
      return;
    }

    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).plugin_reddit_sign_in)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(L10n.of(context).plugin_reddit_sign_in, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Sign in on reddit.com in your browser and allow the app. Reddit then '
                'sends the browser to an address starting with ${RedditAuth.redirectUri} — '
                'the page will not load, which is expected. Copy that address from the '
                "browser's address bar and paste it below. Nothing else leaves this machine.",
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openAuthorizePage,
                icon: const Icon(Icons.open_in_new),
                label: Text(L10n.of(context).open_in_browser),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _redirectController,
                autofocus: true,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Redirect address (${RedditAuth.redirectUri}…)',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: Text(L10n.of(context).plugin_reddit_sign_in),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
