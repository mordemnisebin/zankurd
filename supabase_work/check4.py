import json, sys
sys.path.insert(0, '.')
from sb import query
csvqs = json.load(open('csv_rows.json', encoding='utf-8'))
live = json.load(open('live_prompts.json', encoding='utf-8'))
lp = {r['prompt'].strip() for r in live}
p = next(c['soru'].strip() for c in csvqs if c['soru'].strip() in lp)
esc = p.replace("'", "''")
print(query("SELECT language_code, correct_option, explanation IS NOT NULL AS has_ex, source_url, review_status FROM public.questions WHERE prompt = '" + esc + "'"))
