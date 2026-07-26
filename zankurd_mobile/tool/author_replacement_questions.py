# -*- coding: utf-8 -*-
"""Çıkarılan kalıp sorular yerine gerçek bilgi soran sorular üretir.

`drop_polarity_questions.py` cevabı cümlenin olumsuzluğundan okunabilen 219
soruyu bankadan çıkardı. Terimler değerliydi, sorular değildi. Burada aynı
terimler için gerçek tanımlar yazılıyor ve bankada zaten kanıtlanmış olan
kalıp kullanılıyor:

    Rast e an şaş e: Têgeha «X» tê vê wateyê: <tanım>

Her terimden iki soru çıkar: biri doğru tanımla (Rast), biri **başka bir
terimin** tanımıyla (Şaş). Yanlış olan, olumsuzlaştırılmış bir cümle değil;
gerçek ama yanlış yere konmuş bir tanım — bu yüzden cevabı yalnız konuyu
bilen verir. Açıklama, yanlış tanımın gerçek sahibini de söyler; böylece
yanlış cevap da bir şey öğretir.

Türkçe terim etiketleri Kurmancî'ye alındı ('Cudi dağı' → 'Çiyayê Cûdî'):
Kurmancî bir cümlenin içinde Türkçe terim, 2026-07-26 canlı denetiminde
görülen ayrı bir kusurdu.
"""

import json
import sys

BANK = 'assets/data/offline_questions.json'

