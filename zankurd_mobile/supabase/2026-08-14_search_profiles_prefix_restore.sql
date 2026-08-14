-- `search_profiles` oyuncu kodu aramasını "ZK-" önekiyle çalışır hâle
-- getirir (forward-only, idempotent).
--
-- 2026-07-28_player_tag.sql `search_profiles`e önek soymayı ekledi:
-- `v_tag := upper(regexp_replace(v_query, '^[zZ][kK][-\s]*', ''));` —
-- ekranda gösterilen ve panoya kopyalanan kod hep `ZK-4F7K` biçiminde
-- (profile_widgets.dart:361), yani öneksiz arama kullanıcının elle
-- düzenleme yapmasını gerektirmemeliydi.
--
-- 2026-07-31_exposure_hardening.sql LIKE metakarakter kaçırma
-- güvenlik düzeltmesini eklerken fonksiyonu `create or replace` ile
-- BAŞTAN yazdı ve önek soyma satırını hiç taşımadı:
-- `v_tag text := upper(v_query);`. İki düzeltme birbirinin üzerine
-- yazıldı; canlıda yalnız ikincisi (2026-08-01'de uygulanan) kaldı.
--
-- Sonuç: kullanıcı profilinde "Kod kopyalandı" diyerek panoya aldığı
-- `ZK-4F7K`'yı arkadaş arama kutusuna yapıştırıp Ara'ya basınca sunucu
-- `player_tag = 'ZK-4F7K'` (yanlış, kolonda önek yok) ve
-- `display_name ilike '%ZK-4F7K%'` (yanlış) sorguluyor, boş dönüyor —
-- "Oyuncu bulunamadı". Kodu paylaşmanın tek amacı tek-ve-kesin sonuç
-- bulmaktı; bu göç öncesi o amaç çalışmıyordu (2026-08-14 denetimi).
--
-- Bu göç iki düzeltmeyi BİRLEŞTİRİR: önek soyma geri gelir, LIKE
-- kaçırma korunur.

begin;

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
  -- "ZK-4F7K", "zk-4f7k" ve "4F7K" aynı kodu arar — kod ekranda
  -- önekle görünüyor, elle yazarken önekin yazılmasını beklemek
  -- gereksiz sürtünme olurdu (2026-07-28 kararı, burada geri getirilir).
  v_tag text := upper(regexp_replace(v_query, '^[zZ][kK][-\s]*', ''));
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

commit;
