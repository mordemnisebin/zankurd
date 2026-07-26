# -*- coding: utf-8 -*-
"""Doğru cevabın **ekranda görünen** konumunu banka genelinde dengeler.

Sabit konum ezberlenebilir bir desendir: oyuncu konuyu değil "cevap hep C"
kuralını öğrenir. `question_bank_test` bu yüzden dört konum arasındaki
yayılımın 1'i geçmemesini şart koşar.

İncelik: `QuizQuestion.displayAnswers` şıkları id'den türeyen sabit bir
kaydırmayla döndürür. Depolanan sıra ile görünen sıra farklıdır; dengeleme
görünen sıraya göre yapılmalıdır. Yeni soru eklendikten sonra çalıştırın.

    python3 tool/rebalance_answer_positions.py [id_öneki]
"""

import json
import sys

BANK = 'assets/data/offline_questions.json'


def offset(question_id, length=4):
    seed = sum(ord(ch) for ch in question_id)
    value = seed % length
    return 1 if value == 0 else value


def displayed_index(question_id, stored_index, length=4):
    return (stored_index - offset(question_id, length)) % length


def main() -> int:
    prefix = sys.argv[1] if len(sys.argv) > 1 else 'offline_tek_'
    rows = json.load(open(BANK, encoding='utf-8'))

    counts = [0, 0, 0, 0]
    movable = []
    for row in rows:
        if len(row['answers']) != 4:
            continue
        stored = row['answers'].index(row['correctAnswer'])
        counts[displayed_index(row['id'], stored)] += 1
        if row['id'].startswith(prefix):
            movable.append(row)

    for row in movable:
        stored = row['answers'].index(row['correctAnswer'])
        counts[displayed_index(row['id'], stored)] -= 1

    for row in movable:
        target = counts.index(min(counts))
        stored = (target + offset(row['id'])) % 4
        others = [a for a in row['answers'] if a != row['correctAnswer']]
        others.insert(stored, row['correctAnswer'])
        row['answers'] = others
        counts[target] += 1

    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')
    print('dağılım: %s | yayılım: %d' % (counts, max(counts) - min(counts)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
