#!/usr/bin/env python3
"""`lib/src/theme/app_icons.dart` dosyasını Lucide ikon ailesinden üretir.

Kullanım (zankurd_mobile/ içinden):

    flutter pub get
    python3 tool/generate_lucide_app_icons.py
    dart format lib/src/theme/app_icons.dart

## Niçin bu betik

"Şahnê" tasarım sisteminin çizgi ikon ailesi Lucide'dır (24 ızgara, 2 px
çizgi, yuvarlak uç). Uygulama boyunca `AppIcons.x` çağrıları vardır ve
çağrı yerleri değişmez; yalnız her adın arkasındaki glif değişir. Bu
betik o eşlemeyi tek yerde tutar.

Eski dosya başlığı bu işi `tool/generate_app_icons.py`ye bağlıyordu, ama
o betik başlatıcı simgesini/açılış görselini üretir; `app_icons.dart`ı
hiçbir betik üretmiyordu, başlık yanlış yere işaret ediyordu.

## Neden literal `IconData`

Kod noktaları paketin kendi Dart kaynağından (`LucideIcons.x`) ayrıştırılır,
tahmin edilmez. Çıktı `LucideIcons.x` başvurusu değil literal
`IconData(0x..., fontFamily:, fontPackage:)`dir: `AppIcons` const
`Icon(AppIcons.x)` çağrılarıyla dolu ve literal, Flutter'ın kendi `Icons`
sınıfıyla aynı desendir; paket bir sabiti yeniden adlandırırsa çıktı
kırılmaz, betik yeniden çalıştırılınca fark görünür.

## Lucide'ın karşılayamadığı tek ad

`starSolid`: Lucide yalnız konturdur; yazı tipi biçiminde dolu yıldız
yok (paketin `test/lucide_fill_diagnostic_test.dart`ı yazı tiplerinin
bilerek dolgu içermediğini denetler). Kazanılan puan yıldızının DOLU
çizilmesi bir tasarım gereğidir — bkz. `quiz_result_star_fill_test.dart`:
kontur yıldız "boş" okunur ve renk körü oyuncu için doluluk tek ayırt
edicidir. O yüzden yalnız bu ad Font Awesome Solid'de kalır.
"""
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "lib/src/theme/app_icons.dart"
PACKAGE_CONFIG = ROOT / ".dart_tool/package_config.json"

# Paketin varsayılan (2 px çizgi) statik ailesi. Değişken ağırlıklı
# `Lucide400` aynı kod noktalarını taşır ama ayrı bir yazı tipi dosyasıdır;
# ekran turu tek dosya yüklesin diye statik aile seçildi.
LUCIDE_FAMILY = "Lucide"
LUCIDE_PACKAGE = "lucide_icons_flutter"

