# -*- coding: utf-8 -*-
"""Cevabı cümlenin olumluluk/olumsuzluğundan okunabilen doğru/yanlış
sorularını bankadan çıkarır.

2026-07-26 denetimi. 444 doğru/yanlış sorusunun 219'u tek bir üretim
kalıbından geliyordu: "X, <kategori> alanında geçerli bir terim mi?"

    'Cudi dağı' di çarçoveya erdnîgariyê de têgeheke derbasdar e.   → Rast
    'Zap suyu' bi tevahî li derveyî zanîna erdnîgariyê ye.          → Şaş

Terim ne olursa olsun cevap aynı yerden geliyor: cümle olumluysa Rast,
olumsuzsa Şaş. 219 sorunun 219'unda bu kural tutuyor — yani soru, konu
hakkında hiçbir şey bilmeyen birinin de %100 doğru cevaplayabileceği bir
dilbilgisi testi. Üstelik hiçbirinin açıklaması yok, çünkü açıklanacak bir
bilgi yok.

Bunlara açıklama yazmak kusuru gizlerdi: soru yine bilgi ölçmezdi, ama
ölçüyormuş gibi görünürdü. Bu yüzden siliniyorlar. Her kategori/zorluk
gözünde en az 30 soru kalıyor (bir tur 10 soru sorar), yani banka
kapasitesi bozulmuyor.

Yerlerine, aynı terimlerden gerçek bilgi soran sorular yazılıyor.
"""

import json
import sys

BANK = 'assets/data/offline_questions.json'

NEGATIVE = [
    'qet nayê bikaranîn',
    'bêwate',
    'tune ye',
    'li derveyî',
    'nayê zanîn',
    'têgeheke çêkirî',
    'yer almaz',
    'aîdî qadên derveyî',
    'nayê bikaranîn',
]

POSITIVE = [
    'têgeheke derbasdar',
    'yek ji mijaran e',
    'rast û naskirî',
    'sernavek rast',
    'watedar e',
    'gerçek bir terimdir',
    'bilinen bir konudur',
    'beşek ji zanîna',
    'têgeheke rast',
    'têgihek derbasdar',
]


def is_polarity_answerable(row) -> bool:
    """Cevap, gövdenin olumluluk/olumsuzluğundan okunabiliyor mu?"""
    if row.get('type') != 'trueFalse':
        return False
    prompt = row['prompt']
    negative = any(marker in prompt for marker in NEGATIVE)
    positive = any(marker in prompt for marker in POSITIVE)
    if negative == positive:
        return False
    correct = row['correctAnswer']
    return (positive and correct == 'Rast') or (negative and correct == 'Şaş')


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    kept = [row for row in rows if not is_polarity_answerable(row)]
    dropped = len(rows) - len(kept)

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(kept, handle, ensure_ascii=False, indent=2)
        handle.write('\n')

    print('çıkarılan soru: %d (%d → %d)' % (dropped, len(rows), len(kept)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
