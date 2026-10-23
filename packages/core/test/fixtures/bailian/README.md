# Bailian contract fixtures

The JSON responses in `bailian_contract_test.dart` are synthetic examples derived from the official [Qwen-Audio-TTS HTTP API](https://www.alibabacloud.com/help/en/model-studio/qwen-audio-tts-http-api) and [error reference](https://help.aliyun.com/en/model-studio/error-code), checked 2026-10-23. They are not recorded traffic.

The fake signed HTTPS download returns the independent 10 ms PCM/WAV fixture described in `../minimax/README.md`. The download request must contain no provider Authorization header. The deliberately included `fixture-secret` response messages must remain absent from emitted errors.
