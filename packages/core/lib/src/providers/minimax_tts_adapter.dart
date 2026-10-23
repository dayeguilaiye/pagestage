import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../pcm_audio.dart';
import '../models/voice.dart';
import 'provider_exception.dart';
import 'tts_adapter.dart';
import 'voice_design_adapter.dart';
import 'voice_design_http.dart';

class MiniMaxTtsAdapter implements TtsAdapter, VoiceDesignAdapter {
  MiniMaxTtsAdapter({required String apiKey, Uri? baseUrl, http.Client? client})
    : _apiKey = apiKey,
      _baseUrl = baseUrl ?? Uri.parse('https://api.minimax.io/v1'),
      _client = client ?? http.Client(),
      _ownsClient = client == null {
    if (apiKey.trim().isEmpty ||
        !['http', 'https'].contains(_baseUrl.scheme) ||
        _baseUrl.host.isEmpty ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
  }
  final String _apiKey;
  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  @override
  String get provider => 'minimax';

  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) {
    if (binding.provider != provider) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return const TtsCapabilities(
      supportsVoiceDesign: true,
      emotionControl: EmotionControl.enumerated,
      supportsPronunciation: true,
      returnsTimestamps: false,
      maxCharacters: 9999,
    );
  }

  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    if (request.binding.provider != provider ||
        request.text.trim().isEmpty ||
        request.text.runes.length >= 10000) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    final endpoint = _baseUrl.replace(
      path: '${_baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/t2a_v2',
    );
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': request.binding.model,
              'text': request.text,
              'stream': false,
              'output_format': 'hex',
              'language_boost': request.language == 'zh'
                  ? 'Chinese'
                  : 'English',
              'voice_setting': {
                'voice_id': request.binding.voiceId,
                'speed': 1,
                'vol': 1,
                'pitch': 0,
                'emotion': request.direction.emotion.name,
              },
              'audio_setting': {
                'sample_rate': 24000,
                'format': 'wav',
                'channel': 1,
              },
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (response.statusCode == 401 ||
          response.statusCode == 402 ||
          response.statusCode == 429 ||
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
      final status = (json['base_resp'] as Map)['status_code'];
      if (response.statusCode != 200 || status != 0) {
        throw ProviderException(
          provider: provider,
          kind: switch (status) {
            1004 || 2049 => ProviderErrorKind.invalidKey,
            1008 || 2053 => ProviderErrorKind.insufficientBalance,
            1002 || 1039 || 1045 => ProviderErrorKind.rateLimited,
            1000 || 1001 || 1024 || 1033 => ProviderErrorKind.unavailable,
            20132 || 2042 || 2043 || 2054 => ProviderErrorKind.invalidVoice,
            _ => ProviderErrorKind.invalidResponse,
          },
          code: status is int ? status.toString() : null,
        );
      }
      final data = json['data'] as Map;
      if (data['status'] != 2) throw const FormatException('Incomplete audio.');
      final hex = data['audio'] as String;
      if (hex.isEmpty ||
          hex.length.isOdd ||
          !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
        throw const FormatException('Invalid audio encoding.');
      }
      final wav = Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
      final audio = PcmAudio.fromWav(wav);
      if (audio.samples.isEmpty) throw const FormatException('Empty audio.');
      final characters = (json['extra_info'] as Map)['usage_characters'] as int;
      if (characters < 0) throw const FormatException('Invalid usage.');
      return TtsAudio(audio: audio, characters: characters);
    } on TimeoutException {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.unavailable,
      );
    } on http.ClientException {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.unavailable,
      );
    } on FormatException {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidResponse,
      );
    } on TypeError {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidResponse,
      );
    }
  }

  @override
  Future<DesignedVoice> design(VoiceDesignRequest request) => designMiniMax(
    request,
    apiKey: _apiKey,
    baseUrl: _baseUrl,
    client: _client,
  );

  void close() {
    if (_ownsClient) _client.close();
  }
}
