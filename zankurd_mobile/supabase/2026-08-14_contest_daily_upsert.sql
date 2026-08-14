-- Günün Etkinliği ekranı hep boştu.
--
-- ## Kusur
--
-- `contests` satırlarını hiçbir kod yolu INSERT etmiyordu: ne bir client
-- çağrısı ne de bir pg_cron görevi. `get_today_contest()`
-- (2026-07-05_contest_system.sql) yalnız `WHERE day_key = CURRENT_DATE`
-- ile SELECT yapıyordu — tablo hep boş kaldığı için her zaman boş sonuç
-- döndürüyordu. `ContestScreen` bunu `Contest?` olarak yorumluyor, `null`
-- gelince "bugün etkinlik yok" gösteriyordu; hata fırlatmadığı için kusur
-- sessizdi (2026-08-14 denetimi — `supabase/applied.md`'de kayıtlı hiçbir
-- migration ya da runbook adımı `contests`e satır yazmıyor).
--
-- ## Düzeltme
--
-- `get_today_contest()` idempotent bir "yoksa oluştur" fonksiyonuna
-- çevrilir: gün için satır yoksa gün-sırasına (`EXTRACT(DOY ...)`) göre
-- deterministik bir tema seçip `INSERT ... ON CONFLICT (day_key) DO
-- NOTHING` ile yaratır, sonra SELECT eder. Deterministik seçim + ON
-- CONFLICT DO NOTHING, ekran her açıldığında bu RPC çağrıldığı için aynı
-- gün birden çok istemcinin yarışarak çağırmasında satır çakışması ya da
-- farklı temaya yakınsama riski olmadan aynı sonuca ulaşmasını sağlar.
--
-- `contests` tablosunda `anon`/`authenticated` yalnız SELECT yetkisine
-- sahip (bkz. `baselines/20260801000000_production_baseline.sql:6476-6478`),
-- bu yüzden fonksiyon INSERT yapabilmek için `SECURITY DEFINER` olmalı —
-- orijinal tanım `STABLE`+yazmayan bir sorguydu, artık yazan bir fonksiyon
-- olduğu için `STABLE` kaldırıldı.

create or replace function public.get_today_contest()
returns table (
  id uuid,
  day_key date,
  theme_name_ku text,
  theme_description_ku text,
  category text,
  difficulty_min int,
  difficulty_max int,
  participation_reward int,
  rank1_reward int,
  rank2_reward int,
  rank3_reward int,
  question_count int
)
language plpgsql
security definer
set search_path = public
as $$
declare
  -- Yedi günlük sabit bir tema rotasyonu: ayrı bir "contest_themes" tablosu
  -- kurmak bu ölçekte gereksiz soyutlama olurdu, sabit dizi yeterli.
  v_themes text[][] := array[
    array['Paradîgmayên Kurdî', 'Zanîna gelemperî û pirsên paradîgmayê', 'Paradigma'],
    array['Dîroka Me', 'Bûyer û kesayetiyên dîrokî', 'Dîrok'],
    array['Ziman û Edebiyat', 'Rêziman, biwêj û berhemên edebî', 'Ziman'],
    array['Cografyaya Cîhanê', 'Welat, bajar û taybetiyên cografî', 'Cografya'],
    array['Çand û Kevneşopî', 'Çand, adet û kevneşopiyên gelêrî', 'Çand'],
    array['Muzîk û Huner', 'Stranbêj, huner û hunermendên navdar', 'Muzîk'],
    array['Siyaset û Civak', 'Bûyerên siyasî û civakî yên rojane', 'Siyaset']
  ];
  v_idx int;
begin
  v_idx := 1 + (extract(doy from current_date)::int % array_length(v_themes, 1));

  insert into public.contests (
    day_key, theme_name_ku, theme_description_ku, category,
    difficulty_min, difficulty_max, participation_reward,
    rank1_reward, rank2_reward, rank3_reward, question_count
  )
  values (
    current_date,
    v_themes[v_idx][1],
    v_themes[v_idx][2],
    v_themes[v_idx][3],
    1, 5, 10, 500, 300, 100, 10
  )
  on conflict (day_key) do nothing;

  return query
  select
    c.id, c.day_key, c.theme_name_ku, c.theme_description_ku, c.category,
    c.difficulty_min, c.difficulty_max, c.participation_reward,
    c.rank1_reward, c.rank2_reward, c.rank3_reward, c.question_count
  from public.contests c
  where c.day_key = current_date
  limit 1;
end;
$$;
