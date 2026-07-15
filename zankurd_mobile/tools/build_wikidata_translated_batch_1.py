import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "supabase" / "2026-07-14_wikidata_candidate_questions.csv"
OUT = ROOT / "supabase" / "2026-07-14_wikidata_translated_batch_1.csv"

SELECTED = [
    ("wikidata_0001", "Awustralya", 1), ("wikidata_0002", "Misir", 1), ("wikidata_0003", "Macaristan", 1), ("wikidata_0004", "Paraguay", 2),
    ("wikidata_0005", "Belarûs", 2), ("wikidata_0006", "Qazaxistan", 2), ("wikidata_0007", "Kanada", 1), ("wikidata_0008", "Bosna û Herzegovina", 2),
    ("wikidata_0009", "Ukrayna", 2), ("wikidata_0010", "Spanya", 1), ("wikidata_0011", "Almanya", 1), ("wikidata_0013", "Grînland", 2),
    ("wikidata_0014", "Andorra", 2), ("wikidata_0015", "Kirîbatî", 2), ("wikidata_0016", "Swêd", 1), ("wikidata_0017", "Hindistan", 1),
    ("wikidata_0018", "Îzlanda", 1), ("wikidata_0019", "Hollanda", 1), ("wikidata_0020", "Timor-Rojhilat", 2), ("wikidata_0021", "Lîtvanya", 2),
    ("wikidata_0022", "Lîhtenştayn", 2), ("wikidata_0023", "Meksîko", 1), ("wikidata_0024", "Moldova", 2), ("wikidata_0025", "Norwêc", 1),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note", "source_candidate_id"]

def main():
    source_rows = {row["candidate_id"]: row for row in csv.DictReader(SOURCE.open(encoding="utf-8"))}
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS); writer.writeheader()
        for i, (candidate_id, country, difficulty) in enumerate(SELECTED, 1):
            row = source_rows[candidate_id]
            answer = row["answer_en"]
            options = [row["option_a_en"], row["option_b_en"], row["option_c_en"], row["option_d_en"]]
            shift = (i - 1) % 4
            options = options[shift:] + options[:shift]
            writer.writerow({"id": f"wikidata_translated_1_{i:04d}", "category_key": "Cografya", "language_code": "ku-kmr", "prompt": f"Paytexta {country} kîjan bajar e?", "option_a": options[0], "option_b": options[1], "option_c": options[2], "option_d": options[3], "correct_option": "ABCD"[(4 - shift) % 4], "explanation": f"Li gorî daneyên strukturî yên Wikidata, paytexta {country} {answer} e.", "difficulty": difficulty, "source_title": "Wikidata SPARQL", "source_url": "https://www.wikidata.org/wiki/Wikidata:Licensing", "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "Ji daneyên CC0 yên Wikidata hatiye afirandin; nav û bersivên cografî divê di kontrola dawî de bêne rastkirin.", "source_candidate_id": candidate_id})
    print(f"wrote {len(SELECTED)} translated Wikidata candidates")

if __name__ == "__main__": main()