# AppIcons adı -> Lucide ikon adı (kebab-case). Sıra çıktının sırasıdır.
# Yorumlar anlamca birebir olmayan seçimlerin gerekçesidir.
MAPPING = {
    "arrowLeft": "arrow-left",
    "arrowRight": "arrow-right",
    "arrowRotateLeft": "rotate-ccw",  # "yeniden dene / tekrar oyna"
    "arrowTrendUp": "trending-up",
    "arrowsRotate": "refresh-cw",
    "bagShopping": "shopping-bag",
    "barsStaggered": "align-left",  # kademeli çubuklar: sola yaslı satırlar
    "bell": "bell",
    "bellSlash": "bell-off",
    "bolt": "zap",
    "book": "book",
    "bookOpen": "book-open",
    "bookOpenReader": "book-open-text",  # okuyan kişi yok; metinli açık kitap
    "bookmark": "bookmark",
    "brain": "brain",
    "briefcase": "briefcase",
    "buildingColumns": "landmark",
    "bullseye": "target",
    "calendarDays": "calendar-days",
    "camera": "camera",
    "cartShopping": "shopping-cart",
    "champagneGlasses": "party-popper",  # kutlama (Newroz, cejn, yarışma)
    "chartColumn": "chart-column",
    "chartLine": "chart-line",
    "check": "check",
    "chevronDown": "chevron-down",
    "chevronRight": "chevron-right",
    "chevronUp": "chevron-up",
    "circle": "circle",
    "circleCheck": "circle-check",
    "circleInfo": "info",
    "circlePlay": "circle-play",
    "circlePlus": "circle-plus",
    "circleQuestion": "circle-question-mark",
    "circleXmark": "circle-x",
    "clapperboard": "clapperboard",
    "clock": "clock",
    "clone": "square-stack",  # "kart modu"; `copy` zaten AppIcons.copy
    "cloud": "cloud",
    "coins": "coins",
    "comment": "message-circle",
    "copy": "copy",
    "dice": "dice-5",  # tek zar
    "doorOpen": "door-open",
    "envelope": "mail",
    "eye": "eye",
    "eyeSlash": "eye-off",
    "faceFrown": "frown",
    "faceSmile": "smile",
    "fire": "flame",
    "flag": "flag",
    "floppyDisk": "save",
    "font": "type",
    "forward": "skip-forward",  # "soruyu atla"
    "gamepad": "gamepad-2",
    "gaugeHigh": "gauge",
    "gavel": "gavel",
    "gear": "settings",
    "gem": "gem",
    "globe": "globe",
    "graduationCap": "graduation-cap",
    "hand": "hand",
    "handPointer": "pointer",
    "hashtag": "hash",
    "heart": "heart",
    "hourglass": "hourglass",
    "hourglassStart": "hourglass",  # Lucide'da tek kum saati var
    "house": "house",
    "idBadge": "id-card",
    "image": "image",
    "images": "images",
    "inbox": "inbox",
    "language": "languages",
    "layerGroup": "layers",
    "leaf": "leaf",
    "lightbulb": "lightbulb",
    "listCheck": "list-checks",
    "locationDot": "map-pin",
    "lock": "lock",
    "magnifyingGlass": "search",
    "masksTheater": "drama",
    "medal": "medal",
    "microphone": "mic",
    "mobileScreen": "smartphone",
    "moon": "moon",
    "mountain": "mountain",
    "music": "music",
    "paintbrush": "paintbrush",
    "palette": "palette",
    "paperPlane": "send",
    "paw": "paw-print",
    "pen": "pen",
    "peopleGroup": "users",
    "peopleRoof": "users-round",  # "aile"; `users`tan yuvarlak kafalarla ayrışır
    "personCircleCheck": "user-check",
    "play": "play",
    # Çıplak "?" yok. `circle-question-mark` zaten circleQuestion'da;
    # ikisi ayırt edilsin diye burada rozetli olan seçildi.
    "question": "badge-question-mark",
    "quoteLeft": "quote",
    "rightFromBracket": "log-out",
    "rightToBracket": "log-in",
    "robot": "bot",
    "scaleBalanced": "scale",
    "seedling": "sprout",
    "shareNodes": "share-2",
    "shield": "shield",
    "shieldHalved": "shield-half",
    "shirt": "shirt",
    "shuffle": "shuffle",
    "squareCheck": "square-check",
    # Lucide'da merdiven yok; basamak basamak yükselen sütunlar "seviye"
    # anlamını taşır (alt kategori zorluk basamağı).
    "stairs": "chart-no-axes-column-increasing",
    "star": "star",
    "starSolid": None,  # Lucide'da dolu yıldız yok; aşağıdaki FA kalıntısı
    "stopwatch": "timer",
    "store": "store",
    "sun": "sun",
    "swords": "swords",  # Yarış sekmesi (düello)
    "tableCells": "layout-grid",
    "trashCan": "trash-2",
    "tree": "tree-pine",
    "triangleExclamation": "triangle-alert",
    "trophy": "trophy",
    "user": "user",
    "userPlus": "user-plus",
    "utensils": "utensils",
    "venus": "venus",
    "volumeHigh": "volume-2",
    "volumeXmark": "volume-x",
    "wallet": "wallet",
    "wandMagicSparkles": "wand-sparkles",
    "xmark": "x",
}

