# -*- coding: utf-8 -*-
"""ZanKurd editoryal soru bankası üreteci (2026-07-24).

Çıktı: lib/src/data/editorial_question_bank.dart
Çalıştırma: python3 tools/build_editorial_question_bank.py (repo kökünden:
zankurd_mobile/ içinde). Yeni soru eklemek için aşağıdaki q(...) çağrılarına
ekleyip yeniden çalıştırın; ardından `dart format` gerekir.


Kompakt tuple listesinden geçerli Dart kaynağı üretir.
Alan sırası: (kategori, zorluk, tip, prompt, [şıklar], dogru, ku_aciklama, tr_aciklama, kaynak)
tip: 'mc' | 'tf'
"""
import io, unicodedata

FERHENG = 'ferheng'
REZIMAN = 'reziman'
DIROK = 'dirok'
WEJE = 'weje'
COGRAFYA = 'cografya'
MUZIK = 'muzik'
FOLKLOR = 'folklor'
SIYASET = 'siyaset'
PARADIGMA = 'paradigma'

Q = []
def q(cat, diff, typ, prompt, answers, correct, ku, tr, src):
    Q.append((cat, diff, typ, prompt, answers, correct, ku, tr, src))

# ─────────────────────────── ZIMAN ───────────────────────────
q('Ziman',1,'mc','Alfabeya Kurdî ya latînî ji çend tîpan pêk tê?',
  ['31','29','26','34'],'31',
  'Alfabeya kurdî ya latînî 31 tîpan dihewîne: 8 dengdêr û 23 dengdar.',
  'Kürtçe Latin alfabesi 31 harften oluşur: 8 sesli, 23 sessiz.',REZIMAN)
q('Ziman',2,'mc','Alfabeya latînî ya Kurmancî ji aliyê kê ve hat sîstematîzekirin?',
  ['Celadet Alî Bedirxan','Ehmedê Xanî','Melayê Cizîrî','Feqiyê Teyran'],'Celadet Alî Bedirxan',
  'Celadet Alî Bedirxan di salên 1930î de alfabeya latînî ya kurdî sîstematîze kir û di kovara Hawarê de belav kir.',
  'Celadet Ali Bedirhan 1930\'larda Kürtçe Latin alfabesini sistemleştirdi ve Hawar dergisinde yaydı.',REZIMAN)
q('Ziman',1,'mc','Di alfabeya kurdî ya latînî de çend dengdêr (vowel) hene?',
  ['8','5','6','10'],'8',
  'Dengdêrên kurdî ev in: a, e, ê, i, î, o, u, û.',
  'Kürtçedeki sesliler şunlardır: a, e, ê, i, î, o, u, û.',REZIMAN)
q('Ziman',3,'mc','Di Kurmancî de girêdana navdêr bi rengdêr an bi navdêreke din re bi çi tê çêkirin?',
  ['Veqetandek (izafe)','Daçek','Cînav','Bêjeya pirsê'],'Veqetandek (izafe)',
  'Veqetandek (izafe) navdêrê bi rengdêr an navdêreke din ve girê dide: "kitêb-a min", "mal-a mezin".',
  'İzafe (veqetandek) ismi sıfata veya başka bir isme bağlar: "kitêba min", "mala mezin".',REZIMAN)
q('Ziman',3,'mc','Di Kurmancî de peyva "jin" ji kîjan zayendê ye?',
  ['Mê','Nêr','Bêzayend','Herdu jî'],'Mê',
  'Di Kurmancî de her navdêr zayendek digire; "jin" mê ye, loma veqetandeka wê "-a" ye: "jina baş".',
  'Kurmancî\'de her isim bir cinsiyet alır; "jin" dişildir, bu yüzden izafesi "-a" olur: "jina baş".',REZIMAN)
q('Ziman',3,'mc','Nîşana pirjimariyê ya rewşa tewandî (oblique) di Kurmancî de kîjan e?',
  ['-an','-ek','-ê','-ne'],'-an',
  'Di rewşa tewandî de navdêrên pirjimar "-an" digirin: "Ez pirtûk-an dixwînim".',
  'Bükünlü (oblique) durumda çoğul isimler "-an" alır: "Ez pirtûkan dixwînim".',REZIMAN)
q('Ziman',2,'mc','Lêkera "kirin" di dema niha de ji bo kesê sêyemîn ê yekjimar çawa tê kişandin?',
  ['Ew dike','Ew kir','Ew bike','Ew kiriye'],'Ew dike',
  'Dema niha bi pêşgira "di-" tê çêkirin: di- + k(ir) + -e = dike.',
  'Şimdiki zaman "di-" ön ekiyle kurulur: di- + k(ir) + -e = dike.',REZIMAN)
q('Ziman',4,'mc','Di Kurmancî de "ergatîf" çi tê wateyê?',
  ['Di dema borî ya lêkerên gerguhêz de bikerê tewandî','Nîşana pirjimariyê',
   'Cureyekî daçekê','Rengdêreke pêşgirtî'],'Di dema borî ya lêkerên gerguhêz de bikerê tewandî',
  'Ergatîf: di dema borî de bi lêkerên gerguhêz re biker tê tewandin û lêker li gorî bireserê tê kişandin — "Min pirtûk xwend".',
  'Ergatif: geçmiş zamanda geçişli fiillerde özne büküme girer ve fiil nesneye göre çekimlenir — "Min pirtûk xwend".',REZIMAN)
q('Ziman',2,'mc','Peyva "rojname" ji kîjan du peyvan pêk tê?',
  ['Roj + name','Ro + jname','Rojan + me','Roja + nem'],'Roj + name',
  '"Roj" (roj/tav) û "name" (nivîs) tên cem hev: nivîsa rojane.',
  '"Roj" (gün) ve "name" (yazı) birleşir: günlük yazı, yani gazete.',FERHENG)
q('Ziman',1,'mc','Peyva Kurmancî "av" bi Tirkî çi tê wateyê?',
  ['su','ateş','ekmek','taş'],'su',
  '"Av" bi Tirkî "su" ye.','"Av" Türkçede "su" demektir.',FERHENG)
q('Ziman',1,'mc','Peyva Kurmancî "hesp" bi Tirkî çi tê wateyê?',
  ['at','köpek','kuş','koyun'],'at',
  '"Hesp" bi Tirkî "at" e.','"Hesp" Türkçede "at" demektir.',FERHENG)
q('Ziman',2,'mc','Peyva Kurmancî "zanîn" bi Tirkî çi tê wateyê?',
  ['bilmek','görmek','gitmek','almak'],'bilmek',
  '"Zanîn" bi Tirkî "bilmek" e; navê sepanê jî ji vê koka "zan" tê.',
  '"Zanîn" Türkçede "bilmek" demektir; uygulamanın adı da bu "zan" kökünden gelir.',FERHENG)
q('Ziman',2,'mc','Hevwateya peyva "dilgeş" di Kurmancî de kîjan e?',
  ['Şa','Xemgîn','Westiyayî','Tirsonek'],'Şa',
  '"Dilgeş" û "şa" herdu jî kêfxweşiyê nîşan didin.',
  '"Dilgeş" ve "şa" ikisi de neşeli/sevinçli anlamına gelir.',FERHENG)
q('Ziman',3,'mc','Dijwateya peyva "germ" di Kurmancî de kîjan e?',
  ['Sar','Nerm','Tarî','Giran'],'Sar',
  '"Germ" û "sar" dijwate ne.','"Germ" (sıcak) ile "sar" (soğuk) zıt anlamlıdır.',FERHENG)
q('Ziman',4,'mc','Di Kurmancî de "daçek" (preposition/postposition) çi ye?',
  ['Peyvên wek "di, bi, ji, li" yên ku têkiliya navdêran diyar dikin',
   'Nîşana zayendê','Cureyekî lêkerê','Paşgira pirjimariyê'],
  'Peyvên wek "di, bi, ji, li" yên ku têkiliya navdêran diyar dikin',
  'Daçek têkiliya di navbera navdêr û beşên din ên hevokê de diyar dike: "li malê", "bi destan".',
  'Edatlar isimle cümlenin diğer öğeleri arasındaki ilişkiyi belirtir: "li malê", "bi destan".',REZIMAN)
q('Ziman',5,'mc','Di Kurmancî de "raweya fermanî" ya lêkera "hatin" ji bo kesê duyemîn ê yekjimar kîjan e?',
  ['Were','Hat','Tê','Hatiye'],'Were',
  'Raweya fermanî ya "hatin" bi awayê "were" (tu) û "werin" (hûn) tê bikaranîn.',
  '"Hatin" fiilinin emir kipi "were" (sen) ve "werin" (siz) şeklindedir.',REZIMAN)
q('Ziman',2,'tf','Rast e an şaş e: Di Kurmancî de tîpa "Q" heye.',
  ['Rast','Şaş'],'Rast',
  'Erê, tîpa "q" di alfabeya kurdî de heye: "qelem", "qij".',
  'Evet, Kürtçe alfabede "q" harfi vardır: "qelem", "qij".',REZIMAN)
q('Ziman',3,'tf','Rast e an şaş e: Kurmancî yek ji sê zaravayên sereke yên kurdî ye.',
  ['Rast','Şaş'],'Rast',
  'Kurmancî, Soranî û Zazakî (Kirmanckî) di nav zaravayên sereke de tên hejmartin.',
  'Kurmancî, Soranî ve Zazaca (Kirmanckî) ana lehçeler arasında sayılır.',REZIMAN)
q('Ziman',4,'mc','Kovara "Hawar" bi taybetî ji bo çi girîng e?',
  ['Belavkirina alfabeya latînî ya kurdî','Yekem romana kurdî',
   'Yekem albûma muzîkê','Ferhenga yekem a kurdî'],'Belavkirina alfabeya latînî ya kurdî',
  'Hawar (1932, Şam) alfabeya latînî ya kurdî belav kir û bû dibistana zimanê kurdî ya nûjen.',
  'Hawar (1932, Şam) Kürtçe Latin alfabesini yaydı ve modern Kürtçenin okulu oldu.',REZIMAN)
q('Ziman',5,'mc','Di Kurmancî de cudahiya "min" û "ez" çi ye?',
  ['"Ez" rewşa xwerû, "min" rewşa tewandî ye','Herdu jî heman in',
   '"Min" pirjimar e','"Ez" tenê di dema borî de tê bikaranîn'],
  '"Ez" rewşa xwerû, "min" rewşa tewandî ye',
  '"Ez diçim" (xwerû) lê "Min got" (tewandî) — rewş li gorî dem û gerguhêziya lêkerê diguhere.',
  '"Ez diçim" (yalın) ama "Min got" (bükünlü) — durum, fiilin zamanına ve geçişliliğine göre değişir.',REZIMAN)

# ─────────────────────────── ÇAND ───────────────────────────
q('Çand',1,'mc','Newroz her sal di kîjan rojê de tê pîrozkirin?',
  ['21ê Adarê','1ê Gulanê','21ê Îlonê','1ê Çileyê'],'21ê Adarê',
  'Newroz, cejna serê biharê, her sal di 21ê Adarê de tê pîrozkirin.',
  'Nevruz, baharın başlangıcı bayramı, her yıl 21 Mart\'ta kutlanır.',FOLKLOR)
q('Çand',2,'mc','Li gorî efsaneya Newrozê, Kawa pîşeya wî çi bû?',
  ['Hesinker','Şivan','Cotkar','Bazirgan'],'Hesinker',
  'Kawayê Hesinker li dijî Dehaq rabû û serkeftina wî bi agirê Newrozê tê nîşankirin.',
  'Demirci Kawa, Dehak\'a karşı ayaklandı; zaferi Nevruz ateşiyle simgelenir.',FOLKLOR)
q('Çand',1,'mc','Reqsa gelêrî ya kurdî ya ku bi destgirtin û bi rêz tê kirin çi ye?',
  ['Govend','Semah','Zeybek','Horon'],'Govend',
  'Govend reqsa komî ya kurdî ye; mirov bi destan digirin û bi rêz dilîzin.',
  'Govend, elele ve sıra hâlinde oynanan Kürt halk dansıdır.',FOLKLOR)
q('Çand',3,'mc','Di çanda kurdî de "tiştonek" çi ye?',
  ['Mamik / bilmece','Stranek dînî','Cureyekî xwarinê','Reqsek gelêrî'],'Mamik / bilmece',
  'Tiştonek pirsên jîrekiyê ne ku di şevbihêrkan de tên gotin.',
  'Tiştonek, kış sohbetlerinde sorulan zekâ bilmeceleridir.',FOLKLOR)
q('Çand',2,'mc','Cilê jinan ê kurdî yê ku li ser serî tê girêdan û bi pûl tê xemilandin bi giştî çi navê digire?',
  ['Klîtik / kofî','Şal û şapik','Kras','Şûtik'],'Klîtik / kofî',
  'Kofî serpoşa jinan a kevneşopî ye û li gorî herêman bi pûl û zêran tê xemilandin.',
  'Kofî, kadınların geleneksel başlığıdır; yöreye göre pul ve altınla süslenir.',FOLKLOR)
q('Çand',2,'mc','Di kevneşopiya kurdî de "şevbihêrk" çi ye?',
  ['Civîna şevê ya çîrok û stranan','Cejna zewacê','Rêûresma şînê','Bazara heftane'],
  'Civîna şevê ya çîrok û stranan',
  'Şevbihêrk civîna şevên zivistanê ye: çîrok, tiştonek û stran tên gotin.',
  'Şevbihêrk, kış gecelerinde hikâye, bilmece ve türkülerin paylaşıldığı toplantıdır.',FOLKLOR)
q('Çand',3,'mc','Xwarina kurdî ya ku ji savar û goşt tê çêkirin û bi destan tê gilover kirin çi ye?',
  ['Kutilk','Dolme','Sarma','Kadayîf'],'Kutilk',
  'Kutilk (îçli kufte) ji savarê tê çêkirin û bi goştê hûrkirî tê dagirtin.',
  'Kutilk (içli köfte) bulgurdan yapılır, kıymayla doldurulur.',FOLKLOR)
q('Çand',4,'mc','Di çanda kurdî de "heval" bi giştî çi tê wateyê?',
  ['Hogir / dost','Cîran','Xizm','Mêvan'],'Hogir / dost',
  '"Heval" wateya dostî û hevkariyê dihewîne.',
  '"Heval" arkadaş/yoldaş anlamını taşır.',FOLKLOR)
q('Çand',3,'mc','Destana "Mem û Zîn" bi giştî çîroka çi ye?',
  ['Evîna Mem û Zînê ya ku nagihîje hev','Şerekî navxweyî',
   'Rêwîtiya bazirganekî','Damezrandina bajarekî'],'Evîna Mem û Zînê ya ku nagihîje hev',
  'Mem û Zîn evîndarên ku nagihîjin hev in; Ehmedê Xanî ev destan di 1692an de nivîsî.',
  'Mem û Zîn, kavuşamayan âşıkların hikâyesidir; Ehmedê Xanî 1692\'de yazdı.',WEJE)
q('Çand',2,'tf','Rast e an şaş e: Newroz tenê ji aliyê kurdan ve tê pîrozkirin.',
  ['Şaş','Rast'],'Şaş',
  'Newroz li gelek welatan — Îran, Afxanistan, Azerbaycan, Asyaya Navîn — jî tê pîrozkirin.',
  'Nevruz İran, Afganistan, Azerbaycan ve Orta Asya\'da da kutlanır.',FOLKLOR)
q('Çand',4,'mc','Di dawetên kurdî de "berbû" kî ne?',
  ['Kesên ku bûkê ji mala wê tînin','Muzîkjenên dawetê',
   'Mêvanên ji dûr','Xwarinçêkerên dawetê'],'Kesên ku bûkê ji mala wê tînin',
  'Berbû ew koma xizm û dostan e ku diçe bûkê tîne.',
  'Berbû, gelini evinden almaya giden akraba ve dost topluluğudur.',FOLKLOR)
q('Çand',5,'mc','Rêûresma "kirîvatî" di civaka kurdî de çi ye?',
  ['Girêdana malbatan bi rêya sinetê','Peymana bazirganiyê',
   'Rêûresma şînê','Hilbijartina rîspiyan'],'Girêdana malbatan bi rêya sinetê',
  'Kirîv di rêûresma sinetê de rola bavê duyemîn digire; du malbat bi vî awayî xizm dibin.',
  'Kirve, sünnet töreninde ikinci baba rolündedir; iki aile böylece hısım olur.',FOLKLOR)
q('Çand',1,'mc','Rengên ku bi gelemperî di ala kurdî de derbas dibin kîjan in?',
  ['Sor, spî, kesk û zer','Şîn, spî û sor','Reş, spî û kesk','Zer, mor û sor'],
  'Sor, spî, kesk û zer',
  'Ala kurdî ji sê rengên horizontal — sor, spî, kesk — û rojeke zer a navendî pêk tê.',
  'Kürt bayrağı kırmızı, beyaz, yeşil şeritler ve ortadaki sarı güneşten oluşur.',FOLKLOR)
q('Çand',3,'mc','Di çanda kurdî de "gotinên pêşiyan" çi ne?',
  ['Atasözleri','Stranên dînî','Navên gundan','Rêzikên rêzimanî'],'Atasözleri',
  'Gotinên pêşiyan ezmûna gel a bi hevokên kurt tê veguhastin.',
  'Gotinên pêşiyan, halkın deneyimini kısa cümlelerle aktaran atasözleridir.',FOLKLOR)
