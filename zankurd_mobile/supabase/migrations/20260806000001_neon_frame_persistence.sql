-- ZanKurd — satın alınan Neon çerçevesinin kalıcılaşması
-- =======================================================
--
-- İleri yönlü göç. Uygulanmış hiçbir göç dosyası düzenlenmedi.
--
-- `2026-08-02_shop_neon_frame_allowlist.sql` `spend_coins`in izin
-- listesine `avatar_frame_neon` ekledi: ürün ARTIK SATIN ALINABİLİYOR.
-- Ama aynı değeri `protect_paid_profile_cosmetics` tetikleyicisinin
-- çerçeve listesine kimse eklemedi; o liste dört değerde kaldı:
--
--     array['bronze', 'silver', 'gold', 'mamoste']
--
-- Temiz bir üretim şeması klonunda, gerçek `authenticated` rolüyle
-- uçtan uca üretildi (2026-08-06):
--
--     spend_coins(600,'purchase_avatar_frame_neon')
--       -> {"balance": 4400, "success": true}   (600 coin GERÇEKTEN düştü)
--     update profiles set avatar_frame='neon'
--       -> ERROR: Invalid avatar frame          (çerçeve HİÇ yazılamadı)
--
-- Asıl zarar ikinci adımda değil, sonrasında: `v_frame_changed` her
-- denemede yeniden true olduğu için, `neon` seçili kaldığı sürece
-- UPDATE'in TAMAMI iptal edilir. Aynı klonda doğrulandı — avatar ikonu
-- ve rengi de birlikte kaybedildi:
--
--     update profiles set avatar_frame='neon',
--                         avatar_icon='tac', avatar_color='#FF0000'
--       -> ERROR: Invalid avatar frame
--     avatar_icon hâlâ 'ster', avatar_color hâlâ '#112233'
--
-- Yani kullanıcı 600 coin ödedikten sonra profil kozmetiği kalıcı ve
-- sessiz biçimde donuyordu.
--
-- Çözüm, çerçeveyi listeye eklerken ONU SATIN ALMA ŞARTINA BAĞLAMAK.
-- Desen yeni değil: `showcase_title = 'VIP'` zaten aynı biçimde
-- `shop_purchases` kontrolüyle korunuyor. Neon da ilerlemeyle değil
-- yalnız mağazadan açıldığı için (`avatar_frames.dart`: "`unlockedFrames`
-- onu hiç eklemez") aynı kapıya bağlanır. `bronze/silver/gold/mamoste`
-- ilerlemeyle de kazanılabildiği için onlara dokunulmadı.
--
-- İstemci tarafı: `updateAvatarIdentity` bu reddi yutuyordu ve ekran
-- başarı sayıp kapanıyordu; o da bu düzeltmeyle birlikte geçiriliyor.

begin;

-- ── 1) Kozmetik tetikleyicisi: neon, satın alma şartıyla ───────────────
create or replace function public.protect_paid_profile_cosmetics()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
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
     and new.showcase_title !~ '^(Xwendekar|Pispor|Mamoste) · (Ziman|Çand|Dîrok|Edebiyat|Wêje|Cografya|Erdnîgarî|Muzîk|Siyaset|Paradigma|Paradîgma|Sînema|Teknolojî)$' then
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

-- Doğrulama (salt okunur):
--
--   select 'neon allowed' as check,
--          pg_get_functiondef(oid) like '%neon%' as ok
--     from pg_proc where proname = 'protect_paid_profile_cosmetics';
