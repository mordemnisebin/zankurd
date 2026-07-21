#!/usr/bin/env python3
"""font_awesome_flutter kaynagindan, ihtiyac duyulan 127 ikonun ham
(codePoint, fontFamily, fontPackage) degerlerini cikarip, tamamen
literal (alan-erisim zinciri olmayan, dolayisiyla const-guvenli) bir
IconData sabit sinifi uretir: lib/src/theme/app_icons.dart.

Bu, FontAwesomeIcons.X.data'nin const baglamda calismamasi sorununu
kokten cozer -- Flutter'in kendi Icons sinifinin calisma bicimiyle
birebir ayni (literal IconData(codepoint, fontFamily: ..., fontPackage: ...)).
"""
import re
from pathlib import Path

FA_SOURCE = Path(
    r"C:\src\pub-cache\hosted\pub.dev\font_awesome_flutter-11.0.0\lib\font_awesome_flutter.dart"
)
OUT_PATH = Path(__file__).resolve().parent.parent / "lib" / "src" / "theme" / "app_icons.dart"
NAMES_PATH = Path(__file__).resolve().parent / "_unique_fa_names.txt"


def main():
    names = [n.strip() for n in NAMES_PATH.read_text().splitlines() if n.strip()]
    text = FA_SOURCE.read_text(encoding="utf-8")

    entries = {}
    for name in names:
        pattern = re.compile(
            r"static const FaIconData " + re.escape(name) +
            r" = FaIconData\(\s*IconData\(\s*(0x[0-9a-fA-F]+),\s*"
            r"fontFamily:\s*'([^']+)',\s*fontPackage:\s*'([^']+)',",
            re.DOTALL,
        )
        m = pattern.search(text)
        if not m:
            print(f"BULUNAMADI: {name}")
            continue
        entries[name] = (m.group(1), m.group(2), m.group(3))

    print(f"Bulunan: {len(entries)}/{len(names)}")

    lines = [
        "// AUTO-GENERATED — tool/generate_app_icons.py ile üretildi.",
        "// font_awesome_flutter'ın FontAwesomeIcons.X.data alan-erişimi const",
        "// bağlamlarda çalışmıyor (bkz. 2026-07-21 denetim notu); bu dosya aynı",
        "// (codePoint, fontFamily, fontPackage) değerlerini literal IconData",
        "// olarak sağlar — Flutter'ın kendi Icons sınıfıyla birebir aynı desen.",
        "import 'package:flutter/widgets.dart';",
        "",
        "class AppIcons {",
        "  const AppIcons._();",
        "",
    ]
    for name, (codepoint, family, package) in sorted(entries.items()):
        lines.append(
            f"  static const IconData {name} = IconData({codepoint}, "
            f"fontFamily: '{family}', fontPackage: '{package}');"
        )
    lines.append("}")
    lines.append("")

    OUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Yazildi: {OUT_PATH} ({len(entries)} ikon)")


if __name__ == "__main__":
    main()
