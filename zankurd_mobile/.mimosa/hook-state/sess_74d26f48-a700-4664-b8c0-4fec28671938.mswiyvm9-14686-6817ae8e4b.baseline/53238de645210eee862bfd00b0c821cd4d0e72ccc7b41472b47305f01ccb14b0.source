# -*- coding: utf-8 -*-
"""Türkçe arayüzde Kurmancî görünen offline açıklamalarını çevirir.

`QuizQuestion.getLocalizedExplanation(false)` Türkçe alan yoksa ham metni
olduğu gibi döndürür. 2026-07-26 denetiminde 464 soruda o metin Kurmancî
çıkıyordu: Türkçe oyuncu, öğrenme anının tamamını okuyamıyordu.

Üç aile var:

1. `Ravekirina rast ji bo 'X' ev e: <tanım>` — tanımlar daha önce
   çevrilenlerle **aynı** (bkz. `translate_definitions.py` ve yazım
   araçları); mekanik olarak üretilir.
2. `'terim' → <tanım>` — Türkçe terim, Kurmancî tanım; tanımlar burada
   yazıldı.
3. Kalanlar — tek tek çevrildi.
"""

import importlib.util
import json
import re
import sys

BANK = 'assets/data/offline_questions.json'


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Daha önce çevrilmiş Kurmancî→Türkçe tanım sözlüğü.
_definitions = dict(_load('tool/translate_definitions.py', 'defs').DEFINITIONS)
for tool, attr in [
    ('tool/author_replacement_questions.py', 'TERMS'),
    ('tool/author_replacements_wave2.py', 'TERMS'),
]:
    module = _load(tool, attr.lower() + tool[-6:-3])
    for entries in getattr(module, attr).values():
        for _term, ku_def, tr_def, _difficulty in entries:
            _definitions.setdefault(ku_def + '.', tr_def + '.')
            _definitions.setdefault(ku_def, tr_def)

