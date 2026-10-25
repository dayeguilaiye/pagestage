import 'dart:convert';
import 'package:archive/archive.dart';

/// Original tiny EPUB fixture, generated deterministically inside each test.
List<int> epubFixture({
  required Map<String, String> bodies,
  List<String>? toc,
  bool ncx = false,
  String? encryption,
  bool rights = false,
  Map<String, String> extra = const {},
}) {
  final nav = toc == null
      ? null
      : ncx
      ? 'toc.ncx'
      : 'nav.xhtml';
  final files = <String, String>{
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml':
        '<container><rootfiles><rootfile full-path="OEBPS/book.opf"/></rootfiles></container>',
    'OEBPS/book.opf':
        '''<package xmlns:dc="http://purl.org/dc/elements/1.1/"><metadata><dc:title>Fixture novel</dc:title></metadata><manifest>
      ${[for (final e in bodies.entries.indexed) '<item id="c${e.$1}" href="${e.$2.key}" media-type="application/xhtml+xml"/>'].join()}
      ${nav == null ? '' : '<item id="toc" href="$nav" media-type="${ncx ? 'application/x-dtbncx+xml' : 'application/xhtml+xml'}" ${ncx ? '' : 'properties="nav"'}/>'}
      </manifest><spine ${ncx ? 'toc="toc"' : ''}>${[for (var i = 0; i < bodies.length; i++) '<itemref idref="c$i"/>'].join()}</spine></package>''',
    for (final e in bodies.entries)
      'OEBPS/${e.key}':
          '<html><head><style>secret CSS</style></head><body>${e.value}</body></html>',
    if (nav != null)
      'OEBPS/$nav': ncx
          ? '<ncx><navMap>${[for (final e in toc!.indexed) '<navPoint><navLabel><text>Chapter ${e.$1 + 1}</text></navLabel><content src="${e.$2}"/></navPoint>'].join()}</navMap></ncx>'
          : '<html xmlns:epub="http://www.idpf.org/2007/ops"><body><nav epub:type="toc"><ol>${[for (final e in toc!.indexed) '<li><a href="${e.$2}">Chapter ${e.$1 + 1}</a></li>'].join()}</ol></nav></body></html>',
    if (encryption != null)
      'META-INF/encryption.xml':
          '<encryption><EncryptedData><EncryptionMethod Algorithm="$encryption"/></EncryptedData></encryption>',
    if (rights) 'META-INF/rights.xml': '<rights/>',
    ...extra,
  };
  final archive = Archive();
  for (final e in files.entries) {
    final bytes = utf8.encode(e.value);
    archive.addFile(ArchiveFile(e.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive)!;
}
