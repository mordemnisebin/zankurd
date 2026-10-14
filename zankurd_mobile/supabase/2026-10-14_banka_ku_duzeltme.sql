-- 2026-10-14: soru bankalarındaki Kurmancî düzeltmelerinin canlı kopyası
-- (offline, editorial, üç expansion, deepseek_verified, hat, baslangic,
-- bosluk, bilim, community, source_first, altkonu, restore, visual,
-- fill_in_blank).
--
-- NİÇİN: bu bankalar çok modelli denetimden geçti (Gemini 3.8 Flash önerdi,
-- Grok 4.7 oyladı, ana ajan bağlam ve tutarlılık vetosu uyguladı). Oda ve
-- düello soruları sunucudaki `questions` tablosundan oynanır; yerelde düzelen
-- soruların canlı kopyası eski yazımda kalıyordu. Örnekler: "têgiha"→"têgeha",
-- "Kamûran"→"Kamiran", "distirên"→"distirin", "Paytextê"→"Paytexta",
-- "Riya Îpekê"→"Riya Hevrîşimê", "Dengbêjler"→"Dengbêjan".
--
-- Satırlar CANLI satırlardan üretildi (2026-10-15, salt okuma sorgusu): oturumda
-- değişen 344 yerel sorunun ESKİ soru metni canlıda arandı. Soru
-- metni + şık kümesi + doğru cevap metni eski yerel soruyla birebir tutan
-- 257 satır yeni metne çekilir; canlı şık sırası ve doğru cevap harfi korunur.
-- Tutmayan 21 satır varyanttır (aynı soru, başka şık/cevap) ve dokunulmaz;
-- bunlardan onaylı olup soru metni düzelen 1 satırın yalnız soru metni güncellenir.
-- parity (uuid5) ile eklenenlerin dışında 2026-09-30_cihan_and_science vb.
-- göçlerle giren deepseek soruları da kapsanır.
--
-- Tekrar çalıştırılabilir. Uygulama:
--   supabase db query --linked -f supabase/2026-10-14_banka_ku_duzeltme.sql

begin;

-- edit_sinema_0029
update questions set
  prompt = 'Fîlmê "Yol" ji ber çi sedemî demeke dirêj li Tirkiyeyê nehat nîşandan?',
  option_a = 'Kopyayên fîlm winda bûbûn', option_b = 'Fîlm hate qedexekirin', option_c = 'Derhênerî nexwest ku li Tirkiyeyê were nîşandan', option_d = 'Fîlm hîn nehatibû qedandin'
where id = '4db422af-49fc-5803-b00f-5643d5bc026f';
-- ds26_cinema_0005
update questions set
  prompt = 'Qutbûna ku di nav dîmenekî de ji nişkê ve demê dide pêşerojê an paşerojê çi ye?',
  option_a = 'fade out (vedimirîn)', option_b = 'dissolve (tevlîhevî)', option_c = 'pan (gerandina panoramîk)', option_d = 'jump cut (qutbûna ji nişkê ve)'
where id = 'b1d496d1-92e2-53cf-a2ee-bd0e74dab455';
-- ex28_festival_belgefilm_014
update questions set
  prompt = 'Belgefîlma "İki Dil Bir Bavul" sala 2009an li Festîvala "Altın Portakal" a Antalyayê kîjan xelat wergirt?',
  option_a = 'Xelata Montaja Herî Baş', option_b = 'Xelata Lîstikvanê Zarok ê Herî Baş', option_c = 'Xelata Fîlmê Yekem ê Herî Baş', option_d = 'Xelata Senaryoya Herî Baş'
where id = '794b3b2e-5429-5bed-b97f-f8ad1698c9bd';
-- cinema_0037
update questions set
  prompt = 'Cureyê fîlmî yê ku li rojavayê Amerîkaya sedsala 19an, bi kovboy û şerên sînoran derbas dibe kîjan e?',
  option_a = 'Western', option_b = 'Melodram', option_c = 'Film noir', option_d = 'Trîler'
where id = 'ed612456-efe0-5c05-bef9-d101e5224340';
-- ds26_cinema_0089
update questions set
  prompt = 'Palmiyeya Zêrîn xelata herî bilind a kîjan festîvalê ye?',
  option_a = 'Festîvala Venedîkê', option_b = 'Festîvala Cannesê', option_c = 'Festîvala Berlînê', option_d = 'Festîvala Torontoyê'
where id = '00751d41-1f57-5cab-ae8b-cf50eea625b1';
-- ds26_cinema_0090
update questions set
  prompt = 'Festîvala fîlman a herî kevn a cîhanê kîjan e?',
  option_a = 'Festîvala Cannesê', option_b = 'Festîvala Berlînê', option_c = 'Festîvala Venedîkê', option_d = 'Festîvala Lokarnoyê'
where id = 'c4db8369-94ba-500a-a652-ddd44ad668c0';
-- sf_geo_0001
update questions set
  prompt = 'Di dîrokê de çend okyanûsên binavkirî hebûn?',
  option_a = 'Çar', option_b = 'Sê', option_c = 'Pênc', option_d = 'Şeş'
where id = '3c0d302a-6910-55bd-8d1b-6cb5ed2c7fca';
-- sf_nat_0017
update questions set
  prompt = 'Dûrahiya navîn a di navbera Cîhan û Heyvê de çend kîlometre ye?',
  option_a = '150.000 km', option_b = '384.400 km', option_c = '1.740 km', option_d = '12.000 km'
where id = 'f56925d4-c278-526f-9954-445e9858a610';
-- ds_cografya_0109
update questions set
  prompt = 'Paytexta Brezîlyayê kîjan bajar e?',
  option_a = 'Rio de Janeiro', option_b = 'Sao Paulo', option_c = 'Brasilia', option_d = 'Salvador'
where id = 'af127357-98e4-5a24-b744-26bf16dbe9d2';
-- ds_cografya_0111
update questions set
  prompt = 'Paytexta Îtalyayê kîjan bajar e?',
  option_a = 'Mîlano', option_b = 'Napolî', option_c = 'Roma', option_d = 'Tûrîn'
where id = '1259a721-ad64-5c9e-a092-d2dd9915be39';
-- ds_cografya_0113
update questions set
  prompt = 'Paytexta Spanyayê kîjan bajar e?',
  option_a = 'Barselona', option_b = 'Madrîd', option_c = 'Valensiya', option_d = 'Sevîlla'
where id = '4bc71631-b320-5e9d-b679-31d8e6a4fe9f';
-- ds_cografya_0115
update questions set
  prompt = 'Paytexta Meksîkê kîjan bajar e?',
  option_a = 'Guadalajara', option_b = 'Monterrey', option_c = 'Mexico City', option_d = 'Cancún'
where id = 'a91521ed-0207-579b-ad11-d6e8d55c2147';
-- ds_cografya_0119
update questions set
  prompt = 'Paytexta Arjantînê kîjan bajar e?',
  option_a = 'Córdoba', option_b = 'Rosario', option_c = 'Buenos Aires', option_d = 'Mendoza'
where id = '71acf05d-9c50-54ac-9cd5-20e5765c3551';
-- ds_cografya_0125
update questions set
  prompt = 'Paytexta Nîjeryayê kîjan bajar e?',
  option_a = 'Abuja', option_b = 'Lagos', option_c = 'Kano', option_d = 'Ibadan'
where id = 'd38e75cf-e952-5f58-883e-a0e2da9e6f22';
-- ds_dirok_0065
update questions set
  prompt = 'Kîjan padîşahê Babîlê qanûnên ku bi navê wî têne zanîn nivîsandin?',
  option_a = 'Nebukadnezar I', option_b = 'Nabopolassar', option_c = 'Marduk-zakir-shumi', option_d = 'Hamûrabî'
where id = '1f45591d-b69f-5ad0-96b1-7163716b88d5';
-- ds_dirok_0155
update questions set
  prompt = 'Kîjan şer di sala 1066''an de li Îngilîstanê qewimî?',
  option_a = 'Şerê Trafalgarê', option_b = 'Şerê Waterlooyê', option_c = 'Şerê Azincourtê', option_d = 'Şerê Hastingsê'
where id = 'c328b55c-bc2a-528b-81df-8ad516d4b7b7';
-- ds_dirok_0291
update questions set
  prompt = 'Di riya bazirganiyê ya dîrokî ya ku Çîn bi Rojava ve girê dida de, kîjan berhem ji Çînê dihat?',
  option_a = 'Hevrîşim', option_b = 'Zêr', option_c = 'Qehwe', option_d = 'Şekir'
where id = '3c91f2a0-1f8e-5286-9301-32d46a95390d';
-- ds_dirok_0294
update questions set
  prompt = 'Di Riya Hevrîşimê de kîjan tişt ji Hindistanê dihat?',
  option_a = 'Biharat', option_b = 'Hevrîşim', option_c = 'Çerm', option_d = 'Zêr'
where id = '0166937a-d6ed-5c76-9b2a-65853f8b2796';
-- ds_edebiyat_0082
update questions set
  prompt = 'Di destana "Beowulf" de, Beowulf bi kîjan dijminî re şer dike?',
  option_a = 'Aşîl', option_b = 'Rustem', option_c = 'Odîseus', option_d = 'Grendel'
where id = '5877f966-83b4-582c-b087-d24c8f4fd83e';
-- ds_muzik_0162
update questions set
  prompt = 'Kîjan celebê muzîkê di salên 1990yan de li Seattle derketiye?',
  option_a = 'Pop', option_b = 'Grunge', option_c = 'Hip-hop', option_d = 'Country'
where id = '17811d1e-1b4e-5a45-a0af-b8c65df1b7df';
-- ds_muzik_0190
update questions set
  prompt = 'Kîjan bestekar bi operaya xwe ya "Carmen" tê naskirin?',
  option_a = 'Wolfgang Amadeus Mozart', option_b = 'Ludwig van Beethoven', option_c = 'Giuseppe Verdi', option_d = 'Georges Bizet'
where id = 'c79d3fde-67a6-569e-b340-a89c68a462e1';
-- ds_sinema_0201
update questions set
  prompt = 'Kîjan derhênerê amerîkî fîlmê "Pulp Fiction" di sala 1994an de derxist?',
  option_a = 'Steven Spielberg', option_b = 'Quentin Tarantino', option_c = 'Martin Scorsese', option_d = 'Francis Ford Coppola'
where id = '43cc1d7a-4f3c-5c02-9560-2521b7c899b4';
-- ds_sinema_0204
update questions set
  prompt = 'Di fîlmê "Pulp Fiction" de, kîjan aktorî rola Jules Winnfield lîstiye?',
  option_a = 'John Travolta', option_b = 'Bruce Willis', option_c = 'Uma Thurman', option_d = 'Samuel L. Jackson'
where id = 'f52a52d0-88e6-5f90-b92d-cd1d5543cfb2';
-- ds_cografya_0106
update questions set
  prompt = 'Paytexta kîjan welatî Parîs e?',
  option_a = 'Almanya', option_b = 'Fransa', option_c = 'Spanya', option_d = 'Portûgal'
where id = '5fc5a920-d2ad-538c-ad1f-bda3912d7efe';
-- ds_cografya_0107
update questions set
  prompt = 'Paytexta Rûsyayê kîjan bajar e?',
  option_a = 'Sankt Petersburg', option_b = 'Novosîbîrsk', option_c = 'Moskova', option_d = 'Yekaterînburg'
where id = '9189ac1c-90ea-525f-99b1-09c6a2ef768c';
-- ds_cografya_0108
update questions set
  prompt = 'Paytexta kîjan welatî London e?',
  option_a = 'Îngilistan', option_b = 'Skotland', option_c = 'Wales', option_d = 'Îrlenda'
where id = 'a8ecc3d3-e9b4-5fe4-af91-1fda0bf66e22';
-- ds_cografya_0110
update questions set
  prompt = 'Paytexta kîjan welatî Washington D.C. ye?',
  option_a = 'Kanada', option_b = 'Meksîk', option_c = 'Kûba', option_d = 'Dewletên Yekbûyî'
where id = '24095062-b16c-5a69-ad74-b5fe08ff0bf2';
-- ds_cografya_0112
update questions set
  prompt = 'Paytexta kîjan welatî Berlîn e?',
  option_a = 'Awistirya', option_b = 'Swîsre', option_c = 'Holenda', option_d = 'Almanya'
where id = 'ad9ed9c3-7bd4-5f4e-b544-b97f5e543c40';
-- ds_cografya_0114
update questions set
  prompt = 'Paytexta kîjan welatî Pekîn e?',
  option_a = 'Japonya', option_b = 'Korêya Bakur', option_c = 'Taywan', option_d = 'Çîn'
where id = '584efcb9-430f-5484-aaf0-498e17607102';
-- ds_cografya_0116
update questions set
  prompt = 'Paytexta kîjan welatî Atîna ye?',
  option_a = 'Tirkiye', option_b = 'Îtalya', option_c = 'Kîpros', option_d = 'Yewnanistan'
where id = '02271365-aad0-5007-bf4d-299b8d5585dd';
-- ds_cografya_0117
update questions set
  prompt = 'Paytexta Hindistanê kîjan bajar e?',
  option_a = 'Mumbaî', option_b = 'Delhiya Nû', option_c = 'Kolkata', option_d = 'Bengaluru'
where id = '800f31a6-0629-5d38-96ed-6fa28d1aab28';
-- ds_cografya_0118
update questions set
  prompt = 'Paytexta kîjan welatî Seûl e?',
  option_a = 'Korêya Bakur', option_b = 'Japonya', option_c = 'Çîn', option_d = 'Korêya Başûr'
where id = 'cd31ea74-df42-55e0-b53c-a45f4d4e208c';
-- ds_cografya_0120
update questions set
  prompt = 'Paytexta kîjan welatî Viyana ye?',
  option_a = 'Almanya', option_b = 'Swîsre', option_c = 'Macaristan', option_d = 'Awistirya'
where id = '40d4890c-ca73-59b1-890b-6d566903c5b0';
-- ds_cografya_0121
update questions set
  prompt = 'Paytexta îdarî ya Afrîkaya Başûr kîjan bajar e?',
  option_a = 'Pretoria', option_b = 'Johannesburg', option_c = 'Cape Town', option_d = 'Durban'
where id = '220625d0-5c90-56e8-b60f-6549c94891f9';
-- ds_cografya_0122
update questions set
  prompt = 'Paytexta kîjan welatî Stockholm e?',
  option_a = 'Norwêc', option_b = 'Danîmarka', option_c = 'Swêd', option_d = 'Fînlenda'
where id = 'e0388c7a-13af-584a-b9c9-e6892e17af0b';
-- ds_cografya_0123
update questions set
  prompt = 'Paytexta Polonyayê kîjan bajar e?',
  option_a = 'Varşova', option_b = 'Kraków', option_c = 'Gdańsk', option_d = 'Wrocław'
where id = '1c2ab438-fb2a-53d5-8bb2-238761adbeaa';
-- ds_cografya_0124
update questions set
  prompt = 'Paytexta kîjan welatî Tehran e?',
  option_a = 'Iraq', option_b = 'Efxanistan', option_c = 'Sûrî', option_d = 'Îran'
where id = 'd33a9a6f-66a3-567f-b4e3-38a719f4bcdc';
-- ds_cografya_0199
update questions set
  prompt = 'Kîjan têgih ji bo xeta ku hêlîpan û hêlîdirêjan li ser nexşeyê nîşan dide tê bikaranîn?',
  option_a = 'Xeta îzolîn', option_b = 'Tora koordînatan', option_c = 'Xeta paralel', option_d = 'Xeta merîdyenê'
where id = 'f4e67d62-aea8-56a1-88e8-878db7b034d9';
-- ds_dirok_0157
update questions set
  prompt = 'Di kîjan serdemê de Şerê Sed Salan qewimî?',
  option_a = 'Sedsalên 12''an û 13''an', option_b = 'Sedsalên 13''an û 14''an', option_c = 'Sedsalên 14''an û 15''an', option_d = 'Sedsalên 15''an û 16''an'
where id = 'f9b4fa8d-8e7f-5a39-beb1-24a7474c8f31';
-- ds_dirok_0190
update questions set
  prompt = 'Kîjan kesayetî wek "Bavê Bijîşkiyê" tê zanîn?',
  option_a = 'Galen', option_b = 'Aristoteles', option_c = 'Hippokrates', option_d = 'Pythagoras'
where id = 'e7209b84-ecbd-5a38-ab04-d20819015efe';
-- ds_dirok_0234
update questions set
  prompt = 'Kîjan bûyer di sala 1811''an de li Brîtanyayê qewimî û tê de karkeran makîne hilweşandin?',
  option_a = 'Serhildana Çartîstan', option_b = 'Serhildana Luddîtan', option_c = 'Serhildana Swing', option_d = 'Serhildana Peterloo'
where id = '4e908073-e1c3-514b-ae24-cb4680160fae';
-- ds_dirok_0275
update questions set
  prompt = 'Tora bazirganiyê ya Riya Hevrîşimê bi piranî bi kîjan xanedanê ve tê girêdan?',
  option_a = 'Xanedana Ming', option_b = 'Xanedana Han', option_c = 'Xanedana Qing', option_d = 'Xanedana Tang'
