import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Referral RPC canlı şemayla uyumlu olmalı; aksi halde uygulanırsa
/// kırılır ya da `profiles.coins` ile ledger sapar.
///
/// ## Kusur
///
/// İlk taslak `coin_transactions(user_id, …)` yazıyordu. Canlı kolon
/// `player_id`. Spend/claim yolları bakiyeyi ledger toplamından okur;
/// `profiles.coins` doğrudan UPDATE hem yazım korumasına takılır hem
/// çift muhasebe üretir.
void main() {
  test(
    'redeem_referral_code ledger’a player_id ile yazar, coins UPDATE yok',
    () {
      final sql = File(
        'supabase/2026-09-02_referral_system.sql',
      ).readAsStringSync();

      expect(
        sql,
        contains('create or replace function public.redeem_referral_code'),
      );
      expect(
        sql,
        contains(
          'insert into public.coin_transactions (player_id, amount, reason)',
        ),
      );
      expect(sql, isNot(contains('coin_transactions (user_id')));
      expect(sql, isNot(contains('coins = coins +')));
      expect(sql, contains('for update'));
      expect(
        sql,
        contains('revoke all on function public.redeem_referral_code'),
      );
      expect(sql, contains('from anon'));
    },
  );
}
