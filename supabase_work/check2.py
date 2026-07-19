import json, csv, sys
sys.path.insert(0, '.')
from sb import query
csvqs = json.load(open('csv_rows.json', encoding='utf-8'))
from collections import Counter
print("CSV kategoriler:", Counter(c['kategori'] for c in csvqs))
print("CSV zorluk:", Counter(c['zorluk'] for c in csvqs))
print("live language_code:", query("SELECT language_code, count(*) FROM public.questions GROUP BY 1"))
print("live difficulty range:", query("SELECT min(difficulty), max(difficulty) FROM public.questions"))
print("question types:", query("SELECT question_type, count(*) FROM public.questions GROUP BY 1"))
# CSV ile eşleşen 10 canlı kaydın detayı
live = json.load(open('live_prompts.json', encoding='utf-8'))
match = [c['soru'].strip() for c in csvqs if c['soru'].strip() in {r['prompt'].strip() for r in live}]