where id = '0b3b9e14-98c8-59d6-8d2a-8bd95ff6b7fb';
-- ds_dirok_0293
update questions set
  prompt = 'Ewlehiya Riya Hevrîşimê di kîjan serdemê de bi "Pax Mongolica" ve zêde bû?',
  option_a = 'Serdema Kevir', option_b = 'Serdema Bronz', option_c = 'Serdema Mongol', option_d = 'Serdema Nûjen'
where id = 'ad0433a8-baa8-5443-b73f-25aebad68894';
-- ds_dirok_0276
update questions set
  prompt = 'Kîjan welat wekî destpêka Riya Hevrîşimê tê zanîn?',
  option_a = 'Hindistan', option_b = 'Misir', option_c = 'Yewnanistan', option_d = 'Çîn'
where id = 'b1b8da44-4a25-51ff-bfd9-dea26534d63c';
-- ds_dirok_0277
update questions set
  prompt = 'Riya bazirganiyê ya dîrokî ya ku Çîn bi Rojava ve girê dida, navê xwe ji kîjan berhemê digire?',
  option_a = 'Zêr', option_b = 'Hevrîşim', option_c = 'Qehwe', option_d = 'Çerm'
where id = '17f69e3a-db8d-5c4b-89f7-19e35fc0cd7d';
-- ds_dirok_0287
update questions set
  prompt = 'Di Riya Hevrîşimê de kîjan rêbaza veguhestinê dihat bikaranîn?',
  option_a = 'Karwanên deveyan', option_b = 'Trenên elektrîkê', option_c = 'Balafirên bazirganî', option_d = 'Keştiyên buharê'
where id = 'bbd5e4c2-e35b-54e3-b83e-3ff9d14bb42d';
-- ds_dirok_0282
update questions set
  prompt = 'Kîjan kesayetî bi Riya Hevrîşimê re têkildar e?',
  option_a = 'Julius Caesar', option_b = 'Napoleon', option_c = 'Îskenderê Mezin', option_d = 'Marko Polo'
where id = 'e78fd90d-226f-5460-9d05-3bfed4e9d9bd';
-- ds_edebiyat_0128
update questions set
  prompt = 'Di berhemên Shakespeare de, "To be or not to be" tê çi wateyê?',
  option_a = 'Evîn an nefret', option_b = 'Şer an aştî', option_c = 'Jiyan an mirin', option_d = 'Xewn an rastî'
where id = 'e5aef09f-99f6-5b7c-96ae-01770cad7b61';
-- ds_sinema_0179
update questions set
  prompt = 'Kîjan derhênerî belgefîlmê "Waltz with Bashir" derxist?',
  option_a = 'Werner Herzog', option_b = 'Errol Morris', option_c = 'Ari Folman', option_d = 'Michael Moore'
where id = '7a6df1c9-db0b-500d-b625-e5cc7dd48695';
-- ds_sinema_0194
update questions set
  prompt = 'Belgefîlmê "Senna" li ser jiyana kîjan ajokarê pêşbirkê ye?',
  option_a = 'Ayrton Senna', option_b = 'Michael Schumacher', option_c = 'Alain Prost', option_d = 'Niki Lauda'
where id = '95ba436f-2297-5000-8b11-2eb40d214194';
-- bilim_0003
update questions set
  prompt = 'Hejmara atomê ya elementeke kîmyewî çi nîşan dide?',
  option_a = 'Hejmara nêtronên di navikê de', option_b = 'Hejmara qatên elektronan', option_c = 'Hejmara îzotopan', option_d = 'Hejmara protonên di navikê de'
where id = '3d8290c9-c0b4-5ad6-b865-fd7e6f406503';
-- bilim_0005
update questions set
  prompt = 'Riwek di dema fotosentezê de ji hewayê bi giranî kîjan gazê digirin?',
  option_a = 'Oksîjen', option_b = 'Karbondîoksîd', option_c = 'Azot', option_d = 'Hîdrojen'
where id = 'ef102015-eec4-5b43-9743-55fd7c731245';
-- bilim_0006
update questions set
  prompt = 'Di DNAyê de baza adenînê bi normalî bi kîjan bazê re dibe cot?',
  option_a = 'Tîmîn', option_b = 'Sîtozîn', option_c = 'Guanîn', option_d = 'Urasîl'
where id = 'e7d783a9-0429-5549-ac42-fc16bde666ef';
-- bilim_0028
update questions set
  prompt = 'Di modela cudabûna hêzan de rayeyên dewletê bi kevneşopî li kîjan sê dabeşan tên veqetandin?',
  option_a = 'Navend, herêm û şaredarî', option_b = 'Bac, budçe û bazirganî', option_c = 'Polîs, artêş û dîplomasî', option_d = 'Zagonsazî, cîbicîkirin û daraz'
where id = 'c72adbfe-b686-5127-b698-f1c4b75091fb';
-- bilim_0030
update questions set
  prompt = 'Pênaseya herî giştî ya têgeha destûra bingehîn kîjan e?',
  option_a = 'Belgeya ku tenê budçeya salane ya dewletê diyar dike', option_b = 'Tevahiya biryarên ku rêxistinên navneteweyî wergirtine', option_c = 'Tevahiya prensîb û rêgezên rêxistiniya bingehîn a dewletekê', option_d = 'Zagona ku tenê sûcên cezayî rêz dike'
where id = 'd475db53-8a48-5db3-8538-959b81f6e614';
-- bilim_0037
update questions set
  prompt = 'Statûya Dîwana Dadê ya Navneteweyî ya di nav sîstema NYyê de kîjan e?',
  option_a = 'Organa zagonsaziyê ya Neteweyên Yekbûyî ye', option_b = 'Binkomîteya Konseya Ewlekariyê ya NYyê ye', option_c = 'Organa darazê ya sereke ya Neteweyên Yekbûyî ye', option_d = 'Organa temyîzê ya Dadgeha Cezayê ya Navneteweyî ye'
where id = '7159567c-1b58-54cc-9c8c-54acf26bb2e5';
-- ds_cografya_0207
update questions set
  prompt = 'Kîjan bajar paytexta herêma Kurdistanê ya Iraqê ye?',
  option_a = 'Hewlêr', option_b = 'Silêmanî', option_c = 'Kerkûk', option_d = 'Duhok'
where id = 'af075713-3552-5cb7-b7be-85c03db21600';
-- offline_2520
update questions set
  prompt = 'Di Zazakî (Kirmanckî) de yek ji mewlûdên nivîskî yên pêşîn kê nivîsiye?',
  option_a = 'Mela Ehmedê Xasî', option_b = 'Melayê Cizîrî', option_c = 'Ehmedê Xanî', option_d = 'Mehmed Uzun'
where id = '03cc8178-6eff-437e-93bb-d9e72028d44c';
-- ds_edebiyat_0160
update questions set
  prompt = 'Di helbesta klasîk a Kurmancî de, kîjan têgeh ji bo rêzkirina dengan tê bikaranîn?',
  option_a = 'Îmge', option_b = 'Metn', option_c = 'Serhatî', option_d = 'Rîtm'
where id = '112b4e63-95c6-5a17-90c0-d977dd9f4fa8';
-- ds_teknoloji_0194
update questions set
  prompt = 'Kîjan têgeh ji bo pêvajoya ku têlefon bi komputerê ve tê girêdan û daneyan vediguhêze tê bikaranîn?',
  option_a = 'HDMI', option_b = 'Ethernet', option_c = 'VGA', option_d = 'USB'
where id = '9c55286b-ced6-58e7-b6f1-0fc908690260';
-- ds_teknoloji_0272
update questions set
  prompt = 'Kîjan celebê enerjiyê di navika atomê de tê hilanîn?',
  option_a = 'Enerjiya nukleer', option_b = 'Enerjiya kîmyayî', option_c = 'Enerjiya germî', option_d = 'Enerjiya mekanîkî'
where id = '64dcba5a-8ba0-51a4-8bea-76c7c232a638';
-- ds_teknoloji_0276
update questions set
  prompt = 'Ji hejmara ku bi tenê bi xwe û bi yekê ve tê dabeşkirin re bi kurdî çi tê gotin?',
  option_a = 'Hejmara cot', option_b = 'Hejmara seretayî', option_c = 'Hejmara giştpîvan', option_d = 'Hejmara rasyonel'
where id = '72db9f13-975b-5320-8b8a-e4d7fee684f9';
-- ds_ziman_1176
update questions set
  prompt = 'Kîjan peyva kurmancî ji bo "dayika bavî" tê bikaranîn?',
  option_a = 'Dapîr', option_b = 'Xatûn', option_c = 'Xalojin', option_d = 'Dayik'
where id = '627f231d-6631-5dcd-bacf-597bca487fc1';
-- ds_cand_0157
update questions set
  prompt = 'Kîjan amûra têldar di muzîka govendê ya kurdî de tê bikaranîn?',
  option_a = 'Keman', option_b = 'Tembûr', option_c = 'Piyano', option_d = 'Gîtar'
where id = '7a5eedf4-7cca-5f3a-89de-e0dd9a2ca188';
-- ds_ziman_1102
update questions set
  prompt = 'Di metbexê de, kîjan amûr ji bo birîna tiştan tê bikaranîn?',
  option_a = 'Kefçî', option_b = 'Kêr', option_c = 'Çengal', option_d = 'Sênî'
where id = 'a4b7f40f-be04-5029-a3eb-770684423a11';
-- ds_ziman_1106
update questions set
  prompt = 'Di hundirê malê de, kîjan cih ji bo xwarinê tê bikaranîn?',
  option_a = 'Serşok', option_b = 'Odeya razanê', option_c = 'Baxçe', option_d = 'Metbex'
where id = '5bdba7f8-3cc3-531b-b7b9-68b76fc71985';
-- ds_ziman_0114
update questions set
  prompt = 'Di malê de, kîjan cih ji bo hilanîna xwarinan tê bikaranîn?',
  option_a = 'Dolaba xwarinê', option_b = 'Serşok', option_c = 'Odeya razanê', option_d = 'Baxçe'
where id = '986d3d29-c69b-5d1c-9956-ee98728c0d24';
-- ds_ziman_0121
update questions set
  prompt = 'Di malê de, kîjan cih ji bo hilanîna kincan tê bikaranîn?',
  option_a = 'Dolaba kincan', option_b = 'Metbex', option_c = 'Serşok', option_d = 'Baxçe'
where id = '9809962a-b3a5-551f-a235-3a241d253c38';
-- ds_ziman_0116
update questions set
  prompt = 'Ji bo danîna pirtûkan, kîjan moble tê bikaranîn?',
  option_a = 'Kursî', option_b = 'Dolaba pirtûkan', option_c = 'Mase', option_d = 'Nivîn'
where id = '38d1f4f1-1fb7-552f-a413-feb028c0fa66';
-- ds_cand_0101
update questions set
  prompt = 'Kîjan xwarina kurdî bi hevîrê savarê û goştê hûrkirî tê çêkirin?',
  option_a = 'Birinc', option_b = 'Kutilk', option_c = 'Şorbeya nîskê', option_d = 'Fasûlî'
where id = '76b21777-ea92-53ec-99ae-1af55d324709';
-- hat_0106
update questions set
  prompt = 'Partiya Keda Gel (HEP) di 1990an de bi serokatiya kîjan siyasetmedarî hate damezrandin?',
  option_a = 'Ahmet Turk', option_b = 'Vedat Aydin', option_c = 'Leyla Zana', option_d = 'Fehmî Işiklar'
where id = '75a16595-2f12-56aa-a282-4c46111d4ed7';
-- ds_dirok_0320
update questions set
  prompt = 'Dema ku Ebdulkerîm Qasim di sala 1958an de li Iraqê hate ser desthilatê, di destûra bingehîn de kîjan xal hate bicihkirin?',
  option_a = 'Zimanê kurdî wekî tekane zimanê fermî yê tevahiya dewletê hate ragihandin', option_b = 'Ereb û kurd di avakirina welat de wekî du şirîkên sereke hatin qebûlkirin', option_c = 'Hemû partiyên siyasî yên herêmî bi temamî hatin qedexekirin', option_d = 'Herêmên kurdan ji axa dewleta Iraqê bi temamî hatin veqetandin'
where id = '19457564-c373-5454-90d5-dc24d467a6c5';
-- ds_dirok_0337
update questions set
  prompt = 'Armanca sereke ya operasyonên Enfalê (1988) yên rejîma Baasê li dijî gelê kurd çi bû?',
  option_a = 'Tenê girtina çend serokên partiyan bêyî têkdana jiyana gundiyan', option_b = 'Pêşxistina çandiniya nûjen bi rêya belavkirina tovên berhemdar li gundan', option_c = 'Valakirina gundan, têkbirina berxwedana çiyayî û tunekirina komkî ya xelkê', option_d = 'Avakirina xetên nû yên trenê di navbera Silêmanî û Helebê de'
where id = '8ff42f09-4656-54a4-a19f-0c38caa316d3';
-- ds_teknoloji_0306
update questions set
  prompt = 'Kêmasiya ewlehiyê ya "Spectre" xwe dispêre kîjan taybetmendiya mîmariya nûjen a pêvajoyeran (CPU)?',
  option_a = 'Sîstema girtina germiyê û daxistina leza frekansa navendên pêvajoyê', option_b = 'Pêşbîniya çiqilan (branch prediction) û meşandina texmînî ya fermanan', option_c = 'Bikaranîna navnîşanên bîrgehê yên statîk di dema xebata bernameyan de', option_d = 'Rakirina bîrgeha lezgîn a asta yekem ji bo kêmkirina lêçûna fîzîkî'
where id = '19c70c70-476b-532c-addd-9d316f91e762';
-- ds_teknoloji_0307
update questions set
  prompt = 'Fikrên bingehîn ên mekanîzmaya komkirina çopê ya bi nifşan (Generational Garbage Collection) xwe dispêre çi?',
  option_a = 'Hemû tiştên di bîrgehê de hatine çêkirin heta dawiya bernameyê dijîn', option_b = 'Tiştên kevn ji yên nû zûtir tên jêbirin ji ber ku bîrgehê dagir dikin', option_c = 'Bîrgeha çalak her tim bi awayekî wekhev di navbera tiştan de tê parvekirin', option_d = 'Piraniya tiştên nûhatî (objects) di demeke pir kin de bêkêr dibin û dimirin'
where id = 'e349ecd8-9301-5b01-98cf-1fe18a50f0eb';
-- ds_teknoloji_0314
update questions set
  prompt = 'Di nivîsandina algorîtmayên krîptografîk de armanca bikaranîna rêbaza "Constant-Time" çi ye?',
  option_a = 'Ji bo zêdekirina leza hesabkirinê li ser her cure pêvajoyera kevn', option_b = 'Ji bo rêgirtina li êrîşên kanala alî yên li ser bingeha pîvandina demê', option_c = 'Ji bo kêmkirina enerjiya ku ji aliyê pîlê cîhazê ve tê xerckirin', option_d = 'Ji bo hêsankirina xwendina koda çavkaniyê ji aliyê bernameçêkeran ve'
where id = '7c5870e6-fa26-5485-b99f-c969b4417067';
-- ds_teknoloji_0315
update questions set
  prompt = 'Di mekanîzmaya baldariyê ya Transformeran de (Self-Attention), aloziya hejmartinê li gorî dirêjahiya rêzê (N) çawa zêde dibe?',
  option_a = 'Bi awayekî xêzî O(N) dimîne bêyî ku girêdayî hejmara nîşanan be', option_b = 'Bi awayekî logarîtmîk O(log N) kêm dibe dema ku rêz dirêjtir dibe', option_c = 'Bi awayekî çargoşeyî O(N^2) zêde dibe ji ber berhevdana her nîşanekê bi yên din re', option_d = 'Bi awayekî sabît O(1) dimîne ji ber ku bîrgeha GPU rasterast tê parvekirin'
where id = 'f156d457-ab69-5fa6-9532-74617cf12f25';
-- ds_ziman_1247
update questions set
  prompt = 'Di hevoka "Ez li ser maseyê pirtûkan dibînim" de peyva "maseyê" ji ber çi tewiyaye?',
  option_a = 'Ji ber ku di vê hevokê de wekî kirdeyê sereke hatiye destnîşankirin', option_b = 'Ji ber ku lêkera dîtin di dema niha de her tim navdêran ditewîne', option_c = 'Ji ber ku ketiye navbera daçeka hevedudanî ya cihî "li ser ..."', option_d = 'Ji ber ku peyva mase navdêreke nêr e û li pêşiya bireserê ye'
where id = 'd2ef3893-885a-5c08-b7ca-3f9ce18680b0';
-- ds_ziman_1249
update questions set
  prompt = 'Cudahiya wateyî ya di navbera daçekên "ji ... re" û "ji ... ve" de çi ye?',
  option_a = '"Ji ... re" tenê ji bo amûran e; "ji ... ve" tenê ji bo dema bê ye', option_b = 'Her du daçek jî yek wateyê didin û li şûna hev bê cudahî tên danîn', option_c = '"Ji ... re" navdêrê dike pirjimar lê "ji ... ve" dike yekjimar', option_d = '"Ji ... re" bo araste û sûdwergirtinê ye; "ji ... ve" bo destpêk û jêderê ye'
