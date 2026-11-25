import 'package:flutter/material.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'bookshelf.dart';

// What the shelf says about an import, worded as the import button words
// it, for files other apps open in pagestage.

/// The toast for a book or package that came in; null when nothing did.
String? importedMessage(
  AppLocalizations l,
  ImportOutcome outcome,
) => switch (outcome) {
  BookImported(:final book) => l.bookImported(book.title),
  // Only what happened is said: no "0 chapters changed".
  BookUpdated(:final book, :final addedChapters, :final changedChapters) =>
    switch ((addedChapters, changedChapters.length)) {
      (0, 0) => l.bookUnchanged(book.title),
      (final added, 0) => l.bookUpdatedAdded(book.title, added),
      (0, final changed) => l.bookUpdatedChanged(book.title, changed),
      (final added, final changed) => l.bookUpdated(book.title, added, changed),
    },
  PackageImported(:final book, :final scriptChapters, :final audioChapters) =>
    audioChapters == 0
        ? l.packageImported(book.title, scriptChapters)
        : l.packageImportedAudio(book.title, scriptChapters, audioChapters),
  ImportCancelled() || ImportFailed() => null,
};

/// The title and explanation of a failed import.
(String, String) importFailureText(AppLocalizations l, ImportFailed failure) =>
    switch (failure.reason) {
      ImportFailure.unsupportedFormat => (
        l.importUnsupportedTitle(failure.fileName),
        l.importUnsupportedBody,
      ),
      ImportFailure.drmProtected => (
        l.importDrmTitle(failure.fileName),
        l.importDrmBody,
      ),
      ImportFailure.empty => (
        l.importEmptyTitle(failure.fileName),
        l.importEmptyBody,
      ),
      ImportFailure.unreadable => (
        l.importUnreadableTitle(failure.fileName),
        l.importUnreadableBody,
      ),
      ImportFailure.invalidPackage => (
        l.importPackageInvalidTitle(failure.fileName),
        l.importPackageInvalidBody,
      ),
    };

/// A package for a book already on the shelf takes its place only once the
/// reader agrees.
Future<bool> confirmReplaceBook(BuildContext context, String title) async {
  final l = AppLocalizations.of(context);
  final replace = await showDialog<bool>(
    context: context,
    builder: (context) => PsDialog(
      title: l.replaceBookTitle(title),
      body: Text(l.replaceBookBody),
      actions: [
        PsButton(
          label: l.replaceBookConfirm,
          variant: PsButtonVariant.primary,
          expand: true,
          onPressed: () => Navigator.pop(context, true),
        ),
        PsButton(
          label: l.cancel,
          variant: PsButtonVariant.ghost,
          expand: true,
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    ),
  );
  return replace ?? false;
}
