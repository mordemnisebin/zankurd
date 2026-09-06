#!/usr/bin/env python3
"""Kör partiden dönen cevapları anahtarla karşılaştırır.

## Niçin ayrı adım

Partiyi üreten (`kor_parti_uret.py`) anahtarı HİÇ yazmıyor; doğrulama
buraya ayrılmış. Böylece cevabı veren taraf ile karşılaştıran taraf
birbirini görmüyor — 2026-08-19'da bir çapraz kontrol dosyası tam bu
ayrım olmadığı için bozulmuştu: doğru cevabı kaydın kendisinden
kopyalayan bir satır 55 hükmü çöpe atmıştı.

## Niçin HARF değil METİN saklanıyor

`rebalance_answer_positions.py` şık sırasını değiştirdiğinde kaydedilen
harfler başka şıkları göstermeye başlıyor ve doğrulama sessizce
anlamsızlaşıyor. Metin sıralamadan bağımsızdır.

## Niçin eşleşmeyen cevap ATILIR

Model bazen şıkkın metnini birebir değil, yaklaşık kopyalıyor. Yaklaşık
eşleşmeyi kabul etmek, hükmü uydurmak demektir. Şıklardan birine birebir
oturmayan cevap "?" sayılır: sorulmuş ama yanıt alınamamış olmak zaten
"?"nin tanımıdır.

Kullanım:
  python3 tool/content_authoring/kor_cevap_karsilastir.py <cevap.json> ...
"""
import json
import pathlib
import re
import sys
import unicodedata

HUKUM = pathlib.Path("docs/content_batches/capraz_kontrol.json")
CELISKI = pathlib.Path("docs/content_batches/celiskiler.json")


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", (text or "")).strip().casefold()
    return re.sub(r"\s+", " ", text)


def main(paths) -> int:
    manifest = pathlib.Path("lib/src/data/question_bank_assets.dart").read_text(
        encoding="utf-8")
    bank = {}
    for asset in re.findall(r"'(assets/data/[^']+\.json)'", manifest):
        path = pathlib.Path(asset)
        if path.exists():
            for question in json.loads(path.read_text(encoding="utf-8")):
                bank[question["id"]] = question

    verdicts = {}
    if HUKUM.exists():
        verdicts = json.loads(HUKUM.read_text(encoding="utf-8"))
    before = len(verdicts)

    yazilan = eslesmeyen = bilinmeyen = 0
    for raw in paths:
        data = json.loads(pathlib.Path(raw).read_text(encoding="utf-8"))
        for item in data:
            if not isinstance(item, dict):
                continue
            qid = item.get("id")
            if qid is None or qid not in bank:
                bilinmeyen += 1
                continue
            given = str(item.get("cevap", "?")).strip()
            if given == "?" or not given:
                verdicts[qid] = "?"
                yazilan += 1
                continue
            # Şıklardan BİREBİR (normalleştirilmiş) eşleşen var mı?
            options = bank[qid].get("answers") or []
            match = next(
                (o for o in options if normalize(o) == normalize(given)), None)
            if match is None:
                verdicts[qid] = "?"
                eslesmeyen += 1
                yazilan += 1
                continue
            verdicts[qid] = match
            yazilan += 1

    HUKUM.write_text(json.dumps(verdicts, ensure_ascii=False, indent=1),
                     encoding="utf-8")

    uyusan = celisen = emin_degil = 0
    flagged = []
    for qid, given in verdicts.items():
        question = bank.get(qid)
        if question is None:
            continue
        if given == "?":
            emin_degil += 1
            continue
        if given == question.get("correctAnswer"):
            uyusan += 1
        else:
            celisen += 1
            flagged.append(qid)

    CELISKI.write_text(json.dumps(flagged, ensure_ascii=False, indent=1),
                       encoding="utf-8")

    print(f"yazılan hüküm : {yazilan}  (bilinmeyen id: {bilinmeyen}, "
          f"şıkka oturmayan: {eslesmeyen})")
    print(f"hüküm toplamı : {before} -> {len(verdicts)}")
    print(f"uyuşan: {uyusan}   çelişen: {celisen}   emin değil: {emin_degil}")
    if uyusan + celisen:
        print(f"çelişki oranı : %{100 * celisen / (uyusan + celisen):.1f}")
    print(f"çelişen id'ler -> {CELISKI}")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    sys.exit(main(sys.argv[1:]))
