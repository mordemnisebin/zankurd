# -*- coding: utf-8 -*-
"""Curated bankasının açıklamalarına Türkçe karşılık ekler.

2026-07-26 ekran turu: ders akışında doğru cevaptan sonra açılan
"Açıklama · Zana" paneli, arayüz Türkçeyken Kurmancî metin gösteriyordu.
`QuizQuestion.getLocalizedExplanation(false)` Türkçe alan yoksa ham metni
olduğu gibi döndürür — curated bankasının 45 sorusunun hiçbirinde o alan
yoktu. Öğrenme alanının bütün değeri o paneldedir; okunamayan açıklama
panelin hiç açılmamasından iyi değildir.

Kurmancî metinlerdeki yazım hataları da burada düzeltiliyor: "demorkratîk",
"Xebûna", "Çele.avê", "hate vedîtin" (keşfedildi — kastedilen "koça dawî
kir") gibi.
"""

import re
import sys

BANK = 'lib/src/data/curated_question_bank.dart'

# id: (düzeltilmiş Kurmancî, Türkçe)
EXPLANATIONS = {
    'curated_movement_0001': (
        '«Jiyan» bi Tirkî «yaşam» e. Di vê gotinê de sê têgeh — jin, jiyan û '
        'azadî — bi hev ve tên girêdan.',
        '«Jiyan» Türkçede «yaşam» demektir. Bu sözde üç kavram — kadın, yaşam '
        've özgürlük — birbirine bağlanır.',
    ),
    'curated_movement_0002': (
        '«Azadî» wateya azadiyê dide; peyv di slogan û gotûbêja mafan de gelek '
        'tê bikaranîn.',
        '«Azadî» özgürlük demektir; sözcük sloganlarda ve hak tartışmalarında '
        'sıkça kullanılır.',
    ),
    'curated_movement_0003': (
        'Jineolojî wek nêzîkatiyek ji bo xwendina jiyana jinan, civakê û '
        'têkiliyên hêzê tê pênasekirin.',
        'Jineolojî; kadınların yaşamını, toplumu ve güç ilişkilerini okumak '
        'için bir yaklaşım olarak tanımlanır.',
    ),
    'curated_movement_0004': (
        '«Meclîs» civîna hevbeş e. Di modelên xwe-rêxistinkirî de meclîs cihê '
        'gotûbêj û biryargirtinê ye.',
        '«Meclîs» ortak toplantı demektir. Öz örgütlü modellerde meclis, '
        'tartışma ve karar yeridir.',
    ),
    'curated_movement_0005': (
        '«Xwe-rêxistin» tê wateya ku kes û kom bi hevkarî kar û biryarên xwe '
        'bi xwe rêxistin dikin.',
        '«Xwe-rêxistin», kişi ve grupların işlerini ve kararlarını dayanışmayla '
        'kendilerinin örgütlemesidir.',
    ),
    'curated_movement_0006': (
        '«Berxwedan» di vê hevokê de wateya rawestan û li hember zordariyê '
        'ragirtinê dide.',
        '«Berxwedan» bu cümlede direnmek ve baskı karşısında ayakta kalmak '
        'anlamındadır.',
    ),
    'curated_movement_0007': (
        '«Serhildan» bi rabûn û tevgereke civakî ya li hember zordariyê re '
        'têkildar e; wateya wê li gorî kontekstê diguhere.',
        '«Serhildan», baskıya karşı ayaklanma ve toplumsal hareketle '
        'ilgilidir; anlamı bağlama göre değişir.',
    ),
    'curated_movement_0008': (
        'Agirê Newrozê di gelek vegotinên kurdan de bi ronahî, hêvî û vejîna '
        'nû re tê girêdan.',
        'Newroz ateşi birçok Kürt anlatısında ışıkla, umutla ve yeniden '
        'doğuşla ilişkilendirilir.',
    ),
    'curated_movement_0009': (
        'Newroz bi têgeha «roja nû» re tê şirovekirin û wek destpêka demsala '
        'biharê tê pîrozkirin.',
        'Newroz «yeni gün» kavramıyla açıklanır ve baharın başlangıcı olarak '
        'kutlanır.',
    ),
    'curated_movement_0010': (
        '«Rêxistin» wateya rêkxistinê û rêxistina kes an koman dide.',
        '«Rêxistin», düzenleme ve kişilerin ya da grupların örgütlenmesi '
        'anlamına gelir.',
    ),
    'curated_movement_0011': (
        'Ev têgeh bi meclîs, komîn, hevkarî û biryargirtina ji jêr ve tê '
        'şirovekirin.',
        'Bu kavram meclis, komün, dayanışma ve aşağıdan karar almayla '
        'açıklanır.',
    ),
    'curated_movement_0012': (
        'Di zimanê civakî de «dengê xwe bilind kirin» pir caran wateya '
        'axaftin û parastina maf û daxwazên xwe dide.',
        'Toplumsal dilde «sesini yükseltmek» çoğu zaman konuşmak ve kendi hak '
        've taleplerini savunmak demektir.',
    ),
    'curated_movement_0013': (
        'Ziman tenê amûra ragihandinê nîne; ew çîrok, bîranîn û awayê dîtina '
        'civakê jî hildigire.',
        'Dil yalnızca bir iletişim aracı değildir; hikâyeyi, hafızayı ve '
        'toplumun bakış biçimini de taşır.',
    ),
    'curated_movement_0014': (
        'Hevserokî berpirsiyariya rêveberiyê di navbera du kesan de parve '
        'dike; bi wekheviyê re tê girêdan.',
        'Eş başkanlık, yönetim sorumluluğunu iki kişi arasında paylaştırır ve '
        'eşitlikle ilişkilendirilir.',
    ),
    'curated_movement_0015': (
        'Xwe-rêxistin di cihên cuda de, di nav kom û civakan de bi awayên '
        'cuda tê bikaranîn.',
        'Öz örgütlenme; farklı yerlerde, farklı grup ve toplumlarda farklı '
        'biçimlerde uygulanır.',
    ),
    'curated_movement_0016': (
        'Berxwedan dikare zimanî, çandî, siyasî an civakî be; ew ne tenê bi '
        'awayekî tê pênasekirin.',
        'Direniş dilsel, kültürel, siyasal ya da toplumsal olabilir; tek bir '
        'biçimle tanımlanmaz.',
    ),
    'curated_movement_0017': (
        'Bîranîn û şahidî dikarin ezmûnên kesên ku di nivîsarên fermî de kêm '
        'tên dîtin nîşan bidin.',
        'Hafıza ve tanıklık, resmî metinlerde az görünen kişilerin '
        'deneyimlerini görünür kılabilir.',
    ),
    'curated_movement_0018': (
        '«Rojava» di Kurmancî de hem aliyê rojava hem navê herêmî yê Rojavayê '
        'Kurdistanê ye.',
        '«Rojava» Kurmancîde hem batı yönü hem de Batı Kürdistan’ın bölgesel '
        'adıdır.',
    ),
    'curated_movement_0019': (
        'Stran dikare bîranîn, hest û peyamên civakî bi awayekî dengdar û '
        'hevpar ragihîne.',
        'Şarkı; hafızayı, duyguyu ve toplumsal mesajı sesle ve ortaklaşa '
        'iletebilir.',
    ),
    'curated_movement_0020': (
        'Helbest dikare hest, bîranîn û daxwazên civakî bi zimanekî wêjeyî '
        'vebêje.',
        'Şiir; duyguyu, hafızayı ve toplumsal talebi edebî bir dille '
        'anlatabilir.',
    ),
    'curated_paradigma_0001': (
        'Jineolojî ji «jin» û «lojî» (zanist) pêk tê; zanistiya jinê û '
        'rêxistinkirina civaka azad e.',
        'Jineolojî «jin» (kadın) ve «loji» (bilim) sözcüklerinden oluşur; '
        'kadın bilimi ve özgür toplumun örgütlenmesidir.',
    ),
    'curated_paradigma_0002': (
        'Konfederalîzm modelek e ku rêxistinên herêmî yên xwe-bi-xwe li ser '
        'bingeha wekheviyê bi hev ve girê dide.',
        'Konfederalizm, yerel öz örgütlenmeleri eşitlik temelinde birbirine '
        'bağlayan bir modeldir.',
    ),
    'curated_paradigma_0003': (
        'Hevaltî endamên rêxistinê li ser bingeha wekheviyê digihîne hev, ne '
        'li ser serdestiyê.',
        'Yoldaşlık, örgüt üyelerini tahakküm üzerine değil eşitlik üzerine '
        'birleştirir.',
    ),
    'curated_paradigma_0004': (
        'Di konfederalîzma demokratîk de civak bi rêxistinên xwe-bi-xwe tê '
        'organîzekirin, ne bi dewletê.',
        'Demokratik konfederalizmde toplum devletle değil, öz örgütlenmelerle '
        'düzenlenir.',
    ),
    'curated_paradigma_0005': (
        'Paradîgmaya civaka demokratîk rêxistinên demokratîk û biryardana '
        'gelemperî digire nav xwe.',
        'Demokratik toplum paradigması, demokratik örgütlenmeleri ve ortak '
        'karar almayı kapsar.',
    ),
    'curated_paradigma_0006': (
        'Jineolojî li Rojavayê Kurdistanê bû pîvana azadiya jinê, ziman û '
        'rêxistinbûna wan.',
        'Jineolojî, Batı Kürdistan’da kadın özgürlüğünün, dilinin ve '
        'örgütlenmesinin ölçüsü hâline geldi.',
    ),
    'curated_paradigma_0007': (
        'Ekolojiya demokratîk dixwaze mirov bi xwezayê re lihevhatî bijî, ne '
        'bi serdestiyê.',
        'Demokratik ekoloji, insanın doğaya tahakküm etmeden onunla uyum '
        'içinde yaşamasını ister.',
    ),
    'curated_paradigma_0008': (
        'Biryarên civakî bi rêya lihevkirin û gotûbêjê tên girtin, ne bi '
        'ferzkirinê.',
        'Toplumsal kararlar dayatmayla değil, uzlaşı ve tartışmayla alınır.',
    ),
    'curated_paradigma_0009': (
        'Jinên di berxwedana Kobanê de bûne sembola gotina «jin, jiyan, '
        'azadî».',
        'Kobanê direnişindeki kadınlar «jin, jiyan, azadî» sözünün simgesi '
        'hâline geldi.',
    ),
    'curated_paradigma_0010': (
        'Sembol nîşana parastina jinê ye û azadî û cihgirtina wê ya civakî '
        'destnîşan dike.',
        'Simge, kadın savunmasının işaretidir ve kadının özgürlüğünü ile '
        'toplumsal yerini gösterir.',
    ),
    'curated_siyaset_0001': (
        'Komara Mehabadê (1946) li rojhilatê Kurdistanê yekem komara kurdî ye.',
        'Mehabad Cumhuriyeti (1946), Doğu Kürdistan’daki ilk Kürt '
        'cumhuriyetidir.',
    ),
    'curated_siyaset_0002': (
        'Qazî Mihemed (1893–1947) serokê Komara Mehabadê bû û piştî '
        'hilweşandina komarê hat îdamkirin.',
        'Qazî Mihemed (1893–1947) Mehabad Cumhuriyeti’nin lideriydi ve '
        'cumhuriyetin yıkılışından sonra idam edildi.',
    ),
    'curated_siyaset_0003': (
        'Peymana Sevrê (1920) ji kurdan re xweserî soz da, lê Peymana Lozanê '
        '(1923) ev soz betal kir.',
        'Sevr Antlaşması (1920) Kürtlere özerklik sözü verdi, ancak Lozan '
        'Antlaşması (1923) bu sözü geçersiz kıldı.',
    ),
    'curated_siyaset_0004': (
        'Di 1970î de li Iraqê ji bo Kurdistanê xweserî hat pejirandin; di '
        '1991ê de herêm bi rastî xwe bi xwe rêve bir.',
        '1970’te Irak’ta Kürdistan için özerklik kabul edildi; 1991’de bölge '
        'fiilen kendi kendini yönetmeye başladı.',
    ),
    'curated_siyaset_0005': (
        'Berxwedana Kobanê (2014–2015) di têkoşîna li dijî DAIŞê de roleke '
        'girîng lîst.',
        'Kobanê direnişi (2014–2015), IŞİD’e karşı mücadelede önemli bir rol '
        'oynadı.',
    ),
    'curated_siyaset_0006': (
        'Rêveberiya xweser a Rojava piştre wek konfederalîzmeke herêmî ya '
        'bakurê Sûriyê hat berfirehkirin.',
        'Rojava’daki özerk yönetim, sonradan Kuzey Suriye’nin bölgesel bir '
        'konfederalizmi olarak genişletildi.',
    ),
    'curated_siyaset_0007': (
        'Serhildana Şêx Seîd (1925) yek ji berxwedanên yekem ên girîng ên '
        'kurdan li Tirkiyeyê bû.',
        'Şeyh Said ayaklanması (1925), Kürtlerin Türkiye’deki ilk büyük '
        'direnişlerinden biriydi.',
    ),
    'curated_siyaset_0008': (
        'Peymana Lozanê (1923) soza Sevrê betal kir û axa kurdan di navbera '
        'çend dewletan de hat parvekirin.',
        'Lozan Antlaşması (1923) Sevr’in sözünü geçersiz kıldı ve Kürtlerin '
        'toprağı birkaç devlet arasında bölündü.',
    ),
    'curated_siyaset_0009': (
        'Mistefa Barzanî (1903–1979) rêberê tevgera neteweyî ya başûr bû û di '
        '1979ê de koça dawî kir.',
        'Mustafa Barzani (1903–1979) güneydeki ulusal hareketin önderiydi ve '
        '1979’da hayatını kaybetti.',
    ),
    'curated_siyaset_0010': (
        'Piştî 1991ê Hikûmeta Herêma Kurdistanê hat avakirin; ew yekem '
        'hikûmeta kurdî ya nûdem bû.',
        '1991’den sonra Kürdistan Bölgesel Hükümeti kuruldu; bu, modern '
        'dönemin ilk Kürt hükümetiydi.',
    ),
    'curated_muzik_0001': (
        'Dengbêj stran û çîrokên kevneşopî bi dengê xwe, bêyî amûrê vedibêje.',
        'Dengbêj, geleneksel şarkı ve hikâyeleri çalgı olmadan, yalnız sesiyle '
        'anlatır.',
    ),
    'curated_muzik_0002': (
        'Tembûr amûrek muzîkê ya kevneşopî ya têlî ye; li Kurdistanê û '
        'Rojhilata Navîn belav e.',
        'Tembûr geleneksel telli bir çalgıdır; Kürdistan’da ve Ortadoğu’da '
        'yaygındır.',
    ),
    'curated_muzik_0003': (
        'Govend reqsek komî ye: lîstikvan destên hev digirin û bi rêz li pey '
        'muzîkê dilîzin.',
        'Govend toplu bir danstır: oyuncular el ele tutuşur ve sıra hâlinde '
        'müziğe eşlik eder.',
    ),
    'curated_muzik_0004': (
        'Def/erbane amûrek lêdanê ya çermî ye ku bi dest tê lêxistin; di '
        'govend û şahiyan de belav e.',
        'Def/erbane elle çalınan derili bir vurmalı çalgıdır; halay ve '
        'şenliklerde yaygındır.',
    ),
    'curated_muzik_0005': (
        'Şivan Perwer stranbêjekî navdar ê kurd e; stranên wî li ser '
        'berxwedan, sirgûnî û bîranîna welêt in.',
        'Şivan Perwer tanınmış bir Kürt şarkıcıdır; şarkıları direniş, sürgün '
        've memleket hasreti üzerinedir.',
    ),
}


