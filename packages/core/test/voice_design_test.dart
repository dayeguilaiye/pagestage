import 'dart:io';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late LocalStore store;
  late Book book;
  late FakeDesignTts fake;
  late VoiceDesign design;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('voice-design-');
    store = LocalStore('${directory.path}/store.sqlite');
    book = Book(
      id: 'book',
      title: 'Book',
      language: 'en',
      sourcePath: '',
      chapters: [const Chapter(number: 1, title: 'One', text: 'Hello.')],
    );
    await CastRepository(store).save(
      Cast(
        bookId: book.id,
        profiledThrough: 1,
        speakers: [Speaker(id: 'hero', name: 'Hero')],
      ),
    );
    fake = FakeDesignTts();
    design = VoiceDesign(store, adapters: {'minimax': fake});
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'generates three distinct persisted candidates with encoded preview files',
    () async {
      final candidates = await design.generate(
        book,
        'hero',
        provider: 'minimax',
        model: 'speech-2.8-hd',
        description: 'A warm, mature voice.',
        previewText: 'Hello, our story is about to begin.',
        outputDirectory: directory.path,
      );
      expect(candidates, hasLength(3));
      expect(
        candidates.map((c) => c.voice.binding.voiceId).toSet(),
        hasLength(3),
      );
      expect(fake.synthesis, isEmpty);
      for (final candidate in candidates) {
        expect(candidate.voice.description, 'A warm, mature voice.');
        expect(candidate.voice.binding.designed, isTrue);
        expect(candidate.voice.samplePath, endsWith('.mp3'));
        expect(await File(candidate.voice.samplePath!).readAsBytes(), [
          73,
          68,
          51,
          4,
          0,
          0,
          0,
          0,
          0,
          0,
          255,
          251,
          144,
          0,
        ]);
      }
      final reopened = VoiceDesign(store, adapters: {});
      expect(
        (await reopened.list(
          book.id,
          speakerId: 'hero',
        )).map((c) => c.id).toSet(),
        candidates.map((c) => c.id).toSet(),
      );
      expect((await Casting(store).getCasting(book.id)).voices, isEmpty);
    },
  );

  test(
    'selection activates only the chosen candidate before replacing a durable voice',
    () async {
      final old = await Casting(store).selectVoice(
        book,
        'hero',
        const Voice(
          id: 'old',
          bookId: 'book',
          description: 'Previous voice',
          binding: VoiceBinding(
            provider: 'minimax',
            model: 'speech-2.8-hd',
            voiceId: 'preset',
          ),
        ),
      );
      final candidates = await design.generate(
        book,
        'hero',
        provider: 'minimax',
        model: 'speech-2.8-hd',
        description: 'A warm, mature voice.',
        previewText: 'Hello, our story is about to begin.',
        outputDirectory: directory.path,
      );
      fake.failSynthesis = true;
      await expectLater(
        design.select(book, 'hero', candidates[1].id),
        throwsA(isA<ProviderException>()),
      );
      expect(
        (await Casting(store).getCasting(book.id)).voices['hero']!.id,
        old.id,
      );
      fake.failSynthesis = false;
      final selected = await design.select(book, 'hero', candidates[1].id);
      expect(selected.id, candidates[1].id);
      expect(selected.manuallySelected, isTrue);
      expect(selected.samplePath, endsWith('.selected.wav'));
      expect(
        PcmAudio.fromWav(
          await File(selected.samplePath!).readAsBytes(),
        ).samples,
        [12, 34, 56],
      );
      final bindings = await Casting(
        store,
      ).prepareChapterBindings(book, 1, speakerIds: ['hero']);
      expect(bindings['hero']!.voiceId, 'designed-2');
      await Synthesizer(adapters: {'minimax': fake}).synthesize(
        chapter: book.chapter(1),
        language: book.language,
        voices: bindings,
        outputPath: '${directory.path}/chapter.wav',
        script: Script(
          bookId: book.id,
          chapterNumber: 1,
          sourceTextHash: book.chapter(1).textHash,
          model: 'fake-director',
          promptVersion: 'v1',
          lines: [
            const ScriptLine(
              start: 0,
              end: 6,
              direction: Direction(speakerId: 'hero'),
            ),
          ],
        ),
      );
      expect(fake.synthesis.last.text, 'Hello.');

      expect(
        fake.synthesis.every(
          (request) => request.binding.voiceId == 'designed-2',
        ),
        isTrue,
      );
      final afterReopen = await Casting(store).getVoice(selected.id);
      expect(afterReopen.description, 'A warm, mature voice.');
      expect(afterReopen.binding.model, 'speech-2.8-hd');
    },
  );
  test(
    'a later design failure keeps completed candidates and the current choice',
    () async {
      fake.failDesignAt = 3;
      await expectLater(
        design.generate(
          book,
          'hero',
          provider: 'minimax',
          model: 'speech-2.8-hd',
          description: 'A warm voice.',
          previewText: 'Hello, our story is about to begin.',
          outputDirectory: directory.path,
        ),
        throwsA(isA<ProviderException>()),
      );
      final saved = await design.list(book.id);
      expect(saved, hasLength(2));
      expect(await File(saved.first.voice.samplePath!).exists(), isTrue);
      expect((await Casting(store).getCasting(book.id)).voices, isEmpty);
      expect(fake.synthesis, isEmpty);
    },
  );

  test(
    'candidate generation rejects fewer than three before using the provider',
    () async {
      await expectLater(
        design.generate(
          book,
          'hero',
          provider: 'minimax',
          model: 'speech-2.8-hd',
          description: 'A warm voice.',
          count: 2,
          previewText: 'Hello, our story is about to begin.',
          outputDirectory: directory.path,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(fake.designs, isEmpty);
    },
  );

  test('a candidate cannot replace a different speaker voice', () async {
    final candidates = await design.generate(
      book,
      'hero',
      provider: 'minimax',
      model: 'speech-2.8-hd',
      description: 'A warm voice.',
      previewText: 'Hello, our story is about to begin.',
      outputDirectory: directory.path,
    );
    final cast = await CastRepository(store).get(book.id);
    await CastRepository(store).save(
      cast.copyWith(
        speakers: [
          ...cast.speakers,
          Speaker(id: 'other', name: 'Other'),
        ],
      ),
    );
    await expectLater(
      design.select(book, 'other', candidates.first.id),
      throwsStateError,
    );
    expect(fake.synthesis, isEmpty);
  });
  test(
    'Bailian selection keeps the existing WAV preview without extra synthesis',
    () async {
      final bailian = FakeDesignTts('bailian');
      final service = VoiceDesign(store, adapters: {'bailian': bailian});
      final candidates = await service.generate(
        book,
        'hero',
        provider: 'bailian',
        model: 'qwen-audio-3.1-tts-plus',
        description: 'Warm and clear.',
        previewText: 'Hello, our story is about to begin.',
        outputDirectory: directory.path,
      );
      final selected = await service.select(book, 'hero', candidates.first.id);
      expect(selected.samplePath, candidates.first.voice.samplePath);
      expect(selected.binding.model, 'qwen-audio-3.1-tts-plus');
      expect(selected.binding.designed, isTrue);
      expect(bailian.synthesis, isEmpty);
      expect(
        (await Casting(store).prepareChapterBindings(book, 1))['hero']!.voiceId,
        'designed-1',
      );
    },
  );
  test(
    'duplicate provider bindings cannot masquerade as distinct candidates',
    () async {
      fake.repeatedVoiceId = 'same-voice';
      await expectLater(
        design.generate(
          book,
          'hero',
          provider: 'minimax',
          model: 'speech-2.8-hd',
          description: 'Warm voice.',
          previewText: 'Hello, our story is about to begin.',
          outputDirectory: directory.path,
        ),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidResponse,
          ),
        ),
      );
      expect(await design.list(book.id), hasLength(1));
    },
  );
}

