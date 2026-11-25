import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

/// Files other apps open in the app arrive as a path instead of a pick.
void main() {
  late Directory dir;
  late LocalStore store;
  late Library library;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('library-path-');
    store = LocalStore('${dir.path}/db.sqlite');
    library = Library(store);
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test('a given file comes in as a picked one does, and is not needed '
      'afterwards', () async {
    final source = await File(
      '${dir.path}/阿Q正传.txt',
    ).writeAsString('第一章\n我要给阿Q做正传。\n');
    final outcome = await library.importPath(source.path);
    final book = (outcome as BookImported).book;
    expect(book.title, '阿Q正传');

    await source.delete();
    expect(await library.paragraphs(book.id, 1), ['我要给阿Q做正传。']);
  });

  test('failures are told apart as for a picked file', () async {
    Future<ImportFailed> fail(String name) async =>
        await library.importPath('${dir.path}/$name') as ImportFailed;

    expect((await fail('红楼梦.pdf')).reason, ImportFailure.unsupportedFormat);
    final missing = await fail('不在了.txt');
    expect(missing.fileName, '不在了.txt');
    expect(missing.reason, ImportFailure.unreadable);
    await File('${dir.path}/坏掉的.pagestage').writeAsString('not a package');
    expect((await fail('坏掉的.pagestage')).reason, ImportFailure.invalidPackage);
    expect(await library.books(), isEmpty);
  });
}
