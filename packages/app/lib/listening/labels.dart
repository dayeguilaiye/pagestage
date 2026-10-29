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
        'generationCancelled' => l.errorGenerationCancelled,
        _ => l.errorPlaybackStopped,
      };

  /// The end of the book is news, not a failure.
  static bool isEndOfBook(String? code) => code == 'endOfBook';

  static String provider(AppLocalizations l, String? provider) =>
      switch (provider?.toLowerCase()) {
        null || '' => l.providerUnknown,
        'llm' => l.providerLlm,
        'minimax' => 'MiniMax',
        'edge' => 'Microsoft Edge',
        'bailian' => l.providerBailian,
        'system' => l.systemVoice,
        _ => provider!,
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
        'consentDeclined' => l.reasonConsentDeclined,
        'invalidResponse' => l.reasonInvalidResponse,
        'requestRejected' => l.reasonRequestRejected,
        'schemaUnsupported' => l.reasonSchemaUnsupported,
        'contentRejected' => l.reasonContentRejected,
        'truncated' => l.reasonTruncated,
        'interrupted' => l.reasonInterrupted,
        'voiceUnavailable' => l.reasonVoiceUnavailable,
        'providerDisabled' => l.reasonProviderDisabled,
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
