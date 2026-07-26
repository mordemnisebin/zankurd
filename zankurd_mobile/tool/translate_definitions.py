# -*- coding: utf-8 -*-
"""Türkçe açıklamaların gövdesini gerçekten Türkçeye çevirir.

`explanationTr` alanı 646 soruda doluydu ama 567'sinde çeviri sahteydi:
yalnız çerçeve Türkçeye alınmış, tanım Kurmancî bırakılmıştı —

    KU: «ergatîf» tê vê wateyê: avahiya rêzimanî ya ku kirdeya lêkerên …
    TR: «ergatîf» şu anlama gelir: avahiya rêzimanî ya ku kirdeya lêkerên …

Türkçe arayüzdeki oyuncu için bu, açıklamanın hiç olmamasından kötüdür:
çevrilmiş görünür ama okunamaz. Terim `«»` içinde Kurmancî kalır (öğretilen
şey odur), yalnız tanım çevrilir.

567 açıklamanın tamamı 80 benzersiz tanımdan üretilmiş; bu yüzden tek tek
soru değil, tanım sözlüğü çevrilir.
"""

import json
import re
import sys

BANK = 'assets/data/offline_questions.json'

DEFINITIONS = {
    "nivîskarê romana 'Şivanê Kurd' ku wekî romana yekem a kurdî tê qebûlkirin.":
        "ilk Kürtçe roman kabul edilen 'Şivanê Kurd'ün yazarı.",
    'helbestvanê şoreşger û civakî yê ku helbesta kurdî ya modern biriye qonaxeke nû.':
        'modern Kürt şiirini yeni bir aşamaya taşıyan devrimci ve toplumcu şair.',
    'destana neteweyî ya kurdî ya ku hîmê Mem û Zîna Xanî pêk tîne.':
        "Xanî'nin Mem û Zîn'inin temelini oluşturan Kürt ulusal destanı.",
    'xanedaniya kurdî ya serdema navîn ku navenda wê Amed û doralên wê bûn.':
        'merkezi Amed ve çevresi olan ortaçağ Kürt hanedanı.',
    "nivîskarê destana nemir a 'Mem û Zîn' ku hîmê ramanî yê kurdewariyê daniye.":
        "Kürtlük düşüncesinin temelini atan ölümsüz 'Mem û Zîn' destanının yazarı.",
    'têkiliya hevseng û dostane ya di navbera civakê û xwezayê de.':
        'toplum ile doğa arasındaki dengeli ve dostça ilişki.',
    "helbestvanê klasîk ê ku bi berhema 'Şêx Sen'an' û axaftina bi çûkan re navdar e.":
        "'Şêx Sen'an' eseri ve kuşlarla konuşmasıyla tanınan klasik şair.",
    'geliyê kûr û teng ê ku ava Zapê ya hov tê re diherike ber bi başûr ve.':
        'coşkun Zap suyunun güneye doğru aktığı derin ve dar vadi.',
    'şûna herî kevn a perestgehên mirovahiyê ku li nêzîkî bajarê Rihayê ye.':
        "Riha (Urfa) yakınlarındaki, insanlığın en eski tapınak yeri.",
    'gola herî mezin a herêmê ku avên wê şor û sodadar in.':
        'suları tuzlu ve sodalı olan, bölgenin en büyük gölü.',
    'dansa komî û gelêrî ya ku bi hevgirtina destan û bi rihê hevkariyê tê gerandin.':
        'el ele tutuşarak ve dayanışma ruhuyla oynanan toplu halk dansı.',
    'yek ji stûnên muzîka kurmancî ya klasîk ku kilamên devera Botan tomar kirine.':
        'Botan yöresinin kilamlarını kaydeden, klasik Kurmancî müziğinin direklerinden biri.',
    'rêbaza helbesta nûjen a bê pîvan û bê qafiye ku bi taybetî li ser peyvan ava dide.':
        'ölçüsüz ve kafiyesiz, ağırlığını sözcüğe veren modern şiir yöntemi.',
    'bajarê kevnar û dîrokî yê li ser çemê Dîcleyê ku xwedî şikeftên bêhempa ye.':
        'Dicle kıyısındaki, eşsiz mağaralarıyla bilinen kadim tarihî kent.',
    'zanistiya jinê ku bingeha azadiya civakê li ser azadiya jinê ava dike.':
        'toplumun özgürlüğünü kadının özgürlüğü üzerine kuran kadın bilimi.',
    'şano û lîstika gelêrî ya kurdî ku di dema sersalê de li gundan tê lîstin.':
        'yılbaşı döneminde köylerde oynanan Kürt halk oyunu ve tiyatrosu.',
    'koma yekem a muzîka rock a kurdî ya ku di salên 70an de derketibû holê.':
        "70'li yıllarda ortaya çıkan ilk Kürt rock grubu.",
    'modela birêvebirina civakê ya li derveyî sîstema dewlet-neteweyê.':
        'ulus-devlet sisteminin dışında bir toplum yönetimi modeli.',
    'weşana dîrokî ya kurdî ya serdema destpêka sedsala 20an ku li ser mafên neteweyî dinivîsî.':
        '20. yüzyıl başında ulusal haklar üzerine yazan tarihî Kürt yayını.',
    'romannivîsê kurd ê modern ku bi zimanekî kûr û edebî şoreşek di romana kurdî de çêkir.':
        'derin ve edebî diliyle Kürt romanında devrim yapan modern Kürt romancısı.',
    'helbestvanê ku Mewlûda Kurdî ya yekem bi zaravayê kurmancî nivîsiye.':
        'ilk Kürt Mevlidini Kurmancî lehçesinde yazan şair.',
    'helbestvanê mezin ê klasîk ku bi dîwana xwe ya felsefî û tesewifî tê naskirin.':
        'felsefî ve tasavvufî divanıyla tanınan büyük klasik şair.',
    'stranbêja yekem a kurd ku dengê xwe li ser plakan tomar kiriye.':
        'sesini plağa kaydeden ilk Kürt kadın şarkıcı.',
    'modela alternatîf a jiyanê ya li dijî kapîtalîzma modern.':
        'modern kapitalizme karşı alternatif yaşam modeli.',
    'mîrnişîna kurdî ya bihêz a ku navenda wê Cizîra Botan bû û xwedî serxwebûneke çandî bû.':
        'merkezi Cizîra Botan olan, kültürel bağımsızlığa sahip güçlü Kürt beyliği.',
    'mîrnişîneke kevnar a kurdî ya li rojhilat ku navenda wê Sine bû.':
        'merkezi Sine olan, doğudaki kadim bir Kürt beyliği.',
    'mîrê navdar ê Soran ku di sedsala 19an de hewl da yekîtiya kurdî ava bike.':
        '19. yüzyılda Kürt birliğini kurmaya çalışan ünlü Soran beyi.',
    'geliyê mezin ê ku çemê Dîcleyê tê re diherike û Amedê diparêze.':
        "Dicle'nin içinden aktığı, Amed'i koruyan büyük vadi.",
    'cejna neteweyî û sersala kurdî ya ku sembola serhildan, azadî û vejîna xwezayê ye.':
        'başkaldırının, özgürlüğün ve doğanın yeniden dirilişinin simgesi olan Kürt ulusal bayramı ve yılbaşı.',
    'peymana navdewletî ya sala 1923an ku Kurdistan li ser çar dewletan dabeş kir.':
        "Kürdistan'ı dört devlet arasında bölen 1923 tarihli uluslararası antlaşma.",
    'çiyayê volkanîk ê bazaltî ku deşta Amedê ji ya rihayê vediqetîne.':
        "Amed ovasını Riha ovasından ayıran bazaltik volkanik dağ.",
    'teoriya siyasî ya ku beşdariya rasterast a gel di biryaran de diparêze.':
        'kararlarda halkın doğrudan katılımını savunan siyasal teori.',
    'rojnameya yekem a kurdî ku di sala 1898an de li Qahîreyê ji aliyê Mîqdat Mîdhad Bedirxan ve hat weşandin.':
        "1898'de Kahire'de Mîqdat Mîdhad Bedirxan tarafından çıkarılan ilk Kürt gazetesi.",
    'kela parastina ziman û dîrokê ku bi riya stran û klamên dengbêjan tê meşandin.':
        'dengbêjlerin stran ve kilamlarıyla yürüyen, dili ve tarihi koruyan kale.',
    'serokê mezin ê kurd ku Quds ji xaçperestan rizgar kir û xanedaniya Eyûbiyan ava kir.':
        "Kudüs'ü Haçlılardan geri alan ve Eyyubi hanedanını kuran büyük Kürt önder.",
    'modela aboriyê ya ku li ser bingeha parvekirin û hewcedariyê ava bile ne li ser qezencê.':
        'kâr üzerine değil, paylaşım ve ihtiyaç üzerine kurulu ekonomi modeli.',
    'parvekirina desthilatê ji navendê ber bi herêm û rêveberiyên xweser ve.':
        'iktidarın merkezden bölgelere ve özerk yönetimlere dağıtılması.',
    'prensîba azadiya jin û mêr û wekheviya wan a di her qada jiyanê de.':
        'kadın ve erkeğin özgürlüğü ile yaşamın her alanında eşitliği ilkesi.',
    'amûra bayê ya çobanan ku bi dengê xwe yê xemgîn û lîrik tê naskirin.':
        'hüzünlü ve lirik sesiyle bilinen çoban üflemeli çalgısı.',
    'civaka azad a ku biryarên xwe bi hişmendiya exlakî û polîtîk dide.':
        'kararlarını ahlaki ve politik bilinçle veren özgür toplum.',
    "nîşanderên wekî 'ez, tu, ew, em, hûn, ew' ên ku bo kesan tên bikaranîn.":
        "kişiler için kullanılan 'ez, tu, ew, em, hûn, ew' gibi göstericiler.",
    "cînavkên wekî 'min, te, wî, wê, me, we, wan' ku di bin tewandinê de ne.":
        "büküm (tewandin) almış 'min, te, wî, wê, me, we, wan' gibi zamirler.",
    "peyvên wekî 'di... de, bi... re, ji... re' ku têkiliyên cih nîşan didin.":
        "yer ilişkilerini gösteren 'di... de, bi... re, ji... re' gibi sözcükler.",
    'avahiya lêkerê ya ku kiryarek di rabirdûyeke pir dûr de nîşan dide.':
        'çok uzak bir geçmişte olan eylemi gösteren fiil yapısı.',
    'şêwazê rêveberiyê ku tê de gel bêyî nûneran biryaran dide.':
        'halkın temsilciler olmadan karar verdiği yönetim biçimi.',
    'amûra lêdanê ya zildar ku di muzîka kurdî ya olî û gelêrî de xwedî cihekî girîng e.':
        'Kürt dinî ve halk müziğinde önemli yeri olan zilli vurmalı çalgı.',
    'avahiya rêzimanî ya ku kirdeya lêkerên gerguhêz di dema borî de tewandî nîşan dide.':
        'geçişli fiillerin öznesini geçmiş zamanda bükümlü gösteren dilbilgisi yapısı.',
    'têkiliya artêla mê (a) û nêr (ê) ya ku navdêran bi hev ve girê dide.':
        'adları birbirine bağlayan dişil (a) ve eril (ê) tamlama ilişkisi.',
    'sîstema hevseng a ku tê de jin û mêr bi hev re di hemû saziyan de seroktiyê dikin.':
        'kadın ve erkeğin tüm kurumlarda birlikte başkanlık ettiği dengeli sistem.',
    'têkiliya stratejîk a di navbera hêzên guhertinê yê civakê de.':
        'toplumun değişim güçleri arasındaki stratejik ilişki.',
    'çadira reş a ku ji mûyê bizinan tê çêkirin û koçeran ji germ û sermayê diparêze.':
        'keçi kılından dokunan, göçerleri sıcaktan ve soğuktan koruyan kara çadır.',
    'klamên evînê yên devera Serhadê ku bi taybetî ji aliyê jinan ve dihatin gotin.':
        'özellikle kadınların söylediği Serhat yöresi aşk kilamları.',
    'avahiya serdestiyê ya ku civakê dabeşî çînên jor û jêr dike.':
        'toplumu üst ve alt sınıflara bölen tahakküm yapısı.',
    'elhunera kevnar a jinên kurd ku motîfên li ser wan çîrokên dîrokî vedibêjin.':
        'motifleri tarihî hikâyeler anlatan, Kürt kadınlarının kadim el sanatı.',
    'avahiyên herî bingehîn ên xwe-rêveberiya gel li tax û gundan.':
        'mahalle ve köylerde halkın öz yönetiminin en temel yapıları.',
    'kovara edebî û çandî ya ku di sala 1932an de li Şamê bi destê Bedirxaniyan derketiye.':
        "1932'de Şam'da Bedirhanlar eliyle çıkan edebî ve kültürel dergi.",
    'şêwazê muzîka dengbêjiyê yê ku li ser lehengiya mêran û şeran tê gotin.':
        'erkeklerin kahramanlığı ve savaşlar üzerine söylenen dengbêjlik biçimi.',
    'lêkerên ku hewcedariya wan bi artêla tewandî heye bo temamkirina wateyê.':
        'anlamını tamamlamak için bükümlü nesneye ihtiyaç duyan fiiller.',
    'avahiya helbestî ya kilamên dengbêjiyê ku çîrokên evîn û şeran vedibêjin.':
        'aşk ve savaş hikâyelerini anlatan dengbêj kilamlarının şiirsel yapısı.',
    'têkiliya civakî ya ku tê de mêvan wekî bereketa malê tê qebûl kirin.':
        'konuğun evin bereketi sayıldığı toplumsal ilişki.',
    'mafê parastina xwezayî ya civakê li dijî êrîşên derveyî.':
        'toplumun dış saldırılara karşı doğal savunma hakkı.',
    "hêmanên wekî '-î, -ê, -an' ku di tewandina navdêran de cih digirin.":
        "adların bükümünde yer alan '-î, -ê, -an' gibi ekler.",
    'belgeya bingehîn a ku prensîbên jiyana hevbeş û azad a gelan diyar dike.':
        'halkların ortak ve özgür yaşam ilkelerini belirleyen temel belge.',
    'prensîba parastin û pejirandina hemû nasnameyên cuda yê di civakê de.':
        'toplumdaki bütün farklı kimliklerin korunması ve kabul edilmesi ilkesi.',
    'analîzkirin û hilweşandina sîstema serdest a mêr a li ser civakê.':
        'toplum üzerindeki erkek egemen sistemin çözümlenmesi ve yıkılması.',
    'pergala alfabeya kurdî ya bi tîpên latînî ku ji aliyê Celadet Bedirxan ve hatibû amadekirin.':
        "Celadet Bedirxan'ın hazırladığı Latin harfli Kürt alfabesi sistemi.",
    'amûra muzîkê ya herî pîroz û kevnar a kurdî ku bi taybetî di civatên olî de tê lêdan.':
        'özellikle dinî meclislerde çalınan, en kutsal ve kadim Kürt çalgısı.',
    'guhertina paşgira navdêr an cînavkan li gorî rola wan a di hevokê de.':
        'ad ya da zamirlerin cümledeki rolüne göre ek değiştirmesi.',
    'modela siyasî ya ku tê de gelên herêmê saziyên xwe bi xwe birêve dibin.':
        'bölge halklarının kendi kurumlarını kendilerinin yönettiği siyasal model.',
    'hişmendiya zanistî ya ku ji bin tekelên desthilatê derketiye û ji civakê re xizmet dike.':
        'iktidar tekellerinden çıkmış, topluma hizmet eden bilimsel bilinç.',
    'yek ji du çemên herî mezin ên Mezopotamyayê ku jiyanê dide axên berdar.':
        "Mezopotamya'nın en büyük iki nehrinden biri; verimli toprakların can damarı.",
    'çiyayê pîroz ê ku li gorî baweriyan keştiya Nûh Pêxember li ser rûniştiye.':
        "inanışa göre Nuh Peygamber'in gemisinin üzerine oturduğu kutsal dağ.",
    'çiyayê volkanîk ê bilind û berfîn ê li bakurê Gola Wanê.':
        "Van Gölü'nün kuzeyindeki yüksek ve karlı volkanik dağ.",
    'hêza mezin a antik a li çiyayên Zagrosê ku kurd xwe wekî neviyên wan dibînin.':
        "Kürtlerin kendilerini torunları saydığı, Zagros dağlarındaki büyük antik güç.",
    'şêwazê jiyana kevnar a li ser zozan û germiyanê ku çanda kurdî pir dewlemend kiriye.':
        'yayla ve germiyan arasındaki, Kürt kültürünü zenginleştiren kadim yaşam biçimi.',
    'rêzeçiyayên mezin û asê yên ku sînorê xwezayî yê welatê kurdan pêk tînin.':
        'Kürtlerin ülkesinin doğal sınırını oluşturan büyük ve sarp sıradağlar.',
    "dengbêjê mezin ê ku wekî 'Şahê Dengbêjan' tê naskirin û xwedî dengekî bêhempa bû.":
        "'Dengbêjlerin Şahı' diye bilinen, eşsiz sese sahip büyük dengbêj.",
    'pirtûka dîroka mîrgehên kurdî ku di sala 1597an de ji aliyê Şerefxanê Bedlîsî ve hatibû nivîsandin.':
        "1597'de Bitlisli Şerefhan tarafından yazılan Kürt beylikleri tarihi kitabı.",
    'civînên şevê yên zivistanê ku tê de çîrokên gelêrî û metelok dihatin gotin.':
        'halk masalları ve bilmecelerin anlatıldığı kış gecesi toplantıları.',
    'civînên şevê yên ku tê de helbest û çîrokên klasîk û modern dihatin xwendin.':
        'klasik ve modern şiir ile hikâyelerin okunduğu gece toplantıları.',
}


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    pattern = re.compile(r'(«[^«»]+» şu anlama gelir: )([^«»]+)')
    translated = 0
    missing = set()

    for row in rows:
        text = row.get('explanationTr')
        if not text:
            continue

        def replace(match):
            body = match.group(2).strip()
            turkish = DEFINITIONS.get(body)
            if turkish is None:
                missing.add(body)
                return match.group(0)
            return match.group(1) + turkish

        new_text = pattern.sub(replace, text)
        if new_text != text:
            row['explanationTr'] = new_text
            translated += 1

    if not missing:
        with open(BANK, 'w', encoding='utf-8') as handle:
            json.dump(rows, handle, ensure_ascii=False, indent=2)
            handle.write('\n')
    print('çevrilen açıklama: %d' % translated)
    for body in sorted(missing):
        print('  SÖZLÜKTE YOK | %s' % body)
    return 1 if missing else 0


if __name__ == '__main__':
    sys.exit(main())
