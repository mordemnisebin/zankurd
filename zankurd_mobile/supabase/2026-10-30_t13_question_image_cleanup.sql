-- T13: metinle çözülen îro sorusunda kaldırılmış yerel görsel kalmış.
-- HENÜZ UYGULANMADI. Canlı veri bu çalışma sırasında okunmadı/değiştirilmedi.
-- Kaynak zinciri:
--   2026-08-01_question_distractor_language_fix.sql:1034-1038 (UUID, îro)
--   2026-10-01_server_rescue_fix.sql:583 (aynı UUID, güncel kök ve şıklar)
--   rich_question_bank_v2.sql:142 (eski asset://.../iro.webp)
--   git 3e5ff174: görsel cevabı açık ettiği için dosya kaldırılmış.
-- URL UUID ile canlıda henüz eşlenmedi; aşağıdaki eski değer kontrolü bu
-- nedenle zorunlu. Metin/şık/doğru cevap ve fonksiyon tanımı DEĞİŞMEZ.
-- Önce /Users/kocer/Projects/zankurd_kapisma/t13/images/2026-10-30_t13_question_image_inventory.sql çalıştırılıp gözden
-- geçirilmeli; sonra bu gövde BEGIN ... ROLLBACK içinde denenmelidir.
-- Uygulama için son ROLLBACK yerine COMMIT seçimi yalnız ana ajan/sahibindir.
BEGIN;

DO $t13$
DECLARE
  q public.questions%ROWTYPE;
  changed integer;
BEGIN
  SELECT * INTO q FROM public.questions
   WHERE id = 'd596f0be-684e-4f9d-9451-9308d0eb3cbf'::uuid
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'T13: hedef soru bulunamadı; canlı eşleme gerekir';
  END IF;
  IF q.prompt IS DISTINCT FROM 'Wateya peyva "îro" bi Tirkî kîjan e?'
     OR q.option_a IS DISTINCT FROM 'baba'
     OR q.option_b IS DISTINCT FROM 'soğuk'
     OR q.option_c IS DISTINCT FROM 'kitap'
     OR q.option_d IS DISTINCT FROM 'bugün'
     OR q.correct_option::text IS DISTINCT FROM 'D' THEN
    RAISE EXCEPTION 'T13: soru içeriği değişmiş; güncel kayıt yeniden denetlenmeli';
  END IF;
  IF q.image_url IS NULL THEN
    RAISE NOTICE 'T13: görsel zaten yok; değişiklik yapılmadı';
    RETURN;
  END IF;
  IF q.image_url IS DISTINCT FROM 'asset://assets/question_images/iro.webp' THEN
    RAISE EXCEPTION 'T13: eski görsel URL eşleşmedi; tahminle güncelleme yapılmaz';
  END IF;

  UPDATE public.questions
     SET image_url = NULL, updated_at = now()
   WHERE id = q.id
     AND image_url = 'asset://assets/question_images/iro.webp';
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 1 THEN
    RAISE EXCEPTION 'T13: tam bir satır bekleniyordu, bulunan %', changed;
  END IF;
END
$t13$;

-- Kasıtlı kuru çalışma varsayılanı. Canlıya uygulanmış sayılmaz.
ROLLBACK;
