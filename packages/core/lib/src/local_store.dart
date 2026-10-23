import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Atomic local snapshots shared by the CLI's modules.
///
/// Callers choose the SQLite location. Domain modules own their collection and
/// document schemas; no credentials should be persisted here.
class LocalStore {
  LocalStore(String path) : _database = _Database(_open(path));

  final _Database _database;
  bool _closed = false;

  static QueryExecutor _open(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    return NativeDatabase(file);
  }

  Future<void> put(String collection, String key, Map<String, Object?> value) =>
      _database.customStatement(
        'INSERT INTO documents (collection, key, value) VALUES (?, ?, ?) '
        'ON CONFLICT(collection, key) DO UPDATE SET value = excluded.value',
        [collection, key, jsonEncode(value)],
      );

  Future<Map<String, Object?>?> get(String collection, String key) async {
    final row = await _database
        .customSelect(
          'SELECT value FROM documents WHERE collection = ? AND key = ?',
          variables: [Variable(collection), Variable(key)],
        )
        .getSingleOrNull();
    return row == null ? null : _decode(row.read<String>('value'));
  }

  Future<List<Map<String, Object?>>> list(String collection) async {
    final rows = await _database
        .customSelect(
          'SELECT value FROM documents WHERE collection = ? ORDER BY key',
          variables: [Variable(collection)],
        )
        .get();
    return rows.map((row) => _decode(row.read<String>('value'))).toList();
  }

  Future<void> delete(String collection, String key) =>
      _database.customStatement(
        'DELETE FROM documents WHERE collection = ? AND key = ?',
        [collection, key],
      );

  Future<T> transaction<T>(Future<T> Function() action) =>
      _database.transaction(action);

  Future<void> close() async {
    if (!_closed) {
      _closed = true;
      await _database.close();
    }
  }

  static Map<String, Object?> _decode(String value) =>
      Map<String, Object?>.from(jsonDecode(value) as Map);
}

class _Database extends GeneratedDatabase {
  _Database(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => customStatement(
      'CREATE TABLE documents ('
      'collection TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, '
      'PRIMARY KEY(collection, key))',
    ),
  );
}
