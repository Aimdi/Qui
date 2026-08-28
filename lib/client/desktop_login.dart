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
  State<DesktopCookieLoginScreen> createState() =>
      _DesktopCookieLoginScreenState();
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
      setState(() => _error = L10n.of(context).desktop_login_fields_required);
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L10n.of(context).no),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SubscriptionImportScreen(),
                  ),
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
              Text(
                L10n.of(context).desktop_login_headline,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                L10n.of(context).desktop_login_instructions,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => launchUrlString(
                  'https://x.com/i/flow/login',
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: Text(L10n.of(context).open_in_browser),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _screenNameController,
                decoration: InputDecoration(
                  labelText: L10n.of(context).desktop_login_screen_name,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _authTokenController,
                decoration: InputDecoration(
                  labelText: L10n.of(context).desktop_login_auth_token,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ct0Controller,
                decoration: InputDecoration(
                  labelText: L10n.of(context).desktop_login_ct0,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _guestIdController,
                decoration: InputDecoration(
                  labelText: L10n.of(context).desktop_login_guest_id,
                  border: const OutlineInputBorder(),
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
