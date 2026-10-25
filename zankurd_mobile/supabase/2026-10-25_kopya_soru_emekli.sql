-- 2026-10-25: kaynaklar arası birebir kopya iki sorunun emeklisi — sunucu karşılığı.
--
-- NİÇİN: yerelde `retired_question_ids.dart` (2026-10-25 bloğu) üç kopya
-- emekli oldu; normalleştirilmiş soru metni aynı, aynı bilgiyi soruyor.
-- Canlıda iki kopyanın ikisi de onaylı olduğundan online oda/düello havuzu
-- (start_room_game, start_async_duel, create_async_duel_challenge;
-- is_approved=true süzer) aynı soruyu iki kez getirebiliyordu.
--   kolay_dirok_08  "Ehmedê Xanî kî bû?"            (kalan: offline_curated_20304, 7c6a799d…)
--   sf_nat_0005     Sîstema Rojê gerstêrk sayısı    (kalan: bilim_0001, 4a2c7355…)
--   wo-ku-001       "Ez diçim malê" sıralama — sunucuda YOK (cümle kurma
--                   yalnız yerel; ne uuid5 karşılığı ne metni canlıda var).
-- Silme yok; `is_approved=false` geri alınabilir (aynı id'lerle true).
--
-- Kimlik: uuid5(5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77, 'zankurd-local:' + yerel id).
--
-- Test: begin … rollback içinde güncellenen satır 2, kalan eşler onaylı.
--
-- Çalıştırma: supabase db query --linked -f supabase/2026-10-25_kopya_soru_emekli.sql

begin;

update public.questions
   set is_approved = false
 where id in (
  '199f99ef-54e0-50b9-af61-afe305124d46',  -- kolay_dirok_08
  '0db6534f-3ecd-531d-99ab-7f0267bbbbd7'   -- sf_nat_0005
);

commit;
