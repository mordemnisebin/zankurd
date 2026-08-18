#!/usr/bin/env python3
"""Soru bankası tipografisini YAPISAL olarak normalleştirir.

Niçin ayrı ve yapısal bir araç
------------------------------
2026-08-06'da bu iş iki kez düz `re.sub` ile denendi ve iki kez içerik
bozuldu:

1. Düz tırnak → guillemet dönüşümü, Türkçe EK kesme işaretlerini de
   çevirdi: `1947'de` → `1947«de`, `Edison'un` → `Edison«un`,
   `Palme d'Or` → `Palme d«Or`. 87 kayıt bozuldu.
2. Onarım denemesi, meşru KAPANIŞ `»` işaretlerini kesme işaretine
   çevirdi ve 184 kaydı dengesiz bıraktı.

Kök sebep aynı: **kesme işareti ile alıntı işareti aynı karakteri
paylaşır** (`'`), ve bir regex ikisini ayırt edemez. Bu araç ayırt eder:
metni karakter karakter tarar, tırnağın iki yanındaki bağlama bakar ve
yalnız GERÇEK bir açılış/kapanış ÇİFTİ bulduğunda dönüştürür. Eşleşmeyen
tırnak dönüştürülmez — inceleme listesine düşer.

Kurallar
--------
* `"metin"` (dengeli çift tırnak) → `«metin»`
* `'metin'` yalnız açılış/kapanış bağlamı NETSE → `«metin»`
* Harf/rakama YAPIŞIK `'` kesme işaretidir, asla dokunulmaz:
  `1947'de`, `Edison'un`, `HTTP'ye`, `Palme d'Or`, `O'Connor`
* Zaten `«...»` olan dengeli çiftler aynen kalır (idempotent)
* Alfasayısal iki karakter arasında `«`/`»` SERT HATA
* Dengesiz `«`/`»` SERT HATA
* `»...«` (ters sıra) SERT HATA

Yalnız metin alanlarına dokunur; id, metadata, hash gibi kimlik alanları
hiç okunmaz.
"""
from __future__ import annotations
import argparse, json, re, sys, unicodedata

TEXT_FIELDS = ["prompt", "promptTr", "explanation", "explanationKu", "explanationTr"]
LIST_FIELDS = ["answers", "answersTr"]
ANSWER_FIELDS = ["correctAnswer", "correctAnswerTr"]

WORD = re.compile(r"[0-9A-Za-zÀ-ÿĞğİıŞşÇçÖöÜüÊêÎîÛûŴŵ]")

# Sert hata desenleri
GLUED = re.compile(r"(?<=[0-9A-Za-zÀ-ÿĞğİıŞşÇçÖöÜüÊêÎîÛû])[«»](?=[0-9A-Za-zÀ-ÿĞğİıŞşÇçÖöÜüÊêÎîÛû])")
SUFFIX_GUILLEMET = re.compile(r"(?<=[0-9A-Za-zÀ-ÿĞğİıŞşÇçÖöÜüÊêÎîÛû])[«»](?=[a-zçğıöşüêîû])")


class TypographyError(Exception):
    pass


def _is_word(s: str, i: int) -> bool:
    return 0 <= i < len(s) and bool(WORD.match(s[i]))


def audit(text: str, where: str) -> list[str]:
    """Sert hataları döndürür (boş liste = temiz)."""
    errs = []
    if text.count("«") != text.count("»"):
        errs.append(f"{where}: unbalanced guillemets ({text.count('«')}«/{text.count('»')}»)")
    if GLUED.search(text):
        errs.append(f"{where}: guillemet between alphanumerics")
    if SUFFIX_GUILLEMET.search(text):
        errs.append(f"{where}: guillemet used as Turkish suffix apostrophe")
    # ters sıra: ilk görülen » olmamalı
    order = [c for c in text if c in "«»"]
    depth = 0
    for c in order:
        depth += 1 if c == "«" else -1
        if depth < 0:
            errs.append(f"{where}: closing » before opening «")
            break
    if text.count('"') % 2 == 1:
        errs.append(f"{where}: unbalanced ASCII double quote")
    return errs


