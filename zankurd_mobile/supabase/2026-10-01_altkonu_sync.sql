-- 2026-10-01: «alt konu» bankasından 17 yeni soru (canlı sunucu).
--
-- NİÇİN: üç alt konu 20 oynanabilir soruya ulaşamadığı için kartı gizliydi
-- (Muzîk › Muzîka Nûjen 15, Teknolojî › Programkirin 16, Sînema › Yılmaz
-- Güney û Klasîk 18). `assets/data/altkonu_2026_10_01_questions.json` 17 soru
-- ekledi (her biri açılmış bir web kaynağından; MiMo-V2.6-Flash taslağı,
-- Gemini 3.1 Pro çevirisi, Grok 4.7 incelemesi). Oda ve düello soruları
-- sunucudan çeker; bu sorular sunucuda yoktu.
--
-- KAÇ SORU: 17 yeni satır. Kategori dağılımı:
--   - Muzîk: 7
--   - Sînema: 4
--   - Teknolojî: 6
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
-- review_status = 'approved'. Üretici: tool/sync_altkonu_to_server.py.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from questions where id in (<bu dosyadaki id'ler>);
--
-- Uygulama: supabase db query --linked -f supabase/2026-10-01_altkonu_sync.sql

begin;

-- Önkoşul: gerekli kategorilerin hepsi sunucuda var (bu göç oluşturmaz).
do $$
declare
  v_missing text;
begin
  select string_agg(n, ', ') into v_missing
  from unnest(array['Muzîk', 'Sînema', 'Teknolojî']) as t(n)
  where not exists (select 1 from categories where name = n);
  if v_missing is not null then
    raise exception 'Eksik kategori(ler): %', v_missing;
  end if;
end
$$;

insert into questions (id, category_id, language_code, prompt, option_a, option_b, option_c, option_d, correct_option, explanation, explanation_ku, explanation_tr, difficulty, is_approved, question_type, image_url, source_url, source_title, source_reference, review_status, dialect, quality_version, last_content_check_at)
values
('299859aa-49dd-52ef-ac72-1cb5b51638c2', (select id from categories where name = 'Muzîk'), 'ku-kmr', 'Albûma stûdyoyê ya yekem ya Şivan Perwer kîjan e?', 'Seyir', 'Govenda Azadîxwazan', 'Sebra Min', 'Lê Dayê', 'B', 'Albûma yekem ya Şivan Perwer di sala 1975''an de derket; hunermend di sala 1976''an de koçî Almanyayê kir.', 'Albûma yekem ya Şivan Perwer di sala 1975''an de derket; hunermend di sala 1976''an de koçî Almanyayê kir.', 'Şivan Perwer''in ilk albümü 1975''te yayımlandı; sanatçı 1976''da Almanya''ya göç etti.', 3, true, 'multiple_choice', NULL, 'https://en.wikipedia.org/wiki/%C5%9Eivan_Perwer', 'en.wikipedia.org', 'https://en.wikipedia.org/wiki/%C5%9Eivan_Perwer', 'approved', 'Kurmancî', 2, now()),
('a1ad6bbe-72b0-58a8-9315-2e8a327d292e', (select id from categories where name = 'Muzîk'), 'ku-kmr', 'Ciwan Haco li ku ji dayik bûye?', 'Misirc', 'Dêrxas', 'Dêrsim', 'Qamişlo', 'D', 'Ciwan Haco di 17''ê Tebaxa 1957''an de li Qamişloyê, li Sûriyeyê ji dayik bû; perwerdeya xwe li Bochumê, li Almanyayê qedand.', 'Ciwan Haco di 17''ê Tebaxa 1957''an de li Qamişloyê, li Sûriyeyê ji dayik bû; perwerdeya xwe li Bochumê, li Almanyayê qedand.', 'Ciwan Haco 17 Ağustos 1957''de Suriye''nin Kamışlı kentinde doğdu; eğitimini Almanya''nın Bochum kentinde tamamladı.', 3, true, 'multiple_choice', NULL, 'https://tr.wikipedia.org/wiki/Ciwan_Haco', 'tr.wikipedia.org', 'https://tr.wikipedia.org/wiki/Ciwan_Haco', 'approved', 'Kurmancî', 2, now()),
('97990d53-807c-5e7e-9a2c-7acada9025d4', (select id from categories where name = 'Muzîk'), 'ku-kmr', 'Albûma stûdyoyê ya duyem ya Aynûr Dogan ku di sala 2004''an de derketiye kîjan e?', 'Seyir', 'Nûpel', 'Bahar', 'Keçe Kurdan', 'D', 'Keçe Kurdan, albûma stûdyoyê ya duyem ya Aynûr Dogan e ku di sala 2004''an de derketiye; albûma wê ya yekem Seyir e (2002).', 'Keçe Kurdan, albûma stûdyoyê ya duyem ya Aynûr Dogan e ku di sala 2004''an de derketiye; albûma wê ya yekem Seyir e (2002).', 'Keçe Kurdan, Aynur Doğan''ın 2004''te yayımlanan ikinci stüdyo albümüdür; ilk albümü Seyir''dir (2002).', 4, true, 'multiple_choice', NULL, 'https://tr.wikipedia.org/wiki/Ke%C3%A7e_Kurdan', 'tr.wikipedia.org', 'https://tr.wikipedia.org/wiki/Ke%C3%A7e_Kurdan', 'approved', 'Kurmancî', 2, now()),
('c8787662-1b46-5fc7-9382-fa1ebc406728', (select id from categories where name = 'Muzîk'), 'ku-kmr', 'Kardeş Türküler di kîjan salê de hatiye avakirin?', '1988', '1993', '1996', '1999', 'B', 'Kardeş Türküler di sala 1993''yan de li Zankoya Boğaziçiyê hat avakirin; ew bi zimanên cihê yên Anatolyayê stranan dibêjin.', 'Kardeş Türküler di sala 1993''yan de li Zankoya Boğaziçiyê hat avakirin; ew bi zimanên cihê yên Anatolyayê stranan dibêjin.', 'Kardeş Türküler 1993''te Boğaziçi Üniversitesinde kuruldu; Anadolu''nun farklı dillerinde şarkılar seslendirir.', 2, true, 'multiple_choice', NULL, 'https://tr.wikipedia.org/wiki/Karde%C5%9F_T%C3%BCrk%C3%BCler', 'tr.wikipedia.org', 'https://tr.wikipedia.org/wiki/Karde%C5%9F_T%C3%BCrk%C3%BCler', 'approved', 'Kurmancî', 2, now()),
('09024165-d8e3-52d9-8852-daf8efbb60b0', (select id from categories where name = 'Muzîk'), 'ku-kmr', 'Rojda li ku ji dayik bûye?', 'Dêrsim', 'Misirc', 'Qamişlo', 'Agirî', 'B', 'Rojda di sala 1978''an de li navçeya Misircê ya Sêrtê ji dayik bû; navê wê yê rast Kadriye Şenses e.', 'Rojda di sala 1978''an de li navçeya Misircê ya Sêrtê ji dayik bû; navê wê yê rast Kadriye Şenses e.', 'Rojda 1978''de Siirt''in Kurtalan ilçesinde doğdu; asıl adı Kadriye Şenses''tir.', 4, true, 'multiple_choice', NULL, 'https://tr.wikipedia.org/wiki/Rojda', 'tr.wikipedia.org', 'https://tr.wikipedia.org/wiki/Rojda', 'approved', 'Kurmancî', 2, now()),
('96343e85-0497-5c90-af97-b0d719050c22', (select id from categories where name = 'Muzîk'), 'ku-kmr', 'Nîzamettîn Arîç di kîjan salê de ji dayik bûye?', '1948', '1956', '1959', '1962', 'B', 'Nîzamettîn Arîç di sala 1956''an de li Agiriyê ji dayik bû; bi albûma xwe ya Dayê tê naskirin.', 'Nîzamettîn Arîç di sala 1956''an de li Agiriyê ji dayik bû; bi albûma xwe ya Dayê tê naskirin.', 'Nizamettin Ariç 1956''da Ağrı''da doğdu; Dayê albümüyle tanınır.', 4, true, 'multiple_choice', NULL, 'https://tr.wikipedia.org/wiki/Nizamettin_Ari%C3%A7', 'tr.wikipedia.org', 'https://tr.wikipedia.org/wiki/Nizamettin_Ari%C3%A7', 'approved', 'Kurmancî', 2, now()),
('758d920e-964e-5d5b-bfc6-7e2235beaca9', (select id from categories where name = 'Muzîk'), 'ku-kmr', 'Koma Wetan li kîjan bajarî hatiye avakirin?', 'Berlîn', 'Tiflîs', 'Stokholm', 'Londra', 'B', 'Koma Wetan di sala 1973''yan de li Tiflîsa Yekîtiya Sovyetê hat avakirin û wekî yekemîn koma rockê ya kurdî tê qebûlkirin.', 'Koma Wetan di sala 1973''yan de li Tiflîsa Yekîtiya Sovyetê hat avakirin û wekî yekemîn koma rockê ya kurdî tê qebûlkirin.', 'Koma Wetan 1973''te Sovyetler Birliği''nin Tiflis kentinde kuruldu ve ilk Kürt rock grubu kabul edilir.', 5, true, 'multiple_choice', NULL, 'https://eurasianet.org/the-worlds-first-kurdish-rock-group-and-its-roots-in-soviet-georgia', 'eurasianet.org', 'https://eurasianet.org/the-worlds-first-kurdish-rock-group-and-its-roots-in-soviet-georgia', 'approved', 'Kurmancî', 2, now()),
('98fdfc70-e960-5c7c-aae6-5c48ef0ae8dc', (select id from categories where name = 'Teknolojî'), 'ku-kmr', 'Di Pythonê de kîjan fonksiyon dirêjiya rêzekê vedigerîne?', 'count()', 'size()', 'len()', 'length()', 'C', 'Di Pythonê de fonksiyona len() dirêjiya rêzekê, nivîsekê an ferhengekî vedigerîne.', 'Di Pythonê de fonksiyona len() dirêjiya rêzekê, nivîsekê an ferhengekî vedigerîne.', 'Python''da len() işlevi bir dizinin, metnin veya sözlüğün uzunluğunu döndürür.', 1, true, 'multiple_choice', NULL, 'https://docs.python.org/3/library/functions.html', 'docs.python.org', 'https://docs.python.org/3/library/functions.html', 'approved', 'Kurmancî', 2, now()),
('a3397584-e761-5418-af89-29497c907024', (select id from categories where name = 'Teknolojî'), 'ku-kmr', 'Wateya koda rewşê ya HTTP 404 çi ye?', 'Rûpel nehat dîtin', 'Çewtiya pêşkêşkar', 'Beralîkirin', 'Gihîştina bêdestûr', 'A', 'Koda HTTP 404 tê wateya "Not Found" (nehat dîtin); çavkaniya ku tê xwestin di pêşkêşkar de tune ye.', 'Koda HTTP 404 tê wateya "Not Found" (nehat dîtin); çavkaniya ku tê xwestin di pêşkêşkar de tune ye.', 'HTTP 404 kodu "Not Found" (bulunamadı) anlamına gelir; istenen kaynak sunucuda yoktur.', 1, true, 'multiple_choice', NULL, 'https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/404', 'developer.mozilla.org', 'https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/404', 'approved', 'Kurmancî', 2, now()),
('d87cf31e-ed6b-5bc9-8bd0-2f12c8b319c6', (select id from categories where name = 'Teknolojî'), 'ku-kmr', 'Vekirina (wateya) CSS ya bi îngilîzî çi ye?', 'Computer Style Sheets', 'Cascading Style Sheets', 'Creative Style Systems', 'Colorful Style Sheets', 'B', 'CSS, kurteya biwêja îngilîzî "Cascading Style Sheets" e û xuyanga dîtbarî ya belgeyan diyar dike.', 'CSS, kurteya biwêja îngilîzî "Cascading Style Sheets" e û xuyanga dîtbarî ya belgeyan diyar dike.', 'CSS, İngilizce "Cascading Style Sheets" ifadesinin kısaltmasıdır ve belgelerin görsel sunumunu tanımlar.', 2, true, 'multiple_choice', NULL, 'https://developer.mozilla.org/en-US/docs/Web/CSS', 'developer.mozilla.org', 'https://developer.mozilla.org/en-US/docs/Web/CSS', 'approved', 'Kurmancî', 2, now()),
('b237cd93-936f-52be-8119-d2746a9ea71e', (select id from categories where name = 'Teknolojî'), 'ku-kmr', 'Di lêgerîna duduî (binary search) de, tevlîheviya demê ya rewşa herî xirab çi ye?', 'O(1)', 'O(n)', 'O(n²)', 'O(log n)', 'D', 'Lêgerîna duduî, di rêzeke rêzkirî de di her gavê de navberê nîv dike, loma di rewşa herî xirab de tevlîheviya wê O(log n) ye.', 'Lêgerîna duduî, di rêzeke rêzkirî de di her gavê de navberê nîv dike, loma di rewşa herî xirab de tevlîheviya wê O(log n) ye.', 'İkili arama, sıralı bir dizide her adımda aralık yarıya indirdiği için en kötü durumda O(log n) karmaşıklığına sahiptir.', 3, true, 'multiple_choice', NULL, 'https://en.wikipedia.org/wiki/Binary_search', 'en.wikipedia.org', 'https://en.wikipedia.org/wiki/Binary_search', 'approved', 'Kurmancî', 2, now()),
('e2531487-ac23-5e84-ae90-444872772cea', (select id from categories where name = 'Teknolojî'), 'ku-kmr', 'Pêkhateya daneyê ya lodê (stack) bi kîjan prensîbî dixebite?', 'FIFO (yê ku yekem dikeve, yekem derdikeve)', 'Gihîştina rêzkirî', 'LIFO (yê ku dawî dikeve, yekem derdikeve)', 'Gihîştina rasthatî', 'C', 'Lod (stack) bi prensîbê LIFO dixebite: hêmana ku herî dawî hatiye zêdekirin, yekem tê derxistin.', 'Lod (stack) bi prensîbê LIFO dixebite: hêmana ku herî dawî hatiye zêdekirin, yekem tê derxistin.', 'Yığın (stack) LIFO ilkesiyle çalışır: son eklenen eleman ilk çıkarılır.', 2, true, 'multiple_choice', NULL, 'https://en.wikipedia.org/wiki/Stack_%28abstract_data_type%29', 'en.wikipedia.org', 'https://en.wikipedia.org/wiki/Stack_%28abstract_data_type%29', 'approved', 'Kurmancî', 2, now()),
('361b4ea3-9d8e-5946-859c-9b8ce56c9f03', (select id from categories where name = 'Teknolojî'), 'ku-kmr', 'Di SQL''ê de ji bo kişandina daneyan ji tabloyekê kîjan ferman tê bikaranîn?', 'INSERT', 'UPDATE', 'DELETE', 'SELECT', 'D', 'Di SQL''ê de ji bo kişandina daneyan ji tabloyekê fermana SELECT tê bikaranîn.', 'Di SQL''ê de ji bo kişandina daneyan ji tabloyekê fermana SELECT tê bikaranîn.', 'SQL''de bir tablodan veri çekmek için SELECT komutu kullanılır.', 3, true, 'multiple_choice', NULL, 'https://www.w3schools.com/sql/sql_syntax.asp', 'www.w3schools.com', 'https://www.w3schools.com/sql/sql_syntax.asp', 'approved', 'Kurmancî', 2, now()),
('8c1dbfef-bac8-5423-843d-f3415d6b1a74', (select id from categories where name = 'Sînema'), 'ku-kmr', 'Fîlmê Yilmaz Guney yê ku di sala 1982''yan de li Festîvala Fîlman ya Cannesê xelata Palmiyeya Zêrîn girtiye, kîjan e?', 'Ağıt', 'Yol', 'Duvar', 'Umut', 'B', 'Fîlmê Yol ku Yilmaz Guney senaryoya wî nivîsandiye û bi Şerîf Goren re derhêneriya wî kiriye, di sala 1982''yan de li Festîvala Fîlman ya Cannesê Palmiyeya Zêrîn wergirt.', 'Fîlmê Yol ku Yilmaz Guney senaryoya wî nivîsandiye û bi Şerîf Goren re derhêneriya wî kiriye, di sala 1982''yan de li Festîvala Fîlman ya Cannesê Palmiyeya Zêrîn wergirt.', 'Yılmaz Güney''in senaryosunu yazdığı ve Şerif Gören''le birlikte yönettiği Yol, 1982 Cannes Film Festivali''nde Altın Palmiye kazandı.', 3, true, 'multiple_choice', NULL, 'https://tr.wikipedia.org/wiki/Y%C4%B1lmaz_G%C3%BCney', 'tr.wikipedia.org', 'https://tr.wikipedia.org/wiki/Y%C4%B1lmaz_G%C3%BCney', 'approved', 'Kurmancî', 2, now()),
('a70304b0-6f40-5405-8a30-5801107860fa', (select id from categories where name = 'Sînema'), 'ku-kmr', 'Fîlmê Yilmaz Guney yê bi navê "Umut" di kîjan salê de hat nîşandan?', '1966', '1968', '1970', '1973', 'C', 'Umut, fîlmekî Yilmaz Guney yê sala 1970''an e û yek ji yekemîn fîlmên realîst ên sînemaya Tirkiyeyê tê qebûlkirin.', 'Umut, fîlmekî Yilmaz Guney yê sala 1970''an e û yek ji yekemîn fîlmên realîst ên sînemaya Tirkiyeyê tê qebûlkirin.', 'Umut, Yılmaz Güney''in 1970 yapımı filmidir ve Türk sinemasının ilk gerçekçi filmlerinden biri sayılır.', 4, true, 'multiple_choice', NULL, 'https://tr.wikipedia.org/wiki/Y%C4%B1lmaz_G%C3%BCney', 'tr.wikipedia.org', 'https://tr.wikipedia.org/wiki/Y%C4%B1lmaz_G%C3%BCney', 'approved', 'Kurmancî', 2, now()),
('1257d381-b8a0-551d-9af2-20a8f4ac899f', (select id from categories where name = 'Sînema'), 'ku-kmr', 'Kîjan derhêner fîlmê "Rashomon" derhênaye?', 'Yasujirō Ozu', 'Akira Kurosawa', 'Kenji Mizoguchi', 'Masaki Kobayashi', 'B', 'Rashomon, fîlmeke Akira Kurosawa ya sala 1950''yan e; di sala 1951''an de li Festîvala Fîlman ya Venedîkê xelata Şêrê Zêrîn girt.', 'Rashomon, fîlmeke Akira Kurosawa ya sala 1950''yan e; di sala 1951''an de li Festîvala Fîlman ya Venedîkê xelata Şêrê Zêrîn girt.', 'Rashomon, Akira Kurosawa''nın 1950 tarihli filmidir; 1951 Venedik Film Festivali''nde Altın Aslan kazandı.', 2, true, 'multiple_choice', NULL, 'https://en.wikipedia.org/wiki/Rashomon', 'en.wikipedia.org', 'https://en.wikipedia.org/wiki/Rashomon', 'approved', 'Kurmancî', 2, now()),
('f5478dba-19ca-5eb1-97a1-2e9e287f09b8', (select id from categories where name = 'Sînema'), 'ku-kmr', 'Fîlmê "Dizên Duçerxeyan" ji serberhemên kîjan herika sînemayê tê hejmartin?', 'Pêla Nû ya Fransî', 'Pêla Nû ya Çekî', 'Neo-realîzma Îtalî', 'Pêla Nû ya Alman', 'C', 'Dizên Duçerxeyan (Ladri di biciclette), fîlmeke Vittorio De Sica ya sala 1948''an e û ji serberhemên neo-realîzma îtalî tê hejmartin.', 'Dizên Duçerxeyan (Ladri di biciclette), fîlmeke Vittorio De Sica ya sala 1948''an e û ji serberhemên neo-realîzma îtalî tê hejmartin.', 'Bisiklet Hırsızları (Ladri di biciclette), Vittorio De Sica''nın 1948 tarihli filmi olup İtalyan neo-gerçekçiliğinin başyapıtlarından sayılır.', 3, true, 'multiple_choice', NULL, 'https://en.wikipedia.org/wiki/Bicycle_Thieves', 'en.wikipedia.org', 'https://en.wikipedia.org/wiki/Bicycle_Thieves', 'approved', 'Kurmancî', 2, now())
on conflict (id) do nothing;

-- Doğrulama: her kategori için bu dosyadaki kimliklerin hepsi o kategoride
-- onaylı olarak durmalı; aksi halde işlem geri alınır.
do $$
declare
  v_count integer;
begin

  select count(*) into v_count
  from questions
  where id in ('299859aa-49dd-52ef-ac72-1cb5b51638c2', 'a1ad6bbe-72b0-58a8-9315-2e8a327d292e', '97990d53-807c-5e7e-9a2c-7acada9025d4', 'c8787662-1b46-5fc7-9382-fa1ebc406728', '09024165-d8e3-52d9-8852-daf8efbb60b0', '96343e85-0497-5c90-af97-b0d719050c22', '758d920e-964e-5d5b-bfc6-7e2235beaca9')
    and category_id = (select id from categories where name = 'Muzîk')
    and is_approved = true;
  if v_count <> 7 then
    raise exception 'Muzîk: beklenen 7 onayli soru, bulunan %', v_count;
  end if;

  select count(*) into v_count
  from questions
  where id in ('8c1dbfef-bac8-5423-843d-f3415d6b1a74', 'a70304b0-6f40-5405-8a30-5801107860fa', '1257d381-b8a0-551d-9af2-20a8f4ac899f', 'f5478dba-19ca-5eb1-97a1-2e9e287f09b8')
    and category_id = (select id from categories where name = 'Sînema')
    and is_approved = true;
  if v_count <> 4 then
    raise exception 'Sînema: beklenen 4 onayli soru, bulunan %', v_count;
  end if;

  select count(*) into v_count
  from questions
  where id in ('98fdfc70-e960-5c7c-aae6-5c48ef0ae8dc', 'a3397584-e761-5418-af89-29497c907024', 'd87cf31e-ed6b-5bc9-8bd0-2f12c8b319c6', 'b237cd93-936f-52be-8119-d2746a9ea71e', 'e2531487-ac23-5e84-ae90-444872772cea', '361b4ea3-9d8e-5946-859c-9b8ce56c9f03')
    and category_id = (select id from categories where name = 'Teknolojî')
    and is_approved = true;
  if v_count <> 6 then
    raise exception 'Teknolojî: beklenen 6 onayli soru, bulunan %', v_count;
  end if;

  select count(*) into v_count
  from questions
  where id in ('299859aa-49dd-52ef-ac72-1cb5b51638c2', 'a1ad6bbe-72b0-58a8-9315-2e8a327d292e', '97990d53-807c-5e7e-9a2c-7acada9025d4', 'c8787662-1b46-5fc7-9382-fa1ebc406728', '09024165-d8e3-52d9-8852-daf8efbb60b0', '96343e85-0497-5c90-af97-b0d719050c22', '758d920e-964e-5d5b-bfc6-7e2235beaca9', '98fdfc70-e960-5c7c-aae6-5c48ef0ae8dc', 'a3397584-e761-5418-af89-29497c907024', 'd87cf31e-ed6b-5bc9-8bd0-2f12c8b319c6', 'b237cd93-936f-52be-8119-d2746a9ea71e', 'e2531487-ac23-5e84-ae90-444872772cea', '361b4ea3-9d8e-5946-859c-9b8ce56c9f03', '8c1dbfef-bac8-5423-843d-f3415d6b1a74', 'a70304b0-6f40-5405-8a30-5801107860fa', '1257d381-b8a0-551d-9af2-20a8f4ac899f', 'f5478dba-19ca-5eb1-97a1-2e9e287f09b8')
    and is_approved = true;
  if v_count <> 17 then
    raise exception 'Toplam: beklenen 17 onayli soru, bulunan %', v_count;
  end if;
end
$$;

commit;