where id = 'e853b70e-552c-5dd3-9458-90c5ac6c8191';
-- ds_ziman_1250
update questions set
  prompt = 'Di daçekên "bi ... re" û "bi ... ve" de kîjan vebijêrk cudahiya hevaltî û pêvebûnê rast nîşan dide?',
  option_a = '"Bi ... re" hevaltî/tevgerê nîşan dide, "bi ... ve" pêvebûn/girêdanê nîşan dide', option_b = '"Bi ... re" tenê ji bo dema borî ye, "bi ... ve" ji bo dema niha ye', option_c = '"Bi ... re" neyîniyê çêdike, "bi ... ve" erêniyê diyar dike', option_d = 'Her du daçek jî tenê ji bo navên hejmaran tên bikaranîn'
where id = '7be094a2-7d60-5722-a6ba-fd7292b074e3';
-- ds_ziman_1263
update questions set
  prompt = 'Di navbera zaravayên kurmancî û soranî de cudahiya sereke ya di warê zayenda rêzimanî de çi ye?',
  option_a = 'Soranî sê zayendan diparêze lê di kurmancî de qet zayend nîne', option_b = 'Kurmancî zayenda mê û nêr diparêze, lê di soranî de zayend rabûye', option_c = 'Di her du zaravayan de jî sîstema zayendê bi tevahî wekhev e', option_d = 'Zayend tenê di soranî de heye û di kurmancî de tenê di lêkeran de ye'
where id = '9dcff32a-0635-5fe6-a4ab-5408a57fe5a4';
-- ds_ziman_1283
update questions set
  prompt = 'Di kurmancî de ferqa di navbera lêkerên hevedudanî yên "dest pê kirin" û "dest jê berdan" de ji aliyê daçekê ve çi ye?',
  option_a = 'Her du lêker jî tenê bi daçeka "tê" (di wê de) tên avakirin', option_b = 'Di ya yekem de ti daçek nîne lê di ya duyem de daçeka cihî heye', option_c = 'Di ya yekem de daçeka "pê" (bi wê), di ya duyem de "jê" (ji wê) hatiye bikaranîn', option_d = 'Daçek tenê ji bo çêkirina neyîniyê di lêkera duyem de heye'
where id = '6bfb9a9f-6c16-554d-892f-e03072225df9';
-- ds_ziman_1294
update questions set
  prompt = 'Di hevokên "Min nanê xwe xwar" û "Wî nanê xwe xwar" de çima cînavê vegerok ê "xwe" neguheriye?',
  option_a = 'Ji ber ku "xwe" ji bo hemû kesan cînavê xwedîtiyê yê gerdûnî ye', option_b = 'Ji ber ku lêkera xwarin tenê rê dide cînavên yekjimar', option_c = 'Ji ber ku nan navdêreke nêr e û cînavan bêbandor dike', option_d = 'Ji ber ku her du hevok jî di dema niha de hatine avakirin'
where id = '50f611fc-a806-50f8-a3a4-8230dd63094e';
-- ds_dirok_0016
update questions set
  prompt = 'Şerefxanê Bidlîsî ji kîjan mîrektiyê bû?',
  option_a = 'Mîrektiya Cizîrê', option_b = 'Mîrektiya Botanê', option_c = 'Mîrektiya Hekariyê', option_d = 'Mîrektiya Bidlîsê'
where id = '5ecf5ab2-a5f5-5237-b10f-23d49107e6eb';
-- ds_dirok_0124
update questions set
  prompt = 'Kîjan mîrektiya kurdan di sedsala 16an de li herêma çiyayî ya di navbera Wan û Mûsilê de hukum dikir?',
  option_a = 'Mîrektiya Botanê', option_b = 'Mîrektiya Babanê', option_c = 'Mîrektiya Colemêrgê', option_d = 'Mîrektiya Soranê'
where id = 'b46c2e8a-9d78-575f-ad02-4766b3bba8c2';
-- ds_dirok_0136
update questions set
  prompt = 'Yekem rojnameya kurdî, Kurdistan, ji aliyê kîjan malbatê ve hate derxistin?',
  option_a = 'Malbata Babanan', option_b = 'Malbata Soran', option_c = 'Malbata Bedirxaniyan', option_d = 'Malbata Hekariyê'
where id = 'ca58265e-ed96-5dab-91ce-0e2df46f2964';
-- ds_muzik_0005
update questions set
  prompt = 'Kîjan amûr di performansa dengbêjiyê de bi gelemperî tê bikaranîn?',
  option_a = 'Tembûr', option_b = 'Tu amûrek nîne', option_c = 'Keman', option_d = 'Ney'
where id = '01cbe4ce-ef90-5e21-9156-e8c32a50b8e9';
-- ds_sinema_0045
update questions set
  prompt = 'Di fîlma "Klama Dayika Min" (Erol Mintaş) de diya ku ji Tarlabaşiyê hatiye koçberkirin li kîjan tiştî digere?',
  option_a = 'Malbateke dewlemend ku alîkariya wan a aborî bike', option_b = 'Klameke winda û bîra çandî ya cihê ku lê jiya ye', option_c = 'Zêrên kevn ên ku di gund de di bin erdê de mane', option_d = 'Pasaporta nû ji bo koçkirina ber bi derveyî welat'
where id = '4bee9b8b-1b01-5550-9c0d-02acfc24d65e';
-- ds_teknoloji_0073
update questions set
  prompt = 'Di bernamekirinê de, kîjan têgeh ji bo hilanîna nirxekî ku dikare bibe komek nirxan tê bikaranîn?',
  option_a = 'Guherbar', option_b = 'Xelek', option_c = 'Kom', option_d = 'Şert'
where id = '70235e02-cee3-5030-99e5-44adf8474cd2';
-- ds_teknoloji_0068
update questions set
  prompt = 'Di bernamekirinê de, kîjan têgeh ji bo hilanîna nirxekî ku dikare bibe rast an derew tê bikaranîn?',
  option_a = 'Mantiqî', option_b = 'Guherbar', option_c = 'Xelek', option_d = 'Şert'
where id = 'b1c2bdfa-e22f-5144-a4c9-095202cd38fb';
-- ds_teknoloji_0071
update questions set
  prompt = 'Di bernamekirinê de, kîjan têgeh ji bo hilanîna nirxekî ku dikare bibe navnîşek tîpan tê bikaranîn?',
  option_a = 'Nivîs', option_b = 'Guherbar', option_c = 'Xelek', option_d = 'Şert'
where id = 'ea4190a0-2c54-502d-b0d5-cfe33dce117c';
-- ds_teknoloji_0060
update questions set
  prompt = 'Di bernamekirinê de, kîjan têgeh ji bo hilanîna nirxekî rast an derew tê bikaranîn?',
  option_a = 'Guherbar', option_b = 'Xelek', option_c = 'Şert', option_d = 'Boolean'
where id = 'a0db567f-17fe-5b7f-8c21-f38b61b22e4f';
-- ds_teknoloji_0177
update questions set
  prompt = 'Di têlefoneke jîr de, kîjan beş ji bo hilanîna wêneyan û pelan tê bikaranîn?',
  option_a = 'Bîra xebitandinê', option_b = 'Bîra hundirîn', option_c = 'Pêvajo', option_d = 'Batarya'
where id = '76a4a2c8-697d-5605-838a-44a9dc092cf4';
-- ds_teknoloji_0189
update questions set
  prompt = 'Di têlefoneke jîr de, kîjan beş ji bo nîşandana wêneyan tê bikaranîn?',
  option_a = 'Batarya', option_b = 'Pêvajo', option_c = 'Ekran', option_d = 'Bîra hundirîn'
where id = 'f0bd228e-cb48-5727-895d-fc6a1a903364';
-- ds_teknoloji_0205
update questions set
  prompt = 'Di sala 1945an de, kîjan kesî pêşniyar kir ku bername û dane di heman bîra komputerê de bêne hilanîn?',
  option_a = 'John von Neumann', option_b = 'Alan Turing', option_c = 'Konrad Zuse', option_d = 'Bill Gates'
where id = 'ef6ea15f-c009-57e2-808a-8d96f4d6954f';
-- ds_teknoloji_0281
update questions set
  prompt = 'Kîjan têgeh di matematîkê de ji bo rêjeya di navbera dora çemberê û çapa wê de tê bikaranîn?',
  option_a = 'Euler', option_b = 'Fibonacci', option_c = 'Pi', option_d = 'Pisagor'
where id = '0f492b94-1206-5cd4-9998-9679658543d1';
-- ds_cand_0265
update questions set
  prompt = 'Di çanda kurdî de, kîjan xwarin bi gelemperî ji bo jina ku nû zayî ye tê çêkirin?',
  option_a = 'Kutilk', option_b = 'Şorbe', option_c = 'Birinc', option_d = 'Nan'
where id = '05dd3e7f-d017-5760-8f20-99308003b744';
-- hat_0128
update questions set
  prompt = 'Dilê wê her tim lê dide, lê zindî nîne û demê nîşan dide; ew çi ye?',
  option_a = 'Saet', option_b = 'Kursî', option_c = 'Mase', option_d = 'Derî'
where id = 'b052dffc-b1a5-5f45-9c25-7d4cb7068be2';
-- ds_cand_0227
update questions set
  prompt = 'Kîjan cejn bi gelemperî di 21ê Adarê de tê pîrozkirin?',
  option_a = 'Newroz', option_b = 'Sersal', option_c = 'Cejna Remezanê', option_d = 'Cejna Qurbanê'
where id = '0bcb9643-736d-5af9-b2ec-a0d6e7cfbe43';
-- ds_cand_0235
update questions set
  prompt = 'Kîjan cejn bi gelemperî di 10ê Zilhicceyê de tê pîrozkirin?',
  option_a = 'Cejna Qurbanê', option_b = 'Cejna Remezanê', option_c = 'Newroz', option_d = 'Sersal'
where id = 'e40069a7-033a-5917-92a6-905feb8fb637';
-- ds_cand_0233
update questions set
  prompt = 'Kîjan cejn bi gelemperî ji bo bîranîna Îbrahîm Pêxember tê pîrozkirin?',
  option_a = 'Cejna Qurbanê', option_b = 'Cejna Remezanê', option_c = 'Newroz', option_d = 'Sersal'
where id = 'aa741254-b723-5b45-ae05-88f53be3f46e';
-- ds_cand_0239
update questions set
  prompt = 'Cejna Remezanê di kîjan meha qemerî de tê pîrozkirin?',
  option_a = 'Meha Şewalê', option_b = 'Meha Remezanê', option_c = 'Meha Muherremê', option_d = 'Meha Zilhicceyê'
where id = '661e3993-06fc-5bd1-89f0-ebdedf991079';
-- ds_muzik_0229
update questions set
  prompt = 'Bandora sereke ya dîrokî ya beşa kurdî ya Radyoya Êrîvanê (1955) li ser bîra muzîka kurdî çi bû?',
  option_a = 'Qedexekirina amûrên gelêrî û tenê bikaranîna muzîka klasîk a rûsî', option_b = 'Qeydkirina kilamên devkî bi orkestrasyonê û belavkirina wan a li seranserê herêmê', option_c = 'Tenê çêkirina operayên bi zimanê ermenî li ser dîroka kevnar', option_d = 'Rakirina kevneşopiya dengbêjiyê û anîna muzîka elektronîk a rojavayî'
where id = '67f0f75a-9c85-50c5-8f4c-b2edb2c8e82a';
-- ds_muzik_0241
update questions set
  prompt = 'Di salên 1990î de bandora komên wekî "Koma Dengê Azadî" û "Koma Amed" li ser muzîka nûjen a kurdî çi bû?',
  option_a = 'Têkelkirina melodiyên gelêrî bi polîfonî û amûrên nûjen ên rojavayî re', option_b = 'Rakirina zimanê kurdî û tenê gotina stranên îngilîzî', option_c = 'Qedexekirina tembûrê û tenê bikaranîna muzîka elektronîk a bê peyv', option_d = 'Tenê xwendina metnên dînî yên serdema navîn li mizgeftan'
where id = '2277a859-ca09-500e-841c-d4409491398f';
-- ds_sinema_0269
update questions set
  prompt = 'Sînemaya nûjen a kurdî çima bi piranî ji çîrok û motîfên dengbêjiyê sûd werdigire?',
  option_a = 'Ji ber ku muzîka dengbêjiyê bi hêsanî bi piyanoyê tê guhertin', option_b = 'Ji ber ku qanûnên sînemayê bikaranîna zimanên din qedexe dikin', option_c = 'Ji ber ku di dengbêjiyê de tenê qala çîrokên zanistî tê kirin', option_d = 'Ji ber ku bîra dîrokî û çavkaniya herî xurt a dramatîk a devkî ye'
where id = '81cfe042-ffca-5a25-931c-48c846b7a991';
-- ds_sinema_0279
update questions set
  prompt = 'Fîlma kurt a "Ax" (Toprak, 1999) a "Kazım Öz" çîroka kalekî li gundekî valakirî çawa vedibêje?',
  option_a = 'Şahiya cejnekê ya li gundekî qelebalix bi muzîk û reqsan', option_b = 'Dîroka avakirina bendaveke mezin li ser rûbarê Firatê', option_c = 'Pêşbirkeke çandiniyê di navbera cotkarên herêmê de', option_d = 'Tenêtiya giran a mirovekî ku xaka xwe bernade li hemberî hilweşîn û bêdengiyê'
where id = 'dcaf8039-db90-5b2e-adae-9367642f4e87';
-- ds_sinema_0288
update questions set
  prompt = 'Di fîlma "14 Tîrmeh" (14 Temmuz, 2017) a Haşim Aydemir de, zimanê dîtbarî li ser kîjan şêwazê ava dibe?',
  option_a = 'Klostrofobiya zindanê, êşa giran a laşî û biryardariya îradeya mirov', option_b = 'Dîmenên geş ên peravên deryayê bi muzîka şad', option_c = 'Gera li nav muzexaneyên mezin ên Ewropayê bi hevalan re', option_d = 'Fîlmeke komedî ya li ser jiyana karsazên li otêlên luks'
where id = '2d9d2a6a-ead7-5f46-8b5d-d7533a986d22';
-- ds_dirok_0331
update questions set
  prompt = 'Tevgerên Barzan ên di salên 1943-1945an de ji bo damezrandina Komara Mehabadê (1946) kîjan sûda rasterast anîn?',
  option_a = 'Hemû firokeyên şer ên pêwîst ji aliyê eşîra Barzan ve ji derve hatin anîn', option_b = 'Sîstema aborî ya komarê tenê bi rêya bazirganiya petrola Barzan pêk hat', option_c = 'Mele Mistefa Barzanî û pêşmergeyên wî bûn bingeha hêza leşkerî ya komarê', option_d = 'Hemû qanûnên destûra komarê ji aliyê rûspiyên Barzan ve hatin nivîsandin'
where id = 'e164c8a7-a6e9-543d-9189-1bdc387b35a6';
-- ds_dirok_0338
update questions set
  prompt = 'Piştî Şerê Kendavê û piştî biryara 688an di sala 1991ê de, koalîsyonê li bakurê Iraqê kîjan gav avêt?',
  option_a = 'Sînorên navdewletî yên Iraqê ji nû ve bi fermî guhert', option_b = 'Herêma qedexeya firînê li bakur ava kir û vegera penaberan hêsantir kir', option_c = 'Hemû rêveberiyên herêmî bi fermî betal kir', option_d = 'Kontrola hemû dergehên sînorî rasterast girt destê xwe'
where id = '713c9bdb-6878-52e4-8319-e55cb9c66803';
-- bosluk_0085
update questions set
  prompt = 'Rast e an şaş e: Kovara kurdî "Hawar", di sala 1930an de li Şamê ji aliyê Celadet Alî Bedirxan ve hatiye derxistin.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'c44174c4-4f93-51e0-8dc4-c1d9ab25b38b';
-- ds_teknoloji_0347
update questions set
  prompt = 'Di mîmariya "Event Sourcing" de rewşa heyî ya sîstemê (state) çawa tê bidestxistin?',
  option_a = 'Bi xwendina yek qeyda herî dawî ya ku di tabloyeke statîk a SQLê de maye', option_b = 'Bi texmînkirina encamê bi riya modeleke fêrbûna makîneyê ya hêsan', option_c = 'Bi girtina kopiyeke fîzîkî ya hemû bîrgeha RAMê li ser dîskeke derve', option_d = 'Bi ji nû ve meşandina hemû bûyerên dîrokî yên ku heta niha li pey hev qewimîne'
where id = 'cab543c7-57eb-59ed-994a-5657c0b227b5';
-- bosluk_0090
update questions set
  prompt = 'Rast e an şaş e: Cejna Hanukayê têkoşîna Makabiyan a li dijî Împaratoriya Romayê bi bîr tîne.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'a0794cb0-b720-5fb4-b5c9-952f3ff0a0ea';
