import 'dart:async';
import 'package:qui/utils/read_activity.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:qui/client/client.dart';
import 'package:qui/user.dart';
import 'package:qui/utils/local_json_store.dart';
import 'package:qui/utils/read_request_scope.dart';

class Profile {
  final UserWithExtra user;
  final List<String> pinnedTweets;
  final bool refreshing;
  final Object? refreshError;
  final DateTime? cachedAt;
  Profile(this.user, this.pinnedTweets, {this.refreshing = false, this.refreshError, this.cachedAt});
  Profile status({bool refreshing = false, Object? error, DateTime? cachedAt}) =>
      Profile(user, pinnedTweets, refreshing: refreshing, refreshError: error, cachedAt: cachedAt);
}

class ProfileModel extends Store<Profile> {
  final JsonStore storage;
  final Future<Profile> Function(String) byId;
  final Future<Profile> Function(String) byName;
  int _generation = 0;
  bool _closed = false;
  String? _key;
  final _reads = ReadRequestScope();
  ProfileModel({JsonStore? storage, Future<Profile> Function(String)? byId, Future<Profile> Function(String)? byName})
    : storage = storage ?? LocalJsonStore.shared,
      byId = byId ?? Twitter.getProfileById,
      byName = byName ?? Twitter.getProfileByScreenName,
      super(Profile(UserWithExtra(), []));

  @override
  dynamic get error => triple.error;

  Future<void> loadProfileById(String id) => _load('id:$id', () => byId(id));
  Future<void> loadProfileByScreenName(String name) =>
      _load('name:${name.replaceFirst('@', '').toLowerCase()}', () => byName(name.replaceFirst('@', '')));

  Future<void> _load(String key, Future<Profile> Function() fetch) async {
    if (_closed) return;
    final changed = _key != key;
    _key = key;
    final generation = ++_generation;
    _reads.cancel();
    bool current() => !_closed && generation == _generation;
    if (changed) update(Profile(UserWithExtra(), []), force: true);
    if (state.user.idStr == null) {
      setLoading(true);
    } else {
      update(state.status(refreshing: true, cachedAt: state.cachedAt), force: true);
    }
    try {
      // A pending sidecar write must not prevent the network deadline starting.
      final cached = await _reads
          .start(() => _read(key), timeout: const Duration(seconds: 1), operation: ReadOperation.cache)
          .catchError((Object _) => null);
      if (!current()) return;
      if (cached != null) {
        update(cached.status(refreshing: true, cachedAt: cached.cachedAt), force: true);
        setLoading(false);
      }
      final profile = await _reads.start(fetch, timeout: const Duration(seconds: 30), operation: ReadOperation.profile);
      if (!current()) return;
      update(profile, force: true);
      unawaited(_remember(profile));
    } catch (error) {
      if (!current()) return;
      if (state.user.idStr != null) {
        update(state.status(error: error, cachedAt: state.cachedAt), force: true);
      } else {
        setError(error, force: true);
      }
    } finally {
      if (current()) setLoading(false);
    }
  }

  Future<Profile?> _read(String key) async {
    try {
      final raw = await storage.read('profile:$key');
      if (raw is! Map || raw['user'] is! Map) return null;
      final at = DateTime.tryParse('${raw['at']}');
      if (at == null || DateTime.now().difference(at) > const Duration(days: 7)) return null;
      return Profile(
        UserWithExtra.fromJson(Map<String, dynamic>.from(raw['user'] as Map)),
        (raw['pinned'] as List? ?? []).whereType<String>().toList(),
        cachedAt: at,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _remember(Profile profile) async {
    try {
      final user = profile.user;
      final data = {
        'at': DateTime.now().toIso8601String(),
        'pinned': profile.pinnedTweets,
        'user': {...user.toJson(), 'possibly_sensitive': user.possiblySensitive},
      };
      if (user.idStr != null) await storage.write('profile:id:${user.idStr}', data);
      if (user.screenName != null) await storage.write('profile:name:${user.screenName!.toLowerCase()}', data);
      await pruneJsonCache(storage, 'profile:', 100);
    } catch (_) {
      /* Caching must not turn a successful request into a failure. */
    }
  }

  @override
  Future<void> destroy() {
    _closed = true;
    _generation++;
    _reads.cancel();
    return super.destroy();
  }
}
