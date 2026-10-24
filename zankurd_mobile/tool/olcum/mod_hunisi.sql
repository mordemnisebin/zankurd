-- Salt okuma. Son 28 tamamlanmış günde oyun modlarına göre tur başlangıç/bitiş olay özeti.
-- Kişisel veri döndürmez; yalnız mod bazında toplu olay sayılarını, aynı kullanıcının
-- round_id ile birebir eşleşen tamamlanmış tur sayısını ve bitiş/başlangıç olay oranını üretir.
with mod_olaylari as (
  select
    coalesce(nullif(event_params->>'mode', ''), 'belirsiz') as mod,
    nullif(event_params->>'round_id', '') as round_id,
    event_name,
    user_id
  from public.analytics_events
  where event_name in ('quiz_start', 'quiz_complete')
    and event_timestamp >= date_trunc('day', now()) - interval '28 days'
    and event_timestamp <  date_trunc('day', now())
),
eslesen_turlar as (
  select
    s.mod,
    count(distinct (s.user_id, s.round_id)) as eslesen_tur
  from mod_olaylari s
  join mod_olaylari c
    on c.user_id = s.user_id
   and c.mod = s.mod
   and c.round_id = s.round_id
   and s.event_name = 'quiz_start'
   and c.event_name = 'quiz_complete'
  where s.round_id is not null
  group by s.mod
),
ozet as (
  select
    m.mod,
    count(*) filter (where m.event_name = 'quiz_start') as baslayan_tur,
    count(*) filter (where m.event_name = 'quiz_complete') as biten_tur,
    coalesce(max(e.eslesen_tur), 0) as eslesen_tur,
    count(distinct m.user_id) filter (where m.event_name = 'quiz_start') as baslayan_kisi,
    count(distinct m.user_id) filter (where m.event_name = 'quiz_complete') as bitiren_kisi
  from mod_olaylari m
  left join eslesen_turlar e on e.mod = m.mod
  group by m.mod
)
select
  mod,
  baslayan_tur,
  biten_tur,
  eslesen_tur,
  case when baslayan_tur > 0 then round(100.0 * biten_tur / baslayan_tur) end as bitis_baslangic_yuzde,
  baslayan_kisi,
  bitiren_kisi
from ozet
order by baslayan_tur desc, mod asc;
