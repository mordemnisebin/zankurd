#!/usr/bin/env python3
"""Doğru cevaptan başka dilde olan çeldiricileri değiştirir.

Ölçüm (2026-07-27): on soruda çeldiricilerden biri doğru cevabın dilinde
değildi —

    Pira Malabadê li ser kîjan avê ye?
      ✓ Çemê Batmanê
        Safevi/İran            ← Türkçe, üstelik nehir bile değil

    Hilgirên herî girîng ên wêjeya devkî ya kurdî kî ne?
      ✓ Dengbêjler
        Tüccarlar              ← Türkçe

Dil farkı, bilgi gerektirmeyen bir ipucudur: Kurmancî şıklar arasındaki
tek Türkçe şık (ya da tersi) bakar bakmaz elenir. Dördü aynı çeldiriciyi
paylaşıyordu ("Türkiye'de yasal pro-Kürt/sol-demokratik parti siyaseti"),
yani tek bir bozuk kayıt dört soruya bulaşmıştı.

Düzeltme `fix_length_leak_distractors.py` ile aynı: uyumsuz çeldirici,
**aynı kategorideki başka soruların doğru cevaplarıyla** değiştirilir.
Onlar aynı dilde, benzer uzunlukta ve aynı biçimdedir; ödünç alınan metin
başka bir kavramı anlattığı için bu soruda yanlıştır.

Bir soru elle düzeltildi: `offline_2246`'da "uyumsuz" olan doğru cevabın
kendisiydi — rojnameya "Kürdistan", Türkçe imlayla yazılmıştı. Kurmancî
şıkların arasında tek Türkçe yazım, doğru cevabı işaret ediyordu. Ad
Kurmancî imlayla "Kurdistan" yazılır; açıklamanın Kurmancîsi zaten öyle
diyordu.

Güvenlik ölçütleri bekçilerle aynı: aynı dil, aynı tarih-biçimi, gövdede
geçmeyen, yinelenmeyen ve doğru cevaba eşit olmayan şık. Doğru cevabın
ham dizini korunur — yoksa bankanın A/B/C/D dengesi bozulur.
"""
import json
import random
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets/data"
BANKS = ["offline_questions.json", "editorial_questions.json"]

KU_CHARS = set("îûêÎÛÊ")
TR_CHARS = set("ığöüİĞÖÜ")
YEAR_LIKE = re.compile(r"(\b\d{3,4}\b|yüzyıl|sedsal|y\.y\.|m\.ö|b\.z\.)", re.I)


def language(text: str):
    ku = any(c in KU_CHARS for c in text)
    tr = any(c in TR_CHARS for c in text)
    if ku and not tr:
        return "ku"
    if tr and not ku:
        return "tr"
    return None


def normalize(text: str) -> str:
    return " ".join(text.lower().split())


# Doğru cevabın kendisi yanlış imlayla yazılmış tek durum.
SPELLING_PATCHES = {"offline_2246": ("Kürdistan", "Kurdistan")}


def main() -> None:
    banks = {
        name: json.loads((ROOT / name).read_text(encoding="utf-8")) for name in BANKS
    }
    everything = [q for bank in banks.values() for q in bank]

    pool = defaultdict(list)
    for question in everything:
        pool[question["category"]].append(question["correctAnswer"])

    rng = random.Random(20260727)
    fixed = 0
    replaced = 0

    for bank in banks.values():
        for question in bank:
            patch = SPELLING_PATCHES.get(question["id"])
            if patch is not None:
                old, new = patch
                assert question["correctAnswer"] == old, question["id"]
                index = question["answers"].index(old)
                question["answers"][index] = new
                question["correctAnswer"] = new
            answers = question["answers"]
            correct = question["correctAnswer"]
            if len(answers) < 3:
                continue
            target_language = language(correct)
            if target_language is None:
                continue
            offenders = [
                a
                for a in answers
                if a != correct
                and language(a) is not None
                and language(a) != target_language
            ]
            if not offenders:
                continue

            prompt_norm = normalize(question["prompt"])
            used = {normalize(a) for a in answers}
            target_year_like = bool(YEAR_LIKE.search(correct))
            candidates = []
            seen = set()
            for candidate in pool[question["category"]]:
                key = normalize(candidate)
                if key in used or key in seen or key in prompt_norm:
                    continue
                if language(candidate) != target_language:
                    continue
                if bool(YEAR_LIKE.search(candidate)) != target_year_like:
                    continue
                if not (0.5 * len(correct) <= len(candidate) <= 1.5 * len(correct)):
                    continue
                seen.add(key)
                candidates.append(candidate)
            if len(candidates) < len(offenders):
                print(f"  atlandı (aday yok): {question['id']}")
                continue

            rng.shuffle(candidates)
            picked = iter(candidates)
            question["answers"] = [
                a if a not in offenders else next(picked) for a in answers
            ]
            replaced += len(offenders)
            fixed += 1

    for name, bank in banks.items():
        (ROOT / name).write_text(
            json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
    print(f"{fixed} soruda {replaced} yabancı dilli çeldirici değiştirildi.")


if __name__ == "__main__":
    main()
