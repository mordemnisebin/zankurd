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

## 2026-10-02: tek havuz dengesi kategori başına dengeyi GARANTİ ETMEZ

Küresel yayılım 1 iken tek tek kategoriler kayabilir: toplam dengeliyken
bir kategori A'ya, bir başkası D'ye yığılabilir ve eksilikler birbirini
götürür. Bir denge denetimi kategori başına çarpıklık raporladı (Siyaset
4 şıklı sorularda doğru cevap A %55, Paradigma A %35 / D %15, Coğrafya A
%33, Edebiyat A %32, Sînema B %31). Ölçüm DEPOLANAN konumdu; oyuncunun
GÖRDÜĞÜ konum değil: `QuizQuestion.displayAnswers` şıkları kimlikten
türeyen sabit kaydırmayla döndürür ve o rapordaki yığılmaların çoğu
görünen sırada zaten dağılmıştı. Görünen sırada tek kategori dışı kalan
Edebiyat'tı (B %30, D %19). Araç artık ÖNCE her kategoriyi (görünen
sıraya göre) en çok 1 yayılıma getirir, SONRA küresel yayılımı ≤ 1'e
çeker; ikisi birlikte sağlanır. En az hareket ilkesi: bir soru yalnız
kategorisinin fazla olduğu konumdaysa taşınır.

