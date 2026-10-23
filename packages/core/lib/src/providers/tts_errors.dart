import 'provider_exception.dart';

/// Transport statuses with a stable meaning even when the body is not JSON.
ProviderErrorKind? ttsHttpError(int statusCode) => switch (statusCode) {
  401 => ProviderErrorKind.invalidKey,
  402 => ProviderErrorKind.insufficientBalance,
  429 => ProviderErrorKind.rateLimited,
  >= 500 => ProviderErrorKind.unavailable,
  _ => null,
};

/// Provider error codes shared by synthesis and voice-design responses.
/// Raw provider messages are deliberately excluded from classification.
ProviderErrorKind ttsErrorCode(
  String provider,
  Object? code, {
  required int statusCode,
}) => switch ((provider, code)) {
  ('minimax', 1004 || 2049) ||
  (
    'bailian',
    'InvalidApiKey' || 'invalid_api_key',
  ) => ProviderErrorKind.invalidKey,
  ('minimax', 1008 || 2053) ||
  ('bailian', 'Arrearage') => ProviderErrorKind.insufficientBalance,
  ('minimax', 1002 || 1039 || 1045) ||
  (
    'bailian',
    'Throttling' || 'Throttling.RateQuota' || 'Throttling.AllocationQuota',
  ) => ProviderErrorKind.rateLimited,
  ('minimax', 1000 || 1001 || 1024 || 1033) => ProviderErrorKind.unavailable,
  ('minimax', 20132 || 2042 || 2043 || 2054) => ProviderErrorKind.invalidVoice,
  ('bailian', 'AccessDenied') => ProviderErrorKind.invalidConfiguration,
  _ =>
    statusCode == 403
        ? ProviderErrorKind.invalidConfiguration
        : ProviderErrorKind.invalidResponse,
};