# 'terim' → tanım ailesi (Türkçe terim, Kurmancî tanım).
ARROW = {
    'ademi merkeziyetçilik': 'yetkinin merkezden yerel birimlere dağıtılması.',
    'adil yargılanma': 'bağımsız ve tarafsız mahkemelerde savunma hakkı.',
    'ahlaki güç': 'toplumun yasaya ihtiyaç duymadan kendini düzenleme yetisi.',
    'ahlaki-politik toplum': 'ahlaki değerleri olan ve kararını kendi veren toplum.',
    'anadili hakkı': 'ana dilin resmî ve kamusal alanlarda kullanılması.',
    'anadilinde eğitim': 'halkların kendi diliyle eğitim görme hakkı.',
    'antikapitalizm': 'kapitalizmin kâr ve sömürü mantığına karşı duruş.',
    'ataerkillik': 'erkeği egemen kılan ve kadını bastıran toplumsal sistem.',
    'azınlık hakları': 'çoğunluktan farklı grupların korunması.',
    'barış hakkı': 'toplumun savaşsız yaşama dair evrensel hakkı.',
    'barış süreci': 'çatışma durumunun diyalogla sonlandırılma aşaması.',
    'barışçıl çözüm': 'çatışmayı silahla değil diyalogla çözme iradesi.',
    'cinsiyet kotası': 'kadınların siyasete katılımını güvenceye alan yasal oran.',
    'cinsiyet özgürlükçü': 'cinsiyet baskısına ve ayrımcılığına karşı eşitlikçi ilke.',
    'demokratik anayasa': 'bütün farklı kesimleri kapsayan özgürlükçü anayasa.',
    'demokratik bilim': 'tekelleşmemiş, topluma hizmet eden bilim anlayışı.',
    'demokratik haklar beyannamesi': 'temel hakları sıralayan kurucu belge.',
    'demokratik haklar': 'gösteri, örgütlenme ve ifade özgürlüğü hakları.',
    'demokratik ittifak': 'ezilen farklı kesimlerin eşit birliği.',
    'demokratik ittifaklar': 'farklı muhalif grupların ortak barış platformu.',
    'demokratik kanton': 'yerel özerkliğe sahip idari ve toplumsal birim.',
    'demokratik komünalizm': 'komünal yaşam ve dayanışma temelli sistem.',
    'demokratik konfederal': 'aşağıdan kurulan, devletçi olmayan federasyon.',
    'demokratik konfederalizm': 'devletin dışında bir toplum yönetimi modeli.',
    'demokratik modernite akademisi': 'alternatif bilim ve yaşam arayışının okulu.',
    'demokratik muhalefet': 'mecliste ve sokakta hak arama kanalları.',
    'demokratik siyaset': 'bastırma ve tasfiye yerine diyaloğu seçen siyaset biçimi.',
    'demokratik ulus': 'ortak bir ülkede çok kültürlü ve eşit birliktelik.',
    'demokratik uygarlık': 'halkların devletçi olmayan komünal gelişim çizgisi.',
    'demokratik uzlaşı': 'tarafların ortak çıkar üzerinde buluşması.',
    'demokratik özerklik': 'bölgede özyönetim ve karar alma statüsü.',
    'devletçi uygarlık': 'sınıflı, hiyerarşik ve merkezinde devlet olan tarihsel çizgi.',
    'doğrudan demokrasi': 'halkın temsilciler olmadan doğrudan karar vermesi.',
    'doğrudan katılım': 'halkın siyasal kararlara doğrudan katılması.',
    'ekolojik bilinç': 'insanın doğanın bir parçası olduğunu kavraması.',
    'ekolojik endüstri': 'doğayla uyumlu ve geri dönüşümlü üretim biçimi.',
    'ekolojik toplum': 'doğayı tüketmeyen, onunla uyum içinde yaşayan toplum.',
    'endüstriyalizm': 'kâr için doğayı tahrip eden sanayi modeli.',
    'eş başkanlık': 'yönetim organlarında kadın-erkek eşit temsil sistemi.',
    'hakikat komisyonu': 'geçmişin acılarını araştırıp toplumsal barışı kuran komite.',
    'hiyerarşi': 'toplumda alt-üst ilişkisi kuran baskıcı örgütlenme.',
    'hiyerarşisiz toplum': 'tahakküm ve sömürü olmayan eşitlikçi düzen.',
    'idari özerklik': 'yerel bütçe ve hizmetleri kendi yönetme hakkı.',
    'insan hakları': 'herkesin doğuştan sahip olduğu evrensel haklar.',
    'kadın akademileri': 'kadın bilincini ve jineolojiyi geliştiren okullar.',
    'kadın özgürlüğü': 'toplumsal özgürleşmenin en temel ölçüsü.',
    'kapitalist modernite': 'endüstriyalizm, ulus-devlet ve kapitalizm üçlüsü.',
    'katılımcı bütçe': 'bütçe harcamalarının halk meclislerince belirlenmesi.',
    'komün': 'toplum yönetiminin en küçük ve doğrudan katılımlı birimi.',
    'komünal ekonomi': 'kâr yerine ihtiyaç ve paylaşımı esas alan ekonomi.',
    'komünal mülkiyet': 'toprağın ve araçların topluma ait ortak mülkiyeti.',
    'kooperatifçilik': 'komünal ekonominin temel dayanışma birimi.',
    'kuvvetler ayrılığı': 'yasama, yürütme ve yargının birbirinden bağımsızlığı.',
    'meclis sistemi': 'kararın tek bir başkan yerine komitelerce alındığı düzen.',
    'meclis': 'komünlerin üzerinde eşgüdüm ve karar organı.',
    'meşruiyet': 'yönetimin halkın rızasına ve hukuka uygunluğu.',
    'müzakere': 'sorunları diyalog yoluyla çözme yöntemi.',
    'parti eş başkanlığı': 'partilerde kadının eşit söz sahibi olduğu sistem.',
    'politikleşme': 'toplumun sözle ve kararla kendi kaderine sahip çıkması.',
    'pozitivizm': 'yalnız maddi olguları kabul eden dogmatik bilim anlayışı.',
    'radikal demokrasi': 'aşağıdan doğrudan katılımı öne alan demokrasi.',
    'sivil itaatsizlik': 'adaletsiz yasalara karşı barışçıl gösteri biçimi.',
    'sivil katılım': 'dernek ve inisiyatifler yoluyla yönetime katılma.',
    'sivil toplum': 'devletin dışındaki toplumsal öz örgütlenme alanları.',
    'siyasi ahlak': 'siyasette dürüstlük ve toplum yararını önceleme ilkeleri.',
    'siyasi katılım': 'yurttaşların karar süreçlerine dâhil olması.',
    'siyasi özerklik': 'kendi yasasını yapabilen yerel parlamentonun yetkisi.',
    'sosyal sözleşme': 'kantonların ve komünlerin ortak kurucu metni.',
    'statü hakkı': 'halkların kendi kimliğiyle tanınma ve yönetilme hakkı.',
    'statü talebi': 'anayasal güvence ve kültürel hakların tanınması talebi.',
    'tekelcilik': 'ekonomik ve siyasal gücün tek elde toplanması krizi.',
    'temsili demokrasi': 'halkın yönetime yalnız seçimlerle katıldığı sistem.',
    'toplumsal adalet': 'kaynakların ve hakların eşit paylaşımı ilkesi.',
    'toplumsal barış': 'farklı etnik ve inanç gruplarının huzurlu birlikte yaşamı.',
    'toplumsal cinsiyet': 'toplumun kadın ve erkeğe yüklediği kurgulanmış roller.',
    'toplumsal ekoloji': 'doğanın tahribi ile hiyerarşi arasındaki bağı kuran bilim.',
    'toplumsal muhalefet': 'halkın resmî yönetime karşı barışçıl tepkilerinin örgütlenmesi.',
    'toplumsal sözleşme': 'toplumun birlikte yaşama ilkelerini belirleyen belge.',
    'toplumsal uzlaşı': 'toplumun barışçıl çözüm için ortak karara varması.',
    'ulus devlet': 'tek biçimli ve sınırları kutsayan devlet yapısı.',
    'yerel demokrasi': 'kararların halka en yakın birimlerde alınması.',
    'yerel irade': 'merkezden atanan kayyum yerine seçilmiş yerel yöneticinin gücü.',
    'yerel meclisler': 'yerel kararların alındığı halk meclisleri.',
    'yerel yönetim': 'belediye ve yerel komitelerden oluşan yönetim.',
    'yerel özerklik şartı': 'yerel yönetimlerin gücünü artıran uluslararası belge.',
    'çoğulcu demokrasi': 'yalnız çoğunluğun değil azınlığın da dinlendiği yapı.',
    'çoğulculuk': 'farklı kimlik ve inançların eşit kabulü.',
    'öz savunma': 'toplumun kendini koruma ve örgütleme hakkı.',
    'özgür eş yaşam': 'baskı ve sahiplenme üzerine kurulmayan eşit ortak yaşam.',
    'özgürlük ölçütü': 'toplumun genel özgürlüğünün kadının özgürlüğüyle ölçülmesi.',
    'özyönetim hakkı': 'toplumun dış baskı olmadan kendini yönetme hakkı.',
}

