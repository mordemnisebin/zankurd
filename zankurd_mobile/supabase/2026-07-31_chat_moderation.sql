-- Oda sohbeti moderasyonu (forward-only, idempotent).
--
-- ## Niçin
--
-- Apple App Store Review Kılavuzu 1.2 ve Google Play'in UGC politikası,
-- kullanıcı üretimi içerik barındıran uygulamalarda dört şeyi zorunlu
-- kılar: içerik süzme, içerik bildirme, kullanıcı engelleme ve yayımlanmış
-- iletişim bilgisi.
--
-- 2026-07-31 denetiminde depoda dördü de yoktu; `sendRoomMessage` metni
-- yalnız `trim()` edip yazıyordu. Sohbet o sırada hiçbir ekranda mount
-- edilmediği için canlı bir risk değildi. Sohbet geri getirilirken bu göç
-- onunla birlikte geldi.
--
-- ## Niçin sunucuda da süzülüyor
--
-- İstemci tarafındaki `ChatModerationPolicy` kullanıcıya *niçin*
-- gönderilemediğini anında söylemek içindir. Tek başına yeterli değildir:
-- değiştirilmiş bir istemci doğrudan REST üzerinden yazabilir. Kural bu
-- yüzden BEFORE INSERT tetikleyicisiyle de kuruluyor.

begin;

-- ── Engellenen kullanıcılar ──────────────────────────────────────────
create table if not exists public.blocked_users (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocked_users_no_self check (blocker_id <> blocked_id)
);

alter table public.blocked_users enable row level security;

drop policy if exists "blocked_users_own" on public.blocked_users;
-- Yalnız kendi engel listeni görürsün ve yönetirsin.
create policy "blocked_users_own" on public.blocked_users
  for all
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

-- ── Mesaj bildirimleri ───────────────────────────────────────────────
create table if not exists public.message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.room_messages(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  created_at timestamptz not null default now(),
  -- Aynı kişi aynı mesajı bir kez bildirir.
  unique (message_id, reporter_id)
);

alter table public.message_reports enable row level security;

drop policy if exists "message_reports_insert_own" on public.message_reports;
create policy "message_reports_insert_own" on public.message_reports
  for insert
  with check (reporter_id = auth.uid());

-- Bildirimleri YALNIZ moderasyon (service_role) okur. Kullanıcı kendi
-- bildirdiğini bile listelemez: bildiren kişiyi görünür kılmak taciz
-- yüzeyini büyütür.
drop policy if exists "message_reports_read_none" on public.message_reports;

create index if not exists message_reports_message_idx
  on public.message_reports (message_id);

-- ── Sunucu tarafı içerik süzgeci ─────────────────────────────────────
--
-- Liste bilerek dar ve TAM SÖZCÜK eşleşmeli: geniş bir liste masum
-- metinleri de yakalar ("gu" → "gulan") ve kullanıcı sohbeti bırakır.
create or replace function public.chat_message_is_clean(p_text text)
returns boolean
language plpgsql
immutable
as $$
declare
  v_norm text;
  v_word text;
  v_blocked text[] := array[
    -- 'got' BİLEREK YOK: Kurmancîde "dedi" demek. Aynı gerekçeyle
    -- 'kere', 'heywan', 'gu' ve iki harfliler de dışarıda. İstemci
    -- tarafındaki liste ile aynı (chat_moderation_policy.dart).
    'orospu','pic','yavsak','sikeyim','siktir','amk','gavat',
    'serefsiz','ibne','pezevenk','yarrak','amina','sikik',
    'qehpik','qehbe','kerbeso','beseref'
  ];
