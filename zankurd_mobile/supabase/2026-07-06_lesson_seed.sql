-- Faz D/E: Xwendina (Learning Zone) — Kurmancî ders içeriği seed
-- 8 kategori: everyday, grammar, culture, food, animals, geography, emotions, time
-- Idempotent: slug üzerinden ON CONFLICT DO NOTHING

-- ============================================================================
-- LESSONS
-- ============================================================================

INSERT INTO lessons (slug, title_ku, title_tr, description_ku, category, icon_name, order_in_category, language) VALUES
  -- everyday (Roj-beroj)
  ('silav-u-nasin',   'Silav û Nasîn',    'Selamlaşma ve Tanışma', 'Silavkirin û xwe dan nasîn',        'everyday',  'waving_hand', 1, 'ku'),
  ('hejmar',          'Hejmar',           'Sayılar',               'Hejmarên bingehîn 1-1000',          'everyday',  'numbers',     2, 'ku'),
  -- grammar (Gramer)
  ('cinavk',          'Cînavk',           'Zamirler',              'Cînavkên kesane',                   'grammar',   'person',      1, 'ku'),
  ('lekera-bun',      'Lêkera "bûn"',     'Olmak Fiili',           'Lêkera bûn di dema niha de',        'grammar',   'link',        2, 'ku'),
  -- culture (Çand)
  ('newroz',          'Newroz',           'Newroz',                'Cejna Newrozê û wateya wê',         'culture',   'local_fire_department', 1, 'ku'),
  ('dengbeji',        'Dengbêjî',         'Dengbejlik',            'Hunera dengbêjiyê',                 'culture',   'music_note',  2, 'ku'),
  -- food (Xwarin)
  ('xwarinen-kurdi',  'Xwarinên Kurdî',   'Kürt Yemekleri',        'Xwarinên gelêrî yên kurdan',        'food',      'restaurant',  1, 'ku'),
  ('feki-u-sebze',    'Fêkî û Sebze',     'Meyve ve Sebze',        'Navên fêkî û sebzeyan',             'food',      'eco',         2, 'ku'),
  -- animals (Ajal)
  ('ajalen-male',     'Ajalên Malê',      'Evcil Hayvanlar',       'Ajalên ku li malê tên xwedîkirin',  'animals',   'pets',        1, 'ku'),
  ('ajalen-kovi',     'Ajalên Kovî',      'Yabani Hayvanlar',      'Ajalên çolê û daristanê',           'animals',   'forest',      2, 'ku'),
  -- geography (Cografya)
  ('ciya-u-cem',      'Çiya û Çem',       'Dağlar ve Nehirler',    'Çiya, çem û golên navdar',          'geography', 'landscape',   1, 'ku'),
  ('cih-u-war',       'Cih û War',        'Yer ve Mekan',          'Peyvên cografyayê yên bingehîn',    'geography', 'map',         2, 'ku'),
  -- emotions (Hest)
  ('hesten-bingehin', 'Hestên Bingehîn',  'Temel Duygular',        'Navên hestan û bikaranîna wan',     'emotions',  'favorite',    1, 'ku'),
  -- time (Dem)
  ('rojen-hefteye',   'Rojên Hefteyê',    'Haftanın Günleri',      'Heft rojên hefteyê',                'time',      'calendar_today', 1, 'ku'),
  ('demsal',          'Demsal',           'Mevsimler',             'Çar demsalên salê',                 'time',      'wb_sunny',    2, 'ku')
ON CONFLICT (slug) DO NOTHING;

-- ============================================================================
-- LESSON SLIDES
-- ============================================================================

