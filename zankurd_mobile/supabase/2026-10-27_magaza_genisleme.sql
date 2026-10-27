-- 2026-10-27: mağaza genişlemesi — teslimi olan yeni ürünler.
--
-- NİÇİN: mağazada yalnız 4 ürün vardı (ek çark, altın/neon çerçeve, VIP);
-- karşılığı olmayan katalog satırları bilerek gizlenmişti. Bu göç yalnız
-- istemcide GERÇEKTEN teslim edilen ürünleri açar:
--   joker_pack_3        — 3 joker hakkı (istemcide yerel stok, jetondan
--                         önce harcanır); tekrar alınabilir. Fiyat 350'den
--                         90'a (jokerler 20–50; 3'lü paket indirimli).
--   avatar_frame_kilim  — 300, avatar_frame_newroz — 400,
--   avatar_frame_sev    — 500: yeni premium çerçeveler; profiles koruma
--                         tetikleyicisi yalnız satın alana uygulatır.
-- Seri dondurma mağazada `streak_freeze` gerekçesiyle (50) zaten var olan
-- yoldan satılır; katalog satırı gerekmez.
--
-- Gövdeler CANLI tanımdan alınmıştır (2026-10-27 okundu); değişen yalnız
-- izin listesi, tekrar alınabilir küme ve çerçeve listesi/kapıları.
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-27_magaza_genisleme.sql

begin;

insert into public.shop_items
  (id, title_ku, title_tr, desc_ku, desc_tr, cost, icon_name, theme_color)
values
  ('avatar_frame_kilim', 'Çarçoveya kilîmê', 'Kilim çerçeve',
   'Bila avatarê te bi xelekeke sor û zêrîn a bi nexşên kilîmê bê dorpêçkirin.', 'Avatarın kilim desenli kırmızı-altın bir halkayla çevrilsin.',
   300, 'palette_outlined', 'B5333C'),
  ('avatar_frame_newroz', 'Çarçoveya Newrozê', 'Newroz çerçeve',
   'Bila avatarê te bi rengên agirê Newrozê bibiriqe.', 'Avatarın Newroz ateşinin renkleriyle parlasın.',
   400, 'local_fire_department_outlined', 'F28C28'),
  ('avatar_frame_sev', 'Çarçoveya şevê', 'Gece çerçeve',
   'Bila avatarê te bi şîniya şevê û ronahiya stêrkan bê dorpêçkirin.', 'Avatarın gece mavisi ve yıldız ışığıyla çevrilsin.',
   500, 'nights_stay_outlined', '3D4BB5')
on conflict (id) do update set
  title_ku = excluded.title_ku, title_tr = excluded.title_tr,
  desc_ku = excluded.desc_ku, desc_tr = excluded.desc_tr,
  cost = excluded.cost, icon_name = excluded.icon_name,
  theme_color = excluded.theme_color;

-- Fiyat çıpası (bekçi: shop_price_anchor_parity_test bu biçimi okur).
update public.shop_items set cost = 90 where id = 'joker_pack_3';
update public.shop_items set cost = 300 where id = 'avatar_frame_kilim';
update public.shop_items set cost = 400 where id = 'avatar_frame_newroz';
update public.shop_items set cost = 500 where id = 'avatar_frame_sev';

update public.shop_items set
  title_ku = 'Paketa alîkariyê (3)', title_tr = 'Joker paketi (3)',
  desc_ku = 'Sê mafên alîkariyê: di dema pirsê de bêyî ku zêr kêm bibe tên bikaranîn.',
  desc_tr = 'Üç joker hakkı: soru sırasında jeton düşmeden kullanılır.'
where id = 'joker_pack_3';

-- Görünen eski ürünlerin adları istemci yedek kataloğuyla aynı cümle
-- düzenine (2026-09-29 doğallık kararı; canlıda "VIP Rozeti" kalmıştı).
update public.shop_items set title_ku = 'Zivirîna zêde', title_tr = 'Ekstra çevirme'
  where id = 'spin_wheel_extra';
update public.shop_items set title_ku = 'Çarçoveya zêrîn', title_tr = 'Altın çerçeve'
  where id = 'avatar_frame_gold';
