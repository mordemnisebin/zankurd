import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canlı oda denetimi gizli soruları doğrudan tablodan okumaz', () {
    final source = File('tools/check_live_supabase.py').readAsStringSync();

    expect(source, contains('/rest/v1/rpc/get_room_questions'));
    expect(source, contains('/rest/v1/rpc/advance_room_question'));
    expect(source, isNot(contains('/rest/v1/room_questions')));
  });

  test('canlı denetim tüm oda sorularını iki oyuncuyla oynatır', () {
    final source = File('tools/check_live_supabase.py').readAsStringSync();

    expect(source, contains('question_ids = load_room_questions'));
    expect(
      source,
      contains('for index, question_id in enumerate(question_ids)'),
    );
    expect(source, contains('submit_answer(user_a'));
    expect(source, contains('submit_answer(user_b'));
  });

  test('canlı denetim avatar güvenlik sözleşmesiyle uyumlu renk kullanır', () {
    final source = File('tools/check_live_supabase.py').readAsStringSync();

    expect(source, contains('"avatar_color": "#2E9E93"'));
    expect(source, isNot(contains('"avatar_color": "#E94560"')));
  });
}
