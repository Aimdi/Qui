import 'package:flutter/foundation.dart';
import 'package:flutter_triple/flutter_triple.dart';

enum SavedSort { newest, oldest }

List<T> applySavedSort<T>(Iterable<T> items, SavedSort sort) {
  final list = items.toList(growable: false);
  return sort == SavedSort.oldest ? list.reversed.toList(growable: false) : list;
}

@immutable
class SavedViewState {
  final SavedSort sort;
  final bool selecting;
  final Set<String> selectedIds;

  const SavedViewState({this.sort = SavedSort.newest, this.selecting = false, this.selectedIds = const <String>{}});

  SavedViewState copyWith({SavedSort? sort, bool? selecting, Set<String>? selectedIds}) {
    return SavedViewState(
      sort: sort ?? this.sort,
      selecting: selecting ?? this.selecting,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class SavedViewStore extends Store<SavedViewState> {
  SavedViewStore() : super(const SavedViewState());

  void setSort(SavedSort sort) => update(state.copyWith(sort: sort));

  void beginSelection([String? id]) {
    final selected = <String>{...state.selectedIds};
    if (id != null) selected.add(id);
    update(state.copyWith(selecting: true, selectedIds: Set.unmodifiable(selected)));
  }

  void toggleSelected(String id) {
    final selected = <String>{...state.selectedIds};
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    update(state.copyWith(selecting: true, selectedIds: Set.unmodifiable(selected)));
  }

  void selectVisible(Iterable<String> ids) {
    update(state.copyWith(selecting: true, selectedIds: Set.unmodifiable(ids.toSet())));
  }

  void finishSelection() {
    update(state.copyWith(selecting: false, selectedIds: const <String>{}));
  }
}
