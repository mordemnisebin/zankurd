-- ZanKurd — arkadaş kimliği ve reddedilen isteğin yeniden gönderilmesi
-- ====================================================================
--
-- İleri yönlü göç. Uygulanmış hiçbir göç dosyası düzenlenmedi.
--
-- İki kusur, tek ortak kök: SUNUCU BİR YAZIMI HİÇ KULLANMIYOR YA DA
-- SESSİZCE YUTUYOR, İSTEMCİ İSE BUNU BAŞARI SAYIYOR.
--
--
-- 1) ARKADAŞ KİMLİĞİ — herkes "Player" görünüyordu
--
-- `add_friend(p_friend_id, p_friend_name)` istemciden bir ad alıyor ama
-- gövdesinde O PARAMETREYE HİÇ DOKUNMUYOR; sabit `'Player'` yazıyor.
-- `accept_friend_request` de karşı tarafa `'Player'` yazıyor. Temiz
-- üretim klonunda, gerçek adları Rojda ve Berfin olan iki kullanıcıyla:
--
--     friend_requests.from_user_name -> 'Player'
--     friends.friend_name (iki satır da) -> 'Player'
--
-- Sonuç: gelen istek kimden geldiği belli olmayan bir kart, kabul edilen
-- liste ise birbirinin aynı "Player" satırları.
--
-- İki onarım yolu vardı. YAZMA tarafını düzeltmek mevcut satırları
-- 'Player' bırakır ve ayrı bir backfill ister; üstelik kullanıcı adını
-- değiştirdiğinde kopya yine bayatlar. Bu yüzden OKUMA tarafı düzeltildi:
-- `list_friends` ve `list_pending_friend_requests` adı artık
-- `profiles`tan JOIN ile okuyor.
--
--   • Mevcut 'Player' satırları KENDİLİĞİNDEN düzelir — backfill'e gerek
--     yok, dolayısıyla üretim verisine dokunan bir UPDATE de yok.
--   • Ad değişikliği anında yansır.
--   • İstemcinin gönderdiği `p_friend_name` hiçbir yolda güvenilmez;
--     kimlik yalnız `auth.uid()` ile bağlanmış profilden gelir. Klonda
--     doğrulandı: `add_friend(..., 'Berfin-IMPOSTOR')` çağrısından sonra
--     alıcının gördüğü ad yine gerçek gönderenin adı ('Rojda') oldu.
--
-- Yazma tarafı da dürüstleştirildi (kolon artık bir yalan taşımasın):
-- saklanan ad profilden alınır, istemciden değil. Kolon kaldırılmadı,
-- çünkü profili silinmiş bir kullanıcı için son bilinen ad kalsın.
--
--
-- 2) REDDEDİLEN İSTEK BİR DAHA GÖNDERİLEMİYORDU
--
-- `(from_user_id, to_user_id)` benzersiz; `reject_friend_request` satırı
-- silmiyor yalnız 'rejected' yapıyor; `add_friend` ise
-- `ON CONFLICT DO NOTHING` ile sessizce hiçbir şey yapmayıp KOŞULSUZ
-- `TRUE, 'Friend request sent'` dönüyordu. Klonda:
--
--     add_friend -> success = t, 'Friend request sent'
--     friend_requests.status  -> hâlâ 'rejected'
--     alıcının gördüğü pending istek sayısı -> 0
--
-- Yani bir yanlış dokunuş, o yönde arkadaşlığı kalıcı olarak imkânsız
-- kılıyor ve gönderene tam tersi söyleniyordu.
--
-- Düzeltme: reddedilmiş/iptal edilmiş satır yeniden `pending` yapılabilir;
-- gerçekten hiçbir şey değişmediyse artık `FALSE` dönülür. `ON CONFLICT
-- ... DO UPDATE` tek ifadede çalıştığı için eşzamanlı iki istek yarışa
-- girmez.

begin;

