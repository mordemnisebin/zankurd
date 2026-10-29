import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/services/app_audio_contexts.dart';
import 'package:zankurd_mobile/src/services/audio_session_coordinator.dart';
import 'package:zankurd_mobile/src/services/question_audio_service.dart';

/// Efekt sesleri ve ses bağlamı (Opus–Astra kapışması U16 + U17,
/// 2026-10-29).
///
/// U16 kusuru: efekt oynatıcısı audioplayers'ın varsayılan bağlamıyla
/// (iOS `playback`, seçeneksiz) çalıyordu — doğru/yanlış/jeton sesleri
/// telefonun sessiz anahtarını yok sayıyor, kullanıcının çalan müziğini
/// kesiyordu. Kimse bağlamı sınamadığı için sessiz kaldı: simülatörde
/// sessiz anahtar yoktur, testlerde ses çalınmaz.
///
/// U17 kusuru: `win.mp3` `correct.mp3`'ün, `wildcard.mp3` `coin.mp3`'ün
/// bayt bayt kopyasıydı; geri sayım tıkı 2 saniyelik jeton sesini
/// çalıyordu. Dosya adları farklı olduğu için kod okuması bunu göstermedi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> globalCalls;
  setUp(() {
    globalCalls = [];
    AudioSessionCoordinator.instance = AudioSessionCoordinator(
      setGlobalContext: (ctx) async =>
          globalCalls.add('global:${ctx.iOS.category}'),
    );
  });

  group('U16 ses bağlamı', () {
    test('efekt: iOS ambient (sessiz anahtara uyar, dış sesle karışır), '
        'Android oyun + odak yok', () {
      final c = AppAudioContexts.effects;
      expect(c.iOS.category, AVAudioSessionCategory.ambient);
      expect(c.android.usageType, AndroidUsageType.game);
      expect(c.android.audioFocus, AndroidAudioFocus.none);
    });

    test(
      'telaffuz: iOS playback (sessizde de duyulur), Android geçici odak',
      () {
        final c = AppAudioContexts.speech;
        expect(c.iOS.category, AVAudioSessionCategory.playback);
        expect(c.android.usageType, AndroidUsageType.media);
        expect(c.android.audioFocus, AndroidAudioFocus.gainTransientMayDuck);
      },
    );

    test('efekt oynatıcısı HER çalıştan önce efekt bağlamını kurar', () async {
      SharedPreferences.setMockInitialValues({});
      final fake = _FakePlayer();
      final provider = await SoundProvider.load(player: fake);
      await provider.playCorrect();
      await provider.playTick();
      expect(fake.calls, [
        'ctx:${AVAudioSessionCategory.ambient}',
        'play:${SoundAssets.correct}',
        'ctx:${AVAudioSessionCategory.ambient}',
        'play:${SoundAssets.tick}',
      ]);
    });

    test('telaffuz oynatıcısı çalmadan önce kendi bağlamını kurar '
        '(efekt bağlamı sızmaz)', () async {
      final fake = _FakePlayer();
      final player = AudioplayersVerifiedQuestionAudioPlayer(player: fake);
      await player.play(
        VerifiedQuestionAudioClip(
          questionId: 'q1',
          source: 'assets/audio/x.mp3',
          location: VerifiedAudioLocation.asset,
          provenance: 'test',
          license: 'test',
        ),
      );
      final ctxIndex = fake.calls.indexOf(
        'ctx:${AVAudioSessionCategory.playback}',
      );
      expect(ctxIndex, isNonNegative);
      expect(ctxIndex, lessThan(fake.calls.indexOf('resume')));
      player.dispose();
    });
  });

  // Astra F1 incelemesi (2026-10-29, ÖNEMLİ): iOS oturumu GENEL olduğundan
  // "her oynatıcı kendi bağlamını kurar" yetmiyordu — telaffuz sürerken
  // efekt oturumu ambient'e çekip telaffuzu sessiz anahtarla susturuyordu;
  // ters sırada efektin bağlamı ile çalması arasına playback girebiliyordu.
  group('ses oturumu koordinatörü', () {
    test(
      '(a) telaffuz sürerken efekt çalınmaz, bağlam playback kalır',
      () async {
        final c = AudioSessionCoordinator.instance;
        final speech = _FakePlayer();
        final effect = _FakePlayer();
        await c.beginSpeech(speech, () async {});
        final played = await c.playEffect(
          effect,
          AssetSource(SoundAssets.correct),
        );
        expect(played, isFalse);
        expect(effect.calls, isEmpty, reason: 'efekt oturuma dokunmamalı');
        expect(speech.calls, ['ctx:${AVAudioSessionCategory.playback}']);
        expect(globalCalls, isEmpty);
        expect(c.speechActive, isTrue);
      },
    );

    test(
      "(b) telaffuz bitince oturum ambient'e döner, efekt yine çalar",
      () async {
        final c = AudioSessionCoordinator.instance;
        await c.beginSpeech(_FakePlayer(), () async {});
        await c.endSpeech();
        expect(globalCalls, ['global:${AVAudioSessionCategory.ambient}']);
        expect(c.speechActive, isFalse);
        final effect = _FakePlayer();
        expect(
          await c.playEffect(effect, AssetSource(SoundAssets.tick)),
          isTrue,
        );
        // Fazladan endSpeech sayacı eksiye düşürmez, oturumu tekrar çevirmez.
        await c.endSpeech();
        expect(globalCalls, hasLength(1));
      },
    );

    test('(c) eşzamanlı istekler sırayla; bağlam ile çalma arasına '
        'başka geçiş girmez', () async {
      final c = AudioSessionCoordinator.instance;
      final log = <String>[];
      final slow = _FakePlayer(log: log, tag: 'efekt', delay: true);
      final speech = _FakePlayer(log: log, tag: 'ses');
      final f1 = c.playEffect(slow, AssetSource(SoundAssets.correct));
      final f2 = c.beginSpeech(speech, () async => log.add('ses:start'));
      await Future.wait([f1, f2]);
      expect(log, [
        'efekt:ctx:${AVAudioSessionCategory.ambient}',
        'efekt:play',
        'ses:ctx:${AVAudioSessionCategory.playback}',
        'ses:start',
      ]);
    });

    test(
      "telaffuz oynatıcısı stop'ta ve doğal bitişte oturumu kapatır",
      () async {
        final c = AudioSessionCoordinator.instance;
        final fake = _FakePlayer();
        final player = AudioplayersVerifiedQuestionAudioPlayer(player: fake);
        final clip = VerifiedQuestionAudioClip(
          questionId: 'q1',
          source: 'assets/audio/x.mp3',
          location: VerifiedAudioLocation.asset,
          provenance: 'test',
          license: 'test',
        );
        await player.play(clip);
        expect(c.speechActive, isTrue);
        await player.stop();
        expect(c.speechActive, isFalse);
        expect(globalCalls, ['global:${AVAudioSessionCategory.ambient}']);
        await player.play(clip);
        expect(c.speechActive, isTrue);
        fake.emit(PlayerState.completed);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(c.speechActive, isFalse);
        player.dispose();
      },
    );
  });

  group('U17 ses dosyaları', () {
    test('her efekt ayrı bir dosya; içerikleri birbirinin kopyası değil', () {
      final digests = <String, String>{};
      for (final asset in SoundAssets.all) {
        final file = File('assets/$asset');
        expect(file.existsSync(), isTrue, reason: '$asset yok');
        final digest = md5.convert(file.readAsBytesSync()).toString();
        final twin = digests[digest];
        expect(twin, isNull, reason: '$asset, $twin ile aynı içerik');
        digests[digest] = asset;
      }
    });

    test('geri sayım tıkı kısa (≤150 ms): dosya küçük', () {
      // 128 kbps MP3'te 150 ms ≈ 2,4 KB (+ başlık). 2 saniyelik jeton sesi
      // 12 KB'tı; sınır bunu kesin ayırır.
      final bytes = File('assets/${SoundAssets.tick}').lengthSync();
      expect(bytes, lessThan(4000));
    });

    test('kaynak belgesi her dosyayı anar', () {
      final doc = File('assets/sounds/KAYNAK.md').readAsStringSync();
      for (final asset in SoundAssets.all) {
        expect(doc, contains(asset.split('/').last));
      }
    });
  });
}

class _FakePlayer implements AudioPlayer {
  _FakePlayer({List<String>? log, this.tag, this.delay = false}) : _log = log;

  final calls = <String>[];
  final List<String>? _log;
  final String? tag;
  final bool delay;
  final _states = StreamController<PlayerState>.broadcast();

  void emit(PlayerState s) => _states.add(s);

  void _rec(String e) {
    calls.add(e);
    if (tag != null) _log?.add('$tag:${e.startsWith('play:') ? 'play' : e}');
  }

  @override
  Future<void> setAudioContext(AudioContext ctx) async {
    _rec('ctx:${ctx.iOS.category}');
    // Bağlam ile çalma arasına başka bir istek girebilsin diye bekler.
    if (delay) await Future<void>.delayed(const Duration(milliseconds: 5));
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    _rec('play:${source is AssetSource ? source.path : source}');
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> setSource(Source source) async => calls.add('source');

  @override
  Future<void> setPlaybackRate(double playbackRate) async => calls.add('rate');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Stream<PlayerState> get onPlayerStateChanged => _states.stream;

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
