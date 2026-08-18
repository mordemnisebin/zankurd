from __future__ import annotations

import json
import os
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OFFLINE_BANK = ROOT / "lib" / "src" / "data" / "offline_question_bank.dart"
SOURCE_URL = "zankurd_offline_curated_2026_07_12"
BATCH_SIZE = 250


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing environment variable: {name}")
    return value


SUPABASE_URL = env("SUPABASE_URL").rstrip("/")
SERVICE_ROLE_KEY = env("SUPABASE_SERVICE_ROLE_KEY")


def request(method: str, path: str, body: object | None = None):
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        f"{SUPABASE_URL}/rest/v1/{path}",
        data=data,
        method=method,
        headers={
            "apikey": SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        },
    )
    with urllib.request.urlopen(req, timeout=60) as response:
        raw = response.read().decode("utf-8")
        if not raw:
            return None
        return json.loads(raw)


def dart_unquote(token: str) -> str:
    text = token[1:-1]
    text = text.replace("\\n", "\n")
    text = text.replace("\\'", "'").replace('\\"', '"')
    return text.replace("\\\\", "\\")


def parse_curated_questions() -> list[dict[str, object]]:
    content = OFFLINE_BANK.read_text(encoding="utf-8")
    questions: list[dict[str, object]] = []
    pos = 0
    string_re = r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\""

    while True:
        idx = content.find("QuizQuestion(", pos)
        if idx < 0:
            break
        start = idx + len("QuizQuestion(")
        depth = 1
        i = start
        in_string: str | None = None
        escaped = False
        while i < len(content) and depth > 0:
            char = content[i]
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == in_string:
                    in_string = None
            else:
                if char in {"'", '"'}:
                    in_string = char
                elif char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
            i += 1

        block = content[idx:i]
        pos = i
        id_match = re.search(r"id:\s*'([^']+)'", block)
        if not id_match or not id_match.group(1).startswith("offline_curated_"):
            continue

        def string_field(name: str) -> str:
            match = re.search(rf"{name}:\s*({string_re})", block, re.DOTALL)
            if not match:
                raise ValueError(f"Missing {name} in {id_match.group(1)}")
            return dart_unquote(match.group(1))

        answers_match = re.search(r"answers:\s*\[([\s\S]*?)\]", block)
        if not answers_match:
            raise ValueError(f"Missing answers in {id_match.group(1)}")
        answers = [dart_unquote(token) for token in re.findall(string_re, answers_match.group(1))]
        correct_answer = string_field("correctAnswer")
        correct_index = answers.index(correct_answer)
        type_match = re.search(r"type:\s*QuestionType\.(\w+)", block)
        question_type = type_match.group(1) if type_match else "multipleChoice"
        difficulty_match = re.search(r"difficulty:\s*(\d+)", block)

        padded = (answers + ["-", "-", "-", "-"])[:4]
        questions.append(
            {
                "category": string_field("category"),
                "prompt": string_field("prompt"),
                "option_a": padded[0],
                "option_b": padded[1],
                "option_c": padded[2],
                "option_d": padded[3],
                "correct_option": "ABCD"[correct_index],
                "explanation": string_field("explanation"),
                "difficulty": int(difficulty_match.group(1)) if difficulty_match else 2,
                "question_type": "true_false"
                if question_type == "trueFalse"
                else "multiple_choice",
            }
        )

    return questions


def main() -> None:
    categories = request("GET", "categories?select=id,name")
    category_ids = {row["name"]: row["id"] for row in categories}
    questions = parse_curated_questions()
    missing = sorted({str(q["category"]) for q in questions} - set(category_ids))
    if missing:
        raise SystemExit(f"Missing categories in Supabase: {', '.join(missing)}")

    source_filter = urllib.parse.quote(f"eq.{SOURCE_URL}", safe="=.")
    request("DELETE", f"questions?source_url={source_filter}")

    rows = []
    for question in questions:
        row = dict(question)
        row["category_id"] = category_ids[str(row.pop("category"))]
        row["language_code"] = "ku-kmr"
        row["is_approved"] = True
        row["image_url"] = None
        row["source_url"] = SOURCE_URL
        rows.append(row)

    for start in range(0, len(rows), BATCH_SIZE):
        request("POST", "questions", rows[start : start + BATCH_SIZE])
        print(f"inserted {min(start + BATCH_SIZE, len(rows))}/{len(rows)}")

    print(f"Imported {len(rows)} questions with source_url={SOURCE_URL}")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as error:
        sys.stderr.write(error.read().decode("utf-8", errors="replace"))
        raise