-- bosluk_0093
update questions set
  prompt = 'Rast e an şaş e: Şerê Hastingsê, ku Normanan Îngilistan pê dagir kir, di sala 1068an de pêk hat.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'bea6ba30-53bd-5d13-b997-a3b43442e69f';
-- ds_teknoloji_0106
update questions set
  prompt = 'Kîjan cîhaz ji bo hilanîna daneyan bi awayekî daîmî tê bikaranîn?',
  option_a = 'Hard disk', option_b = 'RAM', option_c = 'CPU', option_d = 'Karta dengî'
where id = 'b586e385-1ba6-5b22-92f8-7816bb780244';
-- ds_teknoloji_0112
update questions set
  prompt = 'Kîjan cîhaz ji bo girêdana komputerê bi înternetê re tê bikaranîn?',
  option_a = 'Karta dengî', option_b = 'Karta grafîkê', option_c = 'Karta bîrê', option_d = 'Karta torê'
where id = '1b98a82c-52cf-5b06-975c-2d0995455951';
-- ds_sinema_0200
update questions set
  prompt = 'Kîjan belgefîlmçêkerê amerîkî fîlma "The Act of Killing" derxist?',
  option_a = 'Joshua Oppenheimer', option_b = 'Adam Curtis', option_c = 'Nick Broomfield', option_d = 'Louis Theroux'
where id = '516d3d14-b170-5e6b-9f30-9e8a71e6b05a';
-- ds_sinema_0208
update questions set
  prompt = 'Di fîlma "Schindler''s List" a Steven Spielberg de, kîjan aktorî rola Oskar Schindler lîstiye?',
  option_a = 'Liam Neeson', option_b = 'Ben Kingsley', option_c = 'Ralph Fiennes', option_d = 'Daniel Day-Lewis'
where id = '138fe7b3-7724-571e-af30-2c17c719a3ba';
-- ds_teknoloji_0006
update questions set
  prompt = 'Di lêpirsîna DNSê de rola "Recursive Resolver" û "Authoritative Name Server" çawa ji hev vediqete?',
  option_a = 'Resolver tenê navnîşanên MAC tomar dike, Authoritative daneyên HTTP dişîne', option_b = 'Resolver tenê di komputerên kesane de heye, Authoritative routera herêmî ye', option_c = 'Resolver geroka înternetê bixwe ye, Authoritative karta tora bêtêl e', option_d = 'Resolver li ser navê klîentê hiyerarşiyê digere, Authoritative qeyda teqez a navê domênê digire'
where id = 'c6adc8df-1c4a-5a25-8c5a-19e4b5e6c710';
-- bilim_0070
update questions set
  prompt = 'Çavdêriyên Alexander Fleming ên di sala 1928''an de, bi keşfa kîjan madeya antîbakteriyel re têkildar in?',
  option_a = 'Însulîn', option_b = 'Kînîn', option_c = 'Streptomîsîn', option_d = 'Penîsîlîn'
where id = '0c3daa41-88bf-53d1-9b69-aa03a4432838';
-- ds_sinema_0267
update questions set
  prompt = 'Fîlma "Babamın Kanatları" bi lîstikvaniya "Menderes Samancılar" kîjan pirsgirêka civakî tîne ziman?',
  option_a = 'Gera tûrîstên dewlemend li ser peravên deryayê', option_b = 'Pêşketina şîrketên komputerê di qada firotina serhêl de', option_c = 'Perwerdehiya pîlotên balafiran di akademiyên leşkerî de', option_d = 'Kuştinên karkeran di qada avakirinê de û bêewlehiya jiyana karkerên koçber'
where id = '68333b3e-a0e5-5444-8f7d-2121b3478dec';
-- altkonu_0001
update questions set
  prompt = 'Albûma stûdyoyê ya yekem a Şivan Perwer kîjan e?',
  option_a = 'Seyir', option_b = 'Govenda Azadîxwazan', option_c = 'Sebra Min', option_d = 'Lê Dayê'
where id = '299859aa-49dd-52ef-ac72-1cb5b51638c2';
-- altkonu_0003
update questions set
  prompt = 'Albûma stûdyoyê ya duyem a Aynûr Dogan ku di sala 2004''an de derketiye kîjan e?',
  option_a = 'Seyir', option_b = 'Nûpel', option_c = 'Bahar', option_d = 'Keçe Kurdan'
where id = '97990d53-807c-5e7e-9a2c-7acada9025d4';
-- altkonu_0009
update questions set
  prompt = 'Wateya koda rewşê ya HTTP 404 çi ye?',
  option_a = 'Rûpel nehat dîtin', option_b = 'Çewtiya pêşkêşkarî', option_c = 'Beralîkirin', option_d = 'Gihîştina bêdestûr'
where id = 'a3397584-e761-5418-af89-29497c907024';
-- altkonu_0011
update questions set
  prompt = 'Di lêgerîna duduyî (binary search) de, tevlîheviya demê ya rewşa herî xirab çi ye?',
  option_a = 'O(1)', option_b = 'O(n)', option_c = 'O(n²)', option_d = 'O(log n)'
where id = 'b237cd93-936f-52be-8119-d2746a9ea71e';
-- altkonu_0014
update questions set
  prompt = 'Fîlmê Yilmaz Guney ê ku di sala 1982''yan de li Festîvala Fîlman a Cannesê xelata Palmiyeya Zêrîn girtiye, kîjan e?',
  option_a = 'Ağıt', option_b = 'Yol', option_c = 'Duvar', option_d = 'Umut'
where id = '8c1dbfef-bac8-5423-843d-f3415d6b1a74';
-- altkonu_0015
update questions set
  prompt = 'Fîlmê Yilmaz Guney ê bi navê "Umut" di kîjan salê de hat nîşandan?',
  option_a = '1966', option_b = '1968', option_c = '1970', option_d = '1973'
where id = 'a70304b0-6f40-5405-8a30-5801107860fa';
-- altkonu_0016
update questions set
  prompt = 'Kîjan derhênerî fîlmê "Rashomon" derhênaye?',
  option_a = 'Yasujirō Ozu', option_b = 'Akira Kurosawa', option_c = 'Kenji Mizoguchi', option_d = 'Masaki Kobayashi'
where id = '1257d381-b8a0-551d-9af2-20a8f4ac899f';
-- altkonu_0017
update questions set
  prompt = 'Fîlmê "Dizên Duçerxeyan" ji serberhemên kîjan herika sînemayê tê hejmartin?',
  option_a = 'Pêla Nû ya Fransî', option_b = 'Pêla Nû ya Çekî', option_c = 'Neo-realîzma Îtalî', option_d = 'Pêla Nû ya Almanî'
where id = 'f5478dba-19ca-5eb1-97a1-2e9e287f09b8';
-- offline_2668 (onaysız satır)
update questions set
  prompt = 'Selahedînê Eyûbî li kîjan bajarî ji dayik bûye?',
  option_a = 'Tikrit', option_b = 'Kahire', option_c = 'Bağdat', option_d = 'İstanbul'
where id = '3693edc9-a7cb-48fe-86ac-8ede0db9645b';
-- bosluk_0111
update questions set
  prompt = 'Rast e an şaş e: Çemê Firatê dirije Deryaya Navîn.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'fcb6af68-14d4-5b47-ae27-be9224b9a5ef';
-- bosluk_0116
update questions set
  prompt = 'Rast e an şaş e: Gola Wanê bi riya rûbarekê dirije deryayê.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = '1f3490c0-f940-5999-8cdb-463c8270c897';
-- ds_cand_1188
update questions set
  prompt = 'Cudahiya rîtmîk û tevgerî ya di navbera govendên "Şêxanî" û "Giranî" de çi ye?',
  option_a = 'Giranî tenê bi rûniştî tê lîstin, Şêxanî tenê li ser hespan e', option_b = 'Giranî tenê bi jinan e, Şêxanî tenê lîstika zarokan e', option_c = 'Giranî ti caran bê def nabe, Şêxanî qet muzîkê naxwaze', option_d = 'Giranî bi gavên giran û seknekê ye, Şêxanî bileztir û livdar e'
where id = '78bb8251-66fd-5328-8a44-441ac38cfbc3';
-- ds_cand_1195
update questions set
  prompt = 'Penêrê Sîrikî (otlu peynir) yê Wanê çima piştî çêkirinê çend mehan di bin erdê de tê veşartin?',
  option_a = 'Ji bo havênbûna hênik, hevgirtina bêhnê û negirtina hewayê', option_b = 'Ji bo ku agirê binê erdê penêr zû biqelîne', option_c = 'Ji bo ku keda mirovan ji çavên dizan veşartî bimîne', option_d = 'Tenê ji bo ku rengê penêr ji spî veguhere reş'
where id = '5207c871-b193-5559-a69a-ea2265c3c666';
-- edit_cand_0004
update questions set
  prompt = 'Di çanda kurdî de "tiştonek" çi ye?',
  option_a = 'Stranek dînî', option_b = 'Cureyekî xwarinê', option_c = 'Mamik / bilmece', option_d = 'Reqseke gelêrî'
where id = 'a1f72b7a-9848-5d75-8e6e-a469af63eab0';
-- edit_cand_0009
update questions set
  prompt = 'Destana "Mem û Zîn" bi giştî çîroka çi ye?',
  option_a = 'nasname û cihêrengiya herêmî', option_b = 'mêvanperweriya kurdî', option_c = 'Evîna Mem û Zînê ya ku nagihîje hev', option_d = 'bi çanda devkî ve girêdayî ye'
where id = '8ebe30a7-bdfa-5d50-aac2-1694092cbd3e';
-- edit_cand_0034
update questions set
  prompt = 'Rast e an şaş e: Govend bi gelemperî bi destgirtinê tê lîstin.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = '917cd285-6c60-58ed-b2f1-022cbcf355a4';
-- edit_cand_0038
update questions set
  prompt = 'Xalîçe û kilîmên kurdî bi giştî bi çi tên xemilandin?',
  option_a = 'Wêneyên fotografî', option_b = 'Motîfên hejmarî û sembolîk', option_c = 'Nivîsên dirêj', option_d = 'Rengên tenê reş û spî'
where id = 'c1b17c99-b7ab-50e0-aa6a-f194c9889fe2';
-- hat_0010
update questions set
  prompt = 'Romana bi navê "Janî Gel" ku wek yekem romana soranî tê qebûlkirin, kê nivîsiye?',
  option_a = 'Îbrahîm Ehmed', option_b = 'Bextiyar Elî', option_c = 'Ata Nahayî', option_d = 'Şêrzad Hesen'
where id = '517d07e4-b30c-5776-ac1f-18ed04d8ed63';
-- ex28_dastangotin_012
update questions set
  prompt = 'Di destana Mem û Zînê de, dema Zîn xwe di bin ebaya Mem de vedişêre, Tacdîn çi dike da ku Mîr ji baxçe dûr bixe?',
  option_a = 'Zengilê bajêr lê dide', option_b = 'Şerekî derewîn dest pê dike', option_c = 'Agir berdide qesra xwe', option_d = 'Hespên Mîr berdide'
where id = 'eee01a23-5c0e-5903-b32c-f0e400fde1df';
-- hat_0011
update questions set
  prompt = 'Berhema klasîk a bi navê "Mem û Zîn" ku bingeha romana kurdî tê dîtin, kê nivîsiye?',
  option_a = 'Ehmedê Xanî', option_b = 'Feqiyê Teyran', option_c = 'Melayê Cizîrî', option_d = 'Elîyê Herîrî'
where id = '52c9b4d5-4ce1-5fd8-9f22-ad162ff4d381';
-- hat_0012
update questions set
  prompt = 'Romana bi navê "Tu" ku di sala 1985an de li Swêdê hatiye weşandin, kê nivîsiye?',
  option_a = 'Mehmed Uzun', option_b = 'Jan Dost', option_c = 'Hesenê Metê', option_d = 'Helîm Yûsiv'
where id = '2bdc636f-6d2d-5c3f-9c94-0ad8d4b585a4';
-- ex28_tistonek_004
update questions set
  prompt = 'Mamikeke kurdî (tiştonek) wiha dibêje: "Ji hire heta Mûsil hemî moriyên sinsil." Bersiv çi ye?',
  option_a = 'Berf', option_b = 'Ba', option_c = 'Birûsk', option_d = 'Baran'
where id = 'e32c38f9-4148-5179-b3ba-bea7ef74a544';
-- hat_0015
update questions set
  prompt = 'Romana bi navê "Şarî Mûsîqare Spîyekan" ku di sala 2006an de hatiye weşandin, kê nivîsiye?',
  option_a = 'Bextiyar Elî', option_b = 'Ata Nahayî', option_c = 'Şêrzad Hesen', option_d = 'Jan Dost'
where id = 'bbc34777-495f-5cf4-a329-55b7ebd24a86';
-- hat_0016
update questions set
  prompt = 'Romana bi navê "Mijabad" ku behsa dîroka Komara Mahabadê dike, kê nivîsiye?',
  option_a = 'Jan Dost', option_b = 'Hesenê Metê', option_c = 'Helîm Yûsiv', option_d = 'Fawaz Husên'
where id = 'f04f32a6-2bab-5e80-bd1e-efd2c0d8b5b4';
-- ex28_tistonek_025
update questions set
  prompt = 'Li hin herêman ji tiştonekê re navekî din tê gotin û pirs bi qalibekî taybet dest pê dike. Ew qalib kîjan e?',
  option_a = 'Carekê ji caran hebû', option_b = 'Guh bidin gotina min', option_c = 'Hebû tunebû, li welatekî', option_d = 'Mamika min a mamanî'
where id = '047cb9c5-2ffc-5829-93ac-3249d4c39ec5';
-- offline_2271
update questions set
  prompt = 'Vexwarina ji cureyê Dew/doogh bi kîjan madeya sereke re têkildar e?',
  option_a = 'lîkora qehweyê', option_b = 'tenê qalikê lîmonê', option_c = 'mast/dew', option_d = 'arê garisî'
where id = 'fcb965f9-eb86-5f64-b593-f492adf19ffe';
-- offline_2307
update questions set
  prompt = 'Di civaka kurdî de avahiyên eşîrî di dîrokê de xwedî kîjan fonksiyonê bûne?',
  option_a = 'tora rêxistinbûna civakî, ewlehî, hilberîn û têkiliya siyasî', option_b = 'xwarina kevneşopî ya ku bi mirîşk û birincê tê çêkirin', option_c = 'ziman, çand, weşangerî, hevgirtin û veguhastina nasnameyê', option_d = 'xwarina sebzeyan an pelan a ku bi dagirtinê tê tijîkirin'
where id = 'e99a7e8a-0beb-5ee5-9706-b2800af5d083';
-- offline_2452
update questions set
  prompt = 'Di çanda herêmê de heyîna efsaneyî ya bi motîfa mar a berbelav kîjan e?',
  option_a = 'efsaneya hespê bibask', option_b = 'Şahmaran', option_c = 'efsaneya keça deryayê', option_d = 'efsaneya teyrê dêw'
where id = 'd7d3e1f4-562b-5e0a-a1b2-5b9ebda8ec4c';
-- offline_2782
update questions set
  prompt = 'Di Êzidîtiyê de kevneşopiya duakirinê ya ber bi rojê ve çi nîşan dide?',
  option_a = 'pîroziya ku ji ronahiyê/rojê re tê dayîn', option_b = 'Melek Tawis û motîfa ronahiyê/rojê', option_c = 'bi çanda rojane re girêdayî ye', option_d = 'xurtkirina girêdanên civakî'
where id = '871f9df8-c339-5057-b456-f239051b6cb1';
-- offline_6093
update questions set
  prompt = '"tûrik" çi ye?',
  option_a = 'şivantiya kevneşopî û zanîna xwezayê', option_b = 'cejna berdana beran û ajaldariyê', option_c = 'çîrok û kilam/stran', option_d = 'tûrê hûnandî yê ku xwarin tê de tê hilgirtin'
where id = 'b0a0fca8-aa88-5f74-a85a-16119b8655eb';
-- offline_6538
update questions set
  prompt = '"şevbêrk" çi ye?',
  option_a = 'bi jiyana di erdnîgariya çiyayî de di dirêjahiya dîrokê de', option_b = 'kincên rengîn, gelek-tebeqe û dirêj (kiras)', option_c = 'lîstik an reqsên kevneşopî yên jinan', option_d = 'civînên axaftinê yên şevên zivistanê'
where id = 'c1900627-a209-52f4-a198-d4b85eb58581';
-- offline_6730
update questions set
  prompt = '"serpêhatî" çi ye?',
  option_a = 'zêrên ku di dawetan de li bûkê tên kirin', option_b = 'cejna kevneşopî ya rakirin û bereketê', option_c = 'vegotina bûyerên balkêş ên rastî', option_d = 'rolên kevneşopî yên civakî-olî'
