#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Soru bankalarında tırnak ve şık büyük/küçük harf birliğini kurar.

Ölçüm (2026-07-30): aynı bankada üç ayrı tırnak kuralı yan yana duruyordu —
«guillemet» 467, tek tırnak 575, çift tırnak 360 soruda. Oyuncu arka arkaya
iki soru çözünce alıntı işareti değişiyordu:

    Peyva «rast» bi Tirkî çi tê gotin?
    Wêneya 'Newroz' dikeve kîjan kategoriyê?
    Di wêneya ku têgiha "av" nîşan dide de, wateya rast kîjan e?

Ayrıca 326 soruda şık kümesi içinde büyük/küçük harf karışıktı
(«Yüz / sözcük / Duygu-his / gün-güneş»). Bu yalnız özensizlik değil:
tek başına büyük harfle başlayan şık göze çarpar, yani biçim ipucu verir.

Kesme işaretine DOKUNULMAZ. "Şakiro'nun", "Kurmancî'de", "ZanKurd'a"
gibi eklerdeki tek tırnak çift oluşturmaz; dönüşüm yalnız açılış-kapanış
çifti bulunan alıntılara uygulanır.

    python3 tool/normalize_question_typography.py [--apply]
"""

import json
import re
import sys

BANKS = [
    'assets/data/offline_questions.json',
    'assets/data/editorial_questions.json',
    'assets/data/community_questions.json',
    'assets/data/sentence_building_questions.json',
    'assets/data/fill_in_blank_2026_08_questions.json',
    'assets/data/expansion_2026_08_questions.json',
    'assets/data/source_first_2026_08_questions.json',
    'assets/data/visual_2026_08_07_questions.json',
    'assets/data/restore_2026_08_07_questions.json',
]

TEXT_FIELDS = ('prompt', 'promptTr', 'explanation', 'explanationKu', 'explanationTr')

# Açılış tırnağı: metin başı, boşluk veya açı-parantez sonrası.
# Kapanış: boşluk, noktalama ya da metin sonu öncesi.
# Bu iki koşul birlikte kesme işaretini dışarıda bırakır.
#
# 2026-07-30: bu kural 27 kaydı kaçırıyordu. Türkçede ek doğrudan kapanış
# tırnağına yapışır — "agir"dir, "Şivanê Kurmanca"yı, "-stan"dan — ve
# kapanıştan sonra harf gelince `(?![\w])` koşulu tutmuyordu. Çift tırnak
# için o koşul kaldırıldı: Türkçe kesme işareti olarak `"` kullanmaz, yani
# çift tırnak çifti her zaman alıntıdır. Tek tırnakta koşul yerinde kalır,
# yoksa "Şakiro'nun ... 'x'" gibi dizilerde kesme işareti alıntı sanılır.
QUOTED = re.compile(r"(?<![\w])'([^'\n]{1,70})'(?![\w])|(?<![\w])\"([^\"\n]{1,70})\"")


def to_guillemets(text):
    if not text:
        return text, 0
    count = 0

    def repl(match):
        nonlocal count
        count += 1
        return '«%s»' % (match.group(1) if match.group(1) is not None else match.group(2))

    return QUOTED.sub(repl, text), count


def option_case_fix(answers, correct):
    """Şık kümesini tek bir büyük/küçük harf kuralına çeker.

    Çoğunluk hangi biçimdeyse o kazanır; eşitlikte küçük harf seçilir
    (sözcük anlamı soran sorularda doğal biçim odur). Özel adlar korunur:
    ilk harften sonra da büyük harf taşıyan şık (ör. "ZanKurd", "Mem û Zîn")
    dokunulmadan bırakılır.
    """
    if len(answers) < 3:
        return answers, correct, 0
    movable = [a for a in answers if not re.search(r'[A-ZÇÊÎŞÛ]', a[1:])]
    if len(movable) < len(answers):
        return answers, correct, 0
    upper = sum(1 for a in answers if a[:1].isupper())
    if upper == 0 or upper == len(answers):
        return answers, correct, 0
    target_upper = upper > len(answers) / 2

    def apply(text):
        if not text:
            return text
        return text[0].upper() + text[1:] if target_upper else text[0].lower() + text[1:]

    new = [apply(a) for a in answers]
    return new, apply(correct), 1


def main() -> int:
    apply_changes = '--apply' in sys.argv
    total_quotes = total_case = 0
    samples = []

    for path in BANKS:
        try:
            rows = json.load(open(path, encoding='utf-8'))
        except FileNotFoundError:
            continue
        for row in rows:
            for field in TEXT_FIELDS:
                if field in row and isinstance(row[field], str):
                    new, n = to_guillemets(row[field])
                    if n:
                        total_quotes += n
                        if len(samples) < 4 and field == 'prompt':
                            samples.append((row['id'], row[field][:74], new[:74]))
                        row[field] = new
            # Şıklar da oyuncuya gösterilir ama TEXT_FIELDS onları kapsamıyordu;
            # 50 şıkta düz tırnak öyle kaldı ("Nû" + "roj", 'şahê dengbêjan').
            # `correctAnswer` şık metniyle eşleşerek puanlandığı için ikisi
            # BİRLİKTE dönüştürülür — yalnız birini çevirmek doğru cevabı
            # şıklardan koparır (2026-07-30).
            for field in ('answers', 'answersTr'):
                values = row.get(field)
                if not isinstance(values, list):
                    continue
                mapping = {}
                converted = []
                for value in values:
                    if not isinstance(value, str):
                        converted.append(value)
                        continue
                    new, n = to_guillemets(value)
                    if n:
                        total_quotes += n
                        mapping[value] = new
                    converted.append(new)
                row[field] = converted
                key = 'correctAnswer' if field == 'answers' else 'correctAnswerTr'
                if row.get(key) in mapping:
                    row[key] = mapping[row[key]]
            answers = row.get('answers')
            if isinstance(answers, list) and answers:
                fixed, correct, n = option_case_fix(answers, row.get('correctAnswer', ''))
                if n:
                    total_case += n
                    row['answers'] = fixed
                    row['correctAnswer'] = correct
        if apply_changes:
            with open(path, 'w', encoding='utf-8') as handle:
                json.dump(rows, handle, ensure_ascii=False, indent=2)
                handle.write('\n')

    print('tırnak dönüşümü: %d alıntı' % total_quotes)
    print('şık harf birliği: %d soru' % total_case)
    for qid, before, after in samples:
        print('  %s\n    önce: %s\n    sonra: %s' % (qid, before, after))
    print('UYGULANDI' if apply_changes else 'kuru koşu — değişiklik yazılmadı (--apply ile uygula)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
