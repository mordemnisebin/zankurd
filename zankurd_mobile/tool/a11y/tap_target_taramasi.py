#!/usr/bin/env python3
"""Dokunma hedefi alt sınırını KAYNAKTAN tarar — Flutter koşmadan.

## Niçin ayrı bir tarama

Asıl bekçi `test/accessibility_guideline_test.dart` içindeki
`meetsGuideline(androidTapTargetGuideline)` çağrısıdır ve doğru bekçi odur:
gerçekten çizer, gerçek pikseli ölçer. Ama iki körlüğü var:

1. **Yalnız o an EKRANDA olan hedefi görür.** Koşullu çizilen bir dal,
   sekmenin arkasındaki bir düğme, kaydırma dışında kalan bir satır
   denetimin dışında kalır ve test yine de yeşil yanar. Bu kuramsal
   değil: `level_placement_screen.dart` a11y bekçisinde ve Android
   kılavuzu orada iddia ediliyor, ama 44 px kısıtlı `IconButton`
   `useCompactSkip` dalında duruyor ve o dal `width < 380 || textScale >
   1.05` ister — bekçinin kurduğu 800x600 / ölçek 1.0 yüzeyinde o dal
   HİÇ çizilmiyor. Yeşil test o düğme hakkında hiçbir şey söylemiyor.
2. **Flutter gerektirir.** Bulut koşusunda Flutter olmayabilir; o zaman
   kaynak okunabilir ama hiçbir şey ölçülemez.

Bu tarama tamamlayıcıdır ve hiç çizmez: kısıtı kaynaktaki SABİTTEN okur,
yani koşullu dalın çizilip çizilmediği umurunda değildir. Karşılığında
bir şey kaybeder — gerçek pikseli bilmez (bkz. "Ne bilmez").

## Eşikler

Flutter'ın iki kılavuzu ayrı sayı ister:

* `androidTapTargetGuideline` → 48x48
* `iOSTapTargetGuideline`     → 44x44

Bu fark bu depoda önemli, çünkü kaynakta **yerleşmiş bir 44 geleneği**
var ve yanına «dokunma hedefi alt sınırının altına düşmemeli» diye yorum
yazılmış. 44 iOS'un alt sınırıdır; Android'in değil. Yani niyet doğru,
sayı Android için eksik. Tarama bu yüzden 44'ü «temiz» saymaz,
`yalniz_android` diye ayrı bir sınıfa koyar.

## Sınıflandırma ve niçin gerekli

Kısıt sayısını görmek yetmez, kimin kısıtı olduğu belirler:

* `ilerleme_cubugu` — `LinearProgressIndicator(minHeight: N)`. N çubuğun
  KALINLIĞIDIR, dokunma hedefi değil. Kaynakta 48 altı kısıtların çoğu
  budur; ayıklanmazsa gerçek bulgu gürültüde kaybolur.
* `iconbutton`     — `IconButton` varsayılan `tapTargetSize`ı
  `MaterialTapTargetSize.padded` olduğu için `constraints` altında kalsa
  bile vuruş alanını 48'e genişletir. Kısıt görünümü küçültür, hedefi
  küçültmez. DOĞRULANMADI: bkz. "Ne bilmez".
* `dokunulabilir` — `InkWell` / `GestureDetector` / `gestures` sarmalı.
  Bunlarda `tapTargetSize` YOKTUR; hiçbir şey 48'e genişletmez, kısıt ne
  diyorsa hedef odur. Gerçek aday sınıfı budur.
* `acik_kapatma`  — `MaterialTapTargetSize.shrinkWrap` ya da
  `minimumSize: Size.zero`. Bunlar Flutter'ın genişletmesini AÇIKÇA
  kapatır; sayı okunmasa bile kusur adayıdır.
* `bilinmiyor`    — pencere içinde sarmalayan bulunamadı; göz gerekir.

## Ne bilmez (kapsamın bittiği yer)

* **Gerçek pikseli ölçmez.** Yalnız `BoxConstraints` sabitini okur. Dış
  bir `SizedBox`, `Padding` ya da esneyen bir satır hedefi 48'in üstüne
  çıkarmış olabilir; tarama bunu göremez ve `dokunulabilir` bulgusu
  «kusur» değil «bakılacak yer» demektir.
* **Sarmalayanı pencereyle arar**, ayrıştırıcıyla değil: bulgudan geriye
  en çok `PENCERE` satır okunur ve ilk eşleşen sarmalayan kabul edilir.
  İç içe geçmiş uzun `build` gövdelerinde yanılabilir. Her bulgunun
  yanında `dosya:satır` basılmasının sebebi budur — hüküm insanındır.
* **Metinden büyüyen hedefi göremez.** Kısıtı olmayan ama yazı tipi
  boyundan küçük kalan bir hedef bu taramaya hiç düşmez.

Yani bu tarama `meetsGuideline`in YERİNE geçmez; ona nereye bakacağını
söyler. Gerçek hüküm Flutter'ın ölçtüğü yerdedir.

Kullanım:

    python3 tool/a11y/tap_target_taramasi.py [--kok lib] [--json]

Çıkış kodu: `dokunulabilir` ya da `acik_kapatma` sınıfında bulgu varsa 1.
"""
import argparse
import json
import pathlib
import re
import sys
from collections import defaultdict

ANDROID_ESIK = 48.0
IOS_ESIK = 44.0

# Bulgudan geriye kaç satır okunacağı. 14, bu depodaki en derin
# `Semantics > InkWell > AnimatedContainer > constraints` zincirini
# (sign_in_screen `_LanguageChip`, 8 satır) rahatça kapsar; daha uzun
# pencere komşu widget'ı yanlışlıkla sarmalayan sanmaya başlıyor.
PENCERE = 14

