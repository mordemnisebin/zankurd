import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Oda soruları ancak geçilmiş index'te correct_option taşır.
void main() {
  test('get_room_questions yalnız geçilmiş soruda şıkkı açar', () {
    final sql = File(
      'supabase/2026-09-06_get_room_questions_revealed.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.get_room_questions'),
    );
    expect(sql, contains('current_question_index'));
    expect(sql, contains("'correct_option'"));
    expect(sql, contains("rq.question_index < v_index"));
    expect(sql, contains("v_status = 'finished'"));
    expect(sql, contains('revoke all on function public.get_room_questions'));
    expect(sql, contains('from public, anon'));
  });
}
