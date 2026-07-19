# -*- coding: utf-8 -*-
"""zankurd_soru_bankasi_cevapli.csv veri hatalarını düzeltir.
- dogru_cevap metnine göre dogru_secenek harfini düzeltir (metin yoksa raporlar).
- Yinelenen seçenekleri raporlar (değiştirmez).
- Zorluk değerlerini Türkçe'ye normalize eder.
- Çıktıyı yeni dosyaya yazar, orijinale dokunmaz.
"""
import csv, io, json

SRC = "zankurd_soru_bankasi_cevapli.csv"
DST = "zankurd_soru_bankasi_cevapli_DUZELTILMIS.csv"
HARFLER = ["A", "B", "C", "D"]
SEC_COLS = ["secenek_a", "secenek_b", "secenek_c", "secenek_d"]
ZORLUK_MAP = {"easy": "Kolay", "medium": "Orta", "hard": "Zor"}

def norm(s):
    return (s or "").strip().lower()

with io.open(SRC, "r", encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f)
    rows = list(reader)
    fieldnames = reader.fieldnames

rapor = {"toplam": len(rows), "harf_duzeltilen": [], "eslesmeyen": [],
         "yinelenen": [], "zorluk_duzeltilen": []}

for i, r in enumerate(rows, start=2):  # header 1. satır
    satir_no = i
    sid = r.get("id", "?")

    # 1) dogru_secenek düzeltme
    dc = norm(r.get("dogru_cevap"))
    sec = [r.get(c, "") for c in SEC_COLS]
    sec_norm = [norm(x) for x in sec]
    eski = (r.get("dogru_secenek") or "").strip().upper()
    if dc and dc in sec_norm:
        yeni = HARFLER[sec_norm.index(dc)]
        if yeni != eski:
            rapor["harf_duzeltilen"].append(
                {"satir": satir_no, "id": sid, "eski": eski, "yeni": yeni})
            r["dogru_secenek"] = yeni
    else:
        rapor["eslesmeyen"].append(
            {"satir": satir_no, "id": sid,
             "dogru_secenek": eski, "dogru_cevap": r.get("dogru_cevap", "")})

    # 2) yinelenen seçenek tespiti (boş olmayanlar)
    dolu = [x for x in sec_norm if x]
    if len(dolu) != len(set(dolu)):
        rapor["yinelenen"].append(
            {"satir": satir_no, "id": sid,
             "secenekler": {HARFLER[j]: sec[j] for j in range(4)}})

    # 3) zorluk normalize
    z = norm(r.get("zorluk"))
    if z in ZORLUK_MAP:
        rapor["zorluk_duzeltilen"].append(
            {"satir": satir_no, "id": sid, "eski": r["zorluk"],
             "yeni": ZORLUK_MAP[z]})
        r["zorluk"] = ZORLUK_MAP[z]

with io.open(DST, "w", encoding="utf-8-sig", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(rows)

print(json.dumps(rapor, ensure_ascii=False, indent=2))
print(f"\nOK: {len(rows)} satır '{DST}' dosyasına yazıldı.")
