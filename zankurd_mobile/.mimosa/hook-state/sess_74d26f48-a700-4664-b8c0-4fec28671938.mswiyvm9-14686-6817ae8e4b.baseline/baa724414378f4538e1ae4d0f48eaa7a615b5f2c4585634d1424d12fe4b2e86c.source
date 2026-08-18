# -*- coding: utf-8 -*-
"""Doğru cevaptan farklı dilde kalmış çeldiricileri çevirir.

Çeldirici havuzu dilden bağımsız üretildiği için soru bankasında tek soru
içinde iki dil karışmıştı; Kurmancî bir çeldirici, Türkçe karşılık isteyen
bir soruda tek bakışta elenebiliyordu. Çeldiriciyi silmek yerine *çeviriyoruz*:
editoryal niyet (hangi kavramla karıştırma sınanıyor) böylece korunuyor.

Kullanım: python3 tool/fix_option_languages.py
Doğrulama: dart run tool/audit_option_languages.dart
"""

import json
import sys

BANKS = [
    'assets/data/offline_questions.json',
    'assets/data/community_questions.json',
]

# Kurmancî → Türkçe
KU_TR = {
    'Dîcle û Ferat': 'Dicle ve Fırat',
    'Hevgirtin û azadiya jinan': 'Dayanışma ve kadınların özgürlüğü',
    'Ji ber ku ji bo pratîka perwerdehiyê fêrbûneke ewle, analîtîk û demokratîk armanc kirî ye':
        'Eğitim pratiği için güvenli, analitik ve demokratik bir öğrenmeyi hedeflediği için',
    'Ji ber ku xwezayê tenê wek tiştê mêtinkirinê nabîne':
        'Doğayı yalnızca sömürülecek bir nesne olarak görmediği için',
    'Ji komînên herêmî heta meclîsên jorîn': 'Yerel komünlerden üst meclislere kadar',
    'Li asta herêmî/deverî': 'Yerel/bölgesel düzeyde',
    'Madrîd û Lîzbon': 'Madrid ve Lizbon',
    'Melek Tawis û motîfa ronahî/rojê': 'Melek Tavus ve ışık/güneş motifi',
    'Siyabend û Xecê': 'Siyabend ile Xecê',
    'Wek her du sosyalîzma reel û kapîtalîzmê red dike':
        'Hem reel sosyalizmi hem kapitalizmi birlikte reddeder',
    'Xweseriyeke derveyî dewletê, ji binî ve xwerêxistî':
        'Devletin dışında, aşağıdan örgütlenen bir özerklik',
    'amûra kevneşopî ya dişibe bilûrê': 'bilûra benzeyen geleneksel çalgı',
    'avahiya ku bi rêveberiya navendî ve hat girêdan / hat rakirin':
        'merkezî yönetime bağlanan veya kaldırılan yapı',
    'avaza şînî ya di muzîka gelêrî ya kurdî de':
        'Kürt halk müziğindeki ağıt ezgisi',
    'aîdiyeta çandî û bîra erdnîgarî': 'kültürel aidiyet ve coğrafi hafıza',
    'belge an tiştê ku ji wê serdemê maye (çavkaniya yekemîn)':
        'o dönemden kalan belge veya nesne (birinci el kaynak)',
    'berhema dîroka kurdan a ku Şerefxan nivîsî':
        "Şerefhan'ın yazdığı Kürt tarihi eseri",
    'berxwedana derdora Çiyayê Agirî ya di navbera salên 1927-1930 de':
        '1927-1930 arasında Ağrı Dağı çevresindeki direniş',
    'berxwedana gel û hêviya azadiyê': 'halkın direnişi ve özgürlük umudu',
    'berxwedana li dijî zilmê û ji nû ve jidayikbûn':
        'zulme karşı direniş ve yeniden doğuş',
    'bi çanda rojane re girêdayî ye': 'gündelik kültürle bağlantılıdır',
    'biçûk': 'küçük',
    'bê amûr (a capella)': 'çalgısız (a capella)',
    'cejna dirûn û bereketê ya kevneşopî': 'geleneksel hasat ve bereket bayramı',
    'cilûbergê kevneşopî yê mêran': 'geleneksel erkek giysisi',
    'civaka olî-çandî ya taybet û trawmayên dîrokî':
        'kendine özgü dinî-kültürel topluluk ve tarihsel travmalar',
    'cureyekî avaza gelêrî ya kurdî ku li herêma Serhedê belav e':
        'Serhat yöresinde yaygın bir Kürt halk ezgisi türü',
    'cureyên kilamên gelêrî': 'halk kilamlarının türleri',
    'defa bi zengil (tef)': 'zilli def (tef)',
    'dewleta mezin a ku Selahedînê Eyûbî damezrand':
        "Selahaddin Eyyubi'nin kurduğu büyük devlet",
    'ekola wêjeyî û ramanî ya ku Ehmedê Xanî dest pê kir':
        "Ehmedê Xanî'nin başlattığı edebî ve düşünsel ekol",
    'ergatîf': 'ergatif',
    'fîqa şivanan (kaval)': 'çoban düdüğü (kaval)',
    'govend tê girtin û li ser agir tê banzdan':
        'halay çekilir ve ateşin üzerinden atlanır',
    'helbestvanê ku di sedsala 17em de ramana ronakbîriya kurdî nivîsî':
        '17. yüzyılda Kürt aydınlanma düşüncesini yazan şair',
    'herêma dîrokî ya derdora Dîcle û Firatê':
        'Dicle ve Fırat çevresindeki tarihî bölge',
    'herêma niştecihbûna dîrokî ya kurdên êzidî û kela wan':
        'Êzidî Kürtlerin tarihî yerleşim bölgesi ve kalesi',
    'hewza ku gola sodalî ya herî mezin a cîhanê ye':
        'dünyanın en büyük sodalı gölünü barındıran havza',
    'hukumdariya kurd a ku di serdema Osmanî de xweser mabû':
        'Osmanlı döneminde özerk kalan Kürt hükümdarlığı',
    'hunermendê ku bayê rock û caz anî muzîka kurdî':
        'Kürt müziğine rock ve caz rüzgârını getiren sanatçı',
    'hunermendê ku kilaman ji ber dibêje': 'kilamları ezbere söyleyen sanatçı',
    'jenosîda ku rejîma Iraqê li dijî kurdan pêk anî':
        'Irak rejiminin Kürtlere karşı uyguladığı soykırım',
    'ji ber ku herêm, zarava, avhewa, çandinî û danûstandina bi mitbaxên cîran re cuda ne':
        'bölge, lehçe, iklim, tarım ve komşu mutfaklarla alışveriş farklı olduğu için',
    'ji ber ku li avhewaya çiyayî berxwedana demsalî û ewlehiya xwarinê peyda dike':
        'dağ ikliminde mevsimsel dayanıklılık ve gıda güvenliği sağladığı için',
    'ji ber ku xebatên ziman û alfabeyê belav kir':
        'dil ve alfabe çalışmalarını yaygınlaştırdığı için',
    'ji ber ku zanîna jiyana rojane, motîf û estetîka herêmî hildigire':
        'gündelik yaşam bilgisini, motifleri ve yerel estetiği taşıdığı için',
    'ji bo pitikan': 'bebekler için',
    'jiyana bi hev re ya nasname û baweriyên cuda':
        'farklı kimlik ve inançların bir arada yaşaması',
    'jiyana hevpar a gelên cuda di nav wekhevî û aştiyê de':
        'farklı halkların eşitlik ve barış içinde ortak yaşamı',
    'kevneşopiya muzîk û rîtûel/avazê': 'müzik ve ritüel/ezgi geleneği',
    'lîstik an reqsên kevneşopî yên jinan':
        'kadınların geleneksel oyun veya dansları',
    'lûtkeya herî bilind a erdnîgariya Kurdistanê':
        'Kürdistan coğrafyasının en yüksek zirvesi',
    'mîrê kurd ê ku di sedsala 19em de têkoşîna xweseriyê da':
        '19. yüzyılda özerklik mücadelesi veren Kürt beyi',
    'mîrê navdar ê Soran ku di sedsala 19an de hewl da yekîtiya kurdî ava bike':
        '19. yüzyılda Kürt birliğini kurmaya çalışan ünlü Soran beyi',
    'nanê kevneşopî yê ku di tenûrê de tê patin':
        'tandırda pişirilen geleneksel ekmek',
    'nivîsandin': 'yazmak',
    'nivîskarê ku Şerefname û Mem û Zîn wergerandin soranî':
        "Şerefname ve Mem û Zîn'i Soranîye çeviren yazar",
    'reqsa gelêrî ya kevneşopî ya sê-pêyî': 'üç ayaklı geleneksel halk dansı',
    'roja ziyaret û bibîranînê ya kevneşopî': 'geleneksel ziyaret ve anma günü',
    'rêxistina kurdî ya ku di destpêka sedsala 20em de hat damezrandin':
        '20. yüzyılın başında kurulan Kürt örgütü',
    'stargeh, azadî û berxwedan': 'sığınak, özgürlük ve direniş',
    'stranên gelêrî yên bilez û rîtmîk ên ku di govendê de tên lêxistin':
        'halayda çalınan hızlı ve ritmik halk şarkıları',
    # "sînor" doğrudan "sınır" olarak çevrilseydi doğru cevabın kopyası
    # olacaktı (offline_8678); aynı alandan başka bir terim seçildi.
    'sînor': 'kıyı şeridi',
    'tûrikê ku ji bo hilgirtina xwarinê tê hûnandin':
        'yiyecek taşımak için örülen heybe',
    'vegotina devkî û çîroka bi avaz': 'sözlü anlatım ve ezgili hikâye',
    'vegotina lehengiyê': 'kahramanlık anlatısı',
    'veguhastina êş, windahî û bîra civakî':
        'acının, kaybın ve toplumsal hafızanın aktarımı',
    'were!': 'gel!',
    'weşana dîrokî ya kurdî ya serdema destpêka sedsala 20an ku li ser mafên neteweyî dinivîsî':
        '20. yüzyıl başında ulusal haklar üzerine yazan tarihî Kürt yayını',
    'xanedaniya kurd a serdema navîn a bi navenda Amedê':
        'Amed merkezli ortaçağ Kürt hanedanı',
    'xweza û teyr': 'doğa ve kuş',
    'yek ji destanên herî xemgîn ên wêjeya devkî ya kurdî':
        'Kürt sözlü edebiyatının en hüzünlü destanlarından biri',
    'yek ji helbestvanên klasîk ên herî kevn ên wêjeya kurdî':
        'Kürt edebiyatının en eski klasik şairlerinden biri',
    'yek ji nûnerên herî naskirî yên kevneşopiya dengbêjiya jinan':
        'kadın dengbêjlik geleneğinin en tanınmış temsilcilerinden biri',
    'yekem hunermenda kurd a jin a ku plak dagirt':
        'plak dolduran ilk Kürt kadın sanatçı',
    'Îranî û gelek gelên din (wek Newrozê)':
        'İranlılar ve başka birçok halk (Newroz gibi)',
    'çalakvana kurd a jin a ku ji aliyê rejîma Iraqê ve hat îdamkirin':
        'Irak rejimi tarafından idam edilen Kürt kadın aktivist',
    'çiyayê volkanîk ê feal ê xwedî gola kraterê':
        'krater gölü olan aktif volkanik dağ',
    'Şerefxan (mîrê Bidlîsê)': 'Şerefhan (Bitlis beyi)',
    'Şerê Hittînê (1187)': 'Hittin Savaşı (1187)',
    'şêwaza jiyana koçerî û rîtma reqsê': 'göçebe yaşam biçimi ve dans ritmi',
    'Mifta / Kilît': 'Anahtar / Kilit',
    'çîrokan vedibêje': 'masal anlatır',
}

