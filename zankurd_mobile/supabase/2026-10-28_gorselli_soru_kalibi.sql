-- Görselli kelime sorularının kalıbı (2026-10-28).
--
-- Kusur: "Wêne "nan" dibêje — wateya rast kîjan e?" ("Görsel "nan" diyor —
-- doğru anlam hangisi?") doğal değildi; görsel bir şey "söylemez" (gece
-- görsel kurulu: GPT-6 Sol). Yeni kalıp Kurmancî kurulunda oybirliğiyle
-- onaylandı (GPT-6 Sol, Gemini 3.8 Flash, Claude Opus 5.5):
-- "Peyva "nan" a di wêneyê de tê çi wateyê?". Yerel kopya:
-- assets/data/offline_questions.json (aynı sözcükler).
-- Yalnız (id, eski metin) eşleşen satır değişir; toplu bul-değiştir yok.
begin;

update public.questions set prompt = 'Peyva "nav" a di wêneyê de tê çi wateyê?'
 where id = '261fed89-743c-44d5-b259-250740c01842'
   and prompt = 'Wêne "nav" dibêje — wateya rast kîjan e?';
update public.questions set prompt = 'Peyva "mal" a di wêneyê de tê çi wateyê?'
 where id = '700d3999-4d1c-449f-839d-88f175c2caf2'
   and prompt = 'Wêne "mal" dibêje — wateya rast kîjan e?';
update public.questions set prompt = 'Peyva "biçûk" a di wêneyê de tê çi wateyê?'
 where id = '93e302b6-e647-4ea9-95ba-4d54acc801b9'
   and prompt = 'Wêne "biçûk" dibêje — wateya rast kîjan e?';
update public.questions set prompt = 'Peyva "xweş" a di wêneyê de tê çi wateyê?'
 where id = '9640a635-e800-48d4-ad3a-a5be59e4dc3a'
   and prompt = 'Wêne "xweş" dibêje — wateya rast kîjan e?';
update public.questions set prompt = 'Peyva "nan" a di wêneyê de tê çi wateyê?'
 where id = 'c7b4379e-ee39-41d4-aec5-06df26a6c436'
   and prompt = 'Wêne "nan" dibêje — wateya rast kîjan e?';

do $$
begin
  if (select count(*) from public.questions where prompt like 'Wêne "%" dibêje%') <> 0 then
    raise exception 'eski kalıp kaldı';
  end if;
  if (select count(*) from public.questions where prompt like 'Peyva "%" a di wêneyê de tê çi wateyê?') < 5 then
    raise exception 'yeni kalıp 5 satırda yok';
  end if;
end $$;

commit;
