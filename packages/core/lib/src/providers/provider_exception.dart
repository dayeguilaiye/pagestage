/// Stable categories callers can use to pause work and request user action.
enum ProviderErrorKind {
  invalidKey,
  insufficientBalance,
  rateLimited,
  unavailable,
  invalidResponse,
  invalidVoice,
  invalidConfiguration,
}

/// Fixed codes on LLM [ProviderErrorKind.invalidResponse] failures.
abstract final class LlmFailure {
  /// Provider moderation refused the input or the answer.
  static const contentFilter = 'content_filter';

  /// The model declined to answer.
  static const refusal = 'refusal';

  /// The answer reached the output length limit.
  static const truncated = 'truncated';

  /// The request itself was refused, such as an unknown model. Every later
  /// request fails the same way.
  static const requestRejected = 'request_rejected';

  /// The endpoint refused the structured output format.
  static const schemaUnsupported = 'schema_unsupported';

  /// The answer could not be read; another request may succeed.
  static const malformed = 'malformed';

  /// The same input fails again, while other chapters can still succeed.
  static bool inputBound(String? code) =>
      code == contentFilter || code == refusal || code == truncated;
}

/// Contains only a safe category and optional machine-readable error code.
/// Raw provider messages and request/response bodies never enter this error.
class ProviderException implements Exception {
  const ProviderException({
    required this.provider,
    required this.kind,
    this.code,
  });
  final String provider;
  final ProviderErrorKind kind;
  final String? code;

  @override
  String toString() =>
      '$provider: ${switch (kind) {
        ProviderErrorKind.invalidKey => 'API key is invalid.',
        ProviderErrorKind.insufficientBalance => 'The account has insufficient balance.',
        ProviderErrorKind.rateLimited => 'The provider rate limit was reached.',
        ProviderErrorKind.unavailable => switch (code) {
          'timeout' => 'The provider request timed out. Retry the command.',
          'connection_error' => 'The provider connection failed or was interrupted. Retry the command.',
          'interrupted_stream' => 'The provider response stream was interrupted. Retry the command.',
          _ => 'The provider is unavailable. Try again later.',
        },
        ProviderErrorKind.invalidResponse => 'The provider returned an invalid response.${code == null ? '' : ' ($code)'}',
        ProviderErrorKind.invalidVoice => 'The voice binding is unavailable.',
        ProviderErrorKind.invalidConfiguration => 'The provider configuration is invalid.',
      }}';
}
