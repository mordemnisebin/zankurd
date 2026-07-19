# -*- coding: utf-8 -*-
"""Idempotent import SQL üretici: offline bank eksikleri + ZK CSV eksik/düzeltmeleri."""
import json, re

diff = json.load(open('diff.json', encoding='utf-8'))
csvqs = json.load(open('csv_rows.json', encoding='utf-8'))

CAT = {r['name']: r['id'] for r in json.load(open('categories.json', encoding='utf-8'))}
CSV_CAT = {
    'Coğrafya': 'Cografya', 'Tarih': 'Dîrok', 'Dil': 'Ziman',
    'Edebiyat ve Basın': 'Edebiyat', 'Sanat ve Kültür': 'Çand',
    'Yemek ve Gündelik Yaşam': 'Çand', 'Siyaset': 'Siyaset',
    'Paradigma': 'Paradigma', 'Toplum ve Kimlik': 'Siyaset',
    'Uygulama ve Eğitim': 'Teknolojî',
}
ZORLUK = {'Kolay': 1, 'Orta': 2, 'Zor': 3}
TYPE_MAP = {'multipleChoice': 'multiple_choice', 'trueFalse': 'true_false', 'visual': 'visual'}

def q(v):
    if v is None:
        return 'NULL'
    return "'" + str(v).replace("'", "''") + "'"

def letter(correct, answers):
    for i, a in enumerate(answers):
        if a.strip() == correct.strip():
            return chr(65 + i)
    return None

rows_offline = []
skipped = []
for item in diff['missing_offline']:
    t = TYPE_MAP.get(item['type'], 'multiple_choice')
    co = letter(item['correct'], item['answers'])
    if co is None:
        skipped.append(('offline', item['id'], 'correctAnswer eslesmedi'))
        continue
    a = item['answers']
    if t == 'true_false':
        opts = (a[0] if len(a) > 0 else 'Rast', a[1] if len(a) > 1 else 'Şaş', '-', '-')
    else:
        if len(a) != 4:
            skipped.append(('offline', item['id'], f'secenek sayisi {len(a)}'))
            continue
        opts = tuple(a)
    # şablon açıklama yasağı
    ex = item['explanation'] or ''
    if re.match(r"^'.*' kavramı hakkında .* bağlamında bilgi edindirme amaçlanmıştır\.$", ex.strip()):
        skipped.append(('offline', item['id'], 'sablon aciklama'))
        continue
    rows_offline.append(dict(
        category_id=CAT[item['category']], prompt=item['prompt'],
        option_a=opts[0], option_b=opts[1], option_c=opts[2], option_d=opts[3],
        correct_option=co, explanation=ex or None, difficulty=item['difficulty'],
        question_type=t, image_url=item['image'],
        source_url='zankurd_offline_curated_2026_07_19',
        source_reference=item['id']))

rows_csv = []
for c in csvqs:
    if c['id'] not in diff['csv_missing']:
        continue
    co = c['dogru_secenek'].strip()
    opts = (c['secenek_a'], c['secenek_b'], c['secenek_c'], c['secenek_d'])
    if opts[ord(co) - 65].strip() != c['dogru_cevap'].strip():
        skipped.append(('csv', c['id'], 'dogru_cevap harfle uyusmuyor'))
        continue
    rows_csv.append(dict(
        category_id=CAT[CSV_CAT[c['kategori']]], prompt=c['soru'],
        option_a=opts[0], option_b=opts[1], option_c=opts[2], option_d=opts[3],
        correct_option=co, explanation=c['aciklama'] or None,
        difficulty=ZORLUK[c['zorluk']], question_type='multiple_choice',
        image_url=None, source_url='zankurd_zk_csv_duzeltilmis_2026_07_19',
        source_reference=c['id']))

COLS = ('category_id, language_code, prompt, option_a, option_b, option_c, option_d, '
        'correct_option, explanation, explanation_ku, explanation_tr, difficulty, '
        'is_approved, question_type, image_url, source_url, source_reference')

def val_row(r):
    return ('(' + q(r['category_id']) + '::uuid, ' + q('ku-kmr') + ', ' + q(r['prompt']) + ', '
            + q(r['option_a']) + ', ' + q(r['option_b']) + ', ' + q(r['option_c']) + ', '
            + q(r['option_d']) + ', ' + q(r['correct_option']) + ', ' + q(r['explanation'])
            + ', NULL, NULL, ' + str(r['difficulty']) + ', true, ' + q(r['question_type'])
            + ', ' + q(r['image_url']) + ', ' + q(r['source_url']) + ', ' + q(r['source_reference']) + ')')

def insert_block(name, rows):
    out = []
    for i in range(0, len(rows), 100):
        chunk = rows[i:i+100]
        vals = ',\n    '.join(val_row(r) for r in chunk)
        out.append(
f"""WITH new_rows({COLS}) AS (
  VALUES
    {vals}
)
INSERT INTO public.questions({COLS})
SELECT n.*
FROM new_rows n
WHERE NOT EXISTS (
  SELECT 1 FROM public.questions q
  WHERE q.prompt = n.prompt AND q.category_id = n.category_id
);
""")
    return out

blocks = []
blocks += insert_block('offline', rows_offline)
blocks += insert_block('csv', rows_csv)

# C düzeltmeleri: canlıda olan 4 ZK sorusunun cevap harfleri
updates = []
fix_ids = [m[0] for m in diff['csv_mismatch']]
for c in csvqs:
    if c['id'] not in fix_ids:
        continue
    co = c['dogru_secenek'].strip()
    opts = (c['secenek_a'], c['secenek_b'], c['secenek_c'], c['secenek_d'])
    if opts[ord(co) - 65].strip() != c['dogru_cevap'].strip():
        skipped.append(('csv-fix', c['id'], 'dogru_cevap harfle uyusmuyor'))
        continue
    updates.append(
f"""UPDATE public.questions
SET option_a = {q(opts[0])}, option_b = {q(opts[1])}, option_c = {q(opts[2])}, option_d = {q(opts[3])},
    correct_option = {q(co)}, explanation = {q(c['aciklama'])}, updated_at = now()
WHERE prompt = {q(c['soru'])} AND correct_option <> {q(co)};
""")

header = f"""-- ZanKurd soru aktarımı 2026-07-19
-- Kaynak 1: offline_question_bank.dart eksikleri ({len(rows_offline)} kayıt)
-- Kaynak 2: zankurd_soru_bankasi_cevapli_DUZELTILMIS.csv eksikleri ({len(rows_csv)} kayıt)
-- Düzeltme: canlıda yanlış cevap harfi taşıyan ZK soruları ({len(updates)} kayıt)
-- Idempotent: prompt+category_id NOT EXISTS kontrolü ile; tekrar çalıştırılabilir.
-- DELETE/DROP içermez.
"""
sql = header + '\n'.join(blocks) + '\n' + '\n'.join(updates)
open(r'C:\Users\AMARGİ\Desktop\pirs kurmanci\supabase_import_2026-07-19.sql', 'w', encoding='utf-8').write(sql)
print('offline eklenecek:', len(rows_offline))
print('csv eklenecek:', len(rows_csv))
print('update:', len(updates))
print('atlanan:', len(skipped))
for s in skipped[:20]:
    print(' ', s)
json.dump(blocks + updates, open('blocks.json', 'w', encoding='utf-8'), ensure_ascii=False)
