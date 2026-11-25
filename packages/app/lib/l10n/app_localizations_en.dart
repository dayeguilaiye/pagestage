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
  String get aiVoice => 'AI voices';

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
    return 'Assigning lines $elapsed';
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
  String get prepareChapters => 'Prepare chapters';

  @override
  String get prepareFrom => 'From';

  @override
  String get prepareThrough => 'Through';

  @override
  String get prepareNote =>
      'Prepares these chapters now, so they play straight away, even offline. Their text goes to your language model and voice service; chapters already done are skipped.';

  @override
  String prepareRange(int first, int through) {
    return 'Prepare chapters $first–$through';
  }

  @override
  String prepareOne(int chapter) {
    return 'Prepare chapter $chapter';
  }

  @override
  String get prepareFailed => 'Couldn’t start preparing. Try again later.';

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
      'Import a TXT or DRM-free EPUB novel from your phone, or a script or audio package someone shared, to read and listen to it here.';

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
      'You can import TXT files, DRM-free EPUB files, and script or audio packages (.pagestage). Your bookshelf hasn’t changed.';

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
      'Its chapters, characters, lines and audio will be deleted. You can’t undo this.';

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
  String get systemVoiceNote => 'Your phone’s own voice reads this book.';

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
  String get cast => 'Characters & voices';

  @override
  String get castLoadFailed => 'Couldn’t load the characters';

  @override
  String castMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters',
      one: '1 character',
    );
    return '$_temp0';
  }

  @override
  String get castEmpty =>
      'No characters found yet. With AI voices on, they’re found as you listen and appear here.';

  @override
  String get castEmptyWorking =>
      'Finding the characters. They appear here as they’re found.';

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
  String get profiling => 'Finding characters';

  @override
  String get statusQueued => 'Queued';

  @override
  String get statusRunning => 'Working';

  @override
  String get statusPaused => 'Paused';

  @override
  String get statusComplete => 'Done';

  @override
  String profilingQueuedTo(int chapter) {
    return 'Queued to find characters through chapter $chapter';
  }

  @override
  String profilingRunningTo(int chapter) {
    return 'Finding characters through chapter $chapter';
  }

  @override
  String get profilingPausedTitle => 'Finding characters paused';

  @override
  String profilingPausedBody(String provider, String reason) {
    return '$provider: $reason';
  }

  @override
  String resumeProfilingTo(int chapter) {
    return 'Resume through chapter $chapter';
  }

  @override
  String profilingSkipped(String chapters) {
    return 'Chapters skipped ($chapters): the provider couldn’t process them';
  }

  @override
  String get chapterListSeparator => ', ';

  @override
  String get profilingActionFailed => 'Couldn’t start. Try again later.';

  @override
  String get profiledWholeBook => 'Every character in the book is found.';

  @override
  String get profileThrough => 'Find through';

  @override
  String get startProfiling => 'Start';

  @override
  String get extendProfiling => 'Find further';

  @override
  String get profilingNote =>
      'Sends the chosen chapters’ text to your language model to find the characters and choose their voices.';

  @override
  String get reasonMissingKey => 'No key yet';

  @override
  String get reasonUnauthorized => 'The key is invalid or lacks permission';

  @override
  String get reasonRateLimited => 'Too many requests';

  @override
  String get reasonQuotaExceeded =>
      'The account is out of credit. Top up, then resume';

  @override
  String get reasonNetwork => 'No connection';

  @override
  String get reasonConsentDeclined => 'You didn’t agree to send the text';

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
  String get reasonLocalSynthesisFailed =>
      'The on-device engine could not synthesize this passage';

  @override
  String get reasonUnknown => 'The service is unavailable for now';

  @override
  String consentTitle(String title) {
    return 'Send text from “$title”?';
  }

  @override
  String get consentChapterTextAndCast =>
      'To find the characters, assign lines and voice them, the text of the chapters you listen to and the book’s characters are sent to it.';

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
  String get consentChapterTextAndCastName => 'Chapter text and characters';

  @override
  String get consentVoiceSampleName => 'Voice sample text';

  @override
  String get consentBookContentName => 'Book content';

  @override
  String get consentCancelNote => 'If you cancel, nothing is sent.';

  @override
  String get consentAccept => 'Agree and send';

  @override
  String get useSystemVoice => 'Use the system voice';

  @override
  String get waitingForSynthesis =>
      'Preparing AI voices — playback starts when they’re ready';

  @override
  String get generationPausedTitle => 'AI voices paused';

  @override
  String get generationResumeFailed =>
      'Couldn’t resume generating. Try again later';

  @override
  String generationPausedLine(String chapter, String provider, String reason) {
    return '$chapter · $provider: $reason';
  }

  @override
  String get resumeGeneration => 'Resume';

  @override
  String get reasonVoiceUnavailable =>
      'The assigned voice is no longer available';

  @override
  String get errorAudioChanged =>
      'The audio has changed (cleared or a new voice). Tap play to prepare it again.';

  @override
  String get changeVoice => 'Change voice';

  @override
  String get designVoice => 'Design a voice';

  @override
  String changeVoiceTitle(String name) {
    return 'A new voice for “$name”';
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
      'No voice service that is on has voices for this book’s language.';

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
    return '“$name” has a new voice';
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
  String get settings => 'Settings';

  @override
  String get llm => 'Language model';

  @override
  String get voiceRole => 'Voices and voice design';

  @override
  String get voiceRoleNoDesign => 'Voices';

  @override
  String get providerReady => 'Set up';

  @override
  String get providerNotSet => 'Not set up';

  @override
  String get llmNoModel => 'No model';

  @override
  String get llmNoKey => 'No key';

  @override
  String get setupTitle => 'Set up a language model first';

  @override
  String get setupBody =>
      'Finding characters and assigning lines run on your own language model account.';

  @override
  String get setupAction => 'Set up the language model';

  @override
  String get generationSectionNote =>
      'Only while you listen; reading silently never triggers it.';

  @override
  String get autoGenerate => 'Use AI voices for new books';

  @override
  String get autoGenerateNote =>
      'Each book can also be switched in its own voice settings.';

  @override
  String get aheadUnit => 'ch';

  @override
  String get generationSettingsFailed =>
      'Couldn’t save generation settings. Try again';

  @override
  String get castingSection => 'Character voices';

  @override
  String get exclusiveVoices => 'Characters with their own voice';

  @override
  String exclusiveVoicesValue(int count) {
    return '$count';
  }

  @override
  String get exclusiveVoicesNote =>
      'The characters with the most lines each get their own voice; the rest share a few extras’ voices.';

  @override
  String get exclusiveVoicesRecastNote =>
      'Books already analysed get their voices reassigned. Voices you changed or designed stay.';

  @override
  String get fewerVoices => 'Fewer exclusive voices';

  @override
  String get moreVoices => 'More exclusive voices';

  @override
  String get recast => 'Reassign voices';

  @override
  String recastDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voices of their own',
      one: '1 voice of its own',
    );
    return 'Reassigned with $_temp0';
  }

  @override
  String get recastFailed => 'Couldn’t reassign voices. Try again';

  @override
  String get appearanceSection => 'Appearance';

  @override
  String get storageSection => 'Storage and usage';

  @override
  String get storage => 'Storage';

  @override
  String get storageTotal => 'In use';

  @override
  String storageAudioPart(String size) {
    return 'Audio $size';
  }

  @override
  String storageOtherPart(String size) {
    return 'Text, scripts and more $size';
  }

  @override
  String get storageBooks => 'By book';

  @override
  String storageBookLine(String total, String audio) {
    return '$total in all · $audio audio';
  }

  @override
  String storageBookNoAudio(String total) {
    return '$total in all · no audio';
  }

  @override
  String get storageLoadFailed => 'Couldn’t read storage use';

  @override
  String get storageEmpty => 'No books are using space yet';

  @override
  String get storageCountNote =>
      'Counted per book: its text, lines, characters and audio files. The database’s index and log are shared by all books and aren’t counted.';

  @override
  String get clearAudio => 'Clear audio';

  @override
  String get clearAudioNote =>
      'Clearing removes only generated audio, samples and the cache. Text, lines and characters stay; voices are made again when you next listen.';

  @override
  String clearAudioTitle(String title) {
    return 'Clear the audio for “$title”?';
  }

  @override
  String clearAudioBody(String size) {
    return 'This frees $size. The text, lines and characters stay; voices are made again when you next listen.';
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
  String get feedbackSection => 'Feedback';

  @override
  String get exportDiagnostics => 'Export a diagnostic report';

  @override
  String get exportDiagnosticsNote => 'Never includes keys or book text';

  @override
  String get exportingDiagnostics => 'Preparing the report…';

  @override
  String get reportProblem => 'Report a problem';

  @override
  String get reportProblemNote => 'Opens a new issue on GitHub';

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
  String get feedbackNote =>
      'The report holds the app version, device details and recent errors. Nothing is uploaded: it leaves your phone only if you send it from the share sheet.';

  @override
  String get aboutSection => 'About';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get llmPageNote =>
      'It finds the book’s characters and decides who reads each line, and how.';

  @override
  String get connectionSection => 'Connection';

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
  String get apiKey => 'Key';

  @override
  String get llmConnectionNote =>
      'Any OpenAI-compatible service works if its model supports structured output (JSON Schema).';

  @override
  String get modelsSection => 'Models';

  @override
  String get profileModel => 'Character model';

  @override
  String get directorModel => 'Lines model';

  @override
  String get modelHint => 'Model name';

  @override
  String get sameAsProfileModel => 'Same as the character model';

  @override
  String get modelsNote =>
      'The character model studies the characters and picks voices; the lines model assigns each line and its delivery. Leave it blank to use the character model.';

  @override
  String get minimaxPageNote =>
      'Voices your characters and designs new voices from a description.';

  @override
  String get minimaxKeyNote =>
      'Mainland keys come from minimaxi.com, international ones from minimax.io; each only works on its own platform.';

  @override
  String get bailianPageNote =>
      'Voices your characters. The Beijing region can also design new voices from a description.';

  @override
  String get region => 'Region';

  @override
  String get regionBeijing => 'Beijing';

  @override
  String get regionSingapore => 'Singapore';

  @override
  String get bailianRegionNote =>
      'Beijing and Singapore keys aren’t interchangeable; use a key for the region you choose.';

  @override
  String get keyHint => 'Paste or type a key';

  @override
  String get newKeyHint => 'Paste or type a new key';

  @override
  String get keySaved => 'Saved';

  @override
  String get pasteKey => 'Paste';

  @override
  String get showKey => 'Show';

  @override
  String get hideKey => 'Hide';

  @override
  String get replaceKey => 'Replace';

  @override
  String get deleteKey => 'Delete key';

  @override
  String get deleteKeyTitle => 'Delete this key?';

  @override
  String get deleteLlmKeyBody =>
      'Finding characters and assigning lines pause until you add a key again; chapters already voiced still play.';

  @override
  String get deleteVoiceKeyBody =>
      'Characters with this provider’s voices can’t be voiced until you add a key again or change their voices.';

  @override
  String get keyDeleted => 'Key deleted';

  @override
  String get keyDeleteFailed => 'Couldn’t delete the key. Try again';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get saveFailed => 'Couldn’t save. Try again.';

  @override
  String get saveFailedBody =>
      'Nothing changed. Check what you entered and try again.';

  @override
  String get discardTitle => 'Discard unsaved changes?';

  @override
  String get discardConfirm => 'Discard changes';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get llmSection => 'Characters and lines';

  @override
  String get voiceSection => 'Voices';

  @override
  String get voiceSectionNote =>
      'Voices are generated only by engines that are on. Keys are stored encrypted on this device and only sent to their own provider.';

  @override
  String get edgeRole => 'Free, no key needed';

  @override
  String get voiceNeedsKey => 'Add a key to turn it on';

  @override
  String get noVoiceTitle => 'No voice provider is on';

  @override
  String get noVoiceBody =>
      'Turn one on to generate voices. Microsoft Edge is free and needs no key.';

  @override
  String get turnOnEdge => 'Turn on Microsoft Edge';

  @override
  String get reasonProviderDisabled =>
      'This service is switched off in Settings';

  @override
  String get reasonNoVoiceProvider =>
      'No voice service for this book’s language is on';

  @override
  String offProviderTitle(String provider) {
    return '$provider is switched off';
  }

  @override
  String offProviderNoKeyTitle(String provider) {
    return '$provider has no key';
  }

  @override
  String offProviderBody(String provider) {
    return 'Some voices come from $provider. Turn it on, or rematch those characters with providers that are on.';
  }

  @override
  String offProviderSpeakers(String names, String provider) {
    return '$names use $provider voices. Turn it on, or rematch them with providers that are on.';
  }

  @override
  String speakersAndMore(String names, int total, int more) {
    return '$names and $more more';
  }

  @override
  String turnOnProvider(String provider) {
    return 'Turn on $provider';
  }

  @override
  String addProviderKey(String provider) {
    return 'Add a $provider key';
  }

  @override
  String get rematchVoices => 'Rematch voices';

  @override
  String get rematchFailed => 'Couldn’t rematch the voices. Try again';

  @override
  String get languageEngineCloud => 'Cloud language model';

  @override
  String get languageEngineDevice => 'On-device language model';

  @override
  String get voiceEngineDevice => 'On-device voices';

  @override
  String get engineInUse => 'In use';

  @override
  String get useEngine => 'Use';

  @override
  String get engineComingSoon => 'Coming soon';

  @override
  String get engineNotInstalled => 'Model not installed';

  @override
  String get engineComingSoonNote =>
      'Runs on this device: the text never leaves it and no key is needed. This engine is not ready yet.';

  @override
  String get engineNotInstalledNote =>
      'This engine runs on this device and needs its model installed first.';

  @override
  String get llmSectionNote =>
      'You can listen without a language model: import a script or audio package someone shared.';

  @override
  String get voiceSectionCloud => 'Voices · Cloud';

  @override
  String get voiceSectionDevice => 'Voices · On device';

  @override
  String get voiceSectionDeviceNote =>
      'On-device engines voice lines on this device; the text never leaves it.';

  @override
  String get traitEmotion => 'Emotion';

  @override
  String get traitInstruction => 'Direction notes';

  @override
  String get traitVocalCues => 'Vocal sounds';

  @override
  String get traitPacing => 'Pace and pitch';

  @override
  String get traitVoiceDesign => 'Voice design';

  @override
  String engineVoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voices',
      one: '1 voice',
    );
    return '$_temp0';
  }

  @override
  String get engineAbilities => 'What it performs';

  @override
  String get engineAbilitiesNote =>
      'Lines are written once. Each voice service performs what it can and replaces or leaves out the rest.';

  @override
  String get engineAbilitiesPlain => 'Distinct voices only';

  @override
  String get enginePageNote => 'Voices the cast.';

  @override
  String get edgePageNote =>
      'Microsoft Edge’s Read Aloud service. Free and needs no key; it has no emotions, only pace and pitch.';

  @override
  String get reasonEngineNotInstalled =>
      'This on-device engine has no model installed yet';

  @override
  String get reasonEngineUnavailable =>
      'This engine can’t be used yet. Choose another in Settings';

  @override
  String packageImported(String title, int scripts) {
    String _temp0 = intl.Intl.pluralLogic(
      scripts,
      locale: localeName,
      other: '$scripts chapters',
      one: '1 chapter',
    );
    return 'Imported “$title”: $_temp0 already directed';
  }

  @override
  String packageImportedAudio(String title, int scripts, int audio) {
    String _temp0 = intl.Intl.pluralLogic(
      scripts,
      locale: localeName,
      other: '$scripts chapters',
      one: '1 chapter',
    );
    return 'Imported “$title”: $_temp0 directed, $audio ready to listen';
  }

  @override
  String importPackageInvalidTitle(String file) {
    return '“$file” isn’t a valid script or audio package';
  }

  @override
  String get importPackageInvalidBody =>
      'The file may be incomplete, or exported by a newer pagestage. Your bookshelf hasn’t changed.';

  @override
  String replaceBookTitle(String title) {
    return 'Replace “$title”?';
  }

  @override
  String get replaceBookBody =>
      'This book is already on your shelf. Importing replaces its characters, lines and audio, and keeps your place.';

  @override
  String get replaceBookConfirm => 'Replace';

  @override
  String get shareBook => 'Share';

  @override
  String shareBookTitle(String title) {
    return 'Share “$title”';
  }

  @override
  String get shareScript => 'Script package';

  @override
  String shareScriptNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters of lines',
      one: '1 chapter of lines',
    );
    return 'The text, the characters and $_temp0. They voice it with their own services, with no language model needed.';
  }

  @override
  String get shareAudio => 'Audio package';

  @override
  String shareAudioNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voiced chapters',
      one: '1 voiced chapter',
    );
    return 'The script package plus the audio of $_temp0. They import it and listen.';
  }

  @override
  String get shareAudioNone => 'No chapter has been voiced yet.';

  @override
  String get shareNothing =>
      'Nothing to share yet. Listen to a few chapters so they get voiced first.';

  @override
  String get sharePreparing => 'Packing…';

  @override
  String get shareFailed => 'Couldn’t pack the book. Try again.';

  @override
  String get shareNote =>
      'A package holds the whole book’s text and leaves only through the system share sheet. Share only books you have the right to share.';

  @override
  String get shareLoadFailed => 'Couldn’t read this book’s scripts and audio';

  @override
  String get expressiveness => 'Emotion';

  @override
  String get expressivenessPlain => 'Even';

  @override
  String get expressivenessNatural => 'Natural';

  @override
  String get expressivenessDramatic => 'Heightened';

  @override
  String get expressivenessPlainNote =>
      'Distinct voices reading evenly, without emotion or vocal sounds.';

  @override
  String get expressivenessNaturalNote =>
      'Performed with the emotion the lines call for.';

  @override
  String get expressivenessDramaticNote => 'Emotions one step stronger.';

  @override
  String changeVoiceOf(String name) {
    return 'Change the voice of “$name”';
  }

  @override
  String reassignLine(String name) {
    return 'Not said by “$name”';
  }

  @override
  String get reassignTitle => 'Who says this line?';

  @override
  String get reassignNote => 'Only this line of the chapter is voiced again.';

  @override
  String get reassignImportedNote =>
      'This chapter’s audio was imported. After the change the whole chapter is voiced again with the voices you have on.';

  @override
  String reassigned(String name) {
    return 'Now said by “$name”';
  }

  @override
  String get reassignFailed => 'Couldn’t change the speaker. Try again.';

  @override
  String get speakersLoadFailed => 'Couldn’t load the characters';

  @override
  String get mingTitle => 'Ming offline voices';

  @override
  String get mingPending => 'Initialization required';

  @override
  String get mingDescription =>
      'Includes 32 Mandarin voices, from children to older adults, with options for narration. One initialization prepares every voice.';

  @override
  String get mingBeforeInit =>
      'Initialize before first use and keep PageStage in the foreground.';

  @override
  String get mingReady => 'Initialization complete. The voices are ready.';

  @override
  String get mingCopying => 'Copying and verifying the model files…';

  @override
  String mingCompiling(String module) {
    return 'Preparing $module…';
  }

  @override
  String get mingPrefill => 'text prefill';

  @override
  String get mingStep => 'single-line language model';

  @override
  String get mingFlow => 'single-line speech generation';

  @override
  String get mingAgg => 'acoustic aggregation';

  @override
  String get mingDec => 'audio decoder';

  @override
  String get mingFlowPair => 'two-line speech generation';

  @override
  String get mingStepPair => 'two-line language model';

  @override
  String get mingStorageError =>
      'Could not prepare the model files. Check free space and try again.';

  @override
  String get mingInitError =>
      'Initialization stopped. Resume from the last completed module.';

  @override
  String get mingInitialize => 'Initialize';

  @override
  String get mingRetry => 'Resume initialization';

  @override
  String get mingPreview => 'Preview two voices';

  @override
  String get mingActionError => 'The action could not be completed. Try again.';

  @override
  String get fallbackNote =>
      'AI voices weren’t ready in time, so the system voice reads this chapter. The next one switches back.';

  @override
  String get systemVoiceForNowNote =>
      'AI voices can’t be used right now, so the system voice reads this chapter.';

  @override
  String get turnOnAiVoice => 'Turn on AI voices';

  @override
  String waitingWithStatus(String status) {
    return 'Preparing this chapter: $status';
  }

  @override
  String get listenWithSystemVoice => 'Listen with the system voice';

  @override
  String get miniWaiting => 'Preparing AI voices…';

  @override
  String get listenFromStart => 'Listen from the start';

  @override
  String get errorNoSystemVoiceShort => 'No reading voice on this phone';

  @override
  String get errorChapterUnavailableShort => 'Can’t open this chapter';

  @override
  String get errorAudioFailedShort => 'Can’t play this passage';

  @override
  String get errorBookMissingShort => 'No longer on your shelf';

  @override
  String get errorAudioChangedShort => 'Audio changed — tap play';

  @override
  String get errorPlaybackStoppedShort => 'Stopped — tap play to retry';

  @override
  String get chapterProfiling => 'Finding characters';

  @override
  String get chapterListening => 'Listening';

  @override
  String get chapterVoiced => 'AI voices ready';

  @override
  String get generationPausedNote =>
      'The system voice reads meanwhile; listening goes on.';

  @override
  String profilingPausedLine(String provider, String reason) {
    return 'Finding characters · $provider: $reason';
  }

  @override
  String checkProviderSettings(String provider) {
    return 'Check $provider settings';
  }

  @override
  String get resumeAfterFixNote => 'It resumes once that’s fixed.';

  @override
  String get retryNow => 'Retry now';

  @override
  String get retryingSoon => 'It will retry by itself shortly.';

  @override
  String get reviewAndAgree => 'Review and agree';

  @override
  String get chooseVoices => 'Choose voices';

  @override
  String get useSystemVoiceForBook => 'Use the system voice for this book';

  @override
  String get reasonConsentNeeded =>
      'You haven’t agreed to send it book text yet';

  @override
  String consentSetupTitle(String provider) {
    return 'Allow sending book text to $provider?';
  }

  @override
  String get consentScopeNote =>
      'Agreeing once covers every book sent here. Withdraw it anytime in Settings › Privacy.';

  @override
  String get consentAgree => 'Agree';

  @override
  String get listeningSection => 'Listening';

  @override
  String get aiVoicesEnabled => 'AI voices';

  @override
  String get aiVoicesEnabledNote =>
      'Off: every book uses the system voice and no text is sent.';

  @override
  String get prepareAheadSetting => 'Prepare ahead';

  @override
  String get prepareAheadSettingNote =>
      'Prepares the next chapters while you listen. At 0 only the chapter you’re on is prepared.';

  @override
  String get fewerAhead => 'Prepare one chapter fewer';

  @override
  String get moreAhead => 'Prepare one chapter more';

  @override
  String get voiceSettings => 'Voice settings';

  @override
  String get voiceSettingsFailed => 'Couldn’t load this book’s voice settings';

  @override
  String get aiVoiceForBook => 'AI voices for each character';

  @override
  String get aiVoiceForBookNote =>
      'Each character gets their own voice, prepared as you listen. Text goes to the providers you set up. Off: the system voice reads, and chapters already voiced still play.';

  @override
  String get aiVoicesOffEverywhere => 'AI voices are off in Settings';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get readDialogueTags => 'Read tags like “he said”';

  @override
  String get readDialogueTagsNote =>
      'Off: characters speak for themselves and tags are skipped, like a radio drama.';

  @override
  String get performanceChangeNote =>
      'Changes apply to this book only. Voiced chapters are voiced again the next time you hear them, calling the voice service again; the chapter playing now finishes first.';

  @override
  String get prepareAhead => 'Prepare chapters…';

  @override
  String get prepareAheadNote =>
      'For example before a trip, to listen offline.';

  @override
  String get stopPreparing => 'Stop preparing';

  @override
  String get stopPreparingNote =>
      'Cancels queued chapters. While you listen, the next chapter or two are still prepared.';

  @override
  String get castShort => 'Characters';

  @override
  String get castRowNote => 'Who each character is and how they sound';

  @override
  String get sampleVoicedTitle => 'The sample is voiced in advance';

  @override
  String get sampleVoicedBody =>
      'Its settings can’t change. Import your own book to voice it with your own providers.';

  @override
  String get voiceStatusSample => 'Sample · voiced in advance';

  @override
  String get voiceStatusTurnOn => 'Turn on AI voices';

  @override
  String voiceStatusReadyThrough(int chapter) {
    return 'Ready through chapter $chapter';
  }

  @override
  String voiceStatusVoicedCount(int count) {
    return '$count chapters voiced';
  }

  @override
  String get voiceStatusAsYouListen => 'Prepared as you listen';

  @override
  String get gapLanguageModelTitle => 'A language model account is needed';

  @override
  String get gapLanguageModelBody =>
      'AI voices first need a language model to find the characters and assign lines. The system voice reads until it’s set up.';

  @override
  String get gapVoiceTitle => 'A voice service is needed';

  @override
  String get gapVoiceBody =>
      'Turn on at least one voice service. Microsoft Edge is free and needs no key.';

  @override
  String profileNeededTitle(int chapter) {
    return 'To voice chapter $chapter, the characters before it need finding first';
  }

  @override
  String profileNeededBody(int from, int through) {
    return 'This sends chapters $from–$through to the language model and may take a while; the system voice reads meanwhile.';
  }

  @override
  String get profileNeededAction => 'Start';

  @override
  String get jumpToChapter => 'Jump to…';

  @override
  String get profilingNotStarted => 'No characters found yet';

  @override
  String profilingStatusLine(int chapter, int count) {
    return 'Found through chapter $chapter of $count';
  }

  @override
  String get profilingAuto =>
      'Characters are found as you listen; there’s nothing to do.';

  @override
  String get profileMore => 'Find characters further ahead…';

  @override
  String laterCharacters(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count characters who appear later',
      one: '1 character who appears later',
    );
    return '$_temp0';
  }

  @override
  String get showLaterCharacters => 'Show (may spoil)';

  @override
  String get hideLaterCharacters => 'Hide';

  @override
  String get profileFirstChapter => 'First appears';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get ageChild => 'Child';

  @override
  String get ageTeen => 'Teen';

  @override
  String get ageYoungAdult => 'Young adult';

  @override
  String get ageMiddleAged => 'Middle-aged';

  @override
  String get ageSenior => 'Senior';

  @override
  String get startupFailedTitle => 'pagestage couldn’t open';

  @override
  String get startupFailedBody =>
      'Your books and settings are still there. Try again; if it keeps happening, export a diagnostic report for us. It contains no book text and no keys.';

  @override
  String get keysUnavailableTitle => 'Saved keys can’t be read';

  @override
  String get keysUnavailableBody =>
      'The system keychain isn’t available right now, so AI voices can’t run; books still read and play in the system voice. Restart the phone and try again, or enter the keys again.';

  @override
  String get regionGlobal => 'International';

  @override
  String get regionChina => 'Mainland China';

  @override
  String get presetSection => 'Service';

  @override
  String get presetService => 'Language model service';

  @override
  String get presetBailian => 'Alibaba Cloud Model Studio (Qwen)';

  @override
  String get presetCustom => 'Custom';

  @override
  String get presetCustomNote =>
      'Any OpenAI-compatible service with structured output (JSON Schema) works; enter its address and model yourself.';

  @override
  String presetConsoleNote(String console) {
    return 'The address, protocol and a suitable model are filled in. Create an API key at $console and paste it below.';
  }

  @override
  String get shareBailianKey => 'Also voice with this key on Model Studio';

  @override
  String get shareBailianKeyNote =>
      'The same Model Studio key voices too (Beijing region); no need to enter it twice.';

  @override
  String get testConnection => 'Test connection';

  @override
  String get testConnectionNote =>
      'Sends one tiny request to check it works; no book text is sent.';

  @override
  String get testConnectionOk => 'Connected and working.';

  @override
  String get testUnauthorized =>
      'The key was refused: check it was copied in full and the region or platform matches.';

  @override
  String get testSchemaUnsupported =>
      'This model doesn’t support structured output (JSON Schema). Pick one that does, or a preset above.';

  @override
  String get testRequestRejected =>
      'The provider refused the request: check the address and model name.';

  @override
  String get testQuota => 'The account is out of credit. Top up and try again.';

  @override
  String get testMissing => 'A key or model name is still missing.';

  @override
  String get testRateLimited => 'Too many requests; try again in a moment.';

  @override
  String get testNetwork =>
      'Couldn’t connect: check the network and the address.';

  @override
  String get usage => 'Usage';

  @override
  String get usageRowNote => 'How much each book used of each service';

  @override
  String get usageNote =>
      'Figures are what each provider reported, in its own units; its bill is the final word on cost.';

  @override
  String get usageEmpty => 'No paid service has been used yet.';

  @override
  String get usageLoadFailed => 'Couldn’t load usage';

  @override
  String get usageEarlier => 'Earlier usage (not kept per book)';

  @override
  String get usageDeletedBook => 'A deleted book';

  @override
  String usageTokens(String provider, String count) {
    return '$provider $count tokens';
  }

  @override
  String usageCharacters(String provider, String count) {
    return '$provider $count characters';
  }

  @override
  String get usageNothingBilled => 'Nothing billed';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacyRowNote => 'Who receives book text; withdraw anytime';

  @override
  String get privacyIntro =>
      'Books stay on this phone. With AI voices on, the text of the chapters you listen to and the book’s characters go to the language model and voice services you set up, to find characters, assign lines and voice them. Keys are stored encrypted on this phone and only sent to their own provider. The system voice sends nothing.';

  @override
  String get consentsSection => 'Services allowed to receive text';

  @override
  String get consentsNote =>
      'After withdrawing, AI voices that need it pause and the system voice reads until you agree again.';

  @override
  String get consentsEmpty => 'No service has been allowed yet';

  @override
  String get revokeConsent => 'Withdraw';

  @override
  String get consentRevoked => 'Withdrawn';

  @override
  String get privacyLoadFailed => 'Couldn’t load';

  @override
  String get systemVoicePageNote =>
      'Reads books and chapters without AI voices. Tap one to hear it and use it.';

  @override
  String get systemVoiceRowNote =>
      'Without AI voices your phone’s own voice reads; pick one you like.';

  @override
  String get systemVoiceChinese => 'Chinese';

  @override
  String get systemVoiceEnglish => 'English';

  @override
  String get systemVoiceNone => 'No voice available';

  @override
  String get systemVoiceDownloadNote =>
      'Download an “Enhanced” or “Premium” voice in system settings (Accessibility › Spoken Content › Voices); it sounds much more natural.';

  @override
  String get voiceQualityEnhanced => 'Enhanced';

  @override
  String get voiceQualityPremium => 'Premium';

  @override
  String get continueListening => 'Continue listening';

  @override
  String get sampleBookMeta => 'Sample · voiced';

  @override
  String get importFailedDismiss => 'OK';

  @override
  String bookUpdatedAdded(String title, int added) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added new chapters',
      one: '1 new chapter',
    );
    return '“$title” has $_temp0';
  }

  @override
  String bookUpdatedChanged(String title, int changed) {
    String _temp0 = intl.Intl.pluralLogic(
      changed,
      locale: localeName,
      other: '$changed chapters',
      one: '1 chapter',
    );
    return '$_temp0 of “$title” changed';
  }

  @override
  String get chapterShort => 'Chapter';

  @override
  String get lineShort => 'Line';

  @override
  String bookUsageLine(String summary) {
    return 'Used by this book: $summary, as the providers reported.';
  }

  @override
  String auditionNeedsProvider(String provider) {
    return 'Auditions need $provider, which isn’t set up';
  }

  @override
  String get auditionNeedsProviderBody =>
      'This voice hasn’t spoken in a voiced chapter yet, so a sample has to be made with it.';
}
