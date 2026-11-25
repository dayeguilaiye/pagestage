import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

/// Localized text for the stable codes the services report. Unknown codes
/// get a general sentence; raw codes never reach the screen.
abstract final class Labels {
  static String listeningError(AppLocalizations l, String code) =>
      switch (code) {
        'systemVoiceUnavailable' => l.errorNoSystemVoice,
        'endOfBook' => l.endOfBook,
        'chapterUnavailable' => l.errorChapterUnavailable,
        'audioFailed' => l.errorAudioFailed,
        'bookMissing' => l.errorBookMissing,
        'audioChanged' => l.errorAudioChanged,
        _ => l.errorPlaybackStopped,
      };

  /// The same, short enough for the mini player's one line.
  static String listeningErrorShort(AppLocalizations l, String code) =>
      switch (code) {
        'systemVoiceUnavailable' => l.errorNoSystemVoiceShort,
        'endOfBook' => l.endOfBook,
        'chapterUnavailable' => l.errorChapterUnavailableShort,
        'audioFailed' => l.errorAudioFailedShort,
        'bookMissing' => l.errorBookMissingShort,
        'audioChanged' => l.errorAudioChangedShort,
        _ => l.errorPlaybackStoppedShort,
      };

  /// A profile's gender tag; empty when unknown, so the row is left out.
  static String gender(AppLocalizations l, String gender) => switch (gender) {
    'male' => l.genderMale,
    'female' => l.genderFemale,
    _ => '',
  };

  /// A profile's age band; empty when unknown.
  static String ageGroup(AppLocalizations l, String age) => switch (age) {
    'child' => l.ageChild,
    'teen' => l.ageTeen,
    'youngAdult' => l.ageYoungAdult,
    'middleAged' => l.ageMiddleAged,
    'senior' => l.ageSenior,
    _ => '',
  };

  /// The end of the book is news, not a failure.
  static bool isEndOfBook(String? code) => code == 'endOfBook';

  /// An engine's name. Engines this build has no name for show their id.
  static String provider(AppLocalizations l, String? provider) =>
      switch (provider?.toLowerCase()) {
        null || '' => l.providerUnknown,
        'llm' => l.providerLlm,
        'llm-device' => l.languageEngineDevice,
        'minimax' => 'MiniMax',
        'edge' => 'Microsoft Edge',
        'bailian' => l.providerBailian,
        'device' => l.voiceEngineDevice,
        'ming' => l.mingTitle,
        'system' => l.systemVoice,
        _ => provider!,
      };

  /// An engine's name where the language engines are listed side by side.
  static String engine(AppLocalizations l, EngineView engine) =>
      engine.id == 'llm' ? l.languageEngineCloud : provider(l, engine.id);

  /// What a voice engine can perform beyond reading in a voice.
  static String trait(AppLocalizations l, EngineTrait trait) => switch (trait) {
    EngineTrait.emotion => l.traitEmotion,
    EngineTrait.instruction => l.traitInstruction,
    EngineTrait.vocalCues => l.traitVocalCues,
    EngineTrait.pacing => l.traitPacing,
    EngineTrait.voiceDesign => l.traitVoiceDesign,
  };

  /// A setting's label; one this build has no label for shows its name.
  static String engineSetting(AppLocalizations l, String name) =>
      switch (name) {
        'key' => l.apiKey,
        'baseUrl' => l.baseUrl,
        'api' => l.protocol,
        'region' => l.region,
        'profileModel' => l.profileModel,
        'directorModel' => l.directorModel,
        _ => name,
      };

  static String engineOption(AppLocalizations l, String option) =>
      switch (option) {
        'chat-completions' => l.protocolChatCompletions,
        'responses' => l.protocolResponses,
        'beijing' => l.regionBeijing,
        'singapore' => l.regionSingapore,
        'global' => l.regionGlobal,
        'china' => l.regionChina,
        _ => option,
      };

  /// [provider]'s name ready to sit inside a sentence: in Chinese a Latin
  /// name gets a space on each side, which [sentence] trims at the ends.
  static String inline(AppLocalizations l, String provider) {
    final name = Labels.provider(l, provider);
    return l.localeName.startsWith('zh') && !psHasCjk(name) ? ' $name ' : name;
  }

  /// Trims the spaces [inline] left at either end.
  static String sentence(String text) => text.trim();

  static String pauseReason(AppLocalizations l, String? reason) =>
      switch (reason) {
        'missingKey' => l.reasonMissingKey,
        'unauthorized' => l.reasonUnauthorized,
        'rateLimited' => l.reasonRateLimited,
        'quotaExceeded' => l.reasonQuotaExceeded,
        'network' => l.reasonNetwork,
        'localSynthesisFailed' => l.reasonLocalSynthesisFailed,
        'consentDeclined' => l.reasonConsentDeclined,
        'consentNeeded' => l.reasonConsentNeeded,
        'invalidResponse' => l.reasonInvalidResponse,
        'requestRejected' => l.reasonRequestRejected,
        'schemaUnsupported' => l.reasonSchemaUnsupported,
        'contentRejected' => l.reasonContentRejected,
        'truncated' => l.reasonTruncated,
        'interrupted' => l.reasonInterrupted,
        'voiceUnavailable' => l.reasonVoiceUnavailable,
        'providerDisabled' => l.reasonProviderDisabled,
        'engineNotInstalled' => l.reasonEngineNotInstalled,
        'engineUnavailable' => l.reasonEngineUnavailable,
        'noVoiceProvider' => l.reasonNoVoiceProvider,
        _ => l.reasonUnknown,
      };

  static String consentContent(AppLocalizations l, String content) =>
      switch (content) {
        'chapterTextAndCast' => l.consentChapterTextAndCast,
        'voiceSample' => l.consentVoiceSample,
        _ => l.consentBookContent,
      };

  /// 1.0×, 1.25×, 0.75×.
  static String speed(double speed) {
    var text = speed.toStringAsFixed(2);
    if (text.endsWith('0')) text = text.substring(0, text.length - 1);
    return '$text×';
  }

  /// 4:05, or 1:04:05 past an hour.
  static String clock(Duration d) {
    final s = d.inSeconds.abs();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = (s % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
  }
}
