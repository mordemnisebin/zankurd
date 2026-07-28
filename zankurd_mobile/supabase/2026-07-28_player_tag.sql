-- ZanKurd — oyuncu kodu (player_tag)
--
-- SORUN
-- `profiles.display_name` benzersiz değil ve arkadaş araması ada göre
-- benzerlik arıyor (`ILIKE '%...%'`). İki kişi "Berfin" adını seçerse
-- arama iki özdeş satır döndürür: aynı ad, aynı görünüm. Arayan kişi
-- hangisinin aradığı kişi olduğunu ayırt edemez ve yanlış kişiye istek
-- gönderir. Sıralamada da aynı ad iki kez görünür.
--
-- NİÇİN "BENZERSİZ AD" DEĞİL
-- Adı benzersiz yapmak akla ilk geleni ama bu uygulamaya uymuyor:
-- ZanKurd'da ad vermek **isteğe bağlı** (ad ekranında "Şimdilik geç"
-- var) ve ad iki dilli bir toplulukta kültürel bir seçim — "Berfin"
-- adını ilk alan kişinin kilitlemesi, sonrakine "Berfin1932" dedirtmek
-- demek. Bunun yerine ad serbest kalır, ayırt etmeyi kısa bir kod yapar.
--
-- ÇÖZÜM
-- Her profile dört karakterlik, değişmeyen bir **oyuncu kodu** verilir:
--
--     Berfin · ZK-4F7K
--
-- Uygulama zaten oda kodlarıyla (ZK-GVNC) bu biçimi kullanıyor, yani
-- oyuncuya yeni bir kavram öğretmiyoruz. Arama artık iki yoldan çalışır:
-- kod birebir yazılırsa tek ve kesin sonuç; ad yazılırsa benzerlik
-- sonuçları — ama her satırda kodu da görünür, böylece iki Berfin
-- birbirinden ayrılır.
--
-- ALFABE
-- Karışan karakterler dışarıda: 0/O, 1/I/L yok. Kod sesli harf içerse
-- de anlamlı bir sözcük çıkarmayacak kadar kısa; yine de küfür riskini
-- azaltmak için sesli harfler tamamen çıkarıldı.
--
-- Bu dosya yeniden çalıştırılabilir (idempotent).

-- ---------------------------------------------------------------------
-- 1) Sütun
-- ---------------------------------------------------------------------
alter table public.profiles
  add column if not exists player_tag text;

-- ---------------------------------------------------------------------
-- 2) Kod üreteci
-- ---------------------------------------------------------------------
-- 32^4 yerine 22^4 = 234.256 olası kod. Çakışma olasılığı büyüdükçe
-- artar; üreteç çakışmada yeniden dener ve benzersiz dizin son sözü
-- söyler.
create or replace function public.generate_player_tag()
returns text
language plpgsql
volatile
as $$
declare
  -- Sesli harf ve karışan karakter yok: 0/O, 1/I/L, A/E/I/O/U dışarıda.
  v_alphabet constant text := '23456789BCDFGHJKMNPQRSTVWXYZ';
  v_length   constant int  := 4;
  v_candidate text;
  v_attempt   int := 0;
begin
  loop
    v_attempt := v_attempt + 1;
    v_candidate := '';
    for i in 1..v_length loop
      v_candidate := v_candidate ||
        substr(v_alphabet, 1 + floor(random() * length(v_alphabet))::int, 1);
    end loop;

    exit when not exists (
      select 1 from public.profiles where player_tag = v_candidate
    );

    -- Havuz dolmadıkça buraya gelinmez; yine de sonsuz döngü olmasın.
    if v_attempt > 50 then
      raise exception 'player_tag üretilemedi (50 deneme)';
    end if;
  end loop;

  return v_candidate;
end;
$$;

-- ---------------------------------------------------------------------
-- 3) Var olan profillere kod ver
-- ---------------------------------------------------------------------
-- Tek tek: üreteç "bu kod kullanılıyor mu" diye baktığı için toplu
-- update'te aynı kod iki satıra düşebilirdi.
do $$
declare
  v_id uuid;
begin
  for v_id in
    select id from public.profiles where player_tag is null
  loop
    update public.profiles
       set player_tag = public.generate_player_tag()
     where id = v_id;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------
-- 4) Benzersizlik ve yeni satırlar
-- ---------------------------------------------------------------------
create unique index if not exists profiles_player_tag_key
  on public.profiles (player_tag);

-- Profil satırı istemciden `upsert` ile açılıyor; kodu istemciye
-- bırakmak (a) çakışmayı istemcide çözmeyi gerektirir, (b) kullanıcının
-- kendi kodunu seçmesine kapı açar. Tetikleyici, kodun nereden gelirse
-- gelsin atanmasını garanti eder.
create or replace function public.assign_player_tag()
returns trigger
language plpgsql
as $$
begin
  if new.player_tag is null or length(trim(new.player_tag)) = 0 then
    new.player_tag := public.generate_player_tag();
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_assign_player_tag on public.profiles;
create trigger profiles_assign_player_tag
  before insert on public.profiles
  for each row
  execute function public.assign_player_tag();

-- Kod değişmez: paylaştığın kodun yarın başkasını göstermemesi için.
create or replace function public.freeze_player_tag()
returns trigger
language plpgsql
as $$
begin
  if old.player_tag is not null and new.player_tag is distinct from old.player_tag then
    new.player_tag := old.player_tag;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_freeze_player_tag on public.profiles;
create trigger profiles_freeze_player_tag
  before update on public.profiles
  for each row
  execute function public.freeze_player_tag();

-- ---------------------------------------------------------------------
-- 5) Arama: kod birebir, ad benzerlik
-- ---------------------------------------------------------------------
-- Dönüş tipi değiştiği için önce düşürmek gerekiyor.
drop function if exists public.search_profiles(text);

create function public.search_profiles(p_query text)
returns table (
  id uuid,
  display_name text,
  avatar_color text,
  player_tag text
)
language plpgsql
stable
security definer
as $$
declare
  v_user_id uuid;
  v_query   text;
  v_tag     text;
begin
  v_user_id := auth.uid();
  v_query := trim(p_query);
  if v_user_id is null or length(v_query) < 2 then
    return;
  end if;

  -- "ZK-4F7K", "zk-4f7k" ve "4F7K" aynı kodu arar: oyuncu kodu ekranda
  -- önekle görünüyor, elle yazarken önekin yazılmasını beklemek gereksiz
  -- sürtünme olurdu.
  v_tag := upper(regexp_replace(v_query, '^[zZ][kK][-\s]*', ''));

  return query
  select p.id, p.display_name, p.avatar_color, p.player_tag
  from public.profiles p
  where p.id <> v_user_id
    and (p.player_tag = v_tag or p.display_name ilike '%' || v_query || '%')
  -- Kod eşleşmesi başa: birebir arayan, aradığını ilk satırda görür.
  order by (p.player_tag = v_tag) desc, p.display_name
  limit 10;
end;
$$;

grant execute on function public.search_profiles(text) to authenticated;
revoke all on function public.generate_player_tag() from public, anon, authenticated;
