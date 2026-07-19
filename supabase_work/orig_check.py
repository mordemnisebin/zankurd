import json, csv
live = json.load(open('live_prompts.json', encoding='utf-8'))
lp = {r['prompt'].strip(): r['correct_option'] for r in live}
orig = list(csv.DictReader(open(r"C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_soru_bankasi_cevapli.csv", encoding='utf-8-sig')))
m = [c for c in orig if c['soru'].strip() in lp]
print("orijinal CSV prompt canlida:", len(m))
mm = []
for c in m:
    if c['dogru_secenek'].strip() != lp[c['soru'].strip()]:
        mm.append((c['id'], c['dogru_secenek'], lp[c['soru'].strip()]))
print("orijinal ile cevap uyusmayan:", len(mm), mm[:12])
