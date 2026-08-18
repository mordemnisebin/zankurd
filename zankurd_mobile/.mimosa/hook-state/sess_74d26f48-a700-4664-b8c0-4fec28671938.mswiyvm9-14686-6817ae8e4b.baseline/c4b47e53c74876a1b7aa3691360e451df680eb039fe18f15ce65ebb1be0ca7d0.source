import csv
import json
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "supabase" / "2026-07-14_wikidata_candidate_questions.csv"

QUERIES = [
    ("Geography", "SELECT DISTINCT ?entity ?entityLabel ?answer ?answerLabel WHERE { ?entity wdt:P31 wd:Q6256; wdt:P36 ?answer. SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". } } LIMIT 250", "country_capital"),
    ("Science & Nature", "SELECT DISTINCT ?entity ?entityLabel ?number WHERE { ?entity wdt:P31 wd:Q11344; wdt:P1086 ?number. SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". } } LIMIT 130", "element_atomic_number"),
    ("Geography", "SELECT DISTINCT ?entity ?entityLabel ?number WHERE { ?entity wdt:P31 wd:Q6256; wdt:P2046 ?number. SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". } } LIMIT 250", "country_area"),
    ("Ziman", "SELECT DISTINCT ?entity ?entityLabel ?answer ?answerLabel WHERE { ?entity wdt:P31 wd:Q6256; wdt:P37 ?answer. SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". } } LIMIT 250", "country_language"),
    ("Geography", "SELECT DISTINCT ?entity ?entityLabel ?number WHERE { ?entity wdt:P31/wdt:P279* wd:Q8502; wdt:P2044 ?number. SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". } } LIMIT 250", "mountain_elevation"),
    ("Geography", "SELECT DISTINCT ?entity ?entityLabel ?number WHERE { ?entity wdt:P31/wdt:P279* wd:Q355304; wdt:P2043 ?number. SERVICE wikibase:label { bd:serviceParam wikibase:language \"en\". } } LIMIT 250", "river_length"),
]

FIELDS = ["candidate_id", "source", "license", "source_category", "question_en", "answer_en", "option_a_en", "option_b_en", "option_c_en", "option_d_en", "correct_option", "source_entity", "translation_status", "editorial_status"]

def query(sparql):
    url = "https://query.wikidata.org/sparql?" + urllib.parse.urlencode({"query": sparql, "format": "json"})
    request = urllib.request.Request(url, headers={"User-Agent": "ZanKurd-Mobile-EditorialResearch/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)["results"]["bindings"]

def value(binding, key):
    return binding[key]["value"]

def main():
    rows = []
    for category, sparql, kind in QUERIES:
        bindings = query(sparql)
        answers = [value(item, "answerLabel") if kind in ("country_capital", "country_language") else value(item, "number") for item in bindings]
        for item in bindings:
            entity = value(item, "entityLabel")
            answer = value(item, "answerLabel") if kind in ("country_capital", "country_language") else value(item, "number")
            if kind == "country_capital":
                question = f"What is the capital city of {entity}?"
            elif kind == "element_atomic_number":
                question = f"What is the atomic number of the element {entity}?"
            elif kind == "country_area":
                question = f"What is the area of {entity}?"
            elif kind == "country_language":
                question = f"What is an official or national language associated with {entity}?"
            elif kind == "mountain_elevation":
                question = f"What is the elevation listed for {entity}?"
            else:
                question = f"What is the recorded length of the river {entity}?"
            distractors = [x for x in answers if x != answer][:3]
            if len(distractors) < 3:
                continue
            options = [answer] + distractors
            rows.append({
                "candidate_id": f"wikidata_{len(rows)+1:04d}",
                "source": "Wikidata SPARQL",
                "license": "CC0",
                "source_category": category,
                "question_en": question,
                "answer_en": answer,
                "option_a_en": options[0], "option_b_en": options[1], "option_c_en": options[2], "option_d_en": options[3],
                "correct_option": "A",
                "source_entity": value(item, "entity"),
                "translation_status": "NOT_TRANSLATED",
                "editorial_status": "SOURCE_CANDIDATE_ONLY",
            })
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader(); writer.writerows(rows)
    print(f"wrote {len(rows)} Wikidata candidates")

if __name__ == "__main__": main()
