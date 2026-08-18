#!/usr/bin/env python3
"""Kullanılmayan tematik görselleri uygun sorulara bağlar.

2026-07-25 denetimi: soruların yalnız %2.8'i görselliydi, oysa
`assets/question_images/` altında hiçbir soruya bağlanmamış 12 tematik
görsel duruyordu. Bu araç onları konusu örtüşen sorulara bağlar.

Eşleşme *muhafazakâr*: her görsel için yalnız ayırt edici bir terimi
sözcük sınırıyla içeren sorular aday olur ve görsel başına en fazla bir
soru işaretlenir. Zorlama eşleşme, alakasız bir görselle soruyu
kafa karıştırıcı hâle getirir — az ama doğru görsel, çok ama yanlış
görselden iyidir.

Kullanım:
    python3 tool/assign_unused_question_images.py [--dry-run]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANK = ROOT / "assets/data/offline_questions.json"
IMAGE_DIR = "asset://assets/question_images"

# Görsel → o görseli gerçekten anlatan, ayırt edici terimler.
# Genel sözcükler (el, aş, dar…) bilinçli olarak yok: yüzlerce alakasız
# soruyla eşleşiyorlardı.
MATCHES: dict[str, list[str]] = {
    "diyalog": ["diyalog"],
    "govend": ["govend"],
    "kilim_motifleri": ["kilim", "motîf", "motif"],
    "mecaz": ["mecaz"],
    "melodi": ["melodî", "makam"],
    "mezopotamya": ["mezopotamya"],
    "sinor": ["sînor"],
    "karakter": ["karakter"],
    "daristan": ["daristan"],
    "halk_mutfagi": ["xwarin", "mitbax"],
    "tarihsel_yorum": ["şirove"],
    "dest": ["destan"],
}


def word_pattern(term: str) -> re.Pattern[str]:
    return re.compile(rf"(?<!\w){re.escape(term)}(?!\w)", re.IGNORECASE)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    questions = json.loads(BANK.read_text(encoding="utf-8"))
    without_image = [q for q in questions if not q.get("imageUrl")]

    assigned = 0
    report: list[str] = []
    for image, terms in MATCHES.items():
        patterns = [word_pattern(t) for t in terms]
        candidate = None
        for question in without_image:
            prompt = question.get("prompt", "") or ""
            if any(p.search(prompt) for p in patterns):
                candidate = question
                break
        if candidate is None:
            report.append(f"  {image:18s} → eşleşme yok")
            continue
        candidate["imageUrl"] = f"{IMAGE_DIR}/{image}.webp"
        candidate["type"] = "visual"
        without_image.remove(candidate)
        assigned += 1
        report.append(f"  {image:18s} → {candidate['id']}: "
                      f"{candidate['prompt'][:56]}")

    visual_before = sum(1 for q in questions if q.get("imageUrl")) - assigned
    print(f"görselli soru: {visual_before} → {visual_before + assigned}")
    print("\n".join(report))

    if args.dry_run:
        print("(dry-run — dosya yazılmadı)")
        return 0

    BANK.write_text(
        json.dumps(questions, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"yazıldı: {BANK.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
