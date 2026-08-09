#!/usr/bin/env python3
"""Türkçe kapsamı genişletmesi için çeviri partilerini hazırlar.

Niçin doğru cevap ajandan İSTENMİYOR
------------------------------------
Bir çeviri ajanına "şıkları çevir ve doğru cevabı da çevir" demek, iki ayrı
üretimin birbiriyle tutmasını ummaktır. Tutmazsa (`correctAnswerTr`
`answersTr` içinde yoksa) model bunu `_hasConsistentTurkishAnswers` ile
yakalayıp bütün soruyu Kurmancî'ye düşürür — yani emek çöpe gider; daha
kötüsü tutuyormuş gibi görünüp YANLIŞ şıkkı işaretleyebilir.

Bu yüzden ajandan yalnız `answersTr` isteniyor ve **sırası korunuyor**.
`correctAnswerTr` burada, `answers.index(correctAnswer)` indeksinden
türetiliyor. Böylece "yanlış şık doğru işaretlendi" hata sınıfı üretim
zincirinden tamamen çıkar; kalan tek risk sözcük seçimidir.

Tip bazında ayrım
-----------------
- `trueFalse`  : şıklar Rast/Şaş — deterministik eşlenir, ajana gitmez.
- `wordOrdering`: `answers` şık değil KELİME HAVUZU'dur ve Kurmancî cümle
                  kurma alıştırmasının kendisidir. Çevrilirse soru yok olur;
                  yalnız soru metni çevrilir.
- diğerleri    : soru metni + şıklar ajana gider.
"""
from __future__ import annotations
import json, os, re

BANKS = [
    "assets/data/sentence_building_questions.json",
    "assets/data/community_questions.json",
    "assets/data/editorial_questions.json",
    "assets/data/offline_questions.json",
    "assets/data/expansion_2026_08_questions.json",
    "assets/data/source_first_2026_08_questions.json",
]
OUT = "scratchpad/tr_expansion"
BATCH = 60

TF_MAP = {"Rast": "Doğru", "Şaş": "Yanlış"}


def has_tr(q: dict) -> bool:
    p = (q.get("promptTr") or "").strip()
    a = q.get("answersTr")
    c = q.get("correctAnswerTr")
    return bool(p and a and c and c in a and len(a) == len(q.get("answers") or []))


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    need, deterministic = [], []
    for path in BANKS:
        for q in json.load(open(path, encoding="utf-8")):
            if has_tr(q):
                continue
            entry = {
                "id": q["id"],
                "bank": os.path.basename(path),
                "category": q.get("category"),
                "type": q.get("type", "multipleChoice"),
                "prompt": q["prompt"],
                "answers": q.get("answers") or [],
                "correctIndex": (q.get("answers") or []).index(q["correctAnswer"])
                if q.get("correctAnswer") in (q.get("answers") or [])
                else None,
                # Türkçe açıklama varsa çevirmenin bağlamıdır: terimin bu
                # projede hangi Türkçe karşılıkla kullanıldığını gösterir.
                "explanationTr": (q.get("explanationTr") or q.get("explanation") or "").strip(),
            }
            if entry["type"] == "trueFalse" and all(
                o in TF_MAP for o in entry["answers"]
            ):
                entry["answersTr"] = [TF_MAP[o] for o in entry["answers"]]
                entry["needsOptions"] = False
                deterministic.append(entry)
            elif entry["type"] == "wordOrdering":
                entry["needsOptions"] = False
                entry["answersTr"] = None  # havuz Kurmancî kalır
                deterministic.append(entry)
            else:
                entry["needsOptions"] = True
            need.append(entry)

    # Parti sırası kategoriye göre: bir ajan tek kategoriye odaklanınca
    # terim tutarlılığı artar (aynı Kurmancî terim aynı Türkçe karşılığı alır).
    need.sort(key=lambda e: (e["category"] or "", e["id"]))
    batches = [need[i : i + BATCH] for i in range(0, len(need), BATCH)]
    for i, b in enumerate(batches):
        with open(f"{OUT}/batch_{i:03d}.json", "w", encoding="utf-8") as fh:
            json.dump(b, fh, ensure_ascii=False, indent=1)

    stats = {
        "total": len(need),
        "batches": len(batches),
        "batchSize": BATCH,
        "deterministicAnswers": len(deterministic),
        "needsOptionTranslation": sum(1 for e in need if e["needsOptions"]),
        "missingCorrectIndex": sum(1 for e in need if e["correctIndex"] is None),
        "withTurkishContext": sum(1 for e in need if e["explanationTr"]),
    }
    print(json.dumps(stats, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