update public.shop_items set title_ku = 'Çarçoveya neon', title_tr = 'Neon çerçeve'
  where id = 'avatar_frame_neon';
update public.shop_items set title_ku = 'Rozeta VIP', title_tr = 'VIP rozeti'
  where id = 'profile_badge_vip';

drop index if exists public.shop_purchases_nonrepeatable_uidx;
create unique index shop_purchases_nonrepeatable_uidx
  on public.shop_purchases(player_id, item_id)
  where item_id not in ('spin_wheel_extra', 'joker_pack_3');

create or replace function public.spend_coins(p_amount integer, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  v_balance integer;
  v_expected integer;
  v_item_id text;
  v_transaction_id uuid;
begin
  if v_uid is null then
    return jsonb_build_object('success', false, 'error', 'not authenticated');
  end if;

  v_expected := case p_reason
    when 'wildcard_fifty_fifty' then 20
    when 'wildcard_audience' then 30
    when 'wildcard_double_answer' then 50
    when 'wildcard_change_question' then 40
    when 'streak_freeze' then 50
    else null
  end;

  if left(p_reason, 9) = 'purchase_' then
    v_item_id := substring(p_reason from 10);
    if not (
      v_item_id = any (array[
        'spin_wheel_extra',
        'avatar_frame_gold',
        'avatar_frame_neon',   -- 2026-08-02: eksikti; ürün alınamıyordu
        'profile_badge_vip',
        -- 2026-10-27 mağaza genişlemesi: teslimi olan ürünler.
        'joker_pack_3',
        'avatar_frame_kilim',
        'avatar_frame_newroz',
        'avatar_frame_sev'
      ])
    ) then
      return jsonb_build_object(
        'success', false,
        'error', 'product not available'
      );
    end if;
    select cost into v_expected
    from public.shop_items
    where id = v_item_id;
  end if;

  if p_amount <= 0
     or v_expected is null
     or v_expected <= 0
     or p_amount is distinct from v_expected then
    return jsonb_build_object('success', false, 'error', 'invalid price');
  end if;

  perform 1 from public.profiles where id = v_uid for update;
  if not found then
    return jsonb_build_object('success', false, 'error', 'profile missing');
  end if;

  -- Tekrar alınabilenler: ek çark ve joker paketi (tüketilir).
  if v_item_id is not null
     and v_item_id not in ('spin_wheel_extra', 'joker_pack_3')
     and exists (
       select 1
       from public.shop_purchases
       where player_id = v_uid
         and item_id = v_item_id
     ) then
    return jsonb_build_object('success', false, 'error', 'already purchased');
  end if;

  select coalesce(sum(amount), 0)::integer into v_balance
  from public.coin_transactions
  where player_id = v_uid;

  if v_balance < v_expected then
    return jsonb_build_object('success', false, 'balance', v_balance);
  end if;

  insert into public.coin_transactions (player_id, amount, reason)
  values (v_uid, -v_expected, p_reason)
  returning id into v_transaction_id;

  if v_item_id is not null then
    insert into public.shop_purchases (
      player_id,
      item_id,
      price_paid,
      coin_transaction_id
    ) values (
      v_uid,
      v_item_id,
      v_expected,
      v_transaction_id
    );
  end if;
  return jsonb_build_object(
    'success', true,
    'balance', v_balance - v_expected
  );
end;
$function$;

create or replace function public.protect_paid_profile_cosmetics()
returns trigger
language plpgsql
security definer
set search_path = public
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
       || '/avatar([-][0-9]+)?[.](jpg|png)([?]v=[0-9]+)?$'
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
         array['bronze', 'silver', 'gold', 'mamoste', 'neon',
               'kilim', 'newroz', 'sev']
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

  -- 2026-10-27: mağaza çerçeveleri yalnız satın alanda (neon gibi).
  if new.avatar_frame in ('kilim', 'newroz', 'sev')
     and v_frame_changed
     and not exists (
       select 1
       from public.shop_purchases sp
       where sp.player_id = new.id
         and sp.item_id = 'avatar_frame_' || new.avatar_frame
     ) then
    raise exception 'Frame has not been purchased';
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
