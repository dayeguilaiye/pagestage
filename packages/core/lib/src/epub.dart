import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'models/book.dart';

class ProtectedEpub implements Exception {
  const ProtectedEpub();
}

/// Reads the container in memory without extracting paths or fetching resources.
/// TOC anchors partition the spine's text, so chapter/file boundaries are independent.
class EpubReader {
  EpubReader(List<int> bytes) {
    if (bytes.length > 128 * 1024 * 1024) _invalid();
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(bytes);
    if (archive.length > 10000) _invalid();
    var expanded = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = p.posix.normalize(file.name);
      if (name.startsWith('/') ||
          name == '..' ||
          name.startsWith('../') ||
          name.contains('\\') ||
          file.isSymbolicLink ||
          _files.containsKey(name)) {
        _invalid();
      }
      expanded += file.size;
      if (file.size > 32 * 1024 * 1024 || expanded > 256 * 1024 * 1024) {
        _invalid();
      }
      _files[name] = file;
    }
    if (decoder.directory.fileHeaders.any((h) => (h.file!.flags & 1) != 0)) {
      throw const ProtectedEpub();
    }
    if (_files.containsKey('META-INF/rights.xml')) throw const ProtectedEpub();
    if (_files.containsKey('META-INF/encryption.xml')) {
      for (final item
          in _xml('META-INF/encryption.xml').descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 'EncryptedData')) {
        final method = _elements(
          item,
          'EncryptionMethod',
        ).firstOrNull?.getAttribute('Algorithm');
        // Font obfuscation is compatible with text-only import.
        if (!{
          'http://www.idpf.org/2008/embedding',
          'http://ns.adobe.com/pdf/enc#RC',
        }.contains(method)) {
          throw const ProtectedEpub();
        }
      }
    }
  }

  final _files = <String, ArchiveFile>{};
  Never _invalid() => throw const FormatException('Invalid EPUB.');
  String _read(String name) {
    final file = _files[name];
    if (file == null) _invalid();
    return utf8.decode(file.content as List<int>);
  }

  XmlDocument _xml(String name) => XmlDocument.parse(_read(name));
  Iterable<XmlElement> _elements(XmlNode node, String local) => node.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == local);
  ({String path, String fragment}) _resolve(String base, String target) {
    final uri = Uri.parse(target);
    if (uri.hasScheme || uri.hasAuthority || uri.hasQuery) _invalid();
    final raw = Uri.decodeComponent(uri.path);
    final path = p.posix.normalize(
      raw.isEmpty ? base : p.posix.join(p.posix.dirname(base), raw),
    );
    if (path.startsWith('/') ||
        path == '..' ||
        path.startsWith('../') ||
        path.contains('\\')) {
      _invalid();
    }
    return (path: path, fragment: Uri.decodeComponent(uri.fragment));
  }

  ({String? title, List<Chapter> chapters}) read() {
    final root = _elements(
      _xml('META-INF/container.xml'),
      'rootfile',
    ).firstOrNull?.getAttribute('full-path');
    if (root == null) _invalid();
    final packagePath = _resolve('container.xml', root).path;
    final package = _xml(packagePath);
    final manifest = <String, XmlElement>{
      for (final e in _elements(package, 'item')) ?e.getAttribute('id'): e,
    };
    String itemPath(XmlElement item) =>
        _resolve(packagePath, item.getAttribute('href') ?? '').path;
    final navItem = manifest.values
        .where(
          (e) => (e.getAttribute('properties') ?? '')
              .split(RegExp(r'\s+'))
              .contains('nav'),
        )
        .firstOrNull;
    final spine = _elements(package, 'spine').firstOrNull;
    if (spine == null) _invalid();
    final documents = <String, _Body>{};
    final offsets = <String, int>{};
    final joined = StringBuffer();
    for (final ref in spine.childElements.where(
      (e) => e.name.local == 'itemref',
    )) {
      if (ref.getAttribute('linear') == 'no') continue;
      final item = manifest[ref.getAttribute('idref')];
      if (item == null) _invalid();
      if (item == navItem) continue;
      if (!{
        'application/xhtml+xml',
        'text/html',
      }.contains(item.getAttribute('media-type'))) {
        _invalid();
      }
      final path = itemPath(item);
      if (documents.containsKey(path)) continue;
      final body = _Body(html.parse(_read(path)).body);
      offsets[path] = joined.length;
      documents[path] = body;
      joined.write(body.text);
      if (!body.text.endsWith('\n')) joined.write('\n');
    }
    if (documents.isEmpty) _invalid();
    final toc = <({String title, String path, String fragment})>[];
    void add(String base, String href, String label) {
      final target = _resolve(base, href);
      toc.add((
        title: label.trim(),
        path: target.path,
        fragment: target.fragment,
      ));
    }

    if (navItem != null) {
      final path = itemPath(navItem);
      final nav = html
          .parse(_read(path))
          .querySelectorAll('nav')
          .where(
            (e) => (e.attributes['epub:type'] ?? e.attributes['type'] ?? '')
                .split(' ')
                .contains('toc'),
          )
          .firstOrNull;
      if (nav == null) _invalid();
      for (final link in nav.querySelectorAll('a[href]')) {
        add(path, link.attributes['href']!, link.text);
      }
    } else {
      final ncx =
          manifest[spine.getAttribute('toc')] ??
          manifest.values
              .where(
                (e) =>
                    e.getAttribute('media-type') == 'application/x-dtbncx+xml',
              )
              .firstOrNull;
      if (ncx != null) {
        final path = itemPath(ncx);
        for (final point in _elements(_xml(path), 'navPoint')) {
          final content = point.childElements
              .where((e) => e.name.local == 'content')
              .firstOrNull;
          final label = point.childElements
              .where((e) => e.name.local == 'navLabel')
              .firstOrNull;
          if (content?.getAttribute('src') case final href?) {
            add(path, href, label?.innerText ?? '');
          }
        }
      }
    }
    final chapters = <Chapter>[];
    void chapter(String title, String text) {
      text = text.trim();
      if (text.isEmpty) return;
      // A chapter heading belongs in its title, not in its spoken body.
      final newline = text.indexOf('\n');
      final first = newline < 0 ? text : text.substring(0, newline);
      if (first.trim() == title.trim() && newline >= 0) {
        text = text.substring(newline + 1).trim();
      }
      if (text.isEmpty) return;
      chapters.add(
        Chapter(
          number: chapters.length + 1,
          title: title.isEmpty ? 'Chapter ${chapters.length + 1}' : title,
          text: '$text\n',
        ),
      );
    }

    if (toc.isEmpty) {
      for (final body in documents.values) {
        chapter(body.title, body.text);
      }
    } else {
      final boundaries = <({int offset, String title})>[];
      for (final entry in toc) {
        final body = documents[entry.path];
        if (body == null) _invalid();
        final local = entry.fragment.isEmpty ? 0 : body.anchors[entry.fragment];
        if (local == null) _invalid();
        final offset = offsets[entry.path]! + local;
        if (boundaries.isNotEmpty && offset < boundaries.last.offset) {
          _invalid();
        }
        if (boundaries.isNotEmpty && offset == boundaries.last.offset) {
          // A nested TOC may repeat the parent start. Prefer the specific label.
          boundaries.removeLast();
        }
        boundaries.add((offset: offset, title: entry.title));
      }
      final text = joined.toString();
      for (var i = 0; i < boundaries.length; i++) {
        chapter(
          boundaries[i].title,
          text.substring(
            boundaries[i].offset,
            i + 1 < boundaries.length ? boundaries[i + 1].offset : text.length,
          ),
        );
      }
    }
    if (chapters.isEmpty) throw const FormatException('The book is empty.');
    return (
      title: _elements(package, 'title').firstOrNull?.innerText.trim(),
      chapters: chapters,
    );
  }
}

