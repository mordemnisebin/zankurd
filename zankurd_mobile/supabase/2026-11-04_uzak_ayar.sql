-- Uzak çalışma ayarı (2026-11-04). CANLIYA UYGULANMADI.
--
-- Niçin: 10 bin+ kullanıcıya hazırlık denetimi (olcek_* bulguları): özellik
-- bayrakları derleme-zamanı sabitiydi ve zorunlu güncelleme yoktu. Bir
-- özellik (sırayla düello, turnuva, kalabalık oda, sohbet, push v2, paylaşım
-- meydan okuması, seri kurtarma) canlıda sorun çıkarırsa onu kapatmanın tek
-- yolu yeni sürüm yayınlamak ve mağaza incelemesini beklemekti. Bu tablo
-- tek satırdır; istemci açılışta okur (ağ yoksa önbellek/güvenli varsayılan:
-- her şey AÇIK, zorunlu güncelleme YOK).
--
-- Güvenlik: RLS açık; anon ve authenticated yalnız SELECT. İstemci yazamaz;
-- değer yalnız SQL editöründen/servis anahtarıyla değişir. Satır tekildir
-- (id = 1 denetimi). Tabloda gizli veri yoktur.
--
-- Kullanım örneği (kapatma): update public.app_runtime_config
--   set async_duel_enabled = false, updated_at = now() where id = 1;
-- Zorunlu güncelleme: min_supported_build_ios / _android'i yeni build
-- numarasına çek. latest_build_* eski sürümde yumuşak bant gösterir.
-- GERİ ALMA: geri_al/2026-11-04_uzak_ayar_geri.sql
begin;

create table if not exists public.app_runtime_config (
  id smallint primary key default 1 check (id = 1),
  min_supported_build_ios integer not null default 0 check (min_supported_build_ios >= 0),
  min_supported_build_android integer not null default 0 check (min_supported_build_android >= 0),
  latest_build_ios integer not null default 0 check (latest_build_ios >= 0),
  latest_build_android integer not null default 0 check (latest_build_android >= 0),
  maintenance_message_tr text,
  maintenance_message_ku text,
  async_duel_enabled boolean not null default true,
  tournament_enabled boolean not null default true,
  crowd_rooms_enabled boolean not null default true,
  chat_enabled boolean not null default true,
  push_v2_enabled boolean not null default true,
  share_challenge_enabled boolean not null default true,
  streak_rescue_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.app_runtime_config enable row level security;

drop policy if exists app_runtime_config_read on public.app_runtime_config;
create policy app_runtime_config_read on public.app_runtime_config
  for select to anon, authenticated using (true);

revoke all on table public.app_runtime_config from public, anon, authenticated;
grant select on table public.app_runtime_config to anon, authenticated;

-- Mevcut değerler: zorunlu/yumuşak güncelleme KAPALI (0), bütün özellikler açık.
insert into public.app_runtime_config (id) values (1) on conflict (id) do nothing;

commit;
