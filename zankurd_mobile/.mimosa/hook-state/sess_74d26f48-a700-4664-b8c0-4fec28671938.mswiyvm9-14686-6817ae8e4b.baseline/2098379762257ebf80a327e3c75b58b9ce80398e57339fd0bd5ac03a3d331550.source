import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUPABASE = ROOT / "supabase"
OUT = SUPABASE / "2026-07-14_chat_all_kurmanci_questions_live.csv"

FILES = [
    SUPABASE / "2026-07-14_all_generated_questions_master.csv",
    SUPABASE / "2026-07-14_opentdb_translated_batch_3.csv",
    SUPABASE / "2026-07-14_opentdb_translated_batch_4.csv",
    SUPABASE / "2026-07-14_opentdb_translated_batch_5.csv",
    SUPABASE / "2026-07-14_wikidata_translated_batch_1.csv",
    SUPABASE / "2026-07-14_wikidata_translated_batch_2.csv",
    SUPABASE / "2026-07-14_wikidata_translated_batch_3.csv",
]

FIELDS = [
    "id", "category_key", "language_code", "prompt", "option_a", "option_b",
    "option_c", "option_d", "correct_option", "explanation", "difficulty",
    "source_title", "source_url", "publication_status", "quality_note",
    "source_candidate_id",
]


def main():
    rows = []
    seen_ids = set()
    seen_prompts = set()
    for path in FILES:
        with path.open(encoding="utf-8-sig", newline="") as handle:
            for raw in csv.DictReader(handle):
                row = {field: raw.get(field, "") for field in FIELDS}
                key = row["prompt"].strip().casefold()
                if not row["id"] or not key:
                    raise ValueError(f"Missing id or prompt: {path.name}")
                if row["id"] in seen_ids:
                    raise ValueError(f"Duplicate id: {row['id']}")
                if key in seen_prompts:
                    raise ValueError(f"Duplicate prompt: {row['prompt']}")
                if row["language_code"] != "ku-kmr":
                    raise ValueError(f"Non-Kurmanci row: {row['id']}")
                if row["publication_status"] not in {"PENDING_EDITORIAL_APPROVAL", "APPROVED"}:
                    raise ValueError(f"Unexpected status: {row['id']}")
                seen_ids.add(row["id"])
                seen_prompts.add(key)
                rows.append(row)

    with OUT.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} unique Kurmanci questions to {OUT.name}")


if __name__ == "__main__":
    main()
