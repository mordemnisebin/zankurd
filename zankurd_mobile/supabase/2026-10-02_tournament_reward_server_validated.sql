-- 2026-10-02: turnuva şampiyonluk ödülü, istemcinin bildirdiği skora
-- dayanamaz (güvenlik denetimi H2).
--
-- KUSUR: `submit_tournament_match(p_match_id, p_score)` skoru istemciden
-- alır; tek sınır `questions_per_match * 150` tavanıdır. Kazanan bu
-- skorlarla belirlenir, eşitlikte "daha erken gönderen" kazanır. Yani tavan
-- skoru hızla gönderen oyuncu her maçı kazanır, şampiyon olur ve
-- `claim_tournament_reward()` 200 coin öder. Skor sunucuda yeniden
-- hesaplanamıyor (maç soruları oyuncuya özel sunucu oturumu değil).
--
-- NEDEN REVOKE DEĞİL: mağazadaki ESKİ sürüm (468ea4a4) Yarış sekmesinde
-- turnuvayı BAYRAKSIZ gösteriyor ve `join_tournament`,
-- `get_tournament_bracket`, `save_tournament_progress`,
-- `submit_tournament_match`, `claim_tournament_reward` RPC'lerini çağırıyor.
-- Güncel istemci (`kTournamentEnabled = false`) ekranı hiç göstermiyor ama
-- kod yerinde. EXECUTE'u kapatmak eski sürümde hata ekranı üretirdi.
--
-- DÜZELTME: ödül, turnuvanın `scores_server_validated = true` işaretli
-- olmasına bağlanır. Sütun varsayılan `false`; mevcut ve eski istemciyle
-- oynanacak hiçbir turnuva işaretlenmez, dolayısıyla istemci skoruyla
-- kazanılan şampiyonluk coin getirmez. Eski istemci `claim_tournament_reward`
-- çağrısında `{"amount": 0, "already_claimed": false}` alır ve `0` olarak
-- işler (hata yok). Canlıda 3 biten turnuva, 0 ödenmiş şampiyonluk vardı.
--
-- TURNUVA YENİDEN AÇILIRKEN (sunucu doğrulamalı yeniden yazım): maç soruları
-- sunucu oturumunda dağıtılıp skor `submit_answer` benzeri sunucu kayıtlı
-- cevaplardan hesaplanmalı; ancak o zaman ilgili turnuvanın
-- `scores_server_validated` değeri turnuva AÇILIRKEN (`join_tournament` içinde
-- `insert into tournaments`) true yapılır. `submit_tournament_match` istemci
-- skorunu hâlâ kabul eder; bu migration onu bilerek DEĞİŞTİRMEZ (eski
-- istemci kırılmasın), yalnız parayı keser.
--
-- GERİ ALMA: eski gövde `2026-07-26_real_player_tournament.sql`de;
-- `alter table public.tournaments drop column scores_server_validated`.

begin;

alter table public.tournaments
  add column if not exists scores_server_validated boolean not null default false;

create or replace function public.claim_tournament_reward()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_tournament uuid;
  v_reason text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('amount', 0, 'error', 'profile missing');
  end if;

  -- Yalnız skorları SUNUCUDA doğrulanmış turnuvalar ödül verir. İstemci
  -- skoruyla kazanılan şampiyonluk (`scores_server_validated = false`)
  -- ödemez; bkz. dosya başı.
  select t.id into v_tournament
  from public.tournaments t
  where t.status = 'finished'
    and t.champion_id = v_uid
    and t.scores_server_validated
    and not exists (
      select 1
      from public.coin_transactions ct
      where ct.player_id = v_uid
        and ct.reason = 'tournament_champion:' || t.id::text
    )
  order by t.finished_at desc
  limit 1;

  if v_tournament is null then
    return jsonb_build_object('amount', 0, 'already_claimed', false);
  end if;

  v_reason := 'tournament_champion:' || v_tournament::text;
  if exists (
    select 1 from public.coin_transactions
    where player_id = v_uid and reason = v_reason
  ) then
    return jsonb_build_object('amount', 0, 'already_claimed', true);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, 200, v_reason);

  return jsonb_build_object('amount', 200, 'already_claimed', false);
end;
$$;

-- ACL korunur (create or replace dokunmaz); yine de açıkça sabitle.
revoke all on function public.claim_tournament_reward() from public, anon;
grant execute on function public.claim_tournament_reward() to authenticated;

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tournaments'
      and column_name = 'scores_server_validated'
      and column_default = 'false'
  ) then
    raise exception 'tournaments.scores_server_validated yok ya da varsayılan false değil';
  end if;
  if pg_get_functiondef('public.claim_tournament_reward()'::regprocedure)
       not like '%t.scores_server_validated%' then
    raise exception 'claim_tournament_reward doğrulama bayrağını aramıyor';
  end if;
  if exists (select 1 from public.tournaments where scores_server_validated) then
    raise exception 'beklenmedik: doğrulanmış işaretli turnuva var';
  end if;
  if has_function_privilege('anon', 'public.claim_tournament_reward()', 'execute') then
    raise exception 'claim_tournament_reward anon''a açık';
  end if;
  if not has_function_privilege('authenticated', 'public.claim_tournament_reward()', 'execute') then
    raise exception 'claim_tournament_reward authenticated''a kapalı (eski istemci kırılır)';
  end if;
end $$;

commit;
