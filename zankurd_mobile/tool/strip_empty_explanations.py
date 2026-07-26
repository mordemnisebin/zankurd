#!/usr/bin/env python3
"""Soru bankasından bilgi taşımayan açıklamaları temizler.

2026-07-25 canlı denetimi: soruların %42'sinde "Açıklama · Zana" paneli
açılıyor ama panel hiçbir şey öğretmiyordu. Üç kalıp vardı:

  1. Doğru/yanlış gürültüsü — "…îdiaya di vê pirsê de ne rast e; bersiva
     rast 'Şaş' e." Cevabın kendisi zaten ekranda yeşil olarak gösteriliyor;
     bu cümle onu tekrar etmekten başka bir şey yapmıyor.

  2. Kategori dolgusu — "misafirperverlik Kürt kültürü kategorisinde ele
     alınır." Kategori zaten soru kartının üstünde bir çip olarak yazıyor.

  3. Terim↔tanım tekrarı — "«X» tê vê wateyê: [sorudaki tanım]". Bu KORUNUR:
     öğrenen için terim ile tanımı yan yana görmek eşleştirmeyi pekiştirir,
     yani teknik olarak tekrar olsa da işlevi var.

Yalnız (1) ve (2) silinir. Boş açıklamada uygulama paneli hiç açmaz
(bkz. `_ExplanationBox`), yani sonuç "öğretmeyen panel" yerine "panel yok"
olur — sessiz ama dürüst.

Kullanım:
    python3 tool/strip_empty_explanations.py [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

BANK = Path(__file__).resolve().parent.parent / "assets/data/offline_questions.json"

# (1) Doğru/yanlış gürültüsü: cevabı tekrar eden şablon.
TRUE_FALSE_NOISE = re.compile(
    r"(îdiaya di vê pirsê de|bersiva rast\s*['«])", re.IGNORECASE
)

# (2) Kategori/alan dolgusu: soru kartında zaten yazan kategoriyi tekrar
# eden, hiçbir tanım taşımayan cümleler.
CATEGORY_FILLER = re.compile(
    r"(kategorisinde ele alınır|kategorisinde değerlendirilir"
    r"|têgeheke derbasdar e|geçerli bir kavramdır"
    r"|de tê nirxandin|kategoriyê de tê|de cih digire)",
    re.IGNORECASE,
)

# (3) Korunacak kalıp — terim↔tanım eşleştirmesi.
TERM_DEFINITION = re.compile(r"tê vê wateyê", re.IGNORECASE)


def is_worthless(explanation: str) -> bool:
    """Açıklama hiçbir bilgi taşımıyor mu?"""
    text = (explanation or "").strip()
    if not text:
        return False  # zaten boş
    if TERM_DEFINITION.search(text):
        return False  # korunur
    if TRUE_FALSE_NOISE.search(text):
        return True
    if CATEGORY_FILLER.search(text):
        return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    questions = json.loads(BANK.read_text(encoding="utf-8"))
    stripped = 0
    for question in questions:
        for field in ("explanation", "explanationKu", "explanationTr"):
            value = question.get(field)
            if value and is_worthless(value):
                question[field] = ""
                stripped += 1

    total = len(questions)
    print(f"soru: {total}, temizlenen açıklama alanı: {stripped}")

    if args.dry_run:
        print("(dry-run — dosya yazılmadı)")
        return 0

    BANK.write_text(
        json.dumps(questions, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"yazıldı: {BANK.relative_to(BANK.parent.parent.parent)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