def dart_literal(text, indent):
    """Uzun metni Dart'ta okunur satırlara böler."""
    pad = ' ' * indent
    words = text.split(' ')
    lines, current = [], ''
    for word in words:
        candidate = word if not current else '%s %s' % (current, word)
        if len(candidate) > 66 and current:
            lines.append(current)
            current = word
        else:
            current = candidate
    if current:
        lines.append(current)
    # Boşluk tırnağın **içinde** olmalı: Dart bitişik dizgileri birleştirirken
    # aradaki beyaz boşluğu atar, bu yüzden dışarıda bırakılan boşluk kaybolur
    # ve "kadın,yaşam" gibi bitişik sözcükler oluşur (2026-07-26).
    return ('\n%s' % pad).join(
        "'%s%s'" % (
            line.replace("'", r"\'"),
            ' ' if index < len(lines) - 1 else '',
        )
        for index, line in enumerate(lines)
    )


def main() -> int:
    source = open(BANK, encoding='utf-8').read()
    added = 0

    for question_id, (kurmanci, turkish) in EXPLANATIONS.items():
        marker = "id: '%s'," % question_id
        start = source.find(marker)
        if start < 0:
            print('bulunamadı: %s' % question_id)
            return 1
        # Sorunun kapanışına kadar olan bloğun sonunu bul.
        end = source.find('\n  ),\n', start)
        block = source[start:end]
        if 'explanationTr:' in block:
            continue
        insertion = (
            "\n    explanationKu:\n        %s,\n    explanationTr:\n        %s,"
            % (dart_literal(kurmanci, 8), dart_literal(turkish, 8))
        )
        source = source[:end] + insertion + source[end:]
        added += 1

    open(BANK, 'w', encoding='utf-8').write(source)
    print('Türkçe açıklama eklenen soru: %d' % added)
    return 0


if __name__ == '__main__':
    sys.exit(main())
