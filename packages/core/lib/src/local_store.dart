import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Atomic local snapshots shared by the CLI's modules.
///
/// Callers choose the SQLite location. Domain modules own their collection and
/// document schemas; no credentials should be persisted here.
class LocalStore {
  LocalStore(this.path) : _database = _Database(_open(path));

  final String path;
  static final _transactionZone = Object();
  final _listeners = <void Function()>{};
  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notify() {
    if (Zone.current[_transactionZone] == this) return;
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  final _Database _database;
  bool _closed = false;

  static QueryExecutor _open(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    // Keeps SQLite work, including large book documents, off the UI isolate.
    return NativeDatabase.createInBackground(file);
  }

  Future<void> put(
    String collection,
    String key,
    Map<String, Object?> value,
  ) async {
    await _database.customStatement(
      'INSERT INTO documents (collection, key, value) VALUES (?, ?, ?) '
      'ON CONFLICT(collection, key) DO UPDATE SET value = excluded.value',
      [collection, key, jsonEncode(value)],
    );
    _notify();
  }

  Future<Map<String, Object?>?> get(String collection, String key) async {
    final row = await _database
        .customSelect(
          'SELECT value FROM documents WHERE collection = ? AND key = ?',
          variables: [Variable(collection), Variable(key)],
        )
        .getSingleOrNull();
    return row == null ? null : _decode(row.read<String>('value'));
  }

  /// Checks for a document without reading its payload.
  Future<bool> exists(String collection, String key) async =>
      await _database
          .customSelect(
            'SELECT 1 FROM documents WHERE collection = ? AND key = ?',
            variables: [Variable(collection), Variable(key)],
          )
          .getSingleOrNull() !=
      null;

  /// Length of the JSON array at [path], read inside SQLite so a large
  /// document is not decoded; null when the document or array is missing.
  Future<int?> arrayLength(String collection, String key, String path) async {
    final row = await _database
        .customSelect(
          'SELECT json_array_length(value, ?) AS length FROM documents '
          'WHERE collection = ? AND key = ?',
          variables: [Variable(path), Variable(collection), Variable(key)],
        )
        .getSingleOrNull();
    return row?.read<int?>('length');
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

  /// Exact UTF-8 payload bytes belonging to one book, excluding shared SQLite overhead.
  Future<int> bookDataBytes(String bookId) async {
    final row = await _database
        .customSelect(
          'SELECT COALESCE(SUM(length(CAST(value AS BLOB))), 0) AS bytes FROM documents WHERE '
          "json_extract(value, '\$.bookId') = ? OR "
          "json_extract(value, '\$.voice.bookId') = ? OR "
          "(collection IN ('books', 'casting') AND key = ?)",
          variables: [Variable(bookId), Variable(bookId), Variable(bookId)],
        )
        .getSingle();
    return row.read<int>('bytes');
  }

  Future<void> delete(String collection, String key) async {
    await _database.customStatement(
      'DELETE FROM documents WHERE collection = ? AND key = ?',
      [collection, key],
    );
    _notify();
  }

  /// Removes documents owned by a book, including tasks and voice candidates.
  Future<void> deleteBook(String bookId) async {
    await _database.customStatement(
      'DELETE FROM documents WHERE '
      "json_extract(value, '\$.bookId') = ? OR "
      "json_extract(value, '\$.voice.bookId') = ? OR "
      "(collection IN ('books', 'casting') AND key = ?)",
      [bookId, bookId, bookId],
    );
    _notify();
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    final result = await _database.transaction(
      () => runZoned(action, zoneValues: {_transactionZone: this}),
    );
    _notify();
    return result;
  }

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
