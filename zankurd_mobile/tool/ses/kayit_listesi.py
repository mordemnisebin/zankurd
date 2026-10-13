#!/usr/bin/env python3
"""Ana dili Kurmancî olan seslendirmenlere verilecek KAYIT LİSTESİ.

## Niçin var

Cihazda Kurmancî TTS sesi neredeyse hiç kurulu değil; seslendirme ancak
gerçek kayıtlarla çalışır. Bu betik, uygulamanın paketli içeriğinden hangi
ifadelerin hangi sırayla kaydedileceğini çıkarır:

* öncelik 1 — başlangıç yolunun (``everyday`` ders sırası) ders ifadeleri,
  yol sırasıyla;
* öncelik 2 — sözlükte olup ders ve sorularda en sık geçen ~300 sözcük;
* öncelik 3 — kalan ders ifadeleri (yol dışı dersler).

``key`` sütunu Dart'taki ``kurmanciTextKey`` ile BİREBİR aynıdır
(``lib/src/utils/kurmanci_text_key.dart``); ``test/kurmanci_text_key_test.dart``
üretilmiş CSV'nin her satırını Dart işleviyle karşılaştırır.

Kullanım (``zankurd_mobile/`` içinden)::

    python3 tool/ses/kayit_listesi.py

Yalnız standart kitaplık.
"""
import csv
import json
import re
import sys
import unicodedata
from collections import Counter, OrderedDict
from pathlib import Path

KOK = Path(__file__).resolve().parents[2]
CIKTI = KOK / "tool" / "ses" / "kayit_listesi.csv"
SOZLUK = KOK / "lib" / "src" / "data" / "learner_lexicon.dart"
DEPO = KOK / "lib" / "src" / "data" / "mock_zankurd_repository.dart"
VERI = KOK / "assets" / "data"
SOZCUK_SAYISI = 300

# ---------------------------------------------------------------- anahtar

_BIRLESIK = {
    "ê": "ê",
    "î": "î",
    "û": "û",
    "ç": "ç",
    "ş": "ş",
    "ș": "ş",
}
_BOSLUK = re.compile(r"[ \t\r\n\f\v  -   　]+")
_GORUNMEZ = re.compile("[​-‍⁠﻿]")
_ASCII = {"ç": "c", "ê": "e", "î": "i", "ş": "s", "û": "u", "ı": "i",
          "ö": "o", "ü": "u", "ğ": "g"}


def normallestir(metin):
    s = _GORUNMEZ.sub("", metin)
    s = _BOSLUK.sub(" ", s).strip()
    s = s.lower().replace("̇", "")
    for kaynak, hedef in _BIRLESIK.items():
        s = s.replace(kaynak, hedef)
    s = s.replace("’", "'").replace("‘", "'")
    # Baştaki/sondaki harf-rakam-işaret dışı karakterler atılır.
    bas, son = 0, len(s)
    while bas < son and unicodedata.category(s[bas])[0] not in "LNM":
        bas += 1
    while son > bas and unicodedata.category(s[son - 1])[0] not in "LNM":
        son -= 1
    return s[bas:son]


def _govde(norm):
    cikti = []
    for ch in norm:
        ch = _ASCII.get(ch, ch)
        cikti.append(ch if re.fullmatch(r"[a-z0-9]", ch) else "-")
    s = re.sub(r"-+", "-", "".join(cikti)).strip("-")[:24].rstrip("-")
    return s or "x"


def _fnv1a32(norm):
    h = 0x811C9DC5
    for b in norm.encode("utf-8"):
        h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
    return "%08x" % h


def anahtar(metin):
    norm = normallestir(metin)
    if not norm:
        return ""
    return "%s_%s" % (_govde(norm), _fnv1a32(norm))


# ------------------------------------------------------------------ okuma

def _dart_metin(ham):
    ham = ham[1:-1]
    return re.sub(r"\\(.)", lambda m: {"n": "\n"}.get(m.group(1), m.group(1)), ham)


_DART_STR = r"""('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")"""


def sozluk_kayitlari():
    """learner_lexicon.dart -> [(id, terim, anlam, kaynak)] (dosya sırası)."""
    metin = SOZLUK.read_text(encoding="utf8")
    desen = re.compile(
        r"LearnerLexiconEntry\(\s*id: '([^']*)',\s*termKu: " + _DART_STR
        + r",\s*meaningTr: " + _DART_STR + r",\s*sourceId: '(\w+)'"
    )
    return [(m.group(1), _dart_metin(m.group(2)), _dart_metin(m.group(3)),
             m.group(4)) for m in desen.finditer(metin)]


def yol_dersleri():
    """Başlangıç yolu: `everyday` kategorisindeki dersler, `order` sırasıyla."""
    metin = DEPO.read_text(encoding="utf8")
    blok = metin[metin.index("_lessonsData"):metin.index("'grammar': [")]
    dersler = []
    for parca in re.split(r"\bLesson\(", blok)[1:]:
        kimlik = re.search(r"id: '(\w+)'", parca)
        sira = re.search(r"order: (\d+)", parca)
        if kimlik and sira:
            dersler.append((int(sira.group(1)), kimlik.group(1)))
    return [k for _, k in sorted(dersler)]