# Türkçe → Kurmancî
TR_KU = {
    "1921'de Sivas yöresinde gelişen Kürt hareketi":
        'tevgera kurdî ya ku di sala 1921 de li derdora Sêwasê pêş ket',
    "1988'de Kürtlere karşı yapılan kimyasal saldırı":
        'êrîşa kîmyayî ya ku di sala 1988 de li dijî kurdan hat kirin',
    'Amca kızı (kuzen)': 'dotmam (keça apê)',
    'Birinin diğerine asimilasyonuyla': 'bi asîmîlekirina yekê di ya din de',
    'Demokratik örgütlenmenin yalnızca merkezi devletle sınırlı olmadığını':
        'ku rêxistinbûna demokratîk tenê bi dewleta navendî re sînordar nîne',
    'Devleti aşan, ona alternatif bir öz yönetim':
        'xwerêveberiyeke ku dewletê derbas dike û alternatîfa wê ye',
    'Dicle nehri üzerinde yer alan binlerce yıllık tarihi kent':
        'bajarê dîrokî yê hezaran salî yê li ser çemê Dîclê',
    'Dinî ilahi/sözlü kutsal metinler': 'îlahî û nivîsên pîroz ên devkî',
    'Dinî-toplumsal sınıfları': 'çînên olî-civakî',
    'Endüstriyalizm, kapitalizm ve ulus-devlet':
        'pîşesazîparêzî, kapîtalîzm û dewlet-netewe',
    'Eşit yurttaşlık ve hakların tanınmasını':
        'hemwelatîbûna wekhev û naskirina mafan',
    'Farklı halkların eşit ve dayanışmacı birlikteliğini':
        'hevgirtina wekhev û piştgir a gelên cuda',
    'Garzan çayı yakınlarındaki dağlık kütle':
        'girseya çiyayî ya nêzî çemê Garzanê',
    'Hakkari dağlarını yararak akan hırçın akarsu':
        'çemê hêrs ê ku çiyayên Colemêrgê diqelêşe',
    'Hakkari/Cizre çevresi (dağlık güneydoğu)':
        'derdora Colemêrg/Cizîrê (başûrê rojhilat ê çiyayî)',
    'Işığa/güneşe verilen kutsallığı':
        'pîroziya ku ji ronahî/rojê re tê dayîn',
    'Kadın bilgisi/bilimi ve patriyarka eleştirisi etrafında gelişen yaklaşım':
        'nêrîna ku li dora zanista jinê û rexneya baviksalariyê pêş dikeve',
    'Kadın özgürlüğü ve çoğulcu öz yönetimle':
        'bi azadiya jinê û xwerêveberiya pirreng',
    'Kadın özgürlüğünü toplumsal özgürlüğün temeli görmeyi':
        'dîtina azadiya jinê wek bingeha azadiya civakî',
    'Kadın, yaşam, özgürlük': 'Jin, jiyan, azadî',
    "Kahire'de 1898'de basılan ilk Kürt gazetesi":
        'rojnameya kurdî ya yekem a ku di sala 1898 de li Qahîreyê hat çapkirin',
    'Kararları teknokratlara bırakır': 'biryaran ji teknokratan re dihêle',
    'Klasik Kürt şiirinin önemli isimleri olmaları':
        'ku navên girîng ên helbesta kurdî ya klasîk in',
    'Kurucu ilkeleri ve yönetim esaslarını belirleyen anayasal belge':
        'belgeya destûrî ya ku prensîbên damezrîner û bingehên rêveberiyê diyar dike',
    'Kürt müziğinin tanınmış sanatçısı': 'hunermendê naskirî yê muzîka kurdî',
    'Kürt sözlü geleneğinde de anlatılan klasik aşk hikayesi':
        'çîroka evînê ya klasîk a ku di kevneşopiya devkî ya kurdî de jî tê gotin',
    'Kürtçe yayıncılığın yaygınlaşması': 'belavbûna weşangeriya kurdî',
    "Mezopotamya'ya hayat veren büyük nehir":
        'çemê mezin ê ku jiyanê dide Mezopotamyayê',
    'Müzakere ve demokratik çözüme':
        'ji bo danûstandin û çareseriya demokratîk',
    "Osmanlı'da 1847'de kurulan kısa süreli idari eyalet":
        'eyaleta îdarî ya kurtedem a ku di sala 1847 de di dema Osmaniyan de hat avakirin',
    'Patriyarka (erkek egemenliği) eleştirisi':
        'rexneya baviksalariyê (serdestiya mêran)',
    'Sadece merkezi hükümette': 'tenê di hukûmeta navendî de',
    'Sessiz sınav düzenini': 'pergala îmtîhana bêdeng',
    'Silah bırakma ve örgütsel yapıyı feshetme çağrısı':
        'banga danîna çekan û hilweşandina avahiya rêxistinî',
    'Sözlü/ezbere aktarılan anlatıya':
        'ji bo vegotina ku devkî an ji ber tê veguhastin',
    'Süleymaniye merkezli güçlü Kürt prensliği':
        'mîrektiya kurd a bihêz a bi navenda Silêmaniyê',
    "Süleymaniye'de basılan erken dönem Kürtçe gazete":
        'rojnameya kurdî ya serdema destpêkê ya ku li Silêmaniyê hat çapkirin',
    'Tiyatro gösterisi': 'pêşandana şanoyê',
    'Toplumsal bilinç ve özgür düşünceyi geliştirmeyi':
        'geşkirina hişmendiya civakî û ramana azad',
    'Uluslararası mahkemede': 'li dadgeha navneteweyî',
    'Yerel demokrasi, kadın özgürlüğü, ekoloji ve çoğulculuk':
        'demokrasiya herêmî, azadiya jinê, ekolojî û pirrengî',
    'ağız': 'dev',
    'doğru': 'rast',
    'el yapımı geleneksel Kürt ayakkabısı':
        'pêlava kurdî ya kevneşopî ya destçêkirî',
    'geleneksel Kürt yeleği veya giysisi': 'elek an cilê kurdî yê kevneşopî',
    'göçebe Kürt aşiretlerinin barınağı': 'stargeha eşîrên kurd ên koçer',
    'gül': 'gul',
    'gün/güneş': 'roj',
    'halay başının elinde salladığı mendil':
        'destmala ku serê govendê dihejîne',
    'halkın kendi kendini yönetme ve örgütleme biçimi':
        'awayê xwerêveberî û rêxistinbûna gel',
    'kadın': 'jin',
    'karşılıklı konuşma': 'axaftina bi hev re',
    'koyun sağan kadınların kültürel rolü':
        'rola çandî ya jinên ku pez didoşin',
    'toplumsal bağları güçlendirme': 'xurtkirina girêdanên civakî',
    'öğretmen': 'mamoste',
    'öğrenci': 'xwendekar',
    'İyi günler': 'Roj baş',
    'İç harçla doldurulan sebze veya yaprak yemeği':
        'xwarina sebze an pelan a ku bi dagirtinê tê tijîkirin',
    "Şakiro'nun seslendirdiği uzun soluklu destansı kilamlar":
        'kilamên destanî yên dirêj ên ku Şakiro digot',
    'çobanların da çaldığı üflemeli geleneksel enstrüman':
        'amûra bayî ya kevneşopî ya ku şivan jî lê dixin',
}


def main() -> int:
    targets = json.load(open(sys.argv[1], encoding='utf-8'))['offending']
    changed = 0
    unresolved = []
    for bank in BANKS:
        rows = json.load(open(bank, encoding='utf-8'))
        dirty = False
        for row in rows:
            bad = targets.get(row['id'])
            if not bad:
                continue
            for old in bad:
                new = KU_TR.get(old) or TR_KU.get(old)
                if new is None:
                    unresolved.append((row['id'], old))
                    continue
                if new in row['answers'] or new == row['correctAnswer']:
                    unresolved.append((row['id'], '%s -> ÇAKIŞMA' % old))
                    continue
                row['answers'] = [new if a == old else a for a in row['answers']]
                changed += 1
                dirty = True
        if dirty:
            with open(bank, 'w', encoding='utf-8') as handle:
                json.dump(rows, handle, ensure_ascii=False, indent=2)
                handle.write('\n')
    print('çevrilen şık: %d' % changed)
    for qid, old in unresolved:
        print('  ÇÖZÜLMEDİ %s | %s' % (qid, old))
    return 1 if unresolved else 0


if __name__ == '__main__':
    sys.exit(main())
