import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _executableSql(File migration) {
  return migration
      .readAsStringSync()
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
      .replaceAll(RegExp(r'--[^\n]*'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

String _functionBody(String sql, String functionName) {
  final marker = 'create or replace function public.$functionName';
  final start = sql.indexOf(marker);
  expect(start, isNonNegative, reason: '$functionName migration içinde yok');
  final nextFunction = sql.indexOf(
    'create or replace function public.',
    start + 1,
  );
  final commit = sql.indexOf(' commit;', start);
  final end = nextFunction >= 0 ? nextFunction : commit;
  expect(end, greaterThan(start), reason: '$functionName sınırı bulunamadı');
  return sql.substring(start, end);
}

void expectOrdered(String source, String first, String second) {
  final firstIndex = source.indexOf(first);
  final secondIndex = source.indexOf(second);
  expect(firstIndex, isNonNegative, reason: 'Eksik sözleşme: $first');
  expect(secondIndex, isNonNegative, reason: 'Eksik sözleşme: $second');
  expect(firstIndex, lessThan(secondIndex), reason: '$first önce çalışmalı');
}

void expectNoRoomUpdateLockAfterQueueLock(String source, String queueLock) {
  final queueLockIndex = source.indexOf(queueLock);
  expect(queueLockIndex, isNonNegative, reason: 'Queue kilidi bulunamadı');
  expect(
    source.substring(queueLockIndex + queueLock.length),
    isNot(contains('for update of r')),
    reason: 'Queue kilidinden sonra room FOR UPDATE deadlock riski taşır',
  );
}

void main() {
  final migration = File(
    'supabase/2026-08-02_multiplayer_session_hardening.sql',
  );
  late String sql;

  setUpAll(() {
    sql = _executableSql(migration);
  });

  test('oda oluşturma tek RPC ile atomiktir ve doğrudan insert kapalıdır', () {
    final create = _functionBody(sql, 'create_online_room');

    expect(
      sql,
      contains(
        'drop policy if exists "players can join as themselves" on public.room_players',
      ),
    );
    expect(
      sql,
      isNot(contains('create policy "players can join as themselves"')),
    );
    expect(
      sql,
      contains(
        'revoke insert on public.rooms from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'revoke insert on public.room_players from public, anon, authenticated',
      ),
    );
    expect(create, contains('p_seconds_per_question not in (20, 30, 45, 60)'));
    expect(create, contains('c.is_active = true'));
    expect(
      create,
      contains('pg_advisory_xact_lock(hashtextextended(v_uid::text, 0))'),
    );
    expect(create, contains("r.status in ('lobby', 'active')"));
    expect(create, contains("'status', v_existing.status"));
    expectOrdered(
      create,
      "r.status in ('lobby', 'active')",
      'insert into public.rooms',
    );
    expectOrdered(
      create,
      'insert into public.rooms',
      'insert into public.room_players',
    );
    expect(create, contains('values (v_room_id, v_uid, true)'));
    expect(
      sql,
      contains(
        'grant execute on function public.create_online_room(text, integer) to authenticated',
      ),
    );
  });

  test('canlı oda hostu zorunlu kalırken bitmiş oda hostu anonimleşebilir', () {
    final start = _functionBody(sql, 'start_room_game');

    expect(
      sql,
      contains('alter table public.rooms alter column host_id drop not null'),
    );
    expect(
      sql,
      contains(
        'foreign key (host_id) references public.profiles(id) on delete set null',
      ),
    );
    expect(
      sql,
      contains(
        "check (status not in ('lobby', 'active') or host_id is not null)",
      ),
    );
    expect(start, contains('if v_room.host_id is distinct from v_uid then'));
    expect(start, isNot(contains('v_room.host_id <> v_uid')));
  });

  test('oda sorgularını destekleyen üyelik ve lobby kod indeksleri vardır', () {
    expect(
      sql,
      contains(
        'create index if not exists room_players_player_room_idx on public.room_players (player_id, room_id)',
      ),
    );
    expect(
      sql,
      contains(
        "create unique index if not exists rooms_lobby_upper_code_uidx on public.rooms (upper(code)) where status = 'lobby'",
      ),
    );
  });

  test(
    'üyelik oluşturan üç yol aynı global kilitten sonra live check yapar',
    () {
      const membershipLock =
          "pg_advisory_xact_lock(hashtextextended('room-membership', 0))";

      for (final body in [
        _functionBody(sql, 'create_online_room'),
        _functionBody(sql, 'join_room_by_code'),
        _functionBody(sql, 'join_matchmaking'),
      ]) {
        expect(body, contains(membershipLock));
        expectOrdered(body, membershipLock, "r.status in ('lobby', 'active')");
      }
    },
  );

  test('katılma, hazır olma ve başlatma aynı oda kilidini kullanır', () {
    final join = _functionBody(sql, 'join_room_by_code');
    final ready = _functionBody(sql, 'set_room_ready');
    final start = _functionBody(sql, 'start_room_game');

    for (final body in [join, ready, start]) {
      expect(body, contains('from public.rooms r'));
      expect(body, contains('for update'));
    }
    expect(
      join,
      contains('pg_advisory_xact_lock(hashtextextended(v_uid::text, 0))'),
    );
    expect(join, contains('v_existing_room_id <> v_room.id'));
    expect(
      RegExp('for update of r').allMatches(join).length,
      1,
      reason: 'join yalnız hedef oda satırını update-lock etmelidir',
    );
    expect(join, contains('v_player_count >= 2'));
    expect(start, contains('v_player_count <> 2'));
    expect(start, contains('v_unready_count > 0'));
    expect(start, contains('v_host_member_count <> 1'));
    expect(start, contains('set quiz_ready_at = null'));
    expect(start, contains('null::timestamp with time zone'));
    expect(
      start,
      isNot(contains('when picked.question_index = 0 then v_server_now')),
    );
  });

  test('oda yalnız istenen soru sayısı tam üretildiyse atomik başlar', () {
    final start = _functionBody(sql, 'start_room_game');

    expect(start, contains('v_question_count <> v_room.question_count'));
    expect(start, contains("raise exception 'not enough approved questions"));
    expect(start, contains('question_count\', v_question_count'));
    expectOrdered(start, 'for update', 'v_server_now := clock_timestamp()');
  });

  test('ilk soru yalnız iki istemci sunucuya hazır olunca başlar', () {
    final ready = _functionBody(sql, 'mark_room_client_ready');
    final resume = _functionBody(sql, 'get_my_resumable_room');
    final submit = _functionBody(sql, 'submit_answer');

    expect(
      sql,
      contains(
        'alter table public.room_players add column if not exists quiz_ready_at timestamp with time zone',
      ),
    );
    expect(ready, contains('from public.rooms r'));
    expect(ready, contains('for update'));
    expect(ready, contains('rp.player_id = v_uid'));
    expect(
      ready,
      contains('quiz_ready_at = coalesce(rp.quiz_ready_at, v_server_now)'),
    );
    expect(ready, contains('rp.quiz_ready_at <= v_room.client_ready_deadline'));
    expect(ready, contains('v_player_count = 2'));
    expect(ready, contains('v_on_time_ready_count = 2'));
    expect(
      ready,
      contains('set started_at = coalesce(rq.started_at, v_server_now)'),
    );
    for (final field in [
      "'status'",
      "'server_now'",
      "'current_question_index'",
      "'current_question_started_at'",
      "'current_question_deadline'",
      "'current_question_remaining_ms'",
    ]) {
      expect(ready, contains(field), reason: 'Eksik ready alanı: $field');
    }
    expect(resume, contains('if v_current_started_at is not null then'));
    expect(submit, contains('if v_question_started_at is null then'));
    expect(submit, contains("raise exception 'room clients are not ready'"));
    expect(submit, isNot(contains('set started_at = coalesce(rq.started_at')));
  });

  test('quiz ready bariyeri iki dakikada terminal sonuca ulaşır', () {
    final start = _functionBody(sql, 'start_room_game');
    final ready = _functionBody(sql, 'mark_room_client_ready');

    expect(
      sql,
      contains(
        'alter table public.rooms add column if not exists client_ready_deadline timestamp with time zone',
      ),
    );
    expect(
      start,
      contains("client_ready_deadline = v_server_now + interval '2 minutes'"),
    );
    expect(ready, contains('v_room.client_ready_deadline'));
    expect(ready, contains('v_server_now >= v_room.client_ready_deadline'));
    expect(ready, contains("ended_reason = 'opponent_not_ready'"));
    expect(ready, contains('forfeited_by = v_not_ready_player_id'));
    expect(ready, contains('delete from public.matchmaking_queue mq'));
    expectOrdered(
      ready,
      "status = 'finished'",
      'delete from public.matchmaking_queue mq',
    );
    expect(
      ready,
      isNot(contains("quiz_ready_at >= v_server_now - interval '10 seconds'")),
    );
  });

  test('oda kodları UUID tabanlı en az kırk bit entropi taşır', () {
    for (final body in [
      _functionBody(sql, 'create_online_room'),
      _functionBody(sql, 'join_matchmaking'),
    ]) {
      expect(body, contains("replace(gen_random_uuid()::text, '-', '')"));
      expect(body, contains(', 1, 10'));
      expect(body, contains("v_room_code := 'zk-'"));
      expect(body, isNot(contains('v_alphabet')));
      expect(body, isNot(contains('floor(random()')));
    }
  });

  test('soru sonucu explicit reveal kapısıyla korunur', () {
    final start = _functionBody(sql, 'start_room_game');

    expect(
      sql,
      contains(
        'alter table public.room_questions add column if not exists revealed_at timestamp with time zone',
      ),
    );
    expect(
      sql,
      contains(
        'revoke select on public.player_answers from public, anon, authenticated',
      ),
    );
    expect(start, contains('set quiz_ready_at = null'));
    expect(start, contains('null::timestamp with time zone as revealed_at'));
  });

  test('eşleştirme tekrarında oyuncu kilitlenir ve mevcut oda döner', () {
    final matchmaking = _functionBody(sql, 'join_matchmaking');

    expect(
      matchmaking,
      contains('pg_advisory_xact_lock(hashtextextended(v_player_id::text, 0))'),
    );
    expect(
      matchmaking,
      contains(
        "pg_advisory_xact_lock(hashtextextended('matchmaking:' || lower(v_category_name), 0))",
      ),
    );
    expect(matchmaking, contains("r.status in ('lobby', 'active')"));
    expect(matchmaking, contains("'status', 'matched'"));
    expect(matchmaking, contains('mq.room_id is null'));
    expectOrdered(
      matchmaking,
      "r.status in ('lobby', 'active')",
      'delete from public.matchmaking_queue',
    );
    expect(matchmaking, contains('mq.room_id = v_queue_room_id'));
    expect(
      matchmaking,
      contains(
        "delete from public.matchmaking_queue mq where mq.room_id is null and upper(mq.category_name) = upper(v_category_name) and mq.joined_at < now() - interval '2 minutes'",
      ),
    );
  });

  test('eşleştirme iptali kilit altında eşleşmiş odayı silmeden döndürür', () {
    final cancel = _functionBody(sql, 'cancel_matchmaking');

    expect(cancel, contains('for update'));
    expect(cancel, contains('if v_room_id is not null then'));
    expect(cancel, contains("'status', 'matched'"));
    expectOrdered(
      cancel,
      'if v_room_id is not null then',
      'delete from public.matchmaking_queue',
    );
    expect(
      sql,
      contains(
        'revoke all on function public.cancel_matchmaking() from public, anon',
      ),
    );
    expect(
      sql,
      contains(
        'revoke insert, delete on public.matchmaking_queue from public, anon, authenticated',
      ),
    );
  });

  test('matchmaking queue doğrudan insert ve delete kabul etmez', () {
    expect(
      sql,
      contains(
        'drop policy if exists "allow insert own matchmaking queue entry" on public.matchmaking_queue',
      ),
    );
    expect(
      sql,
      contains(
        'revoke insert, delete on public.matchmaking_queue from public, anon, authenticated',
      ),
    );
  });

  test('hesap silme canlı oturumları bitirir ve rakibin kanıtını korur', () {
    final deleteAccount = _functionBody(sql, 'delete_my_account');
    const membershipLock =
        "pg_advisory_xact_lock(hashtextextended('room-membership', 0))";
    const userLock =
        'pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0))';

    expectOrdered(deleteAccount, membershipLock, userLock);
    expect(deleteAccount, contains("r.status in ('lobby', 'active')"));
    expect(deleteAccount, contains('order by r.id'));
    expect(deleteAccount, contains('for update of r'));
    expect(deleteAccount, contains("ended_reason = 'account_deleted'"));
    expect(deleteAccount, contains("ended_reason = 'host_left'"));
    expect(deleteAccount, contains('forfeited_by = v_user_id'));
    expect(deleteAccount, contains('delete from public.matchmaking_queue mq'));
    expect(deleteAccount, contains('delete from public.player_answers'));
    expect(deleteAccount, contains('delete from public.room_players'));
    expect(deleteAccount, contains('delete from auth.users'));
    expect(deleteAccount, isNot(contains('delete from public.rooms')));
    expectOrdered(
      deleteAccount,
      "status = 'finished'",
      'delete from public.player_answers',
    );
  });

  test('stale cleanup kanıt silmeden terminalize eder ve joined_at kullanır', () {
    final cleanup = _functionBody(sql, 'cleanup_stale_rooms');
    const membershipLock =
        "pg_advisory_xact_lock(hashtextextended('room-membership', 0))";

    expect(cleanup, contains(membershipLock));
    expect(cleanup, contains('order by r.id'));
    expect(cleanup, contains('for update of r skip locked'));
    expect(cleanup, contains("status = 'finished'"));
    expect(cleanup, contains("ended_reason = 'stale_timeout'"));
    expect(cleanup, contains('mq.joined_at'));
    expect(
      cleanup,
      contains("terminal_room.status not in ('lobby', 'active')"),
    );
    expect(cleanup, isNot(contains('mq.created_at')));
    expect(cleanup, isNot(contains('delete from public.player_answers')));
    expect(cleanup, isNot(contains('delete from public.room_players')));
    expect(cleanup, isNot(contains('delete from public.rooms')));
    expectOrdered(
      cleanup,
      "status = 'finished'",
      'delete from public.matchmaking_queue mq',
    );
    expect(
      sql,
      contains(
        'revoke all on function public.cleanup_stale_rooms() from public, anon, authenticated',
      ),
    );
  });

  test('terminal odadan ayrılma tarihsel üyeliği değiştirmeyen no-op olur', () {
    final leave = _functionBody(sql, 'leave_room');

    expect(leave, contains("v_room.status not in ('lobby', 'active')"));
    expectOrdered(
      leave,
      "v_room.status not in ('lobby', 'active')",
      'update public.room_players rp set is_ready = false',
    );
  });

  test(
    'normal bitiş matched queue satırlarını yalnız terminal durumda temizler',
    () {
      final finish = _functionBody(sql, 'finish_room_game');

      expect(finish, contains("status = 'finished'"));
      expect(finish, contains('delete from public.matchmaking_queue mq'));
      expect(finish, contains('mq.room_id = p_room_id'));
      expectOrdered(
        finish,
        "status = 'finished'",
        'delete from public.matchmaking_queue mq',
      );
    },
  );

  test('quiz ödülü yalnız gerçekten tamamlanmış oda için verilir', () {
    final reward = _functionBody(sql, 'claim_quiz_reward');

    expect(
      sql,
      contains(
        'drop policy if exists "hosts can update their own rooms" on public.rooms',
      ),
    );
    expect(
      sql,
      contains(
        'drop policy if exists "players update their own room membership" on public.room_players',
      ),
    );
    expect(
      sql,
      contains(
        'revoke update, delete on public.rooms from public, anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'revoke update, delete on public.room_players from public, anon, authenticated',
      ),
    );
    expect(reward, contains('for update of r'));
    expect(reward, contains('r.ended_reason'));
    expect(reward, contains('r.current_question_index'));
    expect(
      reward,
      contains("v_room_ended_reason is distinct from 'completed'"),
    );
    expect(reward, contains("'room_not_completed', true"));
    expect(reward, contains("'ended_reason', v_room_ended_reason"));
    expect(
      reward,
      contains('coalesce(v_current_question_index, -1) < v_total_questions'),
    );
    expect(reward, contains("'room_progress_incomplete', true"));
    expect(reward, contains('v_answer_count <> v_total_questions'));
    expect(reward, contains('coalesce(sum(pa.points_awarded), 0)::integer'));
    expect(reward, isNot(contains('greatest(coalesce(rp.score')));
    expect(
      reward,
      contains("v_reason := 'quiz_complete:room=' || p_room_id::text"),
    );
    expect(reward, contains("'already_claimed', true"));
    expect(reward, isNot(contains('coalesce(p_score')));
    expect(reward, isNot(contains('coalesce(p_correct_count')));
    expectOrdered(
      reward,
      "v_room_ended_reason is distinct from 'completed'",
      'insert into public.coin_transactions',
    );
  });

  test(
    'resume yalnız reveal edilmiş cevaplardan skor üretir ve pendingi ayırır',
    () {
      final resume = _functionBody(sql, 'get_my_resumable_room');

      for (final field in [
        "'own_score'",
        "'own_streak'",
        "'correct_count'",
        "'wrong_count'",
        "'best_streak'",
        "'answers'",
        "'pending_answer'",
        "'server_now'",
        "'current_question_started_at'",
        "'current_question_deadline'",
        "'current_question_remaining_ms'",
      ]) {
        expect(resume, contains(field), reason: 'Eksik resume alanı: $field');
      }
      expect(resume, contains('pa.player_id = v_uid'));
      expect(
        resume,
        contains(
          'rq.question_index < v_room.current_question_index or rq.revealed_at is not null',
        ),
      );
      expect(resume, contains("'question_id', rq.question_id"));
      expect(resume, contains("'points_awarded', pa.points_awarded"));
      expect(resume, contains("'correct_option', q.correct_option"));
      for (final field in [
        "'explanation', q.explanation",
        "'explanation_ku', q.explanation_ku",
        "'explanation_tr', q.explanation_tr",
      ]) {
        expect(
          resume,
          contains(field),
          reason: 'Eksik cevap açıklaması: $field',
        );
      }
      expect(resume, contains("'selected_option', pending.selected_option"));
      expect(resume, contains("'response_ms', pending.response_ms"));
      expect(resume, contains('pending_rq.revealed_at is null'));
      expect(resume, contains('sum(pa.points_awarded)'));
      expect(resume, isNot(contains('rp.score as own_score')));
      expect(resume, isNot(contains('rp.streak as own_streak')));
      expect(resume, isNot(contains("'current_correct_option'")));
    },
  );

  test('resume submit ile aynı room-first kilit sırasını korur', () {
    final resume = _functionBody(sql, 'get_my_resumable_room');

    expect(resume, contains('for share of r'));
    expect(resume, isNot(contains('for share of r, rp')));
  });

  test('ilk cevap pending yanıtında sonuç ve skor alanı sızdırmaz', () {
    final submit = _functionBody(sql, 'submit_answer');
    final pendingStart = submit.indexOf('if not v_revealable then');
    final pendingEnd = submit.indexOf('end if;', pendingStart);

    expect(pendingStart, isNonNegative);
    expect(pendingEnd, greaterThan(pendingStart));
    if (pendingStart < 0 || pendingEnd <= pendingStart) return;
    final pendingBranch = submit.substring(pendingStart, pendingEnd);
    for (final safeField in [
      "'accepted', true",
      "'pending', true",
      "'selected_option'",
      "'response_ms'",
      "'already_answered'",
    ]) {
      expect(pendingBranch, contains(safeField));
    }
    for (final forbiddenField in [
      "'correct_option'",
      "'is_correct'",
      "'points'",
      "'new_score'",
      "'new_streak'",
      "'explanation'",
      "'explanation_ku'",
      "'explanation_tr'",
    ]) {
      expect(
        pendingBranch,
        isNot(contains(forbiddenField)),
        reason: 'Pending yanıt sızdırıyor: $forbiddenField',
      );
    }
    expect(submit, contains('v_answer_count = 2'));
    expect(submit, contains('set revealed_at = coalesce(rq.revealed_at'));
    expect(submit, contains('perform public.recalculate_room_player_scores'));
    expect(submit, isNot(contains('update public.room_players')));
    expect(submit, contains('v_existing_answer record'));
    expect(submit, contains('into v_existing_answer'));
    expect(submit, isNot(contains('into p_selected_option')));
    expect(
      submit,
      contains('p_selected_option := v_existing_answer.selected_option'),
    );
    expectOrdered(
      submit,
      'insert into public.player_answers',
      'if not v_revealable then',
    );
  });

  test(
    'score helper iki cevap olmadan çalışmaz ve idempotent yeniden hesaplar',
    () {
      final helper = _functionBody(sql, 'recalculate_room_player_scores');

      expect(helper, contains('security definer'));
      expect(helper, contains('count(distinct pa.player_id)'));
      expect(helper, contains('v_answer_count <> 2'));
      expect(helper, contains('sum(answer.points_awarded)'));
      expect(helper, contains('update public.room_players rp'));
      expect(
        sql,
        contains(
          'revoke all on function public.recalculate_room_player_scores(uuid, uuid) from public, anon, authenticated',
        ),
      );
      expect(
        sql,
        isNot(
          contains(
            'grant execute on function public.recalculate_room_player_scores',
          ),
        ),
      );
    },
  );

  test('soru ilerletme oda kilidiyle sonraki sunucu başlangıcını yazar', () {
    final advance = _functionBody(sql, 'advance_room_question');
    final answerGuard = _functionBody(sql, 'enforce_current_room_question');

    expect(
      sql,
      contains('drop function if exists public.advance_room_question(uuid)'),
    );
    expect(advance, contains('p_expected_question_index integer'));
    expect(advance, contains('from public.rooms r'));
    expect(advance, contains('for update'));
    expect(advance, contains('rp.player_id = v_uid'));
    expect(advance, isNot(contains('v_room.host_id <> v_uid')));
    expect(
      advance,
      contains('p_expected_question_index < v_current_question_index'),
    );
    expect(
      advance,
      contains('p_expected_question_index > v_current_question_index'),
    );
    expectOrdered(
      advance,
      'v_current_question_index >= v_count',
      'p_expected_question_index < v_current_question_index',
    );
    expect(advance, contains('if v_answer_count <> 2'));
    expect(advance, contains('v_server_now >= v_deadline'));
    expect(advance, contains('insert into public.player_answers'));
    expect(advance, contains("'timeout', false, v_limit_ms, 0"));
    expect(advance, contains('on conflict do nothing'));
    expect(advance, contains('perform public.recalculate_room_player_scores'));
    expect(answerGuard, contains('v_server_timeout_allowed'));
    expect(answerGuard, contains('new.selected_option = \'timeout\''));
    expect(answerGuard, contains('new.is_correct is false'));
    expect(answerGuard, contains('new.points_awarded = 0'));
    expect(answerGuard, contains('clock_timestamp() >= rq.started_at'));
    expectOrdered(
      advance,
      'insert into public.player_answers',
      'set current_question_index = v_next',
    );
    expect(advance, contains('update public.room_questions rq'));
    expect(
      advance,
      contains('set started_at = coalesce(rq.started_at, v_server_now)'),
    );
    expect(advance, contains('revealed_at = null'));
    expect(advance, contains('rq.question_index = v_next'));
    expect(advance, contains("status = 'finished'"));
    expect(advance, contains("ended_reason = 'completed'"));
    expect(advance, contains('delete from public.matchmaking_queue mq'));
    expect(
      advance,
      contains("else update public.rooms r set status = 'finished'"),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.advance_room_question(uuid, integer) to authenticated',
      ),
    );
  });

  test('deadline reveal penceresi ilerletmeden önce beş saniye korunur', () {
    final advance = _functionBody(sql, 'advance_room_question');
    final revealPhase = advance.substring(
      advance.indexOf('if v_revealed_at is null then'),
    );

    expect(advance, contains('rq.revealed_at'));
    expect(advance, contains('if v_revealed_at is null then'));
    expect(advance, contains('set revealed_at = coalesce(rq.revealed_at'));
    expectOrdered(
      revealPhase,
      'set revealed_at = coalesce(rq.revealed_at',
      'return v_current_question_index',
    );
    expect(
      advance,
      contains("v_server_now < v_revealed_at + interval '5 seconds'"),
    );
    expectOrdered(
      revealPhase,
      "v_server_now < v_revealed_at + interval '5 seconds'",
      'set current_question_index = v_next',
    );
  });

  test('normal bitiş host yerine üyeliği ve terminal indeksi doğrular', () {
    final finish = _functionBody(sql, 'finish_room_game');

    expect(finish, contains('rp.player_id = v_uid'));
    expect(finish, isNot(contains('v_room.host_id <> v_uid')));
    expect(
      finish,
      contains(
        'coalesce(v_room.current_question_index, -1) < v_question_count',
      ),
    );
    expect(finish, contains("if v_room.status = 'finished' then"));
  });

  test('queue kilidinden sonra room update kilidi alınmaz', () {
    final matchmaking = _functionBody(sql, 'join_matchmaking');
    final cancel = _functionBody(sql, 'cancel_matchmaking');
    const joinQueueLock =
        'from public.matchmaking_queue mq where mq.player_id = v_player_id for update';
    const cancelQueueLock =
        'from public.matchmaking_queue mq where mq.player_id = v_uid for update';

    expectOrdered(matchmaking, 'for update of r', joinQueueLock);
    expectOrdered(cancel, 'for update of r', cancelQueueLock);
    expectNoRoomUpdateLockAfterQueueLock(matchmaking, joinQueueLock);
    expectNoRoomUpdateLockAfterQueueLock(cancel, cancelQueueLock);
  });

  test('cevap süresi istemci yerine soru deadlineından hesaplanır', () {
    final submit = _functionBody(sql, 'submit_answer');

    expect(submit, contains('clock_timestamp()'));
    expect(submit, contains('rq.started_at'));
    expect(submit, contains('v_deadline'));
    expect(submit, contains("p_selected_option := 'timeout'"));
    expect(submit, contains('v_response_ms'));
    expect(submit, contains("'response_ms', v_response_ms"));
    expect(
      submit,
      contains(
        '100 + round(v_remaining_ratio * 100)::integer + least(v_answer_streak * 10, 50)',
      ),
    );
    expect(submit, isNot(contains('coalesce(p_response_ms')));
    expect(submit, isNot(contains('least(p_response_ms')));
  });
}
