import json, sys
sys.path.insert(0, '.')
from sb import query
cats = query("SELECT id, name FROM public.categories")
json.dump(cats, open('categories.json', 'w', encoding='utf-8'), ensure_ascii=False)
print(cats)
