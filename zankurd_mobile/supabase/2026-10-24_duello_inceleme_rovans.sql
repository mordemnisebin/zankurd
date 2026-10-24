-- 2026-10-24: DÜELLO İNCELEME + RÖVANŞ — `get_async_duel_review(p_duel_id)`.
--
-- Ürün sahibi onaylı QuizClash / Trivia Crack düzeni: biten bir düelloda
-- oyuncu 7 sorunun her birini yan yana görür — soru, doğru cevap, benim
-- cevabım (✓/✗, süre) ve rakibin cevabı (✓/✗, süre). Sonuç ekranındaki
-- "Rövanş" düğmesi aynı rakibe arkadaş meydan okuması açar
-- (`create_async_duel_challenge`, DEĞİŞMEZ); düğmenin açık olup olmadığını
-- bu RPC'nin `can_rematch` alanı söyler.
--
-- NEDEN SUNUCU: `async_duel_answers` / `async_duels` istemciye tamamen
-- kapalı (RLS + REVOKE); `questions.correct_option` ham dönmez. Bu RPC yeni
-- bir SELECT yolu açar, bu yüzden üç kapı vardır:
--   1) KATILIMCI: yalnız yaratıcı ya da eşleşmiş rakip ('Not a duel player').
--      Kabul edilmemiş davetli ya da yabancı okuyamaz.
--   2) BİTMİŞ: yalnız status 'completed' / 'expired' ('Duel not finished').
--      Süren düelloda rakibin cevapları ve doğru şıklar ASLA dönmez — oyuncu
--      rakibin cevabından ya da doğru şıktan kopya çekemez (oyun içi gizli
--      cevap ilkesi: bkz. 2026-09-28_async_duels.sql başlığı).
--   3) ENGEL: aramızda iki yönde engel varsa rakibin adı, kimliği VE
--      cevapları dönmez (`opponent_blocked` true); kendi incelemem yine
--      açılır. Engelli rakip için rövanş kapalıdır.
--
-- `can_rematch`: rakip var (profil silinmemiş), engel yok VE rakip kabul
-- edilmiş arkadaşım — `create_async_duel_challenge` arkadaş olmayana 'Not a
-- friend' verir, düğme boşuna basılmasın diye aynı koşul burada hesaplanır.
-- (Sunucuda bot rakibi yoktur: sırayla düello yalnız gerçek profillerle
-- eşleşir; "bot/bilinmeyen" = rakip kimliği boş.)
--
-- Yanıt:
--   { duel_id, status, forfeit, opponent_id, opponent_name,
--     opponent_blocked, opponent_is_friend, can_rematch,
--     questions: [ { index, prompt, option_a..option_d, question_type,
--                    correct_option,
--                    my:  { choice, correct, ms } | null,
--                    opp: { choice, correct, ms } | null } ... ] }
--   `choice`: 'A'..'D' ya da 'TIMEOUT' (süre doldu, her zaman yanlış).
--   `my`/`opp` null = o soruyu hiç cevaplamadı (hükmen kaybeden) ya da
--   (opp için) engel nedeniyle gizli.
--
-- Hata metinleri: 'Not authenticated', 'Duel not found', 'Not a duel
-- player', 'Duel not finished'.
--
-- Yeni fonksiyon (mevcut gövdelere dokunulmaz): canlı gövde kopyalamaya gerek
-- yok. İdempotent. Uygulama:
--   supabase db query --linked -f supabase/2026-10-24_duello_inceleme_rovans.sql
-- Kanıt (göçten önce ve sonra, kalıcı yazmaz):
--   supabase db query --linked -f supabase/kanit/2026-10-24_duello_inceleme_rovans_kanit.sql
-- Geri alma: `drop function public.get_async_duel_review(uuid);` (istemci
-- RPC yoksa bölümü gizler; başka hiçbir şey bağlı değil).

begin;

create or replace function public.get_async_duel_review(p_duel_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
  v_duel public.async_duels%rowtype;
  v_other uuid;
  v_blocked boolean := false;
  v_friend boolean := false;
  v_other_name text := null;
  v_show_other uuid := null;
  v_questions jsonb;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select d.* into v_duel
  from public.async_duels d
  where d.id = p_duel_id;

  if not found then
    raise exception 'Duel not found';
  end if;

  -- Kapı 1: yalnız düelloyu oynayan iki taraf.
  if v_uid is distinct from v_duel.creator_id
     and v_uid is distinct from v_duel.opponent_id then
    raise exception 'Not a duel player';
  end if;

  -- Kapı 2: yalnız bitmiş düello. Süresi geçmiş ama henüz süpürülmemiş
  -- ('matched' kalmış) düello da BİTMİŞ sayılmaz: süpürme (10 dk) sonucu ve
  -- hükmeni kesinleştirir, ondan önce hiçbir cevap açılmaz.
  if v_duel.status not in ('completed', 'expired') then
    raise exception 'Duel not finished';
  end if;

  v_other := case
    when v_duel.creator_id = v_uid then v_duel.opponent_id
    else v_duel.creator_id
  end;

  if v_other is not null then
    -- Kapı 3: iki yönlü engel.
    select exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = v_uid and b.blocked_id = v_other)
         or (b.blocker_id = v_other and b.blocked_id = v_uid)
    ) into v_blocked;

    if not v_blocked then
      v_show_other := v_other;
      select p.display_name into v_other_name
      from public.profiles p
      where p.id = v_other;

      select exists (
        select 1 from public.friends f
        where f.user_id = v_uid and f.friend_id = v_other
      ) into v_friend;
    end if;
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'index', o.idx - 1,
      'prompt', q.prompt,
      'option_a', q.option_a,
      'option_b', q.option_b,
      'option_c', q.option_c,
      'option_d', q.option_d,
      'question_type', q.question_type,
      'correct_option', q.correct_option,
      'my', case
        when mine.duel_id is null then null
        else jsonb_build_object(
          'choice', mine.choice,
          'correct', mine.is_correct,
          'ms', mine.response_ms
        )
      end,
      'opp', case
        when theirs.duel_id is null then null
        else jsonb_build_object(
          'choice', theirs.choice,
          'correct', theirs.is_correct,
          'ms', theirs.response_ms
        )
      end
    ) order by o.idx
  ), '[]'::jsonb)
  into v_questions
  from unnest(v_duel.question_ids) with ordinality as o(question_id, idx)
  join public.questions q on q.id = o.question_id
  left join public.async_duel_answers mine
    on mine.duel_id = v_duel.id
    and mine.player_id = v_uid
    and mine.question_index = o.idx - 1
  -- v_show_other engelde / rakipsizlikte NULL: eşleşme olmaz, cevaplar gizli.
  left join public.async_duel_answers theirs
    on theirs.duel_id = v_duel.id
    and theirs.player_id = v_show_other
    and theirs.question_index = o.idx - 1;

  return jsonb_build_object(
    'duel_id', v_duel.id,
    'status', v_duel.status,
    'forfeit', (v_duel.forfeit_loser_id is not null),
    'opponent_id', v_show_other,
    'opponent_name', v_other_name,
    'opponent_blocked', v_blocked,
    'opponent_is_friend', v_friend,
    'can_rematch', (v_show_other is not null and v_friend),
    'questions', v_questions
  );
end;
$function$;

revoke all on function public.get_async_duel_review(uuid)
  from public, anon;
grant execute on function public.get_async_duel_review(uuid)
  to authenticated;

commit;
