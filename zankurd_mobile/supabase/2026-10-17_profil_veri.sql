-- protect_paid_profile_cosmetics: vitrin unvanı kategori adları (2026-10-17).
-- Kusur: avatar düzenleyici unvanı "<seviye> · <kategori>" biçiminde, kategori
-- adını OYUNCUNUN GÖRDÜĞÜ Kurmancî adla yazar. 2026-09-30'da Paradigma
-- "Zanist û Raman" oldu ve Cîhan eklendi; tetikleyicinin regex'i bu iki adı
-- bilmiyordu. Bu kategorilerde seviye kazanan oyuncunun Kaydet'i TÜM profil
-- yazımıyla birlikte 'Invalid showcase title' ile düşüyordu (avatar/renk de
-- kaydolmuyordu). Gövde CANLI tanımdan alındı; yalnız unvan regex'ine
-- 'Zanist û Raman' ve 'Cîhan' eklendi (eski adlar eski satırlar için kalır).
-- CREATE OR REPLACE yetkileri (authenticated/service_role execute) korur.
begin;
CREATE OR REPLACE FUNCTION public.protect_paid_profile_cosmetics()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_icon_changed boolean;
  v_color_changed boolean;
  v_url_changed boolean;
  v_frame_changed boolean;
  v_title_changed boolean;
begin
  if tg_op = 'INSERT' then
    v_icon_changed := true;
    v_color_changed := true;
    v_url_changed := true;
    v_frame_changed := true;
    v_title_changed := true;
  else
    v_icon_changed := new.avatar_icon is distinct from old.avatar_icon;
    v_color_changed := new.avatar_color is distinct from old.avatar_color;
    v_url_changed := new.avatar_url is distinct from old.avatar_url;
    v_frame_changed := new.avatar_frame is distinct from old.avatar_frame;
    v_title_changed := new.showcase_title is distinct from old.showcase_title;
  end if;

  if v_icon_changed
     and new.avatar_icon is not null
     and not (
       new.avatar_icon = any (array[
         'tembur', 'dengbej', 'ciya', 'roj', 'pirtuk', 'newroz', 'ster',
         'pen', 'cihan', 'mertal', 'tac', 'gul', 'dar', 'cav', 'birusk',
         'kupa'
       ])
     ) then
    raise exception 'Invalid avatar icon';
  end if;

  if v_color_changed
     and new.avatar_color is not null
     and new.avatar_color !~ '^#[0-9A-F]{6}$' then
    raise exception 'Invalid avatar color';
  end if;

  if v_url_changed
     and new.avatar_url is not null
     and new.avatar_url !~ (
       '^https://hupivnxgjtsfafulzspo[.]supabase[.]co/storage/v1/object/public/avatars/'
       || new.id::text
       || '/avatar[.](jpg|png)([?]v=[0-9]+)?$'
     ) then
    raise exception 'Avatar URL must point to the owner storage path';
  end if;

  -- 2026-08-06: `neon` listeye eklendi. Mağazadan alınabildiği hâlde
  -- burada yoktu; ödenen ürün hiç uygulanamıyor, üstelik seçili kaldığı
  -- sürece bütün kozmetik yazımını kilitliyordu.
  if v_frame_changed
     and new.avatar_frame is not null
     and not (
       new.avatar_frame = any (
         array['bronze', 'silver', 'gold', 'mamoste', 'neon']
       )
     ) then
    raise exception 'Invalid avatar frame';
  end if;

  -- Neon YALNIZ satın alanda uygulanabilir: ilerlemeyle açılmıyor, tek
  -- kaynağı mağaza. VIP rozetiyle aynı kapı.
  if new.avatar_frame = 'neon'
     and v_frame_changed
     and not exists (
       select 1
       from public.shop_purchases sp
       where sp.player_id = new.id
         and sp.item_id = 'avatar_frame_neon'
     ) then
    raise exception 'Neon frame has not been purchased';
  end if;

  if v_title_changed
     and new.showcase_title is not null
     and new.showcase_title <> 'VIP'
     and new.showcase_title !~ '^(Xwendekar|Pispor|Mamoste) · (Ziman|Çand|Dîrok|Edebiyat|Wêje|Cografya|Erdnîgarî|Muzîk|Siyaset|Paradigma|Paradîgma|Zanist û Raman|Sînema|Teknolojî|Cîhan)$' then
    raise exception 'Invalid showcase title';
  end if;

  if new.showcase_title = 'VIP'
     and v_title_changed
     and not exists (
       select 1
       from public.shop_purchases sp
       where sp.player_id = new.id
         and sp.item_id = 'profile_badge_vip'
     ) then
    raise exception 'VIP badge has not been purchased';
  end if;
  return new;
end;
$function$;
commit;
