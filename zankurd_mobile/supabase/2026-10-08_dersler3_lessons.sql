-- 2026-10-08: BAŞLANGIÇ YOLU III — yedi yeni ders (canlı sunucu).
--
-- NİÇİN: başlangıç yolu II (2026-10-08_dersler2_lessons.sql) renk, vücut, ev,
-- giysi, hava, soru sözcüğü ve fiil derslerinde bitiyordu; günlük hayatın
-- ilk konuları (meslek, şehirde yön sorma, alışveriş, sağlık, okul, ulaşım) ve
-- geçmiş zaman yoktu. Yerel katalogda (2.0.2) bu dersler `jobs_1`, `city_1`,
-- `shopping_1`, `health_1`, `school_1`, `transport_1`, `past_1` olarak var;
-- sunucuda yoktu. `LearningLessonAliases.bySlug` slug'ları yerel kimliklere
-- bağlar: pise, bajar, kirin, tenduristi, dibistan, veguhestin, dema-bori.
-- Slayt metinleri yerel slaytlarla AYNIDIR (`mock_zankurd_repository.dart`).
--
-- ÖNKOŞUL: 2026-10-08_dersler2_lessons.sql uygulanmış olmalı (everyday sırası
-- 13'e kadar dolu; bu göç 14..20 verir). Uygulanmamışsa doğrulama bloğu
-- everyday ders sayısını denetlediği için işlemi geri alır.
--
-- NE YAPAR: (1) `lessons`a yedi satır ekler (`on conflict (slug) do nothing`);
-- (2) beşer slayt ekler (`on conflict (lesson_id, order_in_lesson) do nothing`);
-- (3) doğrulama bloğu: slayt sayısı, kategori/sıra, çift nokta ve çift boşluk
-- artığı (meşru "..." sayılmaz). Mevcut satırlara dokunmaz. Soru eklemez.
--
-- TEKRAR: ikinci çalıştırma 0 satır ekler.
-- GERİ ALMA: delete from lessons where slug in ('pise','bajar','kirin','tenduristi','dibistan','veguhestin','dema-bori');
--
-- Uygulama: supabase db query --linked -f supabase/2026-10-08_dersler3_lessons.sql

begin;

insert into lessons (slug, title_ku, title_tr, description_ku, category, icon_name, order_in_category, language) values
  ('pise', 'Pîşe', 'Meslekler', 'Pîşe çi ye?', 'everyday', 'work', 14, 'ku'),
  ('bajar', 'Bajar', 'Şehir', 'Cihên girîng ên bajêr', 'everyday', 'location_city', 15, 'ku'),
  ('kirin', 'Li dikanê', 'Alışveriş', 'Silav li dikanê', 'everyday', 'shopping_cart', 16, 'ku'),
  ('tenduristi', 'Tenduristî', 'Sağlık', 'Doktor û nexweşxane', 'everyday', 'favorite', 17, 'ku'),
  ('dibistan', 'Dibistan', 'Okul', 'Cihê xwendinê', 'everyday', 'school', 18, 'ku'),
  ('veguhestin', 'Veguhestin', 'Ulaşım', 'Wesayît û bilêt', 'everyday', 'directions_bus', 19, 'ku'),
  ('dema-bori', 'Dema borî', 'Geçmiş zaman', 'Lêkerên dema borî', 'everyday', 'history', 20, 'ku')
on conflict (slug) do nothing;

-- Pîşe
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Pîşe çi ye?\n\nPîşe karê mirovan e. Piştî dengdêrî: Ez mamoste me. Piştî dengdarî: Ez doktor im.\n\n• pîşe: meslek\n• kar: iş\n• ez: ben\n• tu: sen\n• ew: o\n• im/me: -ım, -im\n• e/ye: -dır, -dir', E'Meslek insanların işidir. Sesliden sonra Ez mamoste me, sessizden sonra Ez doktor im deriz. Bu derste 12 meslek öğreneceğiz.', null::text),
  (2, E'Pîşeyên hevpar:\n\nEv pîşe pir hevpar in.\n\n• mamoste: öğretmen\n• doktor: doktor\n• hemşîre: hemşire\n• xwendekar: öğrenci\n• karker: işçi\n• cotkar: çiftçi\n• polîs: polis', E'Bu meslekler çok yaygındır. Her satırı yüksek sesle oku ve Türkçesini söyle.', null::text),
  (3, E'Lêkera bûnê:\n\nEm pîşeyê bi lêkera bûnê dibêjin.\n\n• ez mamoste me: ben öğretmenim\n• tu doktor î: sen doktorsun\n• ew hemşîre ye: o hemşiredir\n• em karker in: biz işçiyiz\n• hûn polîs in: siz polissiniz\n• ew cotkar in: onlar çiftçidir', E'Mesleği söylemek için bûn fiilini kullanırız. Yüklem sesliyle bitiyorsa ez-me, tu-yî, ew-ye, em/hûn/ew-ne; sessizle bitiyorsa ez-im, tu-î, ew-e, em/hûn/ew-in.', null::text),
  (4, E'Li ku dixebite?\n\nMamoste li dibistanê dixebite.\n\n• dibistan: okul\n• nexweşxane: hastane\n• zevî: tarla\n• dadgeh: mahkeme\n• fabrîka: fabrika\n• qereqol: karakol\n• Doktor li nexweşxaneyê dixebite: Doktor hastanede çalışır', E'Çalışma yerini li ile söyleriz. Örnek: Mamoste li dibistanê dixebite. Doktor li nexweşxaneyê dixebite.', null::text),
  (5, E'Diyalog û rêziman:\n\nDiyalogek kurt.\n\n• Silav, tu kî yî?: Merhaba, sen kimsin\n• Ez Hêlîn im, ez hemşîre me.: Ben Helinim, ben hemşireyim\n• Tu li ku dixebitî?: Sen nerede çalışıyorsun\n• Ez li nexweşxaneyê dixebitim.: Ben hastanede çalışıyorum\n• ev dema niha ye: bu şimdiki zamandır\n• ergatîf tune ye: ergatif yok', E'Bu derste yalnız şimdiki zaman ve bûn var. Geçmiş zamanın ergatif yapısı yok. Diyaloğu iki kişiyle oku.', null::text)
) as s(ord, ku, tr, ex) where slug = 'pise'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Bajar
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Bajar: Cihên Girîng:\n\nDi bajêr de gelek cih hene. Ev peyvên bingehîn in:\n\n• bajar: şehir\n• kolan: sokak\n• nexweşxane: hastane\n• dibistan: okul\n• bazar: çarşı\n• xwaringeh: lokanta\n• otêl: otel', E'Şehirde birçok yer vardır. Temel kelimeler:\n- bajar: şehir\n- kolan: sokak\n- nexweşxane: hastane\n- dibistan: okul\n- bazar: çarşı\n- xwaringeh: lokanta\n- otêl: otel', null::text),
  (2, E'Alî: Rast, Çep, Rasterast:\n\nJi bo nîşandana rê van peyvan bi kar bîne:\n\n• rast: sağ\n• çep: sol\n• rasterast: düz, dosdoğru\n• nêzîk: yakın\n• dûr: uzak\n• li vir: burada\n• li wir: orada', E'Yön tarif ederken bu kelimeleri kullan:\n- rast: sağ\n- çep: sol\n- rasterast: düz, dosdoğru\n- nêzîk: yakın\n- dûr: uzak\n- li vir: burada\n- li wir: orada', null::text),
  (3, E'Rê Pirsîn:\n\nDema tu rê dipirsî, van qaliban bi kar bîne:\n\n• Ji kerema xwe: lütfen\n• ... li ku ye?: ... nerededir?\n• Ez çawa biçim ...?: ... nasıl giderim?\n• li ku derê ye?: nerededir?\n• dûr e?: uzak mıdır?\n• nêzîk e?: yakın mıdır?', E'Yol sorarken bu kalıpları kullan:\n- Ji kerema xwe: lütfen\n- ... li ku ye?: ... nerededir?\n- Ez çawa biçim ...?: ... nasıl giderim?\n- li ku derê ye?: nerededir?\n- dûr e?: uzak mıdır?\n- nêzîk e?: yakın mıdır?', null::text),
  (4, E'Rê Nîşandan:\n\nRê nîşandan. Hevokên fermanî bingehîn in:\n\n• Rasterast biçe: Düz git\n• Li rastê bizivire: Sağa dön\n• Li çepê bizivire: Sola dön\n• Bisekine: Dur\n• li pêş: önde\n• li paş: arkada', E'Yol tarif etme. Emir cümleleri temeldir:\n- Rasterast biçe: Düz git\n- Li rastê bizivire: Sağa dön\n- Li çepê bizivire: Sola dön\n- Bisekine: Dur\n- li pêş: önde\n- li paş: arkada', null::text),
  (5, E'Di Bajêr De: Diyalog:\n\nAxaftineke kurt û hêsan. Peyvên nezaketê:\n\n• Rojbaş: Merhaba, iyi günler\n• Ji kerema xwe: lütfen\n• Spas: Teşekkürler\n• Erê: Evet\n• Na: Hayır\n• Baş e: Tamam, iyidir', E'Kısa ve kolay bir konuşma. Kibarlık kelimeleri:\n- Rojbaş: Merhaba, iyi günler\n- Ji kerema xwe: lütfen\n- Spas: Teşekkürler\n- Erê: Evet\n- Na: Hayır\n- Baş e: Tamam, iyidir', null::text)
) as s(ord, ku, tr, ex) where slug = 'bajar'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Li dikanê
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Silav li dikanê:\n\nLi dikanê em pêşî silav dikin.\n\n• merheba: merhaba\n• rojbaş: iyi günler\n• tu çawa yî?: nasılsın\n• ez baş im: iyiyim\n• bi xêr hatî: hoş geldin\n• bi xatirê te: hoşça kal', E'Dükkânda önce selamlaşırız. Merhaba, iyi günler, nasılsın, iyiyim, hoş geldin ve hoşça kal kalıplarını öğreniyoruz.', null::text),
  (2, E'Tiştên kirînê:\n\nLi dikanê gelek tişt hene.\n\n• nan: ekmek\n• av: su\n• şîr: süt\n• hêk: yumurta\n• sêv: elma\n• dikan: dükkân\n• sûk: pazar', E'Dükkânda birçok ürün vardır. Ekmek, su, süt, yumurta, elma, dükkân ve pazar kelimelerini öğreniyoruz.', null::text),
  (3, E'Pirsîna bihayê:\n\nJi bo pirsîna bihayê em dibêjin.\n\n• Ev çend e?: bu kaçtır\n• Biha çend e?: fiyat nedir\n• erzan: ucuz\n• giran: pahalı\n• ez dixwazim: istiyorum\n• tu çi dixwazî?: ne istiyorsun', E'Fiyatı sormak için Ev çend e ve Biha çend e deriz. Ucuz, pahalı ve istiyorum kalıplarını öğreniyoruz.', null::text),
  (4, E'Pere û hejmar:\n\nJi bo kirînê pere lazim e.\n\n• pere: para\n• biha: fiyat\n• yek: bir\n• du: iki\n• sê: üç\n• çar: dört\n• pênc: beş', E'Alışveriş için para gerekir. Para, fiyat ve 1''den 5''e kadar sayıları öğreniyoruz.', null::text),
  (5, E'Diyaloga kirînê:\n\nKiriyar û firoşkar diaxivin.\n\n• Ez sêv dixwazim: elma istiyorum\n• Şîr li dikanê ye: süt dükkândadır\n• Sêv erzan in: elmalar ucuzdur\n• Nan giran e: ekmek pahalıdır\n• Pere li ku ye?: para nerede', E'Müşteri ve satıcı konuşur. İstiyorum, dükkândadır, ucuzdur, pahalıdır kalıplarıyla kısa bir diyalog kuruyoruz.', null::text)
) as s(ord, ku, tr, ex) where slug = 'kirin'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Tenduristî
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Tenduristî çi ye?\n\nTenduristî ji bo jiyanê pir girîng e. Em xwe nas dikin.\n\n• tenduristî: sağlık\n• baş: iyi\n• nexweş: hasta\n• ez: ben\n• tu: sen\n• ew: o', E'Sağlık yaşam için çok önemlidir. Kendimizi tanıyoruz.\n- tenduristî: sağlık\n- baş: iyi\n- nexweş: hasta\n- ez: ben\n- tu: sen\n- ew: o', null::text),
  (2, E'Doktor û Nexweşxane:\n\nEm diçin ba doktor. Doktor alîkarî dide.\n\n• doktor: doktor\n• nexweşxane: hastane\n• derman: ilaç\n• bijîşk: hekim, doktor\n• alîkarî: yardım\n• nexweş: hasta', E'Doktora gidiyoruz. Doktor yardım eder.\n- doktor: doktor\n- nexweşxane: hastane\n- derman: ilaç\n- bijîşk: hekim, doktor\n- alîkarî: yardım\n- nexweş: hasta', null::text),
  (3, E'Laşê Me:\n\nLaşê me ji beşan pêk tê. Em navên beşan hîn dibin.\n\n• ser: baş\n• çav: göz\n• diran: diş\n• dil: kalp\n• zik: karın\n• laş: vücut, beden', E'Vücudumuz parçalardan oluşur. Parça adlarını öğreniyoruz.\n- ser: baş\n- çav: göz\n- diran: diş\n- dil: kalp\n- zik: karın\n- laş: vücut, beden', null::text),
  (4, E'Nîşanên Nexweşiyê:\n\nDema em nexweş in, laşê me nîşan dide. Ev peyv girîng in.\n\n• êş: ağrı\n• ta: ateş\n• kuxik: öksürük\n• grîp: grip\n• serma: üşütme, soğuk algınlığı\n• diêşe: ağrıyor', E'Hasta olunca vücudumuz belirti gösterir. Bu sözler önemlidir.\n- êş: ağrı\n- ta: ateş\n- kuxik: öksürük\n- grîp: grip\n- serma: üşütme, soğuk algınlığı\n- diêşe: ağrıyor', null::text),
  (5, E'Ez bi Doktor re Dipeyivim:\n\nEm hevokên hêsan dibêjin. Em dema niha bi kar tînin.\n\n• Serê min diêşe: Başım ağrıyor\n• Ez nexweş im: Ben hastayım\n• Taya min heye: Ateşim var\n• Ez dikuxim: Öksürüyorum\n• Derman bide min: Bana ilaç ver', E'Basit cümleler söylüyoruz. Şimdiki zamanı kullanıyoruz.\n- Serê min diêşe: Başım ağrıyor\n- Ez nexweş im: Ben hastayım\n- Taya min heye: Ateşim var\n- Ez dikuxim: Öksürüyorum\n- Derman bide min: Bana ilaç ver', null::text)
) as s(ord, ku, tr, ex) where slug = 'tenduristi'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Dibistan
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Dibistan:\n\nDibistan cihê xwendinê ye. Em di dibistanê de hîn dibin.\n\n• dibistan: okul\n• pol: sınıf\n• ders: ders\n• mamoste: öğretmen\n• xwendekar: öğrenci\n• mezin: büyük', E'Okul, öğrenim yeridir. Okulda öğreniriz.', null::text),
  (2, E'Mamoste û Xwendekar:\n\nLi dibistanê mamoste dersê dide, xwendekar hîn dibe.\n\n• mamoste: öğretmen\n• xwendekar: öğrenci\n• heval: arkadaş\n• ders: ders\n• dibistan: okul\n• hîn dibe: öğreniyor', E'Okulda öğretmen ders verir, öğrenci öğrenir. Kişileri tanıtan basit cümleler kuruyoruz.', null::text),
  (3, E'Pirtûk, Defter û Pênûs:\n\nEm bi van tiştan dixwînin û dinivîsin.\n\n• pirtûk: kitap\n• defter: defter\n• pênûs: kalem\n• çente: çanta\n• dixwîne: okuyor\n• dinivîse: yazıyor', E'Bu eşyalarla okur ve yazarız. Okumak ve yazmak fiillerini şimdiki zamanda görüyoruz.', null::text),
  (4, E'Tiştên Polê:\n\nDi polê de ev tişt hene.\n\n• pol: sınıf\n• mase: masa\n• kursî: sandalye\n• text: kara tahta\n• çente: çanta\n• polê: sınıf (oblik; di polê de: sınıfta)', E'Sınıfta bu şeyler vardır. Yer için di/li + oblik gelir; pol dişil olduğu için hali polê.', null::text),
  (5, E'Di Polê de:\n\nEm di polê de çi dikin? Em hîn dibin.\n\n• ez dixwînim: okuyorum\n• ez dinivîsim: yazıyorum\n• guhdar dike: dinliyor\n• dibêje: söylüyor\n• mezin: büyük\n• biçûk: küçük', E'Sınıfta ne yaparız? Öğreniriz. Şimdiki zamanla çok basit cümleler kuruyoruz.', null::text)
) as s(ord, ku, tr, ex) where slug = 'dibistan'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Veguhestin
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Wesayîtên veguhestinê:\n\nEm bi wesayîtan diçin. Li jêr wesayîtên bingehîn hene:\n\n• otobus: otobüs\n• erebe: araba\n• trên: tren\n• balafir: uçak\n• taksî: taksi', E'Taşıtlarla gidiyoruz. Aşağıda temel taşıtlar var: otobüs, araba, tren, uçak ve taksi.', null::text),
  (2, E'Tu diçî ku derê?\n\nBi lêkera çûn em dibêjin em diçin ku derê:\n\n• ez diçim: gidiyorum\n• tu diçî: gidiyorsun\n• ew diçe: gidiyor\n• em diçin: gidiyoruz\n• hûn diçin: gidiyorsunuz\n• ew diçin: gidiyorlar', E'Çûn fiiliyle nereye gittiğimizi söylüyoruz: ez diçim gidiyorum, tu diçî gidiyorsun, ew diçe gidiyor, em diçin gidiyoruz, hûn diçin gidiyorsunuz, ew diçin gidiyorlar demektir.', null::text),
  (3, E'Bi çi diçî?\n\nBi + wesayît em dibêjin em bi çi diçin:\n\n• bi otobusê: otobüsle\n• bi erebeyê: arabayla\n• bi trênê: trenle\n• bi balafirê: uçakla\n• bi taksiyê: taksiyle', E'Bi + taşıt ile neyle gittiğimizi söylüyoruz: otobüsle, arabayla, trenle, uçakla, taksiyle.', null::text),
  (4, E'Bilêt û Rawestgeh:\n\nJi bo veguhestinê ev peyv girîng in:\n\n• bilêt: bilet\n• rawestgeh: durak\n• balafirgeh: havaalanı\n• rê: yol\n• rêwî: yolcu\n• ajokar: şoför', E'Ulaşım için bu sözcükler önemlidir: bilet, durak, havaalanı, yol, yolcu ve şoför.', null::text),
  (5, E'Diyaloga Hêsan:\n\nLi rawestgehê du kes diaxivin:\n\n• Silav!: Merhaba!\n• Tu diçî ku derê?: Nereye gidiyorsun?\n• Ez diçim Enqereyê.: Ankara’ya gidiyorum.\n• Bi çi diçî?: Neyle gidiyorsun?\n• Bi otobusê diçim.: Otobüsle gidiyorum.', E'Durakta iki kişi konuşuyor: selamlaşma, nereye gidiyorsun, Ankara’ya gidiyorum, neyle gidiyorsun, otobüsle gidiyorum.', null::text)
) as s(ord, ku, tr, ex) where slug = 'veguhestin'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Dema borî
insert into lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
select id, s.ord, s.ku, s.tr, s.ex from lessons, (values
  (1, E'Dema Borî Çi Ye?\n\nDema borî ji bo karên qediyayî ye. Em behsa duh û berê dikin. Mînak:\n\n• duh: dün\n• berê: önce\n• qediya: bitti\n• Ez çûm: Gittim\n• Min xwar: Yedim\n• Me ew dît: Onu gördük', E'Geçmiş zaman bitmiş işler içindir. Dünü ve öncesini anlatırız. Örnek: duh: dün / berê: önce / qediya: bitti / Ez çûm: Gittim / Min xwar: Yedim / Me ew dît: Onu gördük', null::text),
  (2, E'Çûn û Hatin:\n\nÇûn û hatin negerguhêz in, bi ez-tu-ew tên. Mînak:\n\n• ez çûm: gittim\n• tu çûyî: gittin\n• ew çû: gitti\n• ez hatim: geldim\n• tu hatî: geldin\n• ew hat: geldi\n• em çûn: gittik', E'çûn ve hatin geçişsizdir, ez-tu-ew zamirleriyle çekilir. Özne şimdiki zamandaki gibi yalın hâldedir. Örnek: ez çûm: gittim / tu çûyî: gittin / ew çû: gitti / ez hatim: geldim / tu hatî: geldin / ew hat: geldi / em çûn: gittik', null::text),
  (3, E'Xwarin û Dîtin - Ergativ:\n\nDi dema borî de lêkerên gerguhêz bi min, te, wî, wê û me tên. Mînak:\n\n• min xwar: yedim\n• te xwar: yedin\n• wî xwar: o yedi (erkek)\n• wê xwar: o yedi (kadın)\n• me xwar: yedik\n• min dît: gördüm\n• te dît: gördün', E'Geçmiş zamanda geçişli fiiller min, te, wî, wê ve me ile çekilir. ez yerine min, tu yerine te gelir. Nesne tekilse fiil xwar ve dît olarak kalır. Bu kurala ergatif denir. Örnek: min xwar: yedim / te xwar: yedin / wî xwar: o yedi (erkek) / wê xwar: o yedi (kadın) / me xwar: yedik / min dît: gördüm / te dît: gördün', null::text),
  (4, E'Bûn û Neyînî:\n\nBûn negerguhêz e, bi ez, tu û ew tê. Neyînî bi ne- ye. Mînak:\n\n• ez bûm: oldum\n• tu bûyî: oldun\n• ew bû: oldu\n• ez neçûm: gitmedim\n• tu nehatî: gelmedin\n• min nexwar: yemedim\n• min nedît: görmedim', E'bûn geçişsizdir ve ez, tu, ew ile çekilir. Olumsuzluk fiilin başına ne- getirerek yapılır. Geçişlide min nexwar, geçişsizde ez neçûm olur.', null::text),
  (5, E'Di Jiyana Rojane de:\n\nEm bi hevokên kurt dipeyivin. Mînak:\n\n• Duh ez çûm dibistanê: Dün okula gittim\n• Tu hatî malê: Eve geldin\n• Min nan xwar: Ekmek yedim\n• Te çay vexwar: Çay içtin\n• Ew mamoste bû: O öğretmendi', E'Kısa cümlelerle konuşuruz. Örnek: Duh ez çûm dibistanê: Dün okula gittim / Tu hatî malê: Eve geldin / Min nan xwar: Ekmek yedim / Te çay vexwar: Çay içtin / Ew mamoste bû: O öğretmendi', null::text)
) as s(ord, ku, tr, ex) where slug = 'dema-bori'
on conflict (lesson_id, order_in_lesson) do nothing;

