#!/usr/bin/env python3
"""Kaynak sayfasının, sorudaki DENETLENEBİLİR olguyu içerip içermediğine bakar.

## Kapsamın sınırı bilinçli

Soru Kurmancî, kaynak çoğu zaman İngilizce ya da Türkçe. Bu yüzden naif bir
kelime taraması kitlesel yanlış alarm üretir: "Algorîtma" sorusunun kaynağı
`en.wikipedia.org/wiki/Algorithm` olabilir ve Kurmancî sözcük o sayfada hiç
geçmez — ama kaynak doğrudur.

O yüzden yalnız DİLDEN BAĞIMSIZ olgular denetlenir: yıllar ve sayılar. Bir
soru "1989" diyorsa ve kaynak sayfada 1989 hiç geçmiyorsa, ya kaynak yanlış
ya tarih. İkisi de ciddidir ve bu denetim ikisini de yakalar.

Özel adlar bilerek dışarıda: Kurmancî yazımıyla ("Şerefxanê Bidlîsî") başka
dildeki sayfada birebir geçmez ve eşleştirmeye çalışmak gürültü üretir.

Kalan iddiaların doğruluğu bu betiğin işi DEĞİLDİR; insan/model denetimi
gerektirir. Betik yalnız mekanik olarak kesin söylenebileni söyler.

Kullanım:
  python3 tool/content_authoring/verify_facts.py aday.csv
"""
import csv
import json
import re
import sys
import urllib.parse
import time
import urllib.request

YEAR = re.compile(r"\b(1[0-9]{3}|20[0-2][0-9])\b")
UA = {"User-Agent": "zankurd-fact-verify"}


def fetch(request: urllib.request.Request, tries: int = 4) -> bytes:
    """429'a karşı geri çekilerek okur.

    İlk koşuda altı işçiyle Wikipedia API'sine yüklenildi ve 49 satırın
    35'i "yıl kaynakta yok" değil "Too Many Requests" diye düştü — yani
    ölçüm değil, ölçüm aracı bozuktu.
    """
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(request, timeout=25) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == tries - 1:
                raise
            time.sleep(3 * (attempt + 1))
    raise RuntimeError("ulaşılamadı")


def page_text(url: str) -> str:
    """Wikipedia sayfasının düz metnini çeker; başka siteler için ham HTML."""
    split = urllib.parse.urlsplit(url)
    if "wikipedia.org" in split.netloc and split.path.startswith("/wiki/"):
        title = urllib.parse.unquote(split.path[len("/wiki/"):])
        api = (f"https://{split.netloc}/w/api.php?action=query&prop=extracts"
               f"&explaintext=1&redirects=1&format=json&titles="
               + urllib.parse.quote(title))
        pages = json.loads(fetch(urllib.request.Request(api, headers=UA)))["query"]["pages"]
        return " ".join((p.get("extract") or "") for p in pages.values())
    encoded = urllib.parse.urlunsplit((
        split.scheme, split.netloc, urllib.parse.quote(split.path, safe="/%:@"),
        split.query, ""))
    return fetch(urllib.request.Request(encoded, headers=UA)).decode("utf-8", "replace")


def check(row: dict) -> tuple[str, str, list[str]] | None:
    claim = f"{row['prompt']} {row['explanation']} {row['correct_option']}"
    years = sorted(set(YEAR.findall(claim)))
    if not years:
        return None
    try:
        text = page_text(row["source_url"])
    except Exception as error:
        return (row["id"], "kaynak okunamadı", [str(error)[:60]])
    missing = [y for y in years if y not in text]
    if missing:
        return (row["id"], "yıl kaynakta yok", missing)
    return None


def main(path: str) -> int:
    with open(path, newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    checkable = [r for r in rows
                 if YEAR.search(f"{r['prompt']} {r['explanation']} {r['correct_option']}")]
    print(f"{len(rows)} satır, {len(checkable)} tanesinde denetlenebilir yıl var")

    # Tek akış + aralık: Wikipedia API'si eşzamanlı isteklerde 429 veriyor ve
    # o hata "yıl kaynakta yok" gibi görünüp ölçümü kirletiyordu. Yavaş ama
    # doğru; 55 satır için birkaç dakika.
    results = []
    for index, row in enumerate(checkable):
        outcome = check(row)
        if outcome:
            results.append(outcome)
        if index % 5 == 4:
            time.sleep(1.5)

    if not results:
        print("yıl taşıyan satırların hepsi kaynağıyla tutarlı")
        return 0
    print(f"\n{len(results)} satırda sorun:")
    for rid, kind, detail in results:
        print(f"  {rid}: {kind} ({', '.join(detail)})")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "aday.csv"))
