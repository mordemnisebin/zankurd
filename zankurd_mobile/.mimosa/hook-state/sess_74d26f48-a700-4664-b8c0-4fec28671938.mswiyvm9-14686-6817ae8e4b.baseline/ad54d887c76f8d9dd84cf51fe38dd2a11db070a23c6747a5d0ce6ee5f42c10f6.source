import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "supabase" / "2026-07-14_wikidata_candidate_questions.csv"
OUT = ROOT / "supabase" / "2026-07-14_wikidata_translated_batch_3.csv"

SELECTED = [
    ("wikidata_0601", "Tanzanya", 1), ("wikidata_0602", "Iraq", 1), ("wikidata_0606", "Sri Lanka", 2), ("wikidata_0608", "Malî", 2),
    ("wikidata_0611", "Myanmar", 1), ("wikidata_0614", "Tacikistan", 1), ("wikidata_0618", "Îsraîl", 1), ("wikidata_0619", "Afganistan", 2),
    ("wikidata_0625", "Tûnis", 1), ("wikidata_0626", "Antigua û Barbuda", 2), ("wikidata_0627", "Grenada", 2), ("wikidata_0628", "Saint Vincent û Grenadînan", 2),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note", "source_candidate_id"]

def main():
    source_rows = {row["candidate_id"]: row for row in csv.DictReader(SOURCE.open(encoding="utf-8"))}
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS); writer.writeheader()
        for i, (candidate_id, country, difficulty) in enumerate(SELECTED, 1):
            row = source_rows[candidate_id]
            options = [row["option_a_en"], row["option_b_en"], row["option_c_en"], row["option_d_en"]]
            shift = (i - 1) % 4; options = options[shift:] + options[:shift]
            writer.writerow({"id": f"wikidata_translated_3_{i:04d}", "category_key": "Ziman", "language_code": "ku-kmr", "prompt": f"Kîjan ziman wekî zimanekî fermî an neteweyî bi {country} re tê girêdan?", "option_a": options[0], "option_b": options[1], "option_c": options[2], "option_d": options[3], "correct_option": "ABCD"[(4 - shift) % 4], "explanation": f"Li gorî daneyên strukturî yên Wikidata, {row['answer_en']} yek ji zimanên ku bi {country} re tê girêdan e; pirs îdîa nake ku ew tenê zimanê welatê ye.", "difficulty": difficulty, "source_title": "Wikidata SPARQL", "source_url": "https://www.wikidata.org/wiki/Wikidata:Licensing", "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "Ji daneyên CC0 yên Wikidata hatiye afirandin; peywendiya zimanî divê di kontrola dawî de bê rastkirin.", "source_candidate_id": candidate_id})
    print(f"wrote {len(SELECTED)} translated Wikidata language candidates")

if __name__ == "__main__": main()
