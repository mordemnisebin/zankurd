# -*- coding: utf-8 -*-
"""Görsel kategori sorularına açıklama yazar.

"Wêneya 'Newroz' dikeve kîjan kategoriyê?" ailesi bankada açıklamasız kalan
son 20 soruydu. Soru zayıf ama meşru: görsel bir kavramı gösteriyor, oyuncu
onu doğru alana yerleştiriyor. Eksik olan, cevaptan sonra öğretilen şeydi —
kavramın *neden* o alana ait olduğu. Açıklama bunu söyler; böylece soru bir
sınıflandırma alıştırmasından bir bilgi anına döner.
"""

import json
import sys

BANK = 'assets/data/offline_questions.json'

# id: (Kurmancî açıklama, Türkçe açıklama)
EXPLANATIONS = {
    'offline_0379': ('Newroz cejna sersalê ye û bi agir, cil û govendê tê pîrozkirin — ji ber vê di qada çandê de tê nirxandin.',
                     'Newroz yılbaşı bayramıdır; ateş, giysi ve halayla kutlanır — bu yüzden kültür alanında değerlendirilir.'),
    'offline_0389': ('Dengbêj bi deng û bêyî amûrê çîrok û dîrokê vediguhezîne; ev kevneşopiya devkî beşek ji çandê ye.',
                     'Dengbêj sesle ve çalgısız hikâye ve tarih aktarır; bu sözlü gelenek kültürün parçasıdır.'),
    'offline_0399': ('Mêvanperwerî di civaka kurdî de qaîdeyeke exlaqî ye: mêvan bereketa malê tê hesibandin.',
                     'Misafirperverlik Kürt toplumunda ahlaki bir kuraldır: konuk evin bereketi sayılır.'),
    'offline_0404': ('Cilûbergên herêmî reng, motîf û awayê jiyana devera xwe hildigirin; ev jî nasnameya çandî ye.',
                     'Yöresel giysiler kendi bölgesinin rengini, motifini ve yaşam biçimini taşır; bu da kültürel kimliktir.'),
    'offline_0409': ('Şînî ji bo windahiyê tê gotin û êş bi awayekî hevpar tê parvekirin — rîtûeleke çandî ye.',
                     'Ağıt kayıp için söylenir ve acıyı ortaklaşa paylaştırır — kültürel bir ritüeldir.'),
    'offline_0414': ('Vegotina çîrokan zanîn û exlaqê nifşan bi rêya devkî diguhezîne; ev jî mîrateya çandî ye.',
                     'Hikâye anlatımı kuşakların bilgisini ve ahlakını sözlü yolla aktarır; bu da kültürel mirastır.'),
    'offline_0419': ('Pîrozkirina cejnê girêdanên civakî xurt dike û demê bi awayekî hevpar diyar dike.',
                     'Bayram kutlaması toplumsal bağları güçlendirir ve zamanı ortaklaşa anlamlandırır.'),
    'offline_0656': ('Helbest bi kêş, qafiye û wêneyên peyvan tê avakirin; ev şêwazên wêjeyî ne.',
                     'Şiir ölçü, kafiye ve söz imgeleriyle kurulur; bunlar edebî biçimlerdir.'),
    'offline_0659': ('Roman bi vegotineke dirêj kesayet û bûyeran pêş dixe — cureyeke wêjeyî ye.',
                     'Roman uzun bir anlatıyla kişileri ve olayları geliştirir — edebî bir türdür.'),
    'offline_0674': ('Kafiye dengên dawiya rêzan e ku helbestê rîtm û bîr dide; ev hêmaneke wêjeyî ye.',
                     'Kafiye, dizelerin sonundaki ses benzerliğidir; şiire ritim ve akılda kalıcılık verir.'),
    'offline_0677': ('Vebêj ew e ku çîrokê ji kê ve tê gotin diyar dike — têgeheke bingehîn a vegotinê ye.',
                     'Anlatıcı, hikâyenin kimin ağzından anlatıldığını belirler — temel bir anlatı kavramıdır.'),
    'offline_0871': ('Dengbêj bi awaz û kilaman dixebite; her çend çanda devkî be jî, cihê wî di muzîkê de ye.',
                     'Dengbêj ezgi ve kilamlarla çalışır; sözlü kültürden gelse de yeri müziktir.'),
    'offline_0875': ('Rîtm dema muzîkê par dike û govend û stranê li ser wê tê avakirin.',
                     'Ritim müziğin zamanını bölümler; halay ve şarkı onun üzerine kurulur.'),
    'offline_0883': ('Stran gotin û awazê digihîne hev; ev jî bingeha muzîkê ye.',
                     'Şarkı sözle ezgiyi birleştirir; bu da müziğin temelidir.'),
    'offline_0887': ('Def amûreke lêdanê ye ku rîtmê dide govend û dîlanê.',
                     'Def, halay ve düğüne ritmi veren vurmalı çalgıdır.'),
    'offline_0891': ('Erbane defa bi zengil e û di muzîka olî û gelêrî de tê lêxistin.',
                     'Erbane zilli def’tir; dinî ve halk müziğinde çalınır.'),
    'offline_0894': ('Tembûr amûra têlî ya kevnar e û bi taybetî di civatên olî de tê lêdan.',
                     'Tembûr kadim telli çalgıdır; özellikle dinî meclislerde çalınır.'),
    'offline_0898': ('Nota dengê muzîkê dinivîse; bêyî wê veguhastina awazê bi tenê li ser bîrê dimîne.',
                     'Nota müzik sesini yazıya geçirir; o olmadan ezginin aktarımı yalnız belleğe kalır.'),
    'offline_0902': ('Koro stranbêjiya bi kom e; deng li hev tên û yek deng çêdikin.',
                     'Koro topluca söylemektir; sesler birleşip tek bir ses kurar.'),
    'offline_0906': ('Solo stranbêjî an lêxistina bi tenê ye; berevajiyê koroyê ye.',
                     'Solo tek başına söylemek ya da çalmaktır; koronun karşıtıdır.'),
}


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    written = 0
    for row in rows:
        entry = EXPLANATIONS.get(row['id'])
        if entry is None:
            continue
        kurmanci, turkish = entry
        row['explanation'] = turkish
        row['explanationKu'] = kurmanci
        row['explanationTr'] = turkish
        written += 1

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    print('açıklama yazılan soru: %d' % written)
    return 0 if written == len(EXPLANATIONS) else 1


if __name__ == '__main__':
    sys.exit(main())
