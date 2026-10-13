import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idempotency tabloları istemciye kapalı ve RLS açık', () {
    final sql = File(
      'supabase/2026-09-22_xp_and_coin_idempotency.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('alter table public.xp_award_keys enable row level security'),
    );
    expect(
      sql,
      contains(
        'alter table public.idempotent_spends enable row level security',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.xp_award_keys from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on table public.idempotent_spends from public, anon, authenticated',
      ),
    );
  });

  test('client delta XP kapalı, coin idempotency RPC açık kalır', () {
    final sql = File(
      'supabase/2026-09-22_xp_and_coin_idempotency.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains(
        'revoke all on function public.award_xp_delta(integer) from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.award_xp_delta_once(integer, text) from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'grant execute on function public.award_xp_delta_once(integer, text) to authenticated',
        ),
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.spend_coins_once(integer, text, text) to authenticated',
      ),
    );
  });
}
