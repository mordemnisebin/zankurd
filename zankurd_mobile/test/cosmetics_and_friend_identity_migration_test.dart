import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Satın alınan çerçeve saklanabilmeli, arkadaşın adı gerçek olmalı.
///
/// ## Kusurlar
///
/// Üçü de aynı biçimde sessizdi: **sunucu yazımı reddediyor ya da hiç
/// kullanmıyor, istemci bunu başarı sayıyor.**
///
/// 1. `spend_coins` 2026-08-02'de `avatar_frame_neon`ü satılabilir yaptı
///    ama `protect_paid_profile_cosmetics` çerçeve listesine `neon`
///    eklenmedi. Temiz üretim klonunda uçtan uca üretildi: satın alma
///    `{"balance": 4400, "success": true}` döndü (600 coin gerçekten
///    düştü), ardından `avatar_frame='neon'` yazımı
///    `ERROR: Invalid avatar frame` ile reddedildi. Dahası `neon`
///    seçili kaldığı sürece UPDATE'in tamamı iptal olduğu için avatar
///    ikonu ve rengi de kaydedilemez oldu — profil kozmetiği kalıcı ve
///    sessiz biçimde donuyordu.
///
/// 2. `add_friend(p_friend_id, p_friend_name)` istemciden ad alıyor ama
///    o parametreye hiç dokunmadan sabit `'Player'` yazıyordu;
///    `accept_friend_request` de karşı tarafa `'Player'` yazıyordu.
///    Gerçek adları Rojda/Berfin olan iki kullanıcıyla her iki
///    `friends` satırı da `'Player'` çıktı. Gelen istek kimden geldiği
///    belirsiz bir kart, arkadaş listesi ise aynı adın tekrarıydı.
///
/// 3. Reddedilen istek `(from_user_id, to_user_id)` benzersizliği
///    yüzünden satırda kalıyor, ikinci gönderim `DO NOTHING` oluyor ama
///    fonksiyon yine koşulsuz `TRUE, 'Friend request sent'` dönüyordu.
///    Bir yanlış dokunuş o yönde arkadaşlığı kalıcı olarak imkânsız
///    kılıyor, gönderene tam tersi söyleniyordu.
///
/// ## Bekçi niçin dosyaya bakıyor
///
/// CI'da veritabanı yok; göç metni tek denetlenebilir kaynak. Bekçi
/// yalnız "düzeltme var mı" demiyor, **kusurun geri gelemeyeceğini**
/// de sabitliyor: bir fonksiyonu tanımlayan EN YENİ tarihli göç
/// eski deseni yeniden taşırsa test düşer.
void main() {
  final neonMigration = File('supabase/2026-08-06_neon_frame_persistence.sql');
  final friendMigration = File(
    'supabase/2026-08-06_friend_identity_and_resend.sql',
  );

  // İki göç ayrı dosyada duruyor (ayrı mantıksal commitler) ama aynı
  // denetim oturumundan çıktıkları için tek bekçi ikisini de tutar.
  late String neonSql;
  late String friendSql;
  late String sql;

  setUpAll(() {
    for (final file in [neonMigration, friendMigration]) {
      expect(
        file.existsSync(),
        isTrue,
        reason: 'İleri yönlü göç dosyası silinmiş olmamalı: ${file.path}',
      );
    }
    neonSql = neonMigration.readAsStringSync().toLowerCase();
    friendSql = friendMigration.readAsStringSync().toLowerCase();
    sql = '$neonSql\n$friendSql';
  });

  /// Yorum satırları atılmış SQL.
  ///
  /// Bekçi ÇALIŞAN SQL'e bakmalı, düzyazıya değil: bu göçün başlığı
  /// kusuru anlatırken eski `'Player'` sabitini bilerek alıntılıyor ve
  /// ham metin araması bunu düzeltmenin kendisi sanıyordu.
  String executableSql(String source) => source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  /// Bir fonksiyonu tanımlayan en yeni tarihli göçün gövdesi.
  ///
  /// Tarihli dosya adları sıralanabilir olduğu için sözlük sırasındaki
  /// son eleman, uygulanma sırasındaki son tanımdır.
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
    return executableSql(dated.last.readAsStringSync());
  }

  group('neon çerçevesi', () {
    test('çerçeve izin listesinde neon var', () {
      expect(
        sql,
        contains("array['bronze', 'silver', 'gold', 'mamoste', 'neon']"),
        reason: 'Ödenen çerçeve sunucuda saklanabilmeli',
      );
    });

    test('neon yalnız satın alana açık — bedava giymek mümkün değil', () {
      expect(sql, contains("new.avatar_frame = 'neon'"));
      expect(sql, contains("sp.item_id = 'avatar_frame_neon'"));
      expect(sql, contains('neon frame has not been purchased'));
    });

    test('ilerlemeyle kazanılan çerçevelere satın alma şartı eklenmedi', () {
      // bronze/silver/gold/mamoste başarımla da açılır; onları mağaza
      // şartına bağlamak kazanılmış çerçeveleri kilitlerdi.
      for (final frame in ['bronze', 'silver', 'mamoste']) {
        expect(
          sql,
          isNot(contains("new.avatar_frame = '$frame'\n")),
          reason: '$frame satın alma kapısına bağlanmamalı',
        );
      }
    });

    test('VIP rozeti koruması korundu', () {
      expect(sql, contains('vip badge has not been purchased'));
    });

    test('en yeni tetikleyici tanımı neon taşıyor', () {
      final newest = newestDefinitionOf(
        'protect_paid_profile_cosmetics',
      ).toLowerCase();
      expect(
        newest,
        contains("'neon'"),
        reason: 'Daha yeni bir göç dört değerli listeye geri dönmüş',
      );
    });
  });

  group('arkadaş kimliği', () {
    test('add_friend sabit Player yazmıyor', () {
      final newest = newestDefinitionOf('add_friend');
      expect(
        newest,
        isNot(contains("'Player'")),
        reason: 'Sabit ad geri gelmiş; herkes yine aynı görünecek',
      );
    });

    test('accept_friend_request sabit Player yazmıyor', () {
      final newest = newestDefinitionOf('accept_friend_request');
      expect(newest, isNot(contains("'Player'")));
    });

    test('ad istemciden değil profilden okunuyor', () {
      expect(
        sql,
        contains('select display_name into v_display_name from profiles'),
        reason: 'Kimlik yalnız auth.uid() ile bağlanmış profilden gelmeli',
      );
    });

    test(
      'istemcinin gönderdiği ad hiçbir insert/update ifadesine girmiyor',
      () {
        // İmza korundu (çağıran istemciler kırılmasın) ama değer
        // kullanılmıyor: aksi hâlde başkasının adıyla istek atılabilirdi.
        final body = sql.split(
          'create or replace function public.add_friend',
        )[1];
        final upToNextFunction = body.split(r'$function$;')[0];
        expect(
          upToNextFunction,
          isNot(contains('p_friend_name,')),
          reason: 'İstemciden gelen ad yazıma girerse taklit mümkün olur',
        );
        expect(
          upToNextFunction,
          isNot(contains('values (v_user_id, p_friend_name')),
        );
      },
    );

    test('okuma yolu adı profilden birleştiriyor — backfill gerekmiyor', () {
      final friends = newestDefinitionOf('list_friends').toLowerCase();
      final pending = newestDefinitionOf(
        'list_pending_friend_requests',
      ).toLowerCase();
      expect(friends, contains('left join profiles'));
      expect(pending, contains('left join profiles'));
      // Profili silinmiş kullanıcıda son bilinen ad yedekte kalmalı.
      expect(friends, contains('f.friend_name'));
      expect(pending, contains('fr.from_user_name'));
    });

    test('üretim verisine dokunan bir backfill UPDATE eklenmedi', () {
      expect(
        sql,
        isNot(contains('update friends set friend_name')),
        reason: 'Okuma yolu düzeldiği için veri taşımaya gerek yok',
      );
      expect(sql, isNot(contains('update friend_requests set from_user_name')));
    });
  });

  group('reddedilen isteğin yeniden gönderilmesi', () {
    test('çakışma artık sessizce yutulmuyor', () {
      expect(sql, contains('on conflict (from_user_id, to_user_id) do update'));
      expect(sql, contains("set status = 'pending'"));
      expect(
        sql,
        contains("where friend_requests.status is distinct from 'pending'"),
        reason: 'Zaten bekleyen istek yeniden yazılmamalı',
      );
    });

    test('gerçek no-op artık sahte başarı dönmüyor', () {
      expect(sql, contains('get diagnostics v_rows = row_count'));
      expect(sql, contains('friend request already pending'));
      expect(
        sql,
        isNot(contains('on conflict (from_user_id, to_user_id) do nothing')),
        reason: 'DO NOTHING + koşulsuz TRUE tam olarak eski kusurdu',
      );
    });
  });

  test('her göç ileri yönlü ve tek işlem', () {
    for (final each in [neonSql, friendSql]) {
      expect(each, contains('begin;'));
      expect(each, contains('commit;'));
      expect(
        each,
        isNot(contains('drop function')),
        reason: 'İmza korunuyor; istemci çağrıları kırılmamalı',
      );
    }
  });
}
