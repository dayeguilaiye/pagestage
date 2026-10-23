import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/voice.dart';
import 'provider_exception.dart';
import 'voice_design_adapter.dart';

Future<DesignedVoice> designMiniMax(
  VoiceDesignRequest request, {
  required String apiKey,
  required Uri baseUrl,
  required http.Client client,
}) async {
  if (request.description.trim().isEmpty ||
      request.previewText.trim().isEmpty ||
      request.previewText.runes.length > 500 ||
      request.model.trim().isEmpty ||
      !['zh', 'en'].contains(request.language)) {
    throw const ProviderException(
      provider: 'minimax',
      kind: ProviderErrorKind.invalidConfiguration,
    );
  }
  return _send(
    provider: 'minimax',
    apiKey: apiKey,
    baseUrl: baseUrl,
    client: client,
    path: 'voice_design',
    body: {'prompt': request.description, 'preview_text': request.previewText},
    decode: (json) {
      final voiceId = json['voice_id'] as String;
      final hex = json['trial_audio'] as String;
      if (voiceId.trim().isEmpty ||
          hex.isEmpty ||
          hex.length.isOdd ||
          !RegExp(r'^[a-fA-F0-9]+$').hasMatch(hex)) {
        throw const FormatException('Invalid design response.');
      }
      return DesignedVoice(
        binding: VoiceBinding(
          provider: 'minimax',
          model: request.model,
          voiceId: voiceId,
          designed: true,
        ),
        preview: VoicePreview.detect(
          Uint8List.fromList([
            for (var i = 0; i < hex.length; i += 2)
              int.parse(hex.substring(i, i + 2), radix: 16),
          ]),
        ),
      );
    },
  );
}

Future<DesignedVoice> _send({
  required String provider,
  required String apiKey,
  required Uri baseUrl,
  required http.Client client,
  required String path,
  required Map<String, Object?> body,
  required DesignedVoice Function(Map<String, dynamic>) decode,
}) async {
  try {
    final response = await client
        .post(
          baseUrl.replace(
            path: '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/$path',
          ),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));
    if ([401, 402, 429].contains(response.statusCode) ||
        response.statusCode >= 500) {
      throw ProviderException(
        provider: provider,
        kind: switch (response.statusCode) {
          401 => ProviderErrorKind.invalidKey,
          402 => ProviderErrorKind.insufficientBalance,
          429 => ProviderErrorKind.rateLimited,
          _ => ProviderErrorKind.unavailable,
        },
      );
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final code = provider == 'minimax'
        ? (json['base_resp'] as Map)['status_code']
        : json['code'];
    if (response.statusCode != 200 ||
        (provider == 'minimax' ? code != 0 : code != null)) {
      throw ProviderException(
        provider: provider,
        kind: switch (code) {
          1004 ||
          2049 ||
          'InvalidApiKey' ||
          'invalid_api_key' => ProviderErrorKind.invalidKey,
          1008 || 2053 || 'Arrearage' => ProviderErrorKind.insufficientBalance,
          1002 ||
          1039 ||
          1045 ||
          'Throttling' ||
          'Throttling.RateQuota' ||
          'Throttling.AllocationQuota' => ProviderErrorKind.rateLimited,
          1000 || 1001 || 1024 || 1033 => ProviderErrorKind.unavailable,
          20132 || 2042 || 2043 || 2054 => ProviderErrorKind.invalidVoice,
          'AccessDenied' => ProviderErrorKind.invalidConfiguration,
          _ =>
            response.statusCode == 403
                ? ProviderErrorKind.invalidConfiguration
                : ProviderErrorKind.invalidResponse,
        },
      );
    }
    return decode(json);
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

Future<DesignedVoice> designBailian(
  VoiceDesignRequest request, {
  required String apiKey,
  required Uri baseUrl,
  required http.Client client,
}) async {
  if (request.description.trim().isEmpty ||
      request.description.runes.length > 500 ||
      request.previewText.trim().isEmpty ||
      request.previewText.runes.length < 15 ||
      request.previewText.runes.length > 200 ||
      !['zh', 'en'].contains(request.language)) {
    throw const ProviderException(
      provider: 'bailian',
      kind: ProviderErrorKind.invalidConfiguration,
    );
  }
  return _send(
    provider: 'bailian',
    apiKey: apiKey,
    baseUrl: baseUrl,
    client: client,
    path: 'services/audio/tts/customization',
    body: {
      'model': 'voice-enrollment',
      'input': {
        'action': 'create_voice',
        'target_model': request.model,
        'voice_prompt': request.description,
        'preview_text': request.previewText,
        'prefix': 'pagestage',
        'language_hints': [request.language],
      },
      'parameters': {'sample_rate': 24000, 'response_format': 'wav'},
    },
    decode: (json) {
      final output = json['output'] as Map;
      final voiceId = output['voice_id'] as String;
      final model = output['target_model'] as String;
      final audio = output['preview_audio'] as Map;
      final preview = VoicePreview.detect(
        base64Decode(audio['data'] as String),
      );
      if (voiceId.trim().isEmpty ||
          model != request.model ||
          audio['response_format'] != 'wav' ||
          preview.extension != 'wav' ||
          audio['sample_rate'] != 24000) {
        throw const FormatException('Invalid design response.');
      }
      return DesignedVoice(
        binding: VoiceBinding(
          provider: 'bailian',
          model: model,
          voiceId: voiceId,
          designed: true,
          parameters: const {'region': 'beijing'},
        ),
        preview: preview,
      );
    },
  );
}
