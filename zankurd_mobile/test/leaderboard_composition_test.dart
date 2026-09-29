// 2026-09-29 doğallık (K9): podyumun üçlü kalıbı kalktı; tek liste.
// 2026-09-29 Şahnê: kendi sıran artık `_page(pinned: …)` ile sayfanın
// altına sabitlenir; kaynak bekçisi o satırı arar.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Liderlik tablosunun kullanıcı sayısına göre davranışı.
///
/// Az veriyle en kolay bozulan yer eksik yerleri doldurmaktır: sahte
/// kullanıcı ya da boş siluet çizmek, oyuncuya var olmayan bir rekabet
/// göstermek olur.
///
/// Bu bekçiler kaynak sözleşmesine bakar: yalnız var olan oyuncular
/// çizilir ve kullanıcı listede yokken kendi sırası ayrı bir yüzeyle
/// sabitlenir.
///
/// 2026-09-29 doğallık (K9): podyumun üçlü kalıbı (slotlar, tek kişinin
/// ortalanması) kalktı; bekçi artık tek listeyi sorar.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/src/screens/leaderboard_screen.dart').readAsStringSync();
  });

  test('bütün sıralama tek listede; üçlü kalıp yok', () {
    // 2026-09-29 doğallık (K9): podyum kalktı. Liste yalnız var olan
    // oyuncuları çizer; eksik yer için boş siluet ya da sahte oyuncu yok.
    expect(source, contains('for (final e in entries)'));
    expect(source, isNot(contains('class _Podium')));
    expect(source, isNot(contains('podium-slot')));
  });

  test('sahte sıralama veya yer tutucu kullanıcı yok', () {
    for (final fake in const [
      'placeholder',
      'dummyEntry',
      'fakeEntry',
      'emptySlot',
    ]) {
      expect(
        source.toLowerCase(),
        isNot(contains(fake.toLowerCase())),
        reason: 'liderlik tablosu eksik yeri uydurma veriyle doldurmamalı',
      );
    }
  });

  test('kullanıcı listede yoksa kendi sırası sabitlenir', () {
    // Liderlik yalnız ilk 10'u getiriyor; oyuncu listede yoksa kendi
    // sırasını hiç göremiyordu.
    expect(source, contains('_PinnedMyRank'));
    expect(
      source,
      contains('pinned: _myRank(entries) == null ? _buildMyRankRow(ku) : null'),
    );
  });

  test('boş, hata ve yükleniyor durumları ayrı ayrı ele alınır', () {
    expect(source, contains('AppEmptyState'));
    expect(source, contains('AppErrorState'));
    // Yükleniyor: liste geometrisini bozmayan ince bir gösterge.
    expect(source, contains('LinearProgressIndicator'));
  });

  test('kullanıcının kendi satırı vurgulanır', () {
    expect(source, contains('highlight: true'));
  });
}