def convert(text: str) -> tuple[str, int]:
    """Dengeli tırnak çiftlerini guillemet'e çevirir. (yeni_metin, değişiklik)"""
    if not text:
        return text, 0
    out = list(text)
    changes = 0

    # 1) ASCII çift tırnak: dengeli çiftleri sırayla eşle
    idx = [i for i, c in enumerate(out) if c == '"']
    if len(idx) % 2 == 0:
        for a, b in zip(idx[0::2], idx[1::2]):
            out[a], out[b] = "«", "»"
            changes += 2

    s = "".join(out)

    # 2) Tek tırnak: yalnız SIRA BAKIMINDAN NET açılış/kapanış çiftleri.
    #    Her tırnak üç sınıftan biridir:
    #      OPEN  : öncesi kelime değil, sonrası kelime
    #      CLOSE : öncesi kelime, sonrası kelime değil
    #      APOS  : her iki yanı kelime  -> kesme işareti, asla çevrilmez
    #
    #    Türkçede tırnaklı sözcüğe ek gelebilir: 'siz'i, 'kar'a, 'at'ê.
    #    Orada kapanış tırnağı APOS gibi görünür; açılış eşleşmeden kalır ve
    #    naif bir eşleştirici onu İLERİDEKİ başka bir tırnakla eşleştirip
    #    alıntıyı çaprazlar (2026-08-06: `«siz'i gösterir. 'Biz» em` böyle
    #    üretildi). Bu yüzden dizi mükemmel OPEN/CLOSE sırası vermiyorsa
    #    dizge HİÇ çevrilmez ve incelemeye bırakılır — tahmin etmekten iyidir.
    marks = []
    for i, c in enumerate(s):
        if c not in "'\u2019\u2018":
            continue
        prev_w, next_w = _is_word(s, i - 1), _is_word(s, i + 1)
        prev_c = s[i - 1] if i > 0 else ""
        next_c = s[i + 1] if i + 1 < len(s) else ""
        prev_space = (prev_c == "" or prev_c.isspace() or prev_c in "([{\u00ab")
        next_space = (next_c == "" or next_c.isspace() or next_c in ")]}.,;:!?\u00bb")
        if prev_w and next_w:
            # her iki yanı harf: kesme işareti (1947'de, Edison'un)
            marks.append((i, "APOS"))
        elif prev_space and not next_space:
            # Açılış: öncesi boşluk/ayraç, sonrası içerik. `'8½'` gibi
            # rakam-simge karışımı adlarda da doğru çalışır — eski sürüm
            # yalnız harfe bakıyordu ve `½`, `…` gibi karakterlerde
            # eşleştirmeyi bırakıyordu (2026-08-06).
            marks.append((i, "OPEN"))
        elif (not prev_space) and next_space:
            marks.append((i, "CLOSE"))
        else:
            marks.append((i, "AMBIG"))
    pairable = [m for m in marks if m[1] in ("OPEN", "CLOSE")]
    kinds = [k for _, k in pairable]
    ok = len(kinds) % 2 == 0 and all(
        kinds[j] == ("OPEN" if j % 2 == 0 else "CLOSE") for j in range(len(kinds)))
    if ok and not any(k == "AMBIG" for _, k in marks):
        out = list(s)
        for a, b in zip(pairable[0::2], pairable[1::2]):
            out[a[0]], out[b[0]] = "\u00ab", "\u00bb"
            changes += 2
        return "".join(out), changes
    return s, changes

def normalize_record(q: dict) -> tuple[dict, list, list]:
    edits, errs = [], []
    out = dict(q)
    for f in TEXT_FIELDS + ANSWER_FIELDS:
        v = out.get(f)
        if not isinstance(v, str):
            continue
        new, n = convert(v)
        if n:
            edits.append((f, v, new))
            out[f] = new
        errs += audit(out[f], f"{q.get('id')}.{f}")
    for f in LIST_FIELDS:
        v = out.get(f)
        if not isinstance(v, list):
            continue
        arr = []
        for j, x in enumerate(v):
            new, n = convert(x) if isinstance(x, str) else (x, 0)
            if n:
                edits.append((f"{f}[{j}]", x, new))
            arr.append(new)
            if isinstance(new, str):
                errs += audit(new, f"{q.get('id')}.{f}[{j}]")
        out[f] = arr
    # doğru cevap şıklarda kalmalı
    for ans, arr in (("correctAnswer", "answers"), ("correctAnswerTr", "answersTr")):
        if ans in out and arr in out and out[ans] not in out[arr]:
            errs.append(f"{q.get('id')}: {ans} no longer present in {arr}")
    return out, edits, errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("-o", "--out")
    ap.add_argument("--report")
    ap.add_argument("--check", action="store_true",
                    help="değişiklik yazma; yalnız denetle (idempotency testi)")
    a = ap.parse_args()

    rows = json.load(open(a.path, encoding="utf-8"))
    new_rows, all_edits, all_errs = [], [], []
    for q in rows:
        r, edits, errs = normalize_record(q)
        new_rows.append(r)
        all_edits += [(q.get("id"), *e) for e in edits]
        all_errs += errs

    print(f"records        : {len(rows)}")
    print(f"fields changed : {len(all_edits)}")
    print(f"hard errors    : {len(all_errs)}")
    for e in all_errs[:15]:
        print("   ", e)

    if a.report:
        import csv
        with open(a.report, "w", encoding="utf-8", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["questionId", "field", "original", "rebuilt", "reason", "rule", "reviewed"])
            for qid, field, o, n in all_edits:
                w.writerow([qid, field, o, n, "balanced quote pair -> guillemet",
                            "TYPOGRAPHY_QUOTE_PAIR", "auto"])

    if a.check:
        again = [normalize_record(r)[1] for r in new_rows]
        n2 = sum(len(x) for x in again)
        print(f"idempotent     : {'YES' if n2 == 0 else 'NO (' + str(n2) + ' further changes)'}")
        if n2:
            return 1

    if a.out and not all_errs:
        json.dump(new_rows, open(a.out, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print("wrote          :", a.out)

    return 1 if all_errs else 0


if __name__ == "__main__":
    sys.exit(main())