where id = '6e9f8007-63ad-5c56-b456-42cb3b7a3d93';
-- offline_tf_0119
update questions set
  prompt = 'Rast e an şaş e: "mêvanperweriya kurdî" şêwaza jiyana kevnar a li ser zozan û germiyanan e ku çanda kurdî pir dewlemend kiriye.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'cfb1ebb6-f214-55c4-9852-6d0bc355e110';
-- restore_2026_08_07_0001
update questions set
  prompt = 'Di dawet û şahiyên kurdî de diyariya pereyan a ku ji bo nûzewacan tê dayîn bi kîjan navî tê nasîn?',
  option_a = 'metelok', option_b = 'klaş', option_c = 'hewran', option_d = 'şabaş'
where id = 'cfa99d46-5805-56ef-bd4e-817c3ebf456d';
-- restore_2026_08_07_0002
update questions set
  prompt = 'Pêlava kurdî ya kevneşopî ya ku bi tayan tê hûnandin bi kîjan navî tê nasîn?',
  option_a = 'şûtik', option_b = 'klaş', option_c = 'kolos', option_d = 'elek'
where id = 'bbee6622-5449-5dc9-9f51-3e043e429cd1';
-- restore_2026_08_07_0004
update questions set
  prompt = 'Çadira reş a ji mûyê bizinan ya ku koçer di havînê de li zozanan datînin bi kîjan navî tê nasîn?',
  option_a = 'klaş', option_b = 'reşmal', option_c = 'şûtik', option_d = 'metelok'
where id = '1147c81b-570a-5bc4-a81b-367b340ab34e';
-- ds_cografya_0248
update questions set
  prompt = 'Cudahiya sereke ya jeomorfolojîk a di navbera Gola Hêzarê û Gola Nemrûdê de çi ye?',
  option_a = 'Hêzar gola tektonîk e, Nemrûd gola kalderayê ya volkanîk e', option_b = 'Hêzar gola cemedî ye, Nemrûd gola kembera karstîk e', option_c = 'Hêzar gola setê ya çem e, Nemrûd gola tektonîk a kûr e', option_d = 'Hêzar gola çêkirî ye, Nemrûd gola sirûştî ya aluvyal e'
where id = '44ab0464-2fa5-54f4-b77d-436a50983824';
-- hat_0021
update questions set
  prompt = 'Kîjan berhem ferhenga menzûm a zarokan e û ji aliyê Ehmedê Xanî ve hatiye amadekirin?',
  option_a = 'Nûbihara Biçûkan', option_b = 'Zembîlfiroş', option_c = 'Dîwan', option_d = 'Leyl û Mecnûn'
where id = '98d0ab61-97ab-54cf-8911-1edf50e62d02';
-- ds_cografya_0258
update questions set
  prompt = 'Xeta Şikestekê ya Rojhilatê Anatolyayê (EAF) li kîjan herêmê bi Xeta Şikestekê ya Bakurê Anatolyayê (NAF) re digihîje hev?',
  option_a = 'Li herêma Qirlîovayê (Çewlîg)', option_b = 'Li Deşta Herranê li başûr', option_c = 'Li zozanên Cizîrê û Botanê', option_d = 'Li newala Çemê Dîcleyê li Amedê'
where id = 'd2266cf9-c32e-59c1-bbd5-fe24b64e38f5';
-- ds_cografya_0271
update questions set
  prompt = 'Çemê Muradê li gorî Çemê Qerebila (Karasu) xwedî kîjan taybetmendiya hewzeyî ya sereke ye?',
  option_a = 'Tenê di nav golên volkanîk de bêyî derketinê diherike', option_b = 'Çemekî gelekî kurt e ku tenê di havînê de ava wî heye', option_c = 'Ava xwe rasterast bêyî Firatê dirijîne Deryaya Qezwînê', option_d = 'Milê herî dirêj e û xwedî qada hewzeya herî berfireh e'
where id = '3d46a701-c1c7-57e7-a2a1-3145e729c061';
-- ds_cografya_0284
update questions set
  prompt = 'Axa bazaltî ya derdora Qerecdaxê li gorî axên din ên herêmê xwedî kîjan taybetmendiya mîneralî ye?',
  option_a = 'Ji hesin, magnezyûm û mîneralên volkanîk gelekî dewlemend e', option_b = 'Tenê ji xwêya spî û kilsa heliyayî pêk tê', option_c = 'Ti mîneralan di nav xwe de nagire û zû hişk dibe', option_d = 'Tenê ji kilsên asîdî yên avnegir ava bûye'
where id = '23f9a5f4-9182-5e0c-b470-8f0390cb2489';
-- ds_cografya_0285
update questions set
  prompt = 'Rêzeçiyayên Zagrosê çima ji bakur-rojava ber bi başûr-rojhilat ve dirêj dibin?',
  option_a = 'Herikîna avên okyanûsan ji rojava ber bi rojhilat', option_b = 'Kêmbûna zexta atmosferê ya li ser Çola Erebistanê', option_c = 'Teqîna volkanên binê deryayê li Kendava Farsê', option_d = 'Zexta Plakaya Erebistanê ya li ser Plakaya Ewrasyayê'
where id = 'cce6f321-dc09-59e2-9897-e6901ad494cc';
-- edit_cografya_0034
update questions set
  prompt = '"Zozan" û "germiyan" di jiyana koçeran de çi diyar dikin?',
  option_a = 'Riya koçberiyê û bêhnvedana rê', option_b = 'Çadira reş û konê biçûk', option_c = 'Keriyê pêz û garana dewaran', option_d = 'Warê havînê û warê zivistanê'
where id = 'dc47ba27-5546-5eba-a1ad-4bee91274ef1';
-- offline_2705
update questions set
  prompt = '"Çiyayê Sîpanê" nêzîkî kîjan golê ye?',
  option_a = 'Gola Wanê', option_b = 'Gola Egîrdîrê', option_c = 'Gola Xwê', option_d = 'Gola Beyşehîrê'
where id = 'dbe62c63-14c1-584f-a2be-e1bfd3472fc9';
-- offline_8149
update questions set
  prompt = '"Geliyê Munzurê" çi ye?',
  option_a = 'deşta keviran a ku ji lavên Karacadaxê pêk hatiye', option_b = 'geliyê bi statûya parka neteweyî ya li Dêrsimê', option_c = 'deşta çandiniyê ya mezin a ku bi çemikên Firatê tê avdan', option_d = 'çiyayê ku gola kraterê ya duyemîn a herî mezin a cîhanê lê ye'
where id = 'c86835eb-006b-553e-92b5-33c55cc68d16';
-- offline_8479
update questions set
  prompt = '"Gever (Yüksekova)" çi ye?',
  option_a = 'geliyê bi statuya parka neteweyî ya li Dêrsimê', option_b = 'deşta bi bereket a ku deştên Cizîr û Silopiyê digire', option_c = 'çemê girîng ê ku ji Êlihê derbas dibe û dirije Dîcleyê', option_d = 'deşta tektonîk a bilind a li Colemêrgê'
where id = '585d04d5-4fd7-51f0-a83d-1f1d057f3904';
-- restore_2026_08_07_0014
update questions set
  prompt = 'Bajarê Colemêrgê li kîjan parçeyê Kurdistanê ye?',
  option_a = 'Bakurê Kurdistanê', option_b = 'Rojavayê Kurdistanê', option_c = 'Başûrê Kurdistanê', option_d = 'Rojhilatê Kurdistanê'
where id = '81b3abfc-a963-5074-8c52-8fd00bea1fd7';
-- restore_2026_08_07_0015
update questions set
  prompt = 'Gola Wanê li kîjan parçeyê Kurdistanê ye?',
  option_a = 'Rojavayê Kurdistanê', option_b = 'Başûrê Kurdistanê', option_c = 'Bakurê Kurdistanê', option_d = 'Rojhilatê Kurdistanê'
where id = '8bf023ed-b657-53c9-a1e7-72b2e7c3f137';
-- edit_dirok_0005
update questions set
  prompt = 'Peymana Sevrê (1920) ji bo kurdan çima tê gotin ku girîng e?',
  option_a = 'Ji bo dewleteke kurdî ya serbixwe yekser sînor diyar kir', option_b = 'Ji bo herêmeke kurdî ya xweser madde dihewand', option_c = 'Hemû herêmên kurdî xiste bin rêveberiya yek dewletê', option_d = 'Mîrektiyên kurdî wek dewletên serbixwe nas kir'
where id = 'fc7fbf17-4924-50f3-84a2-f169c46b8e08';
-- edit_dirok_0026
update questions set
  prompt = 'Xanedaniya Merwaniyan bi giştî li ku derê hukum kir?',
  option_a = 'Amed û derdora wê', option_b = 'Silêmanî', option_c = 'Sine (Sanandaj)', option_d = 'Mezopotamyaya jorîn'
where id = '09467c0e-de48-5781-bc7c-e9222164194b';
-- offline_2227
update questions set
  prompt = 'Di vegotina Newrozê de sembola berxwedana li dijî zalimî kî ye?',
  option_a = 'Kawayê Hesinkar', option_b = 'Şerefxanê Bidlîsî', option_c = 'Serokkomarê Iraqê', option_d = 'Mîrtî'
where id = '544927f6-f987-589c-a5bd-66bb385ce2ef';
-- offline_2459
update questions set
  prompt = '"Şerefname" çi ye?',
  option_a = 'têkoşîna li dijî seferên xaçparêzan', option_b = 'Împeratoriya Medan (berî Farisan)', option_c = 'yekîneyên siwar ên ku ji eşîretan hatibûn pêkanîn', option_d = 'dîroka xanedan û mîrektiyên kurdan'
where id = '17c96fd1-0fcf-5cf9-ad0b-71ce9ea801fa';
-- offline_2638
update questions set
  prompt = 'Xanedana kurdî ya Hesenweyhî li kîjan herêmê hikim kiriye?',
  option_a = 'Qefqasya (derdora Gence-Aniyê)', option_b = 'Şerefxan (mîrê Bidlîsê)', option_c = 'tevgera neteweyî ya kurdên Iraqê', option_d = 'rojavayê Îranê / derdora Zagrosê'
where id = 'b838b9c3-9ee2-5011-bc1e-ca3007a78b74';
-- offline_2811
update questions set
  prompt = 'Di dîroka kurdî de piştî "serdema mîrektiyan" kîjan pêvajo derketiye holê?',
  option_a = 'dewleta mezin a ku Selahedînê Eyûbî damezrand', option_b = 'mîrektiya kurd a bihêz a bi navenda Silêmaniyê', option_c = 'mîrektiya kurd a girîng a bi navenda Cizîrê', option_d = 'navendîbûn û rêveberiya rasterast'
where id = 'c7684a0d-e15b-5bf1-b8cd-560d4dcfbc76';
-- offline_2826
update questions set
  prompt = '"Şerefname" ji aliyê kê ve hatiye nivîsandin?',
  option_a = 'serokê Komara Mehabadê', option_b = 'Mesûd Barzanî', option_c = 'YNK (Yekîtiya Nîştimanî ya Kurdistanê)', option_d = 'Şerefxan (mîrê Bedlîsê)'
where id = '3cb2d81a-4ee7-5d81-8c5b-c7e2d434f547';
-- offline_curated_20504
update questions set
  prompt = '"Împaratoriya Medî" çi bû?',
  option_a = 'hikûmdariya kurd a ku di serdema Osmanî de xweser mabû', option_b = 'mîrektiya bi navenda Rewandizê ya ku hêza leşkerî berhev kir', option_c = 'mîrnişîneke kevnar a kurdî ya li rojhilat ku navenda wê Sine bû', option_d = 'hêza mezin a kevnar a li çiyayên Zagrosê ku kurd xwe wekî neviyên wan dibînin'
where id = 'd236250d-67f0-5452-bb15-7f0f588c96fa';
-- ds_edebiyat_0244
update questions set
  prompt = 'Cudahiya sereke ya di navbera destana devkî ya "Memê Alan" û berhema nivîskî ya Ehmedê Xanî "Mem û Zîn" (1692) de çi ye?',
  option_a = 'Xanî çîroka gelêrî veguherandiye mesnewiyeke felsefî, tesewufî û nasnameyî', option_b = 'Xanî hemû lehengên destanê ji holê rakirine û tenê behsa şerê dîrokî kiriye', option_c = 'Memê Alan bi alfabeya latînî hatiye nivîsandin lê Mem û Zîn tenê bi devkî ye', option_d = 'Mem û Zîn tenê lîstikeke şanoyê ya nûjen e ku di sedsala bîstan de hatiye nivîsandin'
where id = '19add189-7a66-5a18-aa9d-1a4d22707bf1';
-- ds_edebiyat_0246
update questions set
  prompt = 'Kovara "Hawar" (Şam, 1932) ji aliyê sîstema nivîsînê ve li hember rojnameya "Rêya Teze" (Êrîvan, 1930) xwedî kîjan cudahiya dîrokî bû?',
  option_a = 'Hawar tenê bi zimanê fransî derket, Rêya Teze tenê bi zimanê ermenî bû', option_b = 'Her du jî bi alfabeya latînî derketin, lê Rêya Teze guhertoyeke cuda ya Sovyetî bi kar anî', option_c = 'Hawar tenê kovareke wêneyî bû, Rêya Teze qet tiştek çap nedikir', option_d = 'Her du weşanan jî tenê alfabeya erebî ya kevn a osmanî bi kar dianî'
where id = '69be4d7f-3805-5891-b6bc-698752e4b998';
-- ds_edebiyat_0248
update questions set
  prompt = 'Cegerxwîn di helbesta nûjen a kurdî de çawa rê li ber derbasbûna ji şêwaza klasîk ber bi ya civakî ve vekir?',
  option_a = 'Zimanê helbestê ji qalibên giran ên erûzê ber bi zimanê gel û têkoşîna civakî ve bir', option_b = 'Hemû cureyên helbestê qedexe kirin û tenê çîrokên zarokan nivîsandin', option_c = 'Helbest tenê bi zimanê latînî yê kevnar di nav dêran de xwend', option_d = 'Tenê behsa xwezaya Ewropayê kir û ji jiyana welat bi temamî dûr ket'
where id = '1ea2be4c-5b71-5869-a305-75e6ee313d87';
-- ds_edebiyat_0250
update questions set
  prompt = 'Nivîskar Mehmed Uzun di romanên xwe yên wekî "Siya Evînê" û "Rojek ji Rojên Evdalê Zeynikê" de kîjan peywira sereke ya edebî pêk anî?',
  option_a = 'Tenê pirtûkên felsefeya rojavayî bê guhertin wergerandin ser zimanê kurdî', option_b = 'Hemû çîrokên dengbêjan red kirin û tenê behsa teknolojiya fezayê kir', option_c = 'Tenê helbestên kurt ên bê wate ji bo zarokên biçûk amade kirin', option_d = 'Bîra dîrokî û çanda devkî bi zimanekî nûjen û estetîk kire bingeha romana kurdî'
where id = '0104f8b1-983a-5edb-85f1-caefd7c9fed1';
-- edit_edebiyat_0014
update questions set
  prompt = 'Berhema "Rewşenbîr" an kovarên edebî yên kurdî bi giştî çi rol lîst?',
  option_a = 'Berhevkirina destanên devkî yên gelêrî', option_b = 'Wergerandina berhemên klasîk bo erebî', option_c = 'Pêşxistina zimanê nivîskî yê kurdî', option_d = 'Amadekirina ferhengên dibistanê'
where id = '55ce7d63-f028-5f69-b92c-aa2e1f71c77c';
-- edit_edebiyat_0027
update questions set
  prompt = 'Rast e an şaş e: Cegerxwîn navekî edebî (nasnav) e.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = '99822a77-11a0-57e0-a4a0-0c7629a3f413';
-- offline_2119
update questions set
  prompt = 'Kovara "Hawar"ê kê derxist?',
  option_a = 'Kamiran Alî Bedirxan', option_b = 'Celadet Alî Bedirxan', option_c = 'Mela Ehmedê Xasî', option_d = 'Osman Sebrî'
where id = '8b21a6ab-bae2-5681-bb3d-8841c21e35e9';
-- offline_2122
update questions set
  prompt = 'Alfabeya Kurmancî ya Latînî kê amade kir?',
  option_a = 'Kamiran Alî Bedirxan', option_b = 'Celadet Alî Bedirxan', option_c = 'Mela Ehmedê Xasî', option_d = 'Qedrîcan'
where id = 'a2abe123-b771-5b5e-bd5f-0140185b0175';
-- offline_2787
update questions set
  prompt = 'Wêjeya devkî ya kurdî ji nifşekî bo nifşekî din kê veguhastiye?',
  option_a = 'Askerler', option_b = 'Denizciler', option_c = 'Dengbêjan', option_d = 'Ehmedê Xanî'
where id = 'be738fd5-2c16-5ced-815d-9c1418bdb063';
-- offline_9215
update questions set
  prompt = 'Kîjan cureyê vegotinê bi gelemperî kurt e û li ser bûyerekê an çend bûyeran e?',
  option_a = 'Çîrok', option_b = 'Helbest', option_c = 'Destan', option_d = 'Şano'
