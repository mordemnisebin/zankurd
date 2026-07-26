# -*- coding: utf-8 -*-
"""İkinci dalga: Dîrok, Çand, Edebiyat, Muzîk ve Paradigma için gerçek sorular.

`drop_polarity_questions.py` cevabı cümlenin olumsuzluğundan okunabilen 225
kalıp soruyu çıkardı. Cografya ve Siyaset'in yerine yazılanlar
`author_replacement_questions.py` içinde; bu dosya kalan beş kategoriyi
tamamlar.

Kalıp aynı ve bankada kanıtlanmış:

    Rast e an şaş e: Têgeha «X» tê vê wateyê: <tanım>

Her terimden iki soru: biri doğru tanımla (Rast), biri **başka bir terimin
gerçek tanımıyla** (Şaş). Yanlış olan, olumsuzlaştırılmış bir cümle değil;
gerçek ama yanlış yere konmuş bir tanım — cevabı yalnız konuyu bilen verir.
Açıklama yanlış tanımın gerçek sahibini de söyler, böylece yanlış cevap da
öğretir.
"""

import json
import sys

BANK = 'assets/data/offline_questions.json'

# (Kurmancî terim, Kurmancî tanım, Türkçe tanım, zorluk)
TERMS = {
    'Dîrok': [
        ('Mîrgeha Bidlîsê', 'mîrnişîna kurd a ku Şerefxan jê derket û Şerefname li wir hat nivîsandin',
         'Şerefhan’ın çıktığı ve Şerefname’nin yazıldığı Kürt beyliği', 4),
        ('Mîrgeha Babanê', 'mîrnişîna kurd a bi navenda Silêmaniyê ku di sedsala 18em de bihêz bû',
         '18. yüzyılda güçlenen, merkezi Süleymaniye olan Kürt beyliği', 4),
        ('Serhildana Koçgirî', 'serhildana kurdî ya sala 1921ê ya li derdora Sêwasê',
         '1921’de Sivas yöresinde gelişen Kürt ayaklanması', 4),
        ('Serhildanên Agirî', 'berxwedana derdora Çiyayê Agirî ya di navbera salên 1927-1930 de',
         '1927-1930 arasında Ağrı Dağı çevresindeki direniş', 4),
        ('Komkujiya Helebceyê', 'êrîşa kîmyayî ya ku di sala 1988 de li dijî kurdan hat kirin',
         '1988’de Kürtlere karşı yapılan kimyasal saldırı', 3),
        ('Peymana Qesrişîrînê', 'peymana 1639an a ku erdnîgariya kurdî di navbera du împaratoriyan de par kir',
         'Kürt coğrafyasını iki imparatorluk arasında bölen 1639 antlaşması', 5),
        ('Komara Mehabadê', 'komara kurdî ya kurtedem a ku di sala 1946an de li rojhilat hat avakirin',
         '1946’da doğuda kurulan kısa ömürlü Kürt cumhuriyeti', 3),
        ('Qazî Mihemed', 'serokê Komara Mehabadê yê ku piştî hilweşandina wê hat îdamkirin',
         'Mehabad Cumhuriyeti’nin, yıkılışından sonra idam edilen lideri', 4),
        ('Şêx Seîd', 'serokê serhildana 1925an a li bakurê Kurdistanê',
         '1925’teki Kuzey Kürdistan ayaklanmasının önderi', 3),
        ('Mistefa Barzanî', 'serokê tevgera neteweyî ya başûr a ku bi dehsalan berdewam kir',
         'Güneydeki, onlarca yıl süren ulusal hareketin önderi', 3),
        ('Bedirxan Beg', 'mîrê Botan ê ku di sedsala 19em de li dijî navendîkirinê rabû',
         '19. yüzyılda merkezileşmeye karşı ayaklanan Botan beyi', 4),
        ('Mîqdat Mîdhad Bedirxan', 'kesê ku rojnameya kurdî ya yekem di sala 1898 de derxist',
         'İlk Kürt gazetesini 1898’de çıkaran kişi', 5),
        ('dîroka devkî', 'veguhastina bûyerên rabirdûyê bi rêya şahidî û çîrokên devkî',
         'geçmişin tanıklık ve sözlü anlatı yoluyla aktarılması', 2),
        ('çavkaniya seretayî', 'belge an tiştê ku ji wê serdemê maye û rasterast şahidî dike',
         'o dönemden kalan ve doğrudan tanıklık eden belge veya nesne', 3),
        ('koçberî', 'ji ber şer, aborî an siyasetê guhertina cihê jiyanê ya bi komî',
         'savaş, ekonomi ya da siyaset nedeniyle toplu yer değiştirme', 2),
    ],
    'Çand': [
        ('dengbêjî', 'kevneşopiya vegotina bi deng a ku çîrok û dîrokê bêyî amûrê digihîne',
         'hikâyeyi ve tarihi çalgısız, sesle aktaran anlatı geleneği', 2),
        ('şînî', 'awaza ku ji bo windahiyê tê gotin û êşê bi awayekî hevpar par dike',
         'kayıp için söylenen ve acıyı ortaklaştıran ezgi', 3),
        ('pêjgeha kurdî', 'kevneşopiya xwarinê ya ku li gorî herêm, avhewa û zarava diguhere',
         'bölgeye, iklime ve lehçeye göre değişen yemek geleneği', 2),
        ('nanê tenûrê', 'nanê kevneşopî yê ku li dîwarê tenûrê tê zeliqandin û tê patin',
         'tandırın duvarına yapıştırılarak pişirilen geleneksel ekmek', 1),
        ('şal û şapik', 'cilûbergê kevneşopî yê mêran ê ku ji du parçeyên hevgirtî pêk tê',
         'birbirini tamamlayan iki parçadan oluşan geleneksel erkek giysisi', 3),
        ('kelaş', 'pêlava kurdî ya kevneşopî ya destçêkirî ya ji ristina têlan',
         'iplik örülerek yapılan el yapımı geleneksel Kürt ayakkabısı', 4),
        ('kezî', 'şêwaza kevneşopî ya honandina porê jinan a bi gelek şaxan',
         'kadınların çok örgülü geleneksel saç örme biçimi', 4),
        ('destmala govendê', 'destmala ku serê govendê di destê xwe de dihejîne',
         'halay başının elinde salladığı mendil', 3),
        ('şabaş', 'kevneşopiya dayîna diyariya pereyî ya di dawet û şahiyan de',
         'düğün ve şenliklerde para hediyesi verme geleneği', 3),
        ('mêvanperwerî', 'qaîdeya exlaqî ya ku mêvan wek bereketa malê dihesibîne',
         'konuğu evin bereketi sayan ahlaki kural', 2),
        ('metelok', 'gotina kurt a ku bi mînakekê pendekê digihîne',
         'bir örnekle öğüt ileten kısa söz', 3),
        ('Êzidîtî', 'baweriya kevnar a ku ronahî û rojê pîroz dihesibîne',
         'ışığı ve güneşi kutsal sayan kadim inanç', 3),
        ('Melek Tawis', 'fîgura navendî ya baweriya êzidî ya ku bi motîfa tawisê tê nîşandan',
         'Êzidî inancının, tavus motifiyle gösterilen merkezî figürü', 4),
        ('sersal', 'demsala destpêka salê ya ku bi lîstik û şahiyên gundan tê pîrozkirin',
         'köy oyunları ve şenlikleriyle kutlanan yılbaşı dönemi', 3),
        ('hunera destan', 'çêkirina bi dest a tişt û xemlan a ku zanîna herêmî hildigire',
         'yerel bilgiyi taşıyan, elle nesne ve süs yapma sanatı', 2),
    ],
    'Edebiyat': [
        ('Mem û Zîn', 'destana Ehmedê Xanî ya ku evîn û pirsa neteweyî bi hev ve girê dide',
         'Ehmedê Xanî’nin aşk ile ulusal soruyu birleştiren destanı', 2),
        ('Siyabend û Xecê', 'destana evînê ya devkî ya ku bi dawiyeke trajîk tê zanîn',
         'trajik sonuyla bilinen sözlü aşk destanı', 3),
        ('Dewrêşê Evdî', 'destana devkî ya ku li ser wefadarî û şer tê gotin',
         'sadakat ve savaş üzerine söylenen sözlü destan', 4),
        ('Zembîlfiroş', 'çîroka gelêrî ya ku li ser sedaqet û ceribandinê ye',
         'sadakat ve sınanma üzerine bir halk hikâyesi', 4),
        ('Mewlûda Kurdî', 'berhema olî ya ku Melayê Bateyî bi kurmancî nivîsî',
         'Melayê Bateyî’nin Kurmancî yazdığı dinî eser', 4),
        ('Elî Herîrî', 'yek ji helbestvanên klasîk ên herî kevn ên wêjeya kurdî',
         'Kürt edebiyatının en eski klasik şairlerinden biri', 5),
        ('Nalî', 'helbestvanê klasîk ê soranî yê ku ekola Baban temsîl dike',
         'Baban ekolünü temsil eden klasik Soranî şairi', 5),
        ('Osman Sebrî', 'nivîskar û helbestvanê ku li Şamê di weşangeriya kurdî de xebitî',
         'Şam’da Kürt yayıncılığında çalışan yazar ve şair', 5),
        ('Qanatê Kurdo', 'zimannas û kurdolojîstê ku rêzimana kurmancî bi awayekî zanistî nivîsî',
         'Kurmancî dilbilgisini bilimsel biçimde yazan dilbilimci ve kürdolog', 5),
        ('kesayeta vegotinê', 'kesê ku bûyer li dora wî/wê digere û xwîner pê re dijî',
         'olayların çevresinde döndüğü ve okurun onunla yaşadığı kişi', 2),
        ('vebêj', 'dengê ku çîrokê digihîne û diyar dike ku bûyer ji ber kê tên gotin',
         'hikâyeyi ileten ve olayların kimin ağzından anlatıldığını belirleyen ses', 3),
        ('mecaz', 'bikaranîna peyvê ne bi wateya wê ya rasterast, lê bi wateyeke wêneyî',
         'sözcüğün düz anlamıyla değil, imgesel bir anlamla kullanılması', 3),
        ('kafiye', 'lihevhatina dengên dawiya rêzan a ku helbestê rîtm dide',
         'dizelerin sonundaki, şiire ritim veren ses uyumu', 2),
        ('destan', 'vegotina dirêj a ku lehengî û bîra komî ya gelekî hildigire',
         'kahramanlığı ve bir halkın ortak hafızasını taşıyan uzun anlatı', 2),
        ('Riya Taza', 'rojnameya kurdî ya ku li Ermenistana Sovyetê bi salan hat weşandin',
         'Sovyet Ermenistanı’nda yıllarca yayımlanan Kürtçe gazete', 5),
    ],
    'Muzîk': [
        ('kilam', 'awaza dirêj a dengbêjiyê ya ku çîrokek vedibêje',
         'bir hikâye anlatan uzun dengbêj ezgisi', 2),
        ('stranên govendê', 'stranên bilez û rîtmîk ên ku dema govendê tên gotin',
         'halay sırasında söylenen hızlı ve ritmik şarkılar', 2),
        ('makam', 'pergala perdeyan a ku rengê awazê diyar dike',
         'ezginin rengini belirleyen perde sistemi', 4),
        ('rîtm', 'parkirina demê ya ku govend û stran li ser tê avakirin',
         'halayın ve şarkının üzerine kurulduğu zaman bölümlenmesi', 1),
        ('koro', 'stranbêjiya bi kom a ku deng tê de li hev tên',
         'seslerin birleştiği topluca söyleme biçimi', 1),
        ('solo', 'stranbêjî an lêxistina bi tenê, berevajiyê koroyê',
         'koronun karşıtı olarak tek başına söyleme ya da çalma', 1),
        ('zurna', 'amûra bayî ya bilinddeng a ku bi dahol re li derve tê lêxistin',
         'davulla birlikte açık havada çalınan yüksek sesli üflemeli çalgı', 2),
        ('dahol', 'amûra lêdanê ya mezin a ku bi du daran tê lêxistin',
         'iki değnekle çalınan büyük vurmalı çalgı', 2),
        ('kemençe', 'amûra kevanî ya ku li erdnîgariya kurdî jî tê lêxistin',
         'Kürt coğrafyasında da çalınan yaylı çalgı', 3),
        ('dîwana dengbêjan', 'cihê ku dengbêj lê dicivin û bi dor distirên',
         'dengbêjlerin toplanıp sırayla söyledikleri yer', 3),
        ('Ciwan Haco', 'hunermendê ku bayê rock û caz anî muzîka kurdî',
         'Kürt müziğine rock ve caz rüzgârını getiren sanatçı', 3),
        ('Mihemed Şêxo', 'hunermendê ku bi tembûr û dengê xwe kilamên nûjen çêkir',
         'tembûr ve sesiyle modern kilamlar üreten sanatçı', 4),
        ('Aram Tîgran', 'muzîkjenê bi eslê xwe ermenî yê ku bi stranên kurdî tê naskirin',
         'Kürtçe şarkılarıyla tanınan, Ermeni kökenli müzisyen', 4),
        ('Şivan Perwer', 'stranbêjê ku stranên welatparêzî di sirgûnê de belav kir',
         'yurtseverlik şarkılarını sürgünde yayan şarkıcı', 3),
        ('muzîka şevbêrkê', 'awazên ku di civînên şevê yên zivistanê de tên gotin',
         'kış gecesi toplantılarında söylenen ezgiler', 4),
    ],
    'Paradigma': [
        ('dewlet-netewe', 'modela dewletê ya ku yek ziman û yek nasnameyê ferz dike',
         'tek dil ve tek kimlik dayatan devlet modeli', 3),
        ('şaristaniya dewletparêz', 'xeta dîrokî ya ku desthilat li dora dewletê kom dike',
         'iktidarı devletin çevresinde toplayan tarihsel çizgi', 4),
        ('pîşesazîparêzî', 'nêrîna ku pêşketinê tenê bi mezinbûna hilberînê pîvan dike',
         'gelişmeyi yalnızca üretim büyümesiyle ölçen yaklaşım', 4),
        ('akademiyên jinan', 'saziyên perwerdehiyê yên ku li ser azadiya jinê xebatê dikin',
         'kadın özgürlüğü üzerine çalışan eğitim kurumları', 3),
        ('milkiyeta komûnal', 'xwedîtiya hevpar a ku li ser hewcedariyê ava dibe ne li ser qezencê',
         'kâr üzerine değil ihtiyaç üzerine kurulu ortak mülkiyet', 4),
        ('veqetandina hêzan', 'parvekirina desthilatê di navbera qanûndanîn, rêveberî û dadgehê de',
         'iktidarın yasama, yürütme ve yargı arasında bölünmesi', 3),
        ('hişmendiya ekolojîk', 'zanîna ku mirov beşek ji xwezayê ye, ne xwediyê wê',
         'insanın doğanın sahibi değil parçası olduğu bilinci', 3),
        ('komîn', 'yekeya biçûk a xwerêveberiyê ya li tax an gundekî',
         'mahalle ya da köydeki küçük öz yönetim birimi', 3),
        ('xwerêveberî', 'birêvebirina karûbarên hevpar ji aliyê xelkê wê deverê ve',
         'ortak işlerin o yerin halkı tarafından yürütülmesi', 2),
        ('civaka bêhiyerarşî', 'civaka ku tê de çînên jor û jêr ên sabit tune ne',
         'sabit üst ve alt sınıfların bulunmadığı toplum', 4),
        ('pîvana azadiyê', 'ölçüya ku azadiya civakê bi azadiya jinê tê nirxandin',
         'toplumun özgürlüğünün kadının özgürlüğüyle ölçülmesi', 4),
        ('zayenda civakî', 'rolên ku civak li jin û mêran bar dike, ne yên xwezayî',
         'toplumun kadın ve erkeğe yüklediği, doğal olmayan roller', 4),
        ('civaka sivîl', 'komek saziyên ku ne dewlet in û ne jî bazar in',
         'ne devlet ne pazar olan kurumlar bütünü', 3),
        ('tekelparêzî', 'kombûna desthilat an sermayeyê di destê hindik kesan de',
         'iktidarın ya da sermayenin az sayıda elde toplanması', 4),
        ('politîkbûn', 'guhertina pirsgirêkeke rojane bo mijareke biryardanê ya hevpar',
         'gündelik bir sorunun ortak karar konusuna dönüşmesi', 5),
    ],
}


