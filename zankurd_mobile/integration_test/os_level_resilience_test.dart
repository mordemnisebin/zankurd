// Gerçek OS olaylarına karşı dayanıklılık (integration_test).
//
// Bu dosya ötekilerden bir noktada ayrılır: süreç ölümünü TAKLİT ETMEZ.
// `ZK_PHASE=setup` koşumu biter, işletim sistemi süreci gerçekten kapatır
// (ve dışarıdan `adb shell am force-stop` uygulanır), sonra `ZK_PHASE=resume`
// AYRI BİR SÜREÇ olarak açılır. Aradaki sınır gerçektir; bellek içi hiçbir
// şey taşınmaz, yalnız diskte ve sunucuda kalan taşınır.
//
// Çalıştırma:
//   ... --dart-define=ZK_PHASE=setup
//   adb shell am force-stop com.zankurd.app
//   ... --dart-define=ZK_PHASE=resume --dart-define=ZK_ROOM_ID=<id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';

import 'support/local_backend_guard.dart';

const _phase = String.fromEnvironment('ZK_PHASE', defaultValue: 'setup');
// Koşu başına BENZERSİZ, iki faz arasında AYNI anahtar (ör. zaman damgası):
// sabit varsayılan, bağımsız koşuları birbirine bağlayıp ikinci koşuyu
// "zaten çekildi" diye sahte-yeşil yapardı.
const _freezeKey = String.fromEnvironment('ZK_FREEZE_KEY');

// Setup fazının yazdığı UID; resume fazında verilirse kimliğin süreç
// sınırından sağ çıktığı doğrulanır.
const _expectUserId = String.fromEnvironment('ZK_EXPECT_USER_ID');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseZanKurdRepository repo;

  setUpAll(() async {
    requireLocalBackend();
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
    repo = SupabaseZanKurdRepository(Supabase.instance.client);
    // Anonim hesap YALNIZ oturum yoksa açılır: `signInAnonymously` her çağrıda
    // yeni kullanıcı üretir; resume fazında koşulsuz çağırmak "aynı hesap
    // süreç sınırından sağ çıktı" iddiasını sınanamaz kılıyordu. Resume'da
    // kalıcı oturum diskten yüklenmiş OLMALI.
    if (repo.currentUserId == null) {
      if (_phase == 'resume') {
        fail(
          'resume: kalıcı oturum diskten yüklenemedi (yeni anonim hesap açılmadı).',
        );
      }
      await repo.signInAnonymously();
    }
    await repo.ensureProfile();
  });

  testWidgets('Senaryo: kimlik surec sinirini asar', (tester) async {
    final id = repo.currentUserId;
    expect(id, isNotNull);
    if (_phase == 'resume') {
      expect(
        _expectUserId,
        isNotEmpty,
        reason: 'resume için --dart-define=ZK_EXPECT_USER_ID=<setup UID>',
      );
      expect(id, _expectUserId, reason: 'kimlik süreç sınırında değişti');
    }
    // Aynı cihazda ikinci süreç AYNI kullanıcı olmalı; olmazsa "resume"
    // aslında yeni bir kullanıcıyı test ediyor demektir.
    // ignore: avoid_print
    print('ZK_PHASE=$_phase ZK_USER_ID=$id');
  });

  // Streak-freeze idempotency'sini CİHAZ akışıyla ölç.
  //
  // Aynı değişmez anahtarla iki kez çağrılır; ikinci çağrı yeni bir coin
  // hareketi ÜRETMEMELİ. Anahtar süreçler arasında da sabit olduğu için
  // `resume` fazı bunu üçüncü kez, gerçek bir süreç sınırının ötesinden
  // dener.
  testWidgets(
    'Senaryo: ayni anahtarla dondurma yalniz bir kez ceker',
    (tester) async {
      expect(
        _freezeKey,
        isNotEmpty,
        reason: 'koşuya özgü --dart-define=ZK_FREEZE_KEY=<benzersiz> ver',
      );
      final before = await repo.loadCoinBalance();
      // ignore: avoid_print
      print('ZK_BALANCE_BEFORE=$before');

      final first = await repo.spendStreakFreeze(idempotencyKey: _freezeKey);
      final second = await repo.spendStreakFreeze(idempotencyKey: _freezeKey);
      final after = await repo.loadCoinBalance();

      // ignore: avoid_print
      print(
        'ZK_FREEZE=${first.outcome.name}/${second.outcome.name} '
        'idempotent=${first.idempotent} ZK_BALANCE_AFTER=$after',
      );

      if (first.outcome == StreakFreezeChargeOutcome.insufficient) {
        // Bakiye yetmiyorsa idempotency ölçülemez; PASS verme.
        fail('bakiye yetersiz ($before) — test kullanicisina coin verilmeli');
      }

      expect(first.idempotent, isTrue, reason: 'idempotent RPC bekleniyordu');
      expect(
        second.outcome,
        StreakFreezeChargeOutcome.alreadyCharged,
        reason: 'ikinci cagri yeniden cekmemeli',
      );
      // Setup: TAM bir çekim (50). Resume: sıfır ek çekim.
      expect(
        before - after,
        _phase == 'resume' ? 0 : 50,
        reason:
            '$_phase fazında beklenmeyen bakiye değişimi: $before -> $after',
      );
      if (_phase != 'resume') {
        expect(first.outcome, StreakFreezeChargeOutcome.charged);
      }
      if (_phase == 'resume') {
        // Süreç sınırının ötesinden gelen üçüncü deneme de çekmemeli.
        expect(
          first.outcome,
          StreakFreezeChargeOutcome.alreadyCharged,
          reason: 'onceki surecte cekilmisti; bu surecte yine cekmemeli',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
