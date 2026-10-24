// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get narrator => 'Narrator';

  @override
  String get narratorSeal => 'N';

  @override
  String get extra => 'Extra';

  @override
  String get audition => 'Play sample';

  @override
  String get stopAudition => 'Stop sample';

  @override
  String get auditioning => 'Playing sample';

  @override
  String get more => 'More';

  @override
  String get player => 'Player';

  @override
  String get aiVoice => 'AI voice';

  @override
  String get nextLine => 'Next line';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Try again';

  @override
  String get chapterUnprofiled => 'Not profiled';

  @override
  String get chapterUndirected => 'Not directed';

  @override
  String get chapterDirected => 'Directed';

  @override
  String get chapterSynthesized => 'Synthesized';

  @override
  String get chapterWorking => 'Generating';

  @override
  String get chapterFailed => 'Failed';

  @override
  String get shelfTitle => 'Bookshelf';

  @override
  String get importBook => 'Import';

  @override
  String get importing => 'Importing';

  @override
  String shelfAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All · $count books',
      one: 'All · 1 book',
    );
    return '$_temp0';
  }

  @override
  String get shelfEmptyTitle => 'Your bookshelf is empty';

  @override
  String get shelfEmptyBody =>
      'Import a TXT novel from your phone to read and listen to it here.';

  @override
  String get shelfEmptyAction => 'Import a book';

  @override
  String get shelfLoadFailed => 'Couldn’t load your bookshelf';

  @override
  String chapterCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$_temp0';
  }

  @override
  String bookImported(String title) {
    return 'Imported “$title”';
  }

  @override
  String importUnsupportedTitle(String file) {
    return '“$file” isn’t a TXT file';
  }

  @override
  String get importUnsupportedBody =>
      'Only TXT files can be imported for now. Your bookshelf hasn’t changed.';

  @override
  String importEmptyTitle(String file) {
    return '“$file” has no text';
  }

  @override
  String get importEmptyBody =>
      'Your bookshelf hasn’t changed. Try a TXT file that contains the book’s text.';

  @override
  String importUnreadableTitle(String file) {
    return 'Couldn’t read the text in “$file”';
  }

  @override
  String get importUnreadableBody =>
      'The file may be damaged, or not encoded as UTF-8 or GBK. Your bookshelf hasn’t changed.';

  @override
  String get importAnother => 'Choose another file';

  @override
  String get deleteBook => 'Delete';

  @override
  String deleteBookTitle(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get deleteBookBody =>
      'Its chapters, cast, scripts and audio will be deleted. You can’t undo this.';

  @override
  String get deleteBookConfirm => 'Delete book';

  @override
  String get contents => 'Contents';

  @override
  String get contentsLoadFailed => 'Couldn’t load the contents';

  @override
  String get chapterLoadFailed => 'Couldn’t open this chapter';

  @override
  String get readingSettings => 'Reading settings';

  @override
  String get textSize => 'Text size';

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get lineSpacingCompact => 'Compact';

  @override
  String get lineSpacingComfortable => 'Comfortable';

  @override
  String get lineSpacingLoose => 'Loose';

  @override
  String get nightMode => 'Night mode';

  @override
  String get nightModeSystem => 'System';

  @override
  String get nightModeOff => 'Off';

  @override
  String get nightModeOn => 'On';

  @override
  String get playFromHere => 'Play from here';

  @override
  String get previousLine => 'Previous line';

  @override
  String get playbackFixtureMissing =>
      'Prepare the local playback fixture before running this prototype.';
}
