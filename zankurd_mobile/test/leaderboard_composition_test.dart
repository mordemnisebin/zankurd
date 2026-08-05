import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Liderlik tablosunun kullanıcı sayısına göre davranışı.
///
/// Podyum üç kişilik bir kalıptır ve az veriyle en kolay bozulan yer
/// orasıdır: eksik yerleri doldurmak için sahte kullanıcı ya da boş
/// siluet çizmek, oyuncuya var olmayan bir rekabet göstermek olur.
///
/// Bu bekçiler kaynak sözleşmesine bakar: slotlar null-güvenli kurulmalı,
/// tek kişi ortalanmalı ve kullanıcı listede yokken kendi sırası ayrı bir
/// yüzeyle sabitlenmeli.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/src/screens/leaderboard_screen.dart').readAsStringSync();
  });

  test('podyum slotları yalnız var olan kullanıcılar için kurulur', () {
    // `entries[1]`/`entries[2]`e koşulsuz erişim 1-2 kişilik tabloda
    // çökerdi; koşullu kurulum boş siluet de çizmez.
    expect(source, contains('entries.isNotEmpty ? entries[0] : null'));
    expect(source, contains('entries.length > 1 ? entries[1] : null'));
    expect(source, contains('entries.length > 2 ? entries[2] : null'));
    for (final slot in const ['if (second != null)', 'if (first != null)']) {
      expect(source, contains(slot));
    }
  });

  test('tek kullanıcı üçlü kalıba sıkıştırılmaz', () {
    // Tek lider ortalanır; iki boş sütunun arasına yerleştirilmez.
    expect(source, contains('slots.length == 1'));
    expect(source, contains('Center(child: slots.first)'));
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
    expect(source, contains('if (_myRank(entries) == null) _buildMyRankRow'));
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
