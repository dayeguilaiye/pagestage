# Edge contract fixtures

The local WebSocket server in `edge_contract_test.dart` sends constructed Edge
Read Aloud messages, based on
[tts-api's Go client](https://github.com/dayeguilaiye/tts-api/blob/main/internal/edge/client.go).
Tests never contact Microsoft or another speech provider.

`tone.mp3` is the synthetic one-second, 44.1 kHz mono sine fixture from
[audio_decode 1.3.5](https://github.com/Yusufihsangorgel/audio_decode), distributed
under the adjacent MIT license. It verifies real MP3 decoding and conversion to
the pipeline's 24 kHz PCM. Edge requests explicitly select 24 kHz mono MP3.
This tone is not a recording of the Edge service or a speech quality test.