# Kalanlar: tek tek çeviri.
DIRECT = {
    "'Rojbaş' ji bo günaydın an iyi günler tê bikaranîn.":
        "'Rojbaş' günaydın ya da iyi günler için kullanılır.",
    "'ji kerema xwe' tê wateya 'lütfen'. 'Spas dikim' tê wateya 'teşekkür ederim'.":
        "'ji kerema xwe' lütfen, 'Spas dikim' teşekkür ederim demektir.",
    "'çîrok' Kurmancîde hikâye/anlatı anlamına gelir.":
        "'çîrok' Kurmancîde hikâye/anlatı anlamına gelir.",
    "'Şevbaş' tê wateya 'iyi geceler'. 'Êvarbaş' tê wateya 'iyi akşamlar'.":
        "'Şevbaş' iyi geceler, 'Êvarbaş' iyi akşamlar demektir.",
    'Aştî û siyaseta demokratîk, tundûtûjî û ferzkirinê wek rêbazek çareseriyê red dikin.':
        'Barış ve demokratik siyaset, şiddeti ve dayatmayı bir çözüm yöntemi olarak reddeder.',
    "Bersiva vê tiştokê 'kuvark' (mantar) an jî 'sîwan' (şemsiye) e.":
        "Bu bilmecenin cevabı 'kuvark' (mantar) ya da 'sîwan' (şemsiye).",
    "Bersiva vê tiştokê 'xwê' (tuz) e.":
        "Bu bilmecenin cevabı 'xwê' (tuz).",
    'Civaka ekolojîk, ji civaka pîşesaziyê bi wê cudahiyê vediqete ku xwezayê wek tiştekî ji bo mêtinkirina bêsînor nabîne.':
        'Ekolojik toplum, sanayi toplumundan doğayı sınırsız sömürülecek bir nesne olarak görmemesiyle ayrılır.',
    'DNS (Domain Name System) navên malperan (wek google.com) vediguherîne navnîşanên IP.':
        'DNS (Domain Name System), site adlarını (örneğin google.com) IP adreslerine çevirir.',
    "Dema kesek dibêje 'êvarbaş', em bi heman şêweyî dibêjin 'êvarbaş'.":
        "Biri 'êvarbaş' dediğinde aynı şekilde 'êvarbaş' diye karşılık verilir.",
    'Demokrasiya radîkal, li şûna radestkirina biryaran a hilbijartiyan, beşdariya rasterast û berdewam a ji binî bingeh digire.':
        'Radikal demokrasi, kararları seçilmişlere devretmek yerine aşağıdan doğrudan ve sürekli katılımı esas alır.',
    "Di Flutter de her hêmaneke dîtbarî û sêwiranê wek 'Widget' tê naskirin.":
        "Mobil uygulama tasarımında her görsel öge 'widget' olarak adlandırılır.",
    "Di Kurmancî de 'teknolojiya ewrî' ji bo 'cloud computing' tê bikaranîn.":
        "Kurmancîde 'cloud computing' için 'teknolojiya ewrî' kullanılır.",
    "Di Kurmancî de ji bo 'bilgisayar' peyva 'komputer' an 'computer' tê bikaranîn.":
        "Kurmancîde 'bilgisayar' için 'komputer' sözcüğü kullanılır.",
    "Di Kurmancî de ji bo 'buyurun' peyva 'fermo' tê bikaranîn.":
        "Kurmancîde 'buyurun' için 'fermo' kullanılır.",
    "Di Kurmancî de ji bo 'dosya' peyva 'peldank' an 'dosya' tê bikaranîn.":
        "Kurmancîde 'dosya' için 'peldank' ya da 'dosya' kullanılır.",
    "Di Kurmancî de ji bo 'fare (mouse)' peyva 'mişk' tê bikaranîn.":
        "Kurmancîde 'fare' için 'mişk' kullanılır.",
    "Di Kurmancî de ji bo 'klavye' peyva 'textê tiliyan' an 'klavye' tê bikaranîn.":
        "Kurmancîde 'klavye' için 'textê tiliyan' kullanılır.",
    "Di Kurmancî de ji bo 'veri' peyva 'dane' tê bikaranîn.":
        "Kurmancîde 'veri' için 'dane' kullanılır.",
    "Di Kurmancî de ji bo 'web sitesi' peyva 'malper' tê bikaranîn.":
        "Kurmancîde 'web sitesi' için 'malper' kullanılır.",
    "Di Kurmancî de ji bo 'özür dilerim' peyva 'bibexşîne' an 'lêborînê dixwazim' tê bikaranîn.":
        "Kurmancîde 'özür dilerim' için 'bibexşîne' ya da 'lêborînê dixwazim' kullanılır.",
    "Di programkirinê de ji bo çerxên dubarekirinê (loop) peyva 'xelek' tê bikaranîn.":
        "Programlamada döngü (loop) için Kurmancîde 'xelek' kullanılır.",
    'Di xweseriya demokratîk de, biryar bi rêya meclîs û komînên herêmî ji binî ve tên girtin.':
        'Demokratik özerklikte kararlar yerel meclis ve komünler yoluyla aşağıdan alınır.',
    'Ekolojiya civakî, girêdana di navbera têkiliyên serdestiyê yên civakê û xerakirina xwezayê de dixe navend.':
        'Toplumsal ekoloji, toplumdaki tahakküm ilişkileri ile doğanın tahribi arasındaki bağı merkeze alır.',
    'Eksên bingehîn ên paradîgmayê azadiya jinê, civaka ekolojîk û demokrasiya binî ne.':
        'Paradigmanın temel eksenleri kadın özgürlüğü, ekolojik toplum ve aşağıdan demokrasidir.',
    'Ev slogan bi wateya "jin, jiyan, azadî" tê zanîn.':
        'Bu slogan "jin, jiyan, azadî" — kadın, yaşam, özgürlük — anlamıyla bilinir.',
    "Ev tiştokeke kurdî ya gelêrî ye, bersiva wê 'sol' (pêlav) e.":
        "Bu bir Kürt halk bilmecesidir; cevabı 'sol' (ayakkabı).",
    "Ev tiştokeke zekayê ye, bersiva wê 'kolin' an 'çal' (çukur) e.":
        "Bu bir zekâ bilmecesidir; cevabı 'kolin' ya da 'çal' (çukur).",
    'Ji bo şîfrekirin û parastina ragihandina înternetê protokola HTTPS / SSL tê bikaranîn.':
        'İnternet iletişimini şifrelemek ve korumak için HTTPS / SSL protokolü kullanılır.',
    'Konfederalîzma demokratîk, ne dagirkirina dewletê, lê avakirina xweseriyeke civakî ya alternatîf a li ser dewletê armanc dike.':
        'Demokratik konfederalizm devleti ele geçirmeyi değil, devletin ötesinde alternatif bir toplumsal özerklik kurmayı hedefler.',
    'Mafê zimanê zikmakî bi berdewamiya hebûna çandî û nasnameyê ve girêdayî ye.':
        'Ana dil hakkı, kültürel varoluşun ve kimliğin sürekliliğine bağlıdır.',
    "Mela Ehmedê Xasî, Zazakî'de (Kirmanckî) ilk yazılı mevlitlerden birini vermesiyle bilinir.":
        "Mela Ehmedê Xasî, Zazakîde (Kirmanckî) ilk yazılı mevlitlerden birini vermesiyle bilinir.",
    'Modernîteya demokratîk; derbaskirina krîzên ekolojîk, ên jinê û ên demokrasiyê armanc dike.':
        'Demokratik modernite; ekolojik, kadın ve demokrasi krizlerinin aşılmasını hedefler.',
    'Modernîteya demokratîk; nirxên demokrasî, azadiya jinê û ekolojiyê bingeh digire.':
        'Demokratik modernite; demokrasi, kadın özgürlüğü ve ekoloji değerlerini esas alır.',
    'Netewa demokratîk, hevpariya wekhev, dilxwazî û pirrengiya gel û baweriyên cuda bingeh digire.':
        'Demokratik ulus; farklı halk ve inançların eşit, gönüllü ve çoğul birlikteliğini esas alır.',
    'Paradîgma, beşdariya rasterast û xwerêxistî (komîn-meclîs) ya civakê bingeh digire.':
        'Paradigma, toplumun doğrudan katılımını ve öz örgütlenmesini (komün-meclis) esas alır.',
    "Peyva 'şîfre' tê wateya şifre an parolan.":
        "'Şîfre' sözcüğü şifre ya da parola anlamına gelir.",
    'Pirrengî, di netewa demokratîk de hevjiyana wekhev a nasname û baweriyên cuda misoger dike.':
        'Çoğulculuk, demokratik ulusta farklı kimlik ve inançların eşit birlikte yaşamasını güvenceye alır.',
    'Çareseriya demokratîk; nirxên wekhevî, azadî û aştiyê pêşdixe.':
        'Demokratik çözüm; eşitlik, özgürlük ve barış değerlerini geliştirir.',
    'Çiyayên Qendîlê li ser sînorê Îraq û Îranê ne.':
        'Kandil dağları Irak ile İran sınırında yer alır.',
}

