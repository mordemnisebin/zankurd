import json, sys
sys.path.insert(0, '.')
from sb import query
csvqs = json.load(open('csv_rows.json', encoding='utf-8'))
# Toplum ve Kimlik + Uygulama ve Eğitim örnekleri
for c in csvqs:
    if c['kategori'] in ('Toplum ve Kimlik', 'Uygulama ve Eğitim', 'Yemek ve Gündelik Yaşam'):
        print(c['id'], c['kategori'], '|', c['soru'][:80])
