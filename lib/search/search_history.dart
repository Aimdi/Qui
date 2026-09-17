import 'package:flutter_triple/flutter_triple.dart';
import 'package:qui/utils/local_json_store.dart';

/// Only explicitly submitted searches are remembered, on this device.
class SearchHistory extends Store<List<String>> {
  final JsonStore storage;
  static const _key = 'search:recent';
  Future<void>? _loading;
  bool _closed = false;

  SearchHistory({JsonStore? storage}) : storage = storage ?? LocalJsonStore.shared, super([]);

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final data = await storage.read(_key).timeout(const Duration(seconds: 1));
      if (!_closed && data is List) update(data.whereType<String>().take(20).toList());
    } catch (_) {
      /* History is optional; search still works. */
    }
  }

  Future<void> remember(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    await load();
    if (_closed) return;
    update([trimmed, ...state.where((q) => q.toLowerCase() != trimmed.toLowerCase())].take(20).toList());
    await _save();
  }

  Future<void> remove(String query) async {
    await load();
    if (_closed) return;
    update(state.where((q) => q != query).toList());
    await _save();
  }

  Future<void> clear() async {
    await load();
    if (_closed) return;
    update([]);
    await _save();
  }

  Future<void> _save() async {
    try {
      await storage.write(_key, state);
    } catch (_) {
      /* Optional persistence. */
    }
  }

  @override
  Future<void> destroy() {
    _closed = true;
    return super.destroy();
  }
}