-- Doğrulama
do $$
declare
  r record;
  v_count int;
begin
  for r in select * from (values
    ('pise', 5, 14),
    ('bajar', 5, 15),
    ('kirin', 5, 16),
    ('tenduristi', 5, 17),
    ('dibistan', 5, 18),
    ('veguhestin', 5, 19),
    ('dema-bori', 5, 20)
  ) as t(slug, expected_slides, expected_order) loop
    select count(*) into v_count from lesson_slides ls join lessons l on l.id = ls.lesson_id where l.slug = r.slug;
    if v_count <> r.expected_slides then
      raise exception 'dersler3: % slayt sayisi % (beklenen %)', r.slug, v_count, r.expected_slides;
    end if;
    if not exists (select 1 from lessons where slug = r.slug and category = 'everyday' and order_in_category = r.expected_order and language = 'ku') then
      raise exception 'dersler3: % kategori/sira beklenen degil', r.slug;
    end if;
    if exists (
      select 1 from lesson_slides ls join lessons l on l.id = ls.lesson_id
       where l.slug = r.slug
         and (ls.content_ku ~ '(^|[^.])\.\.([^.]|$)' or ls.content_tr ~ '(^|[^.])\.\.([^.]|$)'
              or ls.content_ku ~ '  ' or ls.content_tr ~ '  ')
    ) then
      raise exception 'dersler3: % slaytinda yazim artigi', r.slug;
    end if;
  end loop;
  if (select count(*) from lessons where category = 'everyday') <> 20 then
    raise exception 'dersler3: everyday ders sayisi 20 degil (dersler2 gocu uygulanmis mi?)';
  end if;
end
$$;

commit;