-- ── 2) Arkadaşlık isteği: gerçek ad + reddedilmiş isteği yeniden gönderme ──
create or replace function public.add_friend(p_friend_id uuid, p_friend_name text)
returns table(success boolean, message text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
  v_display_name text;
  v_rows int;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return query select false, 'Authenticated user required'::text;
    return;
  end if;

  if v_user_id = p_friend_id then
    return query select false, 'Cannot add yourself as friend'::text;
    return;
  end if;

  if exists (
    select 1 from friends
    where (user_id = v_user_id and friend_id = p_friend_id)
       or (user_id = p_friend_id and friend_id = v_user_id)
  ) then
    return query select false, 'Already friends'::text;
    return;
  end if;

  -- Kimlik yalnız sunucudan. `p_friend_name` bilerek kullanılmıyor:
  -- istemciden gelen ad başka birinin adı olabilir. İmza, çağıran
  -- istemciler kırılmasın diye korundu.
  select display_name into v_display_name from profiles where id = v_user_id;

  insert into friend_requests (from_user_id, from_user_name, to_user_id, status)
  values (
    v_user_id,
    coalesce(nullif(btrim(v_display_name), ''), 'Yarîzan'),
    p_friend_id,
    'pending'
  )
  on conflict (from_user_id, to_user_id) do update
     set status = 'pending',
         from_user_name = excluded.from_user_name,
         created_at = now()
   where friend_requests.status is distinct from 'pending';

  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    -- Gerçekten hiçbir şey yazılmadı. Eskiden burada da TRUE dönülüyordu.
    return query select false, 'Friend request already pending'::text;
    return;
  end if;

  return query select true, 'Friend request sent'::text;
end;
$function$;

create or replace function public.accept_friend_request(p_request_id uuid)
returns table(success boolean, message text)
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
  v_from_user_id uuid;
  v_from_name text;
  v_my_name text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return query select false, 'Authenticated user required'::text;
    return;
  end if;

  select from_user_id into v_from_user_id
  from friend_requests
  where id = p_request_id and to_user_id = v_user_id and status = 'pending';

  if v_from_user_id is null then
    return query select false, 'Friend request not found or already processed'::text;
    return;
  end if;

  -- İki ad da profilden; istekteki kopya kimlik kaynağı değildir.
  select display_name into v_from_name from profiles where id = v_from_user_id;
  select display_name into v_my_name from profiles where id = v_user_id;

  insert into friends (user_id, friend_id, friend_name)
  values
    (v_user_id, v_from_user_id,
     coalesce(nullif(btrim(v_from_name), ''), 'Yarîzan')),
    (v_from_user_id, v_user_id,
     coalesce(nullif(btrim(v_my_name), ''), 'Yarîzan'))
  on conflict do nothing;

  update friend_requests set status = 'accepted' where id = p_request_id;

  return query select true, 'Friend request accepted'::text;
end;
$function$;

-- ── 3) Okuma tarafı: ad her zaman profilden ────────────────────────────
--
-- Mevcut 'Player' satırlarını backfill ETMEDEN düzeltir ve ad
-- değişikliklerini anında yansıtır. Profili silinmiş kullanıcıda
-- `friends.friend_name` son bilinen ad olarak yedekte kalır.
create or replace function public.list_friends()
returns table(
  id uuid,
  friend_id uuid,
  friend_name text,
  friend_avatar_color text,
  created_at timestamp with time zone
)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  return query
  select
    f.id,
    f.friend_id,
    coalesce(nullif(btrim(p.display_name), ''), f.friend_name),
    coalesce(p.avatar_color, f.friend_avatar_color),
    f.created_at
  from friends f
  left join profiles p on p.id = f.friend_id
  where f.user_id = v_user_id
  order by f.created_at desc;
end;
$function$;

create or replace function public.list_pending_friend_requests()
returns table(
  id uuid,
  from_user_id uuid,
  from_user_name text,
  created_at timestamp with time zone
)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_user_id uuid;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    return;
  end if;

  return query
  select
    fr.id,
    fr.from_user_id,
    coalesce(nullif(btrim(p.display_name), ''), fr.from_user_name),
    fr.created_at
  from friend_requests fr
  left join profiles p on p.id = fr.from_user_id
  where fr.to_user_id = v_user_id and fr.status = 'pending'
  order by fr.created_at desc;
end;
$function$;

commit;

-- Doğrulama (salt okunur):
--
--   select 'add_friend has no hardcoded name' as check,
--          pg_get_functiondef(oid) not like '%Player%' as ok
--     from pg_proc where proname = 'add_friend';
--
--   select 'list_friends joins profiles' as check,
--          pg_get_functiondef(oid) like '%join profiles%' as ok
--     from pg_proc where proname = 'list_friends';
