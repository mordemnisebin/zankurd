-- 2026-10-08: BAŞLANGIÇ YOLU II — yedi yeni ders (canlı sunucu).
--
-- NİÇİN: başlangıç yolu (2026-10-06) alfabe, aile, kendini tanıtma ve ikinci
-- selamlaşma dersiyle bitiyordu; sıfırdan başlayan öğrenen için renk, vücut,
-- ev, giysi, hava durumu, soru sözcükleri ve temel fiil dersleri yoktu. Yerel
-- katalogda (2.0.2) bu dersler `colors_1`, `body_1`, `home_1`, `clothes_1`,
-- `weather_1`, `questions_1`, `verbs_1` olarak var; sunucuda (üretim `lessons`
-- tablosu, 19 satır) yoktu, yani sunucu katalogunu okuyan derleme yolu bu
-- dersleri hiç göstermezdi. `LearningLessonAliases.bySlug` bu yedi slug'ı yerel
-- kimliklere bağlar: reng, las, mal, cil, hewa, pirs, leker. Slayt metinleri
-- yerel slaytlarla AYNIDIR (`mock_zankurd_repository.dart`).
--
-- NE YAPAR:
--   1. `lessons`a yedi satır ekler (slug tekil; `on conflict (slug) do nothing`).
--   2. Her derse beş slaytını ekler (`(lesson_id, order_in_lesson)` tekil;
--      `on conflict ... do nothing`).
--   3. Doğrulama bloğu: slug, kategori, sıra, slayt sayısı ve yazım artığı
--      (çift nokta; meşru üç nokta "..." artık sayılmaz) tutmazsa işlemi geri alır.
--      Mevcut satırlara (`order_in_category` dahil) DOKUNMAZ: yeni dersler
--      everyday sırasının sonuna 7..13 olarak eklenir (alfabe 1 ... hejmar 6).
--
-- TEKRAR: ikinci çalıştırma 0 satır ekler.
-- SORULAR: bu göç soru eklemez; yeni sorular yerel bankada (ders kısa testi
-- yerel bankadan okur); boşluk doldurma ve cümle kurma çevrimiçi oda
-- protokolüne girmez.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from lessons where slug in ('reng','las','mal','cil','hewa','pirs','leker');
--   (lesson_slides satırları ON DELETE CASCADE ile gider.)
--
-- Uygulama: supabase db query --linked -f supabase/2026-10-08_dersler2_lessons.sql

begin;

insert into lessons (slug, title_ku, title_tr, description_ku, category, icon_name, order_in_category, language) values
  ('reng', 'Reng', 'Renkler', 'Rengên bingehîn û rengên din', 'everyday', 'palette', 7, 'ku'),
  ('las', 'Laşê mirov', 'Vücut', 'Beşên laş', 'everyday', 'accessibility_new', 8, 'ku'),
  ('cil', 'Cil û berg', 'Giysiler', 'Cil û bergên rojane', 'everyday', 'checkroom', 9, 'ku'),
  ('mal', 'Mal', 'Ev', 'Mal û tiştên malê', 'everyday', 'home', 10, 'ku'),
  ('hewa', 'Hewa', 'Hava durumu', 'Hewa çawa ye?', 'everyday', 'cloud', 11, 'ku'),
  ('pirs', 'Pirs', 'Soru kelimeleri', 'Kî? Çi? Ku? Kengî?', 'everyday', 'help', 12, 'ku'),
  ('leker', 'Lêker', 'Temel fiiller', 'Lêkerên bingehîn', 'everyday', 'directions_run', 13, 'ku')
on conflict (slug) do nothing;

