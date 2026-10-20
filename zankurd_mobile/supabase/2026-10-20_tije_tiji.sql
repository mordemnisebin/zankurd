-- 2026-10-20: "tije" → "tijî" (standart Kurmancî "dolu") canlı kopyası.
--
-- NİÇİN: ilk Orkestra kurulu (6 denetçi: Muse Spark/Cline, Gemma 4 31B, DeepSeek
-- V4.1 Flash, GLM 5.3, Kimi K3, Muse Spark Open; hakem Grok 4.7) yerel 10 maddenin
-- hepsinde "tijî" dedi: sıfat ve "tijî kirin / tijî bûn" fiillerinde 5-1 ve 4-2;
-- bilmece alıntısı (ex28_tistonek_001 prompt) 3-3 berabere, hakem Grok TIJI
-- (açıklamadaki "gomeke tijî pez" ile aynı yazım). Karşı oyların çoğu DeepSeek'ten
-- ("tije" ağız biçimi). Toplu bul-değiştir değil: yalnız aşağıdaki kimlik + sütun
-- çiftleri, ve yalnız "tije" sözcüğü (\m…\M) değişir.
--
-- Canlıda (2026-10-20 salt okuma) "tije" içeren 4 satır var; dersler3_0061 ve
-- restore_0003 sunucuda yok (yalnız yerel bankada, aynı commit'te düzeldi).
--   c3901d7a… cinema_0004            prompt
--   69e3fbc5… hat_0120               explanation, explanation_ku
--   004fbb44… ex28_tistonek_001      prompt, explanation, explanation_ku
--   78db12ef… ex28_tistonek_012      explanation, explanation_ku
--
-- Tekrar çalıştırılabilir (ikinci çalıştırmada "tije" kalmadığı için 0 satır).
-- Geri alma: aynı satırlarda regexp_replace(col, '\mtijî\M', 'tije').
-- Uygulama:
--   supabase db query --linked -f supabase/2026-10-20_tije_tiji.sql

begin;

-- Soru metinleri açık yazılır: test/local_parity_server_sync_test.dart bekçisi
-- yerelde düzelen metni düzeltme göçünde birebir arar. Canlı eski metin yerel
-- eski metinle birebir aynıydı (2026-10-20 salt okuma).
-- cinema_0004
update questions set
  prompt = 'Ji bo dîmenê ku rûyê lîstikvanî perdeyê tijî dike, di zimanê sînemayê de kîjan têgeh tê bikaranîn?'
where id = 'c3901d7a-89c0-52df-ae09-8de6f916b591';
-- ex28_tistonek_001
update questions set
  prompt = 'Di mamik û tiştonekên kurdî de bersiva "Goma bavê min tijî pez e, şefeqê radibim hebek tune ye" çi ye?'
where id = '004fbb44-5c21-570b-abec-9b160e37449d';

update questions set
  explanation = regexp_replace(explanation, '\mtije\M', 'tijî', 'g'),
  explanation_ku = regexp_replace(explanation_ku, '\mtije\M', 'tijî', 'g')
where id in (
    '69e3fbc5-a57e-5ea8-a39e-516e625d3918',
    '004fbb44-5c21-570b-abec-9b160e37449d',
    '78db12ef-ed64-504e-9a0a-c001c60c0ef3'
  )
  and (explanation ~ '\mtije\M' or explanation_ku ~ '\mtije\M');

-- Doğrulama: bu dört satırda "tije" kalmamalı ve her biri "tijî" taşımalı.
do $$
declare
  kalan int;
  yeni int;
begin
  select count(*) into kalan from questions
  where id in ('c3901d7a-89c0-52df-ae09-8de6f916b591', '69e3fbc5-a57e-5ea8-a39e-516e625d3918',
               '004fbb44-5c21-570b-abec-9b160e37449d', '78db12ef-ed64-504e-9a0a-c001c60c0ef3')
    and (prompt ~ '\mtije\M' or explanation ~ '\mtije\M' or explanation_ku ~ '\mtije\M');
  select count(*) into yeni from questions
  where id in ('c3901d7a-89c0-52df-ae09-8de6f916b591', '69e3fbc5-a57e-5ea8-a39e-516e625d3918',
               '004fbb44-5c21-570b-abec-9b160e37449d', '78db12ef-ed64-504e-9a0a-c001c60c0ef3')
    and (prompt ~ '\mtijî\M' or explanation_ku ~ '\mtijî\M');
  if kalan <> 0 or yeni <> 4 then
    raise exception 'tije_tiji doğrulaması tutmadı: kalan=%, yeni=%', kalan, yeni;
  end if;
end $$;

commit;
