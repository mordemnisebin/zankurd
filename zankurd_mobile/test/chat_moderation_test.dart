import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/chat_moderation_policy.dart';

/// Oda sohbeti Apple 1.2 / Google Play UGC şartlarını karşılar.
///
/// ## Niçin
///
/// 2026-07-31 denetimi: `sendRoomMessage` metni yalnız `trim()` edip
/// gönderiyordu. Depoda küfür filtresi, mesaj bildirme, kullanıcı
/// engelleme ya da susturma yoktu — `grep -rn 'blocked_users|blockUser|
/// reportUser'` hiçbir şey döndürmüyordu.
///
/// Sohbet o sırada hiçbir ekranda mount edilmediği için canlı bir risk
/// değildi ama widget, repo metotları, DB tablosu, testi ve çevirileri
/// yerinde duruyordu. Sohbet geri getirilirken dördü birlikte geldi:
/// süzgeç, bildirme, engelleme ve yayımlanmış iletişim bilgisi.
void main() {
  group('içerik süzgeci', () {
    test('temiz mesaj geçer', () {
      expect(ChatModerationPolicy.isAllowed('Merheba heval!'), isTrue);
      expect(ChatModerationPolicy.isAllowed('Hadi başlayalım'), isTrue);
      expect(ChatModerationPolicy.isAllowed('Bi ser ket 👏'), isTrue);
    });

    test('boş ve yalnız boşluk reddedilir', () {
      expect(ChatModerationPolicy.review(''), ChatModerationVerdict.empty);
      expect(ChatModerationPolicy.review('   '), ChatModerationVerdict.empty);
    });

    test('hakaret tam sözcük olarak yakalanır', () {
      expect(
        ChatModerationPolicy.review('seni orospu'),
        ChatModerationVerdict.blockedWord,
      );
      expect(
        ChatModerationPolicy.review('qehbe'),
        ChatModerationVerdict.blockedWord,
      );
    });

    test('rakam ve aksan kaçamakları yakalanır', () {
      // "s1kt1r", "ŞEREFSİZ" gibi yazımlar sadeleştirilerek eşleşir.
      expect(
        ChatModerationPolicy.review('s1kt1r'),
        ChatModerationVerdict.blockedWord,
      );
      expect(
        ChatModerationPolicy.review('ŞEREFSİZ'),
        ChatModerationVerdict.blockedWord,
      );
    });

    test('masum sözcükler yanlışlıkla engellenmez', () {
      // Alt dizi araması yapılsaydı bunlar da düşerdi. Aşırı geniş bir
      // filtre kullanıcıyı sohbetten kaçırır; liste bilerek dar ve
      // eşleşme tam sözcük üzerinden.
      for (final clean in [
        'Gulan meha pêncan e',
        'Got û gotin',
        'Salatalık aldım',
        'Aptalca değil, akıllıca',
      ]) {
        final verdict = ChatModerationPolicy.review(clean);
        expect(
          verdict,
          isNot(ChatModerationVerdict.blockedWord),
          reason: '"$clean" masum ama engellendi',
        );
      }
    });

    test('bağlantı paylaşımı reddedilir', () {
      for (final link in [
        'bak https://example.com',
        'www.birsey.net',
        'kotu.xyz gir',
      ]) {
        expect(
          ChatModerationPolicy.review(link),
          ChatModerationVerdict.containsLink,
          reason: '"$link" geçti — reklam ve oltalama yüzeyi',
        );
      }
    });

    test('uzun mesaj ve karakter yığını reddedilir', () {
      expect(
        ChatModerationPolicy.review('a' * 300),
        // Önce uzunluk sınırına takılır.
        ChatModerationVerdict.tooLong,
      );
      expect(
        ChatModerationPolicy.review('haydiiiiiiiiii'),
        ChatModerationVerdict.spam,
      );
    });
  });

  group('sunucu tarafı karşılığı', () {
    late String migration;

    setUpAll(() {
      migration = File(
        'supabase/2026-07-31_chat_moderation.sql',
      ).readAsStringSync();
    });

    test('süzgeç sunucuda da kurulu', () {
      // İstemci süzgeci tek başına yeterli değil: değiştirilmiş bir
      // istemci doğrudan REST üzerinden yazabilir.
      expect(migration, contains('chat_message_is_clean'));
      expect(migration, contains('before insert on public.room_messages'));
    });

    test('bildirme ve engelleme tabloları RLS ile korunuyor', () {
      for (final table in ['blocked_users', 'message_reports']) {
        expect(migration, contains('create table if not exists public.$table'));
        expect(
          migration,
          contains('alter table public.$table enable row level security'),
          reason: '$table RLS olmadan herkese açık olur',
        );
      }
      // Kendi engel listenden başkasını göremezsin.
      expect(migration, contains('blocker_id = auth.uid()'));
    });

    test('gönderen kimliği sunucuda yeniden yazılıyor', () {
      // `sendRoomMessage` sender_id, sender_name ve created_at'i istemciden
      // yazıyordu: bir oyuncu başkasının adıyla mesaj atabilirdi.
      expect(migration, contains('new.sender_id := v_uid'));
      expect(migration, contains('new.created_at := now()'));
      expect(migration, contains('not_a_room_member'));
    });

    test('odaya ait olmayan mesajları okuma kapatıldı', () {
      // 2026-07-13_shop_chat_suggestions.sql:99 `USING (true)` diyordu:
      // oda kodu olmayan biri bütün odaların mesajlarını okuyabiliyordu.
      expect(migration, contains('from public.room_players rp'));
      expect(migration, contains('drop policy if exists "room_messages_read"'));
    });
  });

  test('kötüye kullanım iletişimi uygulamada yayımlı (Apple 1.2/4. şart)', () {
    // UGC barındıran uygulamada iletişim bilgisi yayımlanmış olmalı ve
    // kullanıcı ona UYGULAMADAN ulaşabilmeli — yalnız web sayfasında
    // durması yetmez.
    final settings = File(
      'lib/src/screens/settings_screen.dart',
    ).readAsStringSync();
    expect(
      settings,
      contains('_openAbuseReport'),
      reason: 'Kullanıcı taciz bildirimini nereye yapacağını bilmeli.',
    );

    final strings = File('lib/src/l10n/strings.dart').readAsStringSync();
    expect(strings, contains('reportAbuse'));

    // Adres, hesap silme sayfasında zaten yayımlanan adresle aynı olmalı;
    // iki ayrı iletişim kanalı ikisinin de bakımsız kalmasına yol açar.
    final deletePage = File('web/delete-account.html').readAsStringSync();
    expect(deletePage, contains('mailto:'));
  });
}