-- Reng
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Rengên Bingehîn:\n\nEm îro rengan hîn dibin. Ev şeş rengên bingehîn in:\n\n• spî: beyaz\n• reş: siyah\n• sor: kırmızı\n• kesk: yeşil\n• şîn: mavi\n• zer: sarı', E'Bugün renkleri öğreniyoruz. Bunlar altı temel renktir: beyaz, siyah, kırmızı, yeşil, mavi, sarı.', null::text),
  (2, E'Rengên Din:\n\nEv jî rengên din in. Em hîn bibin:\n\n• porteqalî: turuncu\n• mor: mor\n• qehweyî: kahverengi\n• gewr: gri\n• pembe: pembe\n• reng: renk', E'Bunlar da diğer renkler. Öğrenelim: turuncu, mor, kahverengi, gri, pembe ve renk kelimesi.', null::text),
  (3, E'Ev Çi Reng e?\n\nEm bi lêkera ''bûn''ê rengan dibêjin. Mînak:\n\n• Sêv sor e: Elma kırmızıdır\n• Av şîn e: Su mavidir\n• Nan spî ye: Ekmek beyazdır\n• Kulîlk zer e: Çiçek sarıdır\n• Giya kesk e: Ot yeşildir\n• Pisîk reş e: Kedi siyahtır', E'Rengi bûn fiiliyle söyleriz. Örnekler: Elma kırmızıdır, Su mavidir, Ekmek beyazdır, Çiçek sarıdır, Ot yeşildir, Kedi siyahtır.', null::text),
  (4, E'Reng û Îzafe:\n\nReng piştî navan tên û bi îzafeyê tên girêdan. Mînak:\n\n• sêva sor: kırmızı elma\n• nanê spî: beyaz ekmek\n• kitêba kesk: yeşil kitap\n• kirasê reş: siyah gömlek\n• mala spî: beyaz ev\n• ava şîn: mavi su', E'Renk isimden sonra gelir ve izafe ile bağlanır. Örnekler: kırmızı elma, beyaz ekmek, yeşil kitap, siyah gömlek, beyaz ev, mavi su.', null::text),
  (5, E'Pirs û Bersiv:\n\nBi rengan pirsan bike û bersiv bide. Mînak:\n\n• Ev çi reng e?: Bu ne renk?\n• Ew sor e.: O kırmızıdır.\n• Kîjan reng xweş e?: Hangi renk güzel?\n• Zer xweş e.: Sarı güzel.\n• Sêva sor li ku ye?: Kırmızı elma nerede?', E'Renklerle soru sor ve cevap ver. Örnekler: Bu ne renk?, O kırmızıdır., Hangi renk güzel?, Sarı güzel., Kırmızı elma nerede?', null::text)
) as s(ord, ku, tr, ex) where slug = 'reng'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Laşê mirov
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Laşê Mirov:\n\nÎro em beşên laş hîn dibin. Ev peyv pir girîng in:\n\n• ser: baş\n• rû: yüz\n• stû: boyun\n• mil: omuz, kol\n• dest: el\n• ling: bacak, ayak', E'Bugün vücudun bölümlerini öğreniyoruz. Bu kelimeler çok önemlidir: baş, yüz, boyun, omuz/kol, el, bacak/ayak.', null::text),
  (2, E'Ser û Rû:\n\nEm li ser û rû dinêrin. Van peyvan bînin bîra xwe:\n\n• ser: baş\n• por: saç\n• rû: yüz\n• çav: göz\n• guh: kulak\n• poz: burun\n• dev: ağız\n• diran: diş', E'Başa ve yüze bakıyoruz. Bu kelimeleri aklınızda tutun: baş, saç, yüz, göz, kulak, burun, ağız, diş.', null::text),
  (3, E'Dest û Ling:\n\nEm li dest û ling dinêrin. Van peyvan dubare bike:\n\n• mil: omuz, kol\n• dest: el\n• tilî: parmak\n• ling: bacak, ayak\n• pê: ayak\n• çok: diz', E'Ele ve bacağa bakıyoruz. Bu kelimeleri tekrar et: omuz/kol, el, parmak, bacak/ayak, ayak, diz.', null::text),
  (4, E'Hevokên Hêsan bi Laş:\n\nNiha em peyvan di hevokan de dibînin:\n\n• Çavên min reş in: Gözlerim siyahtır\n• Serê min diêşe: Başım ağrıyor\n• Ez destên xwe dişom: Ellerimi yıkıyorum\n• Diranên min spî ne: Dişlerim beyazdır\n• Lingê min diêşe: Bacağım, ayağım ağrıyor', E'Şimdi kelimeleri cümleler içinde görüyoruz:\n- Gözlerim siyahtır\n- Başım ağrıyor\n- Ellerimi yıkıyorum\n- Dişlerim beyazdır\n- Bacağım (ayağım) ağrıyor', null::text),
  (5, E'Laşê Min:\n\nNiha em bi lêkera bûn-ê diaxivin. Dubare bike:\n\n• Ez sax im: Ben sağlıklıyım\n• Çavên min reş in: Gözlerim siyahtır\n• Destê min paqij e: Elim temizdir\n• Em amade ne: Biz hazırız\n• Laşê min sax e: Vücudum sağlıklıdır', E'Şimdi ''olmak'' (bûn) fiiliyle konuşuyoruz. Tekrar et:\n- Ben sağlıklıyım\n- Gözlerim siyahtır\n- Elim temizdir\n- Biz hazırız\n- Vücudum sağlıklıdır', null::text)
) as s(ord, ku, tr, ex) where slug = 'las'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Cil û berg
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Cil û bergên rojane:\n\nEm îro 6 cilên bingehîn hîn dibin:\n\n• kiras: gömlek\n• pantor: pantolon\n• çakêt: ceket\n• pêlav: ayakkabı\n• şapke: şapka\n• gore: çorap', E'Bugün 6 temel giysiyi öğreniyoruz: gömlek, pantolon, ceket, ayakkabı, şapka ve çorap. Her Kurmancî sözcüğü Türkçe karşılığıyla ezberle.', null::text),
  (2, E'Rengê cilan:\n\nReng bi izafeyê tê ser navdêrê:\n\n• kirasê sor: kırmızı gömlek\n• pantorê reş: siyah pantolon\n• çakêtê şîn: mavi ceket\n• şapkeya spî: beyaz şapka\n• goreyên kesk: yeşil çoraplar\n• pêlavên zer: sarı ayakkabılar', E'Renk, izafe ekiyle giysi adından sonra gelir: kirasê sor (kırmızı gömlek) gibi. Tekil izafe ê/ya, çoğul izafe ên biçimindedir.', null::text),
  (3, E'Ez li xwe dikim:\n\nLêkera li xwe kirinê di dema niha de:\n\n• Ez kiras li xwe dikim: gömlek giyiyorum\n• Tu pantor li xwe dikî: pantolon giyiyorsun\n• Ew şapke li xwe dike: şapka takıyor\n• Em pêlav li xwe dikin: ayakkabı giyiyoruz\n• Hûn mont li xwe dikin: mont giyiyorsunuz\n• Ew gore li xwe dikin: çorap giyiyorlar', E'Giyinmek fiili li xwe kirin, şimdiki zamanla çekilir: dikim, dikî, dike, dikin. Nesne yalın durumda kalır, ergatiflik yoktur.', null::text),
  (4, E'Mezin, biçûk, nû:\n\nCilan bi van rengdêran binas bike:\n\n• montê mezin: büyük mont\n• dawêna biçûk: küçük etek\n• kirasê nû: yeni gömlek\n• çakêtê kevn: eski ceket\n• pêlavên paqij: temiz ayakkabılar\n• goreyên pîs: kirli çoraplar', E'Sıfatlar izafeyle giysiyi niteler: mezin (büyük), biçûk (küçük), nû (yeni), kevn (eski), paqij (temiz), pîs (kirli).', null::text),
  (5, E'Li dikanê:\n\nHevokên kurt ji bo dikanê:\n\n• Ev çi ye: bu nedir\n• Ev kiras e: bu gömlektir\n• Ev çend e: bu kaç lira, fiyatı nedir\n• Ev mezin e: bu büyüktür\n• Ev biçûk e: bu küçüktür\n• Ev sor e: bu kırmızıdır', E'Mağazada lazım olan kalıplar: Ev çi ye (bu nedir), Ev kiras e (bu gömlektir), Ev çend e (fiyatı nedir). Hepsi e/ye ile biter.', null::text)
) as s(ord, ku, tr, ex) where slug = 'cil'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Mal
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Mal çi ye?\n\nMal cihê jiyanê ye. Van peyvan bixwîne:\n\n• mal: ev\n• ode: oda\n• derî: kapı\n• pencere: pencere\n• dîwar: duvar\n• erd: zemin', E'Ev, yaşadığımız yerdir. Bu sözcükleri oku: ev, oda, kapı, pencere, duvar, zemin.', null::text),
  (2, E'Odeyên malê:\n\nHer odeyek ji bo karekî ye:\n\n• ode: oda\n• metbex: mutfak\n• serşok: banyo\n• odeya nivînê: yatak odası\n• odeya rûniştinê: salon\n• korîdor: koridor', E'Her oda bir iş içindir: oda, mutfak, banyo, yatak odası, salon, koridor.', null::text),
  (3, E'Tiştên malê 1:\n\nTiştên ku em her roj bi kar tînin:\n\n• mase: masa\n• kursî: sandalye\n• nivîn: yatak\n• dolab: dolap\n• derî: kapı\n• pencere: pencere', E'Her gün kullandığımız eşyalar: masa, sandalye, yatak, dolap, kapı, pencere.', null::text),
  (4, E'Tiştên malê 2:\n\nTiştên din ên malê:\n\n• ronahî: ışık\n• dîwar: duvar\n• ban: tavan\n• erd: zemin\n• mift: anahtar\n• perde: perde', E'Evin diğer eşyaları: ışık, duvar, tavan, zemin, anahtar, perde.', null::text),
  (5, E'Bi Kurmancî biaxive: Ev ... e / ye:\n\nQalibek sade bi kar bîne:\n\n• Ev mal e: Bu evdir\n• Ev derî ye: Bu kapıdır\n• Ev mase ye: Bu masadır\n• Ode mezin e: Oda büyüktür\n• Metbex paqij e: Mutfak temizdir', E'Basit bir kalıp kullan: Ev mal e: Bu evdir, Ev derî ye: Bu kapıdır, Ev mase ye: Bu masadır, Ode mezin e: Oda büyüktür, Metbex paqij e: Mutfak temizdir. Sessiz harften sonra e, sesli harften sonra ye gelir.', null::text)
) as s(ord, ku, tr, ex) where slug = 'mal'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Hewa
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Hewa çawa ye?\n\nEm li ser hewayê diaxivin.\n\n• Hewa çawa ye?: Hava nasıl?\n• hewa: hava\n• îro: bugün\n• çawa: nasıl\n• xweş: güzel, iyi\n• xirab: kötü\n• Hewa xweş e: Hava güzel', E'Bu derste hava durumunu soruyoruz. Temel soru: Hewa çawa ye? (Hava nasıl?). Cevap: Hewa xweş e. / Hewa xirab e.', null::text),
  (2, E'Roj û germahî:\n\nÎro roj heye û hewa germ e.\n\n• roj: güneş, gün\n• tav: güneş ışığı\n• germ: sıcak\n• pir germ: çok sıcak\n• hinekî germ: biraz sıcak\n• Roj derdikeve: Güneş doğuyor, çıkıyor\n• Hewa germ e: Hava sıcak', E'Güneşli ve sıcak havayı anlatıyoruz. Roj güneş demektir. Germ sıcak demektir. Örnek: Hewa îro germ e. (Hava bugün sıcak.)', null::text),
  (3, E'Baran û ba:\n\nCarinan baran dibare û ba tê.\n\n• baran: yağmur\n• ba: rüzgar\n• ewr: bulut\n• ewrî: bulutlu\n• dibare: yağıyor\n• ba tê: rüzgar esiyor\n• Baran dibare: Yağmur yağıyor', E'Yağmurlu ve rüzgarlı hava. Baran yağmur, ba rüzgar, ewr bulut demektir. Fiil: dibare (yağıyor), tê (geliyor, esiyor).', null::text),
  (4, E'Berf û serma:\n\nDi zivistanê de berf dibare û hewa sar e.\n\n• berf: kar\n• sar: soğuk\n• serma: soğukluk, soğuk hava\n• mij: sis\n• cemed: buz\n• Berf dibare: Kar yağıyor\n• Hewa sar e: Hava soğuk', E'Kışın hava: kar ve soğuk. Berf kar, sar soğuk demektir. Örnek: Berf dibare. (Kar yağıyor.) Hewa sar e. (Hava soğuk.)', null::text),
  (5, E'Demsal û ez:\n\nEm dibêjin ez germ im an ez sar im.\n\n• bihar: ilkbahar\n• havîn: yaz\n• payîz: sonbahar\n• zivistan: kış\n• ez germ im: sıcağım, bana sıcak geliyor\n• ez sar im: üşüyorum, bana soğuk geliyor\n• Ez li malê me: Ben evdeyim', E'Dört mevsim ve bûn fiili (olmak). Ez im (benim), tu yî (sensin), ew e (odur). Hava için e, kişi için im kullanırız: Hewa sar e. Ez sar im.', null::text)
) as s(ord, ku, tr, ex) where slug = 'hewa'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Pirs
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Kî? Çi?\n\nPirsên li ser mirovan û tiştan. Kî ji bo mirovan, çi ji bo tiştan tê bikaranîn.\n\n• Kî ye?: kimdir?\n• Kî ne?: kimler?\n• Tu kî yî?: sen kimsin?\n• Ev çi ye?: bu nedir?\n• Tu çi dixwazî?: ne istiyorsun?\n• Navê te çi ye?: adın nedir?', E'İnsanlar ve eşyalar hakkında sorular. Kî (kim) insanlar için, çi (ne) eşyalar için kullanılır. Fiil cümlenin sonunda çekimlenir.', null::text),
  (2, E'Ku? Kengî?\n\nPirsên li ser cihî û demê. Ku = li kîjan derê, kengî = di kîjan demê de.\n\n• Tu li ku yî?: neredesin?\n• Dibistan li ku ye?: okul nerede?\n• Tu kengî têyî?: ne zaman geliyorsun?\n• Ders kengî dest pê dike?: ders ne zaman başlıyor?\n• Tu îro kengî têyî?: bugün ne zaman geliyorsun?\n• Tu sibê li ku yî?: yarın neredesin?', E'Yer ve zaman soruları. Ku (nerede/nereye) ve kengî (ne zaman) sorulan öğenin yerinde durur; fiil sonda kalır. Cevap yer veya zaman bildirir.', null::text),
  (3, E'Çima? Çawa?\n\nPirsên li ser sedemî û awayî. Çima = ji bo çi, çawa = bi çi awayî.\n\n• Tu çima hatî?: neden geldin?\n• Ew çima naxwaze?: o neden istemiyor?\n• Tu çawa yî?: nasılsın?\n• Tu çawa dixwînî?: nasıl okuyorsun?\n• Çawa çêdibe?: nasıl oluyor?\n• Bi çi awayî?: ne şekilde?', E'Sebep ve yöntem soruları. Çima (neden), çawa (nasıl) ile sorulur. Tu çawa yî? sorusunun cevabı Ez baş im (iyiyim) olur.', null::text),
  (4, E'Çend? Kîjan? Çiqas?\n\nPirsên li ser hejmar û hilbijartinê. Çend ji bo hejmaran, kîjan ji bo hilbijartinê.\n\n• Tu çend salî yî?: kaç yaşındasın?\n• Çend pirtûk?: kaç kitap?\n• Kîjan pirtûk?: hangi kitap?\n• Kîjan dibistan?: hangi okul?\n• Çiqas nan?: ne kadar ekmek?\n• Biha çiqas e?: fiyat ne kadar?', E'Sayı ve seçim soruları. Çend (kaç tane), kîjan (hangisi), çiqas (ne kadar) isimden önce gelir. Yaş sorusu çend salî ile sorulur.', null::text),
  (5, E'Pirsan çêke!\n\nRêza pirsê: peyva pirsê li cihê bersivê dimîne, lêker li dawiyê ye.\n\n• Tu kî yî?: sen kimsin?\n• Ew li ku ye?: o nerededir?\n• Ew kengî dixwîne?: o ne zaman okuyor?\n• Tu çima dikî?: neden yapıyorsun?\n• Ev çend in?: bunlar kaç tanedir?\n• Kîjan baş e?: hangisi iyidir?', E'Kurmancî soru dizilişi: soru kelimesi sorulan öğenin yerinde kalır, çekimli fiil sonda olur. Evet/hayır sorusunda ayrı soru kelimesi gerekmez.', null::text)
) as s(ord, ku, tr, ex) where slug = 'pirs'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Lêker
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Lêker çi ye?\n\nDi kurmancî de lêker di dawiya hevokê de ye. Dema niha bi pêşgira di- çêdibe:\n\n• ez nan dixwim: ben ekmek yiyorum\n• tu çay vedixwî: sen çay içiyorsun\n• ew diçe: o gidiyor\n• em dikin: biz yapıyoruz\n• hûn dibînin: siz görüyorsunuz\n\nHatin cuda ye, di- naxe:\n\n• ew tên: onlar geliyorlar\n\nForma neyînî bi na- ye:\n\n• ez naçim: ben gitmiyorum', E'Kurmancîde fiil cümlenin sonunda yer alır. Şimdiki/geniş zaman çoğu fiilde di- önekiyle yapılır. Özne + nesne + fiil sırası vardır. Hatin (gelmek) di- almaz: ew tên onlar geliyorlar. Olumsuzluk na- ile yapılır: ez naçim ben gitmiyorum.', null::text),
  (2, E'Çûn û hatin:\n\nÇûn û hatin lêkerên tevgerê ne:\n\n• ez diçim: ben gidiyorum\n• tu diçî: sen gidiyorsun\n• ew diçe: o gidiyor\n• ez têm: ben geliyorum\n• tu têyî: sen geliyorsun\n• ew tê: o geliyor\n• em tên: biz geliyoruz\n• em diçin dibistanê: biz okula gidiyoruz', E'Çûn gitmek, hatin gelmektir. Her ikisi de şimdiki zamanda çekimlenir. Sen geliyorsun: tu têyî (ew tê ise o geliyor). Yer, çekimli hâlde fiilden sonra gelir: em diçin dibistanê. Em diçin, biz gidiyoruz demektir.', null::text),
  (3, E'Xwarin û vexwarin:\n\nJi bo xwarin û vexwarinê:\n\n• ez nan dixwim: ben ekmek yiyorum\n• tu nan dixwî: sen ekmek yiyorsun\n• ew nan dixwe: o ekmek yiyor\n• ez av vedixwim: ben su içiyorum\n• tu çay vedixwî: sen çay içiyorsun\n• ew çay vedixwe: o çay içiyor\n• em nan dixwin: biz ekmek yiyoruz', E'Xwarin yemek yemek, vexwarin içmektir. Nesne fiilden önce gelir: nan dixwim ekmek yiyorum. Dixwim ve vedixwim arasındaki ve- farkına dikkat edin.', null::text),
  (4, E'Kirin û dîtin:\n\nKirin û dîtin pir tên bikaranîn:\n\n• ez dikim: ben yapıyorum\n• tu dikî: sen yapıyorsun\n• ew dike: o yapıyor\n• ez dibînim: ben görüyorum\n• tu dibînî: sen görüyorsun\n• ew dibîne: o görüyor\n• em dibînin: biz görüyoruz\n• tu kar dikî: sen iş yapıyorsun', E'Kirin yapmak etmektir, dîtin görmektir. Kar dikim çalışıyorum anlamına gelir. Çekimde kişi eki değişir: dikim, dikî, dike. Soru ve olumsuz daha sonra gelecek.', null::text),
  (5, E'Hevokên hêsan:\n\nBi van lêkeran hevokên hêsan:\n\n• ez diçim malê: ben eve gidiyorum\n• tu têyî dibistanê: sen okula geliyorsun\n• ew nan dixwe: o ekmek yiyor\n• em çay vedixwin: biz çay içiyoruz\n• hûn kar dikin: siz iş yapıyorsunuz\n• ez te dibînim: ben seni görüyorum\n• ez naçim: ben gitmiyorum', E'Özne baştadır. Nesne fiilden önce gelir; yer çoğu zaman fiilden sonra gelir: diçim malê, têyî dibistanê. Naçim gitmiyorum demektir. Önce olumlu basit cümle kurun.', null::text)
) as s(ord, ku, tr, ex) where slug = 'leker'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Doğrulama: slug, kategori, sıra, slayt sayısı ve yazım artığı tutmazsa geri alınır.
do $$
declare
  r record;
  v_count int;
