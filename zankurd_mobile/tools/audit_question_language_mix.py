#!/usr/bin/env python3
"""Soru bankasında dil karışıklığı ve etkin tekrar denetimi.

2026-07-22 canlı UX denetiminde, oynanan quizde soru gövdesi Kurmancî,
şıkların tamamı Türkçe olan sorulara rastlandı. Bu araç kapsamı ölçer ve
editöryel düzeltme için liste üretir.

Kullanım:
    python3 tools/audit_question_language_mix.py            # özet
    python3 tools/audit_question_language_mix.py --csv out.csv

Dart tarafındaki karşılığı: lib/src/services/question_language_policy.dart
(test/question_language_policy_test.dart sayının artmasını engeller).
"""
import argparse
import csv
import re
import sys
from collections import Counter

BANK = 'lib/src/data/offline_question_bank.dart'

# Ziman/Rêziman çeviri alıştırmalarıdır: gövde Kurmancî, şıklar Türkçe
# olması pedagojik olarak doğrudur.
TRANSLATION_CATEGORIES = {'Ziman', 'Rêziman'}
TRANSLATION_MARKERS = (
    'bi tirkî', 'bi kurmancî', 'bi kurdî', 'berambera',
    'wateya wê çi ye', 'tê çi wateyê', 'çi tê gotin', 'wergerîne',
)

KU_WORDS = {
    'di', 'bi', 'ku', 'ji', 'li', 'ye', 'ne', 'wê', 'tê', 'çi', 'yê', 'de',
    'her', 'bo', 'yek', 'ew', 'ev', 'bû', 'dike', 'nav', 'navê', 'kîjan',
    'çend', 'were', 'hat', 'hatiye', 'xwe', 'wek', 'jî', 'peyva', 'wateya',
}
TR_WORDS = {
    've', 'bir', 'ile', 'için', 'olan', 'bu', 'şu', 'daha', 'olarak', 'kim',
    'hangi', 'nedir', 'kimdir', 'yılında', 'tarafından', 'sonra', 'göre',
    'eden', 'edilen', 'yapılan', 'olduğu', 'değil', 'gibi', 'veya', 'olur',
}
KU_CHARS = set('îûê')
TR_CHARS = set('ğıöü')

QUESTION_RE = re.compile(
    r"QuizQuestion\(\s*id:\s*'([^']+)',\s*category:\s*'([^']+)',\s*"
    r"prompt:\s*'((?:[^'\\]|\\.)*)',\s*answers:\s*\[((?:[^\]\\]|\\.)*)\],\s*"
    r"correctAnswer:\s*'((?:[^'\\]|\\.)*)'"
)


def detect_language(text):
    low = text.lower()
    words = set(re.findall(r"[a-zçğıîöşûü']+", low))
    ku = len(words & KU_WORDS) + sum(1 for c in low if c in KU_CHARS) * 0.34
    tr = len(words & TR_WORDS) + sum(1 for c in low if c in TR_CHARS) * 0.34
    if ku == 0 and tr == 0:
        return None
    if ku >= tr * 1.5:
        return 'ku'
    if tr >= ku * 1.5:
        return 'tr'
    return None


def is_translation(category, prompt):
    if category in TRANSLATION_CATEGORIES:
        return True
    low = prompt.lower()
    return any(marker in low for marker in TRANSLATION_MARKERS)


def parse(path):
    src = open(path, encoding='utf-8').read()
    for qid, cat, prompt, answers_raw, correct in QUESTION_RE.findall(src):
        options = re.findall(r"'((?:[^'\\]|\\.)*)'", answers_raw)
        yield qid, cat, prompt, options, correct


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--bank', default=BANK)
    ap.add_argument('--csv', help='ihlal listesini CSV olarak yaz')
    args = ap.parse_args()

    rows = list(parse(args.bank))
    print(f'Ayrıştırılan soru: {len(rows)}')

    violations = []
    per_category = Counter()
    for qid, cat, prompt, options, correct in rows:
        if is_translation(cat, prompt):
            continue
        prompt_lang = detect_language(prompt)
        if prompt_lang is None:
            continue
        option_langs = [l for l in map(detect_language, options) if l]
        if not option_langs:
            continue
        conflicting = sum(1 for l in option_langs if l != prompt_lang)
        if conflicting >= max(2, len(option_langs) * 0.6):
            violations.append((qid, cat, prompt_lang, prompt, correct))
            per_category[cat] += 1

    print(f'\nDil karışıklığı: {len(violations)} soru '
          f'(%{len(violations) / max(1, len(rows)) * 100:.1f})')
    for cat, count in per_category.most_common():
        print(f'  {cat:12s} {count:4d}')

    # Aynı ipucu + aynı doğru cevap = farklı şablonla üretilmiş etkin tekrar.
    keyed = Counter()
    for qid, cat, prompt, options, correct in rows:
        quoted = re.findall(r"\\'([^\\]{6,})\\'", prompt)
        if quoted:
            keyed[(quoted[0], correct)] += 1
    duplicates = {k: c for k, c in keyed.items() if c > 1}
    print(f'\nEtkin tekrar (aynı ipucu + aynı cevap): {len(duplicates)} küme, '
          f'{sum(c - 1 for c in duplicates.values())} fazlalık soru')

    templates = Counter()
    for _, _, prompt, _, _ in rows:
        prefix = ' '.join(prompt.split()[:4])
        templates[prefix] += 1
    print('\nEn sık soru kalıpları:')
    for prefix, count in templates.most_common(5):
        print(f'  {count:5d}x {prefix!r}')

    if args.csv:
        with open(args.csv, 'w', newline='', encoding='utf-8') as fh:
            writer = csv.writer(fh)
            writer.writerow(['id', 'category', 'prompt_lang', 'prompt',
                             'correct_answer'])
            writer.writerows(violations)
        print(f'\nCSV yazıldı: {args.csv}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
