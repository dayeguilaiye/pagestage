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
  String get chapterQueued => 'Queued';

  @override
  String get chapterWorking => 'Generating';

  @override
  String get chapterPaused => 'Paused';

  @override
  String chapterDirecting(String elapsed) {
    return 'Directing $elapsed';
  }

  @override
  String chapterVoicing(int voiced, int total) {
    return 'Voicing $voiced/$total';
  }

  @override
  String chapterPausedBecause(String reason) {
    return 'Paused: $reason';
  }

  @override
  String get prepareChapters => 'Generate ahead';

  @override
  String get prepareFrom => 'From';

  @override
  String get prepareThrough => 'Through';

  @override
  String get prepareNote =>
      'Direct and voice these chapters now, so they play straight away when you listen. Their text goes to your language model and voice provider; chapters already done are skipped.';

  @override
  String prepareRange(int first, int through) {
    return 'Generate chapters $first–$through';
  }

  @override
  String prepareOne(int chapter) {
    return 'Generate chapter $chapter';
  }

  @override
  String get prepareNeedsProfile =>
      'Only profiled chapters can be generated. Profile them in the cast first.';

  @override
  String get prepareFailed => 'Couldn’t start generating. Try again later.';

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
      'Import a TXT or DRM-free EPUB novel from your phone to read and listen to it here.';

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
    return '“$file” isn’t a supported format';
  }

  @override
  String get importUnsupportedBody =>
      'You can import TXT files and DRM-free EPUB files. Your bookshelf hasn’t changed.';

  @override
  String importDrmTitle(String file) {
    return '“$file” is DRM-protected';
  }

  @override
  String get importDrmBody =>
      'The text of a DRM-protected EPUB can’t be read. Import a DRM-free EPUB or a TXT file instead. Your bookshelf hasn’t changed.';

  @override
  String bookUpdated(String title, int added, int changed) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added chapters added',
      one: '1 chapter added',
    );
    String _temp1 = intl.Intl.pluralLogic(
      changed,
      locale: localeName,
      other: '$changed chapters changed',
      one: '1 chapter changed',
    );
    return 'Updated “$title”: $_temp0, $_temp1';
  }

  @override
  String bookUnchanged(String title) {
    return '“$title” is already up to date';
  }

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
      'The file may be damaged; TXT files need to be UTF-8 or GBK. Your bookshelf hasn’t changed.';

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
  String resumeProfilingTo(int chapter) {
    return 'Resume profiling to chapter $chapter';
  }

  @override
  String profilingSkipped(String chapters) {
    return 'Chapters skipped ($chapters): the provider couldn’t process them';
  }

  @override
  String get chapterListSeparator => ', ';

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
  String get reasonInvalidResponse =>
      'The model’s reply wasn’t in the expected format. Try again later or switch models';

  @override
  String get reasonRequestRejected =>
      'The provider refused the request. Check the endpoint and model name';

  @override
  String get reasonSchemaUnsupported =>
      'This endpoint doesn’t support structured output (JSON Schema). Pick a model or provider that does';

  @override
  String get reasonContentRejected =>
      'The provider refused to process this chapter';

  @override
  String get reasonTruncated =>
      'The reply for this chapter exceeded the model’s output limit';

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
  String get edgeSectionNote =>
      'Online voices, ready without an API key. Choose an Edge voice in the cast. Used for automatic casting when no paid voice provider is configured. Supports plain-text reading; emotion and pronunciation instructions are not applied.';

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

  @override
  String generationTitle(String chapter) {
    return '$chapter has no voices yet';
  }

  @override
  String get generationBody =>
      'Generate AI voices now and keep listening while they’re made, or have your phone’s own voice read it for now.';

  @override
  String generationOutOfRange(String chapter) {
    return '$chapter hasn’t been profiled, so its voices can’t be generated yet. Extend profiling to this chapter first, or have your phone’s own voice read it for now.';
  }

  @override
  String get generateNow => 'Generate voices';

  @override
  String get useSystemVoice => 'Use the system voice';

  @override
  String extendProfilingTo(String chapter) {
    return 'Extend profiling to $chapter';
  }

  @override
  String get waitingForSynthesis =>
      'Generating the next voices — playback continues when they’re ready';

  @override
  String get generationPausedTitle => 'Voice generation paused';

  @override
  String get generationResumeFailed =>
      'Couldn’t resume generating. Try again later';

  @override
  String generationPausedLine(String chapter, String provider, String reason) {
    return '$chapter · $provider: $reason';
  }

  @override
  String get resumeGeneration => 'Resume generating';

  @override
  String get reasonVoiceUnavailable =>
      'The assigned voice is no longer available. Choose another in the cast';

  @override
  String get errorAudioChanged =>
      'The audio has changed (cleared or a new voice). Tap play to prepare it again.';

  @override
  String get errorGenerationCancelled =>
      'Generating was cancelled. Tap play to choose again.';

  @override
  String get performanceMode => 'Performance';

  @override
  String get modeAudiobook => 'Audiobook';

  @override
  String get modeDrama => 'Drama';

  @override
  String get modeAudiobookNote =>
      'The narrator reads everything, including tags like “he said”.';

  @override
  String get modeDramaNote =>
      'Characters speak for themselves; tags like “he said” are skipped.';

  @override
  String get modeSaveFailed => 'Couldn’t save the performance style. Try again';

  @override
  String get generationSection => 'Generate while listening';

  @override
  String get generationSectionNote =>
      'How many chapters ahead of you are prepared. Synthesis can’t run further ahead than directing; 0 turns it off.';

  @override
  String get autoGenerate => 'Generate voices automatically';

  @override
  String get autoGenerateNote =>
      'Chapters without voices are generated without asking';

  @override
  String get directingAhead => 'Direct ahead';

  @override
  String get synthesisAhead => 'Synthesize ahead';

  @override
  String get aheadOff => 'Off';

  @override
  String aheadChapters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters ahead',
      one: '1 chapter ahead',
    );
    return '$_temp0';
  }

  @override
  String get fewerDirectingAhead => 'Direct fewer chapters ahead';

  @override
  String get moreDirectingAhead => 'Direct more chapters ahead';

  @override
  String get fewerSynthesisAhead => 'Synthesize fewer chapters ahead';

  @override
  String get moreSynthesisAhead => 'Synthesize more chapters ahead';

  @override
  String get generationSettingsFailed => 'Couldn’t save generation settings';

  @override
  String get storageSection => 'Storage';

  @override
  String get storage => 'Storage';

  @override
  String get storageRowNote => 'See the space each book uses and clear audio';

  @override
  String get storageNote =>
      'Counted per book: its text, scripts, cast and other records plus its audio files. The database file is shared by all books; its index and log overhead isn’t included.';

  @override
  String get storageLoadFailed => 'Couldn’t read storage use';

  @override
  String get storageEmpty => 'No books are using space yet';

  @override
  String get storageTotal => 'Total';

  @override
  String get storageAudio => 'Clearable audio';

  @override
  String get storageBooks => 'Books';

  @override
  String storageBookLine(String total, String audio) {
    return '$total in all · $audio audio';
  }

  @override
  String get clearAudio => 'Clear audio';

  @override
  String get clearAudioNote =>
      'Clearing removes only generated audio, samples and the synthesis cache. Text, scripts and cast stay; audio is made again when you next listen.';

  @override
  String clearAudioTitle(String title) {
    return 'Clear the audio for “$title”?';
  }

  @override
  String clearAudioBody(String size) {
    return 'This frees $size. The text, scripts and cast stay; audio is synthesized again when you next listen.';
  }

  @override
  String get clearAudioConfirm => 'Clear audio';

  @override
  String get clearAudioFailed => 'Couldn’t clear the audio. Try again';

  @override
  String audioCleared(String title) {
    return 'Cleared the audio for “$title”';
  }

  @override
  String get changeVoice => 'Change voice';

  @override
  String get designVoice => 'Design a voice';

  @override
  String changeVoiceTitle(String name) {
    return 'A new voice for $name';
  }

  @override
  String currentVoice(String voice) {
    return 'Currently “$voice”';
  }

  @override
  String get presetVoices => 'Presets';

  @override
  String get voiceDesign => 'Design';

  @override
  String get hearBeforeChoosing => 'Play a voice before choosing it.';

  @override
  String get chooseVoice => 'Use';

  @override
  String get voiceInUse => 'In use';

  @override
  String get chooseVoiceFailed => 'Couldn’t switch to this voice. Try again';

  @override
  String get presetsLoadFailed => 'Couldn’t load preset voices';

  @override
  String get presetsEmpty =>
      'No preset voices suit this book’s language with your current setup.';

  @override
  String get designProvider => 'Design with';

  @override
  String get voiceDescriptionLabel => 'Voice description';

  @override
  String get voiceDescriptionHint =>
      'For example: a man around fifty, low and husky, unhurried';

  @override
  String get designCandidates => 'Design 3 candidates';

  @override
  String get designCandidatesAgain => 'Design new candidates';

  @override
  String get designing => 'Designing voices — this takes a moment';

  @override
  String get designFailed => 'Couldn’t design a voice';

  @override
  String get designFailedBody =>
      'Your description and provider are kept. Try again, or adjust the description.';

  @override
  String get candidates => 'Candidates';

  @override
  String voiceChanged(String name) {
    return '$name has a new voice';
  }

  @override
  String voiceRebuiltTitle(String name) {
    return '$name’s voice was rebuilt';
  }

  @override
  String voiceRebuiltBody(String provider) {
    return 'The $provider voice binding was rebuilt and may sound different. Play it again to check.';
  }

  @override
  String get listenAgain => 'Play again';

  @override
  String get diagnosticsSection => 'Diagnostics and feedback';

  @override
  String get exportDiagnostics => 'Export a diagnostic report';

  @override
  String get exportDiagnosticsNote =>
      'Creates a report and opens the share sheet so you choose where it goes';

  @override
  String get exportingDiagnostics => 'Preparing the report…';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get reportProblemNote =>
      'Opens a new issue on the project’s GitHub in your browser';

  @override
  String get openingBrowser => 'Opening the browser…';

  @override
  String get exportDiagnosticsFailed => 'Couldn’t export the report';

  @override
  String get exportDiagnosticsFailedBody =>
      'The report wasn’t created or the share sheet didn’t open. Try again.';

  @override
  String get reportProblemFailed => 'Couldn’t open the feedback page';

  @override
  String get reportProblemFailedBody =>
      'The browser didn’t open. Check your connection or default browser and try again.';

  @override
  String get diagnosticsPrivacyTitle => 'What the report contains';

  @override
  String get diagnosticsIncludes =>
      'Included: app version, system and device details, recent errors and crashes.';

  @override
  String get diagnosticsExcludes =>
      'Never included: your keys or the text of your books.';

  @override
  String get diagnosticsNoUpload =>
      'Nothing is uploaded automatically: the report leaves your phone only if you send it from the share sheet.';
}
