import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'T5: eski RPC kopyası canlı düzeltmeyi silerdi; yerel test canlı sapmayı görmüyordu',
    () {
      final sql = File(
        'supabase/2026-10-30_gecis_ritmi.sql',
      ).readAsStringSync().toLowerCase();
      expect(sql, contains('pg_get_functiondef'));
      expect(sql, contains('t5: unexpected advance definition'));
      expect(sql, contains('t5: unexpected resume definition'));
      expect(sql, contains('begin;'));
      expect(sql.trim(), endsWith('commit;'));
      expect(sql, contains('do \$verify\$'));
      expect(sql, contains('rollback'));
      expect(sql, contains('enable row level security'));
      expect(sql, contains('has_function_privilege'));
      expect(sql, contains('from public, anon'));
      expect(sql, contains('set search_path = public, pg_temp'));
    },
  );

  test(
    'T5: herkesten önce ve son soruda geçiş riski; yalnız istemci sayacı sınanıyordu',
    () {
      final sql = File(
        'supabase/2026-10-30_gecis_ritmi.sql',
      ).readAsStringSync();
      // Göç tüm RPC'yi yeniden yazmaz: tek süre ifadesini değiştirir.
      // Üyelik, cevap sayısı, deadline, CAS ve terminal dalı aynen kalır.
      expect(sql, contains("v_revealed_at + interval '5 seconds'"));
      expect(
        sql,
        contains(
          'v_revealed_at + public.room_reveal_delay(v_room.is_custom, v_room.max_players)',
        ),
      );
      expect(sql, contains("interval '3 seconds'"));
      expect(sql, contains("interval '4 seconds'"));
      expect(sql, contains("'current_question_reveal_ends_at'"));
      expect(sql, contains('rq.revealed_at + public.room_reveal_delay'));
      expect(
        sql,
        contains('rq.question_index = v_room.current_question_index'),
      );
      expect(
        sql,
        isNot(
          contains('create or replace function public.advance_room_question'),
        ),
      );
      expect(sql, isNot(contains('update public.rooms')));
    },
  );
}
