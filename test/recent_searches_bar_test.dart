import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/generated/l10n.dart';
import 'package:qui/search/recent_searches_bar.dart';
import 'package:qui/search/search_history.dart';
import 'package:qui/utils/local_json_store.dart';

class _MemoryStore implements JsonStore {
  Object? value;

  @override
  Future<Object?> read(String key) async => value;

  @override
  Future<void> write(String key, Object? value) async {
    this.value = value;
  }

  @override
  Future<void> remove(String key) async {
    value = null;
  }

  @override
  Future<Map<String, Object?>> readPrefix(String prefix) async => {};
}

void main() {
  testWidgets('recent search chips can be reopened and cleared', (tester) async {
    final storage = _MemoryStore()..value = ['linux', 'flutter'];
    final history = SearchHistory(storage: storage);
    addTearDown(history.destroy);
    await history.load();

    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: L10n.delegate.supportedLocales,
        home: Scaffold(
          body: RecentSearchesBar(store: history, onSelected: (query) => selected = query),
        ),
      ),
    );

    expect(find.text('linux'), findsOneWidget);
    expect(find.text('flutter'), findsOneWidget);

    await tester.tap(find.text('linux'));
    await tester.pump();
    expect(selected, 'linux');

    await tester.tap(find.byKey(const ValueKey('recent-searches-clear')));
    await tester.pumpAndSettle();

    expect(history.state, isEmpty);
    expect(find.text('linux'), findsNothing);
    expect(storage.value, isEmpty);
  });
}
