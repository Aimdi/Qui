import 'package:flutter/material.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/plugins/karakeep/karakeep_settings_screen.dart';
import 'package:qui/plugins/plugin.dart';

/// Sends links to a self-hosted Karakeep instance. No home tab: the plugin adds
/// a save action where links already are, plus its own settings screen.
class KarakeepPlugin extends QuaxPlugin {
  KarakeepPlugin();

  @override
  String get id => pluginIdKarakeep;

  @override
  String get enabledPrefKey => optionPluginKarakeepEnabled;

  @override
  IconData get icon => Icons.bookmark_add_outlined;

  @override
  String title(BuildContext context) => L10n.of(context).plugin_karakeep_title;

  @override
  String description(BuildContext context) => L10n.of(context).plugin_karakeep_description;

  @override
  Widget? settingsScreen(BuildContext context) => const KarakeepSettingsScreen();
}
