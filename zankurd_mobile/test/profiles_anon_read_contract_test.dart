import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pentest 2.1: anon token ile `profiles` sayfalanabiliyordu.
///
/// Göçün kâğıtta kalmaması için dosyanın gerçekten `anon` SELECT'i
/// kaldırdığını ve authenticated politikasının `anon`a açık olmadığını
/// kilitle.
void main() {
  test('profiles anon okuma göçü SELECT yetkisini kaldırır', () {
    final sql = File(
      'supabase/2026-09-02_restrict_profiles_anon_read.sql',
    ).readAsStringSync();

    expect(sql, contains('revoke select on public.profiles from anon'));
    expect(sql, contains('revoke all on table public.profiles from anon'));
    expect(
      sql,
      contains("create policy \"Profiles are readable by signed-in users\""),
    );
    expect(sql, contains('to authenticated'));
    expect(sql, isNot(contains('to anon')));
  });
}
