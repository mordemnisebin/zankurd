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
/// Göç UYGULANMADI. Aşağıdaki kontroller statiktir; `applied.md` içinde
/// kaydı yoktur ve istemci hâlâ eski yolu kullanır.
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

  test('göç uygulanmış olarak işaretlenmemiştir', () {
    // İstemci bu RPC'ye geçmeden ve göç gerçekten uygulanmadan önce
    // `applied.md`ye satır eklenmesi, ileride yanlış bir "güvende"
    // varsayımına yol açar.
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(applied, isNot(contains('2026-08-03_streak_freeze_idempotency')));
  });

  test('istemci hâlâ eski yolu kullanır, çift çekim riski artmaz', () {
    // Göç uygulanana kadar istemci `spend_streak_freeze` çağırmamalı:
    // çağırırsa canlıda PGRST202 alır ve dondurma tamamen kırılır.
    final screen = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    expect(screen, isNot(contains('spend_streak_freeze')));
    expect(screen, contains("spendCoins(_streakFreezeCost, 'streak_freeze')"));
  });
}