q('Çand',2,'mc','Xwarina "dew" ji çi tê çêkirin?',
  ['Mast û av','Ard û av','Şîr û şekir','Genim û rûn'],'Mast û av',
  'Dew mast û ava tevlihev e; bi taybetî di havînê de tê vexwarin.',
  'Dew (ayran), yoğurt ve suyun karışımıdır; özellikle yazın içilir.',FOLKLOR)
q('Çand',4,'mc','Di kevneşopiya kurdî de "rîspî" kî ye?',
  ['Kesê pîr ê bi rûmet ê ku pirsgirêkan çareser dike','Serokê eşîretê yê leşkerî',
   'Mamosteyê dibistanê','Bazirganê gund'],
  'Kesê pîr ê bi rûmet ê ku pirsgirêkan çareser dike',
  'Rîspî di civakê de rola navbeynkariyê digire û nakokiyan çareser dike.',
  'Rîspî (aksakal), toplumda arabuluculuk yapan, anlaşmazlıkları çözen saygın yaşlıdır.',FOLKLOR)

# ─────────────────────────── DÎROK ───────────────────────────
q('Dîrok',2,'mc','Kovara "Hawar" di kîjan salê de dest bi weşanê kir?',
  ['1932','1898','1945','1960'],'1932',
  'Hawar di 15ê Gulana 1932yan de li Şamê ji aliyê Celadet Alî Bedirxan ve hat weşandin.',
  'Hawar, 15 Mayıs 1932\'de Şam\'da Celadet Ali Bedirhan tarafından yayımlandı.',DIROK)
q('Dîrok',3,'mc','Yekem rojnameya kurdî "Kurdistan" di kîjan salê û li ku derê hat weşandin?',
  ['1898, Qahîre','1908, Stenbol','1920, Bexda','1932, Şam'],'1898, Qahîre',
  'Rojnameya "Kurdistan" di 22ê Nîsana 1898an de li Qahîreyê ji aliyê Miqdad Midhet Bedirxan ve hat weşandin.',
  '"Kurdistan" gazetesi 22 Nisan 1898\'de Kahire\'de Mikdat Mithat Bedirhan tarafından çıkarıldı.',DIROK)
q('Dîrok',1,'mc','Selahedînê Eyûbî bi taybetî bi çi tê nasîn?',
  ['Vegirtina Qudsê di 1187an de','Damezrandina Împeratoriya Osmanî',
   'Nivîsandina Mem û Zînê','Vedîtina alfabeya kurdî'],'Vegirtina Qudsê di 1187an de',
  'Selahedînê Eyûbî yê bi eslê xwe kurd, di 1187an de Qudsê vegirt û Dewleta Eyûbiyan damezrand.',
  'Kürt kökenli Selahaddin Eyyubi 1187\'de Kudüs\'ü aldı ve Eyyubi Devleti\'ni kurdu.',DIROK)
q('Dîrok',3,'mc','Peymana Lozanê di kîjan salê de hat îmzekirin?',
  ['1923','1920','1918','1932'],'1923',
  'Peymana Lozanê di 24ê Tîrmeha 1923yan de hat îmzekirin û şûna Peymana Sevrê girt.',
  'Lozan Antlaşması 24 Temmuz 1923\'te imzalandı ve Sevr\'in yerini aldı.',DIROK)
q('Dîrok',4,'mc','Peymana Sevrê (1920) ji bo kurdan çima tê gotin ku girîng e?',
  ['Ji bo herêmeke kurdî ya xweser madde dihewand','Alfabeya kurdî fermî kir',
   'Dewleteke kurdî damezrand','Kovara Hawarê destûr kir'],
  'Ji bo herêmeke kurdî ya xweser madde dihewand',
  'Sevr xweseriyeke mimkun ji bo kurdan pêşniyar dikir, lê peyman nehat sepandin.',
  'Sevr, Kürtler için olası bir özerklik maddesi içeriyordu ancak antlaşma uygulanmadı.',DIROK)
q('Dîrok',2,'mc','Împeratoriya Medan bi giştî di kîjan sedsalê de hat damezrandin?',
  ['Sedsala 7em a berî zayînê','Sedsala 3em a piştî zayînê',
   'Sedsala 12em','Sedsala 1em a berî zayînê'],'Sedsala 7em a berî zayînê',
  'Med di sedsala 7em a b.z. de li rojhilata Anatolyayê û rojavayê Îranê dewletek ava kirin.',
  'Medler M.Ö. 7. yüzyılda Doğu Anadolu ve Batı İran\'da bir devlet kurdular.',DIROK)
q('Dîrok',4,'mc','Ehmedê Xanî "Mem û Zîn" di kîjan salê de nivîsî?',
  ['1692','1592','1792','1892'],'1692',
  'Ehmedê Xanî Mem û Zîn di 1692an de temam kir; berhem hem evîndarî hem jî hişmendiya netewî dihewîne.',
  'Ehmedê Xanî, Mem û Zîn\'i 1692\'de tamamladı; eser hem aşkı hem ulusal bilinci işler.',WEJE)
q('Dîrok',3,'mc','Mîrektiya Botan bi kîjan navendê tê nasîn?',
  ['Cizîr','Hewlêr','Sanandaj','Kirmanşan'],'Cizîr',
  'Mîrektiya Botan navenda xwe Cizîra Botan bû; Bedirxan Beg mîrê wê yê navdar e.',
  'Botan Emirliği\'nin merkezi Cizre idi; ünlü emiri Bedirhan Bey\'dir.',DIROK)
q('Dîrok',5,'mc','"Şerefname" ya Şerefxanê Bidlîsî çi ye?',
  ['Dîroknameya mîrektiyên kurdan','Dîwanek helbestî',
   'Ferhengek kurdî-erebî','Pirtûkeke rêzimanî'],'Dîroknameya mîrektiyên kurdan',
  'Şerefname (1597) yekem dîroknameya berfireh a kurdan e; mîrektî û eşîret tê de tên nasîn.',
  'Şerefname (1597), Kürtlerin ilk kapsamlı tarih kitabıdır; emirlikleri ve aşiretleri tanıtır.',DIROK)
q('Dîrok',2,'tf','Rast e an şaş e: Celadet Alî Bedirxan hem zimannas hem jî weşanger bû.',
  ['Rast','Şaş'],'Rast',
  'Celadet hem alfabe û rêziman xebitî, hem jî Hawar û Ronahî weşandin.',
  'Celadet hem alfabe ve dilbilgisi üzerine çalıştı hem de Hawar ve Ronahî\'yi yayımladı.',DIROK)
q('Dîrok',4,'mc','Komara Mehabadê di kîjan salê de hat damezrandin?',
  ['1946','1936','1958','1961'],'1946',
  'Komara Mehabadê di 22ê Rêbendana 1946an de li rojhilatê Kurdistanê hat ragihandin.',
  'Mahabad Cumhuriyeti 22 Ocak 1946\'da Doğu Kürdistan\'da ilan edildi.',DIROK)
q('Dîrok',5,'mc','Qadî Mihemed bi çi tê nasîn?',
  ['Serokê Komara Mehabadê','Nivîskarê Şerefnameyê',
   'Damezrînerê kovara Hawarê','Mîrê Botan'],'Serokê Komara Mehabadê',
  'Qadî Mihemed serokê Komara Mehabadê (1946) bû.',
  'Kadı Muhammed, Mahabad Cumhuriyeti\'nin (1946) lideridir.',DIROK)
q('Dîrok',3,'mc','Bajarê Amedê di dîrokê de bi kîjan navê latînî jî tê nasîn?',
  ['Amida','Ninova','Palmyra','Edessa'],'Amida',
  'Amed di çavkaniyên latînî de wek "Amida" derbas dibe; sûrên wê yên bazaltî navdar in.',
  'Amed, Latin kaynaklarında "Amida" olarak geçer; bazalt surlarıyla ünlüdür.',DIROK)
q('Dîrok',4,'mc','Gundê "Xerabreşk" an bi giştî wêrankirina gundan di salên 1990î de bi kîjan têgînê tê nasîn?',
  ['Koçberiya bi darê zorê','Reforma erdê','Bajarvanîkirin','Kolonîzasyona çandinî'],
  'Koçberiya bi darê zorê',
  'Di salên 1990î de gelek gund vala bûn û gel bi darê zorê koçber bû.',
  '1990\'larda birçok köy boşaltıldı ve halk zorunlu göçe tabi tutuldu.',DIROK)
q('Dîrok',1,'mc','Hûrî û Mîtanî bi giştî li kîjan herêmê dijiyan?',
  ['Mezopotamyaya jorîn','Deşta Misirê','Peravê Egeyê','Asyaya Navîn'],'Mezopotamyaya jorîn',
  'Hûrî û Mîtanî li Mezopotamyaya jorîn — herêma Dîcle û Firatê ya jorîn — dijiyan.',
  'Hurriler ve Mitanniler Yukarı Mezopotamya\'da, Dicle-Fırat\'ın yukarı havzasında yaşadı.',DIROK)

# ─────────────────────────── EDEBIYAT ───────────────────────────
q('Edebiyat',2,'mc','Nivîskarê "Mem û Zîn" kî ye?',
  ['Ehmedê Xanî','Melayê Cizîrî','Feqiyê Teyran','Elî Herîrî'],'Ehmedê Xanî',
  'Ehmedê Xanî (1651-1707) Mem û Zîn nivîsî; ew stûna wêjeya klasîk a kurdî ye.',
  'Ehmedê Xanî (1651-1707) Mem û Zîn\'i yazdı; klasik Kürt edebiyatının direğidir.',WEJE)
q('Edebiyat',3,'mc','Melayê Cizîrî bi giştî bi çi tê nasîn?',
  ['Dîwana xwe ya helbestên sofîyane','Yekem romana kurdî',
   'Ferhenga kurdî-erebî','Dîroknameya mîrektiyan'],'Dîwana xwe ya helbestên sofîyane',
  'Melayê Cizîrî (sedsala 16-17em) bi Dîwana xwe ya tesewufî helbesta klasîk a kurdî ava kir.',
  'Melayê Cizîrî (16-17. yy) tasavvufi Divanı ile klasik Kürt şiirini kurdu.',WEJE)
q('Edebiyat',4,'mc','"Feqiyê Teyran" di wêjeya kurdî de bi çi hate naskirin?',
  ['Helbestên xwe yên li ser xweza û teyran','Romanên xwe yên nûjen',
   'Şanoyên xwe','Ferhengên xwe'],'Helbestên xwe yên li ser xweza û teyran',
  'Feqiyê Teyran (sedsala 16-17em) di helbestên xwe de bi teyr û xwezayê re diaxive.',
  'Feqiyê Teyran (16-17. yy) şiirlerinde kuşlar ve doğayla konuşur.',WEJE)
q('Edebiyat',3,'mc','Mehmed Uzun bi giştî bi kîjan cureya wêjeyî tê nasîn?',
  ['Roman','Helbesta klasîk','Şano','Ferhengnasî'],'Roman',
  'Mehmed Uzun (1953-2007) romana kurdî ya nûjen bi berhemên xwe wek "Siya Evînê" bi pêş xist.',
  'Mehmed Uzun (1953-2007) "Siya Evînê" gibi eserlerle modern Kürt romanını geliştirdi.',WEJE)
q('Edebiyat',4,'mc','Şêrko Bêkes bi kîjan zaravayî nivîsandiye?',
  ['Soranî','Kurmancî','Zazakî','Goranî'],'Soranî',
  'Şêrko Bêkes (1940-2013) helbestvanê mezin ê soranîaxêv ê başûrê Kurdistanê ye.',
  'Şêrko Bêkes (1940-2013), Güney Kürdistan\'ın Soranca yazan büyük şairidir.',WEJE)
q('Edebiyat',5,'mc','Di wêjeya kurdî de "dîwan" çi tê wateyê?',
  ['Berhevoka helbestên helbestvanekî','Çîrokeke gelêrî',
   'Rojnameyeke edebî','Pirtûkeke rêzimanî'],'Berhevoka helbestên helbestvanekî',
  'Dîwan berhevoka helbestên helbestvanekî ye, bi gelemperî li gorî qafiyeyê rêzkirî.',
  'Divan, bir şairin şiirlerinin genelde kafiyeye göre düzenlenmiş toplamıdır.',WEJE)
q('Edebiyat',2,'mc','Cegerxwîn bi giştî çi bû?',
  ['Helbestvan','Romannivîs','Dîroknas','Muzîkjen'],'Helbestvan',
  'Cegerxwîn (1903-1984) helbestvanê kurd ê navdar e; navê wî tê wateya "kezebkul".',
  'Cegerxwîn (1903-1984) ünlü Kürt şairidir; adı "ciğeri yanık" anlamına gelir.',WEJE)
q('Edebiyat',3,'tf','Rast e an şaş e: "Siya Evînê" romaneke Mehmed Uzun e.',
  ['Rast','Şaş'],'Rast',
  '"Siya Evînê" (1989) romaneke Mehmed Uzun e û li ser jiyana Memduh Selîm e.',
  '"Siya Evînê" (1989) Mehmed Uzun\'un romanıdır ve Memduh Selim\'in yaşamını anlatır.',WEJE)
q('Edebiyat',4,'mc','Di helbesta klasîk a kurdî de bandora kîjan wêjeyan zêde xuya dike?',
  ['Farisî û erebî','Yewnanî û latînî','Slavî û rûsî','Çînî û hindî'],'Farisî û erebî',
  'Helbesta klasîk a kurdî ji aliyê pîvan û mecazan ve bi wêjeya farisî û erebî re di nav danûstandinê de bû.',
  'Klasik Kürt şiiri, ölçü ve mecaz açısından Fars ve Arap edebiyatıyla etkileşim içindeydi.',WEJE)
q('Edebiyat',5,'mc','Berhema "Nûbihara Biçûkan" a Ehmedê Xanî çi ye?',
  ['Ferhengeke helbestî ya kurdî-erebî ji bo zarokan','Romaneke evîndarî',
   'Dîroknameyek','Berhevoka stranan'],
  'Ferhengeke helbestî ya kurdî-erebî ji bo zarokan',
  'Nûbihara Biçûkan ferhengeke bi rêza helbestî ye ku ji bo hînkirina zarokan hatiye nivîsandin.',
  'Nûbihara Biçûkan, çocuklara öğretmek için manzum yazılmış Kürtçe-Arapça sözlüktür.',WEJE)
q('Edebiyat',2,'mc','Peyva "helbest" bi Tirkî çi tê wateyê?',
  ['şiir','roman','öykü','tiyatro'],'şiir',
  '"Helbest" bi Tirkî "şiir" e.','"Helbest" Türkçede "şiir" demektir.',WEJE)
q('Edebiyat',3,'mc','Kî wek "yekem romannivîsa kurd" tê hesibandin ku romana "Şivanê Kurmanca" nivîsî?',
  ['Erebê Şemo','Cegerxwîn','Mehmed Uzun','Ehmedê Xanî'],'Erebê Şemo',
  'Erebê Şemo "Şivanê Kurmanca" (1935) nivîsî; ew wek romana kurdî ya pêşîn tê hesibandin.',
  'Erebê Şemo, ilk Kürt romanı sayılan "Şivanê Kurmanca"yı (1935) yazdı.',WEJE)

# ─────────────────────────── COGRAFYA ───────────────────────────
q('Cografya',1,'mc','Zincîra çiyayên ku bi piranî di erdnîgariya kurdî re derbas dibe kîjan e?',
  ['Zagros','Alp','Kafkas','Toros Rojava'],'Zagros',
  'Çiyayên Zagros ji bakurê rojavayê Îranê heta başûrê Kurdistanê dirêj dibin.',
  'Zagros dağları, İran\'ın kuzeybatısından Güney Kürdistan\'a uzanır.',COGRAFYA)
q('Cografya',2,'mc','Çiyayê herî bilind ê Tirkiyeyê ku li herêma kurdî ye kîjan e?',
  ['Çiyayê Agirî','Çiyayê Cûdî','Çiyayê Nemrûd','Çiyayê Erciyes'],'Çiyayê Agirî',
  'Çiyayê Agirî bi 5.137 metreyî çiyayê herî bilind ê Tirkiyeyê ye.',
  'Ağrı Dağı 5.137 metreyle Türkiye\'nin en yüksek dağıdır.',COGRAFYA)
q('Cografya',1,'mc','Gola herî mezin a Tirkiyeyê ku li herêma kurdî ye kîjan e?',
  ['Gola Wanê','Gola Tuzê','Gola Beyşehîrê','Gola Îznîkê'],'Gola Wanê',
  'Gola Wanê bi qasî 3.700 km² e û gola herî mezin a Tirkiyeyê ye.',
  'Van Gölü yaklaşık 3.700 km² ile Türkiye\'nin en büyük gölüdür.',COGRAFYA)
q('Cografya',2,'mc','Herdu çemên sereke yên Mezopotamyayê kîjan in?',
  ['Dîcle û Firat','Nîl û Kongo','Volga û Don','Ganj û Îndus'],'Dîcle û Firat',
  'Dîcle û Firat ji çiyayên Kurdistanê diherikin û Mezopotamyayê ava dikin.',
  'Dicle ve Fırat, Kürdistan dağlarından doğar ve Mezopotamya\'yı oluşturur.',COGRAFYA)
