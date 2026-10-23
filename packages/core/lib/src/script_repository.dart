import 'local_store.dart';
import 'models/script.dart';

class ScriptRepository {
  ScriptRepository(this.store);
  final LocalStore store;
  Future<Script?> get(String bookId, int chapterNumber) async {
    final json = await store.get('scripts', '$bookId:$chapterNumber');
    return json == null ? null : Script.fromJson(json);
  }

  Future<void> save(Script script) => store.put(
    'scripts',
    '${script.bookId}:${script.chapterNumber}',
    script.toJson(),
  );
}
