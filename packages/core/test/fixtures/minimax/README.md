# MiniMax contract fixture

`success.json` is a synthetic response derived from the official [synchronous TTS response schema](https://platform.minimax.io/docs/api-reference/speech-t2a-http), checked 2026-10-23. It is not recorded production traffic.

The hex audio was constructed independently with Python `struct`: mono 24,000 Hz signed 16-bit PCM, 240 samples alternating +1200/-1200 (10 ms). A three-byte `JUNK` chunk and RIFF padding precede `data`, exercising legal non-audio chunks. `usage_characters` is a documentation-shaped example count, distinct from source text length.

The contract tests also generate 1-, 60-, and 120-second WAV responses in memory for synthesis and voice-design previews. Mixed-case hex must preserve every PCM sample, and malformed hex must return a typed invalid-response error. The long responses cover the stack overflow caused by whole-string regular-expression validation.

Error cases in `minimax_contract_test.dart` use the official [error-code table](https://platform.minimax.io/docs/api-reference/errorcode). The deliberately inserted `fixture-secret` text ensures response messages and transport exceptions do not appear in user-visible errors.
