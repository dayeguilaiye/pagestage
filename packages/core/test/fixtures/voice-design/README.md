# Voice design HTTP fixtures

The inline fixtures in `../../voice_design_contract_test.dart` are synthetic fixtures derived from official documentation, not recorded production traffic. WAV uses deterministic short PCM generated in the test; MP3 bytes represent an ID3/MPEG container signature for byte-preservation tests, not an audible quality sample. No provider key or real voice was used.

Checked 2026-10-23:

- MiniMax: https://platform.minimax.io/docs/api-reference/voice-design-design
- Bailian request/response: https://help.aliyun.com/en/model-studio/voice-design-api-references
- Bailian limits, Beijing models and exact target-model binding: https://help.aliyun.com/en/model-studio/voice-design-user-guide

The tests establish request shape, encoded-preview preservation, target-model handling, regional constraints and safe errors. Real-key synthesis, voice activation lifetime, audible candidate quality and model/account availability remain manual acceptance work.
