import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

void main() {
  test('Supabase local room shell does not include mock opponents', () {
    final repository = SupabaseZanKurdRepository(
      SupabaseClient('https://example.supabase.co', 'sb_publishable_test_key'),
    );

    final room = repository.createRoom();
    final names = room.players.map((player) => player.name).toSet();

    expect(names, contains('Tu'));
    expect(names, isNot(contains('Rojda')));
    expect(names, isNot(contains('Baran')));
    expect(names, isNot(contains('Dilan')));
  });

  test('online room join uses the room-code RPC contract', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, contains("'join_room_by_code'"));
    expect(
      source,
      isNot(contains(".from('rooms')\n        .select('id, code")),
    );
  });

  test('online multiplayer SQL patch defines required live RPCs', () {
    final sql = File(
      'supabase/online_multiplayer_ready.sql',
    ).readAsStringSync();

    expect(sql, contains('function public.join_room_by_code'));
    expect(sql, contains('function public.start_room_game'));
    expect(sql, contains('function public.finish_room_game'));
    expect(sql, contains('function public.submit_answer'));
    expect(sql, contains('grant execute on function public.join_room_by_code'));
  });

  test('question queries include localized explanation columns', () {
    // explanation_ku/tr kolonları 2026-07-03_reward_hardening.sql ile
    // canlı DB'ye eklendi; soru kolon listeleri (tek sabit:
    // _questionColumns) artık ikisini de SEÇMELİ ki DB'ye girilen
    // dile özel açıklamalar kullanıcıya ulaşsın.
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    final columnLists = RegExp(r"'([^']*correct_option[^']*)'")
        .allMatches(source)
        .map((match) => match.group(1)!)
        .where((columns) => columns.contains('prompt'));

    expect(columnLists, isNotEmpty);
    for (final columns in columnLists) {
      expect(columns, contains('explanation_ku'));
      expect(columns, contains('explanation_tr'));
      expect(columns, contains('question_type'));
      expect(columns, contains('image_url'));
    }
  });

  test('submit answer forwards measured response time to the RPC', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, contains("'p_response_ms': responseMs"));
    expect(source, isNot(contains("'p_response_ms': 2000")));
  });

  test(
    'MockZanKurdRepository implements subscribeRoomBroadcast and sendRoomBroadcast',
    () async {
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
        ),
      );

      expect(
        () => repository.subscribeRoomBroadcast('room_123'),
        returnsNormally,
      );
      await expectLater(
        repository.sendRoomBroadcast('room_123', {'test': 'data'}),
        completes,
      );
    },
  );
}