q('Cografya',3,'mc','Bajarê Hewlêr (Erbil) navenda kîjan herêmê ye?',
  ['Herêma Kurdistanê ya Iraqê','Rojavayê Kurdistanê',
   'Bakurê Kurdistanê','Rojhilatê Kurdistanê'],'Herêma Kurdistanê ya Iraqê',
  'Hewlêr paytexta Herêma Kurdistanê ya Federal a Iraqê ye; qelaya wê di lîsteya UNESCOyê de ye.',
  'Erbil, Irak Federal Kürdistan Bölgesi\'nin başkentidir; kalesi UNESCO listesindedir.',COGRAFYA)
q('Cografya',2,'mc','Sûrên bazaltî yên ku di lîsteya mîrateya cîhanî ya UNESCOyê de ne li kîjan bajarî ne?',
  ['Amed','Wan','Mêrdîn','Riha'],'Amed',
  'Sûrên Amedê û Baxçeyên Hewselê di 2015an de ketin lîsteya UNESCOyê.',
  'Diyarbakır Surları ve Hevsel Bahçeleri 2015\'te UNESCO listesine girdi.',COGRAFYA)
q('Cografya',3,'mc','Girê Navokê (Göbeklitepe) li nêzîkî kîjan bajarî ye?',
  ['Riha','Wan','Amed','Elezîz'],'Riha',
  'Girê Navokê li nêzîkî Rihayê ye û yek ji kevintirîn cihên olî yên cîhanê tê hesibandin.',
  'Göbeklitepe Urfa yakınlarındadır ve dünyanın en eski tapınak alanlarından sayılır.',COGRAFYA)
q('Cografya',4,'mc','Bendava Îlisûyê li ser kîjan çemî hatiye avakirin?',
  ['Dîcle','Firat','Murat','Zap'],'Dîcle',
  'Bendava Îlisûyê li ser Dîcleyê ye; avahiya wê gundê dîrokî Hesenkeyf di bin avê de hişt.',
  'Ilısu Barajı Dicle üzerindedir; yapımı tarihi Hasankeyf\'i sular altında bıraktı.',COGRAFYA)
q('Cografya',3,'mc','Hesenkeyf berî ku di bin avê de bimîne li ser kîjan çemî bû?',
  ['Dîcle','Firat','Botan','Zap'],'Dîcle',
  'Hesenkeyf bajarekî dîrokî yê li ser Dîcleyê bû.',
  'Hasankeyf, Dicle kıyısında tarihi bir yerleşimdi.',COGRAFYA)
q('Cografya',4,'mc','Çemê Zap bi giştî diherike nav kîjan çemî?',
  ['Dîcle','Firat','Erez','Çoruh'],'Dîcle',
  'Zapê Mezin ji Colemêrgê diherike û digihîje Dîcleyê.',
  'Büyük Zap, Hakkâri\'den doğar ve Dicle\'ye karışır.',COGRAFYA)
q('Cografya',2,'tf','Rast e an şaş e: Gola Wanê ava wê şor e.',
  ['Rast','Şaş'],'Rast',
  'Ava Gola Wanê sodalî û şor e; loma tenê masiyê darex (înci kefalî) tê de dijî.',
  'Van Gölü suyu sodalı ve tuzludur; bu yüzden yalnızca inci kefali yaşar.',COGRAFYA)
q('Cografya',5,'mc','Herêma Behdînan bi giştî li kîjan parçeyê Kurdistanê ye?',
  ['Başûr','Bakur','Rojava','Rojhilat'],'Başûr',
  'Behdînan li başûrê Kurdistanê ye; Dihok navenda wê ya sereke ye.',
  'Behdinan, Güney Kürdistan\'dadır; ana merkezi Duhok\'tur.',COGRAFYA)
q('Cografya',3,'mc','Bajarê Qamişlo li kîjan parçeyê Kurdistanê ye?',
  ['Rojava','Bakur','Başûr','Rojhilat'],'Rojava',
  'Qamişlo li bakurê rojhilatê Sûriyeyê — Rojavayê Kurdistanê — ye.',
  'Qamişlo, Suriye\'nin kuzeydoğusunda, Rojava\'dadır.',COGRAFYA)
q('Cografya',4,'mc','Bajarê Sanandaj (Sine) li kîjan welatî ye?',
  ['Îran','Iraq','Sûriye','Ermenistan'],'Îran',
  'Sine (Sanandaj) navenda parêzgeha Kurdistanê ya Îranê ye.',
  'Sine (Sanandaj), İran\'ın Kürdistan eyaletinin merkezidir.',COGRAFYA)
q('Cografya',1,'mc','Peyva "çiya" bi Tirkî çi tê wateyê?',
  ['dağ','nehir','göl','ova'],'dağ',
  '"Çiya" bi Tirkî "dağ" e.','"Çiya" Türkçede "dağ" demektir.',COGRAFYA)

# ─────────────────────────── MUZÎK ───────────────────────────
q('Muzîk',1,'mc','"Dengbêj" kî ye?',
  ['Stranbêjê devkî yê ku çîrokan bi kilaman dibêje','Lêdera tembûrê',
   'Nivîskarê stranan','Reqasê govendê'],
  'Stranbêjê devkî yê ku çîrokan bi kilaman dibêje',
  'Dengbêj bêyî amûrê, tenê bi dengê xwe kilam û çîrokan diguhezîne.',
  'Dengbêj, enstrümansız, yalnız sesiyle kilam ve hikâye aktaran anlatıcıdır.',MUZIK)
q('Muzîk',2,'mc','Amûra kurdî ya bi têlan a ku bi navê "saz" jî tê nasîn kîjan e?',
  ['Tembûr','Bilûr','Def','Zirne'],'Tembûr',
  'Tembûr amûreke têlî ye û di muzîka kurdî de cihekî navendî digire.',
  'Tembûr telli bir çalgıdır ve Kürt müziğinde merkezi yer tutar.',MUZIK)
q('Muzîk',1,'mc','"Bilûr" cureyekî çi amûrê ye?',
  ['Amûra pifê','Amûra têlî','Amûra lêdanê','Amûra elektronîk'],'Amûra pifê',
  'Bilûr amûreke pifê ye, bi gelemperî ji qamîş an dar tê çêkirin.',
  'Bilûr (kaval) üflemeli bir çalgıdır, genelde kamış veya ağaçtan yapılır.',MUZIK)
q('Muzîk',2,'mc','"Def û zirne" bi gelemperî di kîjan rewşê de tên lêxistin?',
  ['Dawet û govendê','Rêûresma şînê','Dersên dibistanê','Nimêja sibehê'],'Dawet û govendê',
  'Def û zirne cotê amûran ê dawet û govendê ye.',
  'Davul ve zurna, düğün ve halayın klasik ikilisidir.',MUZIK)
q('Muzîk',3,'mc','Şivan Perwer bi giştî bi çi tê nasîn?',
  ['Stranbêjiya kurdî ya nûjen û siyasî','Helbesta klasîk',
   'Romannivîsî','Dîroknasî'],'Stranbêjiya kurdî ya nûjen û siyasî',
  'Şivan Perwer stranbêjê kurd ê navdar e; stranên wî yên welatparêz li seranserê Kurdistanê belav bûn.',
  'Şivan Perwer ünlü Kürt sanatçıdır; yurtsever şarkıları tüm Kürdistan\'a yayıldı.',MUZIK)
q('Muzîk',3,'mc','"Kilam" di muzîka kurdî de çi ye?',
  ['Stranên dirêj ên çîrokî','Reqsa komî','Amûreke têlî','Cureyekî xwarinê'],
  'Stranên dirêj ên çîrokî',
  'Kilam bi gelemperî çîrokek dibêje: evîn, şer, koçberî an şîn.',
  'Kilam genelde bir hikâye anlatır: aşk, savaş, göç ya da yas.',MUZIK)
q('Muzîk',4,'mc','Ayşe Şan di dîroka muzîka kurdî de çima girîng e?',
  ['Yek ji dengên jin ên pêşeng ê muzîka kurdî ye','Yekem romannivîsa kurd e',
   'Damezrînera kovara Hawarê ye','Lêdera yekem a tembûrê ye'],
  'Yek ji dengên jin ên pêşeng ê muzîka kurdî ye',
  'Ayşe Şan (1938-1996) di bin şert û mercên dijwar de bû yek ji dengên jin ên herî bibandor ên muzîka kurdî.',
  'Ayşe Şan (1938-1996), zor koşullarda Kürt müziğinin en etkili kadın seslerinden biri oldu.',MUZIK)
q('Muzîk',4,'mc','"Lawik" di muzîka kurdî de bi giştî çi ye?',
  ['Cureyekî kilamê yê bi gelemperî evîndar','Amûreke lêdanê',
   'Reqsek zûtir','Rêbaza notagirtinê'],'Cureyekî kilamê yê bi gelemperî evîndar',
  'Lawik cureyekî kilamê ye; bi piranî li ser evîn û hesretê ye.',
  'Lawik bir kilam türüdür; çoğunlukla aşk ve hasret üzerinedir.',MUZIK)
q('Muzîk',2,'tf','Rast e an şaş e: Dengbêj bi gelemperî bêyî amûra muzîkê distirên.',
  ['Rast','Şaş'],'Rast',
  'Dengbêjî hunerekî devkî ye; deng bi tena serê xwe têrê dike.',
  'Dengbêjlik sözlü bir sanattır; ses tek başına yeterlidir.',MUZIK)
q('Muzîk',5,'mc','"Şeşbendî" di muzîka dengbêjî de bi giştî çi diyar dike?',
  ['Avaz û qalibê kilamê','Hejmara amûran','Dirêjahiya dawetê','Navê herêmekê'],
  'Avaz û qalibê kilamê',
  'Şeşbendî qalibekî avaz e ku dengbêj kilamê li gorî wê dirêj dike.',
  'Şeşbendî, dengbêjin kilamı üzerine kurduğu ezgi kalıbıdır.',MUZIK)
q('Muzîk',3,'mc','Koma Mizgîn, Koma Amed û Koma Dengê Azadî bi giştî çi ne?',
  ['Komên muzîka kurdî ya nûjen','Rojnameyên kurdî',
   'Partiyên siyasî','Weşanxaneyên pirtûkan'],'Komên muzîka kurdî ya nûjen',
  'Ev "kom" di salên 1990î de muzîka kurdî ya komî û siyasî pêş xistin.',
  'Bu "kom"lar 1990\'larda toplu ve politik Kürt müziğini geliştirdi.',MUZIK)
q('Muzîk',1,'mc','Peyva "stran" bi Tirkî çi tê wateyê?',
  ['şarkı','dans','saz','ses'],'şarkı',
  '"Stran" bi Tirkî "şarkı/türkü" ye.','"Stran" Türkçede "şarkı/türkü" demektir.',MUZIK)
q('Muzîk',4,'mc','"Erbane" cureyekî çi amûrê ye?',
  ['Amûra lêdanê ya wek def','Amûra têlî','Amûra pifê','Amûra kevanî'],
  'Amûra lêdanê ya wek def',
  'Erbane (daf) amûreke lêdanê ya çermî ye û bi taybetî di muzîka olî û gelêrî de tê bikaranîn.',
  'Erbane (def), deri kaplı vurmalı bir çalgıdır; dini ve halk müziğinde kullanılır.',MUZIK)

# ─────────────────────────── SIYASET ───────────────────────────
q('Siyaset',2,'mc','Kurd bi giştî li çend welatên sereke belav bûne?',
  ['Çar','Du','Şeş','Heşt'],'Çar',
  'Kurd bi piranî li Tirkiye, Îran, Iraq û Sûriyeyê dijîn; diaspora jî berfireh e.',
  'Kürtler ağırlıklı olarak Türkiye, İran, Irak ve Suriye\'de yaşar; diaspora da geniştir.',SIYASET)
q('Siyaset',3,'mc','Herêma Kurdistanê ya Iraqê statuya xwe ya federal bi kîjan destûrê bi dest xist?',
  ['Destûra Iraqê ya 2005an','Peymana Lozanê','Biryara NYyê ya 1991ê','Destûra 1970yî'],
  'Destûra Iraqê ya 2005an',
  'Destûra federal a Iraqê ya 2005an Herêma Kurdistanê wek herêmeke federal nas kir.',
  '2005 Irak federal anayasası Kürdistan Bölgesi\'ni federal bölge olarak tanıdı.',SIYASET)
q('Siyaset',3,'mc','"Hevserokatî" di siyaseta kurdî de çi ye?',
  ['Rêveberiya bi jin û mêrekî bi hev re','Hilbijartina du salane',
   'Sîstema du meclîsan','Serokatiya dorveger a bajaran'],
  'Rêveberiya bi jin û mêrekî bi hev re',
  'Hevserokatî prensîba wekheviya zayendî ye: her post bi jinek û mêrek tê parvekirin.',
  'Eş başkanlık, cinsiyet eşitliği ilkesidir: her makam bir kadın ve bir erkekle paylaşılır.',SIYASET)
q('Siyaset',4,'mc','"Xweseriya demokratîk" bi giştî çi pêşniyar dike?',
  ['Xwerêveberiya herêmî ya li ser bingehê meclîsên gel',
   'Damezrandina dewleteke nû ya navendî','Rêveberiya leşkerî',
   'Sîstema padîşahiyê'],'Xwerêveberiya herêmî ya li ser bingehê meclîsên gel',
  'Xweseriya demokratîk biryardayînê ji navendê digihîne meclîs û komunên herêmî.',
  'Demokratik özerklik, karar almayı merkezden yerel meclis ve komünlere taşır.',PARADIGMA)
q('Siyaset',4,'mc','Kongra Star bi giştî li ser çi kar dike?',
  ['Rêxistinbûna jinan li Rojava','Weşana rojnameyan',
   'Bazirganiya navneteweyî','Perwerdehiya leşkerî ya giştî'],
  'Rêxistinbûna jinan li Rojava',
  'Kongra Star li Rojava rêxistina şemsiye ya tevgera jinan e.',
  'Kongra Star, Rojava\'da kadın hareketinin çatı örgütüdür.',SIYASET)
q('Siyaset',5,'mc','"KJAR" kurtenavê çi ye?',
  ['Rêxistina jinan a azadîxwaz a rojhilatê Kurdistanê','Meclîseke bajêr',
   'Yekîtiya nivîskaran','Sendîkayeke karkeran'],
  'Rêxistina jinan a azadîxwaz a rojhilatê Kurdistanê',
  'KJAR (Komalgeya Jinên Azad ên Rojhilatê Kurdistanê) li rojhilat li ser azadiya jinê kar dike.',
  'KJAR (Doğu Kürdistan Özgür Kadınlar Topluluğu), doğuda kadın özgürlüğü üzerine çalışır.',SIYASET)
q('Siyaset',2,'tf','Rast e an şaş e: Zimanê kurdî li Herêma Kurdistanê ya Iraqê zimanekî fermî ye.',
  ['Rast','Şaş'],'Rast',
  'Li gorî destûra Iraqê, kurdî li tevahiya welêt zimanekî fermî ye.',
  'Irak anayasasına göre Kürtçe ülke genelinde resmi dildir.',SIYASET)
q('Siyaset',3,'mc','Referandûma serxwebûnê ya Herêma Kurdistanê ya Iraqê di kîjan salê de pêk hat?',
  ['2017','2005','2011','2020'],'2017',
  'Referandûm di 25ê Îlona 2017an de pêk hat; encam bi piranî "erê" bû lê nehat sepandin.',
  'Referandum 25 Eylül 2017\'de yapıldı; sonuç büyük oranda "evet" oldu ancak uygulanmadı.',SIYASET)
q('Siyaset',4,'mc','Rêveberiya Xweser a Bakur û Rojhilatê Sûriyeyê bi giştî di kîjan salan de ava bû?',
  ['Piştî 2012an','Berî 1990î','Di 1946an de','Di 2020î de'],'Piştî 2012an',
  'Piştî 2012an li Rojava kantonên xweser hatin ragihandin û paşê di bin banê rêveberiyeke hevpar de kom bûn.',
  '2012\'den sonra Rojava\'da özerk kantonlar ilan edildi, sonra ortak bir yönetim çatısında birleşti.',SIYASET)
q('Siyaset',5,'mc','"Netewa demokratîk" bi kîjan xalê ji "dewleta netewe" cuda dibe?',
  ['Nasnameyên cuda di nav yek civakê de tên parastin, dewlet ne pêwîst e',
   'Tenê yek zimanê fermî qebûl dike','Tenê bi hilbijartinan kar dike',
   'Bi tundî sînoran diparêze'],
  'Nasnameyên cuda di nav yek civakê de tên parastin, dewlet ne pêwîst e',
  'Netewa demokratîk li şûna yekîtiya zorê ya dewletê, hebûna pirrengî û xwerêveberiyê datîne.',
  'Demokratik ulus, devletin zorla tekleştirmesi yerine çoğulculuğu ve öz yönetimi koyar.',PARADIGMA)
q('Siyaset',2,'mc','Peyva "azadî" bi Tirkî çi tê wateyê?',
  ['özgürlük','eşitlik','adalet','barış'],'özgürlük',
  '"Azadî" bi Tirkî "özgürlük" e.','"Azadî" Türkçede "özgürlük" demektir.',SIYASET)
q('Siyaset',4,'mc','Di siyaseta herêmî de "komun" bi giştî çi ye?',
  ['Yekeya biryardayînê ya herî biçûk a taxê an gund',
   'Dadgeheke bilind','Fermandariya leşkerî','Bankayeke herêmî'],
  'Yekeya biryardayînê ya herî biçûk a taxê an gund',
  'Komun asta yekem a xwerêveberiyê ye; gundî an taxî tê de rasterast biryar didin.',
  'Komün, öz yönetimin en küçük birimidir; köy ya da mahalle sakinleri doğrudan karar alır.',PARADIGMA)

