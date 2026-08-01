-- Sunucudaki sözlük sorularının yabancı dilde çeldiricilerini düzeltir.
--
-- ## Kusur
--
--   Di Kurmancî de peyva "kursî" bi Tirkî çi ye?
--     A) Dört   B) Rûniştin ←Kurmancî   C) Sandalye ✓   D) Öğrenmek
--
--   Peyva Kurmancî "reng" bi Tirkî çi tê gotin?
--     A) bira ←Kurmancî   B) renk ✓   C) reng ←Kurmancî   D) kaya
--
-- İkincisi en kötü hâli: sorulan kelimenin Kurmancî biçimi çeldirici
-- olarak sunuluyor. Dil farkı bilgi gerektirmeyen bir ipucudur — soru
-- "bi Tirkî çi ye?" diyorsa Kurmancî görünen şık bakar bakmaz elenir ve
-- dört şıklık soru fiilen iki şıklığa iner.
--
-- 2026-08-01'de canlı bir oda maçında görüldü. Denetimlerden geçmemişti
-- çünkü `QuestionLanguagePolicy` üç ayrı sebeple kördü — ayrıntı
-- `test/off_language_distractor_ratchet_test.dart` başlığında. Ölçüt
-- düzeltilince sunucudaki 957 sorunun 190'ında bu kusur çıktı.
--
-- ## Yöntem
--
-- Bu depoda kanıtlanmış yol (`tool/fix_offlanguage_distractors.py`):
-- uyumsuz çeldirici, AYNI YÖNDEKİ başka soruların doğru cevaplarıyla
-- değiştirilir. Onlar aynı dilde, benzer uzunlukta ve aynı biçimdedir;
-- ödünç alınan kelime başka bir kavramı anlattığı için bu soruda
-- yanlıştır. Dört kısıt: tek kelimelik adaylar, sorulan terimin bilinen
-- karşılıkları dışlanır (yeni çeldirici ikinci bir doğru cevap olmasın),
-- uzunluk kardeş şıkların ortancasına yakın, büyük/küçük harf
-- DEĞİŞMEYEN şıkların çoğunluğuna uydurulur.
--
-- Kelime dili, bankaların ve sunucunun KENDİ verisinden hasat edilen
-- sözlükle belirlendi ("«X» bi Tirkî çi ye? → Y" her soru X'in Kurmancî,
-- Y'nin Türkçe olduğunu söyler). İki yönde birden görülen eşsesliler
-- (kar, dil, ayak, pencere, rast, şaş) hiçbir yöne sayılmadı.
--
-- ## Güvenlik
--
--   * Hiçbir UPDATE `correct_option`a ya da doğru cevabın sütununa
--     dokunmuyor (üretimde doğrulandı: 0 ihlal).
--   * Her UPDATE değiştirdiği sütunun ESKİ değerini `where` içinde
--     kontrol ediyor: dışa aktarımdan sonra soru değiştiyse ifade 0 satır
--     etkiler, yanlış veri üstüne yazmaz.
--   * Tek işlem: bir ifade düşerse hiçbiri uygulanmaz.
--
-- 195 soru, 268 şık. Uygulandıktan sonra aynı ölçütle kalan: 4 soru —
-- ikisi gerçek ama çok kelimeli tanım şıkkı, ikisi yanlış pozitif:
--
--   239881f2  "Cejn" → «Şal û şapik» Kurmancî; elle değiştirilmeli
--   b1807be4  "Kilam" → «Stranbêjeke jin a navdar» Kurmancî; elle
--   0f73398c  «Askerî zafer» — Türkçedir (şapkalı î), yanlış pozitif
--   386b8e84  «Ev, yol, pazar» — Türkçedir (`ev` eşsesli), yanlış pozitif
--
-- ## Doğrulama
--
-- Uygulandıktan sonra `2026-08-01_question_export_for_audit.sql` yeniden
-- çalıştırılıp CSV `tool/server_questions_export.csv` olarak konur ve
-- `flutter test test/server_question_audit_test.dart` koşulur.

begin;

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "yaşlı/ihtiyar" ye?
--   B: Ben  ->  mêr
update public.questions set option_b = 'mêr'
 where id = '00be1132-62e6-4b27-a883-f9e03cd9db60'
   and option_b = 'Ben';

-- Di Kurmancî de peyva "kaxiz" bi Tirkî çi ye?
--   B: Kursî  ->  Eski
--   D: Ziman  ->  Şarkı
update public.questions set option_b = 'Eski', option_d = 'Şarkı'
 where id = '027fb397-97c3-4a53-ab82-9a0677d9fa09'
   and option_b = 'Kursî' and option_d = 'Ziman';

-- Di Kurmancî de peyva "bajar" bi Tirkî çi ye?
--   C: Zarok  ->  Baba
--   D: Biçûk  ->  Leğen
update public.questions set option_c = 'Baba', option_d = 'Leğen'
 where id = '0360c964-1c84-41a4-8177-1e82332a37cc'
   and option_c = 'Zarok' and option_d = 'Biçûk';

-- Di Kurmancî de peyva "rûniştin" bi Tirkî çi ye?
--   D: Mamoste  ->  Akarsu
update public.questions set option_d = 'Akarsu'
 where id = '0379c63b-59c6-466f-adae-5d3e4fda1297'
   and option_d = 'Mamoste';

-- Di Kurmancî de peyva "rê" bi Tirkî çi ye?
--   D: Duh  ->  Gece
update public.questions set option_d = 'Gece'
 where id = '03c66622-81c1-4d13-b4a5-f0f2a4f4eff7'
   and option_d = 'Duh';

-- Hevwateya "ağız" bi Kurmancî çi ye?
--   D: diş  ->  bav
update public.questions set option_d = 'bav'
 where id = '03c6b627-49ec-495b-a49f-14efffd2de86'
   and option_d = 'diş';

-- Di Kurmancî de peyva "sar" bi Tirkî çi ye?
--   D: Ziman  ->  Doğru
update public.questions set option_d = 'Doğru'
 where id = '0419de57-2915-4608-a708-7cb08b2aa1d7'
   and option_d = 'Ziman';

-- Di Kurmancî de peyva "reng" bi Tirkî çi ye?
--   A: bira  ->  Kitap
--   C: reng  ->  Okul
update public.questions set option_a = 'Kitap', option_c = 'Okul'
 where id = '04603370-98e6-40f6-86ab-fca6dccc060a'
   and option_a = 'bira' and option_c = 'reng';

-- Di Kurmancî de peyva "şev" bi Tirkî çi ye?
--   A: Bira  ->  Doğru
--   C: Xweş  ->  Aslan
update public.questions set option_a = 'Doğru', option_c = 'Aslan'
 where id = '05088ba8-eaf5-4a07-a1e0-52ca91b048e0'
   and option_a = 'Bira' and option_c = 'Xweş';

-- Di Kurmancî de peyva "kursî" bi Tirkî çi ye?
--   B: Rûniştin  ->  Fırıncı
update public.questions set option_b = 'Fırıncı'
 where id = '052bb5cb-6e91-4521-a675-307d8e3894c9'
   and option_b = 'Rûniştin';

-- Di Kurmancî de peyva "hatin" bi Tirkî çi ye?
--   A: Biçûk  ->  Çocuk
update public.questions set option_a = 'Çocuk'
 where id = '05597cd5-b22f-4741-89c7-dcefcc7ec555'
   and option_a = 'Biçûk';

-- "zanîn" (Kurmancî) bi Tirkî kîjan wateyê digire?
--   A: malbat  ->  Kitap
update public.questions set option_a = 'Kitap'
 where id = '05a7389a-5c6e-401c-87c6-d0cdf55f8df7'
   and option_a = 'malbat';

-- Di Kurmancî de peyva "kurd" bi Tirkî çi ye?
--   A: Xweş  ->  Göz
update public.questions set option_a = 'Göz'
 where id = '06e8cfcd-16b1-45e4-826b-6bb333fcd6c9'
   and option_a = 'Xweş';

-- Di Kurmancî de peyva "zarok" bi Tirkî çi ye?
--   A: Nivîn  ->  Deniz
--   D: Biçûk  ->  Gelmek
update public.questions set option_a = 'Deniz', option_d = 'Gelmek'
 where id = '079673a4-9864-41e5-b9f7-30376257e492'
   and option_a = 'Nivîn' and option_d = 'Biçûk';

-- Di wêneya ku têgiha "pir" nîşan dide de, wateya rast kîjan e?
--   A: duh  ->  köy
update public.questions set option_a = 'köy'
 where id = '079eaa08-f5f0-4ae4-a7b2-c0956e021b48'
   and option_a = 'duh';

-- Di Kurmancî de peyva "çiya" bi Tirkî çi ye?
--   A: Pir  ->  Ova
update public.questions set option_a = 'Ova'
 where id = '081f1e64-f18e-40ac-b0c2-40386c997095'
   and option_a = 'Pir';

-- Di Kurmancî de peyva "rû" bi Tirkî çi ye?
--   B: Por  ->  Ling
update public.questions set option_b = 'Ling'
 where id = '096ca1d6-ddc6-40cb-a561-0e8e4613ec7a'
   and option_b = 'Por';

-- Di Kurmancî de peyva "pirtûk" bi Tirkî çi ye?
--   D: Dapîr  ->  Dede
update public.questions set option_d = 'Dede'
 where id = '0bded1fc-8e2f-47c5-baf2-00bcf18f8b73'
   and option_d = 'Dapîr';

-- Di Kurmancî de peyva "dîtin" bi Tirkî çi ye?
--   C: Pirtûk  ->  Rüzgar
update public.questions set option_c = 'Rüzgar'
 where id = '0c1c0b7f-575c-4ec3-84cb-2c3631688796'
   and option_c = 'Pirtûk';

-- Di Kurmancî de peyva "pir" bi Tirkî çi ye?
--   B: Poz  ->  Baba
--   C: Dar  ->  Gece
update public.questions set option_b = 'Baba', option_c = 'Gece'
 where id = '0d33dea9-703c-4e44-a17d-a714e66261b2'
   and option_b = 'Poz' and option_c = 'Dar';

-- Di Kurmancî de peyva "berf" bi Tirkî çi ye?
--   D: Dar  ->  Uzak
update public.questions set option_d = 'Uzak'
 where id = '0eb324b7-2ab6-40e5-a675-cdcc0f2f4c4c'
   and option_d = 'Dar';

-- Çîrok û çîrokên ku zivistanê tên gotin bi giştî bi kurmancî çi tê gotin?
--   A: Ekmek  ->  Kursî
update public.questions set option_a = 'Kursî'
 where id = '133927f0-9045-4a15-92d8-6ad268b44c3b'
   and option_a = 'Ekmek';

-- Di Kurmancî de peyva "bav" bi Tirkî çi ye?
--   C: reng  ->  erkek
update public.questions set option_c = 'erkek'
 where id = '1595e62e-d777-4835-bd95-5b4455d6848d'
   and option_c = 'reng';

-- Di Kurmancî de peyva "biçûk" bi Tirkî çi ye?
--   C: Kursî  ->  Deniz
update public.questions set option_c = 'Deniz'
 where id = '16c7fbf0-6db7-43fa-90db-5ef93d6f4d1e'
   and option_c = 'Kursî';

-- Di Kurmancî de peyva "poz" bi Tirkî çi ye?
--   D: Kursî  ->  Erkek
update public.questions set option_d = 'Erkek'
 where id = '179d5403-3e35-4227-a7ab-58e76ebcb9ab'
   and option_d = 'Kursî';

-- Wateya Tirkî ya peyva "xanî" kîjan e?
--   C: destpêk  ->  işitmek
update public.questions set option_c = 'işitmek'
 where id = '1a16762e-4a39-48cb-b611-66583813b30d'
   and option_c = 'destpêk';

-- Di Kurmancî de peyva "kevin" bi Tirkî çi ye?
--   B: Reng  ->  Ekmek
update public.questions set option_b = 'Ekmek'
 where id = '1adb7a37-6b73-4218-b372-c8f21accfb18'
   and option_b = 'Reng';

-- Di Kurmancî de peyva "zarok" bi Tirkî çi ye?
--   D: Biçûk  ->  Kadın
update public.questions set option_d = 'Kadın'
 where id = '1be0af38-519c-4cd8-9bff-4b9b34db5e83'
   and option_d = 'Biçûk';

-- Ji bo ronahî û hewayê li dîwarê tê vekirin; bi Tirkî kîjan e?
--   C: xwendin  ->  özgürlük
update public.questions set option_c = 'özgürlük'
 where id = '1c975046-0729-46a5-a290-2e460633a497'
   and option_c = 'xwendin';

-- Di Kurmancî de peyva "kûçik" bi Tirkî çi ye?
--   D: Biçûk  ->  Çoban
update public.questions set option_d = 'Çoban'
 where id = '1d2b9f29-a6d2-423a-a7b9-5649bd964e0f'
   and option_d = 'Biçûk';

-- Di Kurmancî de peyva "zanîn" bi Tirkî çi ye?
--   A: Malbat  ->  Ekmek
update public.questions set option_a = 'Ekmek'
 where id = '1e83d019-7b13-4a8a-b1f2-6d1636f1f74c'
   and option_a = 'Malbat';

-- Di Kurmancî de peyva "pencere" bi Tirkî çi ye?
--   B: Xwendin  ->  Kalkmak
update public.questions set option_b = 'Kalkmak'
 where id = '1f345cc5-b602-4ea8-8927-d682ff0f0907'
   and option_b = 'Xwendin';

-- Wateya "ling" (pê) bi Kurmancî çi ye?
--   D: Göz  ->  Dûr
update public.questions set option_d = 'Dûr'
 where id = '1f3ba21b-cb38-46cc-8fc3-6d62ef98f9df'
   and option_d = 'Göz';

-- Di Kurmancî de peyva "duh" bi Tirkî çi ye?
--   A: Por  ->  Köy
--   D: Dar  ->  Aslan
update public.questions set option_a = 'Köy', option_d = 'Aslan'
 where id = '21155940-476a-47ff-8dfd-ff58519410c3'
   and option_a = 'Por' and option_d = 'Dar';

-- Peyva Kurmancî "reng" bi Tirkî çi tê gotin?
--   A: bira  ->  kadın
--   C: reng  ->  ağız
update public.questions set option_a = 'kadın', option_c = 'ağız'
 where id = '21b795ec-c97a-4e1a-b780-028dead37ad0'
   and option_a = 'bira' and option_c = 'reng';

-- Di Kurmancî de peyva "derî" bi Tirkî çi ye?
--   C: Xweş  ->  Diş
update public.questions set option_c = 'Diş'
 where id = '250979c7-80b4-4657-bbd0-0420eb925c5b'
   and option_c = 'Xweş';

-- Di Kurmancî de peyva "mamoste" bi Tirkî çi ye?
--   B: Dibistan  ->  Burun
update public.questions set option_b = 'Burun'
 where id = '267b7097-c6a1-44af-82ca-f6067c9fd665'
   and option_b = 'Dibistan';

-- Di Kurmancî de peyva "rû" bi Tirkî çi ye?
--   A: Dar  ->  Kedi
--   C: Îro  ->  Kapı
update public.questions set option_a = 'Kedi', option_c = 'Kapı'
 where id = '2741b2a0-ba3a-4ec2-893d-3cf2102f7da3'
   and option_a = 'Dar' and option_c = 'Îro';

-- Di çarçoveya Cografyaê de 'deşt' tê çi wateyê?
--   A: gol  ->  Köy
update public.questions set option_a = 'Köy'
 where id = '294f0a13-aea9-4488-a543-9965b63644bf'
   and option_a = 'gol';

-- Di Kurmancî de peyva "çûn" bi Tirkî çi ye?
--   A: malbat  ->  Deniz
update public.questions set option_a = 'Deniz'
 where id = '2a49caef-bc88-433f-a6ba-4f3d8a859575'
   and option_a = 'malbat';

-- Di Kurmancî de peyva "rûniştin" bi Tirkî çi ye?
--   C: Destpêk  ->  Yoğurt
update public.questions set option_c = 'Yoğurt'
 where id = '2a5fef0b-4e95-437e-93ac-017279bf0252'
   and option_c = 'Destpêk';

-- Di Kurmancî de peyva "xwîşk" bi Tirkî çi ye?
--   A: Xwendegeh  ->  Erkek
update public.questions set option_a = 'Erkek'
 where id = '2bd06fd9-9f10-4853-8509-6f4c6fb77e7e'
   and option_a = 'Xwendegeh';

-- Di Kurmancî de peyva "kevin" bi Tirkî çi ye?
--   D: Çiya  ->  Kağıt
update public.questions set option_d = 'Kağıt'
 where id = '2c788c20-a6d8-4ae3-861d-cf25194ca572'
   and option_d = 'Çiya';

-- Di Kurmancî de peyva "mêr" bi Tirkî çi ye?
--   B: Rabûn  ->  Doğru
--   D: Nivîn  ->  Çocuk
update public.questions set option_b = 'Doğru', option_d = 'Çocuk'
 where id = '2f6f9c15-e4ec-4b97-bfaf-5404d70436a9'
   and option_b = 'Rabûn' and option_d = 'Nivîn';

-- Di Kurmancî de peyva "pirtûk" bi Tirkî çi ye?
--   A: Zarok  ->  Ekmek
update public.questions set option_a = 'Ekmek'
 where id = '31560c3e-c727-4fa5-bbb1-53a86dbcfba9'
   and option_a = 'Zarok';

-- Di Kurmancî de peyva "mêr" bi Tirkî çi ye?
--   A: Ciwan  ->  Aile
--   C: Nivîn  ->  Dünya
update public.questions set option_a = 'Aile', option_c = 'Dünya'
 where id = '3455a0ab-5448-4d95-a36d-6b9fbf1894e3'
   and option_a = 'Ciwan' and option_c = 'Nivîn';

-- Di Kurmancî de peyva "hewa" bi Tirkî çi ye?
--   B: Xweş  ->  Ling
--   D: Bira  ->  Kadın
update public.questions set option_b = 'Ling', option_d = 'Kadın'
 where id = '3a080487-f169-4590-b9f1-fd822eb8eee1'
   and option_b = 'Xweş' and option_d = 'Bira';

-- Di Kurmancî de peyva "dê" bi Tirkî çi ye?
--   B: Reng  ->  Aslan
update public.questions set option_b = 'Aslan'
 where id = '3a86363b-9715-4d4f-ad3b-a7ea4054d931'
   and option_b = 'Reng';

-- Di Kurmancî de peyva "pênûs" bi Tirkî çi ye?
--   B: Kursî  ->  Bilmek
--   C: Biçûk  ->  Yayla
update public.questions set option_b = 'Bilmek', option_c = 'Yayla'
 where id = '3b77bdb6-5b97-47a4-8803-d56481f1d239'
   and option_b = 'Kursî' and option_c = 'Biçûk';

-- Di Kurmancî de peyva "duh" bi Tirkî çi ye?
--   B: Dar  ->  Kapı
update public.questions set option_b = 'Kapı'
 where id = '3ba05c6f-be8b-4f78-927a-7a425174e8ac'
   and option_b = 'Dar';

-- Di Kurmancî de peyva "pê" bi Tirkî çi ye?
--   D: Kanî  ->  Dün
update public.questions set option_d = 'Dün'
 where id = '42c73633-d1ca-4342-9227-c66a26681ca5'
   and option_d = 'Kanî';

-- Di Kurmancî de peyva "dibistan" bi Tirkî çi ye?
--   C: Xweş  ->  Ağaç
update public.questions set option_c = 'Ağaç'
 where id = '4456f76b-bc66-481a-a051-5172f98bf151'
   and option_c = 'Xweş';

-- Peyva Kurmancî "biçûk" bi Tirkî çi tê gotin?
--   A: heval  ->  Yatak
update public.questions set option_a = 'Yatak'
 where id = '44f9df2f-5bb8-455c-ad6e-f2910d1bde02'
   and option_a = 'heval';

-- Di Kurmancî de peyva "deşt" bi Tirkî çi ye?
--   C: Por  ->  Vadi
update public.questions set option_c = 'Vadi'
 where id = '46fa37b7-bd4c-4960-9133-b19dbc1d92c4'
   and option_c = 'Por';

-- Di Kurmancî de peyva "xanî" bi Tirkî çi ye?
--   C: Destpêk  ->  Kalkmak
update public.questions set option_c = 'Kalkmak'
 where id = '47b23e42-d718-48ec-b6e1-1c5831142c95'
   and option_c = 'Destpêk';

-- Di Kurmancî de peyva "pencere" bi Tirkî çi ye?
--   C: Xwendin  ->  Kitap
update public.questions set option_c = 'Kitap'
 where id = '4953e36f-40b0-4c4b-b24f-66fe63f0b282'
   and option_c = 'Xwendin';

-- Di Kurmancî de peyva "îro" bi Tirkî çi ye?
--   C: Nivîn  ->  Sınır
update public.questions set option_c = 'Sınır'
 where id = '4a5315ea-60c5-4add-95b5-c6864931e649'
   and option_c = 'Nivîn';

-- Di wêneya ku têgiha "kevin" nîşan dide de, wateya rast kîjan e?
--   D: xweş  ->  dede
update public.questions set option_d = 'dede'
 where id = '4b06ee1e-34a3-431d-9569-c5dc20079847'
   and option_d = 'xweş';

-- Di Kurmancî de peyva "sar" bi Tirkî çi ye?
--   C: Kursî  ->  Bugün
update public.questions set option_c = 'Bugün'
 where id = '4c3ca110-8bd5-406e-96c7-44cce2655533'
   and option_c = 'Kursî';

-- Wêneya "pirtûk" tê çi wateyê?
--   B: zanîn  ->  çoban
update public.questions set option_b = 'çoban'
 where id = '4d9a8242-da28-43bb-babd-f6b0c9d5a24e'
   and option_b = 'zanîn';

-- Di Kurmancî de peyva "xanî" bi Tirkî çi ye?
--   A: Mamoste  ->  Doğru
--   C: Nanxane  ->  Orman
update public.questions set option_a = 'Doğru', option_c = 'Orman'
 where id = '4e3d2c2b-3478-4f65-8754-d6dd8dedddb8'
   and option_a = 'Mamoste' and option_c = 'Nanxane';

-- Di Kurmancî de peyva "kanî" bi Tirkî çi ye?
--   C: Nivîsandin  ->  Yemekhane
update public.questions set option_c = 'Yemekhane'
 where id = '4e61e25f-888e-4ade-b59a-22d11567a3bf'
   and option_c = 'Nivîsandin';

-- Di Kurmancî de peyva "pê" bi Tirkî çi ye?
--   C: Bira  ->  Bugün
update public.questions set option_c = 'Bugün'
 where id = '4ecc448b-60b0-425d-9603-6aaf83fa1156'
   and option_c = 'Bira';

-- Di Kurmancî de peyva "diran" bi Tirkî çi ye?
--   A: Îro  ->  Uzak
update public.questions set option_a = 'Uzak'
 where id = '4f64c5d5-ef05-4610-b710-51ae60a5544b'
   and option_a = 'Îro';

-- Di Kurmancî de peyva "dê" bi Tirkî çi ye?
--   C: Kanî  ->  Erkek
--   D: Xweş  ->  Kadın
update public.questions set option_c = 'Erkek', option_d = 'Kadın'
 where id = '5220a3ba-1b18-41ac-abeb-7b9b6712f45f'
   and option_c = 'Kanî' and option_d = 'Xweş';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "arkadaş" ye?
--   A: Küçük  ->  bajar
--   C: doğru  ->  dest
update public.questions set option_a = 'bajar', option_c = 'dest'
 where id = '53b37b26-ebde-487f-9159-ae8355106578'
   and option_a = 'Küçük' and option_c = 'doğru';

-- Di Kurmancî de peyva "xweş" bi Tirkî çi ye?
--   B: Xwendegeh  ->  Dünya
update public.questions set option_b = 'Dünya'
 where id = '567e8c31-1f06-407f-adbe-942288a0ac77'
   and option_b = 'Xwendegeh';

-- Di Kurmancî de peyva "xweş" bi Tirkî çi ye?
--   B: Xwendekar  ->  Fırıncı
update public.questions set option_b = 'Fırıncı'
 where id = '581240a9-8942-4265-b8db-13d4bb96c425'
   and option_b = 'Xwendekar';

-- Di Kurmancî de peyva "sar" bi Tirkî çi ye?
--   C: Nivîn  ->  Leğen
update public.questions set option_c = 'Leğen'
 where id = '58ebbeed-e60d-4a39-9a49-65003d2875dc'
   and option_c = 'Nivîn';

-- Di Kurmancî de peyva "por" bi Tirkî çi ye?
--   A: Dar  ->  Yüz
--   B: Poz  ->  Bugün
update public.questions set option_a = 'Yüz', option_b = 'Bugün'
 where id = '5ae2e34e-67e5-42a3-b31f-0a3eecd01978'
   and option_a = 'Dar' and option_b = 'Poz';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "kapı" ye?
--   B: Renk  ->  bajar
--   D: ağız  ->  teşt
update public.questions set option_b = 'bajar', option_d = 'teşt'
 where id = '5fb694f7-7d93-41bb-a759-eafb14f94fbd'
   and option_b = 'Renk' and option_d = 'ağız';

-- Di Kurmancî de peyva "heval" bi Tirkî çi ye?
--   A: Nanxane  ->  Yoğurt
update public.questions set option_a = 'Yoğurt'
 where id = '600ca4ed-833f-4a0e-8f78-f80704e10b93'
   and option_a = 'Nanxane';

-- Di Kurmancî de peyva "bajar" bi Tirkî çi ye?
--   B: Nivîn  ->  Burun
update public.questions set option_b = 'Burun'
 where id = '61bbd143-1cfc-4834-8beb-ac23e548aa92'
   and option_b = 'Nivîn';

-- Di Kurmancî de peyva "guh" bi Tirkî çi ye?
--   A: Ziman  ->  Nehir
--   C: Kursî  ->  Aile
update public.questions set option_a = 'Nehir', option_c = 'Aile'
 where id = '622ab99e-a12a-4ba8-a070-d577ae0ac616'
   and option_a = 'Ziman' and option_c = 'Kursî';

-- Peyva Kurmancî "jin" bi Tirkî çi tê gotin?
--   C: ciwan  ->  ağız
update public.questions set option_c = 'ağız'
 where id = '63b99d58-6509-4158-be1a-5452e4ef8f9c'
   and option_c = 'ciwan';

-- Di Kurmancî de peyva "rû" bi Tirkî çi ye?
--   D: Poz  ->  Ağız
update public.questions set option_d = 'Ağız'
 where id = '64ec4bb8-a9f8-43b0-8a36-ee073ff4bcf6'
   and option_d = 'Poz';

-- Di Kurmancî de peyva "newal" bi Tirkî çi ye?
--   B: Reng  ->  Gece
update public.questions set option_b = 'Gece'
 where id = '6635ac10-3477-4d74-9a9f-eb509aaf5d94'
   and option_b = 'Reng';

-- Di Kurmancî de peyva "dil" bi Tirkî çi ye?
--   D: Dibistan  ->  Doğru
update public.questions set option_d = 'Doğru'
 where id = '66b8d665-b78e-4f7f-871a-792f6735dea6'
   and option_d = 'Dibistan';

-- Wateya Tirkî ya peyva "pirtûk" kîjan e?
--   A: zarok  ->  Sanat
update public.questions set option_a = 'Sanat'
 where id = '67a2cd90-215a-4928-b8fe-d9deef69b43e'
   and option_a = 'zarok';

-- Di Kurmancî de peyva "baran" bi Tirkî çi ye?
--   C: Malbat  ->  Kulak
update public.questions set option_c = 'Kulak'
 where id = '68519782-fe8a-4f24-980c-237fe65d860e'
   and option_c = 'Malbat';

-- Di Kurmancî de peyva "çav" bi Tirkî çi ye?
--   B: Îro  ->  Masa
update public.questions set option_b = 'Masa'
 where id = '69818f6a-67b3-4ece-8a7a-7f7663a38061'
   and option_b = 'Îro';

-- Di Kurmancî de peyva "çav" bi Tirkî çi ye?
--   A: Dar  ->  Uzak
update public.questions set option_a = 'Uzak'
 where id = '6b3e6137-0abc-4e2f-8c7b-da24bc1f7287'
   and option_a = 'Dar';

-- Di Kurmancî de peyva "şêr" bi Tirkî çi ye?
--   C: Ciwan  ->  Bugün
update public.questions set option_c = 'Bugün'
 where id = '6b6a98a7-8ea6-4e05-af56-abff6fbfbe88'
   and option_c = 'Ciwan';

-- Di Kurmancî de peyva "bav" bi Tirkî çi ye?
--   A: Xweş  ->  Vadi
--   D: Çiya  ->  Aslan
update public.questions set option_a = 'Vadi', option_d = 'Aslan'
 where id = '6e1c3a08-dde1-4065-aa98-f3176b4f29b0'
   and option_a = 'Xweş' and option_d = 'Çiya';

-- Di Kurmancî de peyva "welat" bi Tirkî çi ye?
--   B: Xwendegeh  ->  Kadın
update public.questions set option_b = 'Kadın'
 where id = '6e35f477-7fc5-40d2-9ca8-75cc79a6b4e4'
   and option_b = 'Xwendegeh';

-- Di Kurmancî de peyva "guh" bi Tirkî çi ye?
--   A: Ciwan  ->  Kitap
--   D: Kursî  ->  Köpek
update public.questions set option_a = 'Kitap', option_d = 'Köpek'
 where id = '6ea10329-7e98-4ed3-aa81-c2b92a74cacf'
   and option_a = 'Ciwan' and option_d = 'Kursî';

-- Di Kurmancî de peyva "rê" bi Tirkî çi ye?
--   A: Por  ->  Ağaç
update public.questions set option_a = 'Ağaç'
 where id = '6eff4222-3c0e-432c-b881-eb4ac7652ada'
   and option_a = 'Por';

-- Di Kurmancî de peyva "gund" bi Tirkî çi ye?
--   B: Por  ->  Aslan
--   C: Şêr  ->  Yaz
--   D: Poz  ->  Hava
update public.questions set option_b = 'Aslan', option_c = 'Yaz', option_d = 'Hava'
 where id = '6f811590-f94a-40ab-8a51-2a6caec30582'
   and option_b = 'Por' and option_c = 'Şêr' and option_d = 'Poz';

-- Wateya Tirkî ya peyva "kurd" kîjan e?
--   C: reng  ->  Ekmek
--   D: xweş  ->  Kulak
update public.questions set option_c = 'Ekmek', option_d = 'Kulak'
 where id = '70328e7d-8a74-4675-8f29-60c93585d991'
   and option_c = 'reng' and option_d = 'xweş';

-- Di Kurmancî de peyva "pênûs" bi Tirkî çi ye?
--   A: Dapîr  ->  Sanat
--   D: Rabûn  ->  Orman
update public.questions set option_a = 'Sanat', option_d = 'Orman'
 where id = '714162ed-dc8f-46a9-8d81-cf584c9d3383'
   and option_a = 'Dapîr' and option_d = 'Rabûn';

-- Di Kurmancî de peyva "ciwan" bi Tirkî çi ye?
--   B: Kanî  ->  Renk
--   C: Bira  ->  Burun
update public.questions set option_b = 'Renk', option_c = 'Burun'
 where id = '7206295a-f374-4108-b8fb-85fac6a3ece8'
   and option_b = 'Kanî' and option_c = 'Bira';

-- Di Kurmancî de peyva "nan" bi Tirkî çi ye?
--   A: Kursî  ->  Aile
--   C: Dapîr  ->  Bugün
--   D: Ziman  ->  Doğru
update public.questions set option_a = 'Aile', option_c = 'Bugün', option_d = 'Doğru'
 where id = '722817b1-6911-4168-a71a-fb82eb609e0c'
   and option_a = 'Kursî' and option_c = 'Dapîr' and option_d = 'Ziman';

-- Di Kurmancî de peyva "nanpêj" bi Tirkî çi ye?
--   A: Xwendin  ->  Doğru
update public.questions set option_a = 'Doğru'
 where id = '7551839b-b838-4846-80b2-b9aaa7a77f52'
   and option_a = 'Xwendin';

-- Di Kurmancî de peyva "jin" bi Tirkî çi ye?
--   C: Ciwan  ->  Dede
update public.questions set option_c = 'Dede'
 where id = '7611a4bc-00f5-43a2-a06d-89b18e8e5e35'
   and option_c = 'Ciwan';

-- Di Kurmancî de peyva "huner" bi Tirkî çi ye?
--   A: Nivîn  ->  Küçük
--   C: Ciwan  ->  Anne
update public.questions set option_a = 'Küçük', option_c = 'Anne'
 where id = '77df17d7-7913-45f6-ab99-81dd331e39ad'
   and option_a = 'Nivîn' and option_c = 'Ciwan';

-- Di Kurmancî de peyva "guh" bi Tirkî çi ye?
--   B: Kursî  ->  Bilmek
--   C: Biçûk  ->  Aslan
update public.questions set option_b = 'Bilmek', option_c = 'Aslan'
 where id = '7a73b2e2-f952-4a5e-8178-0e737137d49e'
   and option_b = 'Kursî' and option_c = 'Biçûk';

-- Hevwateya "sevmek" bi Kurmancî çi ye?
--   C: sandalye  ->  diran
update public.questions set option_c = 'diran'
 where id = '7ae8cdd8-c938-4749-bae5-1f218c02af77'
   and option_c = 'sandalye';

-- Di Kurmancî de peyva "deng" bi Tirkî çi ye?
--   C: Şêr  ->  Yol
update public.questions set option_c = 'Yol'
 where id = '7b2efe2a-8590-49f9-83be-511b4c304f67'
   and option_c = 'Şêr';

-- Di Kurmancî de peyva "roj" bi Tirkî çi ye?
--   B: Xwendekar  ->  Yazmak
update public.questions set option_b = 'Yazmak'
 where id = '7c4f6721-1ca6-4b12-beee-529a5bb77ea8'
   and option_b = 'Xwendekar';

-- Wateya Tirkî ya peyva "kevin" kîjan e?
--   D: çiya  ->  ling
update public.questions set option_d = 'ling'
 where id = '7fcdee75-9c1b-4438-b21e-f81bda5f1b7c'
   and option_d = 'çiya';

-- Di Kurmancî de peyva "duh" bi Tirkî çi ye?
--   A: Pir  ->  Yüz
--   B: Nan  ->  Kedi
update public.questions set option_a = 'Yüz', option_b = 'Kedi'
 where id = '807cdac4-6576-4ba5-a216-ebf004d78ffa'
   and option_a = 'Pir' and option_b = 'Nan';

-- Di Kurmancî de peyva "malbat" bi Tirkî çi ye?
--   C: Bira  ->  Baba
update public.questions set option_c = 'Baba'
 where id = '8164c75e-c557-487a-8d40-f03b8f28629e'
   and option_c = 'Bira';

-- Di Kurmancî de peyva "kevin" bi Tirkî çi ye?
--   A: Bira  ->  Dağ
update public.questions set option_a = 'Dağ'
 where id = '81c9407a-fca9-439d-b2a8-846b6120bc9f'
   and option_a = 'Bira';

-- Peyva Kurmancî "heval" bi Tirkî çi tê gotin?
--   A: nanxane  ->  kağıt
update public.questions set option_a = 'kağıt'
 where id = '81e81c4d-c55c-4987-9b1e-a38ed93827e4'
   and option_a = 'nanxane';

-- Di Kurmancî de peyva "heval" bi Tirkî çi ye?
--   A: Nanxane  ->  Kulak
update public.questions set option_a = 'Kulak'
 where id = '854c1209-ce60-4ee5-891f-0676e82deab9'
   and option_a = 'Nanxane';

-- Di Kurmancî de peyva "pirtûk" bi Tirkî çi ye?
--   B: Nivîn  ->  Akarsu
--   C: Dapîr  ->  Aile
--   D: Biçûk  ->  Kağıt
update public.questions set option_b = 'Akarsu', option_c = 'Aile', option_d = 'Kağıt'
 where id = '8581ded9-752b-42a8-bf3f-1e986e372ff1'
   and option_b = 'Nivîn' and option_c = 'Dapîr' and option_d = 'Biçûk';

-- Di Kurmancî de peyva "kurd" bi Tirkî çi ye?
--   C: Reng  ->  Ekmek
--   D: Xweş  ->  Kağıt
update public.questions set option_c = 'Ekmek', option_d = 'Kağıt'
 where id = '8637b19d-736d-4464-8930-2e256c012daf'
   and option_c = 'Reng' and option_d = 'Xweş';

-- Di Kurmancî de peyva "ziman" bi Tirkî çi ye?
--   B: Çav  ->  Dağ
update public.questions set option_b = 'Dağ'
 where id = '8654d399-0806-4384-af35-6e150db4eccf'
   and option_b = 'Çav';

-- Di Kurmancî de peyva "mase" bi Tirkî çi ye?
--   A: Kanî  ->  Kedi
--   B: Xweş  ->  Genç
update public.questions set option_a = 'Kedi', option_b = 'Genç'
 where id = '8a65179a-8937-45de-a4d9-fe1decf1993c'
   and option_a = 'Kanî' and option_b = 'Xweş';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "kalp/dil" ye?
--   B: ben  ->  hewa
update public.questions set option_b = 'hewa'
 where id = '8c02838e-3fb0-4b12-bd5b-bc44fafce5d4'
   and option_b = 'ben';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "bugün" ye?
--   C: çok  ->  çem
update public.questions set option_c = 'çem'
 where id = '8c131d5d-d56e-4135-80de-a9159fa54086'
   and option_c = 'çok';

-- Di Kurmancî de peyva "pirtûk" bi Tirkî çi ye?
--   D: Nivîn  ->  Erkek
update public.questions set option_d = 'Erkek'
 where id = '8e19ca77-150e-4136-b119-c2a5416d8899'
   and option_d = 'Nivîn';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "yatak" ye?
--   A: kadın  ->  Agir
--   C: doğru  ->  Stêrk
update public.questions set option_a = 'Agir', option_c = 'Stêrk'
 where id = '8e4862df-e06b-47fb-80c6-263bef4fc1c1'
   and option_a = 'kadın' and option_c = 'doğru';

-- Di Kurmancî de peyva "çûn" bi Tirkî çi ye?
--   C: Malbat  ->  Rüzgar
update public.questions set option_c = 'Rüzgar'
 where id = '90026e36-5c5a-4802-88a4-7f1489041db6'
   and option_c = 'Malbat';

-- Di Kurmancî de peyva "çiya" bi Tirkî çi ye?
--   C: Şêr  ->  Kaya
update public.questions set option_c = 'Kaya'
 where id = '918c2a97-99d8-4062-8e95-2d448d406751'
   and option_c = 'Şêr';

-- Wêne "biçûk" dibêje — wateya rast kîjan e?
--   D: heval  ->  kulak
update public.questions set option_d = 'kulak'
 where id = '93e302b6-e647-4ea9-95ba-4d54acc801b9'
   and option_d = 'heval';

-- Di Kurmancî de peyva "dev" bi Tirkî çi ye?
--   B: Xweş  ->  Beş
update public.questions set option_b = 'Beş'
 where id = '9698241c-04b1-46ed-88f9-51f4f3ca7542'
   and option_b = 'Xweş';

-- Di Kurmancî de peyva "kursî" bi Tirkî çi ye?
--   A: Dibistan  ->  Kalkmak
update public.questions set option_a = 'Kalkmak'
 where id = '96e4965c-f592-4a62-a35f-cfc640f42a6c'
   and option_a = 'Dibistan';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "su" ye?
--   C: okul  ->  dar
update public.questions set option_c = 'dar'
 where id = '9d681213-a56d-48cb-b4de-270363503982'
   and option_c = 'okul';

-- Di Kurmancî de peyva "şêr" bi Tirkî çi ye?
--   C: Rabûn  ->  Aile
--   D: Biçûk  ->  Doğru
update public.questions set option_c = 'Aile', option_d = 'Doğru'
 where id = '9efdb579-11b8-43c7-9293-88194f69a43f'
   and option_c = 'Rabûn' and option_d = 'Biçûk';

-- Hevwateya "masa" bi Kurmancî çi ye?
--   A: eski  ->  wêne
--   B: ağız  ->  diran
update public.questions set option_a = 'wêne', option_b = 'diran'
 where id = 'a09c603c-97ad-4223-b276-236fce3dd18d'
   and option_a = 'eski' and option_b = 'ağız';

-- Di Kurmancî de peyva "dar" bi Tirkî çi ye?
--   B: Bira  ->  Doğru
--   D: Reng  ->  Anne
update public.questions set option_b = 'Doğru', option_d = 'Anne'
 where id = 'a1c738c2-b52d-4464-bae0-b4458f06c333'
   and option_b = 'Bira' and option_d = 'Reng';

-- Di Kurmancî de peyva "berf" bi Tirkî çi ye?
--   A: Îro  ->  Yaz
--   D: Por  ->  Göl
update public.questions set option_a = 'Yaz', option_d = 'Göl'
 where id = 'a293b2d2-4833-4e8b-9e9d-5269fd938692'
   and option_a = 'Îro' and option_d = 'Por';

-- Di Kurmancî de peyva "kaxiz" bi Tirkî çi ye?
--   C: Ciwan  ->  Kulak
update public.questions set option_c = 'Kulak'
 where id = 'a70ccf9b-9672-4d56-ba63-cb4f4c7e1150'
   and option_c = 'Ciwan';

-- Ev wêne kîjan têgihê tîne bîra we: "rast" — wateya rast hilbijêrin.
--   B: zarok  ->  gitmek
update public.questions set option_b = 'gitmek'
 where id = 'a8c10abd-e7be-4767-b9fa-b4b9edf8da55'
   and option_b = 'zarok';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "işitmek" ye?
--   A: öğretmen  ->  nivîsandin
--   C: sandalye  ->  ciwan
update public.questions set option_a = 'nivîsandin', option_c = 'ciwan'
 where id = 'a90ab94e-2d69-4582-a6dd-0a463c6f1b6d'
   and option_a = 'öğretmen' and option_c = 'sandalye';

-- Di Kurmancî de peyva "nivîn" bi Tirkî çi ye?
--   A: Nivîn  ->  Sanat
update public.questions set option_a = 'Sanat'
 where id = 'aa96a730-b2d8-4d98-9c23-56303e41a8b1'
   and option_a = 'Nivîn';

-- Di Kurmancî de peyva "pênûs" bi Tirkî çi ye?
--   A: Nivîn  ->  Şarkı
update public.questions set option_a = 'Şarkı'
 where id = 'abdedcec-6052-4adc-a7c4-094f488a9725'
   and option_a = 'Nivîn';

-- Di Kurmancî de peyva "agir" bi Tirkî çi ye?
--   A: Reng  ->  Eski
--   B: Xweş  ->  Beş
update public.questions set option_a = 'Eski', option_b = 'Beş'
 where id = 'acdd0b0a-2567-48d8-bf87-5aec1f513543'
   and option_a = 'Reng' and option_b = 'Xweş';

-- Di Kurmancî de peyva "nivîn" bi Tirkî çi ye?
--   D: Biçûk  ->  Genç
update public.questions set option_d = 'Genç'
 where id = 'ad37f359-2194-4b07-a3bc-d3b26b33fc6f'
   and option_d = 'Biçûk';

-- Di Kurmancî de peyva "nivîn" bi Tirkî çi ye?
--   C: Biçûk  ->  Ekmek
update public.questions set option_c = 'Ekmek'
 where id = 'adf214db-430a-41b6-9f6d-de001a91a5c2'
   and option_c = 'Biçûk';

-- Di Kurmancî de peyva "mase" bi Tirkî çi ye?
--   A: Kanî  ->  Dağ
--   C: Bira  ->  Ling
update public.questions set option_a = 'Dağ', option_c = 'Ling'
 where id = 'ae91a632-5aa7-4d98-9407-aed1b3b951f2'
   and option_a = 'Kanî' and option_c = 'Bira';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "sandalye" ye?
--   B: burun  ->  dapîr
update public.questions set option_b = 'dapîr'
 where id = 'b29b768e-c690-4de3-9927-947d4b5e337c'
   and option_b = 'burun';

-- Di Kurmancî de peyva "nivîn" bi Tirkî çi ye?
--   D: Ciwan  ->  Görmek
update public.questions set option_d = 'Görmek'
 where id = 'b40214a9-589f-4e6e-949a-b26031d6cf4f'
   and option_d = 'Ciwan';

-- Hevwateya "renk" bi Kurmancî çi ye?
--   A: ağız  ->  wêne
--   C: eski  ->  deng
--   D: baba  ->  cejn
update public.questions set option_a = 'wêne', option_c = 'deng', option_d = 'cejn'
 where id = 'b4a2c354-0498-4195-838d-26bac5b7cc95'
   and option_a = 'ağız' and option_c = 'eski' and option_d = 'baba';

-- Wateya Tirkî ya peyva "çûn" kîjan e?
--   C: malbat  ->  yatak
update public.questions set option_c = 'yatak'
 where id = 'b5e87997-548c-4153-82f1-8cf877ebabc3'
   and option_c = 'malbat';

-- Di Kurmancî de peyva "xwendekar" bi Tirkî çi ye?
--   C: Mamoste  ->  Dünya
update public.questions set option_c = 'Dünya'
 where id = 'b89bf8bb-5453-4f64-89fe-361016728f02'
   and option_c = 'Mamoste';

-- Di Kurmancî de peyva "bihîstin" bi Tirkî çi ye?
--   D: Destpêk  ->  Bugün
update public.questions set option_d = 'Bugün'
 where id = 'ba97f952-2a55-43d5-807a-fa10732e05c4'
   and option_d = 'Destpêk';

-- Di Kurmancî de peyva "welat" bi Tirkî çi ye?
--   B: Nivîsandin  ->  Aslan
update public.questions set option_b = 'Aslan'
 where id = 'bbb13a3d-b6d0-4abd-b93f-fc25132cac7b'
   and option_b = 'Nivîsandin';

-- Peyva Kurmancî "dê" bi Tirkî çi tê gotin?
--   C: kanî  ->  şiir
--   D: xweş  ->  uzak
update public.questions set option_c = 'şiir', option_d = 'uzak'
 where id = 'bced3267-903a-4bd2-964a-b09f9a1fad1f'
   and option_c = 'kanî' and option_d = 'xweş';

-- Di Kurmancî de peyva "derî" bi Tirkî çi ye?
--   B: Xweş  ->  Eski
update public.questions set option_b = 'Eski'
 where id = 'c005fbe4-c425-4e9b-9d01-4abd4c21c941'
   and option_b = 'Xweş';

-- "mamoste" (Kurmancî) bi Tirkî kîjan wateyê digire?
--   B: dibistan  ->  kalkmak
update public.questions set option_b = 'kalkmak'
 where id = 'c072eae3-a852-4774-8b4e-6b1205b74053'
   and option_b = 'dibistan';

-- Peyva Kurmancî "malbat" bi Tirkî çi tê gotin?
--   C: reng  ->  gece
update public.questions set option_c = 'gece'
 where id = 'c1305dac-c9f0-4d2a-b1cb-b791f6979298'
   and option_c = 'reng';

-- Di Kurmancî de peyva "welat" bi Tirkî çi ye?
--   D: Xwendegeh  ->  Arkadaş
update public.questions set option_d = 'Arkadaş'
 where id = 'c532fb6a-625f-4471-b9c5-900bfce4d20e'
   and option_d = 'Xwendegeh';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "el" ye?
--   B: ateş  ->  deng
--   D: kaya  ->  deh
update public.questions set option_b = 'deng', option_d = 'deh'
 where id = 'c5aed4c2-e347-46c5-9091-32681a2c6795'
   and option_b = 'ateş' and option_d = 'kaya';

-- "nivîn" (Kurmancî) bi Tirkî kîjan wateyê digire?
--   C: biçûk  ->  dünya
update public.questions set option_c = 'dünya'
 where id = 'c7b6921b-db72-4b19-8a9e-6db0168281b2'
   and option_c = 'biçûk';

-- Ji çîrok û serpêhatiyên ku zivistanan têne vegotin re bi Kurmancî bi giştî çi tê gotin?
--   A: Ekmek  ->  Cejn
update public.questions set option_a = 'Cejn'
 where id = 'c803ec17-b39e-4161-8d0e-15b133efe592'
   and option_a = 'Ekmek';

-- Di Kurmancî de peyva "nanxane" bi Tirkî çi ye?
--   D: Xwendegeh  ->  Teşekkürler
update public.questions set option_d = 'Teşekkürler'
 where id = 'cd84c47f-c6dc-4426-8784-0dc0da290c6e'
   and option_d = 'Xwendegeh';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "ülke/vatan" ye?
--   C: Küçük  ->  cîhan
update public.questions set option_c = 'cîhan'
 where id = 'ce5964dc-c2b6-4e2c-a6a4-aa33cfb552c6'
   and option_c = 'Küçük';

-- Di Kurmancî de peyva "ser" bi Tirkî çi ye?
--   B: Bihîstin  ->  Konuşmak
update public.questions set option_b = 'Konuşmak'
 where id = 'cfc5090a-ce36-4603-a28f-03456fb1ea4e'
   and option_b = 'Bihîstin';

-- Di Kurmancî de peyva "îro" bi Tirkî çi ye?
--   C: Ziman  ->  Doğru
--   D: Biçûk  ->  Dünya
update public.questions set option_c = 'Doğru', option_d = 'Dünya'
 where id = 'cff5837b-e471-47d8-990f-07dee69726ce'
   and option_c = 'Ziman' and option_d = 'Biçûk';

-- Hevwateya "bina/ev" bi Kurmancî çi ye?
--   D: ateş  ->  deşt
update public.questions set option_d = 'deşt'
 where id = 'd0088dd7-ec08-4944-baa8-40ccdd543877'
   and option_d = 'ateş';

-- Di Kurmancî de peyva "cîhan" bi Tirkî çi ye?
--   D: Rabûn  ->  Sınır
update public.questions set option_d = 'Sınır'
 where id = 'd38231bc-b2ec-4a00-8c18-e394feadb5b1'
   and option_d = 'Rabûn';

-- Di Kurmancî de peyva "biçûk" bi Tirkî çi ye?
--   A: Ziman  ->  Ateş
update public.questions set option_a = 'Ateş'
 where id = 'd4e32185-cbf5-4339-b6ab-14595282f145'
   and option_a = 'Ziman';

-- Di wêneya ku têgiha "îro" nîşan dide de, wateya rast kîjan e?
--   A: biçûk  ->  baba
update public.questions set option_a = 'baba'
 where id = 'd596f0be-684e-4f9d-9451-9308d0eb3cbf'
   and option_a = 'biçûk';

-- Di Kurmancî de peyva "cîhan" bi Tirkî çi ye?
--   A: Ciwan  ->  Anne
--   B: Dapîr  ->  Çocuk
--   C: Rabûn  ->  Soğuk
update public.questions set option_a = 'Anne', option_b = 'Çocuk', option_c = 'Soğuk'
 where id = 'd5f396fe-0f96-4d57-9e15-a4fad4817f14'
   and option_a = 'Ciwan' and option_b = 'Dapîr' and option_c = 'Rabûn';

-- Hevwateya "baba" bi Kurmancî çi ye?
--   A: diş  ->  gol
--   D: ben  ->  dar
update public.questions set option_a = 'gol', option_d = 'dar'
 where id = 'd8893e88-7b5b-4a6c-87da-4d5febc6e9e9'
   and option_a = 'diş' and option_d = 'ben';

-- Di Kurmancî de peyva "xwîşk" bi Tirkî çi ye?
--   A: Nivîsandin  ->  Yemekhane
update public.questions set option_a = 'Yemekhane'
 where id = 'd90b30f4-978b-4b72-923d-7e0e6b91770c'
   and option_a = 'Nivîsandin';

-- "dil" (Kurmancî) bi Tirkî kîjan wateyê digire?
--   C: rûniştin  ->  bugün
update public.questions set option_c = 'bugün'
 where id = 'dab11780-c8ff-4b15-942e-fd1146c60094'
   and option_c = 'rûniştin';

-- Di Kurmancî de peyva "derî" bi Tirkî çi ye?
--   B: Xweş  ->  Ağaç
update public.questions set option_b = 'Ağaç'
 where id = 'dafe689d-705d-406e-992b-5a478118c53a'
   and option_b = 'Xweş';

-- Di Kurmancî de peyva "jin" bi Tirkî çi ye?
--   B: Dapîr  ->  Genç
--   C: Kursî  ->  Küçük
update public.questions set option_b = 'Genç', option_c = 'Küçük'
 where id = 'dc09d2f5-0208-43ae-8d61-2d5e3490a2ec'
   and option_b = 'Dapîr' and option_c = 'Kursî';

-- Di Kurmancî de peyva "pir" bi Tirkî çi ye?
--   A: Dar  ->  Aslan
--   C: Poz  ->  Aile
update public.questions set option_a = 'Aslan', option_c = 'Aile'
 where id = 'dcf1bbbe-7580-401a-bf4a-2067a82336b5'
   and option_a = 'Dar' and option_c = 'Poz';

-- Di Kurmancî de peyva "dil" bi Tirkî çi ye?
--   C: Rûniştin  ->  Kalem
update public.questions set option_c = 'Kalem'
 where id = 'dd5a01c2-aa22-4907-b8b2-da2c5cab3277'
   and option_c = 'Rûniştin';

-- Di Kurmancî de peyva "malbat" bi Tirkî çi ye?
--   A: Xweş  ->  Vadi
--   C: Bira  ->  Eski
update public.questions set option_a = 'Vadi', option_c = 'Eski'
 where id = 'df65730b-cd3f-4672-86dd-ea28ac0d4490'
   and option_a = 'Xweş' and option_c = 'Bira';

-- Di Kurmancî de peyva "huner" bi Tirkî çi ye?
--   B: Ziman  ->  Gelmek
--   C: Ciwan  ->  Eski
update public.questions set option_b = 'Gelmek', option_c = 'Eski'
 where id = 'e1d0aa70-0ab3-45d7-86f9-16100eaf288b'
   and option_b = 'Ziman' and option_c = 'Ciwan';

-- Di Kurmancî de peyva "guh" bi Tirkî çi ye?
--   D: Ziman  ->  Ağaç
update public.questions set option_d = 'Ağaç'
 where id = 'e2e770fc-7546-4ef9-b982-30b6fe5cf75f'
   and option_d = 'Ziman';

-- Nîşana wêneyê: "duh". Wateya wê çi ye?
--   D: duh  ->  gece
update public.questions set option_d = 'gece'
 where id = 'e3290aec-3e91-4c45-9a57-97dc3afc9750'
   and option_d = 'duh';

-- Peyva Kurmancî "çem" bi Tirkî çi tê gotin?
--   A: ciwan  ->  anne
--   D: kursî  ->  aslan
update public.questions set option_a = 'anne', option_d = 'aslan'
 where id = 'e35be922-7fe9-4133-8244-0cd266330130'
   and option_a = 'ciwan' and option_d = 'kursî';

-- Di Kurmancî de peyva "derya" bi Tirkî çi ye?
--   A: Nivîn  ->  Eski
--   C: Rabûn  ->  Ağaç
update public.questions set option_a = 'Eski', option_c = 'Ağaç'
 where id = 'e3a2713d-4d74-40de-a304-8f1e8fb4496a'
   and option_a = 'Nivîn' and option_c = 'Rabûn';

-- Di Kurmancî de peyva "jin" bi Tirkî çi ye?
--   A: Ciwan  ->  Köpek
--   D: Biçûk  ->  Deniz
update public.questions set option_a = 'Köpek', option_d = 'Deniz'
 where id = 'e3ee9219-3314-40d4-b5b6-5d68a2be6780'
   and option_a = 'Ciwan' and option_d = 'Biçûk';

-- Di Kurmancî de peyva "kal" bi Tirkî çi ye?
--   D: bira  ->  Ben
update public.questions set option_d = 'Ben'
 where id = 'e47f4e78-d413-47d2-8f3b-a6f945b04f92'
   and option_d = 'bira';

-- Di Kurmancî de peyva "çem" bi Tirkî çi ye?
--   A: Ciwan  ->  Deniz
--   D: Kursî  ->  Ateş
update public.questions set option_a = 'Deniz', option_d = 'Ateş'
 where id = 'e4cb5da2-f8a4-4264-bd49-022445359bec'
   and option_a = 'Ciwan' and option_d = 'Kursî';

-- Di Kurmancî de peyva "hewa" bi Tirkî çi ye?
--   C: bira  ->  Şiir
update public.questions set option_c = 'Şiir'
 where id = 'e5286205-4586-409d-9e8e-99be8638515d'
   and option_c = 'bira';

-- Di Kurmancî de peyva "reng" bi Tirkî çi ye?
--   A: Reng  ->  Kulak
--   C: Kanî  ->  Ben
update public.questions set option_a = 'Kulak', option_c = 'Ben'
 where id = 'e679094f-d532-47d7-b520-050b4ca29178'
   and option_a = 'Reng' and option_c = 'Kanî';

-- Di Kurmancî de peyva "poz" bi Tirkî çi ye?
--   A: Ziman  ->  Deniz
--   B: Kursî  ->  Yayla
update public.questions set option_a = 'Deniz', option_b = 'Yayla'
 where id = 'e755411f-8b71-4a2e-8b0c-03969f266396'
   and option_a = 'Ziman' and option_b = 'Kursî';

-- Di Kurmancî de peyva "xweş" bi Tirkî çi ye?
--   C: Xwendekar  ->  Toprak
update public.questions set option_c = 'Toprak'
 where id = 'e789d15b-df3d-4b71-99b2-f31f8f3b9e3d'
   and option_c = 'Xwendekar';

-- Di Kurmancî de peyva "şêr" bi Tirkî çi ye?
--   C: Rabûn  ->  Köpek
update public.questions set option_c = 'Köpek'
 where id = 'e9d4d582-a0fd-420e-b909-7b88b03309fb'
   and option_c = 'Rabûn';

-- Di Kurmancî de peyva "teşt" bi Tirkî çi ye?
--   C: Kursî  ->  Gitmek
update public.questions set option_c = 'Gitmek'
 where id = 'e9ded9b8-3537-43eb-b64a-1b1daf622b9e'
   and option_c = 'Kursî';

-- Hevwateya "yemekhane" bi Kurmancî çi ye?
--   A: fırıncı  ->  malbat
--   C: öğrenci  ->  havîn
--   D: işitmek  ->  pisîk
update public.questions set option_a = 'malbat', option_c = 'havîn', option_d = 'pisîk'
 where id = 'ea219059-6f28-4325-8ae1-6726ee202a48'
   and option_a = 'fırıncı' and option_c = 'öğrenci' and option_d = 'işitmek';

-- Di Kurmancî de peyva "rê" bi Tirkî çi ye?
--   A: Şêr  ->  Beş
--   B: Por  ->  Kaya
update public.questions set option_a = 'Beş', option_b = 'Kaya'
 where id = 'ea465bfe-d1a8-445a-9e6c-4da0881ae287'
   and option_a = 'Şêr' and option_b = 'Por';

-- Hevwateya "ay" bi Kurmancî çi ye?
--   C: okul  ->  deşt
--   D: eski  ->  ciwan
update public.questions set option_c = 'deşt', option_d = 'ciwan'
 where id = 'ec70b297-1d8c-404e-938e-3242d4ddf2ee'
   and option_c = 'okul' and option_d = 'eski';

-- "welat" (Kurmancî) bi Tirkî kîjan wateyê digire?
--   B: nivîsandin  ->  nasılsın?
update public.questions set option_b = 'nasılsın?'
 where id = 'ef3de8dc-71ea-468c-8bbd-ccc850a9c41c'
   and option_b = 'nivîsandin';

-- Di Kurmancî de peyva "biçûk" bi Tirkî çi ye?
--   A: Ciwan  ->  Ateş
--   D: Nivîn  ->  Soğuk
update public.questions set option_a = 'Ateş', option_d = 'Soğuk'
 where id = 'efc794ce-bd13-4531-8d5b-6f10bd056ba7'
   and option_a = 'Ciwan' and option_d = 'Nivîn';

-- Di Kurmancî de peyva "çav" bi Tirkî çi ye?
--   D: por  ->  baba
update public.questions set option_d = 'baba'
 where id = 'f1f68af6-42a3-4b1c-952e-64ac928ef267'
   and option_d = 'por';

-- Di Kurmancî de peyva "bihîstin" bi Tirkî çi ye?
--   A: Axaftin  ->  Teşekkür
update public.questions set option_a = 'Teşekkür'
 where id = 'f21bd125-97f7-4595-a518-04a72827419f'
   and option_a = 'Axaftin';

-- Di Kurmancî de peyva "nivîn" bi Tirkî çi ye?
--   A: Kursî  ->  Sanat
--   C: Nivîn  ->  Bilmek
update public.questions set option_a = 'Sanat', option_c = 'Bilmek'
 where id = 'f28e7dd0-5ede-48d0-b8b2-23ac91eba803'
   and option_a = 'Kursî' and option_c = 'Nivîn';

-- Di Kurmancî de peyva "bav" bi Tirkî çi ye?
--   A: Bira  ->  Aslan
--   C: Reng  ->  Kürt
--   D: Çiya  ->  Ekmek
update public.questions set option_a = 'Aslan', option_c = 'Kürt', option_d = 'Ekmek'
 where id = 'f2c5bda7-16e2-4597-9a92-44e1d1821a5e'
   and option_a = 'Bira' and option_c = 'Reng' and option_d = 'Çiya';

-- Hevwateya "ateş" bi Kurmancî çi ye?
--   A: ateş  ->  diran
--   B: eski  ->  dûr
--   C: Renk  ->  kanî
update public.questions set option_a = 'diran', option_b = 'dûr', option_c = 'kanî'
 where id = 'f492222d-8bcc-408b-aaf1-3ef69c21965a'
   and option_a = 'ateş' and option_b = 'eski' and option_c = 'Renk';

-- Di Kurmancî de peyva "rû" bi Tirkî çi ye?
--   C: Şêr  ->  Ağaç
update public.questions set option_c = 'Ağaç'
 where id = 'f597e920-13a2-45cb-b56f-a40bfc3ed6a0'
   and option_c = 'Şêr';

-- Kîjan ji van peyva Kurmancî ye ku wateya wê "aile" ye?
--   B: Görmek  ->  newal
--   C: yazmak  ->  pisîk
--   D: toprak  ->  axaftin
update public.questions set option_b = 'newal', option_c = 'pisîk', option_d = 'axaftin'
 where id = 'f6d1ee25-61a2-48ef-b0dc-d221a7c57075'
   and option_b = 'Görmek' and option_c = 'yazmak' and option_d = 'toprak';

-- Di Kurmancî de peyva "rûniştin" bi Tirkî çi ye?
--   B: Mamoste  ->  Gelmek
update public.questions set option_b = 'Gelmek'
 where id = 'f6dc7afb-a63d-4f21-b06f-f07f2bcd6382'
   and option_b = 'Mamoste';

-- Wateya Tirkî ya peyva "kaxiz" kîjan e?
--   C: ciwan  ->  baba
update public.questions set option_c = 'baba'
 where id = 'f6efd917-3ee1-4f85-9623-8395c615a450'
   and option_c = 'ciwan';

-- Di Kurmancî de peyva "zinar" bi Tirkî çi ye?
--   C: Bira  ->  Deniz
update public.questions set option_c = 'Deniz'
 where id = 'f7b3f178-52e6-45ea-bd6f-a602ae408be5'
   and option_c = 'Bira';

-- Di Kurmancî de peyva "cîhan" bi Tirkî çi ye?
--   A: Nivîn  ->  Erkek
update public.questions set option_a = 'Erkek'
 where id = 'f9793c0c-6693-4031-bf42-ab46350e8fd3'
   and option_a = 'Nivîn';

-- Di Kurmancî de peyva "pênûs" bi Tirkî çi ye?
--   B: Ciwan  ->  Kitap
update public.questions set option_b = 'Kitap'
 where id = 'fca9cdd3-1d1c-442f-9a0a-d331b3cc63d6'
   and option_b = 'Ciwan';

commit;