# Gövde kalıpları dönüşümlü kullanılır. Tek kalıp bankanın beşte birini
# geçince tur tekdüzeleşiyor ve `question_language_policy_test` içindeki
# şablon çeşitlilik bekçisi haklı olarak kırılıyor (2026-07-26). Kalıp,
# Rast ve Şaş sorularında aynı sırayla döndüğü için cevapla bağı yoktur.
TEMPLATES = [
    'Rast e an şaş e: Têgeha «%s» tê vê wateyê: %s.',
    'Têgeha «%s» wiha tê ravekirin: %s. Ev rast e an şaş e?',
    'Binirxîne: li gorî vê ravekirinê «%s» ev e — %s. Rast e an şaş e?',
    'Ev ravekirin ji bo «%s» rast e an şaş e: %s?',
]


def build(category, entries, prefix):
    rows = []
    count = len(entries)
    for index, (term, ku_def, tr_def, difficulty) in enumerate(entries):
        wrong_term, wrong_ku, wrong_tr, _ = entries[(index + 1) % count]
        rows.append({
            'id': 'offline_tf_%s_%04d' % (prefix, index * 2),
            'category': category,
            'prompt': TEMPLATES[index % len(TEMPLATES)] % (term, ku_def),
            'answers': ['Rast', 'Şaş'],
            'correctAnswer': 'Rast',
            'explanation': 'Erê, ev ravekirin bi rastî ya «%s» e.' % term,
            'explanationKu': 'Erê, ev ravekirin bi rastî ya «%s» e.' % term,
            'explanationTr': 'Evet, bu tanım gerçekten «%s» kavramına aittir.' % term,
            'type': 'trueFalse',
            'difficulty': difficulty,
        })
        rows.append({
            'id': 'offline_tf_%s_%04d' % (prefix, index * 2 + 1),
            'category': category,
            'prompt': TEMPLATES[index % len(TEMPLATES)] % (term, wrong_ku),
            'answers': ['Rast', 'Şaş'],
            'correctAnswer': 'Şaş',
            'explanation': 'Na — ev ravekirina «%s» e; «%s» tê vê wateyê: %s.'
                           % (wrong_term, term, ku_def),
            'explanationKu': 'Na — ev ravekirina «%s» e; «%s» tê vê wateyê: %s.'
                             % (wrong_term, term, ku_def),
            'explanationTr': 'Hayır — bu tanım «%s» kavramına ait; «%s» şu anlama gelir: %s.'
                             % (wrong_term, term, tr_def),
            'type': 'trueFalse',
            'difficulty': min(5, difficulty + 1),
        })
    return rows


PREFIX = {
    'Dîrok': 'dir',
    'Çand': 'can',
    'Edebiyat': 'ede',
    'Muzîk': 'muz',
    'Paradigma': 'par',
}


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    existing_ids = {row['id'] for row in rows}
    existing_prompts = {row['prompt'] for row in rows}

    added = []
    for category, entries in TERMS.items():
        added.extend(build(category, entries, PREFIX[category]))

    clashes = [r['id'] for r in added if r['id'] in existing_ids]
    dupes = [r['id'] for r in added if r['prompt'] in existing_prompts]
    if clashes or dupes:
        print('ID çakışması: %s' % clashes[:5])
        print('gövde yinelenmesi: %s' % dupes[:5])
        return 1

    rows.extend(added)
    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    print('eklenen soru: %d (%d terim)'
          % (len(added), sum(len(v) for v in TERMS.values())))
    return 0


if __name__ == '__main__':
    sys.exit(main())
