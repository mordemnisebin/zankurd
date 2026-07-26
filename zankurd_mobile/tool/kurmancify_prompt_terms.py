# -*- coding: utf-8 -*-
"""Kurmancî soru gövdelerinin içinde kalan Türkçe terimleri Kurmancî'ye alır.

2026-07-26 canlı denetiminde simülatörde gelen soru:

    "Di çarçoveya muzîkê de mijareke bi navê 'dengbêjlik okulu' tune ye."

Cümle Kurmancî, tırnak içindeki terim Türkçe. Bu, sorunun tam ortasında dil
değiştirmek demek; ürünün birinci ölçütü olan "ilk kullanıcı kafası
karışmasın" ilkesini doğrudan bozuyor. 185 soruda, 101 benzersiz terimde
görüldü.

Terimler tırnak içinde göründüğü için gövdedeki tırnaklı biçim değiştirilir;
şıklar ve açıklamalar ayrı ele alınır (oralarda terim zaten hedef dildedir).
Özel adların Kurmancî imlası tercih edilir: 'Van gölü' → 'Gola Wanê'.
"""

import json
import re
import sys

BANK = 'assets/data/offline_questions.json'

TERMS = {
    # Erdnîgarî — cih navên
    'Ağrı dağı': 'Çiyayê Agirî',
    'Ağrı İsyanları': 'Serhildanên Agirî',
    'Bingöl dağları': 'Çiyayên Bîngolê',
    'Botan çayı': 'Çemê Botanê',
    'Derbendihan gölü': 'Gola Derbendîxanê',
    'Dicle bölümü': 'Beşa Dîcleyê',
    'Dokan gölü': 'Gola Dokanê',
    'Fırat nehri': 'Çemê Firatê',
    'Garzan çayı': 'Çemê Garzanê',
    'Habur çayı': 'Çemê Xabûrê',
    'Halgurd dağı': 'Çiyayê Halgurdê',
    'Hazar gölü': 'Gola Hazarê',
    'Hewler ovası': 'Deşta Hewlêrê',
    'Kandil dağları': 'Çiyayên Qendîlê',
    'Karacadağ': 'Karacadax',
    'Kürdistan iklimi': 'avhewaya Kurdistanê',
    'Munzur dağları': 'Çiyayên Mûnzûrê',
    'Muş ovası': 'Deşta Mûşê',
    'Siverek ovası': 'Deşta Sêwregê',
    'Süphan dağı': 'Çiyayê Sîpanê',
    'Tendürek dağı': 'Çiyayê Tendûrekê',
    'Urmiye gölü': 'Gola Ûrmiyeyê',
    'Van gölü': 'Gola Wanê',
    'Yukarı Fırat bölümü': 'Beşa Firata Jorîn',
    'Yüksekova': 'Colemêrg',
    'Zagros sıradağları': 'Rêzeçiyayên Zagrosê',
    'Şehrizor ovası': 'Deşta Şehrezorê',
    'Şengal dağı': 'Çiyayê Şengalê',
    'meşe ormanları': 'daristanên berû',

    # Dîrok
    'Baban Emirliği': 'Mîrgeha Babanê',
    'Bitlis Prensliği': 'Mîrgeha Bidlîsê',
    'Bohtan Emirliği': 'Mîrgeha Botan',
    'Halepçe katliamı': 'Komkujiya Helebceyê',
    'Kasr-ı Şirin Antlaşması': 'Peymana Qesrişîrînê',
    'Koçgiri İsyanı': 'Serhildana Koçgirî',
    'Kürdistan Eyaleti': 'Eyaleta Kurdistanê',
    'Kürdistan gazetesi': 'Rojnameya Kurdistan',
    'Kürt Teali Cemiyeti': 'Cemiyeta Tealiya Kurdan',
    'Lozan Antlaşması': 'Peymana Lozanê',
    'Med İmparatorluğu': 'Împaratoriya Medî',
    'Soran Emirliği': 'Mîrgeha Soran',
    'sözlü tarih': 'dîroka devkî',
    'Göç': 'Koçberî',
    'göç': 'koçberî',

    # Çand û muzîk
    'Aynur Doğan': 'Aynur Dogan',
    'Hawar Ekolü': 'Ekola Hawarê',
    'Kardeş Türküler': 'Kardeş Türküler',
    'govend müziği': 'muzîka govendê',
    'zaza müziği': 'muzîka kirmanckî',
    'şevbêrk müziği': 'muzîka şevbêrkê',
    'şakiro stranları': 'stranên Şakiro',
    'şabaş geleneği': 'kevneşopiya şabaşê',
    'ağıt': 'şînî',
    'günaydın/iyi günler': 'roj baş',
    'özür dilerim': 'bibore',

    # Siyaset û paradîgma
    'adil yargılanma': 'dadgehkirina dadperwer',
    'ahlaki güç': 'hêza exlaqî',
    'anadili hakkı': 'mafê zimanê zikmakî',
    'anadilinde eğitim': 'perwerdehiya bi zimanê zikmakî',
    'azınlık hakları': 'mafên hindikahiyan',
    'barış hakkı': 'mafê aştiyê',
    'barış süreci': 'pêvajoya aştiyê',
    'cinsiyet kotası': 'kotaya zayendî',
    'cinsiyet özgürlükçü': 'azadîxwaziya zayendî',
    'demokratik komünalizm': 'komunalîzma demokratîk',
    'demokratik uygarlık': 'şaristaniya demokratîk',
    'demokratik uzlaşı': 'lihevkirina demokratîk',
    'demokratik özerklik': 'xweseriya demokratîk',
    'devletçi uygarlık': 'şaristaniya dewletparêz',
    'doğrudan demokrasi': 'demokrasiya rasterast',
    'doğrudan katılım': 'beşdariya rasterast',
    'ekolojik endüstri': 'pîşesaziya ekolojîk',
    'endüstriyalizm': 'pîşesazîparêzî',
    'eş başkanlık': 'eşseroktî',
    'idari özerklik': 'xweseriya îdarî',
    'insan hakları': 'mafên mirovan',
    'kadın akademileri': 'akademiyên jinan',
    'kadın özgürlüğü': 'azadiya jinê',
    'katılımcı bütçe': 'budceya beşdarîxwaz',
    'komün': 'komîn',
    'komünal ekonomi': 'aboriya komûnal',
    'komünal mülkiyet': 'milkiyeta komûnal',
    'kuvvetler ayrılığı': 'veqetandina hêzan',
    'müzakere': 'danûstandin',
    'parti eş başkanlığı': 'eşseroktiya partiyê',
    'sivil katılım': 'beşdariya sivîl',
    'siyasi katılım': 'beşdariya siyasî',
    'siyasi özerklik': 'xweseriya siyasî',
    'sosyal sözleşme': 'peymana civakî',
    'statü hakkı': 'mafê statuyê',
    'statü talebi': 'daxwaza statuyê',
    'toplumsal barış': 'aştiya civakî',
    'toplumsal sözleşme': 'peymana civakî',
    'toplumsal uzlaşı': 'lihevkirina civakî',
    'yerel yönetim': 'rêveberiya herêmî',
    'yerel özerklik şartı': 'şerta xweseriya herêmî',
    'çoğulcu demokrasi': 'demokrasiya pirreng',
    'çoğulculuk': 'pirrengî',
    'öz savunma': 'parastina rewa',
    'özgürlük ölçütü': 'pîvana azadiyê',
    'özyönetim hakkı': 'mafê xwerêveberiyê',
}


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    changed = 0
    for row in rows:
        prompt = row['prompt']
        for turkish, kurmanci in TERMS.items():
            quoted = "'%s'" % turkish
            if quoted in prompt:
                prompt = prompt.replace(quoted, "'%s'" % kurmanci)
        if prompt != row['prompt']:
            row['prompt'] = prompt
            changed += 1

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    print('gövdesi Kurmancîleştirilen soru: %d' % changed)
    return 0


if __name__ == '__main__':
    sys.exit(main())
