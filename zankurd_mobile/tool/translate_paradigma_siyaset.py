# -*- coding: utf-8 -*-
"""Paradigma/Siyaset kategorilerindeki Türkçe cevap/açıklama metinlerini
Kurmancîye çevirir. Terminoloji web araştırmasına dayanır (bkz. 2026-07-21
oturum notu): Öcalan'ın Kurmancî çevirileri (Manîfestoya Şaristaniya
Demokratîk, archive.org), jineolojî akademik kaynakları (zayenda civakî),
ve yerleşik Kürt siyasi sözlüğü (netew-dewlet, modernîteya kapîtalîst).

Üç kalıp bulundu ve ayrı ayrı ele alındı:
1. '<terim>' → <Türkçe tanım>.  (94 benzersiz, terim zaten Kurmancî)
2. '<terim>' için sorudaki iddia doğru değildir; doğru cevap 'Şaş'tır. (28, hepsi Şaş)
3. '<terim>' Paradigma/Siyaset alanında geçerli bir kavramdır. (36)
Kalan ~16 tam özgün cümle elle çevrildi.

Aynı Türkçe tanım metinleri çoktan seçmeli cevap (answers) listesinde de
çeldirici olarak tekrar kullanılıyor — aynı sözlük ikisinde de uygulanır.
"""
import re
from pathlib import Path

BANK = Path("lib/src/data/offline_question_bank.dart")

