import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Günün Etkinliği" hep boştu çünkü hiçbir kod yolu `contests`e satır
/// yazmıyordu.
///
/// ## Kusur
///
/// `get_today_contest()` (2026-07-05_contest_system.sql) yalnız
/// `WHERE day_key = CURRENT_DATE` ile SELECT yapıyordu. Ne bir client kod
/// yolu ne de bir pg_cron görevi `contests` tablosuna satır INSERT
/// etmiyordu — tablo hep boştu, bu yüzden bu fonksiyon her gün hiçbir
/// zaman doldurulmayacak bir satırı arıyordu ve her zaman boş dönüyordu.
/// `SupabaseZanKurdRepository.loadTodayContest()` boş sonucu `null`
/// olarak yorumluyor, hata fırlatmadığı için kusur sessizdi
/// (2026-08-14 denetimi).
///
/// ## Düzeltme
///
/// `get_today_contest()`, `supabase/2026-08-14_contest_daily_upsert.sql`
/// ile idempotent bir "yoksa oluştur" fonksiyonuna çevrildi: gün için
/// satır yoksa gün-sırasına göre deterministik bir tema seçip
/// `INSERT ... ON CONFLICT (day_key) DO NOTHING` ile yaratır, sonra
/// SELECT eder. Bu test canlı bir veritabanı olmadan çalıştığı için SQL'i
/// ÇALIŞTIRMAZ — yalnız en son tanımın gerekli deyimleri içerdiğini,
/// yani `player_tag_test.dart`'taki `newestDefinitionOf` deseniyle bu
/// fonksiyonun EN SON tanımının bu göç olduğunu doğrular.
void main() {
  /// `zankurd_repository.dart`daki desenin aynısı: hangi tarihli göçün bu
  /// fonksiyonu EN SON tanımladığını bulur. `create or replace function`
  /// ile aynı isim birden çok göçte tekrar tanımlanabildiği için (bkz.
  /// `search_profiles`), sadece dosyanın VAR OLMASI yetmez — en yeni
  /// tanımın doğru davranışı taşıdığını doğrulamak gerekir.
  String newestDefinitionOf(String function) {
    final pattern = RegExp(
      'create\\s+(?:or\\s+replace\\s+)?function\\s+(?:public\\.)?$function\\b',
      caseSensitive: false,
    );
    final dated =
        Directory('supabase')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.sql'))
            .where((f) => RegExp(r'/\d{4}-\d{2}-\d{2}_').hasMatch(f.path))
            .where((f) => pattern.hasMatch(f.readAsStringSync()))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(
      dated,
      isNotEmpty,
      reason: '$function hiçbir tarihli göçte tanımlanmıyor',
    );
    return dated.last.readAsStringSync();
  }

  test('göç idempotent upsert deseni içeriyor', () {
    final migration = File(
      'supabase/2026-08-14_contest_daily_upsert.sql',
    ).readAsStringSync();

    expect(
      migration,
      contains('insert into public.contests'),
      reason: 'fonksiyon artık satır yazmalı, sadece okumamalı',
    );
    expect(
      migration,
      contains('on conflict (day_key) do nothing'),
      reason:
          'aynı gün birden çok istemci yarışarak çağırırsa (ekran her '
          'açılışta bu RPC'
          "'yi çağırıyor) çakışma olmadan tek satıra yakınsamalı",
    );
    expect(
      migration,
      contains('security definer'),
      reason:
          '`anon`/`authenticated` `contests` tablosunda yalnız SELECT '
          'yetkisine sahip (bkz. production baseline); INSERT için '
          'fonksiyonun sahibi adına çalışması gerekir',
    );
    expect(
      migration,
      contains('where c.day_key = current_date'),
      reason: 'upsert sonrası hâlâ bugünün satırını döndürmeli',
    );
  });

  test(
    'get_today_contest en son tanımı contests tablosuna yazıyor',
    () {
      // Bu, fonksiyon isminin `2026-07-05_contest_system.sql`'de KALDIĞI
      // ama davranışının `create or replace` ile ileri-yönlü bir göçle
      // DEĞİŞTİĞİ senaryoyu yakalar: eski dosya asla düzenlenmedi (kural
      // gereği), yeni dosya en son tanımı taşıyor.
      final newest = newestDefinitionOf('get_today_contest');
      expect(
        newest,
        contains('insert into public.contests'),
        reason:
            'en son tanım hâlâ salt-okunur eski davranışa geri düşmüş '
            'olabilir; get_today_contest her zaman en son göçten okunmalı',
      );
    },
  );
}
