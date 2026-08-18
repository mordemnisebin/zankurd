#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Kurmancî soruların tamamı Türkçe olan şık kümelerini iki dilli yapar.

Ölçüm (2026-07-30): altı soruda gövde Kurmancî, şıkların **dördü de**
Türkçeydi —

    'destmal' tê çi wateyê?
      ✓ halay başının elinde salladığı mendil
        Kürt halk müziğindeki ağıt ezgisi
        ...

Kurmancî turu oynayan oyuncu Kurmancî bir soru okuyup Türkçe dört şıkla
karşılaşıyordu. Bu kusur mevcut bekçilerden kaçıyordu, çünkü onlar
*uyumsuzluk* arıyor: `offLanguageDistractors` doğru cevaptan farklı dilde
şık arar, `answerIsGivenAwayByLanguage` dilce yalnız kalan şıkkı arar.
Dördü birden Türkçe olunca uyumsuzluk yok — küme tutarlı, ama yanlış dilde.

`offline_2009` gibi kayıtlar bilerek dışarıda: soru zaten "bi Tirkî çi ne?"
diye soruyor, Türkçe cevap orada doğru olanıdır.

Düzeltme: Kurmancî asıl olur, Türkçe küme `answersTr`/`correctAnswerTr`/
`promptTr` alanlarına taşınır — iki dil de kaybolmaz. Doğru cevabın
Kurmancîsi kaydın kendi `explanationKu` alanında zaten yazılıydı.
Çeldiriciler `fix_offlanguage_distractors.py` ile aynı yolla bulunur: aynı
kategorideki başka soruların doğru cevapları ödünç alınır. Onlar gerçek
Kurmancî, benzer uzunlukta ve aynı biçimdedir; başka bir kavramı
anlattıkları için bu soruda yanlıştır.

    python3 tool/fix_turkish_only_option_sets.py
"""

import json
import re
import sys

BANK = 'assets/data/offline_questions.json'

# Türkçede olup Hawar alfabesinde olmayan harfler.
TURKISH_ONLY = re.compile('[ığöüİĞÖÜ]')

# Doğru cevabın Kurmancîsi kaydın explanationKu alanındaki "term → tanım"
# kalıbından okunur; okunamayanlar burada elle verilir.
CORRECT_KU = {
    'offline_2241': 'korpusa axaftinê û pergala naskirina dengî ya kurdiya navîn',
}

# Gövdeler Kurmancî yazılmış ama Türkçe karşılıkları hiç yoktu; Türkçe tur
# Kurmancî soruyu okuyordu. Kümenin dilini düzeltirken bu da kapanır.
PROMPT_TR = {
    'offline_2241': 'Kürtçe konuşma tanıma çalışmalarında Jira projesi hangi alanda '
                    'örnek olarak gösterilir?',
    'offline_6083': "'destmal' ne anlama gelir?",
    'offline_6684': "'heftegiyan' ne anlama gelir?",
    'offline_6716': "'bêrîvan' teriminin doğru karşılığı hangisidir?",
    'offline_7474': "'dîroka devkî' teriminin doğru karşılığı hangisidir?",
    'offline_10962': "'stranên Şakiro' ne anlama gelir?",
}

TARGETS = [
    'offline_2241',
    'offline_6083',
    'offline_6684',
    'offline_6716',
    'offline_7474',
    'offline_10962',
]


def is_kurmanci(text):
    return not TURKISH_ONLY.search(text)


def correct_ku_for(row):
    if row['id'] in CORRECT_KU:
        return CORRECT_KU[row['id']]
    match = re.search(r'→\s*(.+?)\s*\.?$', (row.get('explanationKu') or '').strip())
    return match.group(1).strip().rstrip('.') if match else None


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    by_id = {row['id']: row for row in rows}

    # Kategori başına ödünç havuzu: gerçek Kurmancî doğru cevaplar.
    pool = {}
    for row in rows:
        answer = row['correctAnswer']
        if row['id'] in TARGETS or not is_kurmanci(answer):
            continue
        if len(answer) < 12 or answer in ('Rast', 'Şaş'):
            continue
        pool.setdefault(row['category'], []).append(answer)
    # Aynı metin birden çok soruda doğru cevap olabilir; havuzda tekilleştir,
    # yoksa aynı çeldirici bir soruya iki kez girer.
    pool = {category: list(set(options)) for category, options in pool.items()}
    for options in pool.values():
        # Deterministik sıra: uzunluk sonra alfabetik. Rastgelelik yok ki
        # araç iki kez koşunca aynı sonucu versin.
        options.sort(key=lambda value: (len(value), value))

    changed = 0
    for qid in TARGETS:
        row = by_id.get(qid)
        if row is None:
            print('atlandı (kayıt yok): %s' % qid)
            continue
        correct = correct_ku_for(row)
        if not correct:
            print('atlandı (Kurmancî cevap okunamadı): %s' % qid)
            continue

        turkish_answers = list(row['answers'])
        turkish_correct = row['correctAnswer']

        # Doğru cevap en uzun şık olmasın: ödünç çeldiricilerden en az biri
        # ondan uzun seçilir (banka bu ölçütte %25 bandında tutuluyor).
        candidates = [
            option for option in pool.get(row['category'], [])
            if option != correct and option not in turkish_answers
        ]
        longer = [option for option in candidates if len(option) > len(correct)]
        shorter = [option for option in candidates if len(option) <= len(correct)]
        if len(longer) < 1 or len(longer) + len(shorter) < 3:
            print('atlandı (havuz yetersiz): %s' % qid)
            continue
        borrowed = [longer[0]] + shorter[-2:] if len(shorter) >= 2 else longer[:3]

        kurmanci_answers = borrowed + [correct]
        kurmanci_answers.sort(key=lambda value: (len(value), value))

        row['answers'] = kurmanci_answers
        row['correctAnswer'] = correct
        row['answersTr'] = turkish_answers
        row['correctAnswerTr'] = turkish_correct
        prompt_tr = PROMPT_TR.get(qid)
        if not prompt_tr:
            print('atlandı (Türkçe gövde yok): %s' % qid)
            continue
        row['promptTr'] = prompt_tr
        row['explanation'] = row.get('explanationKu') or row['explanation']
        changed += 1

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    print('iki dilli yapılan: %d' % changed)
    return 0


if __name__ == '__main__':
    sys.exit(main())
