-- Küratörlü ilk soru dalgası.
-- Aynı source_url daha önce işlendi ise migration tekrar ekleme yapmaz.
-- CANLIYA UYGULANDI (2026-07-15): orijinal dosya `category` (metin) sütununa
-- yazıyordu ama canlı `questions` tablosunda `category_id` (uuid FK) var —
-- bu, dosyanın hiç çalıştırılamamış olmasının sebebiydi. Aşağıdaki sürüm
-- kategori adlarını canlı `categories` tablosundaki id'lerle değiştirir ve
-- true_false satırındaki NULL option_c/option_d'yi ("-" placeholder, mevcut
-- true_false kayıtlarının kuralı) NOT NULL kısıtına uyacak şekilde düzeltir.
WITH curated_rows(
  category_id, language_code, prompt, option_a, option_b, option_c, option_d,
  correct_option, explanation, explanation_ku, explanation_tr, difficulty,
  is_approved, question_type, image_url, source_url
) AS (
  VALUES
    ('5e60bd93-f45a-4510-b8bd-9bb1f070fe03'::uuid, 'ku', 'Di gotina «Jin, Jiyan, Azadî» de «jiyan» çi ye?', 'Jin', 'Jiyan', 'Azadî', 'Rêxistin', 'B', '«Jiyan» di vê gotinê de wateya jiyanê dide.', '«Jiyan» di vê gotinê de wateya jiyanê dide.', '"Jiyan" bu ifadede yaşam anlamına gelir.', 1, true, 'multiple_choice', NULL, 'curated_movement_wave_1'),
    ('5e60bd93-f45a-4510-b8bd-9bb1f070fe03'::uuid, 'ku', 'Kîjan peyv di Kurmancî de «azadî» tê wate kirin?', 'Azadî', 'Berdêl', 'Dîrok', 'Rê', 'A', '«Azadî» wateya azadiyê dide.', '«Azadî» wateya azadiyê dide.', '"Azadî" özgürlük anlamına gelir.', 1, true, 'multiple_choice', NULL, 'curated_movement_wave_1'),
    ('9e36450b-e6d6-412e-9279-5b48cd1386ff'::uuid, 'ku', 'Di gotûbêja jinan de «jineolojî» bi kîjan ravekirinê re zêdetir tê girêdan?', 'Nêzîkatiya zanistî ya li ser jiyana jinan û civakê', 'Tenê zanista astronomiyê', 'Rêbazek ji bo hesabkirina pereyan', 'Navê celebekî muzîkê', 'A', 'Jineolojî di edebiyata tevgerê de nêzîkatiyek ji bo xwendina jiyana jinan û civakê ye.', 'Jineolojî nêzîkatiyek e ji bo xwendina jiyana jinan û civakê.', 'Jineolojî, kadınların ve toplumun yaşamını inceleyen bir yaklaşım olarak kullanılır.', 3, true, 'multiple_choice', NULL, 'curated_movement_wave_1'),
    ('5e60bd93-f45a-4510-b8bd-9bb1f070fe03'::uuid, 'ku', 'Di civakê de meclîs çi dike?', 'Cihê ku endam li ser pirsgirêkan diaxivin û biryaran didin', 'Cihê ku tenê stran têne guhdarîkirin', 'Navê aliyekî werzîşê', 'Cihê ku pirtûk tên veşartin', 'A', 'Meclîs civîna gotûbêj û biryargirtinê ye.', 'Meclîs civîna gotûbêj û biryargirtinê ye.', 'Meclis, üyelerin sorunları konuşup karar aldığı yerdir.', 2, true, 'multiple_choice', NULL, 'curated_movement_wave_1'),
    ('9e36450b-e6d6-412e-9279-5b48cd1386ff'::uuid, 'ku', 'Kîjan ravekirin ji bo «xwe-rêxistin» rast e?', 'Maf û erkên xwe bi hevkarî rêxistin kirin', 'Biryarên hemû kesan ji kesekê re hiştin', 'Ji civakê dûrketin', 'Tenê li ser navan nivîsandin', 'A', 'Xwe-rêxistin tê wateya ku kes û kom bi hevkarî kar û biryarên xwe rêxistin dikin.', 'Xwe-rêxistin tê wateya rêxistina kar û biryaran bi hevkarî.', 'Özörgütlenme, iş ve kararları birlikte düzenlemek demektir.', 2, true, 'multiple_choice', NULL, 'curated_movement_wave_1'),
    ('193daac4-d049-4c58-9b79-af22d6a14eb9'::uuid, 'ku', '«Newroz» ji aliyê wateya peyvê ve bi kîjan ravekirinê re nêzîk e?', 'Rojê nû', 'Şeva dirêj', 'Bara kevn', 'Dengê bilind', 'A', 'Newroz bi têgeha «rojê nû» re tê şirovekirin.', 'Newroz bi têgeha «rojê nû» re tê şirovekirin.', 'Newroz, sözcük anlamı bakımından "yeni gün" ile ilişkilendirilir.', 2, true, 'multiple_choice', NULL, 'curated_movement_wave_1'),
    ('193daac4-d049-4c58-9b79-af22d6a14eb9'::uuid, 'ku', 'Di wêneyê de agirê Newrozê tê dîtin. Agir bi kîjan têgehê re zêdetir tê girêdan?', 'Hêvî û vejîn', 'Bêdengî û ji bîrkirin', 'Bazar û bazirgani', 'Zivistan û sarma', 'A', 'Agirê Newrozê bi ronahî, hêvî û vejîna nû re tê girêdan.', 'Agirê Newrozê bi ronahî, hêvî û vejînê re tê girêdan.', 'Newroz ateşi ışık, umut ve yeniden doğuşla ilişkilendirilir.', 2, true, 'visual', 'asset://assets/question_images/newroz.webp', 'curated_movement_wave_1'),
    ('5e60bd93-f45a-4510-b8bd-9bb1f070fe03'::uuid, 'ku', 'Rast e yan şaş e? «Berxwedan» her tim tenê bi awayê çekdarî tê pênasekirin.', 'Rast e', 'Şaş e', '-', '-', 'B', 'Berxwedan dikare zimanî, çandî, siyasî û civakî jî be.', 'Berxwedan dikare zimanî, çandî, siyasî û civakî jî be.', 'Direniş yalnızca silahlı biçimde tanımlanmaz; dilsel, kültürel ve toplumsal biçimleri de olabilir.', 3, true, 'true_false', NULL, 'curated_movement_wave_1')
)
INSERT INTO public.questions(
  category_id, language_code, prompt, option_a, option_b, option_c, option_d,
  correct_option, explanation, explanation_ku, explanation_tr, difficulty,
  is_approved, question_type, image_url, source_url
)
SELECT r.*
FROM curated_rows r
WHERE NOT EXISTS (
  SELECT 1 FROM public.questions q
  WHERE q.source_url = 'curated_movement_wave_1'
);
