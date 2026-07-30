#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Soruyla aynı *türden* olmayan çeldiricileri değiştirir.

Ölçüm (2026-07-30): editoryal bankada on soruda doğru cevap, soruyu
yanıtlayan tek şıktı —

    Alfabeya latînî ya Kurmancî ji aliyê kê ve hat sîstematîzekirin?
      ✓ Celadet Alî Bedirxan        ← tek kişi adı
        cînavkên tewandî            ← gramer terimi
        daçekên hevedudanî          ← gramer terimi

    Mîrektiya Erdelan navenda xwe li ku derê bû?
      ✓ Sine (Sanandaj)             ← tek yer
        Rojnameya Kurdistan         ← gazete
        bihar / Adar                ← mevsim

Bu sorular hiçbir şey ölçmüyordu: Kurmancî okuyabilen ama konuyu hiç
bilmeyen biri "kim?" sorusunda tek kişi adını, "nerede?" sorusunda tek yeri
seçip kazanıyordu.

Mevcut bekçiler bunu göremez, çünkü hepsi *dil* ve *uzunluk* ölçüyor:
`offLanguageDistractors` dil farkına, `answerIsGivenAwayByLanguage` dilce
yalnız kalan şıkka, uzunluk mandalı da en uzun şıkka bakar. Buradaki fark
anlamsal — dördü de Kurmancî, dördü de benzer uzunlukta, ama üçü soruyu
yanıtlamıyor bile. Bu yüzden düzeltme elle doğrulanmış bir tabloyla yapılır;
sezgisel bir dedektör "Kesê ku karekî dike" gibi tanımları kişi adı sanıyor.

Yeni çeldiriciler **uydurulmaz**: hepsi bankada başka soruların doğru
cevabı olarak zaten geçen metinlerdir (`fix_offlanguage_distractors.py` ile
aynı yol). Böylece gerçek Kurmancî, doğru yazım ve aynı biçim garanti olur;
başka bir kavramı anlattıkları için bu soruda yanlıştırlar.

    python3 tool/fix_type_mismatched_distractors.py
"""

import json
import sys

BANK = 'assets/data/editorial_questions.json'
# Ödünç metin iki bankadan da alınabilir: ikisi de projenin denetlenmiş
# içeriği, özel adlar da bankalar arasında aynı imlayla yazılıyor.
SOURCE_BANKS = (BANK, 'assets/data/offline_questions.json')

# soru id → yeni çeldirici üçlüsü (doğru cevap değişmez).
# Her metin bankada başka bir sorunun doğru cevabıdır; araç bunu doğrular.
REPLACEMENTS = {
    # "kim?" → üç Kürt tarihî/edebî figürü
    'edit_ziman_0002': ['Ehmedê Xanî', 'Melayê Cizîrî', 'Şerefxanê Bidlîsî'],
    'edit_dirok_0033': ['Ehmedê Xanî', 'Şerefxanê Bidlîsî', 'Arabê Şamo'],
    # "nerede?" → üç yer
    'edit_dirok_0015': ['Kafkasya (Gence-Anî)', 'Amed û derdora wê', 'Sine (Sanandaj)'],
    'edit_dirok_0031': ['Amed û derdora wê', 'Silêmanî', 'Kafkasya (Gence-Anî)'],
    'edit_dirok_0026': ['Mezopotamyaya jorîn', 'Sine (Sanandaj)', 'Silêmanî'],
    'edit_siyaset_0014': ['Mezopotamyaya jorîn', 'Kafkasya (Gence-Anî)', 'Amed û derdora wê'],
    # "hangi ülkede?" → üç ülke
    'edit_sinema_0009': ['Îtalya', 'Koreya Başûr', 'Swêd'],
    # "kim?" ama cevap bir rol tanımı → üç rol tanımı
    'edit_edebiyat_0031': [
        'Kesê pîr ê bi rûmet ê ku pirsgirêkan çareser dike',
        'Kesa ku stranan dibêje',
        'Kesên ku bûkê ji mala wê tînin',
    ],
    # "neyle tanınır?" → üç müzikal rol tanımı
    'edit_muzik_0005': [
        'Dengbêjeke jin a navdar a sedsala 20em',
        'Stranbêjê devkî yê ku çîrokan bi kilaman dibêje',
        'Koma stranbêj û muzîkjenan',
    ],
    # İki çeldirici birbirinin sözcük sırası değiştirilmiş hâliydi
    # ('azadiya jinê, ekolojî û demokrasî' / 'demokrasî, azadiya jinê û
    # ekolojî') — fiilen aynı şık iki kez.
    'edit_paradigma_0019': [
        'Hilberîna hevpar li şûna kara kesane',
        'azadiya jinê, ekolojî û demokrasî',
        'Civaka ku bi nirx û biryardayîna hevpar tê birêvebirin',
    ],
}


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    by_id = {row['id']: row for row in rows}
    real_answers = set()
    for path in SOURCE_BANKS:
        for row in json.load(open(path, encoding='utf-8')):
            real_answers.add(row['correctAnswer'].strip())

    changed = 0
    for qid, distractors in REPLACEMENTS.items():
        row = by_id.get(qid)
        if row is None:
            print('atlandı (kayıt yok): %s' % qid)
            return 1

        correct = row['correctAnswer'].strip()
        borrowed = [d for d in distractors if d not in real_answers]
        if borrowed:
            print('atlandı (bankada geçmeyen metin): %s → %s' % (qid, borrowed))
            return 1
        if correct in distractors:
            print('atlandı (çeldirici doğru cevapla aynı): %s' % qid)
            return 1
        if len(set(distractors)) != len(distractors):
            print('atlandı (çeldiriciler kendi içinde tekrar): %s' % qid)
            return 1

        answers = sorted([correct] + distractors, key=lambda v: (len(v), v))
        row['answers'] = answers
        changed += 1

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    print('şık kümesi türüne göre onarılan: %d' % changed)
    return 0


if __name__ == '__main__':
    sys.exit(main())