def slayt_ornekleri():
    """Slayt `exampleKu` cümleleri -> [(ders, cümle)] (dosya sırası)."""
    metin = DEPO.read_text(encoding="utf8")
    metin = metin[metin.index("_slidesData"):]
    sonuc = []
    for parca in re.split(r"\bLessonSlide\(", metin)[1:]:
        ders = re.search(r"lessonId: '(\w+)'", parca)
        ornek = re.search(r"exampleKu: " + _DART_STR, parca)
        if not (ders and ornek):
            continue
        ham = _dart_metin(ornek.group(1))
        # Harf/sözcük listeleri ("A, B, C...") cümle değil; kayıt listesine
        # sözlük kayıtları zaten girer.
        if "..." in ham or ham.count(",") >= 2:
            continue
        for cumle in re.findall(r"[^.?!]+[.?!]?", ham):
            cumle = cumle.strip(" —-—")
            if len(normallestir(cumle)) >= 2:
                sonuc.append((ders.group(1), cumle.strip()))
    return sonuc


def soru_metinleri():
    """Paketli soru bankalarındaki Kurmancî alanlar (istem, şık, açıklama)."""
    pubspec = (KOK / "pubspec.yaml").read_text(encoding="utf8")
    metinler = []
    for ad in re.findall(r"assets/data/(\w+_questions\.json)", pubspec):
        yol = VERI / ad
        if not yol.exists():
            continue
        for soru in json.loads(yol.read_text(encoding="utf8")):
            metinler.append(soru.get("prompt") or "")
            metinler.extend(soru.get("answers") or [])
            metinler.append(soru.get("correctAnswer") or "")
            metinler.append(soru.get("explanationKu") or "")
    return metinler


_SOZCUK = re.compile(r"[^\W\d_]+")


def _jetonlar(metin):
    return _SOZCUK.findall(normallestir(metin))


def sikliklar(metinler, uzunluklar):
    sayac = Counter()
    for metin in metinler:
        j = _jetonlar(metin)
        for n in uzunluklar:
            for i in range(len(j) - n + 1):
                sayac[tuple(j[i:i + n])] += 1
    return sayac


# ------------------------------------------------------------------- ana

def main():
    kayitlar = sozluk_kayitlari()
    yol = yol_dersleri()
    yol_kumesi = set(yol)
    ornekler = slayt_ornekleri()
    ders_kaynaklari = {k for *_, k in kayitlar if k != "questions"}

    # Ders ifadeleri: (ders, metin). Her dersin sözlük çiftleri, ardından
    # slayt örnek cümleleri.
    ders_ifadeleri = OrderedDict()
    for ders in yol:
        ders_ifadeleri[ders] = []
    for _, terim, _, kaynak in kayitlar:
        if kaynak != "questions":
            ders_ifadeleri.setdefault(kaynak, []).append((terim, "ders:" + kaynak))
    for ders, cumle in ornekler:
        ders_ifadeleri.setdefault(ders, []).append((cumle, "slayt:" + ders))

    ifadeler = [m for liste in ders_ifadeleri.values() for m, _ in liste]
    uzunluklar = sorted({len(_jetonlar(m)) for m in ifadeler if _jetonlar(m)}
                        | {1})
    sayac = sikliklar(soru_metinleri(), uzunluklar)

    def adet(metin):
        return sayac.get(tuple(_jetonlar(metin)), 0)

    satirlar = OrderedDict()  # key -> [oncelik, metin, kaynaklar, adet]

    def ekle(oncelik, metin, kaynak):
        k = anahtar(metin)
        if not k:
            return
        if k in satirlar:
            if kaynak not in satirlar[k][2]:
                satirlar[k][2].append(kaynak)
            return
        satirlar[k] = [oncelik, metin, [kaynak], adet(metin)]

    for ders in yol:
        for metin, kaynak in ders_ifadeleri[ders]:
            ekle(1, metin, kaynak)

    # Öncelik 2: ders ifadesi olmayan sözlük sözcükleri, sıklığa göre.
    aday = []
    gorulen = set(satirlar)
    for sira, (_, terim, _, kaynak) in enumerate(kayitlar):
        k = anahtar(terim)
        if k in gorulen or len(_jetonlar(terim)) != 1:
            continue
        gorulen.add(k)
        aday.append((-adet(terim), sira, terim, kaynak))
    aday.sort()
    for eksi, _, terim, kaynak in aday[:SOZCUK_SAYISI]:
        if eksi == 0:
            break
        ekle(2, terim, "sozluk:" + kaynak)

    for ders, liste in ders_ifadeleri.items():
        if ders in yol_kumesi:
            continue
        for metin, kaynak in liste:
            ekle(3, metin, kaynak)

    sirali = sorted(satirlar.items(), key=lambda kv: kv[1][0])  # kararlı
    with CIKTI.open("w", encoding="utf8", newline="") as f:
        yazar = csv.writer(f, lineterminator="\n")
        yazar.writerow(["oncelik", "key", "metin", "kaynak", "adet"])
        for k, (oncelik, metin, kaynaklar, n) in sirali:
            yazar.writerow([oncelik, k, metin, "|".join(kaynaklar), n])

    sayim = Counter(v[0] for v in satirlar.values())
    print("yazildi: %s" % CIKTI.relative_to(KOK))
    for o in (1, 2, 3):
        print("oncelik %d: %d satir" % (o, sayim[o]))
    print("toplam: %d satir (sozluk %d kayit, yol dersi %d)"
          % (len(satirlar), len(kayitlar), len(yol)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