# ─────────────────────────── PARADIGMA ───────────────────────────
q('Paradigma',3,'mc','"Jineolojî" bi gelemperî çi tê wateyê?',
  ['Zanista jinê û jiyanê','Hunera nîgarkêşiyê',
   'Zanista erdnîgariyê','Rêbaza aboriyê'],'Zanista jinê û jiyanê',
  'Jineolojî ji "jin" û "-lojî" tê; zanistek e ku jiyan û civakê ji perspektîfa jinê dinirxîne.',
  'Jineoloji, "jin" (kadın) ve "-loji"den gelir; yaşamı ve toplumu kadın perspektifinden inceleyen bilimdir.',PARADIGMA)
q('Paradigma',4,'mc','Di paradîgmaya ekolojîk de armanca sereke çi ye?',
  ['Lihevhatina civak û xwezayê','Zêdekirina hilberînê bi her awayî',
   'Bazirganiya azad a bêsînor','Bajarvanîkirina bilez'],'Lihevhatina civak û xwezayê',
  'Ekolojî têkiliya civakê bi xwezayê re ji nû ve saz dike: jiyan li ser xerakirinê nayê avakirin.',
  'Ekoloji, toplumun doğayla ilişkisini yeniden kurar: yaşam yıkım üzerine inşa edilmez.',PARADIGMA)
q('Paradigma',3,'mc','"Xwe-parastin" di vê paradîgmayê de bi giştî çi tê wateyê?',
  ['Parastina civakê bi rêxistinbûna wê ya xwe','Bazirganiya çekan',
   'Veqetîna ji cîhanê','Rêveberiya bi tenê bi hilbijartinan'],
  'Parastina civakê bi rêxistinbûna wê ya xwe',
  'Xwe-parastin ne tenê ya leşkerî ye; parastina ziman, çand û jiyana civakî jî tê de ye.',
  'Öz savunma yalnız askeri değildir; dilin, kültürün ve toplumsal yaşamın korunmasını da kapsar.',PARADIGMA)
q('Paradigma',5,'mc','Têgîna "modernîteya demokratîk" li hember çi tê danîn?',
  ['Modernîteya kapîtalîst','Serdema navîn','Şoreşa pîşesazî','Felsefeya antîk'],
  'Modernîteya kapîtalîst',
  'Modernîteya demokratîk wek alternatîfeke modernîteya kapîtalîst tê pêşkêşkirin: komun, ekolojî û azadiya jinê.',
  'Demokratik modernite, kapitalist moderniteye alternatif olarak sunulur: komün, ekoloji ve kadın özgürlüğü.',PARADIGMA)
q('Paradigma',2,'mc','Di vê paradîgmayê de "civaka exlaqî û polîtîk" çi tê wateyê?',
  ['Civaka ku bi nirx û biryardayîna hevpar tê birêvebirin',
   'Civaka ku tenê bi qanûnan tê birêvebirin','Civaka bêrêxistin',
   'Civaka ku ji aliyê pisporan ve tê rêvebirin'],
  'Civaka ku bi nirx û biryardayîna hevpar tê birêvebirin',
  'Civaka exlaqî û polîtîk biryarê nade destê teknokratan; nirx û meclîsên gel bingeh in.',
  'Ahlaki ve politik toplum, kararı teknokratlara bırakmaz; değerler ve halk meclisleri esastır.',PARADIGMA)
q('Paradigma',4,'tf','Rast e an şaş e: Di paradîgmaya netewa demokratîk de armanc damezrandina dewleteke nû ye.',
  ['Şaş','Rast'],'Şaş',
  'Armanc ne damezrandina dewletê ye; xwerêveberiya civakê ya li derveyî dewletê ye.',
  'Amaç yeni bir devlet kurmak değil, devlet dışında toplumsal öz yönetimdir.',PARADIGMA)
q('Paradigma',3,'mc','Di têgîna "aboriya komunal" de xala sereke çi ye?',
  ['Hilberîn li gorî pêdiviya civakê, ne li gorî qezencê',
   'Zêdekirina bêsînor a qezencê','Taybetkirina tevahî ya erdê',
   'Bazirganiya tenê ya derveyî'],
  'Hilberîn li gorî pêdiviya civakê, ne li gorî qezencê',
  'Aboriya komunal kooperatîf û hilberîna hevpar dixe pêş qezenca kesane.',
  'Komünal ekonomi, bireysel kârdan önce kooperatifi ve ortak üretimi koyar.',PARADIGMA)
q('Paradigma',5,'mc','"Hiyerarşî" û "dewlet" di vê xebata teorîk de çawa tên nirxandin?',
  ['Wek pêvajoyên dîrokî yên ku dikarin bên guhertin','Wek rewşên xwezayî yên neguherbar',
   'Wek diyardeyên tenê aborî','Wek pirsgirêkên teknîkî'],
  'Wek pêvajoyên dîrokî yên ku dikarin bên guhertin',
  'Hiyerarşî wek çêbûneke dîrokî tê dîtin; ji ber ku dîrokî ye, dikare bê guhertin.',
  'Hiyerarşi tarihsel bir oluşum olarak görülür; tarihsel olduğu için değiştirilebilir.',PARADIGMA)
q('Paradigma',2,'mc','Peyva "jiyan" bi Tirkî çi tê wateyê?',
  ['yaşam','özgürlük','toplum','doğa'],'yaşam',
  '"Jiyan" bi Tirkî "yaşam/hayat" e.','"Jiyan" Türkçede "yaşam/hayat" demektir.',PARADIGMA)
q('Paradigma',4,'mc','Di paradîgmayê de "azadiya jinê" çima wek pîvana azadiya civakê tê dîtin?',
  ['Ji ber ku koletiya yekem li ser jinê hatiye avakirin','Ji ber ku jin pirtir in',
   'Ji ber ku pirsgirêkeke aborî ye','Ji ber ku pirsgirêkeke qanûnî ye'],
  'Ji ber ku koletiya yekem li ser jinê hatiye avakirin',
  'Argûman ev e: hiyerarşiya yekem a civakî bi bindestkirina jinê dest pê kiriye, loma azadî jî ji wir dest pê dike.',
  'Argüman şudur: ilk toplumsal hiyerarşi kadının tabi kılınmasıyla başladı, bu yüzden özgürlük de oradan başlar.',PARADIGMA)


# ══════════════════════ İKİNCİ PARTİ ══════════════════════
# ZIMAN
q('Ziman',1,'mc','Peyva Kurmancî "dar" bi Tirkî çi tê wateyê?',
  ['ağaç','taş','yol','kapı'],'ağaç','"Dar" bi Tirkî "ağaç" e.','"Dar" Türkçede "ağaç" demektir.',FERHENG)
q('Ziman',1,'mc','Peyva Kurmancî "nan" bi Tirkî çi tê wateyê?',
  ['ekmek','tuz','şeker','et'],'ekmek','"Nan" bi Tirkî "ekmek" e.','"Nan" Türkçede "ekmek" demektir.',FERHENG)
q('Ziman',2,'mc','Peyva Kurmancî "biçûk" bi Tirkî çi tê wateyê?',
  ['küçük','büyük','uzun','geniş'],'küçük','"Biçûk" bi Tirkî "küçük" e.','"Biçûk" Türkçede "küçük" demektir.',FERHENG)
q('Ziman',2,'mc','Hejmara "deh" di Kurmancî de bi hejmarî çi ye?',
  ['10','7','12','20'],'10',
  'Hejmarên bingehîn: yek, du, sê, çar, pênc, şeş, heft, heşt, neh, deh.',
  'Temel sayılar: yek, du, sê, çar, pênc, şeş, heft, heşt, neh, deh (10).',FERHENG)
q('Ziman',3,'mc','Di Kurmancî de "-ek" wek paşgir çi diyar dike?',
  ['Nebinavkirîbûn (yek/bir)','Pirjimarî','Zayenda mê','Dema borî'],'Nebinavkirîbûn (yek/bir)',
  '"Pirtûk-ek" wateya "bir kitap" dide; ew nîşana nebinavkirîbûnê ye.',
  '"Pirtûkek" bir kitap demektir; belirsizlik ekidir.',REZIMAN)
q('Ziman',3,'mc','Veqetandeka navdêrên nêr ên yekjimar di Kurmancî de kîjan e?',
  ['-ê','-a','-an','-in'],'-ê',
  'Navdêrê nêr "-ê" digire: "kitêbê" na, lê "dar-ê mezin" — mînak: "bavê min".',
  'Eril isim "-ê" alır; örnek: "bavê min" (benim babam).',REZIMAN)
q('Ziman',4,'mc','Di hevoka "Min ew dît" de lêker li gorî kê tê kişandin?',
  ['Li gorî bireserê (ew)','Li gorî bikerê (min)','Li gorî demê','Li gorî zayendê'],
  'Li gorî bireserê (ew)',
  'Di dema borî ya lêkerên gerguhêz de lêker li gorî bireserê tê kişandin — ev taybetiya ergatîfê ye.',
  'Geçmiş zamanda geçişli fiil nesneye göre çekimlenir — bu ergatifliğin özelliğidir.',REZIMAN)
q('Ziman',2,'mc','Peyva "dibistan" ji kîjan koka lêkerê tê?',
  ['Xwendin (dibistan: cihê xwendinê)','Nivîsandin','Gotin','Dîtin'],
  'Xwendin (dibistan: cihê xwendinê)',
  '"Dibistan" ji "dibi-" (xwendin) û paşgira cih "-stan" pêk tê.',
  '"Dibistan" (okul), okuma kökü ve yer eki "-stan"dan oluşur.',FERHENG)
q('Ziman',3,'mc','Paşgira "-istan/-stan" di peyvên wek "Kurdistan" de çi diyar dike?',
  ['Cih / war','Kesayet','Dem','Hejmar'],'Cih / war',
  '"-stan" paşgira cih e: warê kurdan.','"-stan" yer ekidir: Kürtlerin yurdu.',FERHENG)
q('Ziman',4,'mc','Di Kurmancî de cudahiya "tu" û "hûn" çi ye?',
  ['"Tu" yekjimar, "hûn" pirjimar/rêzdarî ye','Herdu jî pirjimar in',
   '"Tu" tenê ji bo jinan e','"Hûn" tenê di nivîsê de tê bikaranîn'],
  '"Tu" yekjimar, "hûn" pirjimar/rêzdarî ye',
  '"Tu" ji bo yek kesî, "hûn" ji bo gelek kesan an ji bo rêzgirtinê tê bikaranîn.',
  '"Tu" tekil, "hûn" çoğul ya da saygı ifadesidir.',REZIMAN)
q('Ziman',5,'mc','Di Kurmancî de "raweya bilanî" (subjunctive) bi kîjan pêşgirê tê çêkirin?',
  ['bi-','di-','na-','ne-'],'bi-',
  'Raweya bilanî bi "bi-" tê çêkirin: "ez bi-ç-im" (gideyim).',
  'İstek kipi "bi-" ile kurulur: "ez biçim" (gideyim).',REZIMAN)
q('Ziman',4,'mc','Nîşana neyîniyê ya dema niha di Kurmancî de kîjan e?',
  ['na-','ne-','bi-','di-'],'na-',
  'Dema niha bi "na-" neyînî dibe: "ez naçim" (gitmiyorum).',
  'Şimdiki zaman "na-" ile olumsuzlanır: "ez naçim" (gitmiyorum).',REZIMAN)
q('Ziman',2,'tf','Rast e an şaş e: Di Kurmancî de navdêr xwedî zayendê ne (nêr û mê).',
  ['Rast','Şaş'],'Rast',
  'Erê, her navdêreke kurmancî nêr an mê ye û ev yek veqetandekê diyar dike.',
  'Evet, Kurmancî\'de her isim eril ya da dişildir ve bu izafeyi belirler.',REZIMAN)
q('Ziman',3,'mc','Peyva "xwendekar" bi Tirkî çi tê wateyê?',
  ['öğrenci','öğretmen','okul','kitap'],'öğrenci',
  '"Xwendekar" bi Tirkî "öğrenci" ye.','"Xwendekar" Türkçede "öğrenci" demektir.',FERHENG)

# ÇAND
q('Çand',2,'mc','Di kevneşopiya kurdî de "berxwedan" bi giştî çi tê wateyê?',
  ['Li ber xwe dan / direniş','Bazirganî','Xwarina cejnê','Reqsa dawetê'],
  'Li ber xwe dan / direniş',
  '"Berxwedan" ji "li ber xwe dan" tê; wateya xwe-parastin û israrê dide.',
  '"Berxwedan", "li ber xwe dan"dan gelir; direnme ve ısrar anlamındadır.',FOLKLOR)
q('Çand',3,'mc','Xwarina "dolme" ya kurdî bi giştî ji çi tê çêkirin?',
  ['Belg û sebzeyên dagirtî','Ard û şekir','Şîr û hingiv','Genimê sor'],
  'Belg û sebzeyên dagirtî',
  'Dolme belgên rezê an sebzeyên wek bacan û bîber bi birinc û savar tên dagirtin.',
  'Dolma; asma yaprağı ya da patlıcan, biber gibi sebzelerin pirinç/bulgurla doldurulmasıdır.',FOLKLOR)
q('Çand',2,'mc','Cejna Newrozê bi kîjan sembola sereke tê nasîn?',
  ['Agir','Av','Berf','Bager'],'Agir',
  'Agirê Newrozê sembola nûbûn û berxwedanê ye.',
  'Nevruz ateşi yenilenmenin ve direnişin simgesidir.',FOLKLOR)
q('Çand',4,'mc','"Pêşmerge" peyv bi rastî çi tê wateyê?',
  ['Yê ku li pêşiya mirinê ye','Yê ku digere','Yê ku distirê','Yê ku dixwîne'],
  'Yê ku li pêşiya mirinê ye',
  '"Pêş" + "merg" (mirin): yê ku xwe datîne pêşiya mirinê.',
  '"Pêş" (ön) + "merg" (ölüm): ölümün önüne duran.',FOLKLOR)
q('Çand',3,'mc','Di civaka kurdî de "eşîret" çi ye?',
  ['Komeke malbatên bi xizmî girêdayî','Rêxistineke siyasî ya nûjen',
   'Cureyekî xwarinê','Navê herêmeke bajarî'],'Komeke malbatên bi xizmî girêdayî',
  'Eşîret komeke mezin a xizmî ye û bi kevneşopî rola rêveberiya civakî digire.',
  'Aşiret, akrabalıkla bağlı büyük topluluktur ve geleneksel olarak toplumsal yönetim rolü üstlenir.',FOLKLOR)
q('Çand',2,'mc','"Şeva Yeldayê" (Şeva Zivistanê) çi ye?',
  ['Şeva herî dirêj a salê','Yekem roja biharê','Roja dawî ya havînê','Şeva Newrozê'],
  'Şeva herî dirêj a salê',
  'Şeva Yeldayê şeva herî dirêj a salê ye û bi civîn û xwarinê tê derbaskirin.',
  'Yelda gecesi yılın en uzun gecesidir; toplanıp yemekle geçirilir.',FOLKLOR)
q('Çand',4,'mc','Di dawetên kurdî de "qelen" çi ye?',
  ['Diyariya ku ji bo bûkê tê dayîn','Xwarina dawetê',
   'Reqsa dawiyê','Navê muzîkjenan'],'Diyariya ku ji bo bûkê tê dayîn',
  'Qelen di kevneşopiyê de mal an diyariya ku malbata zavayî dide malbata bûkê ye.',
  'Başlık (qelen), geleneksel olarak damat ailesinin gelin ailesine verdiği mal/hediyedir.',FOLKLOR)
q('Çand',5,'mc','"Dîwanxane" di malên kurdî yên kevneşopî de çi ye?',
  ['Odeya mêvanan û civînê','Embara genim','Cihê ajalan','Odeya zarokan'],
  'Odeya mêvanan û civînê',
  'Dîwanxane cihê mêvandarî û biryardana civakî ye.',
  'Dîwanxane, misafir ağırlama ve toplumsal karar alma yeridir.',FOLKLOR)
q('Çand',1,'mc','Peyva "mal" di Kurmancî de bi Tirkî çi tê wateyê?',
  ['ev','yol','dağ','su'],'ev','"Mal" bi Tirkî "ev" e.','"Mal" Türkçede "ev" demektir.',FERHENG)

# DÎROK
q('Dîrok',3,'mc','Şerefxanê Bidlîsî Şerefname di kîjan salê de temam kir?',
  ['1597','1497','1697','1797'],'1597',
  'Şerefname di 1597an de bi farisî hat nivîsandin.',
  'Şerefname 1597\'de Farsça yazıldı.',DIROK)
q('Dîrok',2,'mc','Bedirxan Beg mîrê kîjan mîrektiyê bû?',
  ['Botan','Baban','Erdelan','Soran'],'Botan',
  'Bedirxan Beg mîrê Botanê bû; serhildana wî ya 1840î navdar e.',
  'Bedirhan Bey Botan emiriydi; 1840\'lardaki isyanı ünlüdür.',DIROK)
q('Dîrok',4,'mc','Mîrektiya Baban navenda xwe bi giştî li ku derê bû?',
  ['Silêmanî','Hewlêr','Wan','Kirmanşan'],'Silêmanî',
  'Mîrektiya Baban di sedsala 18-19em de navenda xwe Silêmanî bû.',
  'Baban Emirliği 18-19. yüzyılda merkezini Süleymaniye\'de kurdu.',DIROK)
