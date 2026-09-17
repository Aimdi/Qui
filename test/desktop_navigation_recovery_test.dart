import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:qui/constants.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/home/home_screen.dart';
import 'package:qui/ui/deck.dart';
import 'package:qui/ui/desktop_shell.dart';

NavigationPage _page(String id) =>
    NavigationPage(id, (_) => id, const Icon(Icons.circle_outlined), const Icon(Icons.circle));

Widget _app(Widget child, BasePrefService prefs) => PrefService(
  service: prefs,
  child: MaterialApp(
    localizationsDelegates: const [
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L10n.delegate.supportedLocales,
    home: child,
  ),
);

void main() {
  testWidgets('reordering and removing rail tabs retains selection and controller identity', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final prefs = PrefServiceCache(
      cache: {optionDeckMode: false, optionDeckColumnRows: 1, optionShowNavigationLabels: true},
    );
    var ids = ['one', 'two', 'three'];
    final captured = <String, ScrollController>{};
    Widget shell() => _app(
      QuiShell(
        pages: ids.map(_page).toList(),
        prefs: prefs,
        initialPage: 1,
        builder: (controllers, nodes) => [
          for (var i = 0; i < ids.length; i++)
            Builder(
              builder: (_) {
                captured[ids[i]] = controllers[i]!;
                return Center(child: Text('body-${ids[i]}'));
              },
            ),
        ],
      ),
      prefs,
    );
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();
    final original = captured['two'];
    expect(find.text('body-two'), findsOneWidget);
    ids = ['three', 'one', 'two'];
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();
    expect(find.text('body-two'), findsOneWidget);
    expect(captured['two'], same(original));
    ids = ['one', 'two'];
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();
    expect(find.text('body-two'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('clicking a deck column changes keyboard target', (tester) async {
    var focused = 0;
    final prefs = PrefServiceCache(cache: {});
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: DeckBody(
              pages: [_page('first'), _page('second')],
              focusedIndex: focused,
              onFocusChanged: (index) => setState(() => focused = index),
              children: const [
                Center(child: Text('first body')),
                Center(child: Text('second body')),
              ],
            ),
          ),
        ),
        prefs,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('second body'));
    await tester.pumpAndSettle();
    expect(focused, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
