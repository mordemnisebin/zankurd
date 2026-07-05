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

  test('room player queries preserve avatar showcase fields', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('profiles(display_name, avatar_icon, avatar_color'),
    );
    expect(source, contains("avatarIcon: profile?['avatar_icon'] as String?"));
    expect(
      source,
      contains("avatarColor: profile?['avatar_color'] as String?"),
    );
    expect(source, contains("avatarUrl: profile?['avatar_url'] as String?"));
    expect(
      source,
      contains("avatarFrame: profile?['avatar_frame'] as String?"),
    );
    expect(
      source,
      contains("showcaseTitle: profile?['showcase_title'] as String?"),
    );
  });

  test('matchmaking screen renders matched opponent with avatar identity', () {
    final source = File(
      'lib/src/screens/matchmaking_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_opponentIdentity'));
    expect(source, contains('AvatarIdentity _identityFromPlayer'));
    expect(source, contains('photoUrl: _opponentIdentity.photoUrl'));
    expect(source, contains('iconId: _opponentIdentity.iconId'));
    expect(source, contains('colorHex: _opponentIdentity.colorHex'));
    expect(source, contains('frameId: _opponentIdentity.frameId'));
  });

  test('live scoreboard renders player avatar identity', () {
    final source = File(
      'lib/src/screens/quiz/quiz_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('PlayerAvatar('));
    expect(source, contains('photoUrl: player.avatarUrl'));
    expect(source, contains('iconId: player.avatarIcon'));
    expect(source, contains('colorHex: player.avatarColor'));
    expect(source, contains('frameId: player.avatarFrame'));
  });

  test('duel score header renders both player avatars', () {
    final source = File(
      'lib/src/screens/quiz/quiz_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('required this.player'));
    expect(source, contains('required this.opponent'));
    expect(source, contains('photoUrl: player.avatarUrl'));
    expect(source, contains('photoUrl: opponent.avatarUrl'));
    expect(source, isNot(contains('Icons.android')));
  });

  test('quiz result standings render player avatar identity', () {
    final source = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PlayerAvatar('));
    expect(source, contains('photoUrl: player.avatarUrl'));
    expect(source, contains('iconId: player.avatarIcon'));
    expect(source, contains('colorHex: player.avatarColor'));
    expect(source, contains('frameId: player.avatarFrame'));
  });

  test(
    'avatar showcase SQL migration defines profile fields and storage policy',
    () {
      final sql = File(
        'supabase/2026-07-05_avatar_showcase.sql',
      ).readAsStringSync();

      expect(sql, contains('alter table public.profiles'));
      expect(sql, contains('avatar_icon'));
      expect(sql, contains('avatar_url'));
      expect(sql, contains('avatar_frame'));
      expect(sql, contains('showcase_title'));
      expect(sql, contains('Users update their own profile'));
      expect(sql, contains('using (id = auth.uid())'));
      expect(sql, contains("insert into storage.buckets"));
      expect(sql, contains("id = 'avatars'"));
      expect(sql, contains('bucket_id = \'avatars\''));
      expect(sql, contains('storage.foldername(name)'));
      expect(sql, contains('drop function if exists public.get_leaderboard'));
      expect(sql, contains('function public.get_leaderboard'));
      expect(sql, contains('avatar_color'));
      expect(sql, contains('grant execute on function public.get_leaderboard'));
    },
  );

  test('account deletion SQL removes user avatar storage objects', () {
    final sql = File('supabase/delete_my_account_rpc.sql').readAsStringSync();

    expect(sql, contains('delete from storage.objects'));
    expect(sql, contains("bucket_id = 'avatars'"));
    expect(sql, contains('storage.foldername(name)'));
    expect(sql, contains('v_user_id::text'));
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