-- Silav û Nasîn
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'Silav! / Rojbaş!', 'Selam! / İyi günler!', 'Silav heval! Rojbaş mamoste!'),
  (2, 'Tu çawa yî? — Ez baş im, spas.', 'Nasılsın? — İyiyim, teşekkürler.', 'Tu çawa yî? Ez gelek baş im, tu çawa yî?'),
  (3, 'Navê te çi ye? — Navê min Azad e.', 'Adın ne? — Benim adım Azad.', 'Navê te çi ye? Navê min Rojîn e.'),
  (4, 'Ez ji Amedê me. Tu ji ku derê yî?', 'Ben Diyarbakır''lıyım. Sen nerelisin?', 'Ez ji Wanê me. Ew ji Mêrdînê ye.'),
  (5, 'Bi xatirê te! — Oxir be!', 'Hoşça kal! — Güle güle!', 'Bi xatirê te heval, sibê em ê hev bibînin.')
) AS s(ord, ku, tr, ex) WHERE slug = 'silav-u-nasin'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Hejmar
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'yek (1), du (2), sê (3), çar (4), pênc (5)', 'bir, iki, üç, dört, beş', 'Min sê sêv kirîn.'),
  (2, 'şeş (6), heft (7), heşt (8), neh (9), deh (10)', 'altı, yedi, sekiz, dokuz, on', 'Deh xwendekar li polê ne.'),
  (3, 'bîst (20), sî (30), çil (40), pêncî (50)', 'yirmi, otuz, kırk, elli', 'Bavê min çil salî ye.'),
  (4, 'şêst (60), heftê (70), heştê (80), nod (90)', 'altmış, yetmiş, seksen, doksan', 'Dapîra min heştê salî ye.'),
  (5, 'sed (100), hezar (1000)', 'yüz, bin', 'Di pirtûkxaneyê de hezar pirtûk hene.')
) AS s(ord, ku, tr, ex) WHERE slug = 'hejmar'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Cînavk
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'ez — ben, tu — sen, ew — o', 'Tekil şahıs zamirleri', 'Ez diçim dibistanê. Tu li malê yî.'),
  (2, 'em — biz, hûn — siz, ew — onlar', 'Çoğul şahıs zamirleri', 'Em kurdî hîn dibin. Hûn ji ku ne?'),
  (3, 'min, te, wî/wê — bükümlü hal (tewandî)', 'Geçmiş zamanda ve tamlamada kullanılır', 'Min nan xwar. Pirtûka te xweş e.'),
  (4, 'me, we, wan — bükümlü çoğul', 'Çoğul bükümlü zamirler', 'Me govend girt. Mala wan mezin e.')
) AS s(ord, ku, tr, ex) WHERE slug = 'cinavk'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Lêkera bûn
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'Ez ... im / me — Ben ...im', 'Sesli harften sonra "me", sessizden sonra "im"', 'Ez mamoste me. Ez kurd im.'),
  (2, 'Tu ... î / yî — Sen ...sin', 'Sesli harften sonra "yî"', 'Tu xwendekar î. Tu baş î.'),
  (3, 'Ew ... e / ye — O ...dir', 'Sesli harften sonra "ye"', 'Ew doktor e. Navê wî Zana ye.'),
  (4, 'Em/Hûn/Ew ... in / ne — çoğul', 'Sesli harften sonra "ne"', 'Em heval in. Hûn mamoste ne.')
) AS s(ord, ku, tr, ex) WHERE slug = 'lekera-bun'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Newroz
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'Newroz cejna nû ya salê ye.', 'Newroz yılın yeni günü bayramıdır.', 'Newroz pîroz be!'),
  (2, 'Newroz di 21ê Adarê de tê pîrozkirin.', 'Newroz 21 Mart''ta kutlanır.', 'Di 21ê Adarê de em diçin çiyê.'),
  (3, 'Agir sembola Newrozê ye.', 'Ateş Newroz''un sembolüdür.', 'Xort agirê Newrozê pêdixin.'),
  (4, 'Li Newrozê govend tê girtin û stran tên gotin.', 'Newroz''da halay çekilir ve şarkılar söylenir.', 'Em bi hev re govendê digirin.')
) AS s(ord, ku, tr, ex) WHERE slug = 'newroz'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Dengbêjî
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'Dengbêj stranbêjên gelêrî ne.', 'Dengbejler halk ozanlarıdır.', 'Dengbêj bi dengê xwe dîrokê vedibêjin.'),
  (2, 'Dengbêjî bê amûr, tenê bi deng tê kirin.', 'Dengbejlik enstrümansız, sadece sesle yapılır.', 'Dengê dengbêjan ji dil tê.'),
  (3, 'Evdalê Zeynikê dengbêjekî navdar e.', 'Evdalê Zeynikê ünlü bir dengbejdir.', 'Kilamên Evdalê Zeynikê hîn tên gotin.'),
  (4, 'Kilam çîrokên evîn û şer vedibêjin.', 'Kilamlar aşk ve savaş hikayeleri anlatır.', 'Dapîra min kilamên kevn dizane.')
) AS s(ord, ku, tr, ex) WHERE slug = 'dengbeji'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Xwarinên Kurdî
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'nan — ekmek, av — su, çay — çay', 'Temel yiyecek içecekler', 'Nanê germ xweş e. Çayekê vexwe!'),
  (2, 'Kutilk xwarineke kurdî ya navdar e.', 'İçli köfte ünlü bir Kürt yemeğidir.', 'Diya min kutilkan çêdike.'),
  (3, 'Dolme bi pelên tirî tê çêkirin.', 'Dolma asma yaprağıyla yapılır.', 'Dolmeyên dapîrê pir xweş in.'),
  (4, 'şorbe — çorba, birinc — pirinç, goşt — et', 'Ana yemek kelimeleri', 'Di zivistanê de şorbe germ dike.')
) AS s(ord, ku, tr, ex) WHERE slug = 'xwarinen-kurdi'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Fêkî û Sebze
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'sêv — elma, tirî — üzüm, hinar — nar', 'Yaygın meyveler', 'Sêvên sor şîrîn in.'),
  (2, 'zebeş — karpuz, gundor — kavun, xox — şeftali', 'Yaz meyveleri', 'Di havînê de zebeş tê xwarin.'),
  (3, 'bacanê sor — domates, pîvaz — soğan, sîr — sarımsak', 'Temel sebzeler', 'Bacanê sor û pîvaz bike seletê.'),
  (4, 'kartol — patates, îsot — biber, xiyar — salatalık', 'Diğer sebzeler', 'Îsotên Amedê tûj in!')
) AS s(ord, ku, tr, ex) WHERE slug = 'feki-u-sebze'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Ajalên Malê
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'pisîk — kedi, kûçik — köpek', 'En yaygın evcil hayvanlar', 'Pisîka min spî ye.'),
  (2, 'hesp — at, ker — eşek, hêstir — katır', 'Binek hayvanları', 'Hesp ajalekî bedew e.'),
  (3, 'mî — koyun, bizin — keçi, çêlek — inek', 'Çiftlik hayvanları', 'Şivan mîhan diçêrîne.'),
  (4, 'mirîşk — tavuk, dîk — horoz, qaz — kaz', 'Kümes hayvanları', 'Dîk serê sibê bang dide.')
) AS s(ord, ku, tr, ex) WHERE slug = 'ajalen-male'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Ajalên Kovî
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'gur — kurt, hirç — ayı, rovî — tilki', 'Orman hayvanları', 'Gur di zivistanê de birçî dibin.'),
  (2, 'şêr — aslan, piling — kaplan', 'Yırtıcı hayvanlar', 'Şêr padîşahê ajalan e.'),
  (3, 'kew — keklik, teyr — kuş, baz — şahin', 'Kuşlar', 'Kew li çiyayên Kurdistanê dijîn.'),
  (4, 'kêvroşk — tavşan, xezal — ceylan', 'Küçük yabani hayvanlar', 'Xezal pir bilez direve.')
) AS s(ord, ku, tr, ex) WHERE slug = 'ajalen-kovi'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Çiya û Çem
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'Çiyayê Agiriyê (Ararat) çiyayê herî bilind e.', 'Ağrı Dağı en yüksek dağdır.', 'Çiyayê Agiriyê 5137 metre bilind e.'),
  (2, 'Ferat û Dîcle du çemên mezin in.', 'Fırat ve Dicle iki büyük nehirdir.', 'Dîcle di nav Amedê re derbas dibe.'),
  (3, 'Gola Wanê gola herî mezin e.', 'Van Gölü en büyük göldür.', 'Gola Wanê pir kûr e.'),
  (4, 'Çiyayê Cûdî û Çiyayê Şingalê navdar in.', 'Cudi Dağı ve Sincar Dağı ünlüdür.', 'Li ser Cûdî berf heye.')
) AS s(ord, ku, tr, ex) WHERE slug = 'ciya-u-cem'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Cih û War
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'bajar — şehir, gund — köy', 'Yerleşim yerleri', 'Ez li bajêr dijîm, bavê min li gund.'),
  (2, 'çiya — dağ, deşt — ova, gelî — vadi', 'Yeryüzü şekilleri', 'Di geliyê de çemek diherike.'),
  (3, 'çem — nehir, gol — göl, derya — deniz', 'Su kaynakları', 'Zarok li ber çêm dilîzin.'),
  (4, 'daristan — orman, çol — çöl, zozan — yayla', 'Doğal alanlar', 'Di havînê de em diçin zozanan.')
) AS s(ord, ku, tr, ex) WHERE slug = 'cih-u-war'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Hestên Bingehîn
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'kêfxweş — mutlu, xemgîn — üzgün', 'Temel duygular', 'Ez îro pir kêfxweş im.'),
  (2, 'hêrs — öfke, tirs — korku', 'Güçlü duygular', 'Ji tariyê netirse!'),
  (3, 'evîn — aşk, hezkirin — sevgi', 'Sevgi ifadeleri', 'Ez ji te hez dikim.'),
  (4, 'westiyayî — yorgun, birçî — aç, têr — tok', 'Fiziksel durumlar', 'Ez westiyayî me û birçî me.')
) AS s(ord, ku, tr, ex) WHERE slug = 'hesten-bingehin'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Rojên Hefteyê
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'Duşem, Sêşem, Çarşem', 'Pazartesi, Salı, Çarşamba', 'Roja Duşemê dibistan dest pê dike.'),
  (2, 'Pêncşem, În', 'Perşembe, Cuma', 'Roja Înê em diçin bazarê.'),
  (3, 'Şemî, Yekşem', 'Cumartesi, Pazar', 'Şemî û Yekşem betlane ne.'),
  (4, 'îro — bugün, sibê — yarın, duh — dün', 'Zaman zarfları', 'Îro Çarşem e, sibê Pêncşem e.')
) AS s(ord, ku, tr, ex) WHERE slug = 'rojen-hefteye'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;

-- Demsal
INSERT INTO lesson_slides (lesson_id, order_in_lesson, content_ku, content_tr, example_ku)
SELECT id, s.ord, s.ku, s.tr, s.ex FROM lessons, (VALUES
  (1, 'bihar — ilkbahar', 'Çiçeklerin açtığı mevsim', 'Di biharê de Newroz tê.'),
  (2, 'havîn — yaz', 'En sıcak mevsim', 'Di havînê de em diçin zozanan.'),
  (3, 'payîz — sonbahar', 'Yaprakların döküldüğü mevsim', 'Di payîzê de pelên daran diweşin.'),
  (4, 'zivistan — kış', 'Karlı ve soğuk mevsim', 'Di zivistanê de berf dibare.')
) AS s(ord, ku, tr, ex) WHERE slug = 'demsal'
ON CONFLICT (lesson_id, order_in_lesson) DO NOTHING;
