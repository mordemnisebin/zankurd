import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-10-29 Codex denetimi sunucu göçünün sözleşme bekçisi.
///
/// ## Kusurlar
///
/// * Hata #3: iade anahtarı yalnız oda+oyuncuydu; gir→çık→gir→çık'ta ikinci
///   iade benzersiz indekse çakışıp sessizce atlanıyordu (jeton kaybı).
/// * Hata #10: `join_room_by_code` bakiye kontrolünü mevcut üyelik
///   kontrolünden ÖNCE yapıyordu; son jetonuyla katılıp yanıtı kaybeden
///   oyuncu tekrarında "Insufficient coins" alıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// İkisi de yalnız belirli bir İSTEK SIRASINDA görünür (iki katılım; kaybolan
/// yanıt). Tek katılımlı testler ve bakiyesi bol testler geçer.
///
/// ## Bekçi
///
/// Dosya (uygulanmadan önce) şu sözleşmeyi taşır: iade anahtarı `joined_at`
/// içerir; üyelik dönüşü bakiye kontrolünden önce gelir; yetkiler korunur;
/// kanıt betiği rollback ile biter.
void main() {
  final migration = File(
    'supabase/2026-10-29_codex_denetim_duzeltmeleri.sql',
  ).readAsStringSync();
  final proof = File(
    'supabase/kanit/2026-10-29_codex_denetim_kanit.sql',
  ).readAsStringSync();

  test(
    'iade anahtarı her katılıma özel (joined_at) ve eski anahtarı da korur',
    () {
      expect(migration, contains('rp.joined_at into v_joined'));
      expect(migration, contains("':at='"));
      expect(migration, contains('ct.created_at >= v_joined'));
      expect(
        migration,
        contains('grant execute on function public.refund_room_entry_fee'),
      );
    },
  );

  test('join_room_by_code: üyelik dönüşü bakiye kontrolünden önce gelir', () {
    final fn = migration.substring(
      migration.indexOf('CREATE OR REPLACE FUNCTION public.join_room_by_code'),
    );
    final member = fn.indexOf(
      'and rp.left_at is null\n  ) then\n    return json_build_object(',
    );
    final balance = fn.indexOf('Insufficient coins for room entry fee');
    expect(member, greaterThan(0));
    expect(balance, greaterThan(member));
  });

  test('kanıt betiği tek transaction ve rollback ile biter', () {
    expect(proof.trimRight(), endsWith('rollback;'));
    expect(proof, contains('begin;'));
  });

  test('hat_0094 hem yerelde hem sunucuda emekli', () {
    final retired = File(
      'lib/src/config/retired_question_ids.dart',
    ).readAsStringSync();
    expect(retired, contains("'hat_0094'"));
    expect(migration, contains('c593666a-a8fe-5f3d-a011-c038192c6237'));
  });
}
