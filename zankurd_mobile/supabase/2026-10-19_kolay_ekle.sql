-- 2026-10-19: «kolay» bankasından 36 yeni zorluk-1 soru (canlı sunucu).
--
-- NİÇİN: 455 fazla zor "kolay" soru zorluk 3'e çekilince Sînema, Edebiyat,
-- Siyaset ve Dîrok kolay havuzları inceldi. `assets/data/kolay_2026_10_19_questions.json`
-- 36 soru ekledi (DeepSeek V4.1 taslağı; iki bağımsız jüri, Gemini 3.1 Pro ve
-- Grok/ChatGPT, ikisi de KABUL dedi; kalite kapısı yakın tekrarları elendi).
-- Oda ve düello soruları sunucudan çeker; bu sorular sunucuda yoktu.
--
-- KAÇ SORU: 36 yeni satır. Kategori dağılımı:
--   - Dîrok: 15
--   - Edebiyat: 9
--   - Siyaset: 8
--   - Sînema: 4
--
-- TEKRAR YOK: kimlikler uuid5(ad alanı, "zankurd-local:" + yerel id); bu
-- kimlikler daha önce hiçbir göçte yok. Yine de her satır
-- `on conflict (id) do nothing` ile eklenir; ikinci çalıştırma 0 satır ekler.
--
-- KATEGORİ: `categories.name` ile aranır (tekil). Başta gerekli kategorilerin
-- varlığı denetlenir; biri yoksa hiçbir şey eklenmeden işlem geri alınır. Bu
-- göç kategori OLUŞTURMAZ.
--
-- BİÇİM: metinler yalnız Kurmancî; explanation/explanation_ku/explanation_tr
-- yerel alanlardan; image_url NULL; hepsi is_approved = true,
-- review_status = 'approved'. Üretici: tool/sync_kolay_to_server.py.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from questions where id in (<bu dosyadaki id'ler>);
--
-- Uygulama: supabase db query --linked -f supabase/2026-10-19_kolay_ekle.sql

begin;

-- Önkoşul: gerekli kategorilerin hepsi sunucuda var (bu göç oluşturmaz).
do $$
declare
  v_missing text;
begin
  select string_agg(n, ', ') into v_missing
  from unnest(array['Dîrok', 'Edebiyat', 'Siyaset', 'Sînema']) as t(n)
  where not exists (select 1 from categories where name = n);
  if v_missing is not null then
    raise exception 'Eksik kategori(ler): %', v_missing;
  end if;
end
$$;

insert into questions (id, category_id, language_code, prompt, option_a, option_b, option_c, option_d, correct_option, explanation, explanation_ku, explanation_tr, difficulty, is_approved, question_type, image_url, source_url, source_title, source_reference, review_status, dialect, quality_version, last_content_check_at)
values
('2ac00e3b-59a4-5458-be85-103b4773eb5a', (select id from categories where name = 'Sînema'), 'ku-kmr', 'Kîjan xelat xelata herî navdar a sînemaya Amerîkayê ye?', 'Palme d''Or', 'Xelata Oscarê', 'Xelata Nobelê', 'Grammy', 'B', 'Xelata Oscarê xelata herî navdar a sînemaya Amerîkayê ye.', 'Xelata Oscarê xelata herî navdar a sînemaya Amerîkayê ye.', 'Oscar, Amerika sinemasının en ünlü ödülüdür.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('4461ff31-0647-547c-a7f4-31265e2f8e8d', (select id from categories where name = 'Sînema'), 'ku-kmr', 'Bahman Ghobadi, derhênerê kurd ê fîlma "Kûsî jî difirin", ji kîjan welatî ye?', 'Hindistan', 'Fransa', 'Îran', 'Tirkiye', 'C', 'Bahman Ghobadi derhênerê kurd ê ji Îranê ye.', 'Bahman Ghobadi derhênerê kurd ê ji Îranê ye.', 'Bahman Ghobadi, İran Kürdistanı''ndan bir Kürt yönetmendir.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('8ecf58ab-fe6b-5ee2-8f9a-48d63a5e8a77', (select id from categories where name = 'Sînema'), 'ku-kmr', 'Fîlmên "Harry Potter" behsa kê dikin?', 'Rojnamevanekî', 'Futbolvanekî', 'Kurekî ciwan ê sêrbaz', 'Stranbêjekî', 'C', 'Harry Potter kurekî ciwan ê sêrbaz e.', 'Harry Potter kurekî ciwan ê sêrbaz e.', 'Harry Potter, büyücülük okuluna giden genç bir çocuktur.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('ffe9108a-b340-56ff-9ac7-2942dfbbc574', (select id from categories where name = 'Sînema'), 'ku-kmr', 'Kîjan ji van fîlman bi zimanê kurdî hatiye çêkirin?', 'Mem û Zîn', 'Jurassic Park', 'Titanic', 'Avatar', 'A', '"Mem û Zîn" fîlmekî bi zimanê kurdî hatiye çêkirin.', '"Mem û Zîn" fîlmekî bi zimanê kurdî hatiye çêkirin.', '"Mem û Zîn" Kürtçe çekilmiş tanınmış bir filmdir.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('dcf7ceee-5ad0-5fe8-96f9-abb2aabcd1b8', (select id from categories where name = 'Edebiyat'), 'ku-kmr', '"Mem û Zîn" kî nivîsandiye?', 'Feqiyê Teyran', 'Ehmedê Xanî', 'Cegerxwîn', 'Melayê Cizîrî', 'B', '"Mem û Zîn" berhema herî navdar a wêjeya kurdî ye û ji aliyê Ehmedê Xanî ve hatiye nivîsandin.', '"Mem û Zîn" berhema herî navdar a wêjeya kurdî ye û ji aliyê Ehmedê Xanî ve hatiye nivîsandin.', 'Mem û Zîn, Kürt edebiyatının en ünlü eseridir ve Ehmedê Xanî tarafından yazılmıştır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('06f45127-7823-5367-8c7d-fac47ede4ebc', (select id from categories where name = 'Edebiyat'), 'ku-kmr', '"Mem û Zîn" çi cure berhemek e?', 'Ferhengek', 'Pirtûkeke matematîkê', 'Kovareke rojnamevaniyê', 'Berhemeke evînê (destan)', 'D', '"Mem û Zîn" berhemeke evînê ye ku evîna Mem û Zîn vedibêje.', '"Mem û Zîn" berhemeke evînê ye ku evîna Mem û Zîn vedibêje.', 'Mem û Zîn, Mem ile Zîn arasındaki aşkı anlatan manzum bir destandır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('952a91aa-7b12-58ba-b44a-8052df83ddfc', (select id from categories where name = 'Edebiyat'), 'ku-kmr', 'Melayê Cizîrî ji kîjan bajarî bû?', 'Bexda', 'Tewrêz', 'Cizîr (Cizre)', 'Stenbol (Îstanbul)', 'C', 'Melayê Cizîrî, wek ku navê wî jî nîşan dide, ji Cizîrê (Cizre) ye.', 'Melayê Cizîrî, wek ku navê wî jî nîşan dide, ji Cizîrê (Cizre) ye.', 'Melayê Cizîrî, adından da anlaşılacağı gibi Cizre''dendir.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('431ff289-1b1b-5fcf-bc27-3da2b71906d9', (select id from categories where name = 'Edebiyat'), 'ku-kmr', 'Kîjan berhem a Feqiyê Teyran e?', 'Şerefname', 'Dîwana Melayê Cizîrî', 'Mem û Zîn', 'Şêxê Sen''an', 'D', '"Şêxê Sen''an" berhema Feqiyê Teyran ya herî navdar e.', '"Şêxê Sen''an" berhema Feqiyê Teyran ya herî navdar e.', 'Şêxê Sen''an, Feqiyê Teyran''ın en tanınmış eseridir.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('9fb3c794-227f-5892-898f-8533c32f95ac', (select id from categories where name = 'Edebiyat'), 'ku-kmr', 'Kesê ku helbestan dinivîse, jê re çi tê gotin?', 'Stranbêj', 'Ferhengsaz', 'Helbestvan', 'Romannivîs', 'C', '"Helbestvan" di kurdî de tê wateya şair.', '"Helbestvan" di kurdî de tê wateya şair.', 'Helbestvan, "şair" anlamına gelir.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('e908b755-78bf-515d-90bf-e207aee5e660', (select id from categories where name = 'Edebiyat'), 'ku-kmr', '"Çîrok" çi ye?', 'Pirtûkeke matematîkê', 'Ferhengek', 'Berhemeke kin ku bûyeran vedibêje', 'Kovareke rojnamevaniyê', 'C', '"Çîrok" berhemeke kin a wêjeyê ye ku bûyeran vedibêje.', '"Çîrok" berhemeke kin a wêjeyê ye ku bûyeran vedibêje.', 'Çîrok, olayları anlatan kısa bir edebî eserdir.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('409dc9a8-00d3-5ffd-bfcf-abee08521779', (select id from categories where name = 'Edebiyat'), 'ku-kmr', 'Pirtûka ku helbestên helbestvanekî tê de hatine berhevkirin, jê re çi tê gotin?', 'Kovar', 'Ferheng', 'Rojname', 'Dîwan', 'D', '"Dîwan" pirtûka ku helbestên helbestvanekî tê de hatine berhevkirin e.', '"Dîwan" pirtûka ku helbestên helbestvanekî tê de hatine berhevkirin e.', 'Divan, bir şairin şiirlerinin toplandığı kitaptır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('fc853e99-7a9a-50dc-8dd8-3a8604b65935', (select id from categories where name = 'Edebiyat'), 'ku-kmr', '"Nûbihara Piçûkan" kê nivîsandiye?', 'Cegerxwîn', 'Melayê Cizîrî', 'Ehmedê Xanî', 'Feqiyê Teyran', 'C', '"Nûbihara Piçûkan" ferhenga kurdî-arabî ye ku Ehmedê Xanî ji bo zarokan nivîsandiye.', '"Nûbihara Piçûkan" ferhenga kurdî-arabî ye ku Ehmedê Xanî ji bo zarokan nivîsandiye.', 'Nûbihara Piçûkan, Ehmedê Xanî''nin çocuklar için hazırladığı Kürtçe-Arapça sözlüktür.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('0b586c80-eab9-57e3-be16-e843bcc493e0', (select id from categories where name = 'Edebiyat'), 'ku-kmr', 'Kîjan navê helbestvanekî kurd e?', 'Ferheng', 'Dîwan', 'Zîn', 'Cegerxwîn', 'D', 'Cegerxwîn helbestvanek e; Zîn navekî karakterekî, Dîwan û Ferheng jî navê berheman in.', 'Cegerxwîn helbestvanek e; Zîn navekî karakterekî, Dîwan û Ferheng jî navê berheman in.', 'Cegerxwîn bir şairdir; Zîn bir karakter, Divan ve Ferheng ise eser adlarıdır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('aea5c84c-bb32-5193-b6b8-9650e3d43ad3', (select id from categories where name = 'Siyaset'), 'ku-kmr', 'Paytexta Tirkiyeyê kîjan bajar e?', 'Stenbol', 'Îzmîr', 'Bûrsa', 'Enqere', 'D', 'Paytexta Tirkiyeyê Enqere ye.', 'Paytexta Tirkiyeyê Enqere ye.', 'Türkiye''nin başkenti Ankara''dır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('b0318063-3c98-5027-95ee-fda153e6993f', (select id from categories where name = 'Siyaset'), 'ku-kmr', '"Hikûmet" tê çi wateyê?', 'Cihê ku pirtûk têne firotin', 'Koma kesên ku welat bi rê ve dibin', 'Komela werzişê', 'Rojnameyeke rojane', 'B', 'Hikûmet, koma kesên ku welat bi rê ve dibin e.', 'Hikûmet, koma kesên ku welat bi rê ve dibin e.', 'Hükümet, ülkeyi yöneten kişilerden oluşur.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('82339640-6ad2-5b28-b781-946cf21ade4f', (select id from categories where name = 'Siyaset'), 'ku-kmr', '"Destûr" (makeqanûn) çi ye?', 'Sirûda neteweyî', 'Qanûna herî bilind a welatekî', 'Alaya welatekî', 'Paytexta welatekî', 'B', 'Destûr, qanûna herî bilind a welatekî ye.', 'Destûr, qanûna herî bilind a welatekî ye.', 'Anayasa, bir ülkenin en üstün kanunudur.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('87fc4ee2-f835-50b9-a621-4abcf3193606', (select id from categories where name = 'Siyaset'), 'ku-kmr', '"Neteweyên Yekbûyî" (NY) çi ye?', 'Partiyeke siyasî ya Tirkiyeyê ye', 'Komeleyeke werzişê ye', 'Rêxistineke navneteweyî ye ku gelek welat tê de ne', 'Bajarekî mezin e', 'C', 'Neteweyên Yekbûyî rêxistineke navneteweyî ye.', 'Neteweyên Yekbûyî rêxistineke navneteweyî ye.', 'Birleşmiş Milletler, çok sayıda ülkenin üye olduğu uluslararası bir kuruluştur.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('cdbdf702-9ca4-5830-b9c0-d8b6ba63d37c', (select id from categories where name = 'Siyaset'), 'ku-kmr', 'Neteweyên Yekbûyî piştî kîjan şerî hatin damezrandin?', 'Şerê Cîhanê yê Duyem', 'Şerê Koreyê', 'Şerê Cîhanê yê Yekem', 'Şerê Sar', 'A', 'Neteweyên Yekbûyî piştî Şerê Cîhanê yê Duyem, di sala 1945an de hatin damezrandin.', 'Neteweyên Yekbûyî piştî Şerê Cîhanê yê Duyem, di sala 1945an de hatin damezrandin.', 'Birleşmiş Milletler, İkinci Dünya Savaşı''ndan sonra 1945''te kuruldu.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('f7648195-3418-56ba-b940-537d05039e8b', (select id from categories where name = 'Siyaset'), 'ku-kmr', 'Komara Tirkiyeyê kengî hat damezrandin?', '1938', '1923', '1918', '1946', 'B', 'Komara Tirkiyeyê di sala 1923an de hat damezrandin.', 'Komara Tirkiyeyê di sala 1923an de hat damezrandin.', 'Türkiye Cumhuriyeti 1923''te kuruldu.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('ed660836-a40c-5450-8738-1327873cf1da', (select id from categories where name = 'Siyaset'), 'ku-kmr', 'Peymana Lozanê kengî hat îmzekirin?', '1930', '1920', '1918', '1923', 'D', 'Peymana Lozanê di sala 1923an de hat îmzekirin.', 'Peymana Lozanê di sala 1923an de hat îmzekirin.', 'Lozan Antlaşması 1923''te imzalandı.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('c04fc526-353e-5879-8812-c4ada8bae05a', (select id from categories where name = 'Siyaset'), 'ku-kmr', '"Serokwezîr" kî ye?', 'Serokê artêşê', 'Serokê hikûmetê', 'Serokê bajêr', 'Serokê dadgehê', 'B', 'Serokwezîr serokê hikûmetê ye.', 'Serokwezîr serokê hikûmetê ye.', 'Başbakan, hükümetin başıdır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('0d564fd2-c3e7-5dd3-979a-2e15f38924e3', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Kawayê hesinkar bi kê re şer kir?', 'Napoleon', 'Ristemê Zal', 'Dehak', 'Keyxusrew', 'C', 'Li gorî efsaneya Kawa, Kawayê hesinkar li dijî padîşahê zalim Dehak serî hilda.', 'Li gorî efsaneya Kawa, Kawayê hesinkar li dijî padîşahê zalim Dehak serî hilda.', 'Kawa efsanesine göre demirci Kawa, zalim kral Dehak''a karşı ayaklandı.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('4a02fb99-620b-59cb-9469-596f468400b6', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Newroz kengî tê pîrozkirin?', '1ê Gulanê', '21ê Îlonê', '1ê Rêbendanê', '21ê Adarê', 'D', 'Newroz her sal di 21ê Adarê de tê pîrozkirin.', 'Newroz her sal di 21ê Adarê de tê pîrozkirin.', 'Newroz her yıl 21 Mart''ta kutlanır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('89bdfbf4-f7c5-5adf-8c66-43854fb0a740', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Mem û Zîn kê nivîsandiye?', 'Feqiyê Teyran', 'Melayê Cizîrî', 'Şerefxanê Bedlîsî', 'Ehmedê Xanî', 'D', 'Ehmedê Xanî di sedsala 17an de Mem û Zîn nivîsandiye.', 'Ehmedê Xanî di sedsala 17an de Mem û Zîn nivîsandiye.', 'Mem û Zîn mesnevisini 17. yüzyılda Ahmedê Xanî yazmıştır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('199f99ef-54e0-50b9-af61-afe305124d46', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Ehmedê Xanî kî bû?', 'Dahênerê çapxaneyê', 'Padîşahekî Osmanî', 'Helbestvan û nivîskarekî kurd', 'Fermandarekî Romayê', 'C', 'Ehmedê Xanî helbestvan û nivîskarekî navdar ê kurd e û nivîskarê Mem û Zîn e.', 'Ehmedê Xanî helbestvan û nivîskarekî navdar ê kurd e û nivîskarê Mem û Zîn e.', 'Ahmedê Xanî, Mem û Zîn''in yazarı olan ünlü bir Kürt şair ve düşünürdür.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('d09502c4-1252-54d5-ad50-c7e16c07e550', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Mem û Zîn çi cureyê çîrokê ye?', 'Çîrokeke seyahetê', 'Çîrokeke evînê', 'Çîrokeke şer', 'Çîrokeke bazirganiyê', 'B', 'Mem û Zîn çîrokeke evînê ya navdar a kurdî ye ku evîna Mem û Zîn vedibêje.', 'Mem û Zîn çîrokeke evînê ya navdar a kurdî ye ku evîna Mem û Zîn vedibêje.', 'Mem û Zîn, Mem ile Zîn arasındaki aşkı anlatan ünlü bir Kürt halk hikâyesidir.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('a462acf4-ed35-5235-a608-966e4a4c9b55', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Pîramîdên Mezin li kîjan welatî ne?', 'Misir', 'Îran', 'Tirkiye', 'Yewnanistan', 'A', 'Pîramîdên Mezin ên Gîzayê li Misirê ne.', 'Pîramîdên Mezin ên Gîzayê li Misirê ne.', 'Giza''daki Büyük Piramitler Mısır''da bulunur.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('f1a7938f-c2a6-5ae0-b10e-d26cb691b272', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Şerê Cîhanê yê Duyem kengî bi dawî bû?', '1945', '1960', '1939', '1918', 'A', 'Şerê Cîhanê yê Duyem di sala 1945an de bi dawî bû.', 'Şerê Cîhanê yê Duyem di sala 1945an de bi dawî bû.', 'İkinci Dünya Savaşı 1945''te sona erdi.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('0c2ebb36-2c6a-52eb-8020-9a2cc31e85b5', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Krîstof Kolomb kengî gihîşt parzemîna Amerîkayê?', '1776', '1492', '1453', '1620', 'B', 'Krîstof Kolomb di sala 1492an de gihîşt parzemîna Amerîkayê.', 'Krîstof Kolomb di sala 1492an de gihîşt parzemîna Amerîkayê.', 'Kristof Kolomb 1492''de Amerika kıtasına ulaştı.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('6f97bf6d-49d7-5760-bb2c-08ed23277b8f', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Kawayê hesinkar çi pîşe dikir?', 'Bazirganî', 'Hesinkarî', 'Cotkarî', 'Masîgirî', 'B', 'Kawa hesinkar bû, ji ber vê yekê jê re "Kawayê Hesinkar" tê gotin.', 'Kawa hesinkar bû, ji ber vê yekê jê re "Kawayê Hesinkar" tê gotin.', 'Kawa bir demirciydi; bu yüzden "Kawayê Hesinkar" (Demirci Kawa) olarak anılır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('7bebdf79-a63a-55ac-8394-11edc7555800', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Newroz sembola çi ye?', 'Destpêka biharê û azadiyê', 'Dawiya havînê', 'Roja berfê', 'Destpêka zivistanê', 'A', 'Newroz destpêka biharê û azadiyê sembolîze dike.', 'Newroz destpêka biharê û azadiyê sembolîze dike.', 'Newroz, baharın gelişini ve özgürlüğü simgeler.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('283ec3b0-75b4-556a-a33c-31c2f853cac1', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Selahedîn Eyyûbî kîjan dewletê damezrand?', 'Dewleta Eyûbî', 'Dewleta Romayê', 'Dewleta Sasanî', 'Dewleta Osmanî', 'A', 'Selahedîn Eyyûbî damezrênerê Dewleta Eyûbî ye.', 'Selahedîn Eyyûbî damezrênerê Dewleta Eyûbî ye.', 'Selahaddin Eyyubi, Eyyubi Devleti''nin kurucusudur.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('6672c419-da36-5d37-bf4c-1b501947452a', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Şerê Cîhanê yê Yekem kengî dest pê kir?', '1900', '1914', '1939', '1923', 'B', 'Şerê Cîhanê yê Yekem di sala 1914an de dest pê kir.', 'Şerê Cîhanê yê Yekem di sala 1914an de dest pê kir.', 'Birinci Dünya Savaşı 1914''te başladı.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('d0ac90f5-ac34-5c85-8601-d854d087cefd', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Kê di sala 1923an de Komara Tirkiyê damezrand?', 'Selahedîn Eyyûbî', 'Mustafa Kemal Atatürk', 'Sultan Abdulhemîdê Duyem', 'Osman Beg', 'B', 'Komara Tirkiyê di 29ê Cotmeha 1923an de ji aliyê Mustafa Kemal Atatürk ve hat damezrandin.', 'Komara Tirkiyê di 29ê Cotmeha 1923an de ji aliyê Mustafa Kemal Atatürk ve hat damezrandin.', 'Türkiye Cumhuriyeti 29 Ekim 1923''te Mustafa Kemal Atatürk tarafından kuruldu.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('379f14e8-3f95-5875-8769-86c5b62b46f9', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Kê di sala 1969an de cara pêşî li ser Heyvê meşiya?', 'Neil Armstrong', 'Thomas Edison', 'Yuri Gagarin', 'Krîstof Kolomb', 'A', 'Neil Armstrong di sala 1969an de bû mirovê pêşî ku li ser Heyvê meşiya.', 'Neil Armstrong di sala 1969an de bû mirovê pêşî ku li ser Heyvê meşiya.', 'Neil Armstrong, 1969''da Ay''a ayak basan ilk insandır.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now()),
('5c91184e-f4b1-5c23-8bed-4d68c7c1d211', (select id from categories where name = 'Dîrok'), 'ku-kmr', 'Li gorî efsaneyê, Kawa roja Newrozê çi kir?', 'Serî hilda û Dehak kuşt', 'Kelehek ava kir', 'Pirtûkek nivîsand', 'Gemiyek çêkir', 'A', 'Li gorî efsaneyê, Kawa serî hilda, Dehak têk bir û Newroz da xuyakirin.', 'Li gorî efsaneyê, Kawa serî hilda, Dehak têk bir û Newroz da xuyakirin.', 'Efsaneye göre Kawa ayaklanıp Dehak''ı yendi ve Newroz''u müjdeledi.', 1, true, 'multiple_choice', NULL, NULL, 'Kolay soru taslağı 2026-10-19', NULL, 'approved', 'Kurmancî', 2, now())
on conflict (id) do nothing;

-- Doğrulama: her kategori için bu dosyadaki kimliklerin hepsi o kategoride
-- onaylı olarak durmalı; aksi halde işlem geri alınır.
do $$
declare
  v_count integer;
begin

  select count(*) into v_count
  from questions
  where id in ('0d564fd2-c3e7-5dd3-979a-2e15f38924e3', '4a02fb99-620b-59cb-9469-596f468400b6', '89bdfbf4-f7c5-5adf-8c66-43854fb0a740', '199f99ef-54e0-50b9-af61-afe305124d46', 'd09502c4-1252-54d5-ad50-c7e16c07e550', 'a462acf4-ed35-5235-a608-966e4a4c9b55', 'f1a7938f-c2a6-5ae0-b10e-d26cb691b272', '0c2ebb36-2c6a-52eb-8020-9a2cc31e85b5', '6f97bf6d-49d7-5760-bb2c-08ed23277b8f', '7bebdf79-a63a-55ac-8394-11edc7555800', '283ec3b0-75b4-556a-a33c-31c2f853cac1', '6672c419-da36-5d37-bf4c-1b501947452a', 'd0ac90f5-ac34-5c85-8601-d854d087cefd', '379f14e8-3f95-5875-8769-86c5b62b46f9', '5c91184e-f4b1-5c23-8bed-4d68c7c1d211')
    and category_id = (select id from categories where name = 'Dîrok')
    and is_approved = true;
  if v_count <> 15 then
    raise exception 'Dîrok: beklenen 15 onayli soru, bulunan %', v_count;
  end if;

  select count(*) into v_count
  from questions
  where id in ('dcf7ceee-5ad0-5fe8-96f9-abb2aabcd1b8', '06f45127-7823-5367-8c7d-fac47ede4ebc', '952a91aa-7b12-58ba-b44a-8052df83ddfc', '431ff289-1b1b-5fcf-bc27-3da2b71906d9', '9fb3c794-227f-5892-898f-8533c32f95ac', 'e908b755-78bf-515d-90bf-e207aee5e660', '409dc9a8-00d3-5ffd-bfcf-abee08521779', 'fc853e99-7a9a-50dc-8dd8-3a8604b65935', '0b586c80-eab9-57e3-be16-e843bcc493e0')
    and category_id = (select id from categories where name = 'Edebiyat')
    and is_approved = true;
  if v_count <> 9 then
    raise exception 'Edebiyat: beklenen 9 onayli soru, bulunan %', v_count;
  end if;

  select count(*) into v_count
  from questions
  where id in ('aea5c84c-bb32-5193-b6b8-9650e3d43ad3', 'b0318063-3c98-5027-95ee-fda153e6993f', '82339640-6ad2-5b28-b781-946cf21ade4f', '87fc4ee2-f835-50b9-a621-4abcf3193606', 'cdbdf702-9ca4-5830-b9c0-d8b6ba63d37c', 'f7648195-3418-56ba-b940-537d05039e8b', 'ed660836-a40c-5450-8738-1327873cf1da', 'c04fc526-353e-5879-8812-c4ada8bae05a')
    and category_id = (select id from categories where name = 'Siyaset')
    and is_approved = true;
  if v_count <> 8 then
    raise exception 'Siyaset: beklenen 8 onayli soru, bulunan %', v_count;
  end if;

  select count(*) into v_count
  from questions
  where id in ('2ac00e3b-59a4-5458-be85-103b4773eb5a', '4461ff31-0647-547c-a7f4-31265e2f8e8d', '8ecf58ab-fe6b-5ee2-8f9a-48d63a5e8a77', 'ffe9108a-b340-56ff-9ac7-2942dfbbc574')
    and category_id = (select id from categories where name = 'Sînema')
    and is_approved = true;
  if v_count <> 4 then
    raise exception 'Sînema: beklenen 4 onayli soru, bulunan %', v_count;
  end if;

  select count(*) into v_count
  from questions
  where id in ('2ac00e3b-59a4-5458-be85-103b4773eb5a', '4461ff31-0647-547c-a7f4-31265e2f8e8d', '8ecf58ab-fe6b-5ee2-8f9a-48d63a5e8a77', 'ffe9108a-b340-56ff-9ac7-2942dfbbc574', 'dcf7ceee-5ad0-5fe8-96f9-abb2aabcd1b8', '06f45127-7823-5367-8c7d-fac47ede4ebc', '952a91aa-7b12-58ba-b44a-8052df83ddfc', '431ff289-1b1b-5fcf-bc27-3da2b71906d9', '9fb3c794-227f-5892-898f-8533c32f95ac', 'e908b755-78bf-515d-90bf-e207aee5e660', '409dc9a8-00d3-5ffd-bfcf-abee08521779', 'fc853e99-7a9a-50dc-8dd8-3a8604b65935', '0b586c80-eab9-57e3-be16-e843bcc493e0', 'aea5c84c-bb32-5193-b6b8-9650e3d43ad3', 'b0318063-3c98-5027-95ee-fda153e6993f', '82339640-6ad2-5b28-b781-946cf21ade4f', '87fc4ee2-f835-50b9-a621-4abcf3193606', 'cdbdf702-9ca4-5830-b9c0-d8b6ba63d37c', 'f7648195-3418-56ba-b940-537d05039e8b', 'ed660836-a40c-5450-8738-1327873cf1da', 'c04fc526-353e-5879-8812-c4ada8bae05a', '0d564fd2-c3e7-5dd3-979a-2e15f38924e3', '4a02fb99-620b-59cb-9469-596f468400b6', '89bdfbf4-f7c5-5adf-8c66-43854fb0a740', '199f99ef-54e0-50b9-af61-afe305124d46', 'd09502c4-1252-54d5-ad50-c7e16c07e550', 'a462acf4-ed35-5235-a608-966e4a4c9b55', 'f1a7938f-c2a6-5ae0-b10e-d26cb691b272', '0c2ebb36-2c6a-52eb-8020-9a2cc31e85b5', '6f97bf6d-49d7-5760-bb2c-08ed23277b8f', '7bebdf79-a63a-55ac-8394-11edc7555800', '283ec3b0-75b4-556a-a33c-31c2f853cac1', '6672c419-da36-5d37-bf4c-1b501947452a', 'd0ac90f5-ac34-5c85-8601-d854d087cefd', '379f14e8-3f95-5875-8769-86c5b62b46f9', '5c91184e-f4b1-5c23-8bed-4d68c7c1d211')
    and is_approved = true;
  if v_count <> 36 then
    raise exception 'Toplam: beklenen 36 onayli soru, bulunan %', v_count;
  end if;
end
$$;

commit;