q('Dîrok',5,'mc','Peymana Zuhabê (Qesr-î Şîrîn, 1639) ji bo kurdan çima girîng e?',
  ['Herêma kurdî di navbera Osmanî û Sefewiyan de hat parvekirin',
   'Dewleteke kurdî damezrand','Alfabeya kurdî fermî kir',
   'Koçberiya kurdan rawestand'],
  'Herêma kurdî di navbera Osmanî û Sefewiyan de hat parvekirin',
  'Peymana 1639an sînorê Osmanî-Sefewî destnîşan kir û herêma kurdî ji hev qut kir.',
  '1639 antlaşması Osmanlı-Safevi sınırını çizdi ve Kürt bölgesini ikiye böldü.',DIROK)
q('Dîrok',3,'mc','Kovara "Jîn" di kîjan salan de derket?',
  ['Salên 1918-1919an','Salên 1890î','Salên 1950î','Salên 1970yî'],'Salên 1918-1919an',
  'Kovara Jîn li Stenbolê di 1918-1919an de derket û ji bo hişmendiya netewî girîng bû.',
  'Jîn dergisi İstanbul\'da 1918-1919\'da çıktı ve ulusal bilinç için önemliydi.',DIROK)
q('Dîrok',4,'mc','"Xoybûn" çi bû?',
  ['Rêxistineke siyasî ya kurdan a salên 1920î','Kovareke edebî',
   'Navê bajarekî','Cureyekî muzîkê'],'Rêxistineke siyasî ya kurdan a salên 1920î',
  'Xoybûn di 1927an de li Sûriyeyê hat damezrandin.',
  'Xoybûn 1927\'de Suriye\'de kuruldu.',DIROK)
q('Dîrok',2,'tf','Rast e an şaş e: Selahedînê Eyûbî Dewleta Eyûbiyan damezrand.',
  ['Rast','Şaş'],'Rast',
  'Selahedîn di 1171ê de li Misirê Dewleta Eyûbiyan ava kir.',
  'Selahaddin 1171\'de Mısır\'da Eyyubi Devleti\'ni kurdu.',DIROK)
q('Dîrok',5,'mc','Di dîroka nûjen de "Kurdên Sor" (Sûriye) bi çi têkildar e?',
  ['Bêwelatiya kurdên Sûriyeyê piştî serjimara 1962yan',
   'Komeleyeke muzîkê','Partiyeke Iraqê','Rêxistineke perwerdehiyê'],
  'Bêwelatiya kurdên Sûriyeyê piştî serjimara 1962yan',
  'Serjimara 1962yan li Cizîrê bi sed hezaran kurd bêwelat hiştin.',
  '1962 Cezire sayımı yüz binlerce Kürdü vatansız bıraktı.',DIROK)
q('Dîrok',3,'mc','Qelaya Hewlêrê bi çi taybetî tê nasîn?',
  ['Yek ji kevintirîn cihên bi domdarî lêniştî yên cîhanê',
   'Yekem zanîngeha herêmê','Navenda bazirganiyê ya Osmanî','Bendaveke kevnar'],
  'Yek ji kevintirîn cihên bi domdarî lêniştî yên cîhanê',
  'Qelaya Hewlêrê di 2014an de ket lîsteya mîrateya cîhanî ya UNESCOyê.',
  'Erbil Kalesi 2014\'te UNESCO Dünya Mirası listesine girdi.',COGRAFYA)

# EDEBIYAT
q('Edebiyat',3,'mc','Elî Herîrî di wêjeya kurdî de bi çi tê nasîn?',
  ['Helbestvanekî klasîk ê pêşîn','Yekem romannivîs','Dîroknas','Ferhengnas'],
  'Helbestvanekî klasîk ê pêşîn',
  'Elî Herîrî (sedsala 15-16em) wek yek ji pêşiyên helbesta klasîk a kurdî tê hesibandin.',
  'Elî Herîrî (15-16. yy), klasik Kürt şiirinin öncülerinden sayılır.',WEJE)
q('Edebiyat',4,'mc','Berhema "Rewşenbîr" an kovarên edebî yên kurdî bi giştî çi rol lîstin?',
  ['Pêşxistina zimanê nivîskî yê kurdî','Belavkirina muzîkê',
   'Rêveberiya bajaran','Perwerdehiya leşkerî'],'Pêşxistina zimanê nivîskî yê kurdî',
  'Kovarên edebî ji bo standardkirin û pêşxistina kurdiya nivîskî rolek sereke lîstin.',
  'Edebiyat dergileri, yazılı Kürtçenin standartlaşması ve gelişmesinde başrol oynadı.',WEJE)
q('Edebiyat',2,'mc','Peyva "pirtûk" bi Tirkî çi tê wateyê?',
  ['kitap','kalem','defter','masa'],'kitap','"Pirtûk" bi Tirkî "kitap" e.','"Pirtûk" Türkçede "kitap" demektir.',FERHENG)
q('Edebiyat',5,'mc','Di "Mem û Zîn" de karakterê ku bûye sedema veqetîna evîndaran kî ye?',
  ['Bekir','Tacdîn','Mîr Zeynedîn','Sitî'],'Bekir',
  'Bekirê Ewan di destanê de rola fesadiyê dilîze û Mem û Zînê ji hev dûr dixe.',
  'Bekir, destanda fesatlık rolü oynar ve Mem ile Zin\'i birbirinden ayırır.',WEJE)
q('Edebiyat',3,'mc','Berhemên Cegerxwîn bi giştî li ser çi ne?',
  ['Welatparêzî, azadî û jiyana gel','Tenê evîna kesane',
   'Zanistiya xwezayî','Rêzimana kurdî'],'Welatparêzî, azadî û jiyana gel',
  'Cegerxwîn helbesta xwe bi doza gel û azadiyê ve girê da.',
  'Cegerxwîn şiirini halkın davası ve özgürlükle ilişkilendirdi.',WEJE)
q('Edebiyat',4,'mc','"Bahoz" an romanên nûjen ên kurdî bi piranî di kîjan serdemê de zêde bûn?',
  ['Piştî salên 1980î','Di sedsala 17em de','Berî 1900î','Di 1930î de'],
  'Piştî salên 1980î',
  'Bi diasporayê re û bi weşanxaneyên nû re romana kurdî piştî 1980î bi lez zêde bû.',
  'Diaspora ve yeni yayınevleriyle Kürt romanı 1980 sonrası hızla çoğaldı.',WEJE)
q('Edebiyat',2,'tf','Rast e an şaş e: Ehmedê Xanî di Mem û Zînê de behsa yekîtiya kurdan jî dike.',
  ['Rast','Şaş'],'Rast',
  'Xanî di destanê de li ser bêyekîtiya mîrektiyan rexne dike.',
  'Xanî destanda emirlikler arasındaki birliksizliği eleştirir.',WEJE)

# COGRAFYA
q('Cografya',2,'mc','Çemê Firat ji kîjan herêmê diherike?',
  ['Çiyayên rojhilatê Anatolyayê','Deşta Konyayê','Çiyayên Kafkasyayê','Peravê Behra Reş'],
  'Çiyayên rojhilatê Anatolyayê',
  'Firat ji çiyayên rojhilatê Anatolyayê dest pê dike û diçe Kendava Basrayê.',
  'Fırat, Doğu Anadolu dağlarından doğar ve Basra Körfezi\'ne dökülür.',COGRAFYA)
q('Cografya',3,'mc','Bajarê Silêmaniyê li kîjan welatî ye?',
  ['Iraq','Îran','Sûriye','Tirkiye'],'Iraq',
  'Silêmanî li Herêma Kurdistanê ya Iraqê ye.',
  'Süleymaniye, Irak Kürdistan Bölgesi\'ndedir.',COGRAFYA)
q('Cografya',3,'mc','Bajarê Mêrdînê bi çi taybetiya xwe ya mîmarî navdar e?',
  ['Avahiyên kevirî yên li ser çiyê','Bircên şûşeyî','Kanalên avê','Baxçeyên ser banî'],
  'Avahiyên kevirî yên li ser çiyê',
  'Mêrdîn bi avahiyên kevirî yên li ser bejahiyê ku li deşta Mezopotamyayê dinêrin navdar e.',
  'Mardin, Mezopotamya ovasına bakan yamaçtaki taş yapılarıyla ünlüdür.',COGRAFYA)
q('Cografya',4,'mc','Çiyayê Cûdî di sînorên kîjan bajarî de dimîne?',
  ['Şirnex','Wan','Amed','Riha'],'Şirnex',
  'Çiyayê Cûdî li herêma Şirnexê ye û di çîrokên olî de jî derbas dibe.',
  'Cudi Dağı Şırnak bölgesindedir ve dini anlatılarda da geçer.',COGRAFYA)
q('Cografya',2,'mc','Peyva "gund" bi Tirkî çi tê wateyê?',
  ['köy','şehir','dağ','ova'],'köy','"Gund" bi Tirkî "köy" e.','"Gund" Türkçede "köy" demektir.',FERHENG)
q('Cografya',4,'mc','Herêma "Serhed" bi giştî kîjan derdorê digire?',
  ['Herêma bilind a Agirî-Wan-Mûşê','Peravê Behra Spî',
   'Deşta Cizîrê','Herêma Kirmanşanê'],'Herêma bilind a Agirî-Wan-Mûşê',
  'Serhed navê herêma bilind a bakur e: Agirî, Wan, Mûş, Bidlîs.',
  'Serhed, kuzeydeki yüksek bölgenin adıdır: Ağrı, Van, Muş, Bitlis.',COGRAFYA)
q('Cografya',5,'mc','Deşta Cizîrê bi giştî li ku derê ye?',
  ['Di navbera Dîcle û Firatê de, bakurê rojhilatê Sûriyeyê',
   'Rojavayê Îranê','Başûrê Tirkiyeyê','Bakurê Iraqê ya çiyayî'],
  'Di navbera Dîcle û Firatê de, bakurê rojhilatê Sûriyeyê',
  'Cizîre (Cezire) deşta çandiniyê ya di navbera her du çeman de ye.',
  'Cezire, iki nehir arasındaki tarım ovasıdır.',COGRAFYA)
q('Cografya',3,'tf','Rast e an şaş e: Çiyayê Agirî çiyayekî volkanîk e.',
  ['Rast','Şaş'],'Rast',
  'Agirî çiyayekî volkanîk ê nefeal e.','Ağrı Dağı sönmüş bir volkanik dağdır.',COGRAFYA)

# MUZÎK
q('Muzîk',2,'mc','"Zirne" cureyekî çi amûrê ye?',
  ['Amûra pifê','Amûra têlî','Amûra lêdanê','Amûra kevanî'],'Amûra pifê',
  'Zirne amûreke pifê ya bi dengê bilind e; bi def re tê lêxistin.',
  'Zurna yüksek sesli üflemeli çalgıdır; davulla birlikte çalınır.',MUZIK)
q('Muzîk',3,'mc','"Heyranok" di muzîka kurdî de bi giştî çi ye?',
  ['Stranên kurt ên bi gelemperî evîndar','Reqsa dawetê',
   'Amûreke têlî','Rêbaza notagirtinê'],'Stranên kurt ên bi gelemperî evîndar',
  'Heyranok stranên kurt in û pir caran bi awayê pirs-bersiv tên gotin.',
  'Heyranok kısa ezgilerdir, sık sık soru-cevap biçiminde söylenir.',MUZIK)
q('Muzîk',4,'mc','Meryem Xan di muzîka kurdî de kî ye?',
  ['Dengbêjeke jin a navdar a sedsala 20em','Nivîskareke roman',
   'Damezrînera kovarekê','Lêdera tembûrê ya yekem'],
  'Dengbêjeke jin a navdar a sedsala 20em',
  'Meryem Xan (1904-1949) yek ji dengbêjên jin ên herî navdar e.',
  'Meryem Xan (1904-1949) en tanınmış kadın dengbêjlerdendir.',MUZIK)
q('Muzîk',3,'mc','Radyoya Erîvanê ji bo muzîka kurdî çima girîng e?',
  ['Ji salên 1950î ve stranên kurdî belav kir','Yekem albûma kurdî çap kir',
   'Dibistaneke muzîkê bû','Festîvalek bû'],'Ji salên 1950î ve stranên kurdî belav kir',
  'Weşana kurdî ya Radyoya Erîvanê bû çavkaniyeke sereke ya arşîva dengbêjiyê.',
  'Erivan Radyosu\'nun Kürtçe yayını, dengbêj arşivinin ana kaynağı oldu.',MUZIK)
q('Muzîk',2,'mc','Peyva "deng" bi Tirkî çi tê wateyê?',
  ['ses','söz','saz','şarkı'],'ses','"Deng" bi Tirkî "ses" e.','"Deng" Türkçede "ses" demektir.',FERHENG)
q('Muzîk',5,'mc','Di dengbêjiyê de "kilamên şer" bi giştî li ser çi ne?',
  ['Bûyerên şer û berxwedanê','Dawet û şahiyan','Çandinî','Rêzimanê'],
  'Bûyerên şer û berxwedanê',
  'Kilamên şer bûyerên dîrokî yên şer, êrîş û berxwedanê vediguhezînin.',
  'Savaş kilamları; savaş, saldırı ve direniş olaylarını aktarır.',MUZIK)
q('Muzîk',4,'tf','Rast e an şaş e: Def û erbane herdu jî amûrên lêdanê ne.',
  ['Rast','Şaş'],'Rast',
  'Herdu jî bi çerm têne çêkirin û bi lêdanê deng didin.',
  'İkisi de deri kaplıdır ve vurularak ses verir.',MUZIK)

# SIYASET
q('Siyaset',3,'mc','Di sîstema meclîsên gel de biryar bi giştî çawa tên girtin?',
  ['Bi nîqaş û lihevkirina beşdaran','Ji aliyê pisporan ve bi tenê',
   'Bi fermana navendî','Bi hilbijartina her deh salan'],
  'Bi nîqaş û lihevkirina beşdaran',
  'Meclîsên gel biryardayîna rasterast dixin pêş; nîqaş û lihevkirin bingeh in.',
  'Halk meclisleri doğrudan karar almayı öne alır; tartışma ve uzlaşma esastır.',PARADIGMA)
q('Siyaset',4,'mc','"Kurdên Feylî" bi giştî li kîjan herêmê dijîn?',
  ['Sînorê Iraq-Îranê, herêma Bexda û Îlamê','Bakurê Sûriyeyê',
   'Rojavayê Tirkiyeyê','Kafkasya'],'Sînorê Iraq-Îranê, herêma Bexda û Îlamê',
  'Feylî kurdên şîî ne; di 1980î de bi sed hezaran ji Iraqê hatin dersînorkirin.',
  'Feyli Kürtler Şii Kürtlerdir; 1980\'de yüz binlercesi Irak\'tan sürüldü.',SIYASET)
q('Siyaset',2,'mc','Peyva "gel" bi Tirkî çi tê wateyê?',
  ['halk','devlet','ordu','şehir'],'halk','"Gel" bi Tirkî "halk" e.','"Gel" Türkçede "halk" demektir.',SIYASET)
q('Siyaset',5,'mc','Statuya "Kerkûk" di siyaseta Iraqê de bi kîjan maddeya destûrî ve girêdayî ye?',
  ['Maddeya 140î','Maddeya 5em','Maddeya 61ê','Maddeya 100î'],'Maddeya 140î',
  'Maddeya 140î pêvajoya normalîzasyon, serjimar û referandûmê ji bo herêmên nakok diyar dike.',
  '140. madde, tartışmalı bölgeler için normalleşme, sayım ve referandum sürecini tanımlar.',SIYASET)
q('Siyaset',3,'tf','Rast e an şaş e: Li Rojava pergala hevserokatiyê tê sepandin.',
  ['Rast','Şaş'],'Rast',
  'Di rêveberiya Rojava de her post bi jinek û mêrek re tê parvekirin.',
  'Rojava yönetiminde her makam bir kadın ve bir erkekle paylaşılır.',SIYASET)
q('Siyaset',4,'mc','"Diaspora" ya kurdî bi giştî li ku derê herî zêde ye?',
  ['Ewropaya Rojava','Amerîkaya Başûr','Afrîkaya Başûr','Awustralya'],'Ewropaya Rojava',
  'Almanya, Fransa, Swêd û Hollanda niştecihên kurd ên herî zêde dihewînin.',
  'Almanya, Fransa, İsveç ve Hollanda en büyük Kürt nüfusunu barındırır.',SIYASET)

# PARADIGMA
q('Paradigma',3,'mc','Di paradîgmayê de "kooperatîf" çima girîng e?',
  ['Hilberîna hevpar li şûna kara kesane','Bilindkirina bihayan',
   'Kêmkirina beşdariyê','Navendîkirina biryarê'],'Hilberîna hevpar li şûna kara kesane',
  'Kooperatîf modela aboriya komunal e: xebat û encam tên parvekirin.',
  'Kooperatif, komünal ekonominin modelidir: emek ve sonuç paylaşılır.',PARADIGMA)
q('Paradigma',4,'mc','"Akademî" di modela civakî ya Rojava de çi rol dilîze?',
  ['Perwerdehiya civakî û ramanî','Tenê perwerdehiya teknîkî',
   'Rêveberiya darayî','Kontrola sînoran'],'Perwerdehiya civakî û ramanî',
  'Akademî cihên perwerdehiya kolektîf in: jineolojî, ekolojî, ziman û rêxistinbûn.',
  'Akademiler kolektif eğitim alanlarıdır: jineoloji, ekoloji, dil ve örgütlenme.',PARADIGMA)