begin
  for r in select * from (values
    ('reng', 5, 7),
    ('las', 5, 8),
    ('cil', 5, 9),
    ('mal', 5, 10),
    ('hewa', 5, 11),
    ('pirs', 5, 12),
    ('leker', 5, 13)
  ) as t(slug, expected_slides, expected_order) loop
    select count(*) into v_count
      from lesson_slides ls join lessons l on l.id = ls.lesson_id
     where l.slug = r.slug;
    if v_count <> r.expected_slides then
      raise exception 'dersler2: % slayt sayisi % (beklenen %)', r.slug, v_count, r.expected_slides;
    end if;
    if not exists (select 1 from lessons where slug = r.slug and category = 'everyday'
                      and order_in_category = r.expected_order and language = 'ku') then
      raise exception 'dersler2: % kategori/sira beklenen degil', r.slug;
    end if;
    -- Cift nokta yazim artigidir; "..." (uc nokta) mesrudur.
    if exists (
      select 1 from lesson_slides ls join lessons l on l.id = ls.lesson_id
       where l.slug = r.slug
         and (ls.content_ku ~ '(^|[^.])\.\.([^.]|$)' or ls.content_tr ~ '(^|[^.])\.\.([^.]|$)'
              or ls.content_ku ~ '  ' or ls.content_tr ~ '  ')
    ) then
      raise exception 'dersler2: % slaytinda yazim artigi', r.slug;
    end if;
  end loop;

  if (select count(*) from lessons where category = 'everyday') <> 13 then
    raise exception 'dersler2: everyday ders sayisi 13 degil';
  end if;
end
$$;

commit;
