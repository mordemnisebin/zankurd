#!/usr/bin/env python3
"""Türkçe metni eksik soruların kimlik listesini yazar (yalnız repo verisi).

Niçin (2026-11-01): çevrimiçi (oda/düello) sorular sunucudan yalnız Kurmancî
`prompt` ile gelir; `questions` tablosunda Türkçe metin sütunu yoktur. Türkçe
arayüzde bunlar Kurmancî görünür (istemci küçük bir "Kurmancî" etiketi koyar).
Bu betik CANLI VERİTABANINA BAĞLANMAZ ve ÇEVİRİ ÜRETMEZ: paketli banka
(`assets/data/*.json`) içinde `promptTr`si boş olan ya da Türkçe şık kümesi
tutarsız olan sorulara bakar ve her birinin yerel ile sunucu (uuid5) kimliğini
listeler. Sunucuda yalnız bulunan eski tohum satırlar repoda yoktur; onların
dökümü için `tool/sync_local_parity_to_server.py` akışındaki salt okunur
SELECT gerekir.

Kullanım: python3 tool/tr_eksik_listele.py [çıktı_yolu]
"""
import glob
import json
import os
import sys
import uuid

NAMESPACE = uuid.UUID("5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.path.expanduser("~/Projects/zankurd_kapisma/kalanlar/tr_eksik.txt")
)


def blank(value):
    return value is None or not str(value).strip()


def questions():
    for path in sorted(glob.glob(os.path.join(ROOT, "assets", "data", "*.json"))):
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, ValueError):
            continue
        if isinstance(data, dict):
            for key in ("questions", "items"):
                if isinstance(data.get(key), list):
                    data = data[key]
                    break
        if not isinstance(data, list):
            continue
        for q in data:
            if isinstance(q, dict) and "id" in q and "prompt" in q:
                yield os.path.basename(path), q


def reasons(q):
    out = []
    if blank(q.get("promptTr")):
        out.append("promptTr boş")
    answers = q.get("answers") or []
    answers_tr = q.get("answersTr")
    if q.get("type", "multipleChoice") in ("multipleChoice", "trueFalse", "visual"):
        if not isinstance(answers_tr, list) or len(answers_tr) != len(answers):
            out.append("answersTr eksik/uzunluk farklı")
        elif any(blank(a) for a in answers_tr):
            out.append("answersTr boş şık")
        elif blank(q.get("correctAnswerTr")) or str(
            q["correctAnswerTr"]
        ).strip() not in [str(a).strip() for a in answers_tr]:
            out.append("correctAnswerTr şıklarda yok")
    return out


def main():
    total = 0
    rows = []
    for fname, q in questions():
        total += 1
        why = reasons(q)
        if why:
            sid = uuid.uuid5(NAMESPACE, "zankurd-local:" + str(q["id"]))
            rows.append((str(q["id"]), str(sid), fname, "; ".join(why)))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("# Türkçe metni eksik sorular (yalnız repo verisi; canlı DB'ye bakılmadı)\n")
        f.write(f"# Taranan paketli soru: {total}; eksik: {len(rows)}\n")
        f.write(
            "# Not: sunucudaki `questions` tablosunda Türkçe metin sütunu YOK; "
            "çevrimiçi sorular\n# Türkçe arayüzde Kurmancî görünür (istemci "
            "'Kurmancî' etiketi koyar). Bu liste yalnız\n# paketli bankadaki "
            "eksikleri sayar; sunucuya özgü eski tohum satırlar repoda yoktur.\n"
        )
        f.write("# yerel_id\tsunucu_uuid5\tdosya\tneden\n")
        for row in rows:
            f.write("\t".join(row) + "\n")
    print(f"taranan {total}, eksik {len(rows)} -> {OUT}")


main()
