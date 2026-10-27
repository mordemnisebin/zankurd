-- Turnuva bekleme ekranına doluluk (2026-10-27).
--
-- Kusur: "Oyuncular bekleniyor" ekranı kaç kişinin katıldığını söylemiyordu;
-- 4 simülatörlü turda oyuncu kontenjanın ne kadar dolduğunu göremedi.
-- `get_tournament_bracket` artık `entryCount` ve `size` da döndürür.
-- Gövde canlı tanımdan (pg_get_functiondef) alındı; tek fark son iki alan.
begin;

CREATE OR REPLACE FUNCTION public.get_tournament_bracket()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_tournament public.tournaments;
  v_rounds jsonb;
  v_current_round int;
  v_max_round int;
  v_eliminated boolean;
  v_status text;
begin
  if v_user is null then
    raise exception 'Authenticated user required';
  end if;

  -- Ekran her açıldığında zamanı gelmiş işler yürütülür: süresi dolan
  -- maçlar hükmen kapanır, dolmayı bekleyen turnuvalar eldeki oyuncularla
  -- başlar. Ayrı bir zamanlayıcı gerekmez.
  perform public.resolve_expired_tournament_matches();
  perform public.start_due_tournaments();

  select t.* into v_tournament
    from public.tournaments t
    join public.tournament_entries e on e.tournament_id = t.id
   where e.player_id = v_user
   order by t.opened_at desc
   limit 1;

  if not found then
    return null;
  end if;

  select jsonb_agg(r order by r_round)
    into v_rounds
    from (
      select m.round as r_round,
             jsonb_build_object(
               'round', m.round,
               'matches', jsonb_agg(
                 jsonb_build_object(
                   'id', m.id,
                   'playerOneId', coalesce(m.player_one::text, ''),
                   'playerOneName', coalesce(e1.display_name, '—'),
                   'playerTwoId', coalesce(m.player_two::text, ''),
                   'playerTwoName', coalesce(e2.display_name, '—'),
                   'playerOneScore', coalesce(m.score_one, 0),
                   'playerTwoScore', coalesce(m.score_two, 0),
                   'status', m.status,
                   'winnerId', coalesce(m.winner_id::text, ''),
                   'deadline', m.deadline
                 ) order by m.slot
               )
             ) as r
        from public.tournament_matches m
        left join public.tournament_entries e1
               on e1.tournament_id = m.tournament_id
              and e1.player_id = m.player_one
        left join public.tournament_entries e2
               on e2.tournament_id = m.tournament_id
              and e2.player_id = m.player_two
       where m.tournament_id = v_tournament.id
       group by m.round
    ) rounds;

  -- `currentRound` istemcinin "benim maçım hangi turda" sorusunu yanıtlar
  -- ve tur adını (Son 16 / Çeyrek / Yarı / Final) seçer. Gönderilmezse 0'a
  -- düşer: ikinci turdaki oyuncu birinci turda aranır, maçı hiç bulunamaz
  -- ve ekran yanlış tur adını yazar. Sıfır tabanlıdır — istemci onu dizin
  -- olarak kullanır.
  select min(m.round) - 1
    into v_current_round
    from public.tournament_matches m
   where m.tournament_id = v_tournament.id
     and m.status <> 'completed'
     and v_user in (m.player_one, m.player_two);

  select max(m.round) into v_max_round
    from public.tournament_matches m
   where m.tournament_id = v_tournament.id;

  -- Açık maçı yoksa: ya elendi ya da kupa bitti. Elenmeyi turnuvanın
  -- bitmesine bağlamak yanlıştı — birinci turda kaybeden oyuncu, kupa
  -- sürerken hâlâ "maçın var" görüyordu.
  v_eliminated := v_current_round is null and exists (
    select 1 from public.tournament_matches m
     where m.tournament_id = v_tournament.id
       and m.status = 'completed'
       and v_user in (m.player_one, m.player_two)
       and coalesce(m.winner_id, '00000000-0000-0000-0000-000000000000'::uuid)
           <> v_user
  );

  if v_tournament.champion_id = v_user then
    v_status := 'won';
  elsif v_eliminated then
    v_status := 'eliminated';
  elsif v_tournament.status = 'finished' then
    v_status := 'eliminated';
  else
    v_status := 'active';
  end if;

  return jsonb_build_object(
    'tournamentId', v_tournament.id,
    'userId', v_user,
    'currentRound', coalesce(v_current_round,
                             greatest(coalesce(v_max_round, 1) - 1, 0)),
    'status', v_status,
    'createdAt', v_tournament.opened_at,
    'completedAt', v_tournament.finished_at,
    'rounds', coalesce(v_rounds, '[]'::jsonb),
    -- 2026-10-27: bekleme ekranı "1/4 oyuncu katıldı" diyebilsin. Yalnız
    -- sayı; kimin beklediği (ad) açık turnuvada paylaşılmaz.
    'entryCount', (select count(*) from public.tournament_entries e
                    where e.tournament_id = v_tournament.id),
    'size', v_tournament.size
  );
end;
$function$;

commit;
