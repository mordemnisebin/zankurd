import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/services/app_audio_contexts.dart';
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
  final calls = <String>[];

  @override
  Future<void> setAudioContext(AudioContext ctx) async {
    calls.add('ctx:${ctx.iOS.category}');
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
    calls.add('play:${(source as AssetSource).path}');
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
  Stream<PlayerState> get onPlayerStateChanged => const Stream.empty();

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
