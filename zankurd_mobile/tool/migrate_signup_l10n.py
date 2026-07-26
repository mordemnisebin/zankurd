#!/usr/bin/env python3
"""Kayıt ekranındaki satır içi iki-dil metinlerini anahtar tabanlı kayda taşır.

Ayarlar / profil / giriş ekranlarıyla aynı yordam. Bu ekran giriş ekranıyla
birçok anahtarı paylaşır (e-posta, şifre doğrulama mesajları); paylaşılanlar
yeniden tanımlanmaz, mevcut anahtara bağlanır.

    python3 tool/migrate_signup_l10n.py [--dry-run]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TARGET = Path(__file__).resolve().parent.parent / "lib/src/screens/sign_up_screen.dart"

SIMPLE: dict[tuple[str, str], str] = {
    # Kayıt ekranına özgü
    ("Hemû zelatên pêwîst in", "Tüm alanlar gerekli"): "K.allFieldsRequired",
    ("Hesab tê afirandin...", "Hesap oluşturuluyor..."): "K.creatingAccount",
    ("Hesab hat afirandin! Ji bo pejirandinê e-peyama xwe kontrol bike.", "Hesap oluşturuldu! Doğrulamak için e-postanı kontrol et."): "K.accountCreated",
    ("Paş", "Geri"): "K.backStep",
    ("Hesab Biafirîne", "Hesap Oluştur"): "K.createAccount",
    ("Pêş", "İleri"): "K.nextStep",
    ("Hesabê te jixwe heye? ", "Zaten hesabın var mı? "): "K.haveAccountPrefix",
    ("E-posta û şîfreyê xwe têkeve", "E-postanızı ve parolayı girin"): "K.stepCredentials",
    ("Navê bikarhênerê xwe hilbijêre", "Kullanıcı adınızı seçin"): "K.stepUsername",
    ("Agahiya xwe nîqaş bikin", "Bilgilerinizi inceleyiniz"): "K.stepReview",
    ("Herî kêm 6 tîp", "En az 6 karakter"): "K.passwordHintMin6",
    ("Şîfreyê piştrast bike", "Parolayı Onayla"): "K.confirmPassword",
    ("Piştrastkirina şîfreyê pêwîst e", "Parola onayı gerekli"): "K.confirmPasswordRequired",
    ("Şîfre li hev nakin", "Parolalar eşleşmiyor"): "K.passwordsMismatch",
    ("Navê bikarhêner", "Kullanıcı adı"): "K.username",
    ("Navê bikarhêner pêwîst e", "Kullanıcı adı gerekli"): "K.usernameRequired",
    ("Navê bikarhêner divê herî kêm 2 tîp be", "Kullanıcı adı en az 2 karakter olmalı"): "K.usernameMin2",
    ("E-peyam:", "E-posta:"): "K.emailColon",
    ("Navê bikarhêner:", "Kullanıcı adı:"): "K.usernameColon",
    ("Şîfre:", "Parola:"): "K.passwordColon",
    ("Hesabê xwe biafirîne", "Hesabını oluştur"): "K.createYourAccount",
    # Giriş ekranıyla paylaşılanlar — yeni anahtar açılmaz.
    ("Têkeve", "Giriş Yap"): "K.signIn",
    ("Navnîşana e-peyamê", "E-posta adresi"): "K.emailAddress",
    ("E-peyam pêwîst e", "E-posta gerekli"): "K.emailRequired",
    ("E-peyameke derbasdar binivîse", "Geçerli bir e-posta gir"): "K.emailInvalid2",
    ("Şîfre", "Parola"): "K.passwordLabel",
    ("Şîfre pêwîst e", "Parola gerekli"): "K.passwordRequired",
    ("Şîfre divê herî kêm 6 tîp be", "Parola en az 6 karakter olmalı"): "K.passwordMin6",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    source = TARGET.read_text(encoding="utf-8")
    updated = source
    replaced = 0

    # Uzun metinler önce denenir: "Şîfre" kısa kalıbı "Şîfre pêwîst e"
    # içindeki alt dizgiyi yakalamasın diye sıralama uzunluğa göre yapılır.
    ordered = sorted(SIMPLE.items(), key=lambda kv: -len(kv[0][0]))

    for (ku, tr), key in ordered:
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
