import 'package:flutter/material.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'bookshelf.dart';

/// Asks before deleting [book]; returns whether it was deleted.
Future<bool> deleteBook(
  BuildContext context,
  Bookshelf bookshelf,
  ShelfBook book,
) async {
  final l = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => PsDialog(
      title: l.deleteBookTitle(book.title),
      body: Text(l.deleteBookBody),
      actions: [
        PsButton(
          label: l.deleteBookConfirm,
          variant: PsButtonVariant.danger,
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
  if (confirmed != true) return false;
  await bookshelf.deleteBook(book.id);
  return true;
}
