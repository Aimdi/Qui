import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:qui/search/search_model.dart';
import 'package:qui/search/search_history.dart';
import 'package:qui/user.dart';
import 'package:qui/utils/local_json_store.dart';

class _Storage implements JsonStore {
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
  testWidgets('old people search cannot overwrite a newer search', (tester) async {
    final old = Completer<List<UserWithExtra>>();
    final model = SearchUsersModel(
      search: (query) => query == 'old' ? old.future : Future.value([UserWithExtra.fromArguments(idStr: query)]),
    );
    addTearDown(model.destroy);
    final pending = model.searchUsers('old');
    await model.searchUsers('new');
    old.complete([UserWithExtra.fromArguments(idStr: 'old')]);
    await pending;
    await tester.pump();
    expect(model.state.single.idStr, 'new');
    expect(model.isLoading, isFalse);
  });

  testWidgets('stalled people search times out, retries, and clears safely', (tester) async {
    var stalled = true;
    final model = SearchUsersModel(
      requestTimeout: const Duration(seconds: 1),
      search: (_) => stalled ? Completer<List<UserWithExtra>>().future : Future.value([]),
    );
    addTearDown(model.destroy);
    final pending = model.searchUsers('test');
    await tester.pump(const Duration(seconds: 2));
    await pending;
    expect(model.error, isA<TimeoutException>());
    expect(model.isLoading, isFalse);
    stalled = false;
    await model.searchUsers('test');
    expect(model.error, isNull);
    model.clear();
    expect(model.state, isEmpty);
  });

  test('search history deduplicates, caps entries, persists and clears', () async {
    final storage = _Storage()..value = ['old'];
    final history = SearchHistory(storage: storage);
    await history.remember('  OLD  ');
    expect(history.state, ['OLD']);
    for (var i = 0; i < 25; i++) {
      await history.remember('query $i');
    }
    expect(history.state, hasLength(20));
    expect(history.state.first, 'query 24');
    final reopened = SearchHistory(storage: storage);
    await reopened.load();
    expect(reopened.state, history.state);
    await reopened.remove('query 24');
    expect(reopened.state.first, 'query 23');
    await reopened.clear();
    expect(storage.value, isEmpty);
    await history.destroy();
    await reopened.destroy();
  });
}