# 1) '<terim>' → <tanım> kalıbındaki 94 benzersiz tanım.
GLOSSARY = {
    "gücün tek merkezden yerel birimlere dağıtılması.": "hêza ji navendekê bo yekîneyên herêmî belavkirin.",
    "bağımsız ve tarafsız mahkemelerde savunma hakkı.": "mafê parastinê li dadgehên serbixwe û bêalî.",
    "yasalara gerek kalmadan toplumun kendini yönetebilmesi.": "şiyana civakê ya xweseriyê bêyî pêwîstiya qanûnan.",
    "kendi kararlarını alan, etik değerlere sahip toplum.": "civakeke xwedî nirxên exlaqî ku biryarên xwe bi xwe digire.",
    "resmi ve kamusal alanlarda anadilinin kullanılması.": "bikaranîna zimanê zikmakî di qadên fermî û gelemperî de.",
    "halkların kendi diliyle eğitim alma hakkı.": "mafê gelan ê perwerdehiyê bi zimanê xwe.",
    "kapitalizmin kâr ve sömürü mantığına karşı duruş.": "helwesteke li dijî mantiqê qezenc û mêtinkirinê yê kapîtalîzmê.",
    "erkeği egemen kılan, kadını ezen toplumsal yapı.": "pergaleke civakî ku zilamî serdest dike û jinê tepser dike.",
    "çoğunluğa karşı farklı olan grupların korunması.": "parastina komên ku ji piraniyê cuda ne.",
    "toplumun savaşsız bir ortamda yaşama evrensel hakkı.": "mafê gerdûnî yê civakê ê jiyana bêyî şer.",
    "çatışmalı ortamı diyalogla sonlandırma aşaması.": "qonaxa bidawîkirina rewşa pevçûnê bi diyalogê.",
    "çatışmaları silah yerine diyalogla çözme iradesi.": "îrada çareserkirina pevçûnan bi diyalogê li şûna çekan.",
    "siyasette kadın katılımını güvenceye alan yasal oran.": "rêjeya qanûnî ya ku beşdariya jinan a siyasetê misoger dike.",
    "cinsel baskı ve ayrımcılığa karşı eşitlikçi ilke.": "prensîbeke wekhevîxwaz a li dijî tepser û cudakariya zayendî.",
    "tüm farklı kesimleri kapsayan özgürlükçü anayasa.": "destûreke azadîxwaz a ku hemû beşên cuda vedihewîne.",
    "tekelci olmayan, topluma hizmet eden bilim anlayışı.": "têgihiştineke zanistî ya ne-tekelîst ku xizmetê civakê dike.",
    "temel hakları listeleyen kurucu belge.": "belgeyeke damezrîner a ku mafên bingehîn rêz dike.",
    "protesto, örgütlenme ve ifade özgürlüğü hakları.": "mafên xwepêşandan, xwerêxistin û azadiya îfadeyê.",
    "farklı ezilen kesimlerin eşitlikçi birlikteliği.": "yekîtiya wekhev a beşên cuda yên bindest.",
    "farklı muhalif grupların ortak barış platformu.": "platforma hevbeş a aştiyê ya komên muxalif ên cuda.",
    "yerel özerkliğe sahip idari ve toplumsal birim.": "yekîneyeke îdarî û civakî ya xwedî xweseriya herêmî.",
    "komün yaşamına ve dayanışmaya dayalı sistem.": "pergaleke li ser bingeha jiyana komînal û hevgirtinê.",
    "devletçi olmayan, tabana dayalı federasyon.": "federasyoneke ne-dewletgir a li ser bingeha binî.",
    "devlet dışı toplumsal yönetim modeli.": "modeleke rêveberiya civakî ya derveyî dewletê.",
    "alternatif bilim ve yaşam arayışının okulu.": "dibistana lêgerîna zanist û jiyaneke alternatîf.",
    "mecliste ve sokakta hak arama kanalları.": "kanalên lêgerîna maf li meclîsê û li kolanan.",
    "baskı ve tasfiye yerine diyalogu seçen siyaset tarzı.": "awayekî siyasetê yê ku li şûna tepser û tesfiyeyê, diyalogê hildibijêre.",
    "halkın doğrudan yönetime ve karar süreçlerine katılımı.": "beşdariya gel a rasterast di rêveberî û pêvajoyên biryarê de.",
    "ortak vatanda çok kültürlü ve eşitlikçi birliktelik.": "hevpariyeke pirkulturî û wekhev di welatekî hevbeş de.",
    "devletçi olmayan, halkların komünal gelişim çizgisi.": "xeteke pêşketina komînal a gelan a ne-dewletgir.",
    "ortak yararda partilerin bir araya gelmesi.": "hevkombûna aliyan li ser berjewendiya hevbeş.",
    "yerelde kendi kendini yönetme ve karar alma statüsü.": "statûya xweseriyê û biryargirtinê li herêmê.",
    "sınıflı, hiyerarşik ve devlet odaklı tarih çizgisi.": "xeteke dîrokî ya çînî, hiyerarşîk û navenda wê dewlet e.",
    "halkın temsilciler olmadan doğrudan karar alması.": "biryargirtina rasterast a gel bêyî nûneran.",
    "halkın siyasi kararlara bizzat dahil olması.": "beşdariya rasterast a gel di biryarên siyasî de.",
    "insanın doğanın bir parçası olduğunu anlama durumu.": "têgihiştina mirov a ku ew parçeyekî xwezayê ye.",
    "doğayla uyumlu, geri dönüşümlü üretim tarzı.": "awayekî hilberînê yê li gel xwezayê li hev û bi vegerandinê.",
    "doğayı sömürmeyen, onunla uyumlu yaşayan toplum.": "civakeke ku xwezayê nametirîne, li gel wê bi lihevhatî dijî.",
    "kâr amaçlı doğayı tahrip eden sanayileşme modeli.": "modeleke pîşesaziyê ya ji bo qezencê xwezayê xera dike.",
    "yönetim organlarında kadın-erkek eşit temsil sistemi.": "pergala nûnertiya wekhev a jin-mêr di organên rêveberiyê de.",
    "yönetimde eşit temsil sistemidir.": "pergaleke nûnertiya wekhev a di rêveberiyê de ye.",
    "geçmişteki acıları araştırıp toplumsal barışı kuran kurul.": "komîteyek ku êşên borî lêkolîn dike û aştiya civakî ava dike.",
    "toplumda alt-üst ilişkisi kuran baskıcı örgütlenme.": "rêxistineke tepserker a ku têkiliya jêr-jor di civakê de ava dike.",
    "tahakküm ve sömürünün olmadığı eşitlikçi düzen.": "nîzameke wekhev a bêyî serdestî û mêtinkirinê.",
    "yerel bütçe ve hizmetleri kendi yönetme hakkı.": "mafê birêvebirina bûçe û xizmetên herêmî bi xwe.",
    "her bireyin doğuştan sahip olduğu evrensel haklar.": "mafên gerdûnî yên ku her kes ji dayikbûnê xwedî wan e.",
    "kadın bilincini ve jineolojiyi geliştiren okullar.": "dibistanên ku hişmendiya jinê û jineolojiyê pêş dixin.",
    "toplumsal özgürleşmenin en temel kriteri.": "pîvana herî bingehîn a azadbûna civakî.",
    "endüstriyalizm, ulus-devlet ve kapitalizm üçlüsü.": "sêalîtiya pîşesazîparêziyê, netew-dewlet û kapîtalîzmê.",
    "bütçe harcamalarını halkın meclislerle belirlemesi.": "diyarkirina lêçûnên bûçeyê ji aliyê gel ve bi meclîsan.",
    "toplumun en küçük ve doğrudan katılımcı yönetim birimi.": "yekîneya herî biçûk û a rasterast beşdar a rêveberiya civakê.",
    "kâr yerine ihtiyacı ve paylaşımı esas alan ekonomi.": "aboriyeke ku li şûna qezencê, pêdivî û parvekirinê bingeh digire.",
    "toprağın ve araçların topluma ait olması.": "milkiyeta axê û amûran a gişî civakê.",
    "komünal ekonominin temel dayanışma birimi.": "yekîneya bingehîn a hevgirtinê ya aboriya komînal.",
    "yasama, yürütme ve yargının bağımsız olması.": "serbixwebûna hêzên qanûndanînê, cîbicîkirinê û dadwerî.",
    "kararların tek lider yerine kurullarla alınması.": "pergaleke ku biryar li şûna serokekî bi komîteyan tê girtin.",
    "komünlerin üstünde yer alan koordinasyon ve karar organı.": "organeke hevrêzî û biryarê ya li ser komînan.",
    "yönetimin halkın rızasına ve hukuka uygun olması.": "guncaniya rêveberiyê bi razîbûna gel û hiqûqê re.",
    "sorunları diyalog yoluyla çözme yöntemi.": "rêbaza çareserkirina pirsgirêkan bi rêya diyalogê.",
    "partilerde kadının eşit söz sahibi olma sistemi.": "pergaleke ku jin di partiyan de wekhev xwedî deng in.",
    "erkek egemen sistemin yapısını deşifre etme.": "eşkerekirina avahiya pergala serdestiya zilaman.",
    "toplumun kendi kaderi hakkında söz ve karar sahibi olması.": "xwedîderketina civakê li ser çarenûsa xwe bi deng û biryar.",
    "sadece maddi olguları kabul eden, dogmatik bilim anlayışı.": "têgihiştineke zanistî ya dogmatîk a ku tenê rastiyên madî qebûl dike.",
    "tabandan doğrudan katılımı öncelikli kılan demokrasi.": "demokrasiyeke ku beşdariya rasterast a ji binî pêşî lê digire.",
    "adaletsiz yasalara karşı barışçıl protesto biçimi.": "awayekî xwepêşandana aştiyane ya li dijî qanûnên bêadalet.",
    "dernekler ve inisiyatiflerle yönetime müdahil olma.": "tevlêbûna rêveberiyê bi rêya komele û înîsiyatîfan.",
    "devlet dışı, toplumsal örgütlenme alanları.": "qadên xwerêxistina civakî yên derveyî dewletê.",
    "siyasette dürüstlük ve toplumsal yararı önceleme ilkeleri.": "prensîbên rastgoyî û pêşiyê dayîna berjewendiya civakî di siyasetê de.",
    "vatandaşların karar alma süreçlerine müdahil olması.": "tevlêbûna hemwelatiyan di pêvajoyên biryargirtinê de.",
    "kendi yasalarını yapabilen yerel parlamento yetkisi.": "desthilata parlamentoya herêmî ya ku dikare qanûnên xwe çêbike.",
    "kantonların ve komünlerin ortak kurucu metni.": "metna damezrîner a hevbeş a kanton û komînan.",
    "halkların kendi kimliğiyle tanınma ve yönetilme hakkı.": "mafê gelan ê nasîn û rêveberiyê bi nasnameya xwe.",
    "anayasal güvence ve kültürel hakların tanınması.": "daxwaza misogeriya destûrî û naskirina mafên çandî.",
    "economic and political centralization crisis.": "krîza navendîbûna aborî û siyasî ya destekî yekane.",
    "halkın sadece seçimlerle yönetime katıldığı sistem.": "pergaleke ku gel tenê bi hilbijartinan beşdarî rêveberiyê dibe.",
    "kaynakların ve hakların eşit paylaşılması ilkesi.": "prensîba parvekirina wekhev a çavkanî û mafan.",
    "farklı etnik ve inanç gruplarının huzurlu birlikteliği.": "hevjiyana aram a komên etnîkî û baweriyê yên cuda.",
    "toplumun kadın ve erkeğe biçtiği yapay roller.": "rolên çêkirî yên ku civakê ji jin û mêr re diyar kiriye.",
    "doğa tahribatının hiyerarşiyle ilişkisini kuran bilim.": "zanisteke ku têkiliya di navbera xerakirina xwezayê û hiyerarşiyê de ava dike.",
    "resmi yönetime karşı halkın barışçıl tepki örgütlenmesi.": "rêxistina bertekên aştiyane yên gel li dijî rêveberiya fermî.",
    "toplumun bir arada yaşama ilkelerini belirleyen belge.": "belgeya ku prensîbên hevjiyana civakê diyar dike.",
    "barışçıl çözüm için toplumun ortak karara varması.": "gihiştina civakê ya biryareke hevbeş ji bo çareseriyeke aştiyane.",
    "tek tipleştirici, sınırları kutsallaştıran devlet yapısı.": "avahiyeke dewletê ya yekreng û sînoran pîroz dike.",
    "kararların halka en yakın birimlerde alınması.": "girtina biryaran li yekîneyên herî nêzî gel.",
    "merkezden atanan kayyum yerine seçilmiş yerel yönetici gücü.": "hêza rêveberê herêmî yê hilbijartî li şûna qeyûmê ji navendê tayînkirî.",
    "yerel kararların alındığı halk meclisleri.": "meclîsên gel ên ku biryarên herêmî lê tên girtin.",
    "belediyeler ve yerel kurulların oluşturduğu yönetim.": "rêveberiya ku ji şaredarî û komîteyên herêmî pêk tê.",
    "yerel yönetimlerin gücünü artıran uluslararası belge.": "belgeyeke navneteweyî ya ku hêza rêveberiyên herêmî zêde dike.",
    "sadece çoğunluğun değil azınlığın da dinlendiği yapı.": "avahiyeke ku ne tenê piranî, belkî hindikahî jî tê guhdarîkirin.",
    "farklı kimliklerin ve inançların eşit kabul edilmesi.": "qebûlkirina wekhev a nasname û baweriyên cuda.",
    "toplumun kendini koruma ve örgütleme hakkı.": "mafê civakê yê xwe parastin û xwerêxistinê.",
    "baskı ve sahiplenmeye dayanmayan eşit ortak yaşam.": "jiyaneke hevbeş a wekhev ku li ser tepser û xwedîtiyê ava nabe.",
    "toplumun genel özgürlüğünün kadının özgürlüğüyle ölçülmesi.": "pîvana azadiya giştî ya civakê bi azadiya jinê tê pîvan.",
    "toplumun dışarıdan baskı olmadan kendini yönetmesi.": "mafê civakê yê xwerêveberiyê bêyî tepsera derveyî.",
}

