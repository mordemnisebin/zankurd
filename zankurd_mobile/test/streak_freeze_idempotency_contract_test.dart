import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Seri dondurma harcamasının idempotency sözleşmesi.
///
/// `spend_coins(50, 'streak_freeze')` sunucuda idempotent DEĞİL: mağaza
/// alımları `shop_purchases` kontrolüyle korunuyor ama `streak_freeze`
/// için hiçbir dedup anahtarı yok, her çağrı yeni bir `-50` satırı yazar
/// (`2026-08-02_shop_neon_frame_allowlist.sql`).
///
/// Bu, istemcinin `freezeApplying` aşamasını niçin ASLA yeniden
/// denemediğini açıklar — ve o kısıt kaldırılacaksa önce bu göç
/// uygulanmalıdır.
///
/// Göç production'da uygulandı ve aşağıdaki kontroller statik istemci/RPC
/// sözleşmesini korur. Eski backend'lere karşı güvenli fallback yine tutulur.
void main() {
  late String sql;

  setUpAll(() {
    sql = File('supabase/2026-08-03_streak_freeze_idempotency.sql')
        .readAsStringSync()
        .replaceAll(RegExp(r'--[^\n]*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  });

  test('tekillik yapısaldır, yalnız fonksiyon mantığına bırakılmaz', () {
    // Sadece "önce SELECT sonra INSERT" yeterli değildi: iki eşzamanlı
    // çağrı ikisini de boş görüp iki satır yazabilir. Kısmi tekil indeks
    // bunu veritabanı düzeyinde imkânsız kılar.
    expect(
      sql,
      contains(
        'create unique index if not exists '
        'coin_transactions_streak_freeze_key_uidx',
      ),
    );
    expect(sql, contains('on public.coin_transactions (player_id, reason)'));
    // Kısmi olmalı: eski anahtarsız `streak_freeze` satırları bir
    // kullanıcıda birden çok bulunabilir; tam indeks göçü düşürürdü.
    expect(sql, contains("where reason like 'streak_freeze:%'"));
  });

  test('ikinci çağrı ikinci kez çekmez', () {
    expect(sql, contains('already_charged'));
    expect(sql, contains("v_reason := 'streak_freeze:' || v_key"));
    // Var olan kayıt bulunduğunda erken dönülür; insert'e ulaşılmaz.
    final existingCheck = sql.indexOf('if found then');
    final insert = sql.indexOf('insert into public.coin_transactions');
    expect(existingCheck, isNonNegative);
    expect(insert, greaterThan(existingCheck));
  });

  test('eşzamanlı denemeler kullanıcı kilidiyle sıraya girer', () {
    expect(
      sql,
      contains('pg_advisory_xact_lock(hashtextextended(v_uid::text, 0))'),
    );
  });

  test('kimlik çağırandan değil auth.uid() üzerinden alınır', () {
    expect(sql, contains('v_uid uuid := auth.uid()'));
    // Anahtar kullanıcı kimliği taşımaz; kapsam `player_id` ile sağlanır,
    // yani bir kullanıcının anahtarı başkasının satırıyla çakışamaz.
    expect(sql, contains('coin_tx.player_id = v_uid'));
    expect(sql, isNot(contains('p_player_id')));
    expect(sql, isNot(contains('p_user_id')));
  });

  test('fiyat sunucuda sabittir, çağırandan alınmaz', () {
    expect(sql, contains('v_cost constant integer := 50'));
    expect(sql, isNot(contains('p_amount')));
  });

  test('yetkiler anon kullanıcıya kapalıdır', () {
    expect(
      sql,
      contains(
        'revoke all on function public.spend_streak_freeze(text) '
        'from public, anon',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.spend_streak_freeze(text) '
        'to authenticated',
      ),
    );
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public'));
  });

  test('göç yeniden çalıştırılabilir ve tek transaction içindedir', () {
    expect(sql, contains('create unique index if not exists'));
    expect(sql, contains('create or replace function'));
    expect(sql, contains('begin;'));
    expect(sql, contains('commit;'));
  });

  test('göç production rollout kaydı olarak işaretlenmiştir', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(
      RegExp(
        r'^\| 20260803000000_streak_freeze_idempotency\.sql \| ✅',
        multiLine: true,
      ).hasMatch(applied),
      isTrue,
    );
  });

  // Göç yerel PostgreSQL üzerinde doğrulandıktan (2026-08-03) sonra istemci
  // İstemci idempotent yola geçirildi. Eski veya kısmi backend'lerde
  // PostgREST fonksiyonu bulunamazsa istemci sessizce kırılmak yerine eski
  // `spend_coins` yoluna düşmeli ve bu yolun idempotent olmadığını bildirmeli.
  test('istemci idempotent RPC yolunu kullanır', () {
    final repo = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(repo, contains("client.rpc(\n        'spend_streak_freeze'"));
    expect(repo, contains("'p_idempotency_key': idempotencyKey"));
  });

  test('göç uygulanmamışsa eski yola güvenle düşülür', () {
    final repo = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    // Eksik fonksiyon iki kodla da bildirilebilir; ikisi de yakalanmalı.
    expect(repo, contains("error.code == '42883'"));
    expect(repo, contains("error.code == 'PGRST202'"));
    // Düşülen yol idempotent DEĞİL ve bunu çağırana söylemeli.
    expect(repo, contains('idempotent: false'));
    expect(repo, contains("spendCoins(50, 'streak_freeze')"));
  });

  test('idempotency anahtari sonuc makbuzunun kimligidir', () {
    final screen = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    // Rastgele ya da zamana bagli bir anahtar, tekrarda ikinci kez cekerdi.
    expect(
      screen,
      contains('idempotencyKey: QuizResultProgressReceiptStore.keyFor('),
    );
  });
}
