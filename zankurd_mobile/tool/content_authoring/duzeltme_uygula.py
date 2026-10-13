#!/usr/bin/env python3
"""Dış denetimden dönen düzeltmeleri bankaya uygular — DOĞRULAYARAK.

## Niçin doğrulama uygulamadan önce

Dönen metin gözle makul görünür ama bankaya girdikten sonra kusuru
bulmak çok pahalıdır. Uygulama öncesi şu koşullar aranır ve biri bile
tutmazsa O KAYIT atlanır (tamamı değil — geri kalan iş boşa gitmesin):

* kimlik bankada var mı,
* doğru cevap şıklar arasında mı,
* şık sayısı DEĞİŞMEMİŞ mi (dört şıklı soru dört şıklı kalmalı; sayı
  değişirse `question_bank_test` düşer ve sebebi burada görünmez),
* Kurmancî alanlarda Hawar dışı harf var mı (ı, ğ, ö, ü, İ),
* Türkçe ikiz varsa şık sayısı Kurmancî ile eşit mi (eşit değilse
  iki dil arasındaki konum eşlemesi bozulur).

Atlananlar ekrana yazılır; sessizce düşen kayıt olmaz.
"""
import json
import pathlib
import re
import sys

KAYNAK = pathlib.Path("docs/content_batches/gpt_bulgular/duzeltmeler.json")
HAWAR_DISI = set("ığöüİI")

ALANLAR = ("prompt", "answers", "correctAnswer",
           "promptTr", "answersTr", "correctAnswerTr")


def hawar_ihlali(value) -> str | None:
    metinler = value if isinstance(value, list) else [value]
    for metin in metinler:
        # 'I' yalnız Türkçe büyük harf bağlamında sorun; Kurmancî'de
        # kullanılır (Iraq, Îran değil). Yalnız ı/ğ/ö/ü/İ aranır.
        kotu = {c for c in metin if c in "ığöüİ"}
        if kotu:
            return "".join(sorted(kotu))
    return None


def main() -> int:
    manifest = pathlib.Path("lib/src/data/question_bank_assets.dart").read_text(
        encoding="utf-8")
    assets = re.findall(r"'(assets/data/[^']+\.json)'", manifest)
    banks = {a: json.loads(pathlib.Path(a).read_text(encoding="utf-8"))
             for a in assets if pathlib.Path(a).exists()}
    index = {q["id"]: (a, q) for a, qs in banks.items() for q in qs}

    fixes = [x for x in json.loads(KAYNAK.read_text(encoding="utf-8"))
             if "_okunan" not in x]

    applied, skipped = 0, []
    touched = set()
    for fix in fixes:
        qid = fix.get("id")
        if qid not in index:
            skipped.append((qid, "bankada yok")); continue
        asset, question = index[qid]

        answers = fix.get("answers") or question.get("answers")
        correct = fix.get("correctAnswer", question.get("correctAnswer"))
        if correct not in answers:
            skipped.append((qid, "doğru cevap şıklarda yok")); continue
        if len(answers) != len(question.get("answers") or []):
            skipped.append((qid, f"şık sayısı {len(question.get('answers') or [])} -> {len(answers)}")); continue

        ihlal = hawar_ihlali(fix.get("prompt", "")) or hawar_ihlali(answers)
        if ihlal:
            skipped.append((qid, f"Kurmancî'de Hawar dışı harf: {ihlal}")); continue

        answers_tr = fix.get("answersTr", question.get("answersTr"))
        if answers_tr and len(answers_tr) != len(answers):
            skipped.append((qid, "TR şık sayısı Kurmancî ile eşleşmiyor")); continue

        for alan in ALANLAR:
            if alan in fix:
                question[alan] = fix[alan]
        applied += 1
        touched.add(asset)

    if "--uygula" not in sys.argv:
        print(f"uygulanabilir: {applied}   atlanan: {len(skipped)}")
        for qid, sebep in skipped:
            print(f"  ATLANDI {qid}: {sebep}")
        print("\nuygulamak için: --uygula")
        return 0

    for asset in sorted(touched):
        pathlib.Path(asset).write_text(
            json.dumps(banks[asset], ensure_ascii=False, indent=1),
            encoding="utf-8")
        print(f"  yazıldı: {pathlib.Path(asset).name}")
    print(f"\n{applied} kayıt güncellendi, {len(skipped)} atlandı")
    for qid, sebep in skipped:
        print(f"  ATLANDI {qid}: {sebep}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
