import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  test(
    'room chat policy hides blocked senders without a permissive bypass',
    () {
      final sql = File(
        '$root/supabase/2026-08-01_room_messages_policy_hardening.sql',
      ).readAsStringSync();

      expect(sql, contains('drop policy if exists room_messages_read'));
      expect(sql, contains('create policy room_messages_member_select'));
      expect(sql, contains('not exists'));
      expect(sql, contains('public.blocked_users'));
    },
  );

  test(
    'security advisor migration hardens views, bucket listing and anon RPCs',
    () {
      final sql = File(
        '$root/supabase/2026-08-01_security_advisor_hardening.sql',
      ).readAsStringSync();

      expect(sql, contains('security_invoker'));
      expect(sql, contains('Avatar photos are publicly readable'));
      expect(
        sql,
        contains('revoke execute on function public.join_room_by_code'),
      );
      expect(sql, contains('from public, anon'));
      expect(
        sql,
        contains('revoke execute on function public.report_question'),
      );
    },
  );

  test('all mutable public functions receive an explicit search path', () {
    final sql = File(
      '$root/supabase/2026-08-01_function_search_path_hardening.sql',
    ).readAsStringSync();

    expect(sql, contains('alter function public.log_analytics_event'));
    expect(sql, contains('alter function public.league_week_start'));
    expect(sql, contains('set search_path = public'));
  });
}
