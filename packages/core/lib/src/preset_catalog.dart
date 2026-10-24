import 'dart:convert';

import 'models/voice.dart';
import 'preset_catalog_data.dart';

class VoicePreset {
  const VoicePreset({
    required this.id,
    required this.binding,
    required this.languages,
    this.gender = 'unknown',
    this.ageGroup = 'unknown',
    this.description = '',
    this.styles = const [],
    this.useCases = '',
    this.metadataGaps = const [],
    this.narratorReview = 'notReviewed',
    this.narratorCandidate = false,
    this.regions = const ['beijing', 'singapore'],
    this.sourceUrl = '',
    this.tagProvenance = const {},
  });
  final String id;
  final VoiceBinding binding;
  final List<String> languages;
  final String gender;
  final String ageGroup;
  final String description;
  final List<String> styles;
  final String useCases;
  final List<String> metadataGaps;
  final String narratorReview;
  final bool narratorCandidate;
  final List<String> regions;
  final String sourceUrl;
  final Map<String, String> tagProvenance;

  Map<String, Object?> toJson() => {
    'id': id,
    'binding': binding.toJson(),
    'languages': languages,
    'gender': gender,
    'ageGroup': ageGroup,
    'description': description,
    'styles': styles,
    'useCases': useCases,
    'metadataGaps': metadataGaps,
    'narratorReview': narratorReview,
    'narratorCandidate': narratorCandidate,
    'regions': regions,
    'sourceUrl': sourceUrl,
    'tagProvenance': tagProvenance,
  };
}

/// Documented MiniMax and Bailian presets, checked 2026-10-24.
/// Demographic tags include their source/inference provenance.
final List<VoicePreset> defaultVoiceCatalog = List.unmodifiable(
  (jsonDecode(presetCatalogJson) as List).map((item) {
    final json = item as Map;
    return VoicePreset(
      id: '${json['provider']}:${json['id']}',
      binding: VoiceBinding(
        provider: json['provider'] as String,
        model: json['model'] as String,
        voiceId: json['id'] as String,
      ),
      languages: (json['languages'] as List).cast<String>(),
      gender: json['gender'] as String,
      ageGroup: json['ageGroup'] as String,
      description: [
        json['providerLabel'],
        json['description'],
      ].whereType<String>().where((value) => value.isNotEmpty).join(': '),
      styles: (json['styles'] as List? ?? []).cast<String>(),
      useCases: json['useCases'] as String? ?? '',
      metadataGaps: (json['metadataGaps'] as List? ?? []).cast<String>(),
      narratorReview: json['narratorReview'] as String? ?? 'notReviewed',
      narratorCandidate: json['narratorCandidate'] as bool,
      regions: (json['regions'] as List).cast<String>(),
      sourceUrl: json['sourceUrl'] as String,
      tagProvenance: Map<String, String>.from(json['tagProvenance'] as Map),
    );
  }),
);

/// Shared bilingual vocabulary for provider descriptions and speaker profiles.
/// These broad delivery cues are preferences, not synthesis instructions.
List<String> voiceStyleTags(String description) {
  final text = description.toLowerCase();
  return [
    for (final entry in _styleTerms.entries)
      if (entry.value.any((term) => text.contains(term))) entry.key,
  ];
}

const _styleTerms = <String, List<String>>{
  'calm': [
    'calm',
    'composed',
    'steady',
    'serene',
    '沉稳',
    '稳重',
    '平稳',
    '冷静',
    '平静',
    '从容',
    '沉着',
  ],
  'gentle': [
    'gentle',
    'soft',
    'warm',
    'kind',
    '温柔',
    '柔和',
    '温暖',
    '亲切',
    '温和',
    '温润',
    '轻柔',
    '和蔼',
  ],
  'bright': [
    'bright',
    'energetic',
    'lively',
    'cheerful',
    'upbeat',
    '活泼',
    '明亮',
    '元气',
    '欢快',
    '热情',
  ],
  'deep': ['deep', 'low-pitched', 'resonant', 'magnetic', '低沉', '浑厚', '磁性'],
  'authoritative': [
    'authoritative',
    'commanding',
    'imposing',
    'bossy',
    '威严',
    '权威',
    '霸道',
    '威信',
    '威压',
    '强势',
    '严肃',
  ],
  'sweet': ['sweet', 'cute', '清甜', '甜美', '可爱', '娇'],
  'expressive': [
    'expressive',
    'dramatic',
    'emotional',
    'theatrical',
    '生动',
    '夸张',
    '戏剧',
    '情感丰富',
    '表现力',
  ],
  'humorous': [
    'humor',
    'humour',
    'comic',
    'funny',
    'playful',
    '幽默',
    '风趣',
    '诙谐',
    '俏皮',
  ],
  'clear': ['clear', 'crisp', 'articulate', '清晰', '清脆', '利落', '字正腔圆'],
};
