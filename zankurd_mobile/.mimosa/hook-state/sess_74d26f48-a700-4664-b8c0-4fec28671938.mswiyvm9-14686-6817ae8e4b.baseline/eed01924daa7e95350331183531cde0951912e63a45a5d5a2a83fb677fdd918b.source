import csv
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "supabase" / "2026-07-14_opentdb_remaining_categories_candidates.csv"

CATEGORIES = {
    10: "Entertainment: Books", 11: "Entertainment: Film", 12: "Entertainment: Music",
    13: "Entertainment: Musicals & Theatres", 14: "Entertainment: Television", 15: "Entertainment: Video Games",
    16: "Entertainment: Board Games", 18: "Science: Computers", 19: "Science: Mathematics",
    20: "Mythology", 21: "Sports", 26: "Celebrities", 27: "Animals", 28: "Vehicles",
    29: "Entertainment: Comics", 30: "Science: Gadgets", 31: "Entertainment: Japanese Anime & Manga",
    32: "Entertainment: Cartoon & Animations",
}

FIELDS = ["candidate_id", "source", "license", "source_category", "difficulty", "prompt_en", "option_a_en", "option_b_en", "option_c_en", "option_d_en", "correct_option", "translation_status", "editorial_status"]

def decode(value):
    return urllib.parse.unquote(value)

def fetch(category_id):
    for amount in (50, 25, 10, 5, 1):
        url = f"https://opentdb.com/api.php?amount={amount}&category={category_id}&type=multiple&encode=url3986"
        request = urllib.request.Request(url, headers={"User-Agent": "ZanKurd-Mobile-EditorialResearch/1.0"})
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
        if payload.get("response_code") == 0:
            return payload["results"]
        time.sleep(5.2)
    raise RuntimeError(f"OpenTDB returned no usable batch for category {category_id}")

def main():
    rows = []
    for category_id, category_name in CATEGORIES.items():
        for item in fetch(category_id):
            options = [decode(item["correct_answer"])] + [decode(x) for x in item["incorrect_answers"]]
            rows.append({
                "candidate_id": f"opentdb_remaining_{len(rows)+1:04d}",
                "source": "Open Trivia Database API",
                "license": "CC BY-SA 4.0",
                "source_category": category_name,
                "difficulty": item["difficulty"],
                "prompt_en": decode(item["question"]),
                "option_a_en": options[0], "option_b_en": options[1], "option_c_en": options[2], "option_d_en": options[3],
                "correct_option": "A", "translation_status": "NOT_TRANSLATED", "editorial_status": "SOURCE_CANDIDATE_ONLY",
            })
        if category_id != list(CATEGORIES)[-1]:
            time.sleep(5.2)
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader(); writer.writerows(rows)
    print(f"wrote {len(rows)} candidates")

if __name__ == "__main__": main()