q('Paradigma',5,'mc','Rexneya "pozîtîvîzmê" di vê paradîgmayê de li ser çi ye?',
  ['Zanist ji civak û exlaqê nayê veqetandin','Zanist bi tenê rast e',
   'Ezmûn ne pêwîst e','Dîrok ne girîng e'],'Zanist ji civak û exlaqê nayê veqetandin',
  'Pozîtîvîzm wek "zanista bêbandor" tê rexnekirin; her zanist di nav civakê de tê hilberandin.',
  'Pozitivizm "tarafsız bilim" iddiasıyla eleştirilir; her bilgi toplum içinde üretilir.',PARADIGMA)
q('Paradigma',2,'mc','Peyva "xweza" bi Tirkî çi tê wateyê?',
  ['doğa','şehir','insan','toplum'],'doğa','"Xweza" bi Tirkî "doğa" ye.','"Xweza" Türkçede "doğa" demektir.',PARADIGMA)
q('Paradigma',3,'tf','Rast e an şaş e: Di paradîgmaya ekolojîk de mirov li derveyî xwezayê tê dîtin.',
  ['Şaş','Rast'],'Şaş',
  'Berevajî: mirov beşek ji xwezayê ye; veqetîn wek koka krîzê tê dîtin.',
  'Tersine: insan doğanın parçasıdır; ayrışma krizin kökü olarak görülür.',PARADIGMA)
q('Paradigma',4,'mc','"Hevjiyana azad" di vê paradîgmayê de çi tê wateyê?',
  ['Têkiliya jin û mêr a li ser bingehê wekhevî û azadiyê','Jiyana bêyî civakê',
   'Aboriya bazarê','Rêveberiya navendî'],
  'Têkiliya jin û mêr a li ser bingehê wekhevî û azadiyê',
  'Hevjiyana azad têkiliyê ji xwedîtiyê derdixe û li ser wekheviyê ava dike.',
  'Özgür eş yaşam, ilişkiyi sahiplenmeden çıkarıp eşitlik üzerine kurar.',PARADIGMA)


# ══════════════════════ ÜÇÜNCÜ PARTİ ══════════════════════
# ZIMAN
q('Ziman',1,'mc','Peyva Kurmancî "çav" bi Tirkî çi tê wateyê?',
  ['göz','kulak','burun','el'],'göz','"Çav" bi Tirkî "göz" e.','"Çav" Türkçede "göz" demektir.',FERHENG)
q('Ziman',1,'mc','Peyva Kurmancî "dest" bi Tirkî çi tê wateyê?',
  ['el','ayak','baş','sırt'],'el','"Dest" bi Tirkî "el" e.','"Dest" Türkçede "el" demektir.',FERHENG)
q('Ziman',2,'mc','Peyva Kurmancî "zarok" bi Tirkî çi tê wateyê?',
  ['çocuk','yaşlı','komşu','misafir'],'çocuk','"Zarok" bi Tirkî "çocuk" e.','"Zarok" Türkçede "çocuk" demektir.',FERHENG)
q('Ziman',2,'mc','Peyva Kurmancî "spas" bi Tirkî çi tê wateyê?',
  ['teşekkür','merhaba','hoşça kal','lütfen'],'teşekkür',
  '"Spas" bi Tirkî "teşekkür" e; "spas dikim" = teşekkür ederim.',
  '"Spas" Türkçede "teşekkür"dür; "spas dikim" = teşekkür ederim.',FERHENG)
q('Ziman',3,'mc','Dijwateya peyva "dirêj" di Kurmancî de kîjan e?',
  ['Kurt','Fireh','Giran','Nerm'],'Kurt','"Dirêj" (uzun) û "kurt" (kısa) dijwate ne.','"Dirêj" (uzun) ile "kurt" (kısa) zıt anlamlıdır.',FERHENG)
q('Ziman',3,'mc','Di Kurmancî de "ez dixwazim" hevoka çi demê ye?',
  ['Dema niha','Dema borî','Dema bê','Raweya fermanî'],'Dema niha',
  'Pêşgira "di-" nîşana dema niha ye: "ez di-xwaz-im".','"di-" ön eki şimdiki zamanı gösterir: "ez dixwazim".',REZIMAN)
q('Ziman',4,'mc','Di Kurmancî de paşgira "-van" di peyvên wek "dergehvan" de çi diyar dike?',
  ['Kesê ku karekî dike','Cih','Dem','Hejmar'],'Kesê ku karekî dike',
  '"-van" paşgira kirdeyê ye: dergehvan (kapıcı), stranvan, hunervan.',
  '"-van" fail ekidir: dergehvan (kapıcı), stranvan, hunervan.',REZIMAN)
q('Ziman',4,'mc','Di Kurmancî de "were" û "biçe" kîjan raweyê nîşan didin?',
  ['Raweya fermanî','Raweya bilanî','Dema borî','Dema bê'],'Raweya fermanî',
  'Herdu jî ferman in: "were" (gel), "biçe" (git).','İkisi de emirdir: "were" (gel), "biçe" (git).',REZIMAN)
q('Ziman',5,'mc','Di Kurmancî de "min got" û "ez gotim" — kîjan rast e?',
  ['"Min got" rast e','"Ez gotim" rast e','Herdu jî rast in','Herdu jî şaş in'],
  '"Min got" rast e',
  'Lêkera "gotin" gerguhêz e; di dema borî de biker tê tewandin: "min got".',
  '"Gotin" geçişlidir; geçmiş zamanda özne büküme girer: "min got".',REZIMAN)
q('Ziman',5,'mc','Di Kurmancî de cudahiya "-ê" û "-a" ya veqetandekê çi ye?',
  ['Zayend: "-ê" nêr, "-a" mê','Hejmar: "-ê" yekjimar, "-a" pirjimar',
   'Dem: "-ê" borî, "-a" niha','Rewş: "-ê" xwerû, "-a" tewandî'],
  'Zayend: "-ê" nêr, "-a" mê',
  '"Bavê min" (nêr) lê "diya min" (mê) — veqetandek zayendê nîşan dide.',
  '"Bavê min" (eril) ama "diya min" (dişil) — izafe cinsiyeti gösterir.',REZIMAN)
q('Ziman',2,'mc','Peyva "hevîr" bi Tirkî çi tê wateyê?',
  ['hamur','peynir','tuz','yağ'],'hamur','"Hevîr" bi Tirkî "hamur" e.','"Hevîr" Türkçede "hamur" demektir.',FERHENG)
q('Ziman',3,'mc','Hevwateya peyva "westiyayî" di Kurmancî de kîjan e?',
  ['Betilî','Kêfxweş','Bilez','Nexweş'],'Betilî',
  '"Westiyayî" û "betilî" herdu jî wateya bêhalbûnê didin.','"Westiyayî" ve "betilî" ikisi de yorgunluk anlamındadır.',FERHENG)
q('Ziman',4,'tf','Rast e an şaş e: Di Kurmancî de sifet (rengdêr) piştî navdêrê tê.',
  ['Rast','Şaş'],'Rast','Wek "mala mezin" — rengdêr piştî navdêrê tê û bi veqetandekê tê girêdan.','"Mala mezin" gibi — sıfat isimden sonra gelir ve izafeyle bağlanır.',REZIMAN)
q('Ziman',2,'mc','Peyva "heyv" bi Tirkî çi tê wateyê?',
  ['ay','güneş','yıldız','gök'],'ay','"Heyv" bi Tirkî "ay" e.','"Heyv" Türkçede "ay" demektir.',FERHENG)
q('Ziman',3,'mc','Peyva "zanîngeh" ji kîjan beşan pêk tê?',
  ['Zanîn + geh (cih)','Zan + îng','Za + nîngeh','Zanî + gehîn'],'Zanîn + geh (cih)',
  '"Geh" paşgira cih e: cihê zanînê.','"Geh" yer ekidir: bilgi yeri, üniversite.',FERHENG)

# ÇAND
q('Çand',2,'mc','Xwarina "savar" ji çi tê çêkirin?',
  ['Genim','Birinc','Ard','Nok'],'Savar'.replace('Savar','Genim'),
  'Savar ji genimê kelandî û hûrkirî tê çêkirin.','Bulgur, haşlanıp kırılmış buğdaydan yapılır.',FOLKLOR)
q('Çand',3,'mc','Di kevneşopiya kurdî de "mêvanperwerî" çi tê wateyê?',
  ['Mêvan bi rûmet pêşwazîkirin','Bazirganiya dûr',
   'Rêûresma zewacê','Pîrozkirina cejnê'],'Mêvan bi rûmet pêşwazîkirin',
  'Mêvanperwerî yek ji nirxên herî bilind ên civaka kurdî ye.','Misafirperverlik Kürt toplumunun en yüksek değerlerindendir.',FOLKLOR)
q('Çand',4,'mc','"Çadira reş" bi giştî ji çi tê çêkirin?',
  ['Hiriyê bizinê','Pembû','Hevrîşim','Kaxez'],'Hiriyê bizinê',
  'Çadira koçeran ji hiriyê bizinê tê hûnandin; av derbas nake û bayê digire.',
  'Göçerlerin kara çadırı keçi kılından dokunur; su geçirmez, rüzgârı keser.',FOLKLOR)
q('Çand',3,'mc','Di çanda kurdî de "koçerî" çi ye?',
  ['Jiyana bi ajalan re ya guhêrbar','Cotkariya nîştecih',
   'Bazirganiya bajaran','Masîgiriya golê'],'Jiyana bi ajalan re ya guhêrbar',
  'Koçer li gorî demsalan bi pez û dewaran re di navbera zozan û germiyanê de digerin.',
  'Göçerler, mevsime göre sürüleriyle yayla ve kışlak arasında hareket eder.',FOLKLOR)
q('Çand',2,'mc','"Zozan" çi ye?',
  ['Çîmena çiyayî ya havînê','Gundê zivistanê','Bajarê mezin','Cihê bazarê'],
  'Çîmena çiyayî ya havînê',
  'Zozan çiyayên bilind ên ku di havînê de ji bo pez tên bikaranîn.','Zozan (yayla), yazın sürüler için kullanılan yüksek otlaklardır.',FOLKLOR)
q('Çand',4,'mc','Di rêûresma şînê ya kurdî de "şînbêj" kî ye?',
  ['Kesa ku bi dengekî bilind lorî û şîn dibêje','Kesê ku mêvanan dibîne',
   'Kesê ku xwarinê çêdike','Kesê ku qebrê amade dike'],
  'Kesa ku bi dengekî bilind lorî û şîn dibêje',
  'Şînbêj bi gelemperî jin in û bi kilamên şînê xemgîniyê vedibêjin.',
  'Şînbêj genelde kadınlardır; ağıt kilamlarıyla yası dile getirir.',FOLKLOR)
q('Çand',3,'mc','"Berbang" di Kurmancî de çi tê wateyê?',
  ['Serê sibê / şafak','Nîvê şevê','Danê êvarê','Nîvro'],'Serê sibê / şafak',
  '"Berbang" wextê ku ronahî dest pê dike ye.','"Berbang" ışığın söktüğü an, şafaktır.',FERHENG)
q('Çand',5,'mc','Di destana "Siyabend û Xecê" de mijara sereke çi ye?',
  ['Evîna trajîk a li çiyê','Şerê du eşîran','Rêwîtiya bazirganekî','Damezrandina gundekî'],
  'Evîna trajîk a li çiyê',
  'Siyabend û Xecê evîndarên destanê ne; çîrok bi trajediyê li çiyê diqede.',
  'Siyabend ile Xecê destanın âşıklarıdır; hikâye dağda trajediyle biter.',FOLKLOR)
q('Çand',2,'tf','Rast e an şaş e: Govend bi gelemperî bi destgirtin tê lîstin.',
  ['Rast','Şaş'],'Rast','Di govendê de mirov bi destan an bi qolan digirin.','Halayda eller ya da kollar tutulur.',FOLKLOR)
q('Çand',3,'mc','Xwarina "serê salê" an xwarinên cejnê bi giştî çima girîng in?',
  ['Ji ber ku civak û malbatê tînin cem hev','Ji ber ku erzan in',
   'Ji ber ku zû tên çêkirin','Ji ber ku tenê ji bo mêvanan in'],
  'Ji ber ku civak û malbatê tînin cem hev',
  'Sifreya cejnê fonksiyoneke civakî digire: xizm û cîran tên cem hev.',
  'Bayram sofrası toplumsal bir işlev taşır: akraba ve komşuyu bir araya getirir.',FOLKLOR)
q('Çand',4,'mc','"Hevrîşk" an "hevrîşim" di destkariya kurdî de çi ye?',
  ['Hevrîşim (ipek) — ji bo tevn û xemlê','Cureyekî xwarinê',
   'Amûreke muzîkê','Navê reqsekê'],'Hevrîşim (ipek) — ji bo tevn û xemlê',
  'Hevrîşim di tevn û cilûbergên xemilandî de tê bikaranîn.','İpek, dokuma ve süslü giysilerde kullanılır.',FOLKLOR)
q('Çand',2,'mc','"Tevn" di destkariya kurdî de çi ye?',
  ['Amûra hûnandina xalîçe û bêrîkan','Cureyekî nanê',
   'Amûreke muzîkê','Navê cejnekê'],'Amûra hûnandina xalîçe û bêrîkan',
  'Tevn ji bo hûnandina xalîçe, kilîm û tûrikan tê bikaranîn.','Tezgâh; halı, kilim ve heybe dokumak için kullanılır.',FOLKLOR)
q('Çand',3,'mc','Xalîçe û kilîmên kurdî bi giştî bi çi tên xemilandin?',
  ['Motîfên hêjmarî û sembolîk','Wêneyên fotoğrafî',
   'Nivîsên dirêj','Rengên tenê reş û spî'],'Motîfên hêjmarî û sembolîk',
  'Her motîf wateyeke xwe heye: bereket, parastin, malbat.','Her motifin bir anlamı vardır: bereket, koruma, aile.',FOLKLOR)
q('Çand',5,'mc','Di civaka kurdî de "xwarina şîvê ya hevpar" li dîwanxaneyê bi giştî çi fonksiyonê digire?',
  ['Danûstandina civakî û biryardayîn','Tenê xwarinxwarin',
   'Perwerdehiya fermî','Bazirganî'],'Danûstandina civakî û biryardayîn',
  'Dîwanxane cihê nîqaş û biryara civakî ye; xwarin vê civînê dihewîne.',
  'Dîwanxane toplumsal tartışma ve karar yeridir; yemek bu toplantıyı çerçeveler.',FOLKLOR)

# DÎROK
q('Dîrok',3,'mc','Bajarê Amedê di serdema Romayê de çi rolê digirt?',
  ['Bajarekî sînor ê stratejîk','Paytexta împeratoriyê',
   'Navenda olî ya sereke','Girava bazirganiyê'],'Bajarekî sînor ê stratejîk',
  'Amida di navbera Roma û Sasaniyan de bajarekî sînor ê stratejîk bû.',
  'Amida, Roma ile Sasaniler arasında stratejik bir sınır kentiydi.',DIROK)
q('Dîrok',4,'mc','Xanedaniya Mervaniyan bi giştî li ku derê hukum kir?',
  ['Amed û derdora wê','Misir','Endulûs','Xorasan'],'Amed û derdora wê',
  'Mervanî (990-1085) li Amed û Meyafarqînê hukum kirin.','Mervaniler (990-1085) Amed ve Silvan çevresinde hüküm sürdü.',DIROK)
q('Dîrok',5,'mc','Xanedaniya Şedadiyan bi giştî li kîjan herêmê hukum kir?',
  ['Kafkasya (Gence-Anî)','Misir','Endulûs','Hindistan'],'Kafkasya (Gence-Anî)',
  'Şedadî xanedaneke kurd bû ku li Kafkasyayê, li derdora Gence û Aniyê hukum kir.',
  'Şeddadiler, Kafkasya\'da Gence ve Ani çevresinde hüküm süren Kürt hanedanıydı.',DIROK)
q('Dîrok',2,'mc','Selahedînê Eyûbî li kîjan bajarî ji dayik bû?',
  ['Tikrît','Şam','Qahîre','Musil'],'Tikrît',
  'Selahedîn di 1137an de li Tikrîtê ji dayik bû.','Selahaddin 1137\'de Tikrit\'te doğdu.',DIROK)
q('Dîrok',4,'mc','Şerê Çaldiranê (1514) di navbera kê de bû?',
  ['Osmanî û Sefewî','Roma û Sasanî','Med û Asûrî','Eyûbî û Xaçparêz'],'Osmanî û Sefewî',
  'Şerê Çaldiranê rêza hêzê li rojhilat guhert û herêma kurdî di navbera her du hêzan de ma.',
  'Çaldıran Savaşı doğudaki güç dengesini değiştirdi; Kürt bölgesi iki güç arasında kaldı.',DIROK)
q('Dîrok',3,'mc','Îdrîsê Bidlîsî di dîroka Osmanî de bi çi tê nasîn?',
  ['Navbeynkariya di navbera Osmanî û mîrên kurd de','Nivîsandina Mem û Zînê',
   'Damezrandina Komara Mehabadê','Weşandina kovara Hawarê'],
  'Navbeynkariya di navbera Osmanî û mîrên kurd de',
  'Îdrîsê Bidlîsî piştî Çaldiranê di girêdana mîrektiyên kurd bi Osmaniyan re rolek lîst.',
  'İdris-i Bitlisi, Çaldıran sonrası Kürt emirliklerinin Osmanlı\'ya bağlanmasında rol oynadı.',DIROK)
