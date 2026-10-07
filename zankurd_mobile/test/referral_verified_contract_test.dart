import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Davet ödülü misafir/anonim kimlikte verilmez.
void main() {
  test('redeem_referral_code doğrulanmış kimlik ister', () {
    final sql = File(
      'supabase/2026-09-06_referral_verified_only.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.redeem_referral_code'),
    );
    expect(sql, contains("'not_verified'"));
    expect(sql, contains('auth.identities'));
    expect(sql, contains("provider is distinct from 'anonymous'"));
    expect(sql, contains('revoke all on function public.redeem_referral_code'));
    expect(sql, contains('from anon'));
  });
}
