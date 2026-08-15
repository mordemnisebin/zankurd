#!/usr/bin/env python3
"""Her Kurmancî sözcüğü canlı korpusta KANITLI mı, onu ölçer.

Niçin var
---------
2026-08-06'da Kol B, uydurulmuş Kurmancî bilim terimi üretmemek için
durduruldu (`external_intake_2026_08.md`, Tur 9). O karar doğruydu ama
ÖLÇÜLEBİLİR değildi: bir sözcüğün "yerleşik" olduğuna göz kararı karar
veriliyordu. Bu araç kararı sayıya çevirir.

Kural
-----
Oyuncuya görünen her Kurmancî alandaki her sözcük, canlı soru bankalarında
(2050 kayıt) en az bir kez geçmelidir. Geçmiyorsa üç yol var ve üçü de
kayıtlıdır:

1. `--allow-proper` listesindeki özel ad (kurum, çalgı, eleman adı). Özel ad
   çeviri gerektirmez; kaynağın yazdığı gibi bırakılır.
2. Kanıtlı bir lemmanın çekimli biçimi (`dizivire` <- `zivirîn`). Bu araç
   morfolojik türetme YAPMAZ; böyle bir sözcük `--allow-inflection`
   dosyasında lemmasıyla birlikte açıkça yazılır.
3. Hiçbiri değilse sözcük kullanılmaz. Soru yeniden yazılır.

Sayı (dijit) ve noktalama muaftır: `24` bir Kurmancî sözcük değildir.
"""
from __future__ import annotations
import argparse, json, re, sys, collections

BANKS = [
    "assets/data/offline_questions.json",
    "assets/data/editorial_questions.json",
    "assets/data/community_questions.json",
    "assets/data/sentence_building_questions.json",
]

WORD = re.compile(r"[a-zA-ZçêîşûÇÊÎŞÛğıöüĞİÖÜ]+")

# Oyuncuya görünen Kurmancî alanlar. Türkçe alanlar bu kapıya girmez:
# sözleşme Kurmancî terminolojisi içindir.
VISIBLE_KU = ("promptKu", "explanationKu", "hintKu")


def corpus_tokens() -> collections.Counter:
    texts: list[str] = []

    def walk(o):
        if isinstance(o, str):
            texts.append(o)
        elif isinstance(o, list):
            for x in o:
                walk(x)
        elif isinstance(o, dict):
            for v in o.values():
                walk(v)

    for path in BANKS:
        with open(path, encoding="utf-8") as fh:
            walk(json.load(fh))
    blob = "\n".join(texts).lower()
    return collections.Counter(WORD.findall(blob))


def visible_words(q: dict) -> list[str]:
    fields = [q.get(f) or "" for f in VISIBLE_KU]
    fields += [a for a in (q.get("answersKu") or [])]
    out: list[str] = []
    for f in fields:
        out.extend(w.lower() for w in WORD.findall(f))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("questions", nargs="+")
    ap.add_argument("--allow", action="append", default=[],
                    help="özel ad / çekim izin dosyası (JSON)")
    a = ap.parse_args()

    corpus = corpus_tokens()
    allowed: dict[str, str] = {}
    for path in a.allow:
        with open(path, encoding="utf-8") as fh:
            for k, v in json.load(fh).items():
                allowed[k.lower()] = v

    missing = collections.Counter()
    where: dict[str, set] = collections.defaultdict(set)
    total = 0

    for path in a.questions:
        with open(path, encoding="utf-8") as fh:
            for q in json.load(fh):
                total += 1
                for w in visible_words(q):
                    if corpus.get(w):
                        continue
                    if w in allowed:
                        continue
                    missing[w] += 1
                    where[w].add(q["questionId"])

    print(f"soru {total} | korpus benzersiz token {len(corpus)} "
          f"| izin listesi {len(allowed)}")
    if not missing:
        print("KANITSIZ SÖZCÜK YOK")
        return 0
    print(f"KANITSIZ {len(missing)} sözcük:")
    for w, n in missing.most_common():
        print(f"  {w:20s} x{n:<3d} {sorted(where[w])}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
