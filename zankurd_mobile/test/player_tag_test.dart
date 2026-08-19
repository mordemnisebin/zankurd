import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/friend.dart';

/// Oyuncu kodu: aynı adı taşıyan iki kişiyi ayıran tek şey.
///
/// 2026-07-28: `profiles.display_name` benzersiz değil ve arkadaş araması
/// ada göre benzerlik arıyor. İki kişi "Berfin" adını seçerse arama iki
/// **özdeş** satır döndürüyordu: aynı ad, aynı görünüm, ayırt edecek
/// hiçbir şey yok. Arayan kişi yanlış kişiye istek gönderebilirdi.
///
/// Adı benzersiz yapmak akla ilk gelen ama bu uygulamaya uymuyor: ad
/// vermek isteğe bağlı ("Şimdilik geç" var) ve iki dilli bir toplulukta
/// kültürel bir seçim. Bu yüzden ad serbest kaldı, ayırt etmeyi dört
/// karakterlik değişmez bir kod yapıyor — uygulamanın oda kodlarıyla
/// (ZK-GVNC) aynı biçim, yani oyuncuya yeni bir kavram öğretmiyor.
void main() {
  test('kod ekranda ZK- önekiyle gösterilir', () {
    const player = PlayerSearchResult(
      id: 'a',
      displayName: 'Berfin',
      playerTag: '4F7K',
    );
    expect(player.formattedTag, 'ZK-4F7K');
  });

  test('kodu olmayan eski profilde hiçbir şey uydurulmaz', () {
    // Göç uygulanmadan önce açılmış profillerde kod null. Arayüz o durumda
    // kodu hiç göstermez; "ZK-" ya da "ZK-null" gibi bir şey göstermek
    // paylaşılabilir bir kod varmış izlenimi verirdi.
    for (final tag in [null, '', '   ']) {
      final player = PlayerSearchResult(
        id: 'a',
        displayName: 'Berfin',
        playerTag: tag,
      );
      expect(player.formattedTag, isNull, reason: 'tag=$tag');
    }
  });

  test('arama sonucu sunucudan gelen kodu okur', () {
    final player = PlayerSearchResult.fromJson(const {
      'id': 'a',
      'display_name': 'Berfin',
      'avatar_color': '#C2560E',
      'player_tag': '9XQM',
    });
    expect(player.playerTag, '9XQM');
    expect(player.formattedTag, 'ZK-9XQM');
  });

  /// Bir fonksiyonu tanımlayan en yeni tarihli göçün gövdesi.
  ///
  /// Tarihli dosya adları sıralanabilir olduğu için sözlük sırasındaki son
  /// eleman, uygulanma sırasındaki son tanımdır. `search_profiles` için bu
  /// önemli: 2026-07-28_player_tag.sql önek soymayı EKLEDİ,
  /// 2026-07-31_exposure_hardening.sql fonksiyonu `create or replace` ile
  /// baştan yazarken o satırı taşımadan LIKE kaçırmayı ekledi. Sabit dosya
  /// adına bakan bir bekçi ikinci göçü hiç görmez ve canlıda artık
  /// çalışmayan bir davranışı yeşil gösterir (2026-08-14 denetimi).
  String newestDefinitionOf(String function) {
    final pattern = RegExp(
      'create\\s+(?:or\\s+replace\\s+)?function\\s+public\\.$function\\b',
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

  group('göç betiği', () {
    late String sql;

    setUpAll(() {
      sql = File('supabase/2026-07-28_player_tag.sql').readAsStringSync();
    });

    test('kod benzersiz ve değişmez', () {
      // Benzersizlik yalnız üreteçle sağlanamaz: iki eşzamanlı kayıt aynı
      // kodu üretebilir. Son sözü dizin söyler.
      expect(sql, contains('create unique index if not exists'));
      // Paylaşılan bir kodun yarın başkasını göstermemesi için güncelleme
      // yolu da kapalı.
      expect(sql, contains('freeze_player_tag'));
    });

    test('kod alfabesinde karışan karakter yok', () {
      final alphabet = RegExp(
        r"v_alphabet constant text := '([^']+)'",
      ).firstMatch(sql)!.group(1)!;
      // 0/O, 1/I/L birbirine karışır; kod elle de yazılabilmeli.
      for (final confusing in ['0', 'O', '1', 'I', 'L']) {
        expect(
          alphabet.contains(confusing),
          isFalse,
          reason: '$confusing karışan karakter',
        );
      }
      // Sesli harf yok: dört harflik kodun yanlışlıkla sözcük olmaması için.
      for (final vowel in ['A', 'E', 'U']) {
        expect(alphabet.contains(vowel), isFalse, reason: '$vowel sesli harf');
      }
    });

    test('en yeni search_profiles tanımı önek soymayı korur', () {
      // Bilerek 2026-07-28 dosyasına DEĞİL, en yeni tanıma bakar — bu
      // sözleşmeyi ezen her yeni göç burada kırılır.
      final newest = newestDefinitionOf('search_profiles');
      expect(newest, contains('p.player_tag = v_tag or p.display_name ilike'));
      expect(newest, contains('order by (p.player_tag = v_tag) desc'));
      // "ZK-4F7K", "zk 4f7k" ve "4F7K" aynı kodu aramalı: kod ekranda
      // önekle görünüyor, elle yazarken öneki beklemek gereksiz sürtünme.
      expect(
        newest,
        contains("regexp_replace(v_query, '^[zZ][kK][-\\s]*', '')"),
      );
    });
  });
}
