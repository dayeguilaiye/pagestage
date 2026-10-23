import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/script.dart';
import '../pcm_audio.dart';
import '../pronunciation.dart';
import '../models/voice.dart';
import 'provider_exception.dart';
import 'tts_http.dart';
import 'tts_adapter.dart';
import 'usage_ledger.dart';
import 'voice_design_adapter.dart';

enum BailianRegion { beijing, singapore }

class BailianTtsAdapter implements TtsAdapter, VoiceDesignAdapter {
  BailianTtsAdapter({
    required String apiKey,
    this.region = BailianRegion.beijing,
    this.requestCharacterLimit = 600,
    Uri? baseUrl,
    http.Client? client,
    UsageLedger? usageLedger,
  }) : _apiKey = apiKey,
       _usageLedger = usageLedger,
       _baseUrl =
           baseUrl ??
           Uri.parse(
             region == BailianRegion.beijing
                 ? 'https://dashscope.aliyuncs.com/api/v1'
                 : 'https://dashscope-intl.aliyuncs.com/api/v1',
           ),
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (requestCharacterLimit < 1 ||
        apiKey.trim().isEmpty ||
        !['http', 'https'].contains(_baseUrl.scheme) ||
        _baseUrl.host.isEmpty ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment) {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
  }
  final String _apiKey;
  final UsageLedger? _usageLedger;
  final Uri _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final BailianRegion region;
  final int requestCharacterLimit;
  static const _models = {
    'qwen-audio-3.1-tts-flash',
    'qwen-audio-3.1-tts-plus',
    'qwen-audio-3.0-tts-flash',
    'qwen-audio-3.0-tts-plus',
  };

  bool get _supportsDesignedVoices =>
      region == BailianRegion.beijing &&
      _baseUrl.host != 'dashscope-intl.aliyuncs.com' &&
      !_baseUrl.host.contains('.ap-southeast-');

  @override
  String get provider => 'bailian';

  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) {
    if (binding.provider != provider ||
        !_models.contains(binding.model) ||
        (binding.designed && !_supportsDesignedVoices)) {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return TtsCapabilities(
      supportsPronunciation:
          binding.model.startsWith('qwen-audio-3.1-') &&
          !binding.designed &&
          binding.voiceId.endsWith('_v3.1'),
      maxCharacters: requestCharacterLimit,
    );
  }

  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    final capabilities = capabilitiesFor(request.binding);
    if (request.text.trim().isEmpty ||
        request.text.runes.length > capabilities.maxCharacters) {
      throw const ProviderException(
        provider: 'bailian',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    final matches = pronunciationMatches(
      request.text,
      request.language == 'zh' && capabilities.supportsPronunciation
          ? request.pronunciations
          : [],
    );
    return withTtsErrors(provider, () async {
      final json = await _post('services/audio/tts/SpeechSynthesizer', {
        'model': request.binding.model,
        'input': {
          'text': matches.isEmpty
              ? request.text
              : pronunciationSsml(request.text, matches),
          if (matches.isNotEmpty) 'enable_ssml': true,
          'instruction': _instruction(request.direction, request.language),
          'voice': request.binding.voiceId,
          'format': 'wav',
          'sample_rate': 24000,
          'language_hints': [request.language],
        },
      });
      final output = json['output'] as Map;
      if (output['finish_reason'] != 'stop') {
        throw const FormatException('Incomplete audio.');
      }
      final url = Uri.tryParse((output['audio'] as Map)['url'] as String);
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty) {
        throw const FormatException('Invalid audio URL.');
      }
      // The signed download URL is a separate service and receives no API key.
      final audioResponse = await _client
          .get(url)
          .timeout(const Duration(seconds: 90));
      if (audioResponse.statusCode != 200) {
        throw const FormatException('Audio download failed.');
      }
      final audio = PcmAudio.fromWav(audioResponse.bodyBytes);
      if (audio.samples.isEmpty) throw const FormatException('Empty audio.');
      final usage = json['usage'] as Map? ?? {};
      int? count(String field) {
        final value = usage[field];
        if (value == null) return null;
        if (value is! int || value < 0) {
          throw const FormatException('Invalid usage.');
        }
        return value;
      }

      return TtsAudio(
        audio: audio,
        characters: count('characters'),
        inputTokens: count('input_tokens'),
        outputTokens: count('output_tokens'),
        totalTokens: count('total_tokens'),
      );
    });
  }

  @override
  Future<DesignedVoice> design(VoiceDesignRequest request) async {
    if (!_supportsDesignedVoices ||
        !_models.contains(request.model) ||
        request.description.trim().isEmpty ||
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
    return withTtsErrors(provider, () async {
      final json = await _post('services/audio/tts/customization', {
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
      }, timeout: const Duration(seconds: 120));
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
          provider: provider,
          model: model,
          voiceId: voiceId,
          designed: true,
          parameters: const {'region': 'beijing'},
        ),
        preview: preview,
      );
    });
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final endpoint = _baseUrl.replace(
      path: '${_baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/$path',
    );
    final response = await _client
        .post(
          endpoint,
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final transportError = ttsHttpError(response.statusCode);
    if (transportError != null) {
      throw ProviderException(provider: provider, kind: transportError);
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final code = json['code'];
    if (response.statusCode != 200 || code != null) {
      throw ProviderException(
        provider: provider,
        kind: _errorKind(code, response.statusCode),
      );
    }
    _usageLedger?.record(
      UsageRecord(
        provider: provider,
        endpoint: endpoint.toString(),
        model: body['model'] as String?,
        requestId: json['request_id']?.toString(),
        usage: usageFields(json['usage']),
      ),
    );
    return json;
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}

String _instruction(Direction direction, String language) {
  final note = direction.note.trim();
  if (language == 'zh') {
    const emotions = ['平静', '开心', '悲伤', '愤怒', '恐惧', '厌恶', '惊讶'];
    const intensities = ['轻', '中', '强'];
    return '以${emotions[direction.emotion.index]}的语气、'
        '强度${intensities[direction.intensity.index]}朗读。$note';
  }
  return 'Read with a ${direction.emotion.name} emotion and '
      '${direction.intensity.name} intensity.${note.isEmpty ? '' : ' $note'}';
}

ProviderErrorKind _errorKind(Object? code, int statusCode) => switch (code) {
  'InvalidApiKey' || 'invalid_api_key' => ProviderErrorKind.invalidKey,
  'Arrearage' => ProviderErrorKind.insufficientBalance,
  'Throttling' ||
  'Throttling.RateQuota' ||
  'Throttling.AllocationQuota' => ProviderErrorKind.rateLimited,
  'AccessDenied' => ProviderErrorKind.invalidConfiguration,
  _ =>
    statusCode == 403
        ? ProviderErrorKind.invalidConfiguration
        : ProviderErrorKind.invalidResponse,
};