q('Dîrok',5,'mc','Mîrektiya Erdelan navenda xwe li ku derê bû?',
  ['Sine (Sanandaj)','Cizîr','Hewlêr','Bidlîs'],'Sine (Sanandaj)',
  'Erdelan mîrektiyeke rojhilatê Kurdistanê bû; navenda wê Sine bû.',
  'Erdelan, Doğu Kürdistan\'da bir emirlikti; merkezi Sine (Senendec) idi.',DIROK)
q('Dîrok',2,'tf','Rast e an şaş e: Kovara Hawar bi alfabeya latînî hat weşandin.',
  ['Rast','Şaş'],'Rast','Hawar alfabeya latînî ya kurdî bi kar anî û belav kir.','Hawar, Kürtçe Latin alfabesini kullandı ve yaydı.',DIROK)
q('Dîrok',4,'mc','Kovara "Ronahî" ji aliyê kê ve hat weşandin?',
  ['Celadet Alî Bedirxan','Ehmedê Xanî','Qadî Mihemed','Erebê Şemo'],'Celadet Alî Bedirxan',
  'Ronahî (1942) piştî Hawarê ji aliyê Celadet ve li Şamê derket.','Ronahî (1942), Hawar\'dan sonra Celadet tarafından Şam\'da çıkarıldı.',DIROK)
q('Dîrok',3,'mc','Kurdên Kafkasyayê (Ermenistan-Gurcistan) bi giştî di kîjan serdemê de li wir bi cih bûn?',
  ['Sedsalên 19-20em','Sedsala 12em','Berî zayînê','Sedsala 21em'],'Sedsalên 19-20em',
  'Bi şer û koçberiyên sedsala 19-20em re civakeke kurd li Kafkasyayê ava bû.',
  '19-20. yüzyıl savaş ve göçleriyle Kafkasya\'da bir Kürt topluluğu oluştu.',DIROK)
q('Dîrok',4,'mc','Yekem weşana radyoyê ya bi kurdî li Erîvanê di kîjan salan de dest pê kir?',
  ['Salên 1950î','Salên 1920î','Salên 1980î','Salên 2000î'],'Salên 1950î',
  'Weşana kurdî ya Radyoya Erîvanê ji salên 1950î ve dest pê kir û bû arşîvek girîng.',
  'Erivan Radyosu\'nun Kürtçe yayını 1950\'lerde başladı ve önemli bir arşiv oldu.',MUZIK)
q('Dîrok',5,'mc','"Şerefname" bi kîjan zimanî hat nivîsandin?',
  ['Farisî','Kurmancî','Erebî','Tirkî'],'Farisî',
  'Şerefxanê Bidlîsî berhema xwe bi farisî nivîsî; paşê hat wergerandin.',
  'Şerefhan Bitlisi eserini Farsça yazdı; sonradan çevrildi.',DIROK)
q('Dîrok',3,'mc','Qelaya Dimdimê di dîroka kurdî de bi çi tê nasîn?',
  ['Berxwedana li dijî hêzeke mezin','Navenda bazirganiyê',
   'Cihê weşanê','Zanîngeheke kevn'],'Berxwedana li dijî hêzeke mezin',
  'Berxwedana Dimdimê (sedsala 17em) bû mijara destan û kilaman.',
  'Dimdim direnişi (17. yy) destan ve kilamlara konu oldu.',DIROK)
q('Dîrok',2,'mc','Peyva "dîrok" bi Tirkî çi tê wateyê?',
  ['tarih','coğrafya','edebiyat','müzik'],'tarih','"Dîrok" bi Tirkî "tarih" e.','"Dîrok" Türkçede "tarih" demektir.',FERHENG)
q('Dîrok',4,'mc','Mîrektiyên kurd bi giştî di kîjan sedsalê de hatin ji holê rakirin?',
  ['Sedsala 19em','Sedsala 15em','Sedsala 21em','Sedsala 10em'],'Sedsala 19em',
  'Bi navendîkirina Osmanî re mîrektiyên kurd di sedsala 19em de yek bi yek hatin hilweşandin.',
  'Osmanlı merkezileşmesiyle Kürt emirlikleri 19. yüzyılda tek tek kaldırıldı.',DIROK)

# EDEBIYAT
q('Edebiyat',3,'mc','Melayê Cizîrî li kîjan bajarî jiya?',
  ['Cizîr','Hewlêr','Wan','Şam'],'Cizîr',
  'Melayê Cizîrî li Cizîra Botan jiya û navê xwe ji wir girt.','Melayê Cizîrî Cizre\'de yaşadı ve adını oradan aldı.',WEJE)
q('Edebiyat',4,'mc','Di wêjeya kurdî de "medrese" çi rol lîst?',
  ['Perwerdehiya klasîk û perwerdekirina helbestvanan','Weşandina rojnameyan',
   'Hilberîna muzîkê','Rêveberiya bajaran'],'Perwerdehiya klasîk û perwerdekirina helbestvanan',
  'Gelek helbestvanên klasîk ên kurd di medreseyan de perwerde bûn.',
  'Klasik Kürt şairlerinin çoğu medreselerde yetişti.',WEJE)
q('Edebiyat',2,'mc','Peyva "çîrok" bi Tirkî çi tê wateyê?',
  ['hikâye','şiir','roman','tiyatro'],'hikâye','"Çîrok" bi Tirkî "hikâye" ye.','"Çîrok" Türkçede "hikâye" demektir.',FERHENG)
q('Edebiyat',5,'mc','"Nûbihar" û "Tîroj" bi giştî çi ne?',
  ['Kovarên çand û wêjeyê','Romanên nûjen','Komên muzîkê','Partiyên siyasî'],
  'Kovarên çand û wêjeyê',
  'Kovarên wêjeyî ji bo domandina kurdiya nivîskî cihekî girîng digirin.',
  'Edebiyat dergileri, yazılı Kürtçenin sürekliliği için önemli yer tutar.',WEJE)
q('Edebiyat',3,'mc','Berhema "Şivanê Kurmanca" di kîjan salê de derket?',
  ['1935','1965','1905','1985'],'1935',
  'Erebê Şemo romana xwe di 1935an de li Kafkasyayê weşand.','Erebê Şemo romanını 1935\'te Kafkasya\'da yayımladı.',WEJE)
q('Edebiyat',4,'mc','Di helbesta kurdî de "qafiye" çi ye?',
  ['Lihevhatina dengên dawiya rêzikan','Hejmara rêzikan',
   'Mijara helbestê','Navê helbestvan'],'Lihevhatina dengên dawiya rêzikan',
  'Qafiye ahenga dengî ya dawiya rêzikan e.','Kafiye, dize sonlarındaki ses uyumudur.',WEJE)
q('Edebiyat',5,'mc','Di klasîkên kurdî de "mesnewî" çi ye?',
  ['Forma helbestî ya çîrokî bi beytên qafiyedar','Cureyekî ferhengê',
   'Rêbaza nivîsandina dîrokê','Navê medreseyekê'],
  'Forma helbestî ya çîrokî bi beytên qafiyedar',
  'Mem û Zîn bi forma mesnewiyê hatiye nivîsandin.','Mem û Zîn mesnevi biçiminde yazılmıştır.',WEJE)
q('Edebiyat',2,'tf','Rast e an şaş e: Cegerxwîn navekî edebî (mahlas) e.',
  ['Rast','Şaş'],'Rast','Navê wî yê rastîn Şêxmûs Hesen bû; "Cegerxwîn" mahlasa wî ye.','Asıl adı Şeyhmus Hasan\'dı; "Cegerxwîn" mahlasıdır.',WEJE)
q('Edebiyat',3,'mc','Wêjeya devkî ya kurdî bi piranî bi çi hatiye veguhastin?',
  ['Dengbêj û çîrokbêjan','Pirtûkên çapkirî','Rojnameyan','Fîlman'],
  'Dengbêj û çîrokbêjan',
  'Berî çapxaneyê, wêje bi devkî — bi dengbêj û çîrokbêjan — hate veguhastin.',
  'Matbaadan önce edebiyat sözlü olarak — dengbêj ve masalcılarla — aktarıldı.',WEJE)
q('Edebiyat',4,'mc','"Zembîlfiroş" di wêjeya kurdî de çi ye?',
  ['Destaneke evînî ya gelêrî','Ferhengek','Rojnameyek','Amûreke muzîkê'],
  'Destaneke evînî ya gelêrî',
  'Zembîlfiroş çîroka evîndarekî hejar e; hem bi devkî hem bi nivîskî belav bûye.',
  'Zembîlfiroş, yoksul bir âşığın hikâyesidir; sözlü ve yazılı olarak yayılmıştır.',WEJE)
q('Edebiyat',3,'mc','Wergera berhemên cîhanî bo kurdî çima girîng tê dîtin?',
  ['Zimanê nivîskî fireh dike û peyvsaziyê dewlemend dike','Tenê ji bo bazarê ye',
   'Ji bo kêmkirina xwendinê','Tenê ji bo dibistanan e'],
  'Zimanê nivîskî fireh dike û peyvsaziyê dewlemend dike',
  'Werger têgehên nû tîne û zimanê nivîskî pêş dixe.','Çeviri yeni kavramlar getirir ve yazılı dili geliştirir.',WEJE)
q('Edebiyat',5,'mc','Di Mem û Zînê de "Tacdîn" kî ye?',
  ['Hevalê dilsoz ê Mem','Bavê Zînê','Mîrê bajêr','Dijminê Mem'],'Hevalê dilsoz ê Mem',
  'Tacdîn di destanê de hevalê Mem e û ji bo wî xwe feda dike.','Tacdin destanda Mem\'in dostudur ve onun için fedakârlık yapar.',WEJE)

# COGRAFYA
q('Cografya',2,'mc','Bajarê Wanê li kêleka çi ye?',
  ['Gola Wanê','Behra Reş','Çemê Firat','Behra Spî'],'Gola Wanê',
  'Wan li peravê rojhilatê Gola Wanê ye.','Van, Van Gölü\'nün doğu kıyısındadır.',COGRAFYA)
q('Cografya',3,'mc','Sûrên dîrokî yên Amedê ji kîjan kevirê volkanîk hatine çêkirin?',
  ['Bazalt','Mermer','Gran"it'.replace('"',''),'Kilsin'],'Bazalt',
  'Sûrên Amedê ji kevirê bazaltî yê reş hatine çêkirin.','Diyarbakır surları siyah bazalt taşındandır.',COGRAFYA)
q('Cografya',4,'mc','Çemê Botan diherike nav kîjan çemî?',
  ['Dîcle','Firat','Zap','Murat'],'Dîcle',
  'Çemê Botan ji Colemêrgê tê û digihîje Dîcleyê.','Botan Çayı Hakkâri\'den gelir ve Dicle\'ye karışır.',COGRAFYA)
q('Cografya',2,'mc','Herêma Kurdistanê ya Iraqê ji çend parêzgehên sereke pêk tê?',
  ['Sê (Hewlêr, Silêmanî, Dihok)','Du','Pênc','Heft'],'Sê (Hewlêr, Silêmanî, Dihok)',
  'Sê parêzgehên bingehîn: Hewlêr, Silêmanî û Dihok.','Üç temel il: Erbil, Süleymaniye ve Duhok.',COGRAFYA)
q('Cografya',3,'mc','Bajarê Kirmanşanê li kîjan welatî ye?',
  ['Îran','Iraq','Sûriye','Tirkiye'],'Îran',
  'Kirmanşan li rojhilatê Kurdistanê, li Îranê ye.','Kirmanşah, Doğu Kürdistan\'da, İran\'dadır.',COGRAFYA)
q('Cografya',4,'mc','Deşta Herîrê an deştên çandiniyê yên başûrê Kurdistanê bi giştî bi çi tên nasîn?',
  ['Çandiniya genim û ceh','Masîgirî','Pîşesaziya giran','Turîzma peravê'],
  'Çandiniya genim û ceh',
  'Deştên başûr ji bo çandiniya genim û ceh guncav in.','Güneydeki ovalar buğday ve arpa tarımına elverişlidir.',COGRAFYA)
q('Cografya',5,'mc','Çiyayê Sîpanê li nêzîkî kîjan golê ye?',
  ['Gola Wanê','Gola Urmiyê','Gola Tuzê','Gola Beyşehîrê'],'Gola Wanê',
  'Sîpan çiyayekî volkanîk ê li bakurê Gola Wanê ye.','Süphan, Van Gölü\'nün kuzeyindeki volkanik dağdır.',COGRAFYA)
q('Cografya',3,'mc','Gola Urmiyê li kîjan welatî ye?',
  ['Îran','Tirkiye','Iraq','Sûriye'],'Îran',
  'Gola Urmiyê li rojhilatê Kurdistanê, li bakurê rojavayê Îranê ye.','Urmiye Gölü, Doğu Kürdistan\'da, İran\'ın kuzeybatısındadır.',COGRAFYA)
q('Cografya',2,'tf','Rast e an şaş e: Dîcle û Firat digihîjin Kendava Basrayê.',
  ['Rast','Şaş'],'Rast','Herdu çem li Şatt el-Erebê digihîjin hev û diçin Kendava Basrayê.','İki nehir Şattülarap\'ta birleşip Basra Körfezi\'ne dökülür.',COGRAFYA)
q('Cografya',4,'mc','Bajarê Dihokê li kîjan welatî ye?',
  ['Iraq','Tirkiye','Îran','Sûriye'],'Iraq',
  'Dihok li Herêma Kurdistanê ya Iraqê, li nêzî sînorê Tirkiyeyê ye.','Duhok, Irak Kürdistan Bölgesi\'nde, Türkiye sınırına yakındır.',COGRAFYA)
q('Cografya',3,'mc','"Zozan" û "germiyan" di jiyana koçeran de çi diyar dikin?',
  ['Warê havînê û warê zivistanê','Du bajarên mezin',
   'Du çemên sereke','Du cureyên xwarinê'],'Warê havînê û warê zivistanê',
  'Koçer havînê li zozanan, zivistanê li germiyanê dimînin.','Göçerler yazın yaylada, kışın kışlakta kalır.',COGRAFYA)
q('Cografya',5,'mc','Herêma Şengalê bi taybetî bi kîjan civakê tê nasîn?',
  ['Êzidî','Asûrî','Ermenî','Turkmen'],'Êzidî',
  'Şengal warê sereke yê civaka êzidî ye.','Şengal, Ezidi toplumunun ana yurdudur.',COGRAFYA)
q('Cografya',2,'mc','Peyva "behr" bi Tirkî çi tê wateyê?',
  ['deniz','göl','nehir','çeşme'],'deniz','"Behr" bi Tirkî "deniz" e.','"Behr" Türkçede "deniz" demektir.',FERHENG)
q('Cografya',4,'mc','Bajarê Efrînê li kîjan welatî ye?',
  ['Sûriye','Tirkiye','Iraq','Îran'],'Sûriye',
  'Efrîn li bakurê rojavayê Sûriyeyê ye.','Efrin, Suriye\'nin kuzeybatısındadır.',COGRAFYA)

# MUZÎK
q('Muzîk',3,'mc','"Şeşxane" an amûrên têlî yên kurdî bi giştî çawa tên lêxistin?',
  ['Bi tiliyan an bi mizrabê','Bi kevanê','Bi pifê','Bi lêdana çermê'],
  'Bi tiliyan an bi mizrabê',
  'Tembûr û saz bi tiliyan an bi mizrabê tên lêxistin.','Tembûr ve saz parmakla ya da mızrapla çalınır.',MUZIK)
q('Muzîk',2,'mc','Di muzîka kurdî de peyva "stranbêj" ji bo kê tê bikaranîn?',
  ['Kesa ku stranan dibêje','Kesê ku amûrê çêdike',
   'Kesê ku reqsê hîn dike','Kesê ku helbestê dinivîse'],'Kesa ku stranan dibêje',
  '"Stranbêj" ji "stran" û "bêj" (gotin) pêk tê.','"Stranbêj", "stran" ve "bêj" (söylemek) sözcüklerinden oluşur.',MUZIK)
q('Muzîk',4,'mc','Di muzîka kurdî de "makam" an "avaz" çi diyar dike?',
  ['Qalibê dengî yê stranê','Hejmara stranbêjan',
   'Dirêjahiya dawetê','Navê amûrê'],'Qalibê dengî yê stranê',
  'Avaz qalibê makamî ye ku stran li ser tê avakirin.','Avaz, şarkının üzerine kurulduğu makam kalıbıdır.',MUZIK)
q('Muzîk',3,'mc','Di dawetên kurdî de reqsa komî bi gelemperî bi kîjan amûran tê meşandin?',
  ['Def û zirne','Tembûr û bilûr','Piano û gîtar','Erbane û ney'],'Def û zirne',
  'Def û zirne bi dengê xwe yê bilind ji bo govenda derve guncav in.','Davul ve zurna, yüksek sesiyle açık hava halayına uygundur.',MUZIK)
q('Muzîk',5,'mc','Di kilamên dengbêjan de "vegotin" çima girîng e?',
  ['Kilam çîrokeke dîrokî diguhezîne','Tenê ahenga dengî girîng e',
   'Reqs pê re tê kirin','Amûr pê re tên lêxistin'],'Kilam çîrokeke dîrokî diguhezîne',
  'Dengbêjî hem muzîk hem arşîva devkî ye: bûyer bi kilamê tên parastin.',
  'Dengbêjlik hem müzik hem sözlü arşivdir: olaylar kilamla korunur.',MUZIK)
