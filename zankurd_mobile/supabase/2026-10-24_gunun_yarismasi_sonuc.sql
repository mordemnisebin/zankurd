-- 2026-10-24: GÜNÜN YARIŞMASI SONUCU (bugünün sıralaması + dünün birincisi).
--
-- ## Kusur
--
-- "Günün turu" (ContestScreen) bir sonuç kaydı bırakmıyordu: tur
-- `contestId: null` ile açılır, `submit_contest_entry` bilerek yazmaz
-- (istemci beyanı doğrulanamaz) ve `getContestLeaderboard` boş döner. Yani
-- tur bitince oyuncu kimin nasıl yaptığını göremezdi; "yarışma" yalnız adıydı.
--
-- ## Karar
--
-- Sıralama YALNIZ GÖSTERİMDİR: ödül, XP, jeton ya da lig puanı bağlanmaz.
-- Bu yüzden istemcinin bildirdiği sonuç doğrulanmasa da kimsenin cüzdanına
-- dokunmaz; yine de kaba doğrulama var (aşağıda). Doğrulanmış bir ödüllü
-- yarışma istenirse ayrı iş: sunucunun cevapları kendisi değerlendirmesi
-- gerekir.
--
--   * `daily_event_results`: gün (İstanbul `app_today()`) + oyuncu başına EN
--     FAZLA BİR satır — o günkü İLK bitiş sayılır ("Tekrar oyna" sıralamayı
--     değiştirmez, yoksa herkes sıralama tutturana dek yeniden oynardı).
--     Tablo istemciye KAPALI (RLS açık, politika yok, yetki yok).
--   * `submit_daily_event_result(p_correct, p_total, p_seconds)`: kimlik
--     şart; 1 <= toplam <= 20, 0 <= doğru <= toplam; süre 0..3600'e kırpılır.
--     İlk kayıtta true, tekrarda ya da geçersizde false (hata fırlatmaz:
--     tur sonu ekranı bu yüzden bozulmasın).
--   * `get_daily_event_board()`: tek jsonb — bugünün ilk üçü, çağıranın kendi
--     satırı ve sırası, dünün birincisi, bugünkü katılımcı sayısı, gün.
--     Yalnız herkese açık gösterim verisi: ad, doğru/toplam, süre. Çağıranın
--     engellediği oyuncular listede YOK (sıra numaraları da buna göre; aynı
--     kural `get_leaderboard`ta). Sıralama: doğru çok -> süre az -> önce biten.
--
-- Gün sınırı: `app_today()` = Europe/Istanbul (UTC+3, yaz saati yok). İstemci
-- geri sayımı da aynı sınırı kullanır (bkz. `nextContestResetAt`).
--
-- Geri alma:
--   drop function public.get_daily_event_board();
--   drop function public.submit_daily_event_result(integer, integer, integer);
--   drop table public.daily_event_results;

begin;

create table if not exists public.daily_event_results (
  day date not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  correct_count integer not null,
  total_count integer not null,
  seconds integer not null,
  created_at timestamptz not null default now(),
  primary key (day, user_id),
  constraint daily_event_results_range check (
    total_count between 1 and 20
    and correct_count between 0 and total_count
    and seconds between 0 and 3600
  )
);

create index if not exists daily_event_results_board_idx
  on public.daily_event_results (day, correct_count desc, seconds asc);

alter table public.daily_event_results enable row level security;
revoke all on table public.daily_event_results from public, anon, authenticated;

create or replace function public.submit_daily_event_result(
  p_correct integer, p_total integer, p_seconds integer
) returns boolean
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null
     or p_correct is null or p_total is null
     or p_total < 1 or p_total > 20
     or p_correct < 0 or p_correct > p_total then
    return false;
  end if;

  insert into public.daily_event_results
    (day, user_id, correct_count, total_count, seconds)
  values
    (public.app_today(), v_uid, p_correct, p_total,
     least(greatest(coalesce(p_seconds, 0), 0), 3600))
  on conflict (day, user_id) do nothing;

  return found;
end;
$function$;

revoke all on function public.submit_daily_event_result(integer, integer, integer)
  from public, anon;
grant execute on function public.submit_daily_event_result(integer, integer, integer)
  to authenticated;

create or replace function public.get_daily_event_board()
returns jsonb
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
  with t as (select public.app_today() as d),
  vis as (
    select
      r.day,
      r.user_id,
      r.correct_count,
      r.total_count,
      r.seconds,
      coalesce(nullif(btrim(p.display_name), ''), 'Oyuncu') as name,
      row_number() over (
        partition by r.day
        order by r.correct_count desc, r.seconds asc, r.created_at asc, r.user_id
      ) as rk
    from public.daily_event_results r
    cross join t
    left join public.profiles p on p.id = r.user_id
    where r.day in (t.d, t.d - 1)
      -- Engelleme: yalnız ÇAĞIRANIN engelleri uygulanır (tek yön).
      and not exists (
        select 1 from public.blocked_users b
        where b.blocker_id = auth.uid() and b.blocked_id = r.user_id
      )
  )
  select jsonb_build_object(
    'day', (select d from t),
    'participants', (select count(*) from vis where day = (select d from t)),
    'top', coalesce((
      select jsonb_agg(jsonb_build_object(
        'rank', rk, 'name', name, 'correct', correct_count,
        'total', total_count, 'seconds', seconds,
        'is_me', user_id = auth.uid()
      ) order by rk)
      from vis where day = (select d from t) and rk <= 3
    ), '[]'::jsonb),
    'me', (
      select jsonb_build_object(
        'rank', rk, 'name', name, 'correct', correct_count,
        'total', total_count, 'seconds', seconds, 'is_me', true
      )
      from vis where day = (select d from t) and user_id = auth.uid()
    ),
    'yesterday', (
      select jsonb_build_object(
        'rank', rk, 'name', name, 'correct', correct_count,
        'total', total_count, 'seconds', seconds,
        'is_me', user_id = auth.uid()
      )
      from vis where day = (select d from t) - 1 and rk = 1
    )
  );
$function$;

revoke all on function public.get_daily_event_board() from public, anon;
grant execute on function public.get_daily_event_board() to authenticated;

commit;
