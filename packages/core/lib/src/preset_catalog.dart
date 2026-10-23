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
    'narratorCandidate': narratorCandidate,
    'regions': regions,
    'sourceUrl': sourceUrl,
    'tagProvenance': tagProvenance,
  };
}

/// Documented MiniMax and Bailian presets, checked 2026-10-23.
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
      description: '${json['providerLabel']}: ${json['description']}',
      narratorCandidate: json['narratorCandidate'] as bool,
      regions: (json['regions'] as List).cast<String>(),
      sourceUrl: json['sourceUrl'] as String,
      tagProvenance: Map<String, String>.from(json['tagProvenance'] as Map),
    );
  }),
);
