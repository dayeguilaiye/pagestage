import 'dart:async';

import 'package:http/http.dart' as http;

import 'provider_exception.dart';

/// Transport statuses with a stable meaning even when the body is not JSON.
ProviderErrorKind? ttsHttpError(int statusCode) => switch (statusCode) {
  401 => ProviderErrorKind.invalidKey,
  402 => ProviderErrorKind.insufficientBalance,
  429 => ProviderErrorKind.rateLimited,
  >= 500 => ProviderErrorKind.unavailable,
  _ => null,
};

/// Keeps transport and decoding failures free of provider bodies and credentials.
Future<T> withTtsErrors<T>(
  String provider,
  Future<T> Function() operation,
) async {
  try {
    return await operation();
  } on TimeoutException {
    throw ProviderException(
      provider: provider,
      kind: ProviderErrorKind.unavailable,
    );
  } on http.ClientException {
    throw ProviderException(
      provider: provider,
      kind: ProviderErrorKind.unavailable,
    );
  } on FormatException {
    throw ProviderException(
      provider: provider,
      kind: ProviderErrorKind.invalidResponse,
    );
  } on TypeError {
    throw ProviderException(
      provider: provider,
      kind: ProviderErrorKind.invalidResponse,
    );
  }
}
