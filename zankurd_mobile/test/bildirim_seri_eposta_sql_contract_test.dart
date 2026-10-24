/// 2026-10-24_bildirim_seri_eposta.sql ile istemci arasındaki sözleşme.
///
/// ## Kusur
///
/// Üç özelliğin yarısı sunucudadır: türe göre push süzgeci, seri onarımının
/// idempotent ücreti ve e-posta doğrulama işaretinin kanıtı. İstemci ile göç
/// birbirinden habersiz değişirse (bedel, RPC parametre adı, kind adı)
/// hiçbir derleme hatası çıkmaz: onarım "geçersiz fiyat" ile reddedilir ya
/// da yeni bir push türü tercihsiz kalır.
///
/// ## Niçin sessiz kalırdı
///
/// SQL ve Dart ayrı dünyalar; göç canlıya elle uygulanıyor. Sözleşmeyi
/// yalnız bu dosya iki tarafı yan yana okuyup karşılaştırır.
///
/// ## Kural
///
/// * Bedel (`StreakStore.repairCost`) göçteki sabitle aynıdır.
/// * RPC parametre adları istemci çağrısıyla aynıdır.
/// * Bilinen her push türü ya düello ya arkadaş süzgecine girer.
/// * Yeni SECURITY DEFINER gövdeleri `search_path`i sabitler; istemciye
///   açık olanlar `authenticated`a verilir, `public`/`anon`dan alınır;
///   `claim_push_outbox` kimseye açık değildir.
/// * Kanıt betiği tek işlemdir ve `rollback` ile biter; auth.users'a yazmaz.
/// * Magic link şablonu kodu ({{ .Token }}) iki dilde taşır, bağlantı taşımaz.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  final migration = _read('supabase/2026-10-24_bildirim_seri_eposta.sql');
  final proof = _read(
    'supabase/kanit/2026-10-24_bildirim_seri_eposta_kanit.sql',
  );

  test('göç tek işlemdir', () {
    expect(migration.trimLeft().contains('\nbegin;'), isTrue);
    expect(migration.trimRight().endsWith('commit;'), isTrue);
  });

  test('onarım bedeli istemci ve sunucuda aynıdır', () {
    final match = RegExp(
      r'v_cost constant integer := (\d+);',
    ).firstMatch(migration);
    expect(match, isNotNull);
    expect(int.parse(match!.group(1)!), StreakStore.repairCost);
  });

  test('onarım RPC parametre adları istemciyle aynıdır', () {
    final repo = _read('lib/src/data/supabase_zankurd_repository.dart');
    for (final p in ['p_month', 'p_break_day', 'p_premium']) {
      expect(migration, contains(p));
      expect(repo, contains("'$p'"));
    }
    for (final p in ['p_duel', 'p_social']) {
      expect(migration, contains(p));
      expect(repo, contains("'$p'"));
    }
  });

  test('onarım ücreti gerekçe + kısmi tekil indeksle idempotenttir', () {
    expect(migration, contains("'streak_repair:' || v_month"));
    expect(migration, contains("where reason like 'streak_repair:%'"));
    expect(migration, contains('primary key (player_id, month_key)'));
    expect(migration, contains('pg_advisory_xact_lock'));
  });

  test('bilinen her push türü bir tercih süzgecine girer', () {
    // Süzgeç: async_duel* -> push_duel; sosyal üçlü -> push_social.
    expect(migration, contains(r"like 'async\_duel%'"));
    expect(
      migration,
      contains("'friend_request', 'friend_accept', 'room_invite'"),
    );
    const social = {'friend_request', 'friend_accept', 'room_invite'};
    for (final kind in [
      'async_duel_result',
      'async_duel_invite',
      'async_duel_turn',
      'friend_request',
      'friend_accept',
      'room_invite',
    ]) {
      expect(
        PushTapRouter.targetForKind(kind),
        isNotNull,
        reason: '$kind istemcide tanınan bir tür olmalı',
      );
      expect(
        kind.startsWith('async_duel') || social.contains(kind),
        isTrue,
        reason: '$kind hiçbir tercih süzgecine girmiyor',
      );
    }
    // Süzgeç hem adım 1'de (kapat) hem adım 2'de (seçme) bulunur.
    expect(RegExp('push_duel').allMatches(migration).length, greaterThan(3));
  });

  test('onarım: ay/gün sunucuda, premium yok sayılır, mevcut kayıt önce', () {
    expect(migration, contains("'Europe/Istanbul'"));
    expect(migration, isNot(contains('+ 31')));
    expect(migration, isNot(contains('- 31')));
    expect(migration, contains('v_break < v_today - 1 or v_break > v_today'));
    // Mevcut kayıt sorgusu, tarih/aralık denetiminden ÖNCE gelir.
    final existing = migration.indexOf(
      'from public.streak_repairs\n  where player_id = v_uid and month_key = v_month',
    );
    final range = migration.indexOf("'break day out of range'");
    expect(existing, greaterThan(0));
    expect(existing, lessThan(range));
    // p_premium gövdede okunmaz (yalnız imza ve yorum).
    final body = migration.substring(
      migration.indexOf(
        'create or replace function public.spend_streak_repair',
      ),
      migration.indexOf('-- B3: e-posta doğrulama işareti'),
    );
    expect(RegExp(r'coalesce\(p_premium').hasMatch(body), isFalse);
  });

  test('e-posta kanıtı: telefon boş, gelecek amr yok, adres saklanır', () {
    expect(migration, contains("coalesce(u.phone, '') = ''"));
    expect(migration, contains('extract(epoch from now()) + 60'));
    expect(migration, contains('email_verified_address = v_address'));
    expect(
      migration,
      contains('new.email_verified_address := old.email_verified_address;'),
    );
    expect(migration, contains('new.email_verified_address := null;'));
    expect(
      migration,
      contains(
        'CREATE OR REPLACE FUNCTION public.profiles_client_insert_authority()',
      ),
    );
    final gateway = _read('lib/src/services/email_verification.dart');
    expect(gateway, contains("response['email_verified_address']"));
  });

  test('SECURITY DEFINER gövdeleri search_path sabitler', () {
    final definers = RegExp(
      r'security definer\s+set search_path to .public., .pg_temp.',
      caseSensitive: false,
    ).allMatches(migration).length;
    // get_my_account_flags, set_my_push_prefs, spend_streak_repair,
    // mark_my_email_verified, claim_push_outbox.
    expect(definers, 5);
  });

  test('yetkiler: istemciye açık dört RPC authenticated, claim kimseye', () {
    for (final fn in [
      'get_my_account_flags()',
      'set_my_push_prefs(boolean, boolean)',
      'spend_streak_repair(text, text, boolean)',
      'mark_my_email_verified()',
    ]) {
      expect(
        migration,
        contains('revoke all on function public.$fn from public, anon;'),
      );
      expect(
        migration,
        contains('grant execute on function public.$fn to authenticated;'),
      );
    }
    expect(
      migration,
      contains(
        'revoke execute on function public.claim_push_outbox(integer) from public, anon, authenticated;',
      ),
    );
    expect(
      migration,
      contains(
        'revoke all on public.streak_repairs from public, anon, authenticated;',
      ),
    );
  });

  test('e-posta doğrulama: OTP kanıtı, parola reddi, istemci yazamaz', () {
    expect(migration, contains("a->>'method' in ('otp', 'magiclink')"));
    expect(migration, contains("'otp session required'"));
    expect(migration, contains('extract(epoch from now()) - 900'));
    expect(
      migration,
      contains('new.email_verified_at := old.email_verified_at;'),
    );
    expect(migration, contains('lower(u.email) = v_email'));
  });

  test('kanıt betiği tek işlem, rollback ile biter, auth.users\'a yazmaz', () {
    expect(proof.trimRight().endsWith('rollback;'), isTrue);
    expect(RegExp(r'^begin;', multiLine: true).hasMatch(proof), isTrue);
    expect(proof.toLowerCase(), isNot(contains('insert into auth.users')));
    expect(proof, contains('ONCE-DURUMU'));
    expect(proof, contains('SONRA-OK'));
    // Parola, bayat OTP, taze OTP ve istemci yazımı ayrı satırlarda.
    for (final marker in ['(m)', '(n)', '(o)', '(p)', '(i)', '(c)']) {
      expect(proof, contains(marker));
    }
  });

  test('applied.md satırı uygulandı durumundadır', () {
    final applied = _read('supabase/applied.md');
    expect(applied, contains('| 2026-10-24_bildirim_seri_eposta.sql | ✅ |'));
  });

  test('Magic link şablonu kodu iki dilde taşır, bağlantı taşımaz', () {
    final html = _read('docs/eposta_sablon_magic_link.html');
    expect('{{ .Token }}'.allMatches(html).length, greaterThanOrEqualTo(2));
    // Yorum bloğunun dışında bağlantı değişkeni kullanılmaz.
    final body = html.substring(html.indexOf('-->') + 3);
    expect(body, isNot(contains('ConfirmationURL')));
    expect(body, contains('Koda e-nameyê'));
    expect(body, contains('E-posta kodun'));
  });
}
