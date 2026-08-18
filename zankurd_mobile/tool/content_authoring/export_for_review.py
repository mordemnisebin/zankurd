#!/usr/bin/env python3
"""Bankayı dış denetime verilebilir belgelere çıkarır.

Tek dosya değil kategori başına dosya üretir: 3000+ soru tek belgede
sohbet penceresine sığmaz ve incelemeci ortada dikkatini kaybeder.

Her soru yargılanabilmesi için gereken HER ŞEYİ taşır — şıklar, doğru
cevap, açıklama, kaynak, zorluk ve hangi bankadan geldiği. Kaynağın
belirtilmesi önemli: incelemeci "bu yeni üretilmiş mi yoksa eski içerik mi"
ayrımını yapabilmeli.

Kullanım:
  python3 tool/content_authoring/export_for_review.py docs/content_batches/inceleme
"""
import json
import pathlib
import sys
from collections import defaultdict

BANKS = 'assets/data'


def main(out_dir: str) -> int:
    out = pathlib.Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    by_category = defaultdict(list)
    for path in sorted(pathlib.Path(BANKS).glob('*.json')):
        try:
            data = json.loads(path.read_text(encoding='utf-8'))
        except Exception:
            continue
        items = data if isinstance(data, list) else data.get('questions', [])
        if not isinstance(items, list):
            continue
        for question in items:
            if not isinstance(question, dict) or 'prompt' not in question:
                continue
            if not question.get('answers'):
                continue
            question['_kaynak'] = path.name.replace('_questions.json', '')
            by_category[question.get('category', '?')].append(question)

    total = 0
    for category, questions in sorted(by_category.items()):
        lines = [
            f'# {category} — {len(questions)} soru',
            '',
            'Her kayıt: soru (Kurmancî) / Türkçe karşılığı / şıklar / doğru cevap /',
            'açıklama / kaynak adresi / zorluk / hangi bankadan geldiği.',
            '',
        ]
        for question in questions:
            answers = question.get('answers', [])
            correct = question.get('correctAnswer', '')
            try:
                letter = 'ABCD'[answers.index(correct)]
            except ValueError:
                letter = '?'
            source = (question.get('metadata') or {}).get('sourceReference', '—')
            lines.append(f"## {question['id']}  ·  zorluk {question.get('difficulty','?')}  ·  {question['_kaynak']}")
            lines.append(f"**KU:** {question['prompt']}")
            if question.get('promptTr'):
                lines.append(f"**TR:** {question['promptTr']}")
            for index, answer in enumerate(answers):
                mark = '✅' if index < len(answers) and answer == correct else '  '
                lines.append(f"- {mark} {'ABCD'[index] if index < 4 else '?'}) {answer}")
            lines.append(f"**Doğru:** {letter}) {correct}")
            explanation = question.get('explanationTr') or question.get('explanation') or ''
            if explanation:
                lines.append(f"**Açıklama:** {explanation}")
            lines.append(f"**Kaynak:** {source}")
            lines.append('')
        target = out / f'{category}.md'
        target.write_text('\n'.join(lines), encoding='utf-8')
        size = target.stat().st_size // 1024
        print(f'{category:<12} {len(questions):5d} soru  {size:5d} KB  -> {target}')
        total += len(questions)
    print(f'\ntoplam {total} soru, {len(by_category)} dosya')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else 'docs/content_batches/inceleme'))
