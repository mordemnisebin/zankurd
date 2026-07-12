from __future__ import annotations

import json
import os
import urllib.parse
import urllib.request


SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SUPABASE_SERVICE_ROLE_KEY"]
SOURCE_URL = "zankurd_offline_curated_2026_07_12"


def rest(path: str):
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}",
        headers={
            "apikey": KEY,
            "Authorization": f"Bearer {KEY}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=45) as response:
        return response, response.read().decode("utf-8")


def count(path: str) -> int:
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}",
        method="HEAD",
        headers={
            "apikey": KEY,
            "Authorization": f"Bearer {KEY}",
            "Prefer": "count=exact",
        },
    )
    with urllib.request.urlopen(req, timeout=45) as response:
        content_range = response.headers.get("content-range", "0-0/0")
        return int(content_range.rsplit("/", 1)[1])


def main() -> None:
    source = urllib.parse.quote(f"eq.{SOURCE_URL}", safe="=.")
    print(f"curated_questions={count(f'questions?source_url={source}')}")
    print(f"approved_questions={count('questions?is_approved=eq.true')}")

    _, categories_raw = rest("categories?select=name&order=name")
    categories = [row["name"] for row in json.loads(categories_raw)]
    print("categories=" + ",".join(categories))

    _, sample_raw = rest(
        f"questions?select=prompt,question_type,difficulty&source_url={source}&limit=3"
    )
    for index, row in enumerate(json.loads(sample_raw), start=1):
        print(
            f"sample_{index}={row['question_type']}|d{row['difficulty']}|"
            f"{row['prompt'][:90]}"
        )


if __name__ == "__main__":
    main()
