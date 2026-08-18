from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "supabase" / "wave2_curated_publish_candidates.csv"
OUTPUT = ROOT / "supabase" / "wave2_curated_publish_candidates.sql"


def sql(value: str) -> str:
    return "'" + (value or "").replace("'", "''") + "'"


def main() -> None:
    with INPUT.open(encoding="utf-8-sig", newline="") as file:
        rows = list(csv.DictReader(file))
    with OUTPUT.open("w", encoding="utf-8") as file:
        file.write("-- Curated AI-reviewed candidates; approval intentionally remains false.\n")
        file.write("insert into public.questions (category_id, language_code, prompt, option_a, option_b, option_c, option_d, correct_option, explanation, difficulty, is_approved, question_type, image_url, source_url) values\n")
        values = []
        for row in rows:
            options = [row["corrected_option_a"], row["corrected_option_b"], row["corrected_option_c"], row["corrected_option_d"]]
            values.append(
                "((select id from public.categories where name = {category}), {language}, {prompt}, {a}, {b}, {c}, {d}, {correct}, {explanation}, 2, false, 'multiple_choice', NULL, {source})".format(
                    category=sql(row["category_key"]),
                    language=sql(row["language_code"]),
                    prompt=sql(row["corrected_prompt"]),
                    a=sql(options[0]), b=sql(options[1]), c=sql(options[2]), d=sql(options[3]),
                    correct=sql(row["corrected_correct_option"]),
                    explanation=sql(row["corrected_explanation"]),
                    source=sql(row["better_source_url"] or "editorial_ai_review_pending"),
                )
            )
        file.write(",\n".join(values) + ";\n")
    print(f"Wrote {len(rows)} curated candidates to {OUTPUT}")


if __name__ == "__main__":
    main()
