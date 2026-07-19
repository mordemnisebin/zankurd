import json, sys, time
sys.path.insert(0, '.')
from sb import query

blocks = json.load(open('blocks.json', encoding='utf-8'))
print('toplam blok:', len(blocks))
ok = 0
for i, b in enumerate(blocks):
    try:
        res = query(b)
        ok += 1
        print(f'blok {i+1}/{len(blocks)} OK', str(res)[:80])
    except Exception as e:
        print(f'blok {i+1} HATA:', e)
        try:
            print(e.read().decode()[:500])
        except Exception:
            pass
        break
print('basarili blok:', ok)
