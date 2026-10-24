import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';

import 'support/widget_test_helpers.dart';

/// Günün turunun TEK gün sınırı: Europe/Istanbul (UTC+3 sabit).
///
/// ## Kusur
///
/// Sıralama sunucuda İstanbul gününe (`app_today()`) yazılıyordu ama soru
/// tohumu UTC günüydü, "bugün bitti" bayrağı da cihazın yerel günü. İstanbul
/// 00:00–03:00 arası oynayan oyuncu DÜNÜN soru setini oynayıp BUGÜNÜN
/// sıralamasına giriyordu; yurt dışındaki oyuncu için bayrak başka saatte
/// sıfırlanıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Üç sınır öğlen saatlerinde birbirine eşit görünür; yalnız 21:00–24:00 UTC
/// aralığında ayrışır. Hiçbir hata atmaz, yalnız set ve sıra yanlış güne düşer.
///
/// ## Kural
///
/// Tohum, "bugün bitti" bayrağı, geri sayım ve sunucu günü aynı yardımcıdan
/// ([contestDayKey]) gelir.
void main() {
  // İstanbul 25 Ekim 01:30 — UTC'de hâlâ 24 Ekim.
  final geceYarisiSonrasi = DateTime.utc(2026, 10, 24, 22, 30);
  final ogle = DateTime.utc(2026, 10, 24, 12);

  test('gün anahtarı İstanbul gününü verir', () {
    expect(contestDayKey(geceYarisiSonrasi), DateTime.utc(2026, 10, 25));
    expect(contestDayKey(ogle), DateTime.utc(2026, 10, 24));
    expect(
      contestDayKey(DateTime.utc(2026, 10, 24, 20, 59)),
      DateTime.utc(2026, 10, 24),
    );
    expect(
      contestDayKey(DateTime.utc(2026, 10, 24, 21)),
      DateTime.utc(2026, 10, 25),
    );
    expect(contestDayString(geceYarisiSonrasi), '2026-10-25');
  });

  test('geri sayım ve gün anahtarı aynı sınırı paylaşır', () {
    final reset = nextContestResetAt(geceYarisiSonrasi);
    expect(contestDayKey(reset), DateTime.utc(2026, 10, 26));
    expect(
      contestDayKey(reset.subtract(const Duration(seconds: 1))),
      DateTime.utc(2026, 10, 25),
    );
  });

  test('soru tohumu İstanbul gününü izler (25 Ekim 01:30)', () {
    expect(
      MockZanKurdRepository.dailySeed(geceYarisiSonrasi),
      20261025,
      reason: 'UTC günü 24 olsa da İstanbul günü 25',
    );
    expect(MockZanKurdRepository.dailySeed(ogle), 20261024);
  });

  test('"bugün bitti" bayrağı İstanbul gününe göre', () async {
    SharedPreferences.setMockInitialValues({});
    freshMockRepository();
    final store = await AchievementStore.load();
    // Dünün (24 Ekim) setini öğlen bitirdi.
    await store.recordQuizResult(
      category: 'Tevlihev',
      totalQuestions: 10,
      correctCount: 5,
      bestStreak: 1,
      dailyStreak: 0,
      userScore: 0,
      dailyQuiz: true,
      now: ogle,
    );
    expect(store.dailyQuizDoneOn(ogle), isTrue);
    // İstanbul'da gece yarısı geçti: yeni gün, bayrak sıfır.
    expect(store.dailyQuizDoneOn(geceYarisiSonrasi), isFalse);

    // 01:30'da oynayınca YENİ gün sayılır ve sayaç artar.
    await store.recordQuizResult(
      category: 'Tevlihev',
      totalQuestions: 10,
      correctCount: 5,
      bestStreak: 1,
      dailyStreak: 0,
      userScore: 0,
      dailyQuiz: true,
      now: geceYarisiSonrasi,
    );
    expect(store.dailyQuizDoneOn(geceYarisiSonrasi), isTrue);
    expect(store.dailyQuizCompletions, 2);
  });
}
