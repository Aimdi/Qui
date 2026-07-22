import 'package:flutter_triple/flutter_triple.dart';
import 'package:qui/database/repository.dart';
import 'package:qui/substack/substack_client.dart';
import 'package:sqflite/sqflite.dart';

/// The list of followed Substack publications, backed by the database.
class SubstackModel extends Store<List<SubstackPublication>> {
  SubstackModel() : super([]);

  Future<void> reload() async {
    await execute(() async {
      final database = await Repository.readOnly();

      final rows = await database.query(tableSubstackSubscription, orderBy: 'name COLLATE NOCASE ASC');

      return rows.map(SubstackPublication.fromMap).toList();
    });
  }

  /// Resolves [input] to a publication and follows it. Throws a
  /// [SubstackException] when the address does not point at a Substack.
  Future<SubstackPublication> subscribe(String input) async {
    final publication = await resolveSubstackPublication(input);

    final database = await Repository.writable();
    await database.insert(tableSubstackSubscription, publication.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

    await reload();

    return publication;
  }

  Future<void> unsubscribe(String host) async {
    final database = await Repository.writable();
    await database.delete(tableSubstackSubscription, where: 'host = ?', whereArgs: [host]);

    await reload();
  }
}
