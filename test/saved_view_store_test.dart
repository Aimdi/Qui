import 'package:flutter_test/flutter_test.dart';
import 'package:qui/saved/saved_view_store.dart';

void main() {
  group('Saved library view state', () {
    test('sorts newest order in reverse for oldest', () {
      expect(applySavedSort([3, 2, 1], SavedSort.newest), [3, 2, 1]);
      expect(applySavedSort([3, 2, 1], SavedSort.oldest), [1, 2, 3]);
    });

    test('selection can start, toggle, select visible and finish', () {
      final store = SavedViewStore();
      addTearDown(store.destroy);

      store.beginSelection('one');
      expect(store.state.selecting, isTrue);
      expect(store.state.selectedIds, {'one'});

      store.toggleSelected('two');
      expect(store.state.selectedIds, {'one', 'two'});

      store.toggleSelected('one');
      expect(store.state.selectedIds, {'two'});

      store.selectVisible(['a', 'b']);
      expect(store.state.selectedIds, {'a', 'b'});

      store.finishSelection();
      expect(store.state.selecting, isFalse);
      expect(store.state.selectedIds, isEmpty);
    });

    test('changing sort preserves the selection', () {
      final store = SavedViewStore();
      addTearDown(store.destroy);

      store.beginSelection('one');
      store.setSort(SavedSort.oldest);

      expect(store.state.sort, SavedSort.oldest);
      expect(store.state.selectedIds, {'one'});
    });
  });
}
