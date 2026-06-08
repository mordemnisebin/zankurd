from __future__ import annotations

import csv
import json
from pathlib import Path
from urllib.request import Request, urlopen

import runpy


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "supabase" / "rich_question_bank_v2_questions.csv"
SUPABASE_URL = "https://hupivnxgjtsfafulzspo.supabase.co"
SUPABASE_KEY = "sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s"


def load_category_ids() -> dict[str, str]:
    request = Request(
        f"{SUPABASE_URL}/rest/v1/categories?select=id,name",
        headers={
            "apikey": SUPABASE_KEY,
            "Authorization": f"Bearer {SUPABASE_KEY}",
        },
    )
    with urlopen(request, timeout=30) as response:
        rows = json.loads(response.read().decode("utf-8"))
    return {row["name"]: row["id"] for row in rows}


def main() -> None:
    ns = runpy.run_path(str(ROOT / "tools" / "generate_rich_question_bank.py"))
    questions = ns["build_questions"]()
    category_ids = load_category_ids()

    missing = sorted({str(q["category"]) for q in questions} - set(category_ids))
    if missing:
        raise SystemExit(f"Missing category IDs in Supabase: {', '.join(missing)}")

    with OUTPUT.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "category_id",
                "language_code",
                "prompt",
                "option_a",
                "option_b",
                "option_c",
                "option_d",
                "correct_option",
                "explanation",
                "difficulty",
                "is_approved",
                "question_type",
                "image_url",
                "source_url",
            ],
        )
        writer.writeheader()
        for question in questions:
            writer.writerow(
                {
                    "category_id": category_ids[str(question["category"])],
                    "language_code": "ku-kmr",
                    "prompt": question["prompt"],
                    "option_a": question["a"],
                    "option_b": question["b"],
                    "option_c": question["c"],
                    "option_d": question["d"],
                    "correct_option": question["correct"],
                    "explanation": question["explanation"],
                    "difficulty": question["difficulty"],
                    "is_approved": "true",
                    "question_type": question["question_type"],
                    "image_url": question["image"],
                    "source_url": ns["SOURCE"],
                }
            )

    print(f"Wrote {len(questions)} rows to {OUTPUT}")


if __name__ == "__main__":
    main()
