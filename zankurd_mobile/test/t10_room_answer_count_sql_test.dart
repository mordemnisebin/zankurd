import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/room.dart';

void main() {
  test('T10: yalnız sunucu fazı ve sayısı taşınır; eski RPC uyumludur', () {
    final state = RoomAnswerProgress.tryParse({
      'question_index': 7,
      'answered': 0,
      'active': 4,
      'revealed': true,
    })!;
    expect(state.answered, 0);
    expect(state.active, 4);
    expect(state.revealed, isTrue);
    expect(
      RoomAnswerProgress.tryParse({
        'question_index': 7,
        'answered': 2,
        'active': 4,
      })!.revealed,
      isFalse,
    );
  });
  test('T10: TIMEOUT cevap sayılmaz; yalnız canlı tanıma korumalı yama', () {
    final sql = File(
      'supabase/2026-10-30_t10_room_answer_count.sql',
    ).readAsStringSync();
    expect(sql, contains('pg_get_functiondef(v_oid)'));
    expect(sql, contains("pa.selected_option in ('A', 'B', 'C', 'D')"));
    expect(sql, contains('T10: unexpected answer count definition'));
    expect(sql, contains('T10: unexpected progress phase definition'));
    expect(sql, contains('rq.revealed_at is not null'));
    expect(sql, contains("'revealed', exists"));
    expect(sql, contains('T10: unexpected progress security definition'));
    expect(sql, contains('public.is_room_participant(p_room_id)'));
    expect(sql, contains('rp.left_at is null'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('set search_path = public, pg_temp'));
    expect(sql, isNot(contains('create or replace function')));
    expect(sql, isNot(contains('update public.rooms')));
    expect(sql, contains('begin;'));
    expect(sql.trim(), endsWith('commit;'));
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(applied, contains('2026-10-30_t10_room_answer_count.sql | ⏳'));
  });
}
