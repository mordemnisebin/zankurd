# -*- coding: utf-8 -*-
"""Doğru cevabın **ekranda görünen** konumunu bütün bankalarda dengeler.

Sabit konum ezberlenebilir bir desendir: oyuncu konuyu değil "cevap hep C"
kuralını öğrenir. `question_bank_test` bu yüzden dört konum arasındaki
yayılımın 1'i geçmemesini şart koşar.

İncelik: `QuizQuestion.displayAnswers` şıkları id'den türeyen sabit bir
kaydırmayla döndürür. Depolanan sıra ile görünen sıra farklıdır; dengeleme
görünen sıraya göre yapılmalıdır. Yeni soru eklendikten sonra çalıştırın.

    python3 tool/rebalance_answer_positions.py            # bütün bankalar
    python3 tool/rebalance_answer_positions.py offline_   # yalnız bir önek

## 2026-08-01: araç TEK bankaya bakıyordu

`BANK` sabiti `assets/data/offline_questions.json`a çakılıydı ve
`question_bank_test`teki denge bekçisi de yalnız `offlineQuestionBank`
üzerinde koşuyordu. Uygulama ise dört banka yüklüyor. Ölçüm:

    offline    [221, 221, 221, 221]   yayılım 0    ← araç + bekçi burada
    editorial  [  5,  76,  70, 130]   yayılım 125  ← ikisi de görmüyordu
    community  [  0,  11,  12,  23]   yayılım 23   ← ikisi de görmüyordu

Editoryal sorularda hep D'ye basan oyuncu %46 doğru yapıyordu; topluluk
sorularında A hiçbir zaman doğru değildi. Koruma vardı, kapsamı eksikti.

Banka listesi artık `lib/src/data/question_bank_assets.dart`ten okunuyor
ve dengeleme HEPSİ ÜZERİNDE, tek havuz olarak yapılıyor — oyuncunun
gördüğü akış zaten karışık.
"""

import json
import re
import sys

ASSETS = 'lib/src/data/question_bank_assets.dart'


def bank_paths():
    """Uygulamanın yüklediği banka yolları — tek kaynaktan."""
    source = open(ASSETS, encoding='utf-8').read()
    # Karakter kümesi DAR tutulmamalı. `[a-z_]+` yazılmıştı ve adında rakam
    # geçen `expansion_2026_08_questions.json` sessizce dışarıda kaldı
    # (2026-08-06): araç paylaşılan listeyi doğru okuyordu ama okuduğunu
    # kendi deseniyle süzüyordu, yani 2026-08-01'deki "araç bütün bankaları
    # görmüyor" kusuru bir katman aşağıda geri gelmişti.
    paths = re.findall(r"'(assets/data/[^']+\.json)'", source)
    # Sessiz eksilme bu aracın bilinen kusuru; sayı tutmuyorsa gürültü çıkar.
    declared = source.count("'assets/data/")
    if len(paths) != declared:
        raise SystemExit(
            'banka yolu ayrıştırma eksik: %d/%d' % (len(paths), declared))
    return paths


def offset(question_id, length=4):
    seed = sum(ord(ch) for ch in question_id)
    value = seed % length
    return 1 if value == 0 else value


def displayed_index(question_id, stored_index, length=4):
    return (stored_index - offset(question_id, length)) % length


def main() -> int:
    prefix = sys.argv[1] if len(sys.argv) > 1 else ''
    banks = {path: json.load(open(path, encoding='utf-8'))
             for path in bank_paths()}

    counts = [0, 0, 0, 0]
    movable = []
    for rows in banks.values():
        for row in rows:
            answers = row.get('answers') or []
            if len(answers) != 4 or row.get('correctAnswer') not in answers:
                continue
            stored = answers.index(row['correctAnswer'])
            counts[displayed_index(row['id'], stored)] += 1
            if row['id'].startswith(prefix):
                movable.append(row)

    before = list(counts)
    for row in movable:
        stored = row['answers'].index(row['correctAnswer'])
        counts[displayed_index(row['id'], stored)] -= 1

    for row in movable:
        target = counts.index(min(counts))
        stored = (target + offset(row['id'])) % 4
        # Şıkları DEĞERLE değil İNDEKSLE taşı: aynı devrişimi `answersTr`ye
        # de uygulayabilelim diye. İki dilli bankalarda yalnız `answers`
        # yeniden sıralanırsa Türkçe oynayan oyuncunun gördüğü sıra
        # dengelemenin dışında kalır — bu bekçi tam da onu engellemek için
        # var (2026-08-06, expansion_2026_08 bankası eklendiğinde).
        answers = row['answers']
        correct = answers.index(row['correctAnswer'])
        order = [i for i in range(len(answers)) if i != correct]
        order.insert(stored, correct)
        row['answers'] = [answers[i] for i in order]
        answers_tr = row.get('answersTr')
        if isinstance(answers_tr, list) and len(answers_tr) == len(answers):
            row['answersTr'] = [answers_tr[i] for i in order]
        counts[target] += 1

    for path, rows in banks.items():
        with open(path, 'w', encoding='utf-8') as handle:
            json.dump(rows, handle, ensure_ascii=False, indent=2)
            handle.write('\n')

    print('önce : %s | yayılım %d' % (before, max(before) - min(before)))
    print('sonra: %s | yayılım %d' % (counts, max(counts) - min(counts)))
    print('taşınan soru: %d, banka: %d' % (len(movable), len(banks)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