_RAVEKIRIN = re.compile(r"^Ravekirina rast ji bo '(.+?)' ev e: (.+)$", re.S)
_ARROW = re.compile(r"^'(.+?)' → (.+)$", re.S)


def turkish_for(text):
    """Kurmancî açıklamanın Türkçesi; çözülemezse None."""
    direct = DIRECT.get(text)
    if direct:
        return direct

    match = _RAVEKIRIN.match(text)
    if match:
        turkish_def = _definitions.get(match.group(2).strip())
        if turkish_def:
            return "'%s' için doğru açıklama şudur: %s" % (
                match.group(1), turkish_def,
            )
        return None

    match = _ARROW.match(text)
    if match:
        turkish_def = ARROW.get(match.group(1).strip())
        if turkish_def:
            return "'%s' → %s" % (match.group(1), turkish_def)
    return None


def main() -> int:
    targets = json.load(open(sys.argv[1], encoding='utf-8'))
    rows = json.load(open(BANK, encoding='utf-8'))
    written = 0
    unresolved = {}

    for row in rows:
        text = targets.get(row['id'])
        if text is None:
            continue
        turkish = turkish_for(text)
        if turkish is None:
            unresolved[text] = unresolved.get(text, 0) + 1
            continue
        row['explanationTr'] = turkish
        row.setdefault('explanationKu', row.get('explanation') or text)
        written += 1

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')

    print('Türkçesi yazılan açıklama: %d' % written)
    print('çözülemeyen benzersiz metin: %d' % len(unresolved))
    for text in list(unresolved)[:10]:
        print('  %s' % text[:110])
    return 0


if __name__ == '__main__':
    sys.exit(main())