# Lucide karşılığı olmayan adlar: (kod noktası, aile, paket, gerekçe).
# Kod noktası font_awesome_flutter 11'in FontAwesomeIcons.star.data
# değeridir (Font Awesome 7 Free Solid).
FONT_AWESOME_REMNANTS = {
    "starSolid": (
        0xF005,
        "FontAwesomeSolid",
        "font_awesome_flutter",
        "dolgu yok, dolu yıldız gerekli.",
    ),
}


def kebab_to_camel(name: str) -> str:
    head, *rest = name.split("-")
    return head + "".join(part.capitalize() for part in rest)


def lucide_codepoints() -> dict[str, int]:
    """Paketin Dart kaynağından `LucideIcons.<ad>` -> kod noktası."""
    config = json.loads(PACKAGE_CONFIG.read_text())
    entry = next(p for p in config["packages"] if p["name"] == LUCIDE_PACKAGE)
    # `rootUri` göreli ("../x") ya da mutlak ("file:///...") olabilir;
    # pub önbelleğindeki paketler mutlak gelir.
    uri = entry["rootUri"]
    if uri.startswith("file:"):
        root = Path(unquote(urlparse(uri).path))
    else:
        root = (PACKAGE_CONFIG.parent / uri).resolve()
    source = (root / "lib/lucide_icons.dart").read_text(encoding="utf-8")
    pattern = re.compile(
        r"static const IconData (\w+) = const IconData\(\s*(\d+),\s*"
        r"fontFamily: '(\w+)',\s*fontPackage: '(\w+)'\);"
    )
    found = {}
    for name, code, family, package in pattern.findall(source):
        # Yalnız statik ana aile; `...100`, `...Dir` vb. varyantlar hariç.
        if family == LUCIDE_FAMILY and package == LUCIDE_PACKAGE:
            found[name] = int(code)
    if not found:
        sys.exit("HATA: paket kaynağında Lucide sabitleri ayrıştırılamadı")
    return found


def main() -> None:
    codepoints = lucide_codepoints()
    lines = [
        "// AUTO-GENERATED — tool/generate_lucide_app_icons.py ile üretildi.",
        "// Şahnê tasarım sisteminin çizgi ikon ailesi Lucide'dır (24 ızgara,",
        "// 2 px çizgi, yuvarlak uç). Çağrı yerleri `AppIcons.x` olarak kalır;",
        "// yalnız glif değişti. Eşleme ve gerekçeler betiğin MAPPING tablosunda.",
        "//",
        "// Değerler literal IconData'dır: const `Icon(AppIcons.x)` çağrıları için",
        "// gerekir ve Flutter'ın kendi Icons sınıfıyla aynı desendir. Kod noktaları",
        "// lucide_icons_flutter'ın kendi Dart kaynağından okunur, tahmin edilmez.",
        "//",
        "// Tek istisna `starSolid`: Lucide'da dolu yıldız olmadığından Font Awesome",
        "// Solid'de kalır (bkz. betiğin başlığı). Bu yüzden font_awesome_flutter",
        "// bağımlılığı durur (ayrıca Google markası için).",
        "import 'package:flutter/widgets.dart';",
        "",
        "class AppIcons {",
        "  const AppIcons._();",
        "",
    ]
    missing = []
    for app_name, lucide_name in MAPPING.items():
        if lucide_name is None:
            code, family, package, why = FONT_AWESOME_REMNANTS[app_name]
            lines.append(f"  /// Lucide karşılığı yok: {why}")
        else:
            key = kebab_to_camel(lucide_name)
            if key not in codepoints:
                missing.append((app_name, lucide_name))
                continue
            code, family, package = codepoints[key], LUCIDE_FAMILY, LUCIDE_PACKAGE
            lines.append(f"  /// Lucide `{lucide_name}`.")
        lines += [
            f"  static const IconData {app_name} = IconData(",
            f"    0x{code:x},",
            f"    fontFamily: '{family}',",
            f"    fontPackage: '{package}',",
            "  );",
            "",
        ]
    if missing:
        sys.exit(f"HATA: Lucide'da bulunmayan adlar: {missing}")
    lines[-1:] = ["}", ""]  # sondaki boş satırın yerine kapanış
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"{len(MAPPING)} ad yazıldı -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
