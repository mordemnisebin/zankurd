-- Salt okuma. Son 28 tamamlanmış günde oyun modlarına göre tur başlangıç/bitiş olay özeti.
-- Kişisel veri döndürmez; yalnız mod bazında toplu olay sayılarını ve bitiş/başlangıç olay oranını üretir.
with mod_olaylari as (
  select
    coalesce(nullif(event_params->>'mode', ''), 'belirsiz') as mod,
    event_name,
    user_id
  from public.analytics_events
  where event_name in ('quiz_start', 'quiz_complete')
    and event_timestamp >= date_trunc('day', now()) - interval '28 days'
    and event_timestamp <  date_trunc('day', now())
),
ozet as (
  select
    mod,
    count(*) filter (where event_name = 'quiz_start') as baslayan_tur,
    count(*) filter (where event_name = 'quiz_complete') as biten_tur,
    count(distinct user_id) filter (where event_name = 'quiz_start') as baslayan_kisi,
    count(distinct user_id) filter (where event_name = 'quiz_complete') as bitiren_kisi
  from mod_olaylari
  group by mod
)
select
  mod,
  baslayan_tur,
  biten_tur,
  case when baslayan_tur > 0 then round(100.0 * biten_tur / baslayan_tur) end as bitis_baslangic_yuzde,
  baslayan_kisi,
  bitiren_kisi
from ozet
order by baslayan_tur desc, mod asc;