q('Muzîk',2,'mc','Peyva "kilam" bi Tirkî bi giştî çi tê wateyê?',
  ['uzun hava / türkü','dans','saz','düğün'],'uzun hava / türkü',
  '"Kilam" stranên dirêj ên çîrokî ne.','"Kilam", hikâye anlatan uzun ezgilerdir.',MUZIK)
q('Muzîk',4,'mc','Di muzîka kurdî ya nûjen de "kom" çi ye?',
  ['Koma stranbêj û muzîkjenan','Amûreke têlî',
   'Cureyekî reqsê','Navê festîvalekê'],'Koma stranbêj û muzîkjenan',
  '"Kom" bi hev re distirên û dilîzin; muzîka komî ya salên 1990î pê tê nasîn.',
  '"Kom", birlikte söyleyip çalan topluluktur; 1990\'ların toplu müziği bununla anılır.',MUZIK)
q('Muzîk',3,'tf','Rast e an şaş e: Bilûr bi pifê tê lêxistin.',
  ['Rast','Şaş'],'Rast','Bilûr amûreke pifê ye.','Kaval üflemeli bir çalgıdır.',MUZIK)
q('Muzîk',5,'mc','Di dengbêjiyê de "şêwe" ya herêmî çi tê wateyê?',
  ['Awayê gotinê yê taybetî yê herêmekê','Navê amûrekê',
   'Dirêjahiya kilamê','Hejmara dengbêjan'],'Awayê gotinê yê taybetî yê herêmekê',
  'Her herêm — Serhed, Botan, Behdînan — şêwazeke dengbêjiyê ya xwe heye.',
  'Her yöre — Serhed, Botan, Behdinan — kendi dengbêj üslubuna sahiptir.',MUZIK)
q('Muzîk',3,'mc','Di stranên zarokan ên kurdî de "lorî" çi ye?',
  ['Strana razanê','Strana dawetê','Kilama şer','Strana cejnê'],'Strana razanê',
  'Lorî ji bo razandina zarokan tê gotin.','Lorî (ninni), çocuğu uyutmak için söylenir.',MUZIK)
q('Muzîk',4,'mc','Muzîka kurdî ya diasporayê bi giştî çi bandor kir?',
  ['Belavbûna cîhanî ya stran û tomarkirinê','Kêmbûna stranan',
   'Rawestandina dengbêjiyê','Guhertina alfabeyê'],
  'Belavbûna cîhanî ya stran û tomarkirinê',
  'Diaspora studyo, weşan û festîvalên nû anî; stran li cîhanê belav bûn.',
  'Diaspora yeni stüdyo, yayın ve festivaller getirdi; şarkılar dünyaya yayıldı.',MUZIK)
q('Muzîk',2,'mc','Peyva "govend" bi Tirkî çi tê wateyê?',
  ['halay','şarkı','saz','düğün'],'halay','"Govend" bi Tirkî "halay" e.','"Govend" Türkçede "halay" demektir.',MUZIK)

# SIYASET
q('Siyaset',3,'mc','Di modela xwerêveberiyê de "meclîsa gund" çi dike?',
  ['Li ser pirsgirêkên gund biryar dide','Tenê muzîkê organîze dike',
   'Bacê berhev dike','Ordû ava dike'],'Li ser pirsgirêkên gund biryar dide',
  'Meclîsa gund yekeya biryardayînê ya herî nêzîk gel e.','Köy meclisi, halka en yakın karar birimidir.',PARADIGMA)
q('Siyaset',4,'mc','Di siyaseta herêmî de "komîsyon" bi giştî çi ye?',
  ['Koma xebatê ya li ser mijarekê','Dadgeheke taybet',
   'Yekîneyeke leşkerî','Sendîkayeke karkeran'],'Koma xebatê ya li ser mijarekê',
  'Komîsyon (perwerde, tenduristî, aborî) xebatê li ser mijarekê birêve dibe.',
  'Komisyon (eğitim, sağlık, ekonomi) belli bir konuda çalışmayı yürütür.',PARADIGMA)
q('Siyaset',2,'mc','Peyva "wekhevî" bi Tirkî çi tê wateyê?',
  ['eşitlik','özgürlük','barış','adalet'],'eşitlik','"Wekhevî" bi Tirkî "eşitlik" e.','"Wekhevî" Türkçede "eşitlik" demektir.',SIYASET)
q('Siyaset',5,'mc','Kurdên Êzidî di 2014an de bi kîjan bûyerê rû bi rû man?',
  ['Êrîşa Şengalê','Referandûma serxwebûnê','Peymana Lozanê','Serjimara Cizîrê'],
  'Êrîşa Şengalê',
  'Di Tebaxa 2014an de Şengal hat êrîşkirin; bi hezaran êzidî hatin qetilkirin an revandin.',
  'Ağustos 2014\'te Şengal saldırıya uğradı; binlerce Ezidi katledildi veya kaçırıldı.',SIYASET)
q('Siyaset',3,'mc','Zimanê perwerdehiyê li Herêma Kurdistanê ya Iraqê bi giştî çi ye?',
  ['Kurdî','Erebî','Îngilîzî','Farisî'],'Kurdî',
  'Li herêmê perwerdehî bi kurdî tê kirin; erebî û îngilîzî wek zimanên din tên hînkirin.',
  'Bölgede eğitim Kürtçedir; Arapça ve İngilizce diğer diller olarak okutulur.',SIYASET)
q('Siyaset',4,'tf','Rast e an şaş e: Diaspora di siyaseta kurdî de rolek dilîze.',
  ['Rast','Şaş'],'Rast','Diaspora bi lobî, weşan û piştgiriya aborî bandor dike.','Diaspora lobi, yayın ve ekonomik destekle etkide bulunur.',SIYASET)
q('Siyaset',5,'mc','Di rêveberiyên xweser de "meclîsa jinan" çi rol digire?',
  ['Li ser mijarên jinan biryarên girêdayî digire','Tenê şêwir dide',
   'Tenê perwerdehiyê dide','Rola wê nîne'],
  'Li ser mijarên jinan biryarên girêdayî digire',
  'Meclîsa jinan di mijarên xwe de xwedî mafê biryara dawî ye.',
  'Kadın meclisi, kendi konularında nihai karar hakkına sahiptir.',SIYASET)
q('Siyaset',3,'mc','Di siyaseta nûjen de "xwerêveberiya herêmî" çi tê wateyê?',
  ['Herêm karûbarên xwe bi xwe birêve dibe','Navend her tiştî diyar dike',
   'Ordû rêve dibe','Tenê hilbijartin heye'],'Herêm karûbarên xwe bi xwe birêve dibe',
  'Xwerêveberî hêza biryarê dide asta herêmî.','Öz yönetim, karar gücünü yerel düzeye verir.',PARADIGMA)

# PARADIGMA
q('Paradigma',3,'mc','Di paradîgmayê de "civaka xwezayî" çi tê wateyê?',
  ['Civaka berî hiyerarşiya dewletê','Civaka bêziman',
   'Civaka pîşesazî','Civaka dîjîtal'],'Civaka berî hiyerarşiya dewletê',
  'Civaka xwezayî wek modela berî çînî û berî dewletê tê nirxandin.',
  'Doğal toplum, sınıf ve devlet öncesi model olarak değerlendirilir.',PARADIGMA)
q('Paradigma',4,'mc','"Hişmendiya civakî" di vê paradîgmayê de çima girîng e?',
  ['Guhertin bi perwerdehî û hişmendiyê dest pê dike','Tenê aborî girîng e',
   'Tenê hiqûq girîng e','Guhertin bi teknolojiyê tê'],
  'Guhertin bi perwerdehî û hişmendiyê dest pê dike',
  'Akademî û perwerdehiya civakî amûrên sereke yên veguhertinê ne.',
  'Akademiler ve toplumsal eğitim, dönüşümün ana araçlarıdır.',PARADIGMA)
q('Paradigma',5,'mc','Rexneya li "dewleta netewe" di vê paradîgmayê de bi giştî li ser çi ye?',
  ['Pirrengiyê bi zorê yek dike','Pir bi hêz e',
   'Pir belavbûyî ye','Tenê aborî ye'],'Pirrengiyê bi zorê yek dike',
  'Dewleta netewe ziman, çand û nasnameyên cuda di bin yek qalibî de dixe.',
  'Ulus-devlet farklı dil, kültür ve kimlikleri tek kalıba sokar.',PARADIGMA)
q('Paradigma',2,'mc','Peyva "azadî" û "wekhevî" bi hev re di vê paradîgmayê de bi çi ve girêdayî ne?',
  ['Bi azadiya jinê ve','Bi aboriya bazarê ve','Bi hêza leşkerî ve','Bi sînoran ve'],
  'Bi azadiya jinê ve',
  'Azadiya civakê bi asta azadiya jinê tê pîvandin.','Toplumun özgürlüğü, kadının özgürlük düzeyiyle ölçülür.',PARADIGMA)
q('Paradigma',4,'tf','Rast e an şaş e: Di modela komunal de biryar ji jor ber bi jêr ve tê dayîn.',
  ['Şaş','Rast'],'Şaş','Berevajî: biryar ji jêr — ji komun û meclîsan — ber bi jor ve diçe.','Tersine: karar aşağıdan — komün ve meclislerden — yukarı doğru gider.',PARADIGMA)
q('Paradigma',3,'mc','"Perwerdehiya bi zimanê zikmakî" di vê paradîgmayê de çima girîng tê dîtin?',
  ['Nasname û hişmendî bi ziman tê veguhastin','Tenê ji bo îmtîhanan',
   'Tenê ji bo turîzmê','Girîngiya wê nîne'],'Nasname û hişmendî bi ziman tê veguhastin',
  'Ziman hem bîr hem nasname diguhezîne; loma perwerdehiya zikmakî bingehîn e.',
  'Dil hem hafızayı hem kimliği taşır; bu yüzden anadilde eğitim temeldir.',PARADIGMA)
q('Paradigma',5,'mc','Di têgîna "modernîteya kapîtalîst" de sê stûnên rexnekirî çi ne?',
  ['Kapîtalîzm, pîşesaziyparêzî û dewleta netewe','Ziman, çand û dîrok',
   'Perwerde, tenduristî û aborî','Komun, meclîs û akademî'],
  'Kapîtalîzm, pîşesaziyparêzî û dewleta netewe',
  'Ev sê stûn wek koka krîza civakî û ekolojîk tên nirxandin.',
  'Bu üç sütun, toplumsal ve ekolojik krizin kökü olarak değerlendirilir.',PARADIGMA)
q('Paradigma',4,'mc','Di modela ekolojîk de çandiniya herêmî çima tê pêşniyar kirin?',
  ['Pêdiviya herêmê bi xwe tê dîtin, veguhastin kêm dibe','Ji bo îxracatê',
   'Ji bo pîşesaziya giran','Ji bo turîzmê'],
  'Pêdiviya herêmê bi xwe tê dîtin, veguhastin kêm dibe',
  'Hilberîna herêmî xerckirina enerjiyê û girêdana derve kêm dike.',
  'Yerel üretim, enerji tüketimini ve dışa bağımlılığı azaltır.',PARADIGMA)

# ─────────────────────────── ÇIKTI ───────────────────────────
SRC_CONST = {
    FERHENG: '_ferhengSource', REZIMAN: '_rezimanSource', DIROK: '_diroknasSource',
    WEJE: '_wejeSource', COGRAFYA: '_cografyaSource', MUZIK: '_muzikSource',
    FOLKLOR: '_folklorSource', SIYASET: '_siyasetSource', PARADIGMA: '_paradigmaSource',
}
SLUG = {'Ziman':'ziman','Çand':'cand','Dîrok':'dirok','Edebiyat':'edebiyat',
        'Cografya':'cografya','Muzîk':'muzik','Siyaset':'siyaset','Paradigma':'paradigma'}

def esc(s):
    return s.replace('\\', r'\\').replace("'", r"\'").replace('$', r'\$')

counters = {}
out = io.StringIO()
out.write('''/// İkinci editoryal dalga (2026-07-24).
///
/// Kaynak denetiminde bulunan üç sorunu gidermek için yazıldı:
///  1. Otomatik havuzun 320 sorusunda gövde Kurmancî, şıklar Türkçeydi —
///     oyuncu sorunun yarısını anlamıyordu. Buradaki her soruda gövde ve
///     şıklar aynı dildedir; istisna yalnız açıkça çeviri alıştırmalarıdır.
///  2. Offline havuzun hiçbir sorusunda Kurmancî açıklama yoktu. Burada her
///     sorunun `explanationKu` ve `explanationTr` alanı doludur.
///  3. Offline havuzda kaynak/onay meta verisi yoktu. Buradaki her soru
///     `approved` ve kaynaklıdır.
///
/// Sorular konu anahtar kelimeleriyle alt kategorilere de doğru düşecek
/// şekilde yazılmıştır (bkz. `SubcategoryConfig`).
library;

import '../models/question_metadata.dart';
import '../models/quiz_question.dart';

const _rezimanSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Rêzimana kurdî — Bedirxan & Lescot',
  sourceReference:
      'Celadet Alî Bedirxan & Roger Lescot, Grammaire Kurde (Dialecte Kurmandji), Paris 1970; Hawar (1932-1943)',
  qualityVersion: 2,
);

const _ferhengSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Ferhenga kurdî',
  sourceReference:
      'Zana Farqînî, Ferhenga Kurdî-Tirkî (2004); Michael L. Chyet, Kurdish-English Dictionary (Yale, 2003)',
  qualityVersion: 2,
);

const _diroknasSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Dîroka kurdan — çavkaniyên akademîk',
  sourceReference:
      'The Cambridge History of the Kurds (2021); Encyclopaedia Iranica — Kurds; Şerefxanê Bidlîsî, Şerefname (1597)',
  qualityVersion: 2,
);

const _wejeSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Wêjeya kurdî — antolojî û berhem',
  sourceReference:
      'Ehmedê Xanî, Mem û Zîn (1692); Mehmed Uzun, Kürt Edebiyatına Giriş; Melayê Cizîrî, Dîwan',
  qualityVersion: 2,
);

const _cografyaSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Erdnîgariya herêmê',
  sourceReference:
      'Encyclopaedia Britannica — Kurdistan, Zagros, Lake Van; UNESCO World Heritage List (Diyarbakır Fortress and Hevsel Gardens, 2015)',
  qualityVersion: 2,
);

const _muzikSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Muzîk û dengbêjiya kurdî',
  sourceReference:
      'Mehmet Uzun, Dengbêj Üslubu Hakkında; Estelle Amy de la Bretèque, Paroles mélodisées (2013)',
  qualityVersion: 2,
);

const _folklorSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Folklor û kevneşopiya kurdî',
  sourceReference:
      'Ordîxanê Celîl & Celîlê Celîl, Zargotina Kurda; Encyclopaedia Iranica — Newruz',
  qualityVersion: 2,
);

const _siyasetSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Siyaseta herêmê — çavkaniyên belge û akademîk',
  sourceReference:
      'Destûra Iraqê (2005), Beşa 4; The Cambridge History of the Kurds; https://kongra-star.org/eng/about/',
  qualityVersion: 2,
);

const _paradigmaSource = QuestionMetadata(
  reviewStatus: ReviewStatus.approved,
  dialect: 'Kurmancî',
  sourceTitle: 'Paradîgmaya netewa demokratîk — çavkanî û şirove',
  sourceReference:
      'Cambridge, Beyond Feminism? Jineolojî and the Kurdish Women\\'s Freedom Movement; https://kongra-star.org/eng/about/',
  qualityVersion: 2,
);

/// Editoryal ikinci dalga soru bankası.
const editorialQuestionBank = <QuizQuestion>[
''')

for (cat, diff, typ, prompt, answers, correct, ku, tr, src) in Q:
    slug = SLUG[cat]
    counters[slug] = counters.get(slug, 0) + 1
    qid = f'edit_{slug}_{counters[slug]:04d}'
    assert correct in answers, (qid, correct)
    assert len(set(answers)) == len(answers), qid
    qtype = 'QuestionType.trueFalse' if typ == 'tf' else 'QuestionType.multipleChoice'
    out.write('  QuizQuestion(\n')
    out.write(f"    id: '{qid}',\n")
    out.write(f"    category: '{esc(cat)}',\n")
    out.write(f"    prompt: '{esc(prompt)}',\n")
    out.write('    answers: [\n')
    for a in answers:
        out.write(f"      '{esc(a)}',\n")
    out.write('    ],\n')
    out.write(f"    correctAnswer: '{esc(correct)}',\n")
    out.write(f"    explanation: '{esc(tr)}',\n")
    out.write(f"    explanationKu: '{esc(ku)}',\n")
    out.write(f"    explanationTr: '{esc(tr)}',\n")
    if typ == 'tf':
        out.write(f'    type: {qtype},\n')
    out.write(f'    difficulty: {diff},\n')
    out.write(f'    metadata: {SRC_CONST[src]},\n')
    out.write('  ),\n')

out.write('];\n')
open('lib/src/data/editorial_question_bank.dart', 'w').write(out.getvalue())

import collections
print('toplam soru:', len(Q))
print(collections.Counter(x[0] for x in Q))
print('zorluk:', sorted(collections.Counter(x[1] for x in Q).items()))
print('tip:', collections.Counter(x[2] for x in Q))
# prompt tekilliği
keys = [(x[0], x[3].strip().lower()) for x in Q]
assert len(set(keys)) == len(keys), 'yinelenen prompt var'
print('prompt tekilliği: OK')
