import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUPABASE = ROOT / "supabase"
OUT = SUPABASE / "2026-07-14_open_web_candidate_pool_master.csv"

FIELDS = ["candidate_id", "source", "license", "source_category", "difficulty", "prompt_en", "option_a_en", "option_b_en", "option_c_en", "option_d_en", "correct_option", "source_entity", "translation_status", "editorial_status"]

def main():
    rows = []
    for name in ["2026-07-14_opentdb_candidate_pool.csv", "2026-07-14_opentdb_remaining_categories_candidates.csv"]:
        with (SUPABASE / name).open(encoding="utf-8-sig", newline="") as f:
            rows.extend({field: row.get(field, "") for field in FIELDS} for row in csv.DictReader(f))
    with (SUPABASE / "2026-07-14_wikidata_candidate_questions.csv").open(encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            rows.append({
                "candidate_id": row["candidate_id"], "source": row["source"], "license": row["license"], "source_category": row["source_category"], "difficulty": "UNSET", "prompt_en": row["question_en"], "option_a_en": row["option_a_en"], "option_b_en": row["option_b_en"], "option_c_en": row["option_c_en"], "option_d_en": row["option_d_en"], "correct_option": row["correct_option"], "source_entity": row["source_entity"], "translation_status": row["translation_status"], "editorial_status": row["editorial_status"],
            })
    if len(rows) != len({r["candidate_id"] for r in rows}):
        raise ValueError("duplicate candidate ids")
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS); writer.writeheader(); writer.writerows(rows)
    print("candidates", len(rows), "sources", Counter(r["source"] for r in rows), "licenses", Counter(r["license"] for r in rows), "categories", len(Counter(r["source_category"] for r in rows)))

if __name__ == "__main__": main()
