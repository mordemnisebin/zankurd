/// G15 kusuru: V1 işi teslimden önce kalıcı tüketiyor; cron'u kapatmak eski
/// manuel worker'ı durdurmuyor. Sessizlik: önceki bekçiler dosya/cron varlığını
/// denetliyor, eski RPC yetkisini ve güvenli geri durdurmayı denetlemiyordu.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'G15 V1 kalıcı tüketimi: yalnız cron testi eski worker yetkisini sessiz bıraktı',
    () {
      final sql = File(
        'supabase/2026-11-01_push_delivery_v2_closed_cutover.sql',
      ).readAsStringSync();
      final rollback = File(
        'supabase/geri_al/2026-11-01_push_delivery_v2_closed_cutover.sql',
      ).readAsStringSync();
      for (final text in [sql, rollback]) {
        expect(text, contains('begin;'));
        expect(text, contains('commit;'));
        expect(text, contains('set enabled = false where singleton'));
        expect(
          text,
          contains(
            'revoke all on function public.claim_push_outbox(integer)\n'
            '  from public, anon, authenticated, service_role;',
          ),
        );
        expect(text, contains('active := false'));
        expect(text, isNot(contains('set claimed_at')));
        expect(text, isNot(contains('grant execute')));
      }
      expect(sql, contains('has_function_privilege'));
      expect(sql, contains("to_regprocedure('public.claim_push_outbox_v2"));
      expect(sql, isNot(contains('create function')));
      expect(sql, isNot(contains('create or replace function')));
    },
  );
}
