-- 2026-10-19: dış içerik denetiminde bulunan 10 kusurlu sorunun emeklisi — sunucu karşılığı.
--
-- NİÇİN: canlıdaki 4197 sorunun tamamı AI Studio'da Gemini 3.1 Pro ve Grok ile
-- denetlendi; işaretlenenleri ana ajan tek tek okuyup doğruladı. Aşağıdaki 10
-- soru ya cevaplanamaz ya belirsiz ya da tartışmalı olduğundan oyuncuya haksız
-- yanıt ya da kafa karışıklığı yaşatıyordu:
--   b71fc75c…, 8745e3c2…: istem "li gorî nivîsê" (metne göre) diyor ama metin yok
--                         → cevaplanamaz.
--   0cf8e955… (sf_cin_0008), f023e0f2… (sf_cin_0007): özne eksik ("ilk edisyon
--                         nerede", "uluslararası jüri ilk kez hangi yıl") — hangi
--                         festival olduğu söylenmiyor → belirsiz.
--   398606d8… (offline_tf_ede_0019), e1cd60c0… (offline_tf_siy_0040): D/Y
--                         ifadeleri; anahtardaki cevap (Şaş) yaygın tanımla
--                         çelişiyor → anahtar belirsiz.
--   dd5a01c2…: "Kalp/dil" şıkı Türkçe sesteş sözcükle karışıyor → kafa karıştırıcı.
--   bb4d417e… (offline_curated_21475): "heyran"ı yalnız Serhad'ın kadın aşk
--                         türküsü sayıyor → tartışmalı.
--   0b44b8bf… (curated_siyaset_0009): "Barzani hareketinin ilk lideri" — Şeyh
--                         Abdüsselam mı Mustafa Barzani mi; iki bağımsız denetim
--                         işaretledi → belirsiz.
--   b89716ef… (offline_9668): "Destana Dewrêşê Evdî çi ye?" B ve D şıkları
--                         neredeyse aynı (iki model COK_DOGRU dedi).
-- Silme yok, `is_approved=false` geri alınabilir. Yerelde aynı kimlikler
-- `retired_question_ids.dart` ile oynanmaz oldu; sunucuda b71fc75c…, 8745e3c2…
-- ve dd5a01c2… için yerel karşılık yoktur (yalnız sunucu).
--
-- Kimlik: uuid5(5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77, 'zankurd-local:' + yerel id).

begin;

update public.questions
   set is_approved = false
 where id in (
  'b71fc75c-9b2e-4e1d-89ef-aca3e7e2dd88',  -- yalnız sunucu: metin yok
  '8745e3c2-d0b8-4eb3-9924-8bec2416a67d',  -- yalnız sunucu: metin yok
  '0cf8e955-2850-5e14-9b9f-57ede52e2945',  -- sf_cin_0008
  'f023e0f2-2915-5736-92bc-457854904eda',  -- sf_cin_0007
  '398606d8-fa1d-53e1-bca5-a2f513af5b8d',  -- offline_tf_ede_0019
  'e1cd60c0-814c-5cf2-a7c1-9c44d2f31059',  -- offline_tf_siy_0040
  'dd5a01c2-aa22-4907-b8b2-da2c5cab3277',  -- yalnız sunucu: Kalp/dil sesteşi
  'bb4d417e-241e-504f-ab15-882fe1ddb986',  -- offline_curated_21475
  '0b44b8bf-5e75-577a-9c84-1e4687ebf866',  -- curated_siyaset_0009
  'b89716ef-c9cb-5967-a626-a44764db5c51'   -- offline_9668
);

-- Doğrulama: 10 kimliğin hepsi onaysız olmalı.
do $$
declare n int;
begin
  select count(*) into n from public.questions
   where is_approved = false and id in (
    'b71fc75c-9b2e-4e1d-89ef-aca3e7e2dd88','8745e3c2-d0b8-4eb3-9924-8bec2416a67d',
    '0cf8e955-2850-5e14-9b9f-57ede52e2945','f023e0f2-2915-5736-92bc-457854904eda',
    '398606d8-fa1d-53e1-bca5-a2f513af5b8d','e1cd60c0-814c-5cf2-a7c1-9c44d2f31059',
    'dd5a01c2-aa22-4907-b8b2-da2c5cab3277','bb4d417e-241e-504f-ab15-882fe1ddb986',
    '0b44b8bf-5e75-577a-9c84-1e4687ebf866','b89716ef-c9cb-5967-a626-a44764db5c51');
  if n <> 10 then
    raise exception 'icerik_emekli: beklenen 10, bulunan %', n;
  end if;
end $$;

commit;
