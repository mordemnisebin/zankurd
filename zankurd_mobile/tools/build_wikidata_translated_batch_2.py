import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "supabase" / "2026-07-14_wikidata_candidate_questions.csv"
OUT = ROOT / "supabase" / "2026-07-14_wikidata_translated_batch_2.csv"

SELECTED = [
    ("wikidata_0228", "lîtîyum", 1), ("wikidata_0231", "radium", 2), ("wikidata_0232", "brom", 1), ("wikidata_0233", "barîyum", 1),
    ("wikidata_0234", "sîlîkon", 1), ("wikidata_0235", "neptûnyum", 2), ("wikidata_0236", "osmîyum", 2), ("wikidata_0237", "selenyum", 2),
    ("wikidata_0238", "bor", 1), ("wikidata_0239", "karbon", 1), ("wikidata_0240", "tin", 1), ("wikidata_0241", "gallium", 2),
    ("wikidata_0242", "argon", 1), ("wikidata_0243", "cerium", 2), ("wikidata_0244", "indium", 2), ("wikidata_0245", "neodîmyum", 2),
    ("wikidata_0246", "plutonyum", 2), ("wikidata_0247", "itriyum", 2), ("wikidata_0248", "xenon", 1), ("wikidata_0249", "vanadyum", 2),
    ("wikidata_0250", "mes", 1), ("wikidata_0251", "antîmon", 2), ("wikidata_0252", "protaktînyum", 3), ("wikidata_0253", "manganez", 1),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note", "source_candidate_id"]

def main():
    source_rows = {row["candidate_id"]: row for row in csv.DictReader(SOURCE.open(encoding="utf-8"))}
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS); writer.writeheader()
        for i, (candidate_id, element, difficulty) in enumerate(SELECTED, 1):
            row = source_rows[candidate_id]
            options = [row["option_a_en"], row["option_b_en"], row["option_c_en"], row["option_d_en"]]
            shift = (i - 1) % 4
            options = options[shift:] + options[:shift]
            writer.writerow({"id": f"wikidata_translated_2_{i:04d}", "category_key": "Paradigma", "language_code": "ku-kmr", "prompt": f"Hejmara atomî ya elementê {element} çend e?", "option_a": options[0], "option_b": options[1], "option_c": options[2], "option_d": options[3], "correct_option": "ABCD"[(4 - shift) % 4], "explanation": f"Li gorî daneyên strukturî yên Wikidata, hejmara atomî ya elementê {element} {row['answer_en']} e.", "difficulty": difficulty, "source_title": "Wikidata SPARQL", "source_url": "https://www.wikidata.org/wiki/Wikidata:Licensing", "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "Ji daneyên CC0 yên Wikidata hatiye afirandin; nav û bersivên zanistî divê di kontrola dawî de bêne rastkirin.", "source_candidate_id": candidate_id})
    print(f"wrote {len(SELECTED)} translated Wikidata science candidates")

if __name__ == "__main__": main()