where id = '9230f7f0-1707-50d5-a194-242c170d559b';
-- offline_9459
update questions set
  prompt = 'Têgeha "vebêj" çi pêk tîne?',
  option_a = 'kesayeta sereke ya çîrokê', option_b = 'cihê ku bûyer tê de diqewime', option_c = 'ramana sereke ya berhemê', option_d = 'dengê ku çîrokê vedibêje'
where id = '593fbd25-9e49-5731-a04e-0358f7087ddf';
-- hat_0033
update questions set
  prompt = '"Mem û Zîn" ji aliyê cureyê edebî ve kîjan şêwe ye?',
  option_a = 'Ferheng', option_b = 'Rêziman', option_c = 'Mesnewî', option_d = 'Bîranîn'
where id = 'e3eb6c85-e38f-5429-9220-f8afbab12693';
-- offline_curated_20375
update questions set
  prompt = 'Cegerxwîn di helbesta kurdî de bi çi tê naskirin?',
  option_a = 'helbestvanê ku Mewlûda Kurdî ya yekem bi zaravayê kurmancî nivîsiye', option_b = 'rêbaza helbesta nûjen a bê pîvan û bê qafiye ku bi taybetî li ser peyvan ava dibe', option_c = 'helbestvanê mezin ê klasîk ku bi dîwana xwe ya felsefî û tesewifî tê naskirin', option_d = 'helbestvanê şoreşger û civakî yê ku helbesta kurdî ya modern biriye qonaxeke nû'
where id = '86d45d6f-a690-58df-93ed-b0557ab297a5';
-- offline_tf_ede_0024
update questions set
  prompt = 'Rast e an şaş e: "qafiye" lihevhatina dengên dawiya rêzan e ku rîtmê dide helbestê.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'eee41fe4-fbfe-5716-a324-0abbeec7852a';
-- offline_tf_ede_0025
update questions set
  prompt = 'Rast e an şaş e: "qafiye" vegotina dirêj e ku lehengî û bîra komî ya gelekî hildigire.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = '18b8c5a7-d76e-5462-890d-a74b4e875f9b';
-- hat_0036
update questions set
  prompt = 'Bernavê Yilmaz Guney ê herî naskirî kîjan e?',
  option_a = 'Qralê Kirêt', option_b = 'Qralê Mezin', option_c = 'Qralê Spî', option_d = 'Qralê Ciwan'
where id = '16476150-e023-5cf7-9ef6-db51fc512c8e';
-- hat_0038
update questions set
  prompt = 'Dema Yilmaz Guney girtî bû, kişandin û derhêneriya fîlmê Yol kê kir?',
  option_a = 'Zeki Okten', option_b = 'Atif Yilmaz', option_c = 'Halit Refig', option_d = 'Şerif Goren'
where id = '0a6c4ac7-8c82-5ee8-8f7a-54bf9de797ef';
-- edit_muzik_0001
update questions set
  prompt = '"Dengbêj" kî ye?',
  option_a = 'hunermendê gelêrî yê klasîk ê populer ê herêma Behdînan', option_b = 'stranbêja yekem a kurd ku dengê xwe li ser plakan tomar kiriye', option_c = 'cureyê muzîkê yê ku bêtir li ser evîn û mêrxasiyê tê gotin', option_d = 'Stranbêjê devkî yê ku çîrokan bi kilaman dibêje'
where id = '896ddb0a-ca48-5407-be00-a11d45dc3495';
-- edit_muzik_0008
update questions set
  prompt = '"Lawik" di muzîka kurdî de bi giştî çi ye?',
  option_a = 'Yek ji dengên jin ên pêşeng ên muzîka kurdî ye', option_b = 'Belavbûna cîhanî ya stran û tomarkirinê', option_c = 'Cureyekî kilamê yê bi gelemperî evîndar', option_d = 'Bi tiliyan an bi mizrabê'
where id = '0371d73d-ca0d-55dc-99cf-132a03b72b2f';
-- edit_muzik_0023
update questions set
  prompt = 'Di muzîka kurdî de "meqam" an "avaz" çi diyar dike?',
  option_a = 'Hejmara stranbêjan', option_b = 'Dirêjahiya dawetê', option_c = 'Navê amûrê', option_d = 'Qalibê dengî yê stranê'
where id = 'd1762212-4e25-5cc0-bf5c-e9225ed77b8d';
-- edit_muzik_0025
update questions set
  prompt = 'Di kilamên dengbêjan de "vegotin" çima girîng e?',
  option_a = 'Tenê ahenga dengî girîng e', option_b = 'Reqs pê re tê kirin', option_c = 'Amûr pê re tên lêxistin', option_d = 'Kilam çîrokeke dîrokî diguhêzîne'
where id = 'f1ae8d02-3ffe-5c2b-9c0d-86a7875709cc';
-- edit_muzik_0027
update questions set
  prompt = 'Di muzîka kurdî ya nûjen de "kom" çi ye?',
  option_a = 'Bûyerên şer û berxwedanê', option_b = 'Stranên kurt ên bi gelemperî evîndar', option_c = 'Kilam çîrokeke dîrokî diguhêzîne', option_d = 'Koma stranbêj û muzîkjenan'
where id = '6eee6d0d-3636-5701-8498-a6da5c3a5f83';
-- edit_muzik_0031
update questions set
  prompt = 'Muzîka kurdî ya diasporayê bi giştî çi bandor kir?',
  option_a = 'Komên muzîka kurdî ya nûjen', option_b = 'veguhastina muzîkal a bi têkiliya hoste-şagird', option_c = 'Belavbûna cîhanî ya stran û tomarkirinê', option_d = 'muzîka rîtmîk û meqamî ya herêma Şirnex û Cizîrê'
where id = '4beac4a5-b058-5533-9ddd-56acaace8a54';
-- ex28_nujen_013
update questions set
  prompt = 'Grûpa Kardeş Türküler di sala 1993an de ji aliyê xwendekarên kîjan zanîngehê ve hate damezrandin?',
  option_a = 'Zanîngeha Boğaziçiyê', option_b = 'Zanîngeha Enqereyê', option_c = 'Zanîngeha Dîcleyê', option_d = 'Zanîngeha Teknîkî ya Stenbolê'
where id = '272611e7-f47f-58de-b5ae-f711deec7639';
-- offline_10314
update questions set
  prompt = '"awazên Serhedê" çi ne?',
  option_a = 'muzîka rîtmîk û meqamî ya herêma Şirnex û Cizîrê', option_b = 'şêwaza muzîka lîrîk a taybetî ya herêma Qersê, Agirî û Wanê', option_c = 'dengbêjê bi eslê xwe ermenî yê ku muzîka devkî ya kurdî berhev kir', option_d = 'hunermendê rîtmê yê ku erbane an defê bi hostatî lê dide'
where id = 'b6180e9e-1460-56fd-b07f-409fcd93dc3c';
-- offline_10423
update questions set
  prompt = '"tembûr" çi ye?',
  option_a = 'şêwaza muzîka lîrîk a taybetî ya herêma Qersê, Agirî û Wanê', option_b = 'sazê têlî yê ku di kevneşopiya Yarsan/Ehlê Heq de pîroz tê hesibandin', option_c = 'amûra pifê ya bi dengê bilind a ku li derve tê lêxistin', option_d = 'hunermendê rîtmê yê ku erbane an defê bi hostatî lê dide'
where id = 'e7333f15-0ae5-594e-b3be-366230238b4b';
-- offline_10813
update questions set
  prompt = '"kevneşopiya şabaşê" çi ye?',
  option_a = 'edeta ku ji muzîkjenan re pere tên avêtin', option_b = 'veguhastina muzîkal a bi têkiliya hoste-şagirt', option_c = 'dengê bihêz ê ku kurd jê re dibêjin "şahê dengbêjan"', option_d = 'kilama kevneşopî ya navdar a ku efsaneyekê vedibêje'
where id = '1d460377-37ec-5152-baa9-9436757d7e35';
-- offline_10878
update questions set
  prompt = '"Kardeş Türküler" çi ye?',
  option_a = 'muzîka devkî ya ku di şevbihêrkên zivistanê de tê gotin', option_b = 'koma ku muzîka kurdî di hawîrdoreke pirçandî de pêşkêş dike', option_c = 'stranbêjî an lêxistina bi tenê ya hunermendekî', option_d = 'muzîka rîtmîk û meqamî ya herêma Şirnex û Cizîrê'
where id = '050cca2a-e567-568d-8846-d8f01ad565d4';
-- offline_10926
update questions set
  prompt = '"Mihemed Şêxo" kî bû?',
  option_a = 'dengbêjê ku tomarên destpêkê yên muzîka kurdî kirin', option_b = 'koma ku muzîka kurdî di hawîrdoreke pirçandî de pêşkêş dike', option_c = 'dengbêjê ku hestên neteweyî yên gelê kurd dianî ziman', option_d = 'amûra pifê ya bi dengê bilind a ku li derve tê lêxistin'
where id = '59bfeddd-0c33-5014-9534-3dfbbe134c72';
-- offline_11180
update questions set
  prompt = 'Têgeha "meqamê dengbêjan" tê çi wateyê?',
  option_a = 'şêwaza dengî ya bi rîtma azad a ku kilam pê tên gotin', option_b = 'muzîkjenê şoreşger ê hezkirî yê herêma Behdînan', option_c = 'şêwaza muzîka lîrîk a taybetî ya herêma Qersê, Agirî û Wanê', option_d = 'stranbêjî an lêxistina bi tenê ya hunermendekî'
where id = '83665086-049e-51aa-ae63-163adde0d5bb';
-- offline_curated_21376
update questions set
  prompt = 'Yek ji stûnên muzîka klasîk ên ku kilamên devera Botanê tomar kirine kî bû?',
  option_a = 'Meryem Xan', option_b = 'Hesen Cizrawî', option_c = 'heyran', option_d = 'lawik'
where id = 'd72e8f29-7c93-5925-81c2-92e35fccad60';
-- offline_curated_21475
update questions set
  prompt = 'Di muzîka kurdî de taybetmendiya kilamên bi navê "heyran" çi ye?',
  option_a = 'amûra têldar a ku di kevneşopiya Yarsan/Ehlê Heq de pîroz tê hesibandin ku bi taybetî di civatên olî de tê lêdan', option_b = 'klamên evînê yên devera Serhadê ku bi taybetî ji aliyê jinan ve dihatin gotin', option_c = 'stranbêja yekem a kurd ku dengê xwe li ser plakan tomar kiriye', option_d = 'yek ji stûnên muzîka kurmancî ya klasîk ku kilamên devera Botanê tomar kirine'
where id = 'bb4d417e-241e-504f-ab15-882fe1ddb986';
-- restore_2026_08_07_0012
update questions set
  prompt = 'Cudahiya sereke ya di navbera kilamê û stranên govendê de çi ye?',
  option_a = 'Kilam bi zirneyê tê gotin, stranên govendê bêdeng in', option_b = 'Kilam çîrokê vedibêje, stranên govendê rîtmî ne', option_c = 'Kilam tenê ji hêla jinan ve tê gotin', option_d = 'Kilam tenê di dawetan de tê gotin'
where id = '7a17b4bf-65ee-5ae6-9f52-92df9234d23d';
-- offline_11597
update questions set
  prompt = 'Bi "rexneya patriyarkayê" çi tê xwestin?',
  option_a = 'federasyoneke ne-dewletgir a li ser bingeha binî', option_b = 'rolên çêkirî yên ku civakê ji jin û mêr re diyar kirine', option_c = 'eşkerekirina avahiya pergala serdestiya zilaman', option_d = 'yek pirrengî-dilxwazî ye, ya din yekreng-mecbûrî ye'
where id = '7b26ded7-27b6-5ce7-817d-e027b96677b5';
-- offline_11957
update questions set
  prompt = 'Dema "zayenda civakî" tê gotin, çi tê xwestin?',
  option_a = 'krîza navendîbûna aborî û siyasî ya destekî yekane', option_b = 'sîstema jiyanê ya alternatîf a modernîteya kapîtalîst', option_c = 'rolên çêkirî yên ku civakê ji jin û mêr re diyar kirine', option_d = 'pergaleke civakî ku zilamî serdest dike û jinê tepeser dike'
where id = 'd7d0cb69-399a-55ac-b1f1-316565247d35';
-- offline_12122
update questions set
  prompt = 'Derbarê "patriyarka" de vebijêrka rast kîjan e?',
  option_a = 'pergaleke civakî ku zilamî serdest dike û jinê tepeser dike', option_b = 'nîzameke wekhev a bêyî serdestî û mêtinkirinê', option_c = 'li seranserê cîhanê bûye sembola azadiya jinê', option_d = 'prensîbeke wekhevîxwaz a li dijî tepeserî û cudakariya zayendî'
where id = '070752cc-ae4d-565c-a6b2-af697ee89cad';
-- offline_2682
update questions set
  prompt = '"Civaka Ekolojîk" ji civaka pîşesaziyê bi kîjan aliyî ve cuda dibe?',
  option_a = 'Ji ber ku xwezayê tenê wek tiştekî mêtinkirinê nabîne', option_b = 'Geşkirina hişmendiya civakî û ramana azad', option_c = 'Li seranserê cîhanê bûye sembola azadiya jinê', option_d = 'Mafê civakê yê xweparastin û xwerêxistinê'
where id = 'd98d7c23-daca-5618-a097-8b06bbf11463';
-- offline_12882
update questions set
  prompt = 'Derbarê "pêvajoya aştiyê" de vebijêrka rast kîjan e?',
  option_a = 'qonaxa bidawîkirina rewşa pevçûnê bi diyalogê', option_b = 'mafê parastinê li dadgehên serbixwe û bêalî', option_c = 'hêzê ji navendekê bo yekîneyên herêmî belavkirin', option_d = 'pergaleke ku jin di partiyan de wekhev xwedî deng in'
where id = '8f1c2fe4-68b1-5aae-b8fd-0ef7a54c20ea';
-- offline_13040
update questions set
  prompt = 'Ji bo "mafên hindikahiyan" ravekirina herî dirust kîjan e?',
  option_a = 'parastina komên ku ji piraniyê cuda ne', option_b = 'platforma hevbeş a aştiyê ya komên muxalif ên cuda', option_c = 'îradeya çareserkirina pevçûnan bi diyalogê li şûna çekan', option_d = 'hêzê ji navendekê bo yekîneyên herêmî belavkirin'
where id = 'e953efd8-6f54-5ea2-a72d-d61c0ece7c4a';
-- offline_13390
update questions set
  prompt = 'Derbarê "meşrûiyet" de ya rast a zanîn çi ye?',
  option_a = 'guncaniya rêveberiyê bi razîbûna gel û hiqûqê re', option_b = 'banga danîna çekan û hilweşandina avahiya rêxistinî', option_c = 'prensîba parvekirina wekhev a çavkanî û mafan', option_d = 'parastina komên ku ji piraniyê cuda ne'
where id = 'f521a0f8-18f7-56dc-9575-05b08d2fa9e5';
-- offline_tf_siy_0020
update questions set
  prompt = 'Binirxîne: li gorî vê ravekirinê "muxalefeta civakî" ev e — redkirina eşkere û bêşîdet a qanûneke ku neheq tê dîtin. Rast e an şaş e?',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'a2cd1ed2-4317-5286-b841-e38ea4d84488';
-- offline_tek_0009
update questions set
  prompt = 'Çima girêdanên bêtêl ji yên bi kablo bêtir hewceyî şîfrekirinê ne?',
  option_a = 'Ji ber ku girêdanên bêtêl her tim hêdîtir dixebitin', option_b = 'Ji ber ku amûrên bêtêl kêmtir enerjiyê xerc dikin', option_c = 'Ji ber ku sînyal li hewayê belav dibe û herkes dikare bigire', option_d = 'Ji ber ku kabloyên wan ji yên din kurttir tên çêkirin'
where id = 'ac709ea0-c523-5a80-a1b4-ccb8d8677363';
-- offline_tek_0028
update questions set
  prompt = 'Wêneyek bi çareseriya bilind her tim kêmtir cih digire.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'e404770e-4a58-54da-942e-56ff4899c418';
-- offline_tek_0041
update questions set
  prompt = 'Di bernamesaziyê de "algorîtma" bi giştî çi ye?',
  option_a = 'Zimanek ji bo nivîsandina bernameyan', option_b = 'Hêmaneke dîtbarî ya li ser ekranê', option_c = 'Rêbazek bi gavên diyarkirî', option_d = 'Pergalek ji bo hilanîna daneyan'
where id = '571f75c7-e506-5d42-b67c-b4a96fa9c111';
-- offline_tek_0085
update questions set
  prompt = 'Dema tu li malperekê digerî, "cookie" çi dike?',
  option_a = 'Girêdana înternetê bileztir û bêtêl dike', option_b = 'Şîfreyên te yên hesaban diguherîne û nû dike', option_c = 'Hemû reklaman ji rûpelên malperan radike û paqij dike', option_d = 'Agahiyên gera te li ser amûrê tomar dike'