# 2) Tümüyle özgün 16 cümle (elle çevrildi).
OTHER = {
    "Anadil hakkı, kültürel varoluş ve kimliğin sürdürülmesiyle ilişkilendirilir.":
        "Mafê zimanê zikmakî bi berdewamiya hebûna çandî û nasnameyê ve girêdayî ye.",
    "Barış ve demokratik siyaset, çözüm yöntemi olarak şiddet ve dayatmayı reddeder.":
        "Aştî û siyaseta demokratîk, tundûtûjî û ferzkirinê wek rêbazek çareseriyê red dikin.",
    "Demokratik konfederalizm, devleti ele geçirmeyi değil; onu aşan, alternatif bir toplumsal öz yönetim kurmayı hedefler.":
        "Konfederalîzma demokratîk, ne dagirkirina dewletê, lê avakirina xweseriyeke civakî ya alternatîf a li ser dewletê armanc dike.",
    "Demokratik modernite; demokrasi, kadın özgürlüğü ve ekoloji değerlerini esas alır.":
        "Modernîteya demokratîk; nirxên demokrasî, azadiya jinê û ekolojiyê bingeh digire.",
    "Demokratik modernite; ekolojik, kadın ve demokrasi krizlerini aşmayı hedefler.":
        "Modernîteya demokratîk; derbaskirina krîzên ekolojîk, ên jinê û ên demokrasiyê armanc dike.",
    "Demokratik ulus, farklı halk ve inançların eşit, gönüllü ve çoğulcu birlikteliğini esas alır.":
        "Netewa demokratîk, hevpariya wekhev, dilxwazî û pirrengiya gel û baweriyên cuda bingeh digire.",
    "Demokratik çözüm; eşitlik, özgürlük ve barış değerlerini önceler.":
        "Çareseriya demokratîk; nirxên wekhevî, azadî û aştiyê pêşdixe.",
    "Demokratik özerklikte kararlar, yerel meclis ve komünler aracılığıyla tabandan alınır.":
        "Di xweseriya demokratîk de, biryar bi rêya meclîs û komînên herêmî ji binî ve tên girtin.",
    "Ekolojik toplum, doğayı sınırsız sömürülecek bir nesne olarak görmemesiyle sanayi toplumundan ayrılır.":
        "Civaka ekolojîk, ji civaka pîşesaziyê bi wê cudahiyê vediqete ku xwezayê wek tiştekî ji bo mêtinkirina bêsînor nabîne.",
    "Jineolojî, kadın özgürlüğü, toplumsal cinsiyet, tarih ve bilgi üretimini yeniden düşünmeye odaklanan bir yaklaşımdır.":
        "Jineolojî, nêzîkatiyek e ku li ser ji nû ve raçavkirina azadiya jinê, zayenda civakî, dîrok û hilberîna zanînê hûr dibe.",
    "Paradigma, toplumun doğrudan ve örgütlü (komün-meclis) katılımını esas alır.":
        "Paradîgma, beşdariya rasterast û xwerêxistî (komîn-meclîs) ya civakê bingeh digire.",
    "Paradigmanın temel eksenleri kadın özgürlüğü, ekolojik toplum ve taban demokrasisidir.":
        "Eksên bingehîn ên paradîgmayê azadiya jinê, civaka ekolojîk û demokrasiya binî ne.",
    "Radikal demokrasi, kararları seçilmişlere devretmek yerine tabandan doğrudan ve sürekli katılımı esas alır.":
        "Demokrasiya radîkal, li şûna radestkirina biryaran a hilbijartiyan, beşdariya rasterast û berdewam a ji binî bingeh digire.",
    'Slogan "kadın (jin), yaşam (jiyan), özgürlük (azadî)" anlamına gelir.':
        'Ev slogan bi wateya "jin, jiyan, azadî" tê zanîn.',
    "Toplumsal ekoloji, toplumdaki tahakküm ilişkileri ile doğanın tahribi arasındaki bağı merkeze alır.":
        "Ekolojiya civakî, girêdana di navbera têkiliyên serdestiyê yên civakê û xerakirina xwezayê de dixe navend.",
    "Çoğulculuk, demokratik ulusta farklı kimlik ve inançların eşit biçimde bir arada yaşamasını güvence altına alır.":
        "Pirrengî, di netewa demokratîk de hevjiyana wekhev a nasname û baweriyên cuda misoger dike.",
    # İkinci tarama turunda bulunan, çeldirici (answers) listesindeki
    # bağımsız Türkçe cümle parçaları.
    "Doğayı yalnızca sömürü nesnesi olarak görmemesiyle":
        "Ji ber ku xwezayê tenê wek tiştê mêtinkirinê nabîne",
    "Tahakküm ile doğa tahribatı arasındaki ilişkiyi":
        "Têkiliya di navbera serdestiyê û xerakirina xwezayê de",
    "Yerel yönetim, eğitim ve ekonomi gibi alanlarda":
        "Di qadên wek rêveberiya herêmî, perwerdehî û aboriyê de",
    "Toplulukların yerel olarak kendi işlerini yönetmesini":
        "Birêvebirina karên xwe yên herêmî ji aliyê civakan ve",
    "Tabandan doğrudan ve sürekli katılımı önceler":
        "Beşdariya rasterast û berdewam a ji binî pêş dixe",
    "Sadece sembolik değil, örgütsel ve kurumsal düzeyde":
        "Ne tenê sembolîk, lê di asta rêxistinî û saziyî de",
    "Toplum ile doğa arasında uyumlu, sürdürülebilir bir ilişkiyi":
        "Têkiliyeke li hev û berdewam a di navbera civakê û xwezayê de",
    "Kimlik, dil, statü ve haklar sorunu olarak":
        "Wek pirsgirêka nasname, ziman, statû û mafan",
    "Eğitim uygulaması için güvenli, analitik ve demokratik öğrenme amaçlandığı için":
        "Ji ber ku ji bo pratîka perwerdehiyê fêrbûneke ewle, analîtîk û demokratîk armanc kirî ye",
    "Hem reel sosyalizmi hem kapitalizmi olduğu gibi":
        "Wek her du sosyalîzma reel û kapîtalîzmê red dike",
    "Toplumun bütününün özgürleşmesinin koşulu sayıldığı için":
        "Ji ber ku wek şerta azadbûna civakê bi tevahî tê hesibandin",
    "Kimliğin ve kültürün kuşaklara aktarımı için":
        "Ji bo veguhastina nasname û çandê ji nifşekî bo yê din",
    "Yerel/bölgesel düzeyde":
        "Li asta herêmî/deverî",
    "Toplum-doğa ilişkisini iktidar ve ekonomi eleştirisiyle birlikte ele aldığı için":
        "Ji ber ku têkiliya civak-xweza bi rexneya desthilatdarî û aboriyê ve tevî hev vedihewîne",
}


