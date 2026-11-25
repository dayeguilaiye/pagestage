import 'dart:async';

import 'package:flutter/material.dart';

import '../application/incoming_files.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'bookshelf.dart';
import 'import_feedback.dart';

/// Imports each file another app opens in pagestage as if the reader had
/// picked it with the import button, and says how it went in the same
/// words. Files go one at a time: each waits for the one before it, and
/// for any question or failure that one brought up.
class IncomingImport extends StatefulWidget {
  const IncomingImport({
    super.key,
    required this.bookshelf,
    required this.child,
    this.enabled = true,
    this.files,
  });

  final Bookshelf bookshelf;
  final Widget child;

  /// When off, as in the gallery and reading-only runs, files stay with the
  /// platform. Read once, when first built.
  final bool enabled;

  /// The platform's when null.
  final IncomingFiles? files;

  @override
  State<IncomingImport> createState() => _IncomingImportState();
}

class _IncomingImportState extends State<IncomingImport> {
  late final _files = widget.files ?? IncomingFiles();
  StreamSubscription<String>? _arrivals;
  var _imports = Future<void>.value();

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _arrivals = _files.paths.listen(
        (path) => _imports = _imports.then((_) => _import(path)),
      );
    }
  }

  @override
  void dispose() {
    _arrivals?.cancel();
    super.dispose();
  }

  /// Never throws, so the files after it still come in.
  Future<void> _import(String path) async {
    ImportOutcome outcome;
    try {
      outcome = await widget.bookshelf.importPath(
        path,
        confirmReplace: _confirmReplace,
      );
    } catch (_) {
      outcome = ImportFailed(
        path.substring(path.lastIndexOf('/') + 1),
        ImportFailure.unreadable,
      );
    }
    try {
      _files.discard(path);
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      if (importedMessage(l, outcome) case final message?) {
        showPsToast(context, message);
      } else if (outcome case final ImportFailed failure) {
        await _fail(failure, l);
      }
    } catch (_) {
      // Saying how it went must not stop the next file.
    }
  }

  Future<bool> _confirmReplace(String title) async =>
      mounted && await confirmReplaceBook(context, title);

  /// The shelf's failure banner, as a dialog: the reader may be on any page
  /// when a file arrives.
  Future<void> _fail(ImportFailed failure, AppLocalizations l) {
    final (title, body) = importFailureText(l, failure);
    return showDialog<void>(
      context: context,
      builder: (context) => PsDialog(
        title: title,
        body: Text(body),
        actions: [
          PsButton(
            label: l.importFailedDismiss,
            expand: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