where id = '6f287e0b-b1cc-58b7-83cc-be9e25648976';
-- offline_tek_2013
update questions set
  prompt = 'Yekîneya "wat" di jiyana rojane de çi dide zanîn?',
  option_a = 'Hêza ku amûrek xerc dike', option_b = 'Giraniya amûrê li ser mêzînê', option_c = 'Dirêjahiya kabloya amûrê', option_d = 'Dema ku amûr dixebite'
where id = 'a2af74aa-952a-5ec8-b3c9-4ff62edeed39';
-- offline_tek_2014
update questions set
  prompt = 'Amûreke ku vemirandî ye lê kabloya wê hîn jî girêdayî ye bi tu awayî elektrîkê naxwe.',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = '8e7cda6a-8ec8-561a-b62d-f7b447296032';
-- sf_tech_0012
update questions set
  prompt = 'Li gorî rêbernameya nû ya NISTê, tîpên taybet mecbûr in?',
  option_a = 'Na, êdî mecbûrî nayên pêşniyarkirin', option_b = 'Erê, her dem mecbûr in', option_c = 'Tenê ji bo bankan mecbûr in', option_d = 'Tenê ji bo e-nameyê mecbûr in'
where id = '860992af-40be-5316-840b-9ef8c3bbb69c';
-- sf_tech_0014
update questions set
  prompt = 'Çima bikaranîna heman şîfreyê li gelek malperan xeternak e?',
  option_a = 'Ji ber ku malper dikarin bi heman şîfreyê hêdîtir bibin', option_b = 'Ji ber ku şikandina yek hesabî dikare hesabên din jî bixe xetereyê', option_c = 'Ji ber ku bikaranîna şîfreyekê li gelek cihan bîranîna wê dijwartir dike', option_d = 'Ji ber ku bikaranîna heman şîfreyê trafîka înternetê zêde dike'
where id = '625559d2-089c-5db1-8861-1cc95dcac661';
-- tech_core_0016
update questions set
  prompt = 'Paşgira pelê (wek .txt an .jpg) bi giştî çi diyar dike?',
  option_a = 'Mezinahiya pelê bi bayt, kîlobayt an megabaytan', option_b = 'Dîroka çêkirina pelê', option_c = 'Cureya naverokê û bernameya ku wê vedike', option_d = 'Cihê ku pel lê hatiye hilanîn'
where id = '9c166f62-2ac2-5a91-954a-fbf5bdb516dc';
-- tech_core_0026
update questions set
  prompt = '"Cookie" di gerokê de bi giranî ji bo çi tê bikaranîn?',
  option_a = 'Ji bo bîranîna rewşa bikarhêner', option_b = 'Ji bo zêdekirina leza pêvajokerî', option_c = 'Ji bo şîfrekirina trafîka ku di torê re derbas dibe', option_d = 'Ji bo çapkirina rûpelan'
where id = 'fc069fd1-65a8-58f1-aebd-74fc63e7033f';
-- tech_core_0044
update questions set
  prompt = 'Rîsk di tora Wi-Fi ya giştî de çi ye?',
  option_a = 'Kesên din dikarin trafîka neşîfrekirî bibînin', option_b = 'Bataryaya amûrê zû diqede', option_c = 'Pelên li ser dîskê bixweber tên jêbirin', option_d = 'Ekran hêdî hêdî tarî dibe'
where id = '72ca0545-96c0-55e8-ad48-45f926162ba1';
-- tech_core_0045
update questions set
  prompt = 'Kîjan nîşan e-nameyekê gumanbar dike?',
  option_a = 'Bikaranîna zimanekî fermî', option_b = 'Hebûna logoya saziyê', option_c = 'Şandin di roja xebatê de', option_d = 'Daxwaza lezgîn a tikandina girêdanekê'
where id = 'ad1111a2-e5a0-5d48-b5c6-62f6826b77d6';
-- tech_core_0052
update questions set
  prompt = 'Çima divê kopiya ewlehiyê dem bi dem bi vegerandinê bê ceribandin?',
  option_a = 'Ji ber ku pelên di kopiyê de bi demê re mezintir dibin', option_b = 'Ji ber ku şîfre her mehê diguhere', option_c = 'Ji ber ku dîsk bi ceribandinê zûtir dibe', option_d = 'Ji ber ku kopiyeke xerabûyî tenê hingê xuya dibe'
where id = '928f3928-ac9b-5ee9-b7ec-d38f885a0096';
-- tech_invent_0001
update questions set
  prompt = 'Di derdora sala 1450an de li Ewrûpayê makîneya çapê ya bi tîpên livok kê pêş xist?',
  option_a = 'Johannes Gutenberg', option_b = 'Nicolaus Copernicus', option_c = 'Isaac Newton', option_d = 'Leonardo da Vinci'
where id = '08463ac0-ae76-5ba9-adeb-626929ed5f96';
-- tech_invent_0017
update questions set
  prompt = 'Motora elektrîkê enerjiya elektrîkê vediguherîne kîjan cure enerjiyê?',
  option_a = 'Enerjiya kîmyewî', option_b = 'Enerjiya ronahiyê', option_c = 'Enerjiya nukleerî', option_d = 'Enerjiya mekanîkî'
where id = '174047d3-f77b-5ff6-ac5f-bbb253d0e648';
-- tech_invent_0031
update questions set
  prompt = 'Li gorî qanûna parastina enerjiyê, di pergaleke girtî de enerjî çi dibe?',
  option_a = 'Bi demê re kêm dibe', option_b = 'Tenê şiklê xwe diguherîne', option_c = 'Bi demê re zêde dibe', option_d = 'Bi demê re bi tevahî ji holê radibe'
where id = '19e393da-b6ac-542c-a084-94b15393e6e6';
-- tech_invent_0036
update questions set
  prompt = 'Panela rojê ronahiya rojê rasterast vediguherîne çi?',
  option_a = 'Enerjiya kîmyewî ya hilanînê', option_b = 'Enerjiya nukleerî', option_c = 'Enerjiya dengî', option_d = 'Enerjiya elektrîkî'
where id = '0f93976d-0e73-5d93-b2b9-ac79fa3974f1';
-- tech_invent_0050
update questions set
  prompt = 'Qereqola Fezayê ya Navneteweyî gera li dora Erdê di çend deqîqeyan de diqedîne?',
  option_a = 'Nêzîkî 12 saet û nîv', option_b = 'Nêzîkî 90 deqîqe', option_c = 'Nêzîkî 24 saet', option_d = 'Nêzîkî 8 deqîqe'
where id = '42877b59-daa0-5118-af64-e79b057b22ef';
-- tech_invent_0054
update questions set
  prompt = 'Du sondeyên Voyager ku di sala 1977an de hatin şandin, wekî armanca sereke ber bi kîjan cismên ezmanî ve çûn?',
  option_a = 'Gerstêrkên dêw ên derve', option_b = 'Gerstêrkên hişk ên hundir', option_c = 'Asteroîdên kembera navîn', option_d = 'Kometên demdirêj'
where id = 'bbce3fbc-299e-5f7c-9d15-4f59667928da';
-- offline_2241
update questions set
  prompt = 'Di xebatên naskirina axaftina kurdî de projeya Jira di kîjan qadê de wek mînak tê nîşandan?',
  option_a = 'Korpusa dengî û pergala tîpguhêziyê ya Kurmancî', option_b = 'Korpusa dengî û pergala naskirinê ya Kurdiya Navîn', option_c = 'Korpusa nivîskî û pergala wergerê ya Zazakî', option_d = 'Korpusa dengî û pergala sentezê ya Hewramî'
where id = 'f24a54ca-36fd-5d91-8eec-bdbf9dd44950';
-- offline_2599
update questions set
  prompt = 'Di Kurmancî de peyva "mast" kîjan xwarinê nîşan dide?',
  option_a = 'Madeya şîrîn a ku mêşhingiv çêdikin', option_b = 'Xwarina hişk a ku ji şîr tê çêkirin', option_c = 'Rûnê ku ji şîr tê derxistin', option_d = 'Xwarina şîrî ya bi tirşandinê tê çêkirin'
where id = 'c19c0e55-1ef6-50da-b2fc-08a07ad0c0f4';
-- offline_5188
update questions set
  prompt = 'Wateya peyva "kaxez" bi tirkî çi ye?',
  option_a = 'kağıt', option_b = 'here!', option_c = 'doğru', option_d = 'yazmak'
where id = 'e7b43ce4-77a0-5298-bac1-19a00d158652';
-- offline_5270
update questions set
  prompt = '"sevmek" bi Kurmancî çi ye?',
  option_a = 'xwarin', option_b = 'bihîstin', option_c = 'rêvebirin', option_d = 'hezkirin'
where id = '70e8412a-6f18-566a-8f75-1f5b7e29877a';
-- ziman_x_0006
update questions set
  prompt = 'Ji du peyvên cuda yên bi heman wateyê re çi tê gotin?',
  option_a = 'Dijwate', option_b = 'Hevwate', option_c = 'Hevdeng', option_d = 'Peyva deynkirî'
where id = 'db341440-42f2-5009-bced-69bc4cd922fb';
-- ziman_x_0008
update questions set
  prompt = 'Kîjan hevok wateya "Ekmeği yedim" bi rêzimanî rast dide?',
  option_a = 'Ez nan xwar', option_b = 'Min nan xwar', option_c = 'Ez nan dixwim', option_d = 'Min nan dixwe'
where id = '1364b4a0-45b8-5fe7-914a-2fb1d852be9b';
-- cinema_0010
update questions set
  prompt = 'Dîmenek ku bêyî qutkirinê bi kişandineke domdar tê tomarkirin, çawa tê binavkirin?',
  option_a = 'Montaja paralel', option_b = 'Plan-sekans', option_c = 'Fondu', option_d = 'Qutkirina xwerû'
where id = 'fadabce3-5283-5a09-abf6-4763b3bdd5ae';
-- ds26_cinema_0035
update questions set
  prompt = 'Têgeha ku hemû hêmanên dîtbarî yên li ber kamerayê (dekor, ronahî, lîstik) di çarçoveyekê de berhev dike çi ye?',
  option_a = 'sînematografî', option_b = 'montaj', option_c = 'senaryo', option_d = 'mise-en-scène'
where id = '7cb87bb6-ee0a-5112-baab-764d28e79923';
-- edit_sinema_0025
update questions set
  prompt = 'Fîlmê "Sürü" (1978) ji hêla kîjan derhênerî ve hatiye kişandin?',
  option_a = 'Şerîf Gören', option_b = 'Zeki Ökten', option_c = 'Atif Yilmaz', option_d = 'Ömer Lütfi Akad'
where id = '17e7cfdf-b172-5249-abec-95ff56b3e787';
-- offline_5168 (onaysız satır)
update questions set
  prompt = 'Wateya Tirkî ya "kûçik" "kedi" ye?',
  option_a = 'Rast', option_b = 'Şaş', option_c = '-', option_d = '-'
where id = 'f6bb9c14-bca6-46d2-b785-98b31ae02963';
-- hat_0063
update questions set
  prompt = 'Kîjan gol li Bakurê Kurdistanê gola sodayî ya herî mezin e?',
  option_a = 'Gola Urmiyeyê', option_b = 'Gola Wanê', option_c = 'Gola Sewanê', option_d = 'Gola Dukanê'
where id = '4098e5a6-f237-51f5-85c8-c235b51d3a94';
-- hat_0077
update questions set
  prompt = 'Kîjan av li nêzî Zaxo û Silopiyê derbas dibe û beşek ji sînorê di navbera Iraq û Tirkiyeyê de pêk tîne?',
  option_a = 'Xabûr', option_b = 'Firat', option_c = 'Mirad', option_d = 'Aras'
where id = '0b19ca83-8918-5b9c-bdd0-0b5ace3c9376';
-- hat_0078
update questions set
  prompt = 'Kîjan rêzeçiyayê dirêj ji Rojhilatê Kurdistanê heta Başûr û Loristanê dirêj dibe?',
  option_a = 'Zagros', option_b = 'Toros', option_c = 'Pontos', option_d = 'Elburz'
where id = '562b9ef7-b62d-531b-8075-4f55366c3b6f';
-- bosluk_0016
update questions set
  prompt = 'Johann Sebastian Bach, di sala 1721an de Şeş Konsertoyên Brandenburgê diyarî kê kirin?',
  option_a = 'Leopold, Mîrê Anhalt-Köthenê', option_b = 'Christian Ludwig, Margrafê Brandenburg-Schwedtê', option_c = 'Wilhelm Ernst, Dukê Saxe-Weimarê', option_d = 'Friedrich Wilhelm I, Qralê Prusyayê'
where id = '32928a95-3481-59bc-a089-dd89683f56b4';
-- bosluk_0020
update questions set
  prompt = 'Di sala 1847an de li Nexweşxaneya Giştî ya Viyanayê, kîjan bijîşkî ji bo kêmkirina rêjeya mirina dayikan destşûştina bi kilsa klorî ferz kir?',
  option_a = 'Ferdinand von Hebra', option_b = 'Carl von Rokitansky', option_c = 'Ignaz Semmelweis', option_d = 'Theodor Billroth'
where id = '36b102e8-b869-572e-a7ae-ee355faf2960';
-- bosluk_0022
update questions set
  prompt = 'Albert A. Michelson û Edward W. Morley ezmûna eterê di kîjan salê de pêk anî?',
  option_a = '1879', option_b = '1887', option_c = '1895', option_d = '1905'
where id = '7d64cd70-8912-54e1-a40f-73a212bcc487';
-- bosluk_0026
update questions set
  prompt = 'Barry Marshall û Robin Warren di sala 2005an de Xelata Nobelê ya Tibê ji bo keşfa kîjan bakteriyê wergirt?',
  option_a = 'Helicobacter pylori', option_b = 'Mycobacterium tuberculosis', option_c = 'Salmonella typhi', option_d = 'Streptococcus pneumoniae'
where id = '22124204-0ebb-5f37-854a-64fbfe152e9b';
-- bosluk_0030
update questions set
  prompt = 'Di Magna Cartaya ku di sala 1215an de ji aliyê Qral John ve li Runnymedeyê hat morkirin de, hat diyarkirin ku tu mirovê azad bêyî pêvajoyeke qanûnî nayê girtin û bêyî biryara dadgehê jî dest nayê danîn ser mal û milkê wî. Ev prensîb di kîjan xala belgeyê de cih digire?',
  option_a = 'Xala 61ê', option_b = 'Xala 39an', option_c = 'Xala 40ê', option_d = 'Xala 12an'
where id = 'b36be6ef-67df-5ac9-b52d-b59c7b369a3b';
-- bosluk_0041
update questions set
  prompt = 'Di dîroka siyasî ya Çekoslovakyayê de, serokê Partiya Komunîst ê ku di Bihara Pragê ya 1968an de dest bi reforman kir kî bû?',
  option_a = 'Gustáv Husák', option_b = 'Alexander Dubček', option_c = 'Antonín Novotný', option_d = 'Ludvík Svoboda'
where id = 'e96e6b8a-e020-56c6-adf7-9b94eb3fdd45';
-- offline_0005 (onaysız satır)
update questions set
  prompt = 'Di wêneyê ku têgeha "av" nîşan dide de, wateya rast kîjan e?',
  option_a = 'ateş', option_b = 'ben', option_c = 'ev', option_d = 'su'
where id = 'a44e5412-6189-4b42-8d25-435da95e1836';
-- offline_2464 (onaysız satır)
update questions set
  prompt = '"Semsûr" navê Kurdî yê kîjan bajarî ye?',
  option_a = 'Malatya', option_b = 'Antep', option_c = 'Mereş', option_d = 'Adıyaman'
where id = 'ad23634e-d299-4847-9280-7e38bd7e6894';
-- varyant satır (şıkları yerelden farklı): yalnız soru metni
update questions set
  prompt = 'Ji cihê ku dengbêj lê dicivin û distirin re çi tê gotin?'
where id = 'b792b4fd-2035-44e2-a60b-a18efc277e58';

