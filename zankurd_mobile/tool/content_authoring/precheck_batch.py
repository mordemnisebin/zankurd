#!/usr/bin/env python3
"""Üretilen soru partisini `promote_question_bank.dart` kapısına sokmadan denetler.

Niçin var: kapı Dart tarafında koşar ve bir parti toptan reddedilirse gerekçeyi
`rejected_rows.csv`den okumak gerekir. Bu betik aynı kuralların ucuz olanlarını
üretimin hemen ardından uygular; böylece model çıktısı daha ilk turda
düzeltilebilir. Kapının yerine GEÇMEZ — pahalı kontroller (kanonik kopya
taraması, kategori dağılımı, dil uyumu) orada kalır.

Kurallar `tool/content_authoring/src/promotion.dart` içindeki
`content_promotion_v1` kapısından birebir alınmıştır.

Kullanım:
    python3 tool/content_authoring/precheck_batch.py parti.csv
"""
import csv
import re
import sys
from collections import Counter

REQUIRED = [
    "id", "language_code", "category_key", "prompt",
    "option_a", "option_b", "option_c", "option_d",
    "correct_option", "explanation", "difficulty",
    "source_verified", "source_url", "publication_status", "confidence",
]
VERIFIED = {"verified", "doğrulandı", "dogrulandi", "evet", "yes", "true"}
PUBLISHABLE = {"reviewed", "approved", "published"}
# Kapı bu sözcükleri çözülmemiş editoryal sorun sayar; not alanına yazılmamalı.
UNRESOLVED = ["şablon", "tekrar", "sablon"]
TURKISH_ONLY = re.compile(r"[ığöüİ]")


def norm(value: str) -> str:
    return " ".join((value or "").strip().lower().split())


def template_key(prompt: str) -> str:
    """Kapının şablon ölçüsünün kaba karşılığı: ilk üç sözcük + soru uzunluğu."""
    words = norm(prompt).split()
    return " ".join(words[:3]) + f"|{len(words)//5}"


def main(path: str) -> int:
    with open(path, newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        print("HATA: parti boş")
        return 1

    missing_cols = [c for c in REQUIRED if c not in rows[0]]
    if missing_cols:
        print(f"HATA: eksik sütunlar: {', '.join(missing_cols)}")
        return 1

    seen_ids, seen_prompts, seen_expl = set(), set(), set()
    templates = Counter()
    problems = []

    for i, row in enumerate(rows, start=2):
        bad = []
        rid = (row["id"] or "").strip()
        prompt = (row["prompt"] or "").strip()
        expl = (row["explanation"] or "").strip()
        options = [(row[f"option_{c}"] or "").strip() for c in "abcd"]

        if not rid:
            bad.append("missing_id")
        elif rid in seen_ids:
            bad.append("duplicate_id")
        seen_ids.add(rid)

        if (row["language_code"] or "").strip().lower() != "ku-kmr":
            bad.append("unsupported_locale")
        if not (row["category_key"] or "").strip():
            bad.append("missing_category")

        if not prompt:
            bad.append("empty_prompt")
        elif len(prompt.split()) < 5:
            bad.append("prompt_too_simple")
        elif norm(prompt) in seen_prompts:
            bad.append("canonical_duplicate")
        seen_prompts.add(norm(prompt))

        if len(options) != 4 or any(not o for o in options):
            bad.append("invalid_options")
        elif len({norm(o) for o in options}) != 4:
            bad.append("duplicate_option")

        correct = (row["correct_option"] or "").strip()
        if correct.upper() in {"A", "B", "C", "D"}:
            answer = options["ABCD".index(correct.upper())]
        else:
            matches = [o for o in options if norm(o) == norm(correct)]
            answer = matches[0] if len(matches) == 1 else ""
            if not answer:
                bad.append("invalid_correct_answer")

        if len(expl) < 24:
            bad.append("short_explanation")
        elif norm(expl) in seen_expl:
            bad.append("explanation_duplicate")
        elif answer and norm(expl).startswith(norm(answer)) and \
                len(norm(expl)) <= len(norm(answer)) + 18:
            bad.append("explanation_repeats_answer")
        seen_expl.add(norm(expl))

        try:
            difficulty = int((row["difficulty"] or "").strip())
            if difficulty < 1 or difficulty > 3:
                bad.append("invalid_difficulty")
        except ValueError:
            bad.append("missing_difficulty")

        try:
            if float((row["confidence"] or "").strip()) < 0.9:
                bad.append("low_confidence")
        except ValueError:
            bad.append("missing_confidence")

        if norm(row["source_verified"]) not in VERIFIED:
            bad.append("unverified_source")
        if not (row["source_url"] or "").strip().startswith("https://"):
            bad.append("missing_source_url")
        if norm(row["publication_status"]) not in PUBLISHABLE:
            bad.append("unpublishable_status")

        note = norm(row.get("notes", "") or "") + " " + norm(row.get("issue_type", "") or "")
        if any(word in note for word in UNRESOLVED):
            bad.append("editorial_issue")

        # Kurmancî taşıyıcı cümlede Türkçeye özgü harf olmamalı; tırnak içi
        # (çevrilecek Türkçe) muaf — `question_bank_kurmanci_carrier_test`
        # ile aynı kural.
        carrier = re.sub(r'"[^"]*"|\([^)]*\)', " ", prompt)
        if TURKISH_ONLY.search(carrier):
            bad.append("turkish_letter_in_kurmanci")

        key = template_key(prompt)
        templates[key] += 1
        if templates[key] > 3:
            bad.append("template_density")

        if bad:
            problems.append((i, rid or "?", bad))

    print(f"satır: {len(rows)}   sorunlu: {len(problems)}   temiz: {len(rows) - len(problems)}")
    if problems:
        counts = Counter(r for _, _, reasons in problems for r in reasons)
        print("\ngerekçeler:")
        for reason, n in counts.most_common():
            print(f"  {n:5d}  {reason}")
        print("\nilk 15 sorunlu satır:")
        for line, rid, reasons in problems[:15]:
            print(f"  satır {line} ({rid}): {', '.join(reasons)}")
    return 1 if problems else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
