import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qui/constants.dart';
import 'package:qui/database/entities.dart';
import 'package:qui/database/repository.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/subscriptions/_import.dart' show SubscriptionImportScreen;
import 'package:url_launcher/url_launcher_string.dart';

/// Desktop login: paste `auth_token` and `ct0` cookies from a browser session.
///
/// WebView login is unreliable on Linux/desktop toolkits, so Qui uses an
/// explicit cookie form instead. Open x.com in your browser, log in, copy the
/// two cookies, and paste them here.
class DesktopCookieLoginScreen extends StatefulWidget {
  const DesktopCookieLoginScreen({super.key});

  @override
  State<DesktopCookieLoginScreen> createState() => _DesktopCookieLoginScreenState();
}

class _DesktopCookieLoginScreenState extends State<DesktopCookieLoginScreen> {
  final _authTokenController = TextEditingController();
  final _ct0Controller = TextEditingController();
  final _screenNameController = TextEditingController();
  final _guestIdController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _authTokenController.dispose();
    _ct0Controller.dispose();
    _screenNameController.dispose();
    _guestIdController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final authToken = _authTokenController.text.trim();
    final ct0 = _ct0Controller.text.trim();
    final screenName = _screenNameController.text.trim().replaceAll('@', '');
    final guestId = _guestIdController.text.trim();

    if (authToken.isEmpty || ct0.isEmpty || screenName.isEmpty) {
      setState(() => _error = 'auth_token, ct0 and screen name are required');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final cookieParts = <String>[
        if (guestId.isNotEmpty) 'guest_id=$guestId',
        'auth_token=$authToken',
        'ct0=$ct0',
      ];
      final authHeader = {
        'Cookie': cookieParts.join(';'),
        'authorization': bearerToken,
        'x-csrf-token': ct0,
      };

      final database = await Repository.writable();
      await database.insert(
        tableAccounts,
        Account(
          id: ct0,
          screenName: screenName,
          authHeader: json.encode(authHeader),
        ).toMap(),
      );
      await database.close();

      if (!mounted) return;
      Navigator.pop(context);
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(L10n.of(context).import_subscriptions),
          content: Text(L10n.of(context).import_subscriptions_text(screenName)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).no)),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionImportScreen()),
                );
              },
              child: Text(L10n.of(context).yes),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).login)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Sign in to X on desktop', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Open x.com in your browser, log in, then paste the auth_token and ct0 '
                'cookies (DevTools → Application → Cookies → x.com). Your session stays '
                'on this machine only.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => launchUrlString(
                  'https://x.com/i/flow/login',
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open X login in browser'),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _screenNameController,
                decoration: const InputDecoration(
                  labelText: 'Screen name (without @)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _authTokenController,
                decoration: const InputDecoration(
                  labelText: 'auth_token cookie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ct0Controller,
                decoration: const InputDecoration(
                  labelText: 'ct0 cookie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _guestIdController,
                decoration: const InputDecoration(
                  labelText: 'guest_id cookie (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(L10n.of(context).login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
