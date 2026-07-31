-- Açıkta kalan üç okuma yüzeyini kapatır (forward-only, idempotent).
--
-- Üçü de 2026-07-31 denetiminde bulundu ve üçü de aynı desende: bir
-- sertleştirme yapılmış, ama sertleştirmenin *yanından dolanan* bir yol
-- açık kalmış.

begin;

-- ── 1) Editoryal yedek tabloları ────────────────────────────────────
--
-- İki editoryal göç `questions` tablosunun tam kopyalarını yedek olarak
-- bıraktı (`select * from questions`). Bu tablolarda ne RLS ne de
-- `revoke select` vardı. Supabase'in varsayılan yetkileri gereği `public`
-- şemasında oluşturulan yeni tablolar `anon` ve `authenticated` rollerine
-- açıktır.
--
-- 2026-07-22'de `questions` tablosundan doğru cevabı gizlemek için özel
-- olarak `revoke select on public.questions from public, anon,
-- authenticated` yapıldı ve istemci `quiz_public_questions` view'ına
-- taşındı. Ama bu iki yedek tablo o kapatmanın dışında kaldı ve
-- `correct_option` kolonunu aynen taşıyor — yani doğru cevaplar
-- sertleştirmenin arkasından dolanılarak okunabilir durumda olabilir.
--
-- Yedeklerin işi bitti: düzeltmeler 2026-07-18'de canlıda doğrulandı,
-- geri dönüş penceresi kapandı. En temizi silmek. `if exists` ile
-- idempotent; tablo yoksa (yerel kurulum) sorun çıkmaz.
drop table if exists public.questions_editorial_backup_20260716;
drop table if exists public.questions_editorial_backup_20260716_phase2;

-- Bundan sonrası için kural: `questions` kopyaları `public` şemasında
-- açılmaz. Ayrı bir şema, yalnız service_role'a açık.
create schema if not exists backup;
revoke all on schema backup from public, anon, authenticated;
comment on schema backup is
  'questions gibi hassas tabloların yedekleri buraya alınır. public '
  'şemasında açılan yedekler anon/authenticated rollerine otomatik açık '
  'olur ve doğru cevap gizlemesinin yanından dolanır (2026-07-31).';

-- ── 2) search_profiles: LIKE metakarakterleri ───────────────────────
--
-- `p.display_name ilike '%' || v_query || '%'` deseninde `v_query` yalnız
-- `trim` ediliyor, LIKE metakarakterleri (`%`, `_`, `\`) kaçırılmıyordu.
-- En az iki karakter şartını `%%` veya `a%` gibi desenlerle sağlayan bir
-- istemci, `limit 10` içinde alfabetik olarak tüm kullanıcı kütüğünü
-- sayfalayabiliyordu: arama kutusu bir kullanıcı listeleme aracına
-- dönüşüyordu.
--
-- Kaçırma + `escape` yan tümcesi: kullanıcının yazdığı `%` artık bir
-- joker değil, aranan harfin kendisi.
create or replace function public.search_profiles(p_query text)
returns table (
  id uuid,
  display_name text,
  avatar_color text,
  player_tag text
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_query text := trim(coalesce(p_query, ''));
  v_tag text := upper(v_query);
  v_pattern text;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if length(v_query) < 2 then
    return;
  end if;

  -- Ters bölü ÖNCE kaçırılır, yoksa kendisinden sonra eklenenleri bozar.
  v_pattern := '%' ||
    replace(replace(replace(v_query, '\', '\\'), '%', '\%'), '_', '\_') ||
    '%';

  return query
  select p.id, p.display_name, p.avatar_color, p.player_tag
  from public.profiles p
  where p.id <> v_user_id
    and (p.player_tag = v_tag or p.display_name ilike v_pattern escape '\')
  -- Kod eşleşmesi başa: birebir arayan, aradığını ilk satırda görür.
  order by (p.player_tag = v_tag) desc, p.display_name
  limit 10;
end;
$$;

revoke all on function public.search_profiles(text) from public, anon;
grant execute on function public.search_profiles(text) to authenticated;

-- ── 3) profiles.fcm_token okuma koruması ────────────────────────────
--
-- Cihazın push jetonu doğrudan `profiles` satırında duruyor. Yazma tarafı
-- düşünülmüş (`set_fcm_token`, security definer + search_path) ama okuma
-- tarafı için tek satır yoktu: `profiles` üzerinde bir SELECT politikası
-- başkalarının satırını görmeye izin veriyorsa jeton da onunla birlikte
-- gider. Push jetonu, sahibine bildirim gönderebilen bir yetkidir.
--
-- Kolon bazlı yetki `revoke` ile kapatılıyor; istemcinin jetonu okumaya
-- zaten ihtiyacı yok, yalnız yazıyor.
do $$
begin
  if exists (
    select 1 from information_schema.columns
     where table_schema = 'public'
       and table_name = 'profiles'
       and column_name = 'fcm_token'
  ) then
    execute 'revoke select (fcm_token) on public.profiles from anon, authenticated';
  end if;
end;
$$;

commit;
