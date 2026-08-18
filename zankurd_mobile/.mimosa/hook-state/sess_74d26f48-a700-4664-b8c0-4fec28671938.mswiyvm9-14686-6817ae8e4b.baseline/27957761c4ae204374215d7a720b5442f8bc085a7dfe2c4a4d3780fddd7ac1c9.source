import csv
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "supabase" / "2026-07-14_chat_all_kurmanci_questions_live.csv"
BATCH_SIZE = 100

BASE_URL = os.environ.get("SUPABASE_URL", "https://hupivnxgjtsfafulzspo.supabase.co").rstrip("/")
KEY = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s")


def request(method, path, body=None, prefer=None):
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
    headers = {
        "apikey": KEY,
        "Authorization": f"Bearer {KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if prefer:
        headers["Prefer"] = prefer
    req = urllib.request.Request(BASE_URL + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            raw = response.read().decode("utf-8")
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{method} {path} failed: HTTP {error.code}: {detail}") from error


def load_categories():
    status, data = request("GET", "/rest/v1/categories?select=id,name&order=name")
    if status != 200:
        raise RuntimeError(f"category read failed: {status}")
    categories = {row["name"]: row["id"] for row in data}
    missing = sorted({row["category_key"] for row in read_rows()} - categories.keys())
    for name in missing:
        slug = "".join(ch.lower() if ch.isalnum() else "-" for ch in name).strip("-")
        status, created = request(
            "POST", "/rest/v1/categories", {"name": name, "slug": slug, "is_active": True},
            prefer="return=representation",
        )
        if status not in (200, 201) or not created:
            raise RuntimeError(f"category create failed for {name}: {status}")
        categories[name] = created[0]["id"]
        print(f"created category: {name}")
    return categories


def read_rows():
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def load_existing_prompts():
    status, data = request("GET", "/rest/v1/questions?select=prompt&language_code=eq.ku-kmr&limit=10000")
    if status != 200:
        raise RuntimeError(f"question read failed: {status}")
    return {row["prompt"].strip().casefold() for row in data}


def main():
    rows = read_rows()
    categories = load_categories()
    existing = load_existing_prompts()
    new_rows = []
    for row in rows:
        prompt_key = row["prompt"].strip().casefold()
        if prompt_key in existing:
            continue
        new_rows.append({
            "category_id": categories[row["category_key"]],
            "language_code": "ku-kmr",
            "prompt": row["prompt"],
            "option_a": row["option_a"],
            "option_b": row["option_b"],
            "option_c": row["option_c"],
            "option_d": row["option_d"],
            "correct_option": row["correct_option"],
            "explanation": row["explanation"],
            "difficulty": int(row["difficulty"]),
            "is_approved": True,
            "question_type": "multiple_choice",
            "image_url": None,
            "source_url": row["source_url"],
        })
        existing.add(prompt_key)

    print(f"bundle={len(rows)} existing_or_duplicate={len(rows) - len(new_rows)} to_insert={len(new_rows)}")
    for start in range(0, len(new_rows), BATCH_SIZE):
        batch = new_rows[start:start + BATCH_SIZE]
        request("POST", "/rest/v1/questions", batch, prefer="return=minimal")
        print(f"inserted {min(start + BATCH_SIZE, len(new_rows))}/{len(new_rows)}")
    print("live import complete")


if __name__ == "__main__":
    main()