class FakeDesignTts implements TtsAdapter, VoiceDesignAdapter {
  @override
  final String provider;
  FakeDesignTts([this.provider = 'minimax']);
  final designs = <VoiceDesignRequest>[];
  final synthesis = <TtsRequest>[];
  bool failSynthesis = false;
  int? failDesignAt;
  String? repeatedVoiceId;
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) =>
      const TtsCapabilities(supportsPronunciation: true, maxCharacters: 9999);
  @override
  Future<DesignedVoice> design(VoiceDesignRequest request) async {
    designs.add(request);
    if (designs.length == failDesignAt) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.rateLimited,
      );
    }
    return DesignedVoice(
      binding: VoiceBinding(
        provider: provider,
        model: request.model,
        voiceId: repeatedVoiceId ?? 'designed-${designs.length}',
        designed: true,
      ),
      preview: VoicePreview.detect(
        provider == 'bailian'
            ? PcmAudio(samples: Int16List.fromList([1, 2, 3])).toWav()
            : Uint8List.fromList([
                73,
                68,
                51,
                4,
                0,
                0,
                0,
                0,
                0,
                0,
                255,
                251,
                144,
                0,
              ]),
      ),
    );
  }

  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    synthesis.add(request);
    if (failSynthesis) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.unavailable,
      );
    }
    return TtsAudio(
      audio: PcmAudio(samples: Int16List.fromList([12, 34, 56])),
      characters: request.text.length,
    );
  }
}