begin
  if p_text is null or length(trim(p_text)) = 0 then
    return false;
  end if;
  if length(p_text) > 240 then
    return false;
  end if;
  -- Bağlantı: reklam ve oltalama yüzeyi.
  if p_text ~* '(https?://|www\.|[a-z0-9-]+\.(com|net|org|io|me|tk|ru|xyz))' then
    return false;
  end if;

  -- İstemcideki `_normalize` ile aynı sadeleştirme: aksan ve rakam
  -- kaçamakları düz hâle indirgenir.
  v_norm := lower(p_text);
  v_norm := translate(v_norm, 'ışğüöçîêû01345@', 'isguocieuoiesa');
  v_norm := regexp_replace(v_norm, '[^a-z]+', ' ', 'g');

  foreach v_word in array v_blocked loop
    if (' ' || v_norm || ' ') like ('% ' || v_word || ' %') then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

-- Süzgeç + kimlik zorlaması aynı tetikleyicide.
--
-- Gönderenin kimliği, adı ve zaman damgası İSTEMCİDEN geliyordu
-- (`sendRoomMessage` üçünü de insert gövdesine yazıyor). Yani bir oyuncu
-- başkasının adıyla ve istediği zaman damgasıyla mesaj yazabilirdi —
-- sohbette kimlik taklidi. Üçü de sunucuda yeniden yazılıyor: istemcinin
-- ne gönderdiğinin önemi kalmıyor (2026-07-31 denetimi).
create or replace function public.enforce_chat_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not public.chat_message_is_clean(new.text) then
    raise exception 'chat_message_rejected';
  end if;

  -- Yalnız odanın üyesi yazabilir.
  if not exists (
    select 1 from public.room_players rp
     where rp.room_id = new.room_id and rp.player_id = v_uid
  ) then
    raise exception 'not_a_room_member';
  end if;

  new.sender_id := v_uid;
  new.sender_name := coalesce(
    (select p.display_name from public.profiles p where p.id = v_uid),
    new.sender_name
  );
  new.created_at := now();
  new.text := trim(new.text);
  return new;
end;
$$;

drop trigger if exists room_messages_moderation on public.room_messages;
create trigger room_messages_moderation
  before insert on public.room_messages
  for each row execute function public.enforce_chat_moderation();

-- ── İstemci RPC'leri ─────────────────────────────────────────────────
create or replace function public.report_room_message(
  p_message_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  insert into public.message_reports (message_id, reporter_id, reason)
  values (p_message_id, auth.uid(), coalesce(nullif(trim(p_reason), ''), 'other'))
  on conflict (message_id, reporter_id) do nothing;
end;
$$;

create or replace function public.block_player(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if p_blocked_id = auth.uid() then
    raise exception 'cannot_block_self';
  end if;
  insert into public.blocked_users (blocker_id, blocked_id)
  values (auth.uid(), p_blocked_id)
  on conflict do nothing;
end;
$$;

create or replace function public.unblock_player(p_blocked_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  delete from public.blocked_users
   where blocker_id = auth.uid() and blocked_id = p_blocked_id;
end;
$$;

revoke all on function public.report_room_message(uuid, text) from public, anon;
grant execute on function public.report_room_message(uuid, text) to authenticated;
revoke all on function public.block_player(uuid) from public, anon;
grant execute on function public.block_player(uuid) to authenticated;
revoke all on function public.unblock_player(uuid) from public, anon;
grant execute on function public.unblock_player(uuid) to authenticated;

-- ── Odaya ait olmayan mesajları okumayı kapat ────────────────────────
--
-- `2026-07-13_shop_chat_suggestions.sql:99` `room_messages` için
-- `USING (true)` okuma politikası kuruyordu: oda kodu olmayan biri de
-- bütün odaların mesajlarını okuyabiliyordu. Üyelik şartı ekleniyor ve
-- engellenen göndericilerin mesajları süzülüyor.
drop policy if exists "room_messages_read" on public.room_messages;
create policy "room_messages_read" on public.room_messages
  for select
  using (
    exists (
      select 1 from public.room_players rp
       where rp.room_id = room_messages.room_id
         and rp.player_id = auth.uid()
    )
    and not exists (
      select 1 from public.blocked_users b
       where b.blocker_id = auth.uid()
         and b.blocked_id = room_messages.sender_id
    )
  );

commit;
