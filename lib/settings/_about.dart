import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/utils/urls.dart';
import 'package:pref/pref.dart';

class SettingsAboutFragment extends StatelessWidget {
  final String appVersion;

  const SettingsAboutFragment({super.key, required this.appVersion});

  Future<void> _appInfo(BuildContext context) async {
    var packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;

    // Report the real platform (Platform.operatingSystem is one of android /
    // ios / linux / macos / windows) instead of the previous hard-coded 'ios',
    // and always show the dialog — the old Android branch built metadata but
    // never opened it.
    final metadata = <String, Object>{
      'locale': Localizations.localeOf(context).languageCode,
      'os': Platform.operatingSystem,
      'version': packageInfo.buildNumber,
    };
    final content = JsonEncoder.withIndent(' ' * 2).convert(metadata);

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(L10n.of(context).ok)),
              ],
              title: Text(L10n.of(context).app_info),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(content, style: const TextStyle(fontFamily: 'monospace'))
                ],
              ));
        });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
          onLongPress: () => _appInfo(context),
          onSecondaryTap: () => _appInfo(context),
          child: PrefLabel(
            leading: const Icon(Icons.info),
            title: Text(L10n.of(context).version),
            subtitle: Text(appVersion),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: appVersion));

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(L10n.of(context).copied_version_to_clipboard),
                ));
              }
            },
          )),
      PrefLabel(
        leading: const Icon(Icons.favorite),
        title: Text(L10n.of(context).contribute),
        subtitle: Text(L10n.of(context).help_make_fritter_even_better),
        onTap: () => openUri(context, 'https://github.com/Aimdi/Qui'),
      ),
      PrefLabel(
        leading: const Icon(Icons.bug_report),
        title: Text(L10n.of(context).report_a_bug),
        subtitle: Text(
          L10n.of(context).let_the_developers_know_if_something_is_broken,
        ),
        onTap: () => openUri(context, 'https://github.com/Aimdi/Qui/issues'),
      ),
      PrefLabel(
        leading: const Icon(Icons.copyright),
        title: Text(L10n.of(context).licenses),
        subtitle: Text(L10n.of(context).all_the_great_software_used_by_fritter),
        onTap: () => showLicensePage(
            context: context,
            applicationName: L10n.of(context).fritter,
            applicationVersion: appVersion,
            applicationLegalese: L10n.of(context).released_under_the_mit_license,
            applicationIcon: Container(
              margin: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(48.0),
                child: Image.asset(
                  'assets/icon.png',
                  height: 48.0,
                  width: 48.0,
                ),
              ),
            )),
      ),
    ]);
  }
}