do $$
declare v_count integer;
begin
  select count(*) into v_count from questions where id in ('4db422af-49fc-5803-b00f-5643d5bc026f', 'b1d496d1-92e2-53cf-a2ee-bd0e74dab455', '794b3b2e-5429-5bed-b97f-f8ad1698c9bd', 'ed612456-efe0-5c05-bef9-d101e5224340', '00751d41-1f57-5cab-ae8b-cf50eea625b1', 'c4db8369-94ba-500a-a652-ddd44ad668c0', '3c0d302a-6910-55bd-8d1b-6cb5ed2c7fca', 'f56925d4-c278-526f-9954-445e9858a610', 'af127357-98e4-5a24-b744-26bf16dbe9d2', '1259a721-ad64-5c9e-a092-d2dd9915be39', '4bc71631-b320-5e9d-b679-31d8e6a4fe9f', 'a91521ed-0207-579b-ad11-d6e8d55c2147', '71acf05d-9c50-54ac-9cd5-20e5765c3551', 'd38e75cf-e952-5f58-883e-a0e2da9e6f22', '1f45591d-b69f-5ad0-96b1-7163716b88d5', 'c328b55c-bc2a-528b-81df-8ad516d4b7b7', '3c91f2a0-1f8e-5286-9301-32d46a95390d', '0166937a-d6ed-5c76-9b2a-65853f8b2796', '5877f966-83b4-582c-b087-d24c8f4fd83e', '17811d1e-1b4e-5a45-a0af-b8c65df1b7df', 'c79d3fde-67a6-569e-b340-a89c68a462e1', '43cc1d7a-4f3c-5c02-9560-2521b7c899b4', 'f52a52d0-88e6-5f90-b92d-cd1d5543cfb2', '5fc5a920-d2ad-538c-ad1f-bda3912d7efe', '9189ac1c-90ea-525f-99b1-09c6a2ef768c', 'a8ecc3d3-e9b4-5fe4-af91-1fda0bf66e22', '24095062-b16c-5a69-ad74-b5fe08ff0bf2', 'ad9ed9c3-7bd4-5f4e-b544-b97f5e543c40', '584efcb9-430f-5484-aaf0-498e17607102', '02271365-aad0-5007-bf4d-299b8d5585dd', '800f31a6-0629-5d38-96ed-6fa28d1aab28', 'cd31ea74-df42-55e0-b53c-a45f4d4e208c', '40d4890c-ca73-59b1-890b-6d566903c5b0', '220625d0-5c90-56e8-b60f-6549c94891f9', 'e0388c7a-13af-584a-b9c9-e6892e17af0b', '1c2ab438-fb2a-53d5-8bb2-238761adbeaa', 'd33a9a6f-66a3-567f-b4e3-38a719f4bcdc', 'f4e67d62-aea8-56a1-88e8-878db7b034d9', 'f9b4fa8d-8e7f-5a39-beb1-24a7474c8f31', 'e7209b84-ecbd-5a38-ab04-d20819015efe', '4e908073-e1c3-514b-ae24-cb4680160fae', '0b3b9e14-98c8-59d6-8d2a-8bd95ff6b7fb', 'ad0433a8-baa8-5443-b73f-25aebad68894', 'b1b8da44-4a25-51ff-bfd9-dea26534d63c', '17f69e3a-db8d-5c4b-89f7-19e35fc0cd7d', 'bbd5e4c2-e35b-54e3-b83e-3ff9d14bb42d', 'e78fd90d-226f-5460-9d05-3bfed4e9d9bd', 'e5aef09f-99f6-5b7c-96ae-01770cad7b61', '7a6df1c9-db0b-500d-b625-e5cc7dd48695', '95ba436f-2297-5000-8b11-2eb40d214194', '3d8290c9-c0b4-5ad6-b865-fd7e6f406503', 'ef102015-eec4-5b43-9743-55fd7c731245', 'e7d783a9-0429-5549-ac42-fc16bde666ef', 'c72adbfe-b686-5127-b698-f1c4b75091fb', 'd475db53-8a48-5db3-8538-959b81f6e614', '7159567c-1b58-54cc-9c8c-54acf26bb2e5', 'af075713-3552-5cb7-b7be-85c03db21600', '03cc8178-6eff-437e-93bb-d9e72028d44c', '112b4e63-95c6-5a17-90c0-d977dd9f4fa8', '9c55286b-ced6-58e7-b6f1-0fc908690260', '64dcba5a-8ba0-51a4-8bea-76c7c232a638', '72db9f13-975b-5320-8b8a-e4d7fee684f9', '627f231d-6631-5dcd-bacf-597bca487fc1', '7a5eedf4-7cca-5f3a-89de-e0dd9a2ca188', 'a4b7f40f-be04-5029-a3eb-770684423a11', '5bdba7f8-3cc3-531b-b7b9-68b76fc71985', '986d3d29-c69b-5d1c-9956-ee98728c0d24', '9809962a-b3a5-551f-a235-3a241d253c38', '38d1f4f1-1fb7-552f-a413-feb028c0fa66', '76b21777-ea92-53ec-99ae-1af55d324709', '75a16595-2f12-56aa-a282-4c46111d4ed7', '19457564-c373-5454-90d5-dc24d467a6c5', '8ff42f09-4656-54a4-a19f-0c38caa316d3', '19c70c70-476b-532c-addd-9d316f91e762', 'e349ecd8-9301-5b01-98cf-1fe18a50f0eb', '7c5870e6-fa26-5485-b99f-c969b4417067', 'f156d457-ab69-5fa6-9532-74617cf12f25', 'd2ef3893-885a-5c08-b7ca-3f9ce18680b0', 'e853b70e-552c-5dd3-9458-90c5ac6c8191', '7be094a2-7d60-5722-a6ba-fd7292b074e3', '9dcff32a-0635-5fe6-a4ab-5408a57fe5a4', '6bfb9a9f-6c16-554d-892f-e03072225df9', '50f611fc-a806-50f8-a3a4-8230dd63094e', '5ecf5ab2-a5f5-5237-b10f-23d49107e6eb', 'b46c2e8a-9d78-575f-ad02-4766b3bba8c2', 'ca58265e-ed96-5dab-91ce-0e2df46f2964', '01cbe4ce-ef90-5e21-9156-e8c32a50b8e9', '4bee9b8b-1b01-5550-9c0d-02acfc24d65e', '70235e02-cee3-5030-99e5-44adf8474cd2', 'b1c2bdfa-e22f-5144-a4c9-095202cd38fb', 'ea4190a0-2c54-502d-b0d5-cfe33dce117c', 'a0db567f-17fe-5b7f-8c21-f38b61b22e4f', '76a4a2c8-697d-5605-838a-44a9dc092cf4', 'f0bd228e-cb48-5727-895d-fc6a1a903364', 'ef6ea15f-c009-57e2-808a-8d96f4d6954f', '0f492b94-1206-5cd4-9998-9679658543d1', '05dd3e7f-d017-5760-8f20-99308003b744', 'b052dffc-b1a5-5f45-9c25-7d4cb7068be2', '0bcb9643-736d-5af9-b2ec-a0d6e7cfbe43', 'e40069a7-033a-5917-92a6-905feb8fb637', 'aa741254-b723-5b45-ae05-88f53be3f46e', '661e3993-06fc-5bd1-89f0-ebdedf991079', '67f0f75a-9c85-50c5-8f4c-b2edb2c8e82a', '2277a859-ca09-500e-841c-d4409491398f', '81cfe042-ffca-5a25-931c-48c846b7a991', 'dcaf8039-db90-5b2e-adae-9367642f4e87', '2d9d2a6a-ead7-5f46-8b5d-d7533a986d22', 'e164c8a7-a6e9-543d-9189-1bdc387b35a6', '713c9bdb-6878-52e4-8319-e55cb9c66803', 'c44174c4-4f93-51e0-8dc4-c1d9ab25b38b', 'cab543c7-57eb-59ed-994a-5657c0b227b5', 'a0794cb0-b720-5fb4-b5c9-952f3ff0a0ea', 'bea6ba30-53bd-5d13-b997-a3b43442e69f', 'b586e385-1ba6-5b22-92f8-7816bb780244', '1b98a82c-52cf-5b06-975c-2d0995455951', '516d3d14-b170-5e6b-9f30-9e8a71e6b05a', '138fe7b3-7724-571e-af30-2c17c719a3ba', 'c6adc8df-1c4a-5a25-8c5a-19e4b5e6c710', '0c3daa41-88bf-53d1-9b69-aa03a4432838', '68333b3e-a0e5-5444-8f7d-2121b3478dec', '299859aa-49dd-52ef-ac72-1cb5b51638c2', '97990d53-807c-5e7e-9a2c-7acada9025d4', 'a3397584-e761-5418-af89-29497c907024', 'b237cd93-936f-52be-8119-d2746a9ea71e', '8c1dbfef-bac8-5423-843d-f3415d6b1a74', 'a70304b0-6f40-5405-8a30-5801107860fa', '1257d381-b8a0-551d-9af2-20a8f4ac899f', 'f5478dba-19ca-5eb1-97a1-2e9e287f09b8', '3693edc9-a7cb-48fe-86ac-8ede0db9645b', 'fcb6af68-14d4-5b47-ae27-be9224b9a5ef', '1f3490c0-f940-5999-8cdb-463c8270c897', '78bb8251-66fd-5328-8a44-441ac38cfbc3', '5207c871-b193-5559-a69a-ea2265c3c666', 'a1f72b7a-9848-5d75-8e6e-a469af63eab0', '8ebe30a7-bdfa-5d50-aac2-1694092cbd3e', '917cd285-6c60-58ed-b2f1-022cbcf355a4', 'c1b17c99-b7ab-50e0-aa6a-f194c9889fe2', '517d07e4-b30c-5776-ac1f-18ed04d8ed63', 'eee01a23-5c0e-5903-b32c-f0e400fde1df', '52c9b4d5-4ce1-5fd8-9f22-ad162ff4d381', '2bdc636f-6d2d-5c3f-9c94-0ad8d4b585a4', 'e32c38f9-4148-5179-b3ba-bea7ef74a544', 'bbc34777-495f-5cf4-a329-55b7ebd24a86', 'f04f32a6-2bab-5e80-bd1e-efd2c0d8b5b4', '047cb9c5-2ffc-5829-93ac-3249d4c39ec5', 'fcb965f9-eb86-5f64-b593-f492adf19ffe', 'e99a7e8a-0beb-5ee5-9706-b2800af5d083', 'd7d3e1f4-562b-5e0a-a1b2-5b9ebda8ec4c', '871f9df8-c339-5057-b456-f239051b6cb1', 'b0a0fca8-aa88-5f74-a85a-16119b8655eb', 'c1900627-a209-52f4-a198-d4b85eb58581', '6e9f8007-63ad-5c56-b456-42cb3b7a3d93', 'cfb1ebb6-f214-55c4-9852-6d0bc355e110', 'cfa99d46-5805-56ef-bd4e-817c3ebf456d', 'bbee6622-5449-5dc9-9f51-3e043e429cd1', '1147c81b-570a-5bc4-a81b-367b340ab34e', '44ab0464-2fa5-54f4-b77d-436a50983824', '98d0ab61-97ab-54cf-8911-1edf50e62d02', 'd2266cf9-c32e-59c1-bbd5-fe24b64e38f5', '3d46a701-c1c7-57e7-a2a1-3145e729c061', '23f9a5f4-9182-5e0c-b470-8f0390cb2489', 'cce6f321-dc09-59e2-9897-e6901ad494cc', 'dc47ba27-5546-5eba-a1ad-4bee91274ef1', 'dbe62c63-14c1-584f-a2be-e1bfd3472fc9', 'c86835eb-006b-553e-92b5-33c55cc68d16', '585d04d5-4fd7-51f0-a83d-1f1d057f3904', '81b3abfc-a963-5074-8c52-8fd00bea1fd7', '8bf023ed-b657-53c9-a1e7-72b2e7c3f137', 'fc7fbf17-4924-50f3-84a2-f169c46b8e08', '09467c0e-de48-5781-bc7c-e9222164194b', '544927f6-f987-589c-a5bd-66bb385ce2ef', '17c96fd1-0fcf-5cf9-ad0b-71ce9ea801fa', 'b838b9c3-9ee2-5011-bc1e-ca3007a78b74', 'c7684a0d-e15b-5bf1-b8cd-560d4dcfbc76', '3cb2d81a-4ee7-5d81-8c5b-c7e2d434f547', 'd236250d-67f0-5452-bb15-7f0f588c96fa', '19add189-7a66-5a18-aa9d-1a4d22707bf1', '69be4d7f-3805-5891-b6bc-698752e4b998', '1ea2be4c-5b71-5869-a305-75e6ee313d87', '0104f8b1-983a-5edb-85f1-caefd7c9fed1', '55ce7d63-f028-5f69-b92c-aa2e1f71c77c', '99822a77-11a0-57e0-a4a0-0c7629a3f413', '8b21a6ab-bae2-5681-bb3d-8841c21e35e9', 'a2abe123-b771-5b5e-bd5f-0140185b0175', 'be738fd5-2c16-5ced-815d-9c1418bdb063', '9230f7f0-1707-50d5-a194-242c170d559b', '593fbd25-9e49-5731-a04e-0358f7087ddf', 'e3eb6c85-e38f-5429-9220-f8afbab12693', '86d45d6f-a690-58df-93ed-b0557ab297a5', 'eee41fe4-fbfe-5716-a324-0abbeec7852a', '18b8c5a7-d76e-5462-890d-a74b4e875f9b', '16476150-e023-5cf7-9ef6-db51fc512c8e', '0a6c4ac7-8c82-5ee8-8f7a-54bf9de797ef', '896ddb0a-ca48-5407-be00-a11d45dc3495', '0371d73d-ca0d-55dc-99cf-132a03b72b2f', 'd1762212-4e25-5cc0-bf5c-e9225ed77b8d', 'f1ae8d02-3ffe-5c2b-9c0d-86a7875709cc', '6eee6d0d-3636-5701-8498-a6da5c3a5f83', '4beac4a5-b058-5533-9ddd-56acaace8a54', '272611e7-f47f-58de-b5ae-f711deec7639', 'b6180e9e-1460-56fd-b07f-409fcd93dc3c', 'e7333f15-0ae5-594e-b3be-366230238b4b', '1d460377-37ec-5152-baa9-9436757d7e35', '050cca2a-e567-568d-8846-d8f01ad565d4', '59bfeddd-0c33-5014-9534-3dfbbe134c72', '83665086-049e-51aa-ae63-163adde0d5bb', 'd72e8f29-7c93-5925-81c2-92e35fccad60', 'bb4d417e-241e-504f-ab15-882fe1ddb986', '7a17b4bf-65ee-5ae6-9f52-92df9234d23d', '7b26ded7-27b6-5ce7-817d-e027b96677b5', 'd7d0cb69-399a-55ac-b1f1-316565247d35', '070752cc-ae4d-565c-a6b2-af697ee89cad', 'd98d7c23-daca-5618-a097-8b06bbf11463', '8f1c2fe4-68b1-5aae-b8fd-0ef7a54c20ea', 'e953efd8-6f54-5ea2-a72d-d61c0ece7c4a', 'f521a0f8-18f7-56dc-9575-05b08d2fa9e5', 'a2cd1ed2-4317-5286-b841-e38ea4d84488', 'ac709ea0-c523-5a80-a1b4-ccb8d8677363', 'e404770e-4a58-54da-942e-56ff4899c418', '571f75c7-e506-5d42-b67c-b4a96fa9c111', '6f287e0b-b1cc-58b7-83cc-be9e25648976', 'a2af74aa-952a-5ec8-b3c9-4ff62edeed39', '8e7cda6a-8ec8-561a-b62d-f7b447296032', '860992af-40be-5316-840b-9ef8c3bbb69c', '625559d2-089c-5db1-8861-1cc95dcac661', '9c166f62-2ac2-5a91-954a-fbf5bdb516dc', 'fc069fd1-65a8-58f1-aebd-74fc63e7033f', '72ca0545-96c0-55e8-ad48-45f926162ba1', 'ad1111a2-e5a0-5d48-b5c6-62f6826b77d6', '928f3928-ac9b-5ee9-b7ec-d38f885a0096', '08463ac0-ae76-5ba9-adeb-626929ed5f96', '174047d3-f77b-5ff6-ac5f-bbb253d0e648', '19e393da-b6ac-542c-a084-94b15393e6e6', '0f93976d-0e73-5d93-b2b9-ac79fa3974f1', '42877b59-daa0-5118-af64-e79b057b22ef', 'bbce3fbc-299e-5f7c-9d15-4f59667928da', 'f24a54ca-36fd-5d91-8eec-bdbf9dd44950', 'c19c0e55-1ef6-50da-b2fc-08a07ad0c0f4', 'e7b43ce4-77a0-5298-bac1-19a00d158652', '70e8412a-6f18-566a-8f75-1f5b7e29877a', 'db341440-42f2-5009-bced-69bc4cd922fb', '1364b4a0-45b8-5fe7-914a-2fb1d852be9b', 'fadabce3-5283-5a09-abf6-4763b3bdd5ae', '7cb87bb6-ee0a-5112-baab-764d28e79923', '17e7cfdf-b172-5249-abec-95ff56b3e787', 'f6bb9c14-bca6-46d2-b785-98b31ae02963', '4098e5a6-f237-51f5-85c8-c235b51d3a94', '0b19ca83-8918-5b9c-bdd0-0b5ace3c9376', '562b9ef7-b62d-531b-8075-4f55366c3b6f', '32928a95-3481-59bc-a089-dd89683f56b4', '36b102e8-b869-572e-a7ae-ee355faf2960', '7d64cd70-8912-54e1-a40f-73a212bcc487', '22124204-0ebb-5f37-854a-64fbfe152e9b', 'b36be6ef-67df-5ac9-b52d-b59c7b369a3b', 'e96e6b8a-e020-56c6-adf7-9b94eb3fdd45', 'a44e5412-6189-4b42-8d25-435da95e1836', 'ad23634e-d299-4847-9280-7e38bd7e6894', 'b792b4fd-2035-44e2-a60b-a18efc277e58');
  if v_count <> 258 then
    raise exception 'beklenen 258 soru, bulunan %', v_count;
  end if;
end
$$;

commit;
