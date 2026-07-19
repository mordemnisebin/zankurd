import json, sys
sys.path.insert(0, '.')
from sb import query

# TAM YEDEK: questions tablosu
rows = []
off = 0
while True:
    r = query(f"SELECT * FROM public.questions ORDER BY id LIMIT 5000 OFFSET {off}")
    rows += r
    if len(r) < 5000:
        break
    off += 5000
print("yedeklenen satir:", len(rows))
json.dump(rows, open('questions_backup_2026-07-19.json', 'w', encoding='utf-8'), ensure_ascii=False, default=str)
