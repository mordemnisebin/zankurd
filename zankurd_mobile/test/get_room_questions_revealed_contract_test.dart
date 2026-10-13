import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Oda soruları ancak geçilmiş index'te correct_option taşır.
///
/// 2026-07-21 notu başlıkta “istemciye açık” ve gövdede “canlıya
/// basılmadan önce” diyordu; 2026-07-22 REVOKE ve 2026-09-06 reveal
/// applied.md’de dururken not güncel kaynak gibi okunuyordu.
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

  test('tarihî exposure notu canlı açık iddiası taşımaz', () {
    final note = File(
      'supabase/2026-07-21_correct_option_exposure_NOTE.md',
    ).readAsStringSync();

    expect(note, contains('TARİHÎ'));
    expect(note, contains('güncel kaynak değil'));
    expect(note, contains('REVOKE SELECT'));
    expect(note, contains('applied.md'));
    expect(
      note,
      isNot(contains('# correct_option istemciye açık —')),
      reason:
          'Başlık hâlâ şimdiki zamanla “açık” derse not kaynak gibi okunur.',
    );
    expect(
      note.toLowerCase(),
      isNot(contains('canlıya basılmadan önce')),
      reason:
          '2026-09-06 reveal applied.md’de canlı; not güncel kaynak gibi '
          'okunmasın.',
    );
  });
}
