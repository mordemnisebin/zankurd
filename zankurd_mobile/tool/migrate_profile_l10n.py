#!/usr/bin/env python3
"""Profil ekranındaki satır içi iki-dil metinlerini anahtar tabanlı kayda taşır.

Ayarlar ekranıyla aynı yordam (bkz. `migrate_settings_l10n.py`); yalnız metin
haritası değişir. Göç ekran ekran ilerliyor çünkü `AGENTS.md` tek seferlik
büyük refactor'ü yasaklıyor.

    python3 tool/migrate_profile_l10n.py [--dry-run]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TARGET = Path(__file__).resolve().parent.parent / "lib/src/screens/profile_screen.dart"

SIMPLE: dict[tuple[str, str], str] = {
    ("Profîl", "Profil"): "K.profileTitle",
    ("Profîl nehat barkirin", "Profil yüklenemedi"): "K.profileLoadFail",
    ("Girêdanê kontrol bike û dîsa biceribîne.", "Bağlantıyı kontrol edip tekrar dene."): "K.checkConnection",
    ("Dîsa biceribîne", "Tekrar dene"): "K.retry",
    ("Rêze", "Sıralama"): "K.statRank",
    ("Tevayî Xal", "Toplam Puan"): "K.statTotalScore",
    ("Pirsên Bersivandî", "Cevaplanan Soru"): "K.statAnswered",
    ("Rastî", "Doğruluk"): "K.statAccuracy",
    ("Statîstîkên Min", "İstatistiklerim"): "K.myStats",
    ("Analîza Berfireh", "Detaylı İstatistik"): "K.detailedStats",
    ("Performansa Heftane", "Haftalık Performans"): "K.weeklyPerformance",
    ("Performans nehat barkirin.", "Performans yüklenemedi."): "K.performanceLoadFail",
    ("Îro dest pê bike", "Bugün başla"): "K.startToday",
    ("FÊRBÛN", "ÖĞRENME"): "K.secLearningCaps",
    ("Pirsên Tomarkirî", "Kaydedilen Sorular"): "K.savedQuestions",
    ("Şaşiyên Min", "Yanlışlarım"): "K.myMistakes",
    ("Şaşiyek tune — aferîn!", "Hiç yanlışın yok — aferin!"): "K.noMistakes",
    ("Pirs Pêşniyar Bike", "Soru Öner"): "K.suggestQuestion",
    ("Pirsa xwe pêşniyar bike, piştî pejirandinê were zêdekirin", "Kendi sorunu öner, onaylandıktan sonra eklensin"): "K.suggestQuestionSub",
    ("HESAB", "HESAP"): "K.secAccountCaps",
    ("Hesabê Xwe Tomar Bike", "Hesabını Kaydet"): "K.saveAccount",
    ("E-posta û şîfreyekê binivîse — hesabê te yê mêvan bibe mayînde", "E-posta ve şifre belirle — misafir hesabın kalıcı olsun"): "K.saveAccountSub",
    ("E-posta û şîfreyekê binivîse da ku hesabê xwe yê mêvan bikî hesabê mayînde.", "Misafir hesabını kalıcı yapmak için e-posta ve şifre belirle."): "K.saveAccountBody",
    ("E-posta", "E-posta"): "K.email",
    ("E-postayek derbasdar binivîse", "Geçerli bir e-posta gir"): "K.emailInvalid",
    ("Şîfre", "Şifre"): "K.password",
    ("Şîfre divê herî kêm 6 tîpan be", "Şifre en az 6 karakter olmalı"): "K.passwordTooShort",
    ("an jî", "veya"): "K.orSeparator",
    ("Bi Google ve Girêde", "Google ile Bağla"): "K.linkGoogle",
    ("Hesabê te bi serkeftî hat tomarkirin!", "Hesabın başarıyla kaydedildi!"): "K.accountSaved",
    ("Bi Google ve tê girêdan...", "Google ile bağlanılıyor..."): "K.connectingGoogle",
    ("Derkeve", "Çıkış Yap"): "K.signOut",
    ("Tu dixwazî ji hesabê xwe derkevî?", "Hesabından çıkmak istiyor musun?"): "K.signOutConfirm",
    ("Betal", "Vazgeç"): "K.cancel",
    ("Tomar Bike", "Kaydet"): "K.save",
    ("Dukan", "Mağaza"): "K.shop",
    ("Mîheng", "Ayarlar"): "K.settings",
    ("Hemû pirsên şaş li benda dema dubarekirinê ne. Paşê biceribîne!", "Tüm yanlışlarınızın tekrar süreleri bekleniyor. Daha sonra tekrar deneyin!"): "K.allMistakesWaiting",
    ("Pirsên şaş tune. Pêşî pêşbirkekê bilîze!", "Tekrar edilecek yanlış yok. Önce bir yarış oyna!"): "K.noMistakesPlayFirst",
}

# `\n` içeren metin: kaçış dizisi ham olarak eşleşmeli.
MULTILINE = [
    (
        r"ku\s*\?\s*'Hîn dîroka lîstikê ya serhêl tune\.\\nBi yekê re bikevin an yek çêbikin\.'"
        r"\s*:\s*'Henüz çevrimiçi oyun geçmişin yok\.\\nBir odaya katıl veya oluştur\.'",
        "context.t(K.noOnlineHistory)",
    ),
    (
        r"ku\s*\?\s*'Ji bo dubarekirinê: \$_readyMistakeCount / Tevavî: \$_mistakeCount'"
        r"\s*:\s*'Tekrar Edilecek: \$_readyMistakeCount / Toplam: \$_mistakeCount'",
        "context.t(K.mistakeCounts, {"
        "'ready': '\\$_readyMistakeCount', 'total': '\\$_mistakeCount'})",
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

    for pattern, replacement in MULTILINE:
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