MIN_KISIT = re.compile(r"\bmin(Width|Height)\s*:\s*(\d+(?:\.\d+)?)")
ACIK_KAPATMA = re.compile(
    r"MaterialTapTargetSize\.shrinkWrap|minimumSize\s*:\s*Size\.zero"
)

# Sıra ÖNEMLİ: en yakın sarmalayan kazanır, bu yüzden geriye doğru
# okurken ilk eşleşen alınır. `LinearProgressIndicator` listede en başta
# değil — sarmalayan araması zaten en yakını bulur.
SARMALAYANLAR = [
    ("ilerleme_cubugu", re.compile(r"\bLinearProgressIndicator\s*\(")),
    ("iconbutton", re.compile(r"\bIconButton\s*\(")),
    ("dokunulabilir", re.compile(r"\b(InkWell|GestureDetector)\s*\(")),
]


def sarmalayan_bul(satirlar: list[str], indeks: int) -> str:
    """Bulgunun sahibini geriye doğru bounded pencerede arar.

    Ayrıştırıcı değil, sezgidir; niçin yeterli olduğu ve nerede
    yanılabileceği modül belgesinde yazılı.
    """
    bas = max(0, indeks - PENCERE)
    for i in range(indeks, bas - 1, -1):
        for ad, desen in SARMALAYANLAR:
            if desen.search(satirlar[i]):
                return ad
    return "bilinmiyor"


def kilavuz_hukmu(deger: float) -> str:
    """Hangi kılavuzun düştüğünü söyler.

    44 ayrı bir hüküm: iOS'u geçer, Android'i geçmez. Bu depodaki 44
    geleneği tam bu boşlukta duruyor.
    """
    if deger < IOS_ESIK:
        return "ikisi_de"
    if deger < ANDROID_ESIK:
        return "yalniz_android"
    return "temiz"


def dosyayi_tara(yol: pathlib.Path, kok: pathlib.Path) -> list[dict]:
    satirlar = yol.read_text(encoding="utf-8").splitlines()
    bulgular = []
    bagil = yol.relative_to(kok.parent) if kok.parent in yol.parents else yol

    for i, satir in enumerate(satirlar):
        for eslesme in MIN_KISIT.finditer(satir):
            deger = float(eslesme.group(2))
            hukum = kilavuz_hukmu(deger)
            if hukum == "temiz":
                continue
            bulgular.append(
                {
                    "dosya": str(bagil),
                    "satir": i + 1,
                    "sinif": sarmalayan_bul(satirlar, i),
                    "eksen": eslesme.group(1),
                    "deger": deger,
                    "kilavuz": hukum,
                    "kaynak": satir.strip(),
                }
            )
        if ACIK_KAPATMA.search(satir):
            bulgular.append(
                {
                    "dosya": str(bagil),
                    "satir": i + 1,
                    "sinif": "acik_kapatma",
                    "eksen": "-",
                    "deger": None,
                    "kilavuz": "ikisi_de",
                    "kaynak": satir.strip(),
                }
            )
    return bulgular


# Rapor sırası: göz gerektirenler önce, ayıklananlar sonra.
SIRA = ["acik_kapatma", "dokunulabilir", "bilinmiyor", "iconbutton", "ilerleme_cubugu"]

BASLIK = {
    "acik_kapatma": "AÇIK KAPATMA — Flutter'ın 48 genişletmesi elle kapatılmış",
    "dokunulabilir": "DOKUNULABİLİR — InkWell/GestureDetector, genişletme YOK",
    "bilinmiyor": "BİLİNMİYOR — sarmalayan bulunamadı, göz gerekir",
    "iconbutton": "ICONBUTTON — padded genişletme kurtarıyor olmalı (doğrulanmadı)",
    "ilerleme_cubugu": "İLERLEME ÇUBUĞU — dokunma hedefi değil, ayıklandı",
}


def main() -> int:
    ayristirici = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ayristirici.add_argument("--kok", default="lib", type=pathlib.Path)
    ayristirici.add_argument("--json", action="store_true")
    argumanlar = ayristirici.parse_args()

    kok = argumanlar.kok
    if not kok.is_dir():
        print(f"kök bulunamadı: {kok}", file=sys.stderr)
        return 2

    bulgular = []
    for yol in sorted(kok.rglob("*.dart")):
        bulgular.extend(dosyayi_tara(yol, kok))

    if argumanlar.json:
        print(json.dumps(bulgular, ensure_ascii=False, indent=2))
    else:
        gruplar = defaultdict(list)
        for bulgu in bulgular:
            gruplar[bulgu["sinif"]].append(bulgu)
        for sinif in SIRA:
            grup = gruplar.get(sinif, [])
            print(f"\n## {BASLIK[sinif]}  ({len(grup)})")
            for bulgu in grup:
                deger = "-" if bulgu["deger"] is None else f"{bulgu['deger']:g}"
                print(
                    f"  {bulgu['dosya']}:{bulgu['satir']}"
                    f"  {bulgu['eksen']}={deger}  düşen={bulgu['kilavuz']}"
                )
                print(f"      {bulgu['kaynak']}")

    goz_gerektiren = [
        b for b in bulgular if b["sinif"] in ("acik_kapatma", "dokunulabilir")
    ]
    if not argumanlar.json:
        print(f"\nGöz gerektiren bulgu: {len(goz_gerektiren)}")
    return 1 if goz_gerektiren else 0


if __name__ == "__main__":
    sys.exit(main())
