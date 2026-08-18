from __future__ import annotations

import csv
import sys
from pathlib import Path

from editorial_audit import DEFAULT_SQL, sql_rows


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "supabase" / "2026-07-14_editorial_kurmanci_question_wave_2_for_ai_review.csv"


def main() -> None:
    source = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SQL
    rows = sql_rows(source.read_text(encoding="utf-8"))
    fields = [
        "review_id",
        "category_key",
        "language_code",
        "prompt",
        "option_a",
        "option_b",
        "option_c",
        "option_d",
        "correct_option",
        "correct_answer",
        "explanation",
        "difficulty",
        "question_type",
        "source_url",
        "automatic_audit_status",
        "human_or_ai_review_status",
        "review_notes",
    ]
    with OUTPUT.open("w", encoding="utf-8-sig", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader()
        for index, row in enumerate(rows, start=1):
            options = [row[key] for key in ("a", "b", "c", "d")]
            correct_index = "ABCD".index(row["correct"])
            writer.writerow(
                {
                    "review_id": f"wave2_{index:05d}",
                    "category_key": row["category"],
                    "language_code": "ku-kmr",
                    "prompt": row["prompt"],
                    "option_a": row["a"],
                    "option_b": row["b"],
                    "option_c": row["c"],
                    "option_d": row["d"],
                    "correct_option": row["correct"],
                    "correct_answer": options[correct_index],
                    "explanation": row["explanation"],
                    "difficulty": row["difficulty"],
                    "question_type": row["question_type"],
                    "source_url": row["source"],
                    "automatic_audit_status": "PASS",
                    "human_or_ai_review_status": "PENDING",
                    "review_notes": "",
                }
            )
    print(f"Wrote {len(rows)} rows to {OUTPUT}")


if __name__ == "__main__":
    main()
