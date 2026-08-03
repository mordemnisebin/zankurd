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

const _phase = String.fromEnvironment('ZK_PHASE', defaultValue: 'setup');
const _freezeKey = String.fromEnvironment(
  'ZK_FREEZE_KEY',
  defaultValue: 'os-resilience-fixed-key',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseZanKurdRepository repo;

  setUpAll(() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
    repo = SupabaseZanKurdRepository(Supabase.instance.client);
    await repo.signInAnonymously();
    await repo.ensureProfile();
  });

  testWidgets('Senaryo: kimlik surec sinirini asar', (tester) async {
    final id = repo.currentUserId;
    expect(id, isNotNull);
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
      // Tek çekim: en fazla 50 coin gitmiş olmalı.
      expect(
        before - after,
        lessThanOrEqualTo(50),
        reason: 'iki kez cekilmis: $before -> $after',
      );
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