Taşınmayan sorular: sayısal şık kümeleri (konum değerden çıkar), şıkları
birbirine gönderme yapan sorular ("Herdu jî", "Ti dewletê", "Hiçbiri"…
`is_order_dependent`) ve önek dışında kalanlar. Onlar sayılır, taşınmaz.
"""

import json
import re
import sys
import zlib

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


def is_numeric_option_set(answers):
    """Şıkların tamamı sayı mı? `QuizQuestion._numericValues` ile aynı kural.

    Sayısal şıklar 2026-08-24'ten beri döndürülmüyor, SIRALANIYOR (bkz.
    `displayAnswers`). Bu araç onları yeniden yerleştiremez: konumları
    değerin kendisinden çıkar. Denge kalan sorularla sağlanır.
    """
    for option in answers:
        trimmed = str(option).strip().replace('.', '')
        if not trimmed:
            return False
        try:
            float(trimmed)
        except ValueError:
            return False
    return True


def numeric_displayed_index(answers, correct, question_id):
    """Sayısal şıkta doğru cevabın SABİT gösterim konumu."""
    values = sorted(range(len(answers)),
                    key=lambda i: float(str(answers[i]).strip().replace('.', '')))
    ordered = [answers[i] for i in values]
    if offset(question_id, len(answers)) % 2 == 0:
        ordered = list(reversed(ordered))
    return ordered.index(correct)


# Şıkların birbirine gönderme yaptığı kalıplar: bunlar yerinden oynarsa soru
# anlamını yitirir ("Herdu jî" ancak iki şıkkın ardından anlamlıdır). Kısa
# şıklar (≤ 30 karakter) taranır; uzun cümlelerdeki "herdu jî" gibi
# geçişler başka bir şeye gönderme yapmaz.
_ORDER_DEPENDENT = re.compile(
    r'^(her\s*du(\s+\S+){0,2}|herdu\s+jî(\s+\S+){0,2}|her\s+s[êe]\s+jî.*|'
    r'hers[êe]\s+jî.*|hemû\s+yên\s+jorîn.*|(ti|tu)\s+yek\s+jî.*|'
    r'ti\s+dewlet\S*|hiç\s*biri.*|hiçbir\S*(\s+\S+)?|hepsi.*|'
    r'her\s+ikisi.*|ikisi\s+de.*|her\s+iki\s+\S+(\s+\S+)?|'
    r'ne\s+\S+\s+ne\s+\S+|(a|b|c|d)\s+(û|ve)\s+(a|b|c|d))$',
    re.IGNORECASE,
)


def is_order_dependent(answers, answers_tr=None):
    """Şıklardan biri başka şıklara mı gönderme yapıyor?"""
    for option in list(answers) + list(answers_tr or []):
        text = str(option).strip()
        if len(text) <= 30 and _ORDER_DEPENDENT.match(text):
            return True
    return False


def displayed_index(question_id, stored_index, length=4):
    return (stored_index - offset(question_id, length)) % length


class Entry:
    """Dengelemeye giren tek bir 4 şıklı soru."""

    def __init__(self, row, category, displayed, movable, playable=True):
        self.row = row
        self.category = category
        self.displayed = displayed
        self.movable = movable
        self.playable = playable


def place(entry, target):
    """Doğru cevabı GÖRÜNEN [target] konumuna taşır (answers + answersTr)."""
    row = entry.row
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
    entry.displayed = target


def spread(counts):
    return max(counts) - min(counts)


def load_playable(path, banks_ids):
    """`tool/parity/dump_local_bank_test.dart` çıktısından oynanabilir kimlikler.

    Dönen ikinci değer: bankalarda OLMAYAN (Dart sabitindeki "curated")
    oynanabilir 4 şıklı sorular — sayılır ama bu araç onları taşıyamaz.
    """
    dump = json.load(open(path, encoding='utf-8'))
    playable = {q['id'] for q in dump if q.get('playable')}
    external = [q for q in dump
                if q.get('playable') and q['id'] not in banks_ids
                and q.get('type') != 'trueFalse'
                and len(q.get('answers') or []) == 4
                and q.get('correctAnswer') in q['answers']]
    return playable, external


def main() -> int:
    """Kullanım: rebalance_answer_positions.py [önek] [--playable DOSYA]

    `--playable`: `flutter test tool/parity/dump_local_bank_test.dart`
    çıktısı. Verilirse OYNANABİLİR sorular ayrıca (kategori başına) dengelenir
    — oyuncunun gördüğü küme budur; emekli/gizli sorular ona dokunmadan
    dengeyi tamamlar. Verilmezse bütün sorular tek küme sayılır.
    """
    args = sys.argv[1:]
    playable_path = None
    if '--playable' in args:
        index = args.index('--playable')
        playable_path = args[index + 1]
        del args[index:index + 2]
    prefix = args[0] if args else ''
    banks = {path: json.load(open(path, encoding='utf-8'))
             for path in bank_paths()}
    bank_ids = {row['id'] for rows in banks.values() for row in rows}
    playable_ids, external = (
        load_playable(playable_path, bank_ids) if playable_path
        else (None, []))

    entries = []
    for rows in banks.values():
        for row in rows:
            answers = row.get('answers') or []
            if len(answers) != 4 or row.get('correctAnswer') not in answers:
                continue
            if row.get('type') in ('fillInBlank', 'wordOrdering'):
                continue
            stored = answers.index(row['correctAnswer'])
            if is_numeric_option_set(answers):
                # Konumu değer belirler; sayılır ama TAŞINMAZ.
                displayed = numeric_displayed_index(
                    answers, row['correctAnswer'], row['id'])
                movable = False
            else:
                displayed = displayed_index(row['id'], stored)
                movable = (row['id'].startswith(prefix) and
                           not is_order_dependent(answers,
                                                  row.get('answersTr')))
            playable = playable_ids is None or row['id'] in playable_ids
            entries.append(Entry(row, row.get('category', ''), displayed,
                                 movable, playable))
    for q in external:
        answers = q['answers']
        if is_numeric_option_set(answers):
            displayed = numeric_displayed_index(
                answers, q['correctAnswer'], q['id'])
        else:
            displayed = displayed_index(q['id'], answers.index(q['correctAnswer']))
        entries.append(Entry(q, q.get('category', ''), displayed, False, True))

    external_ids = {q['id'] for q in external}
    categories = sorted({e.category for e in entries})
    cat_all = {c: [0] * 4 for c in categories}
    cat_play = {c: [0] * 4 for c in categories}
    total = [0] * 4
    for e in entries:
        cat_all[e.category][e.displayed] += 1
        if e.playable:
            cat_play[e.category][e.displayed] += 1
        # Küresel denge (question_bank_test) yalnız bank dosyalarındaki
        # soruları sayar; dış (Dart sabiti) sorular dışarıda kalır.
        if e.row['id'] in external_ids:
            continue
        total[e.displayed] += 1
    before_total = list(total)
    before_all = {c: list(v) for c, v in cat_all.items()}
    before_play = {c: list(v) for c, v in cat_play.items()}

    moved_ids = set()

    def move(entry, target):
        moved_ids.add(entry.row['id'])
        cat_all[entry.category][entry.displayed] -= 1
        total[entry.displayed] -= 1
        if entry.playable:
            cat_play[entry.category][entry.displayed] -= 1
        place(entry, target)
        cat_all[entry.category][target] += 1
        total[target] += 1
        if entry.playable:
            cat_play[entry.category][target] += 1

    def movers(category, position, playable):
        # Kararlı ama dosyalara yayılan sıra (kimlik sırasına yığılmasın).
        pool = [e for e in entries
                if e.category == category and e.displayed == position
                and e.movable and e.playable == playable]
        return sorted(pool, key=lambda e: zlib.crc32(e.row['id'].encode()))

    def balance(category, counts, playable):
        """Kategoriyi [counts] (sayaç) üzerinden en çok 1 yayılıma getirir.

        Yalnız `e.playable == playable` olan satırlar taşınır: ilk geçişte
        oynanabilirler (sayaç = oynanabilir sayacı), ikinci geçişte kalanlar
        (sayaç = tüm sayacı) — ikincisi birinciyi bozmaz.
        """
        size = sum(counts)
        base, extra = divmod(size, 4)
        # Fazlalık hangi konumlarda kalsın: zaten en dolu olanlarda (en az
        # hareket); eşitlikte küresel olarak en boş olanlarda.
        ranked = sorted(range(4), key=lambda p: (-counts[p], total[p], p))
        quota = [base] * 4
        for p in ranked[:extra]:
            quota[p] += 1
        while True:
            over = [p for p in range(4)
                    if counts[p] > quota[p] and movers(category, p, playable)]
            under = [p for p in range(4) if counts[p] < quota[p]]
            if not over or not under:
                break
            src = max(over, key=lambda p: counts[p] - quota[p])
            dst = max(under, key=lambda p: quota[p] - counts[p])
            move(movers(category, src, playable)[0], dst)

    # Aşama 1: oynanabilir sorular kategori başına en çok 1 yayılıma.
    if playable_ids is not None:
        for category in categories:
            balance(category, cat_play[category], True)
    # Aşama 2: bütün sorular kategori başına; yalnız oynanabilir OLMAYANLAR
    # taşınır (verilmediyse hepsi "oynanabilir" sayılır ve bu geçiş boş).
    for category in categories:
        balance(category, cat_all[category], playable_ids is None)

    # Aşama 3: küresel yayılımı ≤ 1'e çek (`question_bank_test` yalnız bank
    # dosyalarını sayar; Dart sabitindeki dış sorular kategori sayacında var,
    # küresel sayaçta yok, bu yüzden kategoriler dengeliyken küresel yayılım
    # birkaç soru kayabilir). Kategori yayılımı 2'yi geçecek taşıma yapılmaz. Önce oynanabilir
    # OLMAYAN satırlar, olmazsa oynanabilirler (oynanabilir kategori dengesi
    # korunacak şekilde).
    guard = 0
    while spread(total) > 1 and guard < 10000:
        guard += 1
        hi = total.index(max(total))
        lo = total.index(min(total))
        best = None
        for playable in ([False, True] if playable_ids is not None
                         else [True]):
            for category in categories:
                counts = cat_all[category]
                if counts[hi] - counts[lo] < 0:
                    continue
                candidates = movers(category, hi, playable)
                if not candidates:
                    continue
                after = list(counts)
                after[hi] -= 1
                after[lo] += 1
                if spread(after) > max(2, spread(counts)):
                    continue
                if playable:
                    play = list(cat_play[category])
                    play[hi] -= 1
                    play[lo] += 1
                    if spread(play) > max(2, spread(cat_play[category])):
                        continue
                gain = counts[hi] - counts[lo]
                if best is None or gain > best[0]:
                    best = (gain, candidates[0])
            if best is not None:
                break
        if best is None:
            break
        move(best[1], lo)

    for path, rows in banks.items():
        with open(path, 'w', encoding='utf-8') as handle:
            json.dump(rows, handle, ensure_ascii=False, indent=2)
            handle.write('\n')

    def report(title, before, after):
        print(title)
        for category in categories:
            for label, counts in (('önce ', before[category]),
                                  ('sonra', after[category])):
                size = sum(counts)
                if not size:
                    continue
                print('  %-10s %s %-22s n=%3d yayılım %2d | %%: %s' % (
                    category, label, counts, size, spread(counts),
                    ' '.join('%4.1f' % (100 * c / size) for c in counts)))

    report('görünen konum, kategori başına, BÜTÜN sorular (A B C D):',
           before_all, cat_all)
    if playable_ids is not None:
        report('görünen konum, kategori başına, OYNANABİLİR sorular:',
               before_play, cat_play)
    print('önce : %s | yayılım %d' % (before_total, spread(before_total)))
    print('sonra: %s | yayılım %d' % (total, spread(total)))
    print('taşınan soru: %d / %d, banka: %d' % (
        len(moved_ids), len(entries), len(banks)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