# (Kurmancî terim, Kurmancî tanım, Türkçe tanım, zorluk)
TERMS = {
    'Cografya': [
        ('Geliyê Botan', 'geliyê kûr ê ku çemê Botanê di nav zinaran de vekiriye û Cizîrê dorpêç dike',
         "Botan çayının kayalar arasında açtığı, Cizre'yi çevreleyen derin vadi", 3),
        ('Newal', 'geliyê teng û kûr ê ku av bi demê re di nav axê de vekiriye',
         'suyun zamanla toprakta açtığı dar ve derin vadi', 1),
        ('Çemê Garzanê', 'çemê ku ji çiyayên Sêrtê dadikeve û digihîje Dîcleyê',
         "Siirt dağlarından inip Dicle'ye kavuşan akarsu", 4),
        ('Av', 'hêmana bingehîn a ku jiyanê dide û şêwaza niştecihbûnê diyar dike',
         'yaşamı veren ve yerleşim biçimini belirleyen temel öge', 1),
        ('Avhewaya Kurdistanê', 'avhewaya parzemînî ya bi zivistanên sar û havînên hişk ku bi bilindahiyê ve diguhere',
         'yükseltiye göre değişen, kışı soğuk yazı kurak karasal iklim', 3),
        ('Colemêrg', 'bajarê çiyayî yê herî bilind ê herêmê ku bi zozan û geliyên xwe tê naskirin',
         'yayla ve vadileriyle bilinen, bölgenin en yüksek dağlık kenti', 2),
        ('Erd', 'rûyê axê yê ku çandinî, niştecihbûn û jiyana rojane li ser tê avakirin',
         'tarımın, yerleşimin ve gündelik yaşamın üzerine kurulduğu toprak yüzeyi', 1),
        ('Herêma Serhedê', 'herêma bilind a bakur ku Agirî, Wan û Muşê digire nav xwe',
         'Ağrı, Van ve Muş’u içine alan yüksek kuzey bölgesi', 3),
        ('Çiya', 'bilindahiya erdê ya ku avhewa, çandinî û rêyên veguhastinê diyar dike',
         'iklimi, tarımı ve ulaşım yollarını belirleyen yeryüzü yükseltisi', 1),
        ('Deşt', 'erdê rast û berdar ê ku çandinî lê hêsan e',
         'tarımın kolay olduğu düz ve verimli arazi', 1),
        ('Daristan', 'devera ku bi darên xurt hatiye nixumandin û avhewayê nerm dike',
         'gür ağaçlarla kaplı, iklimi yumuşatan alan', 1),
        ('Gol', 'ava sekinî ya ku li newalekê kom dibe û bi çeman tê xwedîkirin',
         'bir çukurda toplanan, akarsularla beslenen durgun su', 1),
        ('Hewa', 'rewşa atmosferê ya rojane ku baran, ba û germahiyê digire nav xwe',
         'yağmuru, rüzgârı ve sıcaklığı kapsayan günlük atmosfer durumu', 1),
        ('Sînor', 'xeta ku du waran an du welatan ji hev vediqetîne',
         'iki yeri ya da iki ülkeyi birbirinden ayıran çizgi', 1),
        ('Çemê Dîcleyê', 'çemê ku ji Amedê dest pê dike û bi Ferat re Mezopotamyayê xwedî dike',
         "Amed'den doğup Fırat ile Mezopotamya'yı besleyen nehir", 2),
        ('Çemê Araksê', 'çemê ku sînorê bakurê rojhilat ê herêmê pêk tîne û diherike Deryaya Xezerê',
         "bölgenin kuzeydoğu sınırını çizen ve Hazar'a dökülen nehir", 4),
        ('Çemê Xabûrê', 'çemê ku ji Botanê tê û li nêzîkî Zaxoyê digihîje Dîcleyê',
         "Botan'dan gelip Zaho yakınlarında Dicle'ye karışan çay", 4),
        ('Ava Zapê', 'ava hov a ku ji Colemêrgê dadikeve û enerjiya avî ya başûr xwedî dike',
         'Hakkâri’den inen, güneyin su enerjisini besleyen coşkun akarsu', 3),
        ('Deşta Amedê', 'deşta bazaltî ya berdar a ku li dora Amedê belav dibe',
         'Amed çevresine yayılan verimli bazalt ovası', 3),
        ('Deşta Hewlêrê', 'deşta fireh a başûr ku çandiniya genim lê serdest e',
         'buğday tarımının egemen olduğu geniş güney ovası', 4),
        ('Deşta Sêwregê', 'deşta ku di navbera Karacadaxê û Firatê de dirêj dibe',
         "Karacadağ ile Fırat arasında uzanan ova", 4),
        ('Karacadax', 'çiyayê volkanîk ê bazaltî yê ku deşta Amedê ji ya Rihayê vediqetîne',
         'Amed ovasını Urfa ovasından ayıran bazaltik volkanik dağ', 3),
        ('Çiyayên Bîngolê', 'rêzeçiyayên ku serekaniya gelek çeman in û bi zozanên xwe tên naskirin',
         'birçok nehrin kaynağı olan, yaylalarıyla bilinen sıradağlar', 3),
        ('Çiyayên Mûnzûrê', 'rêzeçiyayên Dêrsimê yên bi berf û parka neteweyî ya bi heman navî',
         'Dersim’in karlı sıradağları ve aynı adlı millî park', 3),
        ('Geliyê Mûnzûrê', 'geliyê kûr ê ku çemê Mûnzûrê di nav zinarên kilsî de vekiriye',
         'Munzur çayının kireç kayalarında açtığı derin vadi', 4),
        ('Çiyayê Tendûrekê', 'çiyayê volkanîk ê feal ê li navbera Agirî û Wanê',
         'Ağrı ile Van arasındaki aktif volkanik dağ', 4),
        ('Çiyayê Halgurdê', 'lûtkeya herî bilind a başûrê Kurdistanê li ser sînorê Îranê',
         "İran sınırındaki, Güney Kürdistan'ın en yüksek zirvesi", 5),
        ('Rêzeçiyayên Zagrosê', 'rêzeçiyayên mezin ên ku sînorê xwezayî yê welatê kurdan pêk tînin',
         'Kürtlerin ülkesinin doğal sınırını oluşturan büyük sıradağlar', 2),
        ('Gola Dokanê', 'bendava mezin a li ser Zapa Biçûk a ku Silêmaniyê bi av û elektrîkê xwedî dike',
         "Küçük Zap üzerinde, Süleymaniye'yi su ve elektrikle besleyen büyük baraj gölü", 5),
        ('Gola Derbendîxanê', 'bendava li ser çemê Sîrwanê ya ku deşta Germiyanê av dide',
         'Sirvan nehri üzerinde, Germiyan ovasını sulayan baraj', 5),
        ('Herêma Behdînan', 'herêma başûrê rojava ya bi navenda Dihokê ku bi zaravayê behdînî tê naskirin',
         'Duhok merkezli, behdinî lehçesiyle bilinen kuzeybatı bölgesi', 4),
        ('Avhewaya Deryaya Navîn', 'avhewaya bi zivistanên şil û havînên germ ku li başûrê rojava tê dîtin',
         'kışı yağışlı yazı sıcak olan, güneybatıda görülen iklim', 2),
    ],
    'Siyaset': [
        ('xweseriya îdarî', 'veguhastina hin desthilatên rêveberiyê ji navendê bo herêmê',
         'bazı yönetim yetkilerinin merkezden bölgeye devri', 3),
        ('mafê statuyê', 'daxwaza naskirina hiqûqî ya hebûna gelekî di nav dewletê de',
         'bir halkın devlet içindeki varlığının hukuken tanınması talebi', 4),
        ('pergala meclîsan', 'rêveberiya ku biryar tê de ji meclîsên gel derdikevin, ne ji yek desthilatê',
         'kararların tek bir iktidardan değil halk meclislerinden çıktığı yönetim', 3),
        ('demokrasiya temsîlî', 'rêveberiya ku tê de gel biryarê bi rêya nûnerên hilbijartî dide',
         'halkın kararı seçilmiş temsilciler eliyle verdiği yönetim', 2),
        ('demokrasiya radîkal', 'nêrîna ku beşdariya rasterast û berdewam a gel di biryaran de diparêze',
         'halkın kararlara doğrudan ve sürekli katılımını savunan yaklaşım', 4),
        ('siyaseta demokratîk', 'çareserkirina pirsgirêkên civakê bi nîqaş û lihevkirinê, ne bi zorê',
         'toplumun sorunlarını zorla değil tartışma ve uzlaşıyla çözme', 3),
        ('muxalefeta demokratîk', 'rexnekirina desthilatê di nav sînorên hiqûqî de bêyî çekan',
         'iktidarı silaha başvurmadan, hukuk içinde eleştirme', 3),
        ('muxalefeta civakî', 'nerazîbûna ku ji hêla komên civakî ve tê nîşandan, ne ji hêla partiyan ve',
         'partilerin değil toplumsal kesimlerin gösterdiği hoşnutsuzluk', 4),
        ('bêîtaetiya sivîl', 'redkirina eşkere û bêşiddet a qanûneke ku neheq tê dîtin',
         'haksız görülen bir yasanın açık ve şiddetsiz biçimde reddi', 4),
        ('mafên hindikahiyan', 'parastina ziman, ol û çanda komên hejmara wan kêm',
         'sayıca az olan grupların dil, din ve kültürünün korunması', 2),
        ('perwerdehiya bi zimanê zikmakî', 'mafê xwendinê bi zimanê ku zarok pê mezin bûye',
         'çocuğun büyüdüğü dilde okuma hakkı', 2),
        ('garantiya destûrî', 'girêdana mafekî bi destûra bingehîn da ku bi qanûneke asayî neyê rakirin',
         'bir hakkın sıradan yasayla kaldırılamaması için anayasaya bağlanması', 4),
        ('dadgehkirina dadperwer', 'mafê her kesî yê darizandina eşkere, bêalî û di demeke maqûl de',
         'herkesin açık, tarafsız ve makul sürede yargılanma hakkı', 3),
        ('kotaya zayendî', 'diyarkirina rêjeyeke herî kêm ji bo nûnertiya jinan di saziyan de',
         'kurumlarda kadın temsili için asgari bir oran belirlenmesi', 3),
        ('budceya beşdarîxwaz', 'diyarkirina xerckirina budceyê bi dengê rasterast ê niştecihan',
         'bütçe harcamasının sakinlerin doğrudan oyuyla belirlenmesi', 4),
        ('meclîsên herêmî', 'saziyên biryardar ên tax û gundan ên herî nêzî jiyana rojane',
         'gündelik yaşama en yakın karar organları: mahalle ve köy meclisleri', 3),
        ('vîna herêmî', 'biryardayîna li ser pirsên herêmê ji hêla xelkê wê herêmê ve',
         'bölgeye dair kararların o bölgenin halkınca verilmesi', 3),
        ('lihevkirina civakî', 'peymana bêyaz a ku komên cuda li ser jiyana hevpar digihîjin hev',
         'farklı kesimlerin ortak yaşam üzerinde vardığı yazısız uzlaşı', 4),
        ('aştiya civakî', 'rewşa ku tê de nakokî bi şîdetê nayên çareserkirin',
         'çatışmaların şiddetle çözülmediği toplumsal durum', 2),
        ('mafê aştiyê', 'mafê gelan ê jiyaneke bê şer û bê tirsa şîdetê', 
         'halkların savaşsız ve şiddet korkusuz yaşama hakkı', 3),
        ('exlaqê siyasî', 'pîvana ku desthilatdar li gorî berjewendiya civakê tevbigere, ne ya xwe',
         'iktidarın kendi çıkarına değil toplumun yararına davranma ölçüsü', 4),
        ('beşdariya siyasî', 'tevlîbûna hemwelatiyan a di biryar û çavdêriya rêveberiyê de',
         'yurttaşların karara ve yönetimin denetimine katılması', 2),
        ('hevpeymaniyên demokratîk', 'hevkariya hêzên cuda yên civakê li ser bernameyeke hevpar',
         'toplumun farklı güçlerinin ortak program üzerinde iş birliği', 4),
        ('mafên demokratîk', 'komek mafên wekî azadiya gotin, civîn û rêxistinbûnê',
         'ifade, toplanma ve örgütlenme özgürlüğü gibi haklar bütünü', 2),
        ('beşdariya rasterast', 'biryardayîna gel bi xwe, bêyî navbeynkariya nûneran',
         'halkın temsilci aracılığı olmadan doğrudan karar vermesi', 3),
        ('rêveberiya herêmî', 'saziya hilbijartî ya ku karûbarên bajêr an gund birêve dibe',
         'kentin ya da köyün işlerini yürüten seçilmiş kurum', 2),
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


def build(category, entries, start_index):
    rows = []
    count = len(entries)
    for index, (term, ku_def, tr_def, difficulty) in enumerate(entries):
        wrong_term, wrong_ku, wrong_tr, _ = entries[(index + 1) % count]
        prefix = 'offline_tf_%s_%04d' % (category[:3].lower(), start_index + index * 2)

        rows.append({
            'id': prefix,
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
            'id': 'offline_tf_%s_%04d' % (category[:3].lower(), start_index + index * 2 + 1),
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


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    existing = {row['id'] for row in rows}
    added = []
    for category, entries in TERMS.items():
        added.extend(build(category, entries, 1))

    clash = [row['id'] for row in added if row['id'] in existing]
    if clash:
        print('ID çakışması: %s' % clash[:5])
        return 1

    rows.extend(added)
    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    print('eklenen soru: %d' % len(added))
    return 0


if __name__ == '__main__':
    sys.exit(main())
