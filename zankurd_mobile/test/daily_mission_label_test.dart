import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';

/// Günlük görev etiketi kategoriyi arayüz diline çevirmeli.
///
/// 2026-07-27: ana ekranda görev "Cografya kategorisinde oyna" yazıyordu.
/// İki kusur birden vardı ve ikisi de aynı satırdan geliyordu: kategori
/// adı ham anahtardı (bankada ASCII tutuluyor, bu yüzden 'ğ' yok) ve
/// anahtar Kurmancî — Türkçe arayüzde "Muzîk", "Dîrok", "Ziman"
/// görünüyordu.
///
/// Kurmancî etiketi zaten `CategoryNames.localized` çağırıyordu; unutulan
/// yalnız Türkçe koldu. Bu yüzden test iki kolu birden ölçer: tek kolu
/// sınayan bir bekçi tam da kaçırılan tarafı kaçırırdı.
void main() {
  final mission = DailyMission(
    type: MissionType.playCategory,
    target: 1,
    coinReward: 25,
    category: 'Cografya',
  );

  test('Türkçe etikette kategori Türkçe ve doğru yazımla görünür', () {
    expect(mission.labelTr, 'Coğrafya kategorisinde oyna');
  });

  test('Kurmancî etikette kategori Kurmancî görünür', () {
    expect(mission.labelKu, contains('Erdnîgarî'));
  });

  test('sunucu anahtarı ASCII slug olarak kalır', () {
    // Etiket çevrilirken anahtarın da çevrilmesi ödül çağrısını bozardı.
    expect(mission.missionKey, 'playCategory:cografya');
  });
}
