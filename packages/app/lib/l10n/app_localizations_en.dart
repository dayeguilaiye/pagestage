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

  @override
  String get systemVoice => 'System voice';

  @override
  String get systemVoiceNote =>
      'This chapter has no generated voices yet, so your phone’s own voice is reading it.';

  @override
  String chapterNumber(int number) {
    return 'Chapter $number';
  }

  @override
  String chapterOfCount(String title, int number, int count) {
    return '$title · $number of $count';
  }

  @override
  String lineOfCount(int number, int count) {
    return 'Sentence $number of $count';
  }

  @override
  String get nowListening => 'NOW LISTENING';

  @override
  String get closePlayer => 'Close player';

  @override
  String get openPlayer => 'Open player';

  @override
  String get nothingPlayingTitle => 'Nothing is playing';

  @override
  String get nothingPlayingBody =>
      'Choose a book on your bookshelf and tap Listen.';

  @override
  String get backToShelf => 'Back to bookshelf';

  @override
  String get chapterProgress => 'Chapter progress';

  @override
  String get previousChapter => 'Previous chapter';

  @override
  String get nextChapter => 'Next chapter';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get speedShort => 'Speed';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get sleepTimerShort => 'Sleep';

  @override
  String get sleepEndOfChapterShort => 'End of chapter';

  @override
  String get sleepOff => 'Off';

  @override
  String sleepMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'In $minutes minutes',
      one: 'In 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get sleepEndOfChapter => 'At the end of this chapter';

  @override
  String sleepStopsIn(String time) {
    return 'Stops in $time';
  }

  @override
  String get sleepStopsAtChapterEnd => 'Stops at the end of this chapter';

  @override
  String get readAlong => 'Read along';

  @override
  String get listenToChapter => 'Listen to this chapter';

  @override
  String get backToSpokenLine => 'Back to the spoken line';

  @override
  String get startListening => 'Listen';

  @override
  String resumeListening(int chapter) {
    return 'Resume · Chapter $chapter';
  }

  @override
  String listenedTo(int chapter) {
    return 'Up to chapter $chapter';
  }

  @override
  String get errorNoSystemVoice =>
      'There’s no reading voice on this phone. Download a Chinese or English voice in system settings.';

  @override
  String get endOfBook => 'You’ve reached the end of the book';

  @override
  String get errorChapterUnavailable =>
      'Couldn’t open this chapter. Try the next one.';

  @override
  String get errorAudioFailed =>
      'This passage can’t be played. Try the next sentence.';

  @override
  String get errorBookMissing => 'This book is no longer on your bookshelf.';

  @override
  String get errorPlaybackStopped => 'Playback stopped. Tap play to try again.';

  @override
  String get providerUnknown => 'The provider';

  @override
  String get providerLlm => 'Language model';

  @override
  String get providerBailian => 'Alibaba Cloud Bailian';

  @override
  String get cast => 'Cast';

  @override
  String get castLoadFailed => 'Couldn’t load the cast';

  @override
  String castMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count speakers',
      one: '1 speaker',
    );
    return '$_temp0';
  }

  @override
  String get castEmpty =>
      'No cast yet. Once the book is profiled, its speakers and their voices appear here.';

  @override
  String get castEmptyWorking =>
      'Profiling. Speakers appear here as they are found.';

  @override
  String get castProvisional => 'Provisional';

  @override
  String get voiceNotAssigned => 'No voice yet';

  @override
  String get auditionFailed => 'Couldn’t play the sample';

  @override
  String get profileGender => 'Gender';

  @override
  String get profileAge => 'Age';

  @override
  String get profilePersonality => 'Personality';

  @override
  String get profileSpeakingStyle => 'Way of speaking';

  @override
  String get profileVoice => 'Voice';

  @override
  String get profileEmpty => 'No profile details yet.';

  @override
  String get profiling => 'Profiling';

  @override
  String get chaptersProfiled => 'chapters profiled';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusRunning => 'Profiling';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusComplete => 'Done';

  @override
  String profilingQueuedTo(int chapter) {
    return 'Queued to profile through chapter $chapter';
  }

  @override
  String profilingRunningTo(int chapter) {
    return 'Profiling through chapter $chapter';
  }

  @override
  String get profilingPausedTitle => 'Profiling paused';

  @override
  String profilingPausedBody(String provider, String reason) {
    return '$provider: $reason';
  }

  @override
  String get resumeProfiling => 'Resume profiling';

  @override
  String get profilingActionFailed =>
      'Couldn’t start profiling. Try again later.';

  @override
  String get profiledWholeBook => 'The whole book is profiled.';

  @override
  String get profileThrough => 'Profile through';

  @override
  String get startProfiling => 'Start profiling';

  @override
  String get extendProfiling => 'Profile further';

  @override
  String get profilingNote =>
      'Profiling sends the chosen chapters’ text to your language model to find the speakers and choose their voices. You’ll be asked before anything is sent.';

  @override
  String get reasonMissingKey => 'No key yet. Add one in Settings';

  @override
  String get reasonUnauthorized =>
      'The key is invalid or lacks permission. Check it in Settings';

  @override
  String get reasonRateLimited => 'Too many requests. Resume in a little while';

  @override
  String get reasonQuotaExceeded => 'The account has run out of credit';

  @override
  String get reasonNetwork => 'The connection dropped';

  @override
  String get reasonConsentDeclined => 'You cancelled sending';

  @override
  String get reasonInvalidResponse => 'The provider’s reply couldn’t be used';

  @override
  String get reasonInterrupted => 'Interrupted when the app closed';

  @override
  String get reasonUnknown => 'The service is unavailable for now';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSubtitle => 'Use your own provider accounts';

  @override
  String get llmSection => 'Language model';

  @override
  String get llmSectionNote =>
      'Profiles and directs: finds the speakers and gives each line a voice and a delivery.';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get baseUrlInvalid =>
      'Enter an address starting with https:// or http://';

  @override
  String get protocol => 'API';

  @override
  String get protocolChatCompletions => 'Chat Completions';

  @override
  String get protocolResponses => 'Responses';

  @override
  String get profileModel => 'Profiling model';

  @override
  String get profileModelHelp => 'Analyses characters and chooses voices.';

  @override
  String get directorModel => 'Directing model';

  @override
  String get directorModelHelp =>
      'Directs line by line. Leave blank to use the profiling model.';

  @override
  String get sameAsProfileModel => 'Same as profiling model';

  @override
  String get llmKey => 'Language model key';

  @override
  String get minimaxSectionNote => 'Generates the characters’ voices.';

  @override
  String get minimaxKey => 'MiniMax key';

  @override
  String get bailianSection => 'Alibaba Cloud Bailian';

  @override
  String get bailianSectionNote =>
      'Generates the characters’ voices from the region you choose.';

  @override
  String get bailianKey => 'Bailian key';

  @override
  String get region => 'Region';

  @override
  String get regionBeijing => 'Beijing';

  @override
  String get regionSingapore => 'Singapore';

  @override
  String get keyStored => 'Saved';

  @override
  String get keyNotSet => 'Not set';

  @override
  String get keyWillBeRemoved => 'Will be removed';

  @override
  String get keyHint => 'Paste a key';

  @override
  String get keyStoredHint => 'Leave blank to keep, or enter a new key';

  @override
  String get keyRemovedHint => 'This key is removed when you save';

  @override
  String get showKey => 'Show';

  @override
  String get hideKey => 'Hide';

  @override
  String get removeKey => 'Remove key';

  @override
  String get undoRemoveKey => 'Keep key';

  @override
  String get saveSettings => 'Save';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsSaveFailed => 'Couldn’t save settings';

  @override
  String get settingsSaveFailedBody =>
      'Nothing has changed. Check what you entered and save again.';

  @override
  String get castSection => 'Cast';

  @override
  String get exclusiveVoices => 'Exclusive voices';

  @override
  String get exclusiveVoicesNote =>
      'The characters with the most lines each get a voice of their own; everyone else shares the extras’ voices.';

  @override
  String get exclusiveVoicesFailed =>
      'Couldn’t change the number of exclusive voices';

  @override
  String get fewerVoices => 'Fewer';

  @override
  String get moreVoices => 'More';

  @override
  String consentTitle(String title) {
    return 'Send text from “$title”?';
  }

  @override
  String get consentChapterTextAndCast =>
      'Directing needs the chosen chapters’ text and the book’s cast to assign lines and voices.';

  @override
  String get consentVoiceSample =>
      'Making a sample needs a short sample text and the character’s voice description.';

  @override
  String get consentBookContent =>
      'This step sends some of the book’s content to the provider.';

  @override
  String get consentProvider => 'Provider';

  @override
  String get consentEndpoint => 'Sent to';

  @override
  String get consentContentLabel => 'Content';

  @override
  String get consentChapterTextAndCastName => 'Chapter text and cast';

  @override
  String get consentVoiceSampleName => 'Voice sample text';

  @override
  String get consentBookContentName => 'Book content';

  @override
  String get consentCancelNote => 'If you cancel, nothing is sent.';

  @override
  String get consentAccept => 'Agree and send';
}
