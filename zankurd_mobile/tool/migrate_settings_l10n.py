#!/usr/bin/env python3
"""Ayarlar ekranındaki satır içi iki-dil metinlerini anahtar tabanlı kayda taşır.

2026-07-25 denetimi: uygulama metinleri çağrı yerinde `ku ? 'x' : 'y'` ya da
`context.s('x', 'y')` biçiminde duruyor — iki dil varsayımı koda gömülü.
Üçüncü bir dil (Soranî, Zazakî, İngilizce) bu imzayı kırar.

`AGENTS.md` büyük refactor'ü yasakladığı için göç ekran ekran yapılır.
Ayarlar, 66 kullanımla en yoğun dosya; bu betik onu taşır.

Betik tek seferlik değil, tekrar çalıştırılabilir (idempotent): eşleşme
bulamazsa hiçbir şey yapmaz.

    python3 tool/migrate_settings_l10n.py [--dry-run]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TARGET = Path(__file__).resolve().parent.parent / "lib/src/screens/settings_screen.dart"

# (Kurmancî, Türkçe) -> anahtar sabiti
SIMPLE: dict[tuple[str, str], str] = {
    ("Mîheng", "Ayarlar"): "K.settings",
    ("Ziman, dîmen, deng û hesab.", "Dil, görünüm, ses ve hesap."): "K.settingsSubtitle",
    ("Hesap", "Hesap"): "K.secAccount",
    ("Navê lîstikvanê", "Oyuncu Adı"): "K.playerName",
    ("Navê xwe binivîse...", "Oyundaki adını gir..."): "K.playerNameHint",
    ("Hînbûn", "Öğrenme"): "K.secLearning",
    ("Asta xwe ji nû ve diyar bike", "Seviyeni yeniden belirle"): "K.retakePlacement",
    ("Kurt sînavek bê tade", "Kısa, baskısız bir sınav"): "K.retakePlacementSub",
    ("Ewlekarî", "Güvenlik"): "K.secSafety",
    ("Moda zaroka ewle", "Güvenli çocuk modu"): "K.childSafeMode",
    ("Dîmen", "Görünüm"): "K.secAppearance",
    ("Zimanê sepanê", "Uygulama dili"): "K.appLanguage",
    ("Modê tarî/ronahî", "Karanlık/Aydınlık mod"): "K.darkLightMode",
    ("Tevgerê kêm bike", "Hareketi azalt"): "K.reduceMotion",
    ("Deng û Agahdarî", "Ses & Bildirim"): "K.secSoundNotif",
    ("Deng û mûzîk", "Ses efektleri"): "K.soundEffects",
    ("Bîranîna rojane", "Günlük hatırlatıcı"): "K.dailyReminder",
    ("Deng-xwendin", "Seslendirme"): "K.secTts",
    ("Hemû taybetmendiyên premium vekirî ne", "Tüm premium özellikler aktif"): "K.premiumActive",
    ("Premium bibe", "Premium ol"): "K.premiumCta",
    (
        "Parastina xweber a zincîrê û piştgiriya ZanKurdê",
        "Otomatik seri koruması ve ZanKurd'a destek",
    ): "K.premiumPerks",
    ("VEKIRÎ", "AKTİF"): "K.premiumBadgeOn",
    ("BIGIRE", "BAŞLA"): "K.premiumBadgeOff",
    ("Derbarê Sepanê", "Uygulama Hakkında"): "K.secAbout",
    ("Çawa tê lîstin?", "Nasıl oynanır?"): "K.howToPlay",
    ("Nepenî", "Gizlilik"): "K.privacy",
    ("Guherto", "Sürüm"): "K.version",
    ("Her guhertin di vê amûrê de tavilê tê sepandin.", "Yaptığın değişiklikler bu cihazda anında uygulanır."): "K.localChangesNote",
    ("Karên Hesabê", "Hesap İşlemleri"): "K.secDanger",
    ("Ev kar nayên vegerandin.", "Bu alandaki işlemler geri alınamaz."): "K.dangerNote",
    ("Hesabê Min Jê Bibe", "Hesabımı Sil"): "K.deleteAccount",
    ("Profîl, coin û pirsên tomarkirî tên jêbirin.", "Profil, coin ve kaydedilen soru verilerin silinir."): "K.deleteAccountSub",
    ("Destûra agahdariyê tune ye", "Bildirim izni verilmedi"): "K.notifPermDenied",
    ("Baş e", "Tamam"): "K.ok",
    ("Betal", "Vazgeç"): "K.cancel",
    ("Veke", "Aç"): "K.openSettings",
    ("Hesabê bi dawî jê bibî?", "Hesabı kalıcı olarak sil?"): "K.deleteConfirmTitle",
    ("Ev çalakî venagere. Profîl, coin, pirsên tomarkirî û daneyên kesane yên hesabê te tên jêbirin.", "Bu işlem geri alınamaz. Profil, coin, kaydedilen sorular ve hesabına bağlı kişisel veriler silinir."): "K.deleteConfirmBody",
    ("Berdewam Bike", "Devam Et"): "K.continueAction",
    ("JÊ BIBE", "SIL"): "K.deleteWord",
    ("Erêkirina dawî", "Son onay"): "K.finalConfirm",
    ("Bi Dawî Jê Bibe", "Kalıcı Olarak Sil"): "K.deleteForever",
    ("Deng-xwendin li vê amûrê nayê bikaranîn.", "Seslendirme bu cihazda kullanılamıyor."): "K.ttsUnavailable",
    ("Deng-xwendinê veke", "Seslendirmeyi aç"): "K.ttsEnable",
    ("Pirs û şîroveyan bi deng bixwîne", "Soru ve açıklamaları sesli okut"): "K.ttsEnableSub",
    ("Leza xwendinê", "Konuşma hızı"): "K.ttsRate",
    ("Bilindahiya deng", "Ses seviyesi"): "K.ttsVolume",
}

# Değişken içeren metinler: yer tutucuya çevrilir.
PARAMETERIZED: list[tuple[str, str]] = [
    (
        r"ku\s*\?\s*'Asta te ya niha: \$name'\s*:\s*'Mevcut seviyen: \$name'",
        "context.t(K.currentLevel, {'name': name})",
    ),
    (
        r"ku\s*\?\s*'Her roj di demjimêr \$_notificationTime de'\s*:\s*'Her gün saat \$_notificationTime'",
        "context.t(K.dailyReminderAt, {'time': _notificationTime})",
    ),
    (
        r"ku\s*\?\s*'Demê biguherîne: \$_notificationTime'\s*:\s*'Saati değiştir: \$_notificationTime'",
        "context.t(K.changeTime, {'time': _notificationTime})",
    ),
    (
        r"ku\s*\?\s*'Ji bo jêbirina hesabê \"\$confirmWord\" binivîse\.'"
        r"\s*:\s*'Hesabını silmek için \"\$confirmWord\" yaz\.'",
        "context.t(K.deleteTypeWord, {'word': confirmWord})",
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
            r"ku\s*\?\s*'" + re.escape(ku) + r"'\s*:\s*'" + re.escape(tr) + r"'",
            re.S,
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

    for pattern, replacement in PARAMETERIZED:
        updated, n = re.subn(pattern, replacement, updated, flags=re.S)
        replaced += n

    if "import '../l10n/strings.dart';" not in updated:
        updated = updated.replace(
            "import '../l10n/lang.dart';",
            "import '../l10n/lang.dart';\nimport '../l10n/strings.dart';",
            1,
        )

    remaining = len(
        re.findall(r"(\bku\s*\?\s*['\"])|(\.s\(\s*['\"])", updated)
    )
    print(f"değiştirilen: {replaced}, dosyada kalan satır içi: {remaining}")

    if args.dry_run:
        print("(dry-run — dosya yazılmadı)")
        return 0

    TARGET.write_text(updated, encoding="utf-8")
    print(f"yazıldı: {TARGET.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
