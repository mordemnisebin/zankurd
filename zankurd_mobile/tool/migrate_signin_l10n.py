#!/usr/bin/env python3
"""Giriş ekranındaki satır içi iki-dil metinlerini anahtar tabanlı kayda taşır.

Ayarlar ve profil ekranlarıyla aynı yordam. Göç ekran ekran ilerliyor;
`AGENTS.md` tek seferlik büyük refactor'ü yasaklıyor.

    python3 tool/migrate_signin_l10n.py [--dry-run]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TARGET = Path(__file__).resolve().parent.parent / "lib/src/screens/sign_in_screen.dart"

SIMPLE: dict[tuple[str, str], str] = {
    ("E-peyam pêwîst e", "E-posta gerekli"): "K.emailRequired",
    ("Şîfre pêwîst e", "Parola gerekli"): "K.passwordRequired",
    ("Şîfre divê herî kêm 6 tîp be", "Parola en az 6 karakter olmalı"): "K.passwordMin6",
    ("Tê têketin...", "Giriş yapılıyor..."): "K.signingIn",
    ("Bi Google ve tê girêdan...", "Google ile bağlanılıyor..."): "K.connectingGoogle",
    ("Bi Apple ve tê girêdan...", "Apple ile bağlanılıyor..."): "K.connectingApple",
    ("Wek mêvan tê têketin...", "Misafir olarak giriliyor..."): "K.signingInGuest",
    ("Pêşî navnîşana e-peyamê ya derbasdar binivîse.", "Önce geçerli e-posta adresini yaz."): "K.enterValidEmailFirst",
    ("E-peyama vesazkirinê tê şandin...", "Sıfırlama e-postası gönderiliyor..."): "K.sendingReset",
    ("Girêdana vesazkirina şîfreyê ji e-peyama te re hat şandin.", "Parola sıfırlama bağlantısı e-postana gönderildi."): "K.resetSent",
    ("Vesazkirina şîfreyê bi ser neket.", "Parola sıfırlama başarısız."): "K.resetFailed",
    ("Navnîşana e-peyamê", "E-posta adresi"): "K.emailAddress",
    ("E-peyameke derbasdar binivîse", "Geçerli bir e-posta gir"): "K.emailInvalid2",
    ("Şîfre", "Parola"): "K.passwordLabel",
    ("Şîfre ji bîr kir?", "Parolayı unuttun mu?"): "K.forgotPassword",
    ("Têkeve", "Giriş Yap"): "K.signIn",
    ("Hesabê te tune? ", "Hesabın yok mu? "): "K.noAccountPrefix",
    ("Tomar bibe", "Kaydol"): "K.signUp",
    ("Kurmancî hîn bibe û pêşbirkê bike", "Kurmancî öğren ve yarışmaya katıl"): "K.welcomeSubtitle",
    ("Bi Google têkeve", "Google ile giriş yap"): "K.signInGoogle",
    ("Bi Apple têkeve", "Apple ile giriş yap"): "K.signInApple",
    ("Wek mêvan bidomîne", "Misafir olarak devam et"): "K.continueGuest",
    ("An jî bi e-peyamê", "Veya e-posta ile"): "K.orWithEmail",
}

# Türkçesi kaçışlı kesme işareti taşıyor: `'ZanKurd\'a Hoş Geldin'`.
# Düz eşleşme kalıbı bunu kaçıramaz, ayrı ele alınır.
SPECIAL = [
    (
        r"ku\s*\?\s*'Bi xêr hatî ZanKurdê'\s*:\s*'ZanKurd\\'a Hoş Geldin'",
        "context.t(K.welcomeTitle)",
    ),
    (
        r"context\.s\(\s*'Bi xêr hatî ZanKurdê'\s*,\s*'ZanKurd\\'a Hoş Geldin'\s*,?\s*\)",
        "context.t(K.welcomeTitle)",
    ),
]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    source = TARGET.read_text(encoding="utf-8")
    updated = source
    replaced = 0

    for (ku, tr), key in SIMPLE.items():
        ternary = re.compile(
            r"ku\s*\?\s*'" + re.escape(ku) + r"'\s*:\s*'" + re.escape(tr) + r"'", re.S
        )
        updated, n = ternary.subn(f"context.t({key})", updated)
        replaced += n

        helper = re.compile(
            r"context\.s\(\s*'" + re.escape(ku) + r"'\s*,\s*'"
            + re.escape(tr) + r"'\s*,?\s*\)",
            re.S,
        )
        updated, n = helper.subn(f"context.t({key})", updated)
        replaced += n

    for pattern, replacement in SPECIAL:
        updated, n = re.subn(pattern, replacement, updated, flags=re.S)
        replaced += n

    if "import '../l10n/strings.dart';" not in updated:
        updated = updated.replace(
            "import '../l10n/lang.dart';",
            "import '../l10n/lang.dart';\nimport '../l10n/strings.dart';",
            1,
        )

    remaining = len(re.findall(r"(\bku\s*\?\s*['\"])|(\.s\(\s*['\"])", updated))
    print(f"değiştirilen: {replaced}, dosyada kalan satır içi: {remaining}")

    if args.dry_run:
        print("(dry-run — dosya yazılmadı)")
        return 0

    TARGET.write_text(updated, encoding="utf-8")
    print(f"yazıldı: {TARGET.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
