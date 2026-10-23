# Pronunciation and loudness fixtures

`polyphonic-zh.json` is an original synthetic sentence with chosen proper-name readings: 长乐 (chang2 le4), 单明 (shan4 ming2), 重庆 (chong2 qing4), 曾乐 (zeng1 le4). It is intended for both providers' later listening checks. The current run uses no real provider key or recorded live traffic.

`pronunciation_contract_test.dart` derives request shapes from the official [MiniMax synchronous API](https://platform.minimax.io/docs/api-reference/speech-t2a-http), [Bailian HTTP API](https://www.alibabacloud.com/help/en/model-studio/qwen-audio-tts-http-api), and [SSML phoneme rules](https://www.alibabacloud.com/help/en/model-studio/ssml-latex-user-guide), checked 2026-10-23. Responses reuse the independently generated MiniMax WAV fixture or generated silent PCM; response URLs are inert example domains. These tests verify serialization and parsing, not voice quality or pronunciation correctness.

`loudness_synthesis_test.dart` feeds public Synthesizer fake TTS adapters with mathematical PCM16 sine waves at 24 kHz. Independent expected values:

- [ITU-R BS.1770-5](https://www.itu.int/dms_pubrec/itu-r/rec/bs/R-REC-BS.1770-5-202311-I!!PDF-E.pdf): 997 Hz mono sine with full-scale peak measures -3.01 LKFS; 0.1 peak amplitude gives about -23.01. The test allows 0.1 LU for the sample-rate-adjusted filter and quantization.
- 100/1000/4000 Hz, 0.1 peak: -24.79155/-22.97774/-19.67392 LUFS, calculated independently from the complex frequency response of the two biquads. These literal expectations are not outputs from the time-domain meter being tested.
- [EBU Tech 3341](https://tech.ebu.ch/docs/tech3341.pdf) relative-gate test shape: 10/60/10 seconds, sine peak levels -36/-23/-36 dBFS. The mono adaptation has an expected integrated level of about -26.01 LUFS, with 0.2 LU tolerance for boundary blocks.
- -1 dBFS sample ceiling: integer PCM16 absolute peak no greater than 29204. Quiet tones, zero samples, a near-full-scale impulse and two provider chunks exercise boost limits, silence, headroom and one gain per logical utterance.

These are synthetic numerical checks of the documented implementation. They do not establish EBU certification, true-peak compliance or perceived equality between real voices.
