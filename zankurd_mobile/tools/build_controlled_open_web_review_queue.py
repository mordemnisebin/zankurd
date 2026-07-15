import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "supabase" / "2026-07-14_open_web_candidate_pool_master.csv"
OUT = ROOT / "supabase" / "2026-07-14_open_web_controlled_review_queue.csv"

FIELDS = ["candidate_id", "source", "license", "source_category", "difficulty", "prompt_en", "option_a_en", "option_b_en", "option_c_en", "option_d_en", "correct_option", "source_entity", "translation_status", "editorial_status", "controlled_disposition", "controlled_note"]

def main():
    rows = list(csv.DictReader(SOURCE.open(encoding="utf-8-sig", newline="")))
    seen = set(); output = []
    for row in rows:
        prompt_key = " ".join(row["prompt_en"].split()).casefold()
        if prompt_key in seen:
            disposition, note = "REJECT_DUPLICATE", "Exact normalized prompt already exists in the source pool."
        else:
            seen.add(prompt_key)
            if row["source"] == "Wikidata SPARQL":
                disposition, note = "TEMPLATE_TRANSLATION_REVIEW", "Structured CC0 fact; suitable for controlled Kurmancî template translation and fact check."
            else:
                disposition, note = "TRANSLATION_AND_EDITORIAL_REVIEW", "User-contributed CC BY-SA question; translate, verify, rewrite distractors and retain attribution."
        if row["source_category"] == "Science & Nature" and row["answer_en" if "answer_en" in row else "prompt_en"] == "":
            disposition, note = "MANUAL_REVIEW", "Missing structured answer field."
        output.append({**row, "controlled_disposition": disposition, "controlled_note": note})
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS); writer.writeheader(); writer.writerows(output)
    print("rows", len(output), "dispositions", Counter(r["controlled_disposition"] for r in output), "unique_prompts", len(seen))

if __name__ == "__main__": main()
