import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// profiles own-row: authenticated herkesi SELECT edemez; kamu profil RPC.
void main() {
  test('profiles own-row göçü SELECT\'i kendi satırına çeker', () {
    final sql = File(
      'supabase/2026-09-06_profiles_own_row.sql',
    ).readAsStringSync();

    expect(sql, contains('Users can read own profile'));
    expect(sql, contains('using (id = auth.uid())'));
    expect(
      sql,
      contains('create or replace function public.get_public_profiles'),
    );
    expect(sql, contains('revoke all on function public.get_public_profiles'));
    expect(sql, contains('from public, anon'));
    expect(sql, isNot(contains('using (true)')));
  });
}
