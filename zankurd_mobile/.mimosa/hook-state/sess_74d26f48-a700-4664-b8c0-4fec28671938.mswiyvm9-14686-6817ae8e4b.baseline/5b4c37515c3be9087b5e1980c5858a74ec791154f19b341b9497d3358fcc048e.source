import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "supabase" / "2026-07-14_opentdb_candidate_pool.csv"

CATEGORIES = {
    9: "General Knowledge",
    17: "Science & Nature",
    22: "Geography",
    23: "History",
    24: "Politics",
    25: "Art",
}

FIELDS = ["candidate_id", "source", "license", "source_category", "difficulty", "prompt_en", "option_a_en", "option_b_en", "option_c_en", "option_d_en", "correct_option", "translation_status", "editorial_status"]

def decode(value):
    return urllib.parse.unquote(value)

def fetch(category_id):
    url = f"https://opentdb.com/api.php?amount=50&category={category_id}&type=multiple&encode=url3986"
    request = urllib.request.Request(url, headers={"User-Agent": "ZanKurd-Mobile-EditorialResearch/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        payload = json.load(response)
    if payload.get("response_code") != 0:
        raise RuntimeError(f"OpenTDB response code {payload.get('response_code')} for category {category_id}")
    return payload["results"]

def main():
    rows = []
    for category_id, category_name in CATEGORIES.items():
        for item in fetch(category_id):
            options = [decode(item["correct_answer"])] + [decode(x) for x in item["incorrect_answers"]]
            # Stable ordering keeps the raw candidate pool auditable; editorial import will reshuffle later.
            rows.append({
                "candidate_id": f"opentdb_{len(rows)+1:04d}",
                "source": "Open Trivia Database API",
                "license": "CC BY-SA 4.0",
                "source_category": category_name,
                "difficulty": item["difficulty"],
                "prompt_en": decode(item["question"]),
                "option_a_en": options[0],
                "option_b_en": options[1],
                "option_c_en": options[2],
                "option_d_en": options[3],
                "correct_option": "A",
                "translation_status": "NOT_TRANSLATED",
                "editorial_status": "SOURCE_CANDIDATE_ONLY",
            })
        if category_id != list(CATEGORIES)[-1]:
            time.sleep(5.2)

    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {len(rows)} OpenTDB candidates to {OUT}")

if __name__ == "__main__":
    main()
