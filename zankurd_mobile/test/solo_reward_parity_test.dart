import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/coin_calculator.dart';

/// Solo ödül formülü iki yerde yaşıyor; ayrışmamalı.
///
/// ## Niçin iki yerde
///
/// Üretimde miktarı YALNIZ sunucu belirler (`claim_solo_reward` RPC'si);
/// istemciden `coin_transactions`'a yazma yolu yoktur. Ama çevrimdışı/mock
/// yolunun da aynı davranışı göstermesi gerekir, yoksa Supabase'siz oynanan
/// ekonomi üretimdekiyle ilgisiz olur ve "mock'ta çalışıyordu" diyen bir
/// hata sınıfı doğar.
///
/// Bu yüzden formül iki kez yazılıdır — bir kez SQL'de, bir kez Dart'ta — ve
/// bu bekçi ikisinin aynı kaldığını sabitler. Metinden okumak kırılgan
/// görünebilir; alternatifi ikisinin sessizce ayrışmasıdır ve sessiz ayrışma
/// bu depoda tekrar tekrar yaşanmış bir kusur sınıfıdır (bkz.
/// `all_banks_quality_test.dart` başlığı).
void main() {
  const migration = 'supabase/2026-08-10_solo_round_reward.sql';

  late String sql;

  setUpAll(() {
    final file = File(migration);
    expect(
      file.existsSync(),
      isTrue,
      reason:
          '$migration bulunamadı; göç silindiyse istemci yolu da '
          'kaldırılmalı, yoksa var olmayan bir RPC çağrılır',
    );
    sql = file.readAsStringSync();
  });

  test('günlük tavan SQL ile Dart arasında aynı', () {
    expect(
      sql,
      contains(
        'v_daily_cap constant integer := ${CoinCalculator.soloDailyCap}',
      ),
      reason:
          'SQL tavanı ile `CoinCalculator.soloDailyCap` '
          '(${CoinCalculator.soloDailyCap}) ayrışmış',
    );
  });

  test('ödül formülü SQL ile Dart arasında aynı', () {
    // SQL: least(4 + p_correct_count + p_best_streak, v_remaining)
    expect(
      sql,
      contains('4 + p_correct_count + p_best_streak'),
      reason:
          'SQL formülü değişmiş; `CoinCalculator.soloAward` ile birlikte '
          'güncellenmeli',
    );
    // Dart tarafı aynı formülü vermeli.
    expect(CoinCalculator.soloAward(correctCount: 0, bestStreak: 0), 4);
    expect(CoinCalculator.soloAward(correctCount: 8, bestStreak: 5), 17);
    expect(CoinCalculator.soloAward(correctCount: 10, bestStreak: 10), 24);
  });

  test('kusursuz tur tavanı tek başına doldurmuyor', () {
    // Tasarım kararı: tavana bir turda değil birkaç turda varılmalı, yoksa
    // "günde bir tur" oynayan biri için ödül döngüsü yine tek atışa döner.
    final perfectRound = CoinCalculator.soloAward(
      correctCount: 10,
      bestStreak: 10,
    );
    expect(
      perfectRound,
      lessThan(CoinCalculator.soloDailyCap),
      reason: 'Tek tur tavanı dolduruyorsa ikinci turun ödülü sıfır olur',
    );
    expect(
      CoinCalculator.soloDailyCap / perfectRound,
      lessThanOrEqualTo(3.0),
      reason:
          'Tavana ulaşmak üç turdan fazla sürerse günlük hedef ulaşılmaz '
          'hissettirir',
    );
  });

  test('SQL doğrulanamayan girdiyi reddediyor', () {
    // Talep doğrulanamıyor ama saçma değerler defter'e girmemeli.
    for (final guard in [
      'p_correct_count > p_total_questions',
      'p_best_streak > p_total_questions',
      'p_total_questions > v_max_questions',
      'p_correct_count < 0',
    ]) {
      expect(sql, contains(guard), reason: 'Girdi kontrolü kaybolmuş: $guard');
    }
  });

  test('SQL yetkiyi authenticated ile sınırlıyor', () {
    expect(sql, contains('revoke all on function public.claim_solo_reward'));
    expect(sql, contains('grant execute on function public.claim_solo_reward'));
    expect(
      sql,
      contains('security definer'),
      reason:
          'SECURITY DEFINER olmadan RLS yüzünden defter yazılamaz; kaldıysa '
          'ödül sessizce hiç verilmez',
    );
  });

  test('SQL eşzamanlı talepte tavanı kilitle koruyor', () {
    expect(
      sql,
      contains('from public.profiles where id = v_user_id for update'),
      reason:
          'Kilit kalkarsa iki eşzamanlı talep de "bugün 0 kazandım" okuyup '
          'ikisi de yazar ve tavan aşılır',
    );
  });
}
