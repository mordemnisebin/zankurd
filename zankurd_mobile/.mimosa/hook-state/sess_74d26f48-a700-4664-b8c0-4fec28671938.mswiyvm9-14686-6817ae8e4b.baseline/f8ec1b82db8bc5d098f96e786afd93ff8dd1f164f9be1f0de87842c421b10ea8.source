# -*- coding: utf-8 -*-
"""Kurmancî arayüzde Türkçe kalan açıklamalara Kurmancî karşılık yazar.

`getLocalizedExplanation(true)` Kurmancî alan yoksa `explanationToKu`
kurallarını dener; eşleşme yoksa metni `Şirove: <Türkçe>` diye sarıp geçer.
2026-07-26 denetiminde 428 soruda oyuncu Kurmancî arayüzde Türkçe açıklama
görüyordu — geçen turda giderilen kusurun aynası.

Kalıp açıklamalar `explanation_ku.dart` içinde kuralla çözülür; burada
kurala sığmayan, gerçek çeviri isteyen metinler var. Anahtar tam metindir:
benzer ama farklı cümlelerin yanlışlıkla aynı çeviriyi almasını engeller.
"""

import json
import sys

BANK = 'assets/data/offline_questions.json'

KU = {
    # ── Cografya ───────────────────────────────────────────────────────
    '"Dîcle", Dicle Nehri\'nin Kürtçe/yerel adıdır.':
        '"Dîcle" navê kurdî yê çemê Dîcleyê ye.',
    '"Erzirom", Erzurum şehrinin Kürtçe-yerel söylenişidir.':
        '"Erzirom" bilêvkirina kurdî ya bajarê Erzeromê ye.',
    '"Euphrates", Fırat Nehri\'nin (uluslararası) adıdır.':
        '"Euphrates" navê navneteweyî yê çemê Firatê ye.',
    '"Semsûr", Adıyaman şehrinin Kürtçe adıdır.':
        '"Semsûr" navê kurdî yê bajarê Semsûrê (Adiyaman) e.',
    "'Aras nehri' → Kars ve Iğdır sınırlarından geçip Hazar'a dökülen su.":
        "'Çemê Araksê' → çemê ku ji sînorên Qersê û Îdirê derbas dibe û "
        'dirijê Deryaya Xezerê.',
    "'Ağrı dağı' → Kürdistan coğrafyasının en yüksek zirvesi.":
        "'Çiyayê Agirî' → lûtkeya herî bilind a erdnîgariya Kurdistanê.",
    "'Behdînan bölgesi' → Zaho ve Duhok civarındaki dağlık coğrafi alan.":
        "'Herêma Behdînan' → devera çiyayî ya li dora Zaxo û Dihokê.",
    "'Bingöl dağları' → birçok nehrin kaynağını aldığı yüksek yaylaklar.":
        "'Çiyayên Bîngolê' → zozanên bilind ên ku serkaniya gelek çeman in.",
    "'Derbendihan gölü' → Diyala nehri üzerinde kurulmuş baraj gölü.":
        "'Gola Derbendîxanê' → bendava ku li ser çemê Diyalayê hatiye avakirin.",
    "'Dicle bölümü' → Diyarbakır ve Şırnak'ı kapsayan nehir havzası.":
        "'Beşa Dîcleyê' → hewza çem a ku Amed û Şirnexê digire nav xwe.",
    "'Dicle nehri' → Diyarbakır surlarının altından geçen nehir.":
        "'Çemê Dîcleyê' → çemê ku ji binê sûrên Amedê derbas dibe.",
    "'Dokan gölü' → Süleymaniye yakınlarında yer alan yapay baraj gölü.":
        "'Gola Dokanê' → bendava çêkirî ya li nêzîkî Silêmaniyê.",
    "'Fırat nehri' → Mezopotamya'ya hayat veren büyük nehir.":
        "'Çemê Firatê' → çemê mezin ê ku jiyanê dide Mezopotamyayê.",
    "'Habur çayı' → Türkiye ve Irak sınırını çizen Dicle kolu.":
        "'Çemê Xabûrê' → şaxê Dîcleyê yê ku sînorê Tirkiye û Iraqê diyar dike.",
    "'Halgurd dağı' → Irak Kürdistanı sınırlarında yer alan en yüksek zirve.":
        "'Çiyayê Halgurdê' → lûtkeya herî bilind a başûrê Kurdistanê.",
    "'Hazar gölü' → Elazığ sınırlarında yer alan tektonik göl.":
        "'Gola Hazarê' → gola tektonîk a li herêma Elezîzê.",
    "'Hewler ovası' → Güney Kürdistan'ın en verimli tarım ovası.":
        "'Deşta Hewlêrê' → deşta çandiniyê ya herî berdar a başûrê Kurdistanê.",
    "'Kandil dağları' → Garzan çayı yakınlarındaki dağlık kütle.":
        "'Çiyayên Qendîlê' → çiyayên bilind ên li ser sînorê Îraq û Îranê.",
    "'Karacadağ' → Diyarbakır ovasında yer alan yayvan bazaltik volkan.":
        "'Karacadax' → volkana bazaltî ya berfireh a li deşta Amedê.",
    "'Kürdistan iklimi': karasal ve dağlık alanlarda soğuk kışlar.":
        "'Avhewaya Kurdistanê' → li deverên parzemînî û çiyayî zivistanên sar.",
    "'Munzur dağları' → Dersim coğrafyasının en engebeli sıradağları.":
        "'Çiyayên Mûnzûrê' → rêzeçiyayên herî asê yên erdnîgariya Dêrsimê.",
    "'Muş ovası' → Fırat'ın kollarının suladığı büyük tarım ovası.":
        "'Deşta Mûşê' → deşta mezin a çandiniyê ya ku şaxên Firatê av didin.",
    "'Nemrut krateri' → dünyanın en büyük ikinci krater gölüne sahip dağ.":
        "'Kratera Nemrûdê' → çiyayê xwedî gola kraterê ya duyemîn a herî mezin "
        'a cîhanê.',
    "'Siverek ovası' → Karacadağ lavlarının oluşturduğu taşlık plato.":
        "'Deşta Sêwregê' → deşta kevirî ya ku ji lavên Karacadaxê pêk hatiye.",
    "'Süphan dağı' → Van gölü kuzeyinde yer alan sönmüş volkanik dağ.":
        "'Çiyayê Sîpanê' → çiyayê volkanîk ê temirî yê li bakurê Gola Wanê.",
    "'Tendürek dağı' → krater gölüne sahip aktif volkanik dağ.":
        "'Çiyayê Tendûrekê' → çiyayê volkanîk ê feal ê xwedî gola kraterê.",
    "'Urmiye gölü' → Doğu Kürdistan'da yer alan tuzlu göl havzası.":
        "'Gola Ûrmiyeyê' → hewza gola şor a li rojhilatê Kurdistanê.",
    "'Van gölü' → dünyanın en büyük sodalı gölü olan havza.":
        "'Gola Wanê' → hewza ku gola sodadar a herî mezin a cîhanê ye.",
    "'Yukarı Fırat bölümü' → Kürdistan coğrafyasının kuzeybatı yüksek kesimi.":
        "'Beşa Firata Jorîn' → beşa bilind a bakurê rojava ya erdnîgariya "
        'Kurdistanê.',
    "'Zagros sıradağları': Kürdistan coğrafyasını baştan başa bölen dağlar.":
        "'Rêzeçiyayên Zagrosê' → çiyayên ku erdnîgariya Kurdistanê ji serî heta "
        'binî dabeş dikin.',
    "'Zap vadisi' → dik kayalıklar arasından Zap suyunun aktığı derin vadi.":
        "'Geliyê Zapê' → geliyê kûr ê ku ava Zapê di nav zinarên asê de tê re "
        'diherike.',
    "'akdeniz iklimi' → Akdeniz'e yakın Kürt bölgelerinde görülen iklim.":
        "'Avhewaya Deryaya Navîn' → avhewaya ku li deverên kurdî yên nêzî "
        'Deryaya Navîn tê dîtin.',
    "'meşe ormanları' → Kürdistan dağlarının tipik bitki örtüsü ve ağacı.":
        "'Daristanên berû' → nebat û dara tîpîk a çiyayên Kurdistanê.",
    "'Şehrizor ovası' → Süleymaniye güneyindeki tarihi verimli düzlük.":
        "'Deşta Şehrezorê' → deşta dîrokî û berdar a başûrê Silêmaniyê.",
    "'Şengal dağı' → Musul ovasının ortasında yükselen stratejik dağ.":
        "'Çiyayê Şengalê' → çiyayê stratejîk ê ku li navenda deşta Mûsilê "
        'bilind dibe.',
    "Behdînan, ağırlıkla Irak'ın Duhok çevresini kapsayan bir Kürt bölgesidir.":
        'Behdînan devereke kurdî ye ku bi giranî dora Dihokê digire nav xwe.',
    'Bu şehirler, Dicle-Fırat arasındaki Yukarı Mezopotamya bölgesinde yer alır.':
        'Ev bajar li herêma Mezopotamyaya Jorîn a di navbera Dîcle û Firatê de ne.',
    "Büyük Zap ve Küçük Zap, Dicle'nin kollarıdır.":
        'Zapa Mezin û Zapa Biçûk şaxên Dîcleyê ne.',
    "Cizîr ve Botan, güneydoğudaki tarihî Botan-Cizre bölgesiyle anılır.":
        'Cizîr û Botan bi herêma dîrokî ya Botan-Cizîrê tên naskirin.',
    'Cudi Dağı, Şırnak ilindedir.':
        'Çiyayê Cûdî li parêzgeha Şirnexê ye.',
    "Fırat'ın kaynakları Doğu Anadolu'dadır (Karasu ve Murat).":
        'Serkaniyên Firatê li bakurê Kurdistanê ne (Karasu û Morad).',
    'Hawraman (Hewramî) bölgesi, İran ile Irak sınır kuşağında, dağlık bir Kürt yöresidir.':
        'Herêma Hewraman devereke kurdî ya çiyayî ye, li ser sînorê Îran û Îraqê.',
    "Hewlêr, Irak Kürdistan Bölgesi'nin merkezi Erbil'in Kürtçe adıdır.":
        'Hewlêr navê kurdî yê navenda Herêma Kurdistanê ye.',
    "Kobanê, Suriye'nin kuzeyinde, Türkiye sınırına yakın bir şehirdir.":
        'Kobanê bajarekî bakurê Sûriyeyê ye, nêzî sînorê Tirkiyeyê.',
    "Mahabad, İran'ın kuzeybatısındadır.":
        'Mehabad li bakurê rojava yê Îranê ye.',
    "Çiyayê Sîpan (Süphan Dağı), Van Gölü'nün kuzeyinde yer alır.":
        'Çiyayê Sîpanê li bakurê Gola Wanê ye.',

    # ── Dîrok ──────────────────────────────────────────────────────────
    "'Amida' → Diyarbakır'ın antik çağdaki tarihi ismi ve kalesi.":
        "'Amida' → navê dîrokî yê Amedê di serdema antîk de û kela wê.",
    "'Anfal operasyonu': Irak rejimi tarafından Kürtlere yönelik soykırım.":
        "'Operasyona Enfalê' → jenosîda ku rejîma Iraqê li dijî kurdan pêk anî.",
    "'Ağrı İsyanları': 1927-1930 yılları arasında Ağrı dağı çevresindeki direniş.":
        "'Serhildanên Agirî' → berxwedana derdora Çiyayê Agirî ya di navbera "
        'salên 1927-1930 de.',
    "'Baban Emirliği' → Süleymaniye merkezli güçlü Kürt prensliği.":
        "'Mîrgeha Babanê' → mîrnişîna kurd a bihêz a bi navenda Silêmaniyê.",
    "'Barzani Hareketi' → Güney Kürdistan'da uzun yıllar süren ulusal hareket.":
        "'Tevgera Barzanî' → tevgera neteweyî ya ku bi salan li başûrê "
        'Kurdistanê berdewam kir.',
    "'Bitlis Prensliği': Osmanlı döneminde özerk kalmış Kürt hükümdarlığı.":
        "'Mîrgeha Bidlîsê' → hukumdariya kurd a ku di serdema Osmanî de xweser "
        'mabû.',
    "'Bohtan Emirliği' → Cizre merkezli önemli Kürt beyliği.":
        "'Mîrgeha Botan' → mîrnişîna kurd a girîng a bi navenda Cizîrê.",
    "'Celadet Bedirxan': Kürt alfabesini geliştiren yayıncı ve aydın.":
        "'Celadet Bedirxan' → weşanger û ronakbîrê ku alfabeya kurdî pêş xist.",
    "'Cizre' → Botan emirliğinin ve tarihsel kültürün beşiği olan şehir.":
        "'Cizîr' → bajarê ku dergûşa mîrgeha Botan û çanda dîrokî ye.",
    "'Dersim 1937': Dersim bölgesinde yaşanan askeri harekat ve kriz.":
        "'Dêrsim 1937' → operasyona leşkerî û krîza ku li herêma Dêrsimê jiya.",
    "'Ehmedê Xanî': 17. yüzyılda Kürt aydınlanma fikrini yazan şair.":
        "'Ehmedê Xanî' → helbestvanê ku di sedsala 17em de ramana ronakbîriya "
        'kurdî nivîsî.',
    "'Eyyubiler' → Selahaddin Eyyubi tarafından kurulan büyük devlet.":
        "'Eyûbî' → dewleta mezin a ku Selahedînê Eyûbî damezrand.",
    "'Halepçe katliamı' → 1988'de Kürtlere karşı yapılan kimyasal saldırı.":
        "'Komkujiya Helebceyê' → êrîşa kîmyayî ya ku di sala 1988 de li dijî "
        'kurdan hat kirin.',
    "'Hasankeyf': Dicle nehri üzerinde yer alan binlerce yıllık tarihi kent.":
        "'Heskîf' → bajarê dîrokî yê hezaran salî yê li ser çemê Dîcleyê.",
    "'Hawar dergisi' → Latin alfabesiyle basılan ilk Kürtçe dergi.":
        "'Kovara Hawarê' → kovara kurdî ya yekem a ku bi tîpên latînî hat "
        'çapkirin.',
    "'Kasr-ı Şirin Antlaşması' → Osmanlı ve Safevi sınırını belirleyen antlaşma.":
        "'Peymana Qesrişîrînê' → peymana ku sînorê Osmanî û Sefewiyan diyar kir.",
    "'Kürt Teali Cemiyeti' → 20. yüzyıl başında kurulan Kürt örgütü.":
        "'Cemiyeta Tealiya Kurdan' → rêxistina kurdî ya ku di destpêka sedsala "
        '20em de hat damezrandin.',
    "'Leyla Qasim': Irak rejimi tarafından idam edilen Kürt kadın aktivist.":
        "'Leyla Qasim' → çalakvana kurd a jin a ku ji aliyê rejîma Iraqê ve hat "
        'îdamkirin.',
    "'Lozan Antlaşması' → Kürt coğrafyasını dört devlete bölen antlaşma.":
        "'Peymana Lozanê' → peymana ku erdnîgariya kurdî li ser çar dewletan "
        'dabeş kir.',
    "'Mahabad Cumhuriyeti' → 1946'da kurulan ilk kısa ömürlü Kürt devleti.":
        "'Komara Mehabadê' → yekem dewleta kurdî ya kurtjiyan a ku di sala 1946 "
        'de hat damezrandin.',
    "'Med İmparatorluğu': antik çağda Zagros merkezli büyük güç.":
        "'Împaratoriya Medî' → hêza mezin a antîk a bi navenda Zagrosê.",
    "'Mela Mahmude Bayazidi': Kürt örf adetlerini derleyen ilk araştırmacı.":
        "'Mela Mehmûdê Bazîdî' → lêkolînerê yekem ê ku adet û kevneşopiyên kurdan "
        'berhev kir.',
    "'Mervaniler' → Diyarbakır merkezli ortaçağ Kürt hanedanlığı.":
        "'Merwanî' → xanedaniya kurd a serdema navîn a bi navenda Amedê.",
    "'Mikdat Mithat Bedirxan': Kürdistan gazetesini çıkaran ilk Kürt gazeteci.":
        "'Mîqdat Mîdhad Bedirxan' → rojnamevanê kurd ê yekem ê ku rojnameya "
        'Kurdistan derxist.',
    "'Mustafa Barzani': Kürt hareketinin efsanevi askeri ve siyasi lideri.":
        "'Mistefa Barzanî' → rêberê leşkerî û siyasî yê navdar ê tevgera kurdî.",
    "'Mîrê Kor': Soran emirliğinin kör lakaplı güçlü lideri.":
        "'Mîrê Kor' → serokê bihêz ê mîrektiya Soranê yê bi leqeba kor.",
    "'Qazi Muhammed': Mahabad Kürt Cumhuriyeti'nin cumhurbaşkanı.":
        "'Qazî Mihemed' → serokkomarê Komara Kurdî ya Mehabadê.",
    "'Soran Emirliği' → Ravanduz merkezli askeri güç biriktiren beylik.":
        "'Mîrgeha Soran' → mîrnişîna bi navenda Rewandizê ya ku hêza leşkerî kom "
        'kir.',
    "'arkeoloji' → maddi kalıntılarla geçmişi araştırma.":
        "'arkeolojî' → lêkolîna rabirdûyê bi rêya bermahiyên madî.",
    "'birincil kaynak' → Döneminden kalan belge veya nesne (birincil kaynak).":
        "'çavkaniya seretayî' → belge an tiştê ku ji wê serdemê maye.",
    "'göç' → toplulukların yer değiştirmesi.":
        "'koçberî' → guhertina cihê jiyanê ya komên mirovan.",
    "'kronoloji' → olayları zaman sırasına koyma.":
        "'kronolojî' → rêzkirina bûyeran li gorî demê.",
    "'kültürel etkileşim' → toplumların birbirini etkilemesi.":
        "'bandora çandî' → bandorkirina civakan a li ser hev.",
    "'sözlü tarih' → tanıklık ve anlatılarla geçmişi anlama yöntemi.":
        "'dîroka devkî' → rêbaza têgihiştina rabirdûyê bi şahidî û vegotinan.",
    "'tarihsel yorum' → kanıtlardan anlam çıkarma.":
        "'şiroveya dîrokî' → derxistina wateyê ji delîlan.",
    "'yerleşik yaşam' → kalıcı yerleşim düzeni.":
        "'jiyana niştecih' → pergala niştecihbûna domdar.",
    "'İhsan Nuri Paşa': Hoybun cemiyeti adına askeri liderlik yapan subay.":
        "'Îhsan Nûrî Paşa' → efserê ku ji bo Xoybûnê rêberiya leşkerî kir.",
    "'Şengal' → Êzidî Kürtlerin tarihsel yerleşim bölgesi ve kalesi.":
        "'Şengal' → herêma niştecihbûna dîrokî ya kurdên êzidî û kela wan.",
    "'Şeyh Mahmud Berzenci': Irak'ta kendini Kürdistan kralı ilan eden lider.":
        "'Şêx Mehmûdê Berzencî' → rêberê ku li Iraqê xwe wek padîşahê Kurdistanê "
        'ragihand.',
    "'Şeyh Said': 1925 yılında Kürt hakları için isyan eden lider.":
        "'Şêx Seîd' → rêberê serhildana 1925an a ji bo mafên kurdan.",
    "1923 Lozan Antlaşması, Sevr'in yerine geçmiş ve Kürtlere dair bir statü içermemiştir.":
        'Peymana Lozanê ya 1923an cihê Sevrê girt û ji bo kurdan tu statû nedihewand.',
    'Beylikler döneminin ardından merkezîleşme politikalarıyla doğrudan yönetim süreci yaşanmıştır.':
        'Piştî serdema mîrgehan, bi siyaseta navendîkirinê rêveberiyeke rasterast hat sepandin.',
    'Doğru açıklama: Dicle ve Fırat çevresindeki tarihsel bölge.':
        'Ravekirina rast: herêma dîrokî ya derdora Dîcle û Firatê.',
    'Doğru açıklama: tanıklık ve anlatılarla geçmişi anlama yöntemi.':
        'Ravekirina rast: rêbaza têgihiştina rabirdûyê bi şahidî û vegotinan.',
    "Eyyubiler, ağırlıkla Kahire ve Şam'ı merkez edinmiştir.":
        'Eyûbiyan bi giranî Qahîre û Şam kirine navend.',
    "Hesenwayhîler, Orta Çağ'da Batı İran-Zagros çevresinde hüküm sürmüş bir Kürt hanedanıdır.":
        'Hesenwayhî xanedaniyeke kurd e ku di serdema navîn de li rojavayê Îranê '
        'û derdora Zagrosê hukum kir.',
    'Kürt Newroz anlatısında Kawa, Dehak/Zahhak zulmüne karşı başkaldırının sembol figürüdür.':
        'Di vegotina Newroza kurdî de Kawa sembola serhildanê ya li dijî zilma '
        'Dehaq e.',
    "Mahabad Cumhuriyeti 1946'da, bugünkü İran sınırları içinde kurulmuştur.":
        'Komara Mehabadê di sala 1946an de, di nav sînorên îroyîn ên Îranê de hat '
        'avakirin.',
    'Medler, Kürtlerin tarihsel atalarından biri olarak sıkça anılır.':
        'Med gelek caran wek yek ji bav û kalên dîrokî yên kurdan tên anîn ziman.',
    "Mervanîler, 10-11. yüzyıllarda Diyarbakır (Amed) ve çevresinde hüküm süren bir Kürt hanedanıdır.":
        'Merwanî xanedaniyeke kurd e ku di sedsalên 10-11em de li Amedê û '
        'derdora wê hukum kir.',
    "Mesud Barzani, Mustafa Barzani'nin oğludur ve KDP liderliği yapmıştır.":
        'Mesûd Barzanî kurê Mistefa Barzanî ye û rêberiya PDKê kiriye.',
    'Newroz anlatısında Dehak, halka zulmeden zalim bir kral/tiran olarak betimlenir.':
        'Di vegotina Newrozê de Dehaq wek padîşahekî zalim ê ku li gel zilmê dike '
        'tê nîşandan.',
    'Newroz, ilkbaharın başlangıcı olarak 21 Mart ile özdeşleşir.':
        'Newroz bi 21ê Adarê, destpêka biharê, tê naskirin.',
    "Selahaddin Eyyubi, 1187 Hıttin Savaşı'nın ardından Kudüs'ü geri almıştır.":
        'Selahedînê Eyûbî piştî Şerê Hittînê yê 1187an Qudsê vegerand.',
    "Selahaddin Eyyubi, bugünkü Irak'ta yer alan Tikrit'te doğmuştur.":
        'Selahedînê Eyûbî li Tikrîtê, ku îro li Iraqê ye, ji dayik bûye.',
    'Êzidîler, maruz kaldıkları katliamları kendi dillerinde "ferman" olarak adlandırır.':
        'Êzidî komkujiyên ku dîtine bi zimanê xwe "ferman" bi nav dikin.',
    "Şerefname, Bitlis beyi Şeref Han tarafından 1597'de yazılmıştır.":
        'Şerefname di sala 1597an de ji aliyê Şerefxanê Bidlîsî ve hatiye '
        'nivîsandin.',
    'Şerefname, Kürt emirlikleri ve hanedanları hakkında erken dönem önemli kaynaklardan biridir.':
        'Şerefname yek ji çavkaniyên girîng ên serdema destpêkê ye derbarê '
        'mîrgeh û xanedaniyên kurdî de.',
    'Şerefname, Kürt hanedanlarının ve beyliklerinin tarihini anlatan ilk kapsamlı eserdir.':
        'Şerefname yekem berhema berfireh e ku dîroka xanedanî û mîrgehên kurdî '
        'vedibêje.',

    # ── Edebiyat ───────────────────────────────────────────────────────
    '"pêkenok" güldürü amaçlı kısa anlatı, yani fıkradır.':
        '"pêkenok" vegotineke kurt a bo kenandinê ye.',
    "'Abdulla Goran': Sorani Kürtçe şiirinde modernleşmenin öncüsü.":
        "'Ebdulla Goran' → pêşengê nûjenbûnê di helbesta soranî de.",
    "'Arabê Şamo': Şivanê Kurd adlı ilk Kürtçe romanın yazarı.":
        "'Erebê Şemo' → nivîskarê romana yekem a kurdî, 'Şivanê Kurd'.",
    "'Cegerxwîn': modern Kürt şiirinin öncü toplumcu şairi.":
        "'Cegerxwîn' → helbestvanê civakî yê pêşeng ê helbesta kurdî ya modern.",
    "'Dewrêşê Evdî destanı' → Kürt sözlü edebiyatının en hüzünlü destanlarından biri.":
        "'Destana Dewrêşê Evdî' → yek ji destanên herî xemgîn ên wêjeya devkî ya "
        'kurdî.',
    "'Dîwana Melayê Cizîrî': mistik aşk ve felsefe içeren meşhur şiir divanı.":
        "'Dîwana Melayê Cizîrî' → dîwana helbestê ya navdar a bi evîna mîstîk û "
        'felsefeyê.',
    "'Ehmedê Xasî': Zazaca ilk mevlidi yazan şair ve din alimi.":
        "'Ehmedê Xasî' → helbestvan û alimê ku mewlûda yekem bi kirmanckî nivîsî.",
    "'Elî Herîrî': Kürt edebiyatının bilinen en eski klasik şairlerinden.":
        "'Elî Herîrî' → yek ji helbestvanên klasîk ên herî kevn ên wêjeya kurdî.",
    "'Evdirehîm Rehmî Hekarî': Kürt tiyatrosunun kurucu oyun yazarlarından.":
        "'Evdirehîm Rehmî Hekarî' → yek ji şanonivîsên damezrîner ên şanoya kurdî.",
    "'Feqiyê Teyran': kuşların diliyle yazan meşhur Kürt şair.":
        "'Feqiyê Teyran' → helbestvanê navdar ê kurd ê ku bi zimanê çûkan nivîsî.",
    "'Ferhad û Şîrîn': Kürt sözlü geleneğinde de anlatılan klasik aşk hikayesi.":
        "'Ferhad û Şîrîn' → çîroka evînê ya klasîk a ku di kevneşopiya devkî ya "
        'kurdî de jî tê gotin.',
    "'Haris Bitlisî': klasik dönemde Kürtçe eserler yazmış şair.":
        "'Harisê Bidlîsî' → helbestvanê ku di serdema klasîk de bi kurdî berhem "
        'nivîsandin.',
    "'Hawar Ekolü' → Kürt aydınlanmasını ve Latin alfabesini yayan edebi akım.":
        "'Ekola Hawarê' → tevgera wêjeyî ya ku ronakbîriya kurdî û alfabeya latînî "
        'belav kir.',
    "'Hejar Mukriyanî': Şerefname ve Mem û Zîn'i Soraniceye çeviren yazar.":
        "'Hejar Mukriyanî' → nivîskarê ku Şerefname û Mem û Zîn wergerandin soranî.",
    "'Hêmin Mukriyanî': Doğu Kürdistan'ın meşhur modern şair ve yazarı.":
        "'Hêmin Mukriyanî' → helbestvan û nivîskarê nûjen ê navdar ê rojhilatê "
        'Kurdistanê.',
    "'Kamuran Bedirxan': Kürtçe gramer kitapları yazan dilbilimci ve yazar.":
        "'Kamûran Bedirxan' → zimannas û nivîskarê ku pirtûkên rêzimana kurdî "
        'nivîsandin.',
    "'Masture Erdelan': tarihte divan yazmış ilk Kürt kadın tarihçi ve şair.":
        "'Mestûre Erdelan' → dîroknas û helbestvana kurd a yekem a ku dîwan "
        'nivîsandiye.',
    "'Melayê Bateyî': Mevlid-i Şerif'i Kürtçe yazan klasik şair.":
        "'Melayê Bateyî' → helbestvanê klasîk ê ku Mewlûda Kurdî nivîsî.",
    "'Melayê Cizîrî': Kürt tasavvuf şiirinin klasik divan şairi.":
        "'Melayê Cizîrî' → helbestvanê dîwanê yê klasîk ê helbesta tesewifî ya "
        'kurdî.',
    "'Memê Alan destanı' → Ehmedê Xanî'nin Mem û Zîn'e ilham aldığı halk destanı.":
        "'Destana Memê Alan' → destana gelêrî ya ku Ehmedê Xanî jê ji bo Mem û "
        'Zînê îlham girt.',
    "'Mestûre Kurdistanî': Erdelan beyliğinde yaşamış ünlü kadın şair.":
        "'Mestûre Kurdistanî' → helbestvana jin a navdar a ku li mîrektiya "
        'Erdelanê jiya.',
    "'Nalî': Soranice klasik şiir okulunun en büyük divan şairi.":
        "'Nalî' → helbestvanê dîwanê yê herî mezin ê ekola klasîk a soranî.",
    "'Nûbihara Biçukan' → Ehmedê Xanî tarafından yazılan ilk Kürtçe sözlük.":
        "'Nûbihara Biçûkan' → ferhenga kurdî ya yekem a ku Ehmedê Xanî nivîsî.",
    "'Osman Sabri': modern Kürt hikayeciliğinin kurucu isimlerinden.":
        "'Osman Sebrî' → yek ji navên damezrîner ên çîroknivîsiya kurdî ya modern.",
    "'Pertew Begê Hkarî': Hakkari emirliğinde yetişmiş klasik divan şairi.":
        "'Pertew Begê Hekarî' → helbestvanê dîwanê yê klasîk ê ku li mîrgeha "
        'Colemêrgê mezin bû.',
    "'Qanadê Kurdo': Kürt dili ve edebiyatı üzerine çalışan akademisyen.":
        "'Qanatê Kurdo' → akademîsyenê ku li ser ziman û wêjeya kurdî xebitî.",
    "'Qedrîcan' → modern Kürt şiirinde ve nesrinde iz bırakmış yazar.":
        "'Qedrîcan' → nivîskarê ku di helbest û pexşana kurdî ya nûjen de şop "
        'hiştiye.',
    "'Riya Taza gazetesi' → Erivan'da uzun yıllar basılan Kürtçe gazete.":
        "'Rojnameya Riya Taza' → rojnameya kurdî ya ku bi salan li Rewanê hat "
        'çapkirin.',
    "'Ronahî dergisi' → Şam'da Latin alfabesiyle çıkarılan edebi dergi.":
        "'Kovara Ronahî' → kovara wêjeyî ya ku li Şamê bi tîpên latînî derket.",
    "'Xanî Mektebi' → Ehmedê Xanî'nin başlattığı edebi ve düşünsel ekol.":
        "'Mekteba Xanî' → ekola wêjeyî û ramanî ya ku Ehmedê Xanî dest pê kir.",
    "'Yaşar Kemal': Kürt kökenli, dünya çapında tanınan usta romancı.":
        "'Yaşar Kemal' → romannivîsê hoste yê bi eslê xwe kurd ê ku li cîhanê tê "
        'naskirin.',
    "'Şivanê Kurd': 1935 yılında basılan ilk modern Kürtçe roman.":
        "'Şivanê Kurd' → romana kurdî ya modern a yekem, di sala 1935an de hat "
        'çapkirin.',
    "'Şêrko Bêkes': Kürt şiirine serbest tarzı getiren büyük şair.":
        "'Şêrko Bêkes' → helbestvanê mezin ê ku şêwaza azad anî helbesta kurdî.",
    'Atasözü: "El eli yıkar, el de yüzü yıkar" — dayanışmayı anlatır.':
        'Gotina pêşiyan: "Dest destî dişo, dest jî rû dişo" — hevkariyê vedibêje.',
    'Cigerxwîn, şiirlerini Kürtçe (Kurmancî) yazmıştır.':
        'Cegerxwîn helbestên xwe bi kurmancî nivîsandine.',
    'Destan, kahramanlık ve toplumsal hafızayı taşıyan epik anlatıdır.':
        'Destan vegotineke epîk e ku lehengî û bîra civakî hildigire.',
    "Hawar dergisi, Celadet Alî Bedirxan tarafından Şam'da (Suriye) yayımlanmıştır.":
        'Kovara Hawarê ji aliyê Celadet Alî Bedirxan ve li Şamê hat weşandin.',
    'Hawar çevresi, Latin temelli Kürt alfabesinin standartlaşması ve modern Kurmancî yazısı açısından önemlidir.':
        'Derdora Hawarê ji bo standardbûna alfabeya kurdî ya latînî û nivîsa '
        'kurmancî ya nûjen girîng e.',
    'Kürdistan gazetesi, ilk Kürt gazetesi olarak basın tarihinde özel bir yere sahiptir.':
        'Rojnameya Kurdistan wek rojnameya kurdî ya yekem di dîroka çapemeniyê de '
        'cihekî taybet digire.',
    'Kürt sözlü edebiyatının en önemli taşıyıcıları dengbêjlerdir.':
        'Hilgirên herî girîng ên wêjeya devkî ya kurdî dengbêj in.',
    'Kürtçe roman, ağırlıkla 20. yüzyılda gelişen modern bir türdür.':
        'Romana kurdî cureyekî nûjen e ku bi giranî di sedsala 20em de pêş ket.',
    "Mehmed Uzun, İsveç'te yaşamasına rağmen eserlerini ağırlıkla Kürtçe (Kurmancî) yazmıştır.":
        'Mehmed Uzun her çend li Swêdê jiya jî, berhemên xwe bi giranî bi kurmancî '
        'nivîsandin.',
    'Tema, bir edebî metnin ana düşüncesi ya da işlediği temel izlektir.':
        'Tema ramana sereke ya nivîseke wêjeyî ye.',

    # ── Muzîk ──────────────────────────────────────────────────────────
    "'Aram Tigran': Kürtçe şarkılarıyla tanınan Ermeni asıllı usta müzisyen.":
        "'Aram Tîgran' → muzîkjenê hoste yê bi eslê xwe ermenî yê ku bi stranên "
        'kurdî tê naskirin.',
    "'Aynur Doğan': modern dönemde Kürt halk müziğini icra eden sanatçı.":
        "'Aynur Dogan' → hunermenda ku di serdema nûjen de muzîka gelêrî ya kurdî "
        'dilîze.',
    "'Ciwan Haco': Kürt müziğine rock ve caz esintileri getiren sanatçı.":
        "'Ciwan Haco' → hunermendê ku bayê rock û caz anî muzîka kurdî.",
    "'Erdewan Zaxoyî': Bahdinan bölgesinin sevilen devrimci müzisyeni.":
        "'Erdewan Zaxoyî' → muzîkjenê şoreşger ê hezkirî yê herêma Behdînan.",
    "'Eyşeqan' → Kürt kadın dengbêj geleneğinin en bilinen temsilcilerinden.":
        "'Eyşeqan' → yek ji nûnerên herî naskirî yên kevneşopiya dengbêjiya jinan.",
    "'Hasan Cizrawî': erken dönem Kürt müziği kayıtlarını yapan dengbêj.":
        "'Hesen Cizrawî' → dengbêjê ku tomarên muzîka kurdî yên serdema destpêkê "
        'çêkirin.',
    "'Karapetê Xaço': Kürt sözlü müziğini derleyen Ermeni asıllı dengbêj.":
        "'Karapetê Xaço' → dengbêjê bi eslê xwe ermenî yê ku muzîka devkî ya kurdî "
        'berhev kir.',
    "'Kardeş Türküler': Kürt müziğini çok kültürlü ortamda icra eden grup.":
        "'Kardeş Türküler' → koma ku muzîka kurdî di hawîrdoreke pirçandî de "
        'dilîze.',
    "'Koma Amed': 90'larda Kürt müziğinde devrim yapan alternatif müzik grubu.":
        "'Koma Amed' → koma muzîkê ya alternatîf a ku di salên 90î de di muzîka "
        'kurdî de şoreş çêkir.',
    "'Koma Wetan': tarihteki ilk Kürtçe rock grubunun adı.":
        "'Koma Wetan' → navê koma rocka kurdî ya yekem di dîrokê de.",
    "'Meryem Xan': Kürt müziğinde plak dolduran ilk Kürt kadın sanatçı.":
        "'Meryem Xan' → hunermenda kurd a jin a yekem a ku plak dagirt.",
    "'Mihemed Taha Akreyî': Bahdinan bölgesinin popüler klasik halk sanatçısı.":
        "'Mihemed Taha Akreyî' → hunermendê gelêrî yê klasîk ê populer ê herêma "
        'Behdînan.',
    "'Mihemed Şêxo': Kürt halkının ulusal duygularını seslendiren ozan.":
        "'Mihemed Şêxo' → ozanê ku hestên neteweyî yên gelê kurd dianî ziman.",
    "'behedînî ezgileri' → Duhok ve Zaho yöresine has müzikal tarz.":
        "'awazên behdînî' → şêwaza muzîkê ya taybetî ya devera Dihok û Zaxoyê.",
    "'botan ezgileri' → Şırnak ve Cizre yöresinin ritmik ve makamsal müziği.":
        "'awazên Botan' → muzîka rîtmîk û makamî ya devera Şirnex û Cizîrê.",
    "'dahol' → zurna ile birlikte çalınan ritim sazı.":
        "'dahol' → amûra rîtmê ya ku bi zurnê re tê lêxistin.",
    "'defbaz' → erbane veya defi ustalıkla çalan ritim sanatçısı.":
        "'defbaz' → hunermendê rîtmê yê ku erbane an defê bi hostatî lê dide.",
    "'dengbêj evi' → Van ve Diyarbakır'da dengbêjlerin dinlendiği kültürel mekan.":
        "'mala dengbêjan' → cihê çandî yê ku li Wan û Amedê dengbêj lê tên "
        'guhdarîkirin.',
    "'dengbêj makamı' → kilamların okunduğu serbest ritimli vokal tarzı.":
        "'makamê dengbêjiyê' → şêwaza dengî ya bi rîtma azad a ku kilam pê tên "
        'gotin.',
    "'dengbêj' → ezgili sözlü anlatım yapan sanatçı.":
        "'dengbêj' → hunermendê ku vegotina devkî bi awaz dike.",
    "'dengbêjlik okulu' → usta-çırak ilişkisiyle yürüyen müzikal aktarım.":
        "'dibistana dengbêjiyê' → veguhastina muzîkî ya bi têkiliya hoste-şagirt.",
    "'erbane' → halk müziğinde yaygın olarak çalınan zilli tef.":
        "'erbane' → defa bi zengil a ku di muzîka gelêrî de belav tê lêxistin.",
    "'govend müziği' → halaylarda çalınan hareketli ve ritmik halk şarkıları.":
        "'muzîka govendê' → stranên gelêrî yên bilez û rîtmîk ên ku di govendê de "
        'tên lêxistin.',
    "'heyran' → Serhat bölgesinde yaygın olan bir Kürt halk ezgisi türü.":
        "'heyran' → cureyekî awaza gelêrî ya kurdî ku li herêma Serhedê belav e.",
    "'hîran' → Kürt halk müziğinde bir başka ezgi tarzı.":
        "'hîran' → şêwazeke din a awazê di muzîka gelêrî ya kurdî de.",
    "'kemençe' → Kürt coğrafyasında da çalınan yaylı çalgı.":
        "'kemençe' → amûra kevanî ya ku li erdnîgariya kurdî jî tê lêxistin.",
    "'kilam' → dengbêjlerin söylediği destansı veya aşk temalı şarkı.":
        "'kilam' → strana destanî an evînî ya ku dengbêj dibêjin.",
    "'koro' → topluluk halinde şarkı söyleme biçimi.":
        "'koro' → awayê stranbêjiya bi kom.",
    "'lawik' → daha çok aşk ve yiğitlik üzerine söylenen müzik türü.":
        "'lawik' → cureyê muzîkê ya ku bêtir li ser evîn û mêrxasiyê tê gotin.",
    "'makam' → Türk ve Kürt müziğinde ezgisel yapıyı belirleyen sistem.":
        "'makam' → pergala ku avahiya awazê diyar dike.",
    "'melodî' → seslerin ardışık dizilmesiyle oluşan ezgi.":
        "'melodî' → awaza ku ji rêzbûna dengan pêk tê.",
    "'nota' → müziği kağıda dökmek için kullanılan evrensel işaretler.":
        "'nota' → nîşanên gerdûnî yên ku muzîkê dinivîsin.",
    "'ritim' → müziğin temelini oluşturan düzenli vuruşlar.":
        "'rîtm' → lêdanên birêkûpêk ên ku bingeha muzîkê pêk tînin.",
    "'serhad ezgileri' → Kars, Ağrı ve Van yöresine özgü lirik müzik tarzı.":
        "'awazên Serhedê' → şêwaza muzîka lîrîk a taybetî ya devera Qers, Agirî û "
        'Wanê.',
    "'solo' → tek bir sanatçının şarkı söylemesi veya çalması.":
        "'solo' → stranbêjî an lêxistina bi tenê.",
    "'stran' → Kürtçe şarkı veya melodi.":
        "'stran' → strana an awaza kurdî.",
    "'stranbêj' → genel olarak şarkı okuyan, seslendiren kişi.":
        "'stranbêj' → kesê ku stranan dibêje.",
    "'tembûr' → Kürt halk müziğinde en kutsal sayılan telli saz.":
        "'tembûr' → amûra têlî ya ku di muzîka gelêrî ya kurdî de herî pîroz tê "
        'hesibandin.',
    "'zaza müziği' → Dersim ve Bingöl yöresinde icra edilen Kürtçe müzik.":
        "'muzîka kirmanckî' → muzîka kurdî ya ku li devera Dêrsim û Bîngolê tê "
        'lîstin.',
    "'zurna' → yüksek sesli, açık havada çalınan nefesli çalgı.":
        "'zurna' → amûra bayî ya bilinddeng a ku li derve tê lêxistin.",
    "'çeng' → antik Mezopotamya ve Kürt müziğinde kullanılan arp benzeri çalgı.":
        "'çeng' → amûra dişibe harpê ya ku li Mezopotamyaya antîk û di muzîka "
        'kurdî de hat bikaranîn.',
    "'Şakiro' → Kürtlerin 'şahê dengbêjan' dediği güçlü ses.":
        "'Şakiro' → dengê bihêz ê ku kurd jê re dibêjin 'şahê dengbêjan'.",
    "'Şivan Perwer': Kürt müziğini dünyaya tanıtan en meşhur ses sanatçısı.":
        "'Şivan Perwer' → hunermendê dengî yê herî navdar ê ku muzîka kurdî bi "
        'cîhanê da naskirin.',
    "'şabaş geleneği' → müzisyenlere para atarak taltif etme adeti.":
        "'kevneşopiya şabaşê' → adeta avêtina pereyan ji muzîkjenan re.",
    "'şakiro stranları' → Şakiro'nun seslendirdiği uzun soluklu destansı kilamlar.":
        "'stranên Şakiro' → kilamên destanî yên dirêj ên ku Şakiro digot.",
    "'şevbêrk müziği' → kış gecesi sohbetlerinde icra edilen sözlü müzik.":
        "'muzîka şevbêrkê' → muzîka devkî ya ku di civînên şevên zivistanê de tê "
        'gotin.',
    'Büyük dengbêj Evdalê Zeynikê 19. yüzyılda yaşadı.':
        'Dengbêjê mezin Evdalê Zeynikê di sedsala 19em de jiya.',
    'Davul-zurna düğün ve şenliklerin müziğidir.':
        'Dahol û zurna muzîka dawet û şahiyan e.',
    'Erbane (def), çerçeveli/zilli bir vurmalı çalgıdır.':
        'Erbane (def) amûreke lêdanê ya bi çarçove û zengil e.',
    'Govend, dengbêjlik ve kilam birlikte zengin bir Kürt müzik-kültür mirasını oluşturur.':
        'Govend, dengbêjî û kilam bi hev re mîrateyeke dewlemend a muzîk-çanda '
        'kurdî pêk tînin.',
    'Govend, el ele tutuşularak oynanan toplu bir halk dansıdır.':
        'Govend dansek gelêrî ya komî ye ku bi girtina destan tê lîstin.',
    "Hesen Zîrek, İran'ın Bokan kentinden ünlü bir sestir.":
        'Hesen Zîrek dengekî navdar ê ji bajarê Bokanê ye.',
    'Kilam, stran ve lawik, Kürt sözlü-müzikal geleneğinin ezgi türleridir.':
        'Kilam, stran û lawik cureyên awazê yên kevneşopiya devkî-muzîkî ya kurdî '
        'ne.',
    "Meryem Xan'ın plak kayıtları, kadın seslerinin ilk örneklerindendir.":
        'Tomarên plakê yên Meryem Xanê ji mînakên yekem ên dengên jinan in.',
    'Mey, kamıştan yapılan üflemeli bir çalgıdır.':
        'Mey amûreke bayî ye ku ji qamîşê tê çêkirin.',
    'Şarkı söyleyen kişiye "stranbêj" denir.':
        'Ji kesê ku stranan dibêje re "stranbêj" tê gotin.',

    # ── Ziman ──────────────────────────────────────────────────────────
    '"-istan" yer/ülke adı türetir: gulistan (gül bahçesi) gibi.':
        '"-istan" navên cih û welatan çêdike: wek gulistan (baxçeyê gulan).',
    '"Bîr" hafıza/akıl anlamına gelir (ör. bîr anîn = hatırlamak).':
        '"Bîr" tê wateya bîranîn û hiş (mînak: bîr anîn).',
    '"e" kısa, "ê" ise kapalı uzun bir ünlüdür; farklı seslerdir.':
        '"e" dengdareke kurt e, "ê" jî dirêj û girtî ye; ew du deng in.',
    '"hatin" (gelmek) fiilinin emir kipi "were!" (gel!) olur.':
        'Fermana lêkera "hatin" dibe "were!".',
    '"zanîn" fiilinin olumsuzu özel biçimde "nizanim" olur.':
        'Neyîniya lêkera "zanîn" bi şêweyeke taybet dibe "nizanim".',
    '"Çiya" dağ demektir (ör. Çiyayê Agirî = Ağrı Dağı).':
        '"Çiya" bilindahiya erdê ye (mînak: Çiyayê Agirî).',
    'Bu tanım evlerdeki pencereyi anlatır.':
        'Ev ravekirin pencereya malan vedibêje.',
    'Heval, gündelik kullanımda arkadaş; siyasal-kolektif bağlamda yoldaş anlamında kullanılır.':
        'Heval di zimanê rojane de dost e; di çarçoveya siyasî-komî de wateya '
        'hevrêtiyê digire.',
    'Jira, Merkezî Kürtçe için konuşma korpusu ve büyük sözvarlıklı konuşma tanıma çalışması olarak sunulmuştur.':
        'Jira ji bo kurdiya navîn wek korpusa axaftinê û xebateke naskirina '
        'dengî ya bi ferhengeke mezin hatiye pêşkêşkirin.',
    'Kurmancî ve Soranî, Kürtçe denildiğinde en yaygın iki ana lehçe/standart olarak öne çıkar.':
        'Kurmancî û soranî du zaravayên sereke yên herî belav ên kurdî ne.',
    'Kurmancî, özellikle Türkiye ve Suriye bağlamında Latin temelli Hawar alfabesiyle yaygınlaşmıştır.':
        'Kurmancî bi taybetî li Tirkiye û Sûriyeyê bi alfabeya Hawarê ya latînî '
        'belav bûye.',
    'Soranî, Irak ve İran’da Arap temelli Kürt alfabesiyle yaygın biçimde yazılır.':
        'Soranî li Iraq û Îranê bi alfabeya kurdî ya bi bingeha erebî tê '
        'nivîsandin.',

    # ── Çand ───────────────────────────────────────────────────────────
    '"Bav û kal" (baba ve dede) deyimi ataları/ecdadı ifade eder.':
        '"Bav û kal" bav û kalên mirov, yanî ecdad, îfade dike.',
    '"Cejna Newrozê" Newroz bayramı demektir (cejn = bayram).':
        '"Cejna Newrozê" cejna Newrozê ye (cejn = bayram).',
    '"Mîr", bey ya da yönetici anlamına gelir; beyliklerin başındaki kişiyi belirtir.':
        '"Mîr" tê wateya serokê mîrgehê, yanî serokê mîrnişînê.',
    '"xelat" hediye ya da ödül anlamına gelir.':
        '"Xelat" tê wateya diyarî an xelatê.',
    "'Newroz' → baharın gelişi ve yenilenme.":
        "'Newroz' → hatina biharê û vejîna nû.",
    "'ağıt' → duygu ve toplumsal hafıza.":
        "'şînî' → hest û bîra civakî.",
    "'bayramlaşma' → toplumsal bağları güçlendirme.":
        "'pîrozbahî' → xurtkirina girêdanên civakî.",
    "'bilûr' → kaval benzeri geleneksel üflemeli çalgı.":
        "'bilûr' → amûra bayî ya kevneşopî ya dişibe kavalê.",
    "'bêrîvan' → koyun sağan kadınların kültürel rolü.":
        "'bêrîvan' → rola çandî ya jinên ku pez didoşin.",
    "'cîranî' → komşuluk ve toplumsal yardımlaşma.":
        "'cîranî' → cîrantî û hevkariya civakî.",
    "'dengbêj' → sözlü anlatım ve ezgili hikaye.":
        "'dengbêj' → vegotina devkî û çîroka bi awaz.",
    "'destmal' → halay başının elinde salladığı mendil.":
        "'destmal' → destmala ku serê govendê dihejîne.",
    "'fistan' → geleneksel kadın giysisi.":
        "'fistan' → cilê kevneşopî yê jinan.",
    "'govendên herêmî' → yöresel halk dansları.":
        "'govendên herêmî' → reqsên gelêrî yên devera xwe.",
    "'halk mutfağı' → yerel yaşam ve paylaşım.":
        "'mitbaxa gel' → jiyana herêmî û parvekirin.",
    "'heftegiyan' → geleneksel yedi tahıllı çorba.":
        "'heftegiyan' → şorbeya kevneşopî ya bi heft dexlan.",
    "'helase' → geleneksel hasat ve bereket şenliği.":
        "'helase' → şahiya kevneşopî ya dirûn û bereketê.",
    "'hewran' → geleneksel kıl çadır yapımı.":
        "'hewran' → çêkirina çadira kevneşopî ya ji mû.",
    "'kelaş' → el yapımı geleneksel Kürt ayakkabısı.":
        "'kelaş' → pêlava kurdî ya kevneşopî ya destçêkirî.",
    "'kilim motifleri' → kültürel sembol ve renk hafızası.":
        "'motîfên kilimê' → sembola çandî û bîra rengan.",
    "'koçerî' → göçer yaşam tarzı ve dans ritmi.":
        "'koçerî' → şêwaza jiyana koçerî û rîtma reqsê.",
    "'lûr' → Kürt halk müziğinde ağıt benzeri ezgi.":
        "'lûr' → awaza dişibe şînî ya di muzîka gelêrî ya kurdî de.",
    "'masal anlatımı' → kuşaktan kuşağa aktarılan anlatı.":
        "'vegotina çîrokan' → vegotina ku ji nifşekî diçe nifşekî din.",
    "'memê alan' → destansı Kürt halk anlatısı.":
        "'Memê Alan' → vegotina gelêrî ya destanî ya kurdî.",
    "'nanê sêlê' → sac üzerinde pişirilen ekmek.":
        "'nanê sêlê' → nanê ku li ser sêlê tê patin.",
    "'nanê tenûrê' → tandırda pişirilen geleneksel ekmek.":
        "'nanê tenûrê' → nanê kevneşopî yê ku di tenûrê de tê patin.",
    "'pêncşem' → geleneksel ziyaret ve anma günü.":
        "'pêncşem' → roja ziyaret û bibîranînê ya kevneşopî.",
    "'qazîn' → geleneksel kadın oyunları veya dansları.":
        "'qazîn' → lîstik an reqsên kevneşopî yên jinan.",
    "'qutik' → geleneksel Kürt yeleği veya giysisi.":
        "'qutik' → elek an cilê kurdî yê kevneşopî.",
    "'reşmal' → siyah keçi kılından yapılan çadır.":
        "'reşmal' → çadira ku ji mûyê reş ê bizinan tê çêkirin.",
    "'serpêhatî' → yaşanmış ilginç olayların anlatımı.":
        "'serpêhatî' → vegotina bûyerên balkêş ên jiyayî.",
    "'sersal' → Kürt halk takviminde yılbaşı kutlaması.":
        "'sersal' → pîrozkirina serê salê di salnameya gelêrî ya kurdî de.",
    "'serzêr' → düğünlerde geline takılan altınlar.":
        "'serzêr' → zêrên ku di dawetan de li bûkê tên kirin.",
    "'sêpê' → üç ayaklı geleneksel halk dansı.":
        "'sêpê' → reqsa gelêrî ya kevneşopî ya sê-pêyî.",
    "'sînan' → geleneksel taş işçiliği.":
        "'sînan' → hunera kevirtaşiyê ya kevneşopî.",
    "'tûrik' → yiyecek taşımak için dokunan torba.":
        "'tûrik' → tûrikê ku ji bo hilgirtina xwarinê tê hûnandin.",
    "'tûtik' → geleneksel kaval benzeri çalgı.":
        "'tûtik' → amûra kevneşopî ya dişibe bilûrê.",
    "'yerel kıyafetler' → kimlik ve bölgesel çeşitlilik.":
        "'cilûbergên herêmî' → nasname û cudahiya deveran.",
    "'zembîlfiroş' → meşhur Kürt halk hikayesi.":
        "'Zembîlfiroş' → çîroka gelêrî ya navdar a kurdî.",
    "'çilkez' → geleneksel Kürt saç örgüsü modeli.":
        "'çilkezî' → modela kezîkirina kurdî ya kevneşopî.",
    "'şabaş' → müzisyenlere bahşiş atma geleneği.":
        "'şabaş' → kevneşopiya avêtina baxşîşê ji muzîkjenan re.",
    "'şahmaran' → doğu kültüründe mitolojik figür.":
        "'Şahmaran' → fîgura mîtolojîk a çanda rojhilat.",
    "'şax' → şırnak yöresine ait geleneksel dans.":
        "'şax' → reqsa kevneşopî ya devera Şirnexê.",
    "'şevbêrk' → kış gecelerinde yapılan sohbet toplantıları.":
        "'şevbêrk' → civînên şevê yên zivistanê.",
    "'şîlan' → yabani gül ve bitkisel çay geleneği.":
        "'şîlan' → gula çolê û kevneşopiya çaya nebatî.",
    'Ağıtlar, bireysel yasın yanında toplumsal olayların ve kolektif acının hafızasını taşır.':
        'Şînî ne tenê şîna kesane, bîra bûyerên civakî û êşa hevbeş jî hildigire.',
    'Aşiret yapıları tarihsel olarak sosyal dayanışma ve siyasal otorite ağlarının bir parçası olmuştur.':
        'Avahiyên eşîrî di dîrokê de beşek ji tora hevgirtina civakî û desthilata '
        'siyasî bûne.',
    'Dengbêjler, geleneksel olarak köy odaları ve dîwanlarda toplanıp icra yaparlardı.':
        'Dengbêj bi kevneşopî li odeyên gundan û dîwanan dicivîn û distirandin.',
    'Dew/doogh, yoğurt temelli ferahlatıcı bir içecek geleneğiyle ilişkilidir.':
        'Dew vexwarineke şêrînker a ji mastî ye û bi kevneşopiyeke xwe ve girêdayî '
        'ye.',
    'Dil, dengbêjlikten edebiyata ve günlük yaşama kadar kültürel hafızanın ana taşıyıcılarındandır.':
        'Ziman ji dengbêjiyê heta wêje û jiyana rojane hilgirê sereke yê bîra '
        'çandî ye.',
    'Ezidiler, Kürtçe konuşan/kimliklenen topluluklar arasında özgün inanç yapıları ve yakın dönem travmalarıyla öne çıkar.':
        'Êzidî di nav civakên kurdîaxêv de bi baweriya xwe ya taybet û trawmayên '
        'dawî tên naskirin.',
    'Kürt bayrağında kırmızı, beyaz ve yeşil renkler ile ortada bir güneş bulunur.':
        'Di ala kurdî de rengên sor, spî û kesk hene û li navê rojek heye.',
    'Kürt coğrafyası geniş olduğu için malzemeler ve tarif adları bölgeden bölgeye değişebilir.':
        'Ji ber ku erdnîgariya kurdî fireh e, madde û navên xwarinan ji dever bi '
        'dever diguherin.',
    'Kürt mutfağında dolma veya yaprax, yaprak ve sebzelerin pirinçli/etli harçla doldurulmasıyla yapılır.':
        'Di pêjgeha kurdî de dolme bi tijîkirina pel û sebzeyan bi birinc û goşt '
        'tê çêkirin.',
    'Kürtlerin dağlara verdiği önem, tarih boyunca dağlık bir coğrafyada yaşamalarıyla ilişkilidir.':
        'Girîngiya ku kurd didin çiyayan, bi jiyana wan a di erdnîgariyeke çiyayî '
        'de ve girêdayî ye.',
    'Nan, Kürtçede ekmek anlamına gelen temel kelimedir.':
        'Nan di kurmancî de peyva bingehîn e ku tê wateya nanê xwarinê.',
    'Newroz "yeni gün" demektir ve bahar yeni yılını simgeler.':
        'Newroz tê wateya "roja nû" û sersala biharê sembolîze dike.',
    'Newroz kutlamalarının simgesi yakılan büyük ateştir.':
        'Sembola pîrozbahiyên Newrozê agirê mezin ê ku tê pêxistin e.',
    'Newroz, "nû" (yeni) ve "roj" (gün) sözcüklerinden oluşur: yeni gün.':
        'Newroz ji peyvên "nû" û "roj" pêk tê: roja nû.',
    'Ortak sunum ve paylaşım, aile, komşuluk ve misafirlik ilişkilerini güçlendiren kültürel pratiklerdir.':
        'Pêşkêşkirin û parvekirina hevbeş pratîkên çandî ne ku têkiliyên malbat, '
        'cîranî û mêvanperweriyê xurt dikin.',
    'Çay ikramı günlük yaşamın ve misafirliğin parçasıdır.':
        'Pêşkêşkirina çayê beşek ji jiyana rojane û mêvanperweriyê ye.',
    'Êzidî geleneğinde güneşe/ışığa verilen kutsallık, ibadet biçimlerine de yansır.':
        'Di kevneşopiya êzidî de pîroziya ku ji roj û ronahiyê re tê dayîn, di '
        'şêwazên îbadetê de jî xuya dibe.',
    'Êzidî toplumunda dinî-toplumsal önderlik geleneksel olarak Mîr ve Baba Şeyh tarafından yürütülür.':
        'Di civaka êzidî de serokatiya olî-civakî bi kevneşopî ji aliyê Mîr û Bavê '
        'Şêx ve tê meşandin.',
    'Êzidîlik, Kürtçe konuşan Êzidî topluluğunun geleneksel inancıdır.':
        'Êzidîtî baweriya kevneşopî ya civaka êzidî ya kurdîaxêv e.',
    'Şahmaran, yarı insan yarı yılan biçiminde tasvir edilen, bölgede yaygın efsanevi bir varlıktır.':
        'Şahmaran hebûneke efsanewî ya belav e ku nîv mirov nîv mar tê nîşandan.',
}


def main() -> int:
    targets = json.load(open(sys.argv[1], encoding='utf-8'))
    rows = json.load(open(BANK, encoding='utf-8'))
    written = 0
    unresolved = {}

    for row in rows:
        text = targets.get(row['id'])
        if text is None:
            continue
        kurmanci = KU.get(text.strip())
        if kurmanci is None:
            unresolved[text] = unresolved.get(text, 0) + 1
            continue
        row['explanationKu'] = kurmanci
        row.setdefault('explanationTr', row.get('explanation') or text)
        written += 1

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')

    print('Kurmancî karşılığı yazılan: %d' % written)
    print('çözülemeyen benzersiz metin: %d' % len(unresolved))
    for text in list(unresolved)[:12]:
        print('  %s' % text[:110])
    return 0


if __name__ == '__main__':
    sys.exit(main())
