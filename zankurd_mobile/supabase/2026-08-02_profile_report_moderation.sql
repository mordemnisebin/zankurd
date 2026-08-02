-- ZanKurd — profil (avatar + görünen ad) bildirimi ve engelin genişletilmesi
--
-- SORUN (2026-08-02 denetimi, A-05 -> P1-008)
--
-- Avatar fotoğrafı bir GÖRSEL UGC yüzeyidir ve yabancılara gösterilir:
-- liderlik (`leaderboard_screen.dart`), eşleştirmede rakip
-- (`matchmaking_screen.dart`), oda sohbeti ve turnuva tablosu. Buna karşın:
--
--   * Süzme yok — kova yalnız MIME türü (jpeg/png/webp) ve 2 MB sınırı
--     uyguluyor; içerik denetimi hiç yok.
--   * Bildirme yok — `report_room_message` yalnız sohbet MESAJINI bildiriyor;
--     avatarı ya da adı bildirmenin hiçbir yolu yoktu.
--   * Engelleme etkisiz — `block_player` yalnız sohbeti süzüyordu; engellenen
--     kullanıcının avatarı liderlikte ve eşleştirmede görünmeye devam
--     ediyordu.
--
-- Apple Guideline 1.2 dört şey ister: süzme, bildirme, engelleme ve
-- yayınlanmış iletişim. Avatar/ad yüzeyi için dördünden üçü eksikti.
-- (İletişim adresi zaten var: `AppConfig.supportEmail`.)
--
-- BU GÖÇ NE GETİRİR
--
--   1. `profile_reports` tablosu — kim, kimi, hangi gerekçeyle bildirdi.
--   2. `report_player_profile(uuid, text)` RPC'si — bildirimi kaydeder ve
--      bildiren kullanıcı için ENGELİ de kurar (bildiren kişi bildirdiği
--      profili bir daha görmek zorunda kalmasın).
--   3. `leaderboard_entries` görünümünün engellenenleri süzen okuma yolu.
--
-- Kasıtlı olarak YAPMADIĞI: içeriği otomatik kaldırmak. Karar moderasyon
-- tarafındadır; istemci yalnız bildirir. `room_messages` bildirimi de aynı
-- deseni izliyor (`2026-07-31_chat_moderation.sql`).

-- ── Bildirim tablosu ─────────────────────────────────────────────────────
create table if not exists public.profile_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reported_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now(),
  -- Aynı kişiyi tekrar tekrar bildirip tabloyu şişirmek engellenir;
  -- moderasyon için tek kayıt yeterlidir.
  unique (reporter_id, reported_id)
);

alter table public.profile_reports enable row level security;

-- Bildiren yalnız KENDİ bildirimlerini görebilir. Kimsenin "beni kim
-- bildirdi" sorusunu sorabilmesi gerekmez.
drop policy if exists "own profile reports" on public.profile_reports;
create policy "own profile reports"
  on public.profile_reports for select
  to authenticated
  using (auth.uid() = reporter_id);

-- Doğrudan INSERT yok: yalnız RPC üzerinden yazılır (engel kurma adımı
-- atlanmasın diye).
revoke all on table public.profile_reports from public, anon, authenticated;

create index if not exists profile_reports_reported_idx
  on public.profile_reports (reported_id, created_at desc);

-- ── Bildirme RPC'si ──────────────────────────────────────────────────────
create or replace function public.report_player_profile(
  p_reported_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  -- Kendini bildirmek anlamsız; sessizce başarı dönmek yerine açıkça
  -- reddedilir ki istemci hatayı gösterebilsin.
  if v_uid = p_reported_id then
    return jsonb_build_object('success', false, 'error', 'cannot report self');
  end if;

  if p_reported_id is null
     or not exists (select 1 from public.profiles where id = p_reported_id)
  then
    return jsonb_build_object('success', false, 'error', 'unknown profile');
  end if;

  insert into public.profile_reports (reporter_id, reported_id, reason)
  values (v_uid, p_reported_id, coalesce(nullif(btrim(p_reason), ''), 'unspecified'))
  on conflict (reporter_id, reported_id) do update
    set reason = excluded.reason,
        created_at = now();

  -- Bildiren kişi için engeli de kur: bildirdiği avatarı/adı bir daha
  -- görmek zorunda kalmamalı. Apple 1.2'nin "engelleme" maddesi ile
  -- "bildirme" maddesi kullanıcı gözünde tek bir eylemdir.
  insert into public.blocked_users (blocker_id, blocked_id)
  values (v_uid, p_reported_id)
  on conflict do nothing;

  return jsonb_build_object('success', true);
end;
$$;

revoke all on function public.report_player_profile(uuid, text)
  from public, anon;
grant execute on function public.report_player_profile(uuid, text)
  to authenticated;

-- ── Engellenenleri liderlikten süzen okuma yolu ──────────────────────────
--
-- Engel yalnız sohbette işliyordu; liderlik sorgusu engelli kullanıcıyı da
-- döndürüyordu, yani engellenen kişinin avatarı ve adı görünmeye devam
-- ediyordu. Bu fonksiyon istemcinin çağırdığı süzülmüş yoldur.
create or replace function public.leaderboard_visible(
  p_limit integer default 10
)
returns setof public.leaderboard_entries
language sql
stable
security definer
set search_path = public
as $$
  select le.*
  from public.leaderboard_entries le
  where not exists (
    select 1
    from public.blocked_users b
    where b.blocker_id = auth.uid()
      and b.blocked_id = le.player_id
  )
  order by le.total_score desc
  limit least(greatest(coalesce(p_limit, 10), 1), 100);
$$;

revoke all on function public.leaderboard_visible(integer) from public, anon;
grant execute on function public.leaderboard_visible(integer) to authenticated;

-- ── Uygulama sonrası doğrulama (elle çalıştırılır) ───────────────────────
--
-- select to_regclass('public.profile_reports') is not null as tablo_var;
--
-- select proname, prosecdef
-- from pg_proc p join pg_namespace n on n.oid = p.pronamespace
-- where n.nspname = 'public'
--   and proname in ('report_player_profile', 'leaderboard_visible');
--
--   beklenen: iki satır, ikisinde de prosecdef = true
--
-- select has_function_privilege('anon', 'public.report_player_profile(uuid, text)', 'execute');
--   beklenen: false
