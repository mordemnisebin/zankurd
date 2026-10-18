import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `2026-10-18_oda_davet.sql` göçünün metin bekçisi.
///
/// ## Kusur
///
/// Odaya arkadaş daveti yeni bir yazma yüzeyi açar (`room_invites`, üç RPC).
/// Sunucu davranışı yerelde çalıştırılamıyor (Docker/Postgres yok).
///
/// ## Niçin sessiz kalırdı
///
/// Bir sonraki "temiz" yeniden yazım istemciye doğrudan INSERT/UPDATE
/// yetkisi açabilir, engel/arkadaşlık denetimini düşürebilir ya da
/// `respond_room_invite`ı oda katılımını kendisi yapacak şekilde büyütüp
/// `join_room_by_code`un engel/doluluk/ücret kontrollerini atlayabilir.
/// Bu test sözleşmeyi metin olarak sabitler; çalışma zamanı kanıtı
/// `2026-10-18_oda_davet_duman.sql` (geri alınan işlem).
void main() {
  final sql = File('supabase/2026-10-18_oda_davet.sql').readAsStringSync();

  String body(String name) {
    final start = RegExp(
      'create or replace function public\\.$name\\(',
    ).firstMatch(sql);
    expect(start, isNotNull, reason: '$name tanımlı olmalı');
    final open = sql.indexOf(r'$function$', start!.start);
    final close = sql.indexOf(r'$function$', open + 1);
    return sql.substring(start.start, close);
  }

  test('tablo: tekil (oda, davetli), durum kümesi, RLS, yalnız SELECT', () {
    expect(sql, contains('references public.rooms(id) on delete cascade'));
    expect(sql, contains('unique (room_id, invitee_id)'));
    expect(sql, contains("'pending', 'accepted', 'declined', 'expired'"));
    expect(sql, contains('enable row level security'));
    expect(
      sql,
      contains(
        'revoke all on table public.room_invites from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains('grant select on table public.room_invites to authenticated'),
    );
    expect(sql, isNot(contains('grant insert')));
    expect(sql, isNot(contains('grant update')));
  });

  test(
    'invite_friends_to_room: üyelik, lobi, doluluk, arkadaşlık, engel, sınır',
    () {
      final b = body('invite_friends_to_room');
      expect(b, contains("v_room.status <> 'lobby'"));
      expect(b, contains('rp.left_at is null'));
      expect(b, contains("raise exception 'Room is full'"));
      expect(b, contains('from public.friends f'));
      expect(b, contains('from public.blocked_users b'));
      expect(b, contains('> 20'));
      expect(b, contains("interval '1 hour'"));
      expect(b, contains('> 100'));
      expect(b, contains("'room_invite'"));
      expect(b, contains('on conflict (room_id, invitee_id) do update'));
    },
  );

  test(
    'respond_room_invite KATILIMI YAPMAZ: kodu döndürür, join_room_by_code kalır',
    () {
      final b = body('respond_room_invite');
      expect(b, isNot(contains('insert into public.room_players')));
      expect(b, contains('return v_code'));
      expect(b, contains("'Invite expired'"));
      expect(b, contains('invitee_id = v_uid'));
    },
  );

  test('list_my_room_invites: 30 dk süre, engel süzgeci, yalnız lobi', () {
    final b = body('list_my_room_invites');
    expect(b, contains("interval '30 minutes'"));
    expect(b, contains("r.status = 'lobby'"));
    expect(b, contains('public.blocked_users'));
  });

  test('üç RPC de SECURITY DEFINER + sabit search_path, anon kapalı', () {
    for (final name in [
      'invite_friends_to_room',
      'list_my_room_invites',
      'respond_room_invite',
    ]) {
      final b = body(name);
      expect(b, contains('security definer'), reason: name);
      expect(b, contains('set search_path = public'), reason: name);
      expect(b, contains('auth.uid()'), reason: name);
    }
    expect(
      RegExp(
        r'revoke all on function public\.\w+\([^)]*\)\s+from public, anon',
      ).allMatches(sql).length,
      3,
    );
    expect(
      RegExp(
        r'grant execute on function[^;]*to authenticated',
      ).allMatches(sql).length,
      3,
    );
  });

  test('oda kodu biçimine bağımlılık yok (kod KAPALI bir dizgedir)', () {
    expect(sql, isNot(contains('ZK-')));
    expect(sql, isNot(contains('create_online_room')));
    expect(sql, isNot(contains('start_room_game')));
  });
}