class _Body {
  _Body(html.Element? body) {
    if (body == null) throw const FormatException('Invalid EPUB.');
    title = body.querySelector('h1,h2,h3')?.text.trim() ?? '';
    _walk(body);
    text = _out.toString();
  }
  final anchors = <String, int>{};
  final _out = StringBuffer();
  var _last = '';
  late final String text;
  late final String title;
  void _newline() {
    if (_last != '\n' && _out.isNotEmpty) {
      _out.write('\n');
      _last = '\n';
    }
  }

  void _walk(html.Node node) {
    if (node is html.Text) {
      var value = node.data.replaceAll(RegExp(r'\s+'), ' ');
      if (_last.isEmpty || _last == '\n' || _last == ' ') {
        value = value.replaceFirst(RegExp(r'^ +'), '');
      }
      if (value.isNotEmpty) {
        _out.write(value);
        _last = value[value.length - 1];
      }
    } else if (node is html.Element) {
      if ({
            'script',
            'style',
            'nav',
            'head',
            'noscript',
          }.contains(node.localName) ||
          node.attributes.containsKey('hidden')) {
        return;
      }
      final block = {
        'p',
        'div',
        'section',
        'article',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'li',
        'blockquote',
        'br',
        'tr',
        'pre',
        'hr',
      }.contains(node.localName);
      if (block) _newline();
      final id = node.id.isEmpty ? node.attributes['name'] : node.id;
      if (id != null && id.isNotEmpty) anchors[id] = _out.length;
      for (final child in node.nodes) {
        _walk(child);
      }
      if (block) _newline();
    }
  }
}