def main():
    text = BANK.read_text(encoding="utf-8")
    original = text
    stats = {"arrow": 0, "answers": 0, "tf": 0, "generic": 0, "other": 0}

    # Dosyada tek-tırnaklı Dart string literalleri, içindeki tırnaklar
    # `\'` olarak kaçışlanmış halde saklanıyor (dosya ham metin olarak
    # okunduğu için `\'` iki karakter: ters bölü + tırnak). Tüm literal
    # değerleri tek geçişte işleyip hangi kalıba uyduğuna göre çeviriyoruz.
    STR_RE = re.compile(r"'((?:\\.|[^'\\])*)'")

    def unescape(s):
        return s.replace("\\'", "'")

    def escape(s):
        return s.replace("'", "\\'")

    def literal_repl(m):
        raw = m.group(1)
        s = unescape(raw)

        # 1) '<terim>' → <tanım>.
        am = re.match(r"^'([^']+)' → (.+)\.$", s)
        if am:
            term, tr_def = am.group(1), am.group(2).strip()
            ku_def = GLOSSARY.get(tr_def + ".")
            if ku_def is not None:
                stats["arrow"] += 1
                return "'" + escape(f"'{term}' → {ku_def}") + "'"

        # 2) True/False boilerplate.
        tm = re.match(r"^'([^']+)' için sorudaki iddia doğru değildir; doğru cevap 'Şaş'tır\.$", s)
        if tm:
            term = tm.group(1)
            stats["tf"] += 1
            return "'" + escape(f"'{term}' îdiaya di vê pirsê de ne rast e; bersiva rast 'Şaş' e.") + "'"

        # 3) '<terim>' Paradigma/Siyaset alanında geçerli bir kavramdır.
        gm = re.match(r"^'([^']+)' (Paradigma|Siyaset) alanında geçerli bir kavramdır\.$", s)
        if gm:
            term, category = gm.group(1), gm.group(2)
            stats["generic"] += 1
            qada = "Paradîgmayê" if category == "Paradigma" else "Siyasetê"
            return "'" + escape(f"'{term}' di qada {qada} de têgeheke derbasdar e.") + "'"

        # 4) Doğrudan çeldirici cevaplar (answers listesi) — aynı sözlük.
        # MC seçenekleri nokta içermez, sözlük anahtarları içerir.
        ku_def = GLOSSARY.get(s) or GLOSSARY.get(s + ".")
        if ku_def is not None:
            stats["answers"] += 1
            return "'" + escape(ku_def.rstrip(".") if not s.endswith(".") else ku_def) + "'"

        # 5) Tam özgün cümleler.
        ku_other = OTHER.get(s)
        if ku_other is not None:
            stats["other"] += 1
            return "'" + escape(ku_other) + "'"

        return m.group(0)

    text = STR_RE.sub(literal_repl, text)

    BANK.write_text(text, encoding="utf-8")
    print(stats)
    print("changed:", text != original)


if __name__ == "__main__":
    main()
