#!/usr/bin/env python3
"""Kurmancî soruları Türkçe ikizleriyle birleştirip banka biçimine getirir.

Şema `assets/data/` altındaki mevcut bankadan alındı:
  prompt/promptTr, answers/answersTr/correctAnswerTr,
  explanation (Türkçe, yedek), explanationKu, explanationTr

`bilingual_bank_integrity_test` Türkçe alanların ya HEP birlikte ya hiç
bulunmasını şart koşuyor; bu yüzden dördü birden yoksa kayıt ATILIR, yarım
bırakılmaz. Yarım kayıt bankaya girerse soru Türkçe oynanışta sessizce yok
sayılır — `language_pool_parity_test`in kovaladığı kusur budur.

Doğru cevabın Türkçe karşılığı hesaplanır, çeviriden ALINMAZ: model şık
sırasını bozarsa doğru cevap yanlış şıkka bağlanır. Sıra korunmuşsa indeks
üzerinden eşleme kesindir.

Kullanım:
  python3 tool/content_authoring/merge_bilingual.py ku.json tr.json çıktı.json
"""
import json
import pathlib
import sys


def main(ku_path: str, tr_path: str, out_path: str) -> int:
    questions = json.loads(pathlib.Path(ku_path).read_text(encoding="utf-8"))
    translations = {t["id"]: t for t in
                    json.loads(pathlib.Path(tr_path).read_text(encoding="utf-8"))}

    merged, skipped = [], []
    for question in questions:
        tr = translations.get(question["id"])
        if not tr:
            skipped.append((question["id"], "çeviri yok"))
            continue
        answers_tr = tr.get("answersTr") or []
        prompt_tr = (tr.get("promptTr") or "").strip()
        explanation_tr = (tr.get("explanationTr") or "").strip()
        if len(answers_tr) != 4 or not prompt_tr or not explanation_tr:
            skipped.append((question["id"], "eksik alan"))
            continue
        if any(not str(a).strip() for a in answers_tr):
            skipped.append((question["id"], "boş şık"))
            continue
        if len({str(a).strip().lower() for a in answers_tr}) != 4:
            skipped.append((question["id"], "Türkçe şıklar birbirinin aynısı"))
            continue

        try:
            index = question["answers"].index(question["correctAnswer"])
        except ValueError:
            skipped.append((question["id"], "doğru cevap şıklarda yok"))
            continue

        record = dict(question)
        record["promptTr"] = prompt_tr
        record["answersTr"] = [str(a).strip() for a in answers_tr]
        record["correctAnswerTr"] = record["answersTr"][index]
        record["explanationKu"] = question.get("explanation", "")
        record["explanationTr"] = explanation_tr
        # Bankanın baskın düzeni: `explanation` Türkçedir, Kurmancî karşılığı
        # ayrı alanda durur.
        record["explanation"] = explanation_tr
        merged.append(record)

    pathlib.Path(out_path).write_text(
        json.dumps(merged, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(merged)} soru birleştirildi -> {out_path}")
    if skipped:
        from collections import Counter
        print(f"{len(skipped)} atlandı:")
        for reason, count in Counter(r for _, r in skipped).most_common():
            print(f"   {count:4d}  {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2], sys.argv[3]))
