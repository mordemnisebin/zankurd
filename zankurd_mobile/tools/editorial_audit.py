"""Kurmancî soru bankası için yayın öncesi editoryal kalite kapısı."""

from __future__ import annotations

import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SQL = ROOT / "supabase" / "2026-07-13_pure_kurmanci_question_wave_1.sql"
REPORT = ROOT / "reports" / "editorial_audit_report.md"

TURKISH_CHARS = set("ıüöğ")
MAX_SEMANTIC_SHAPE_COUNT = 12
EXPECTED_CATEGORIES = {
    "Ziman",
    "Edebiyat",
    "Dîrok",
    "Cografya",
    "Çand",
    "Muzîk",
    "Siyaset",
    "Paradigma",
}


def sql_rows(text: str) -> list[dict[str, str]]:
    def unescape(value: str) -> str:
        return value.replace("''", "'")

    rows = []
    for line in text.splitlines():
        if not line.startswith("((select id from public.categories where name = "):
            continue
        category, payload = line.split("'), 'ku-kmr', ", 1)
        category = category.rsplit("'", 1)[1]
        fields = []
        token = []
        quoted = False
        index = 0
        while index < len(payload):
            char = payload[index]
            if char == "'":
                if quoted and index + 1 < len(payload) and payload[index + 1] == "'":
                    token.append("''")
                    index += 2
                    continue
                quoted = not quoted
                token.append(char)
            elif char == "," and not quoted:
                fields.append("".join(token).strip())
                token = []
            else:
                token.append(char)
            index += 1
        fields.append("".join(token).strip().rstrip(");"))
        values = [field[1:-1] if field.startswith("'") and field.endswith("'") else field for field in fields]
        if len(values) < 12:
            continue
        values[11] = values[11].rstrip(")").strip("'")
        rows.append({
            "category": category,
            "prompt": unescape(values[0]),
            "a": unescape(values[1]),
            "b": unescape(values[2]),
            "c": unescape(values[3]),
            "d": unescape(values[4]),
            "correct": values[5],
            "explanation": unescape(values[6]),
            "difficulty": values[7],
            "question_type": values[9],
            "source": unescape(values[11]),
        })
    return rows


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value.casefold()).strip()


def semantic_shape(prompt: str) -> str:
    value = re.sub(r"'[^']*'", "<x>", prompt)
    value = re.sub(r"\s+", " ", value.casefold()).strip()
    return value


def audit(rows: list[dict[str, str]]) -> dict[str, object]:
    exact = Counter(normalize(row["prompt"]) for row in rows)
    shapes = Counter(semantic_shape(row["prompt"]) for row in rows)
    leaks = []
    bad_options = []
    for row in rows:
        options = [row[key] for key in ("a", "b", "c", "d")]
        correct_index = "ABCD".index(row["correct"])
        answer = normalize(options[correct_index])
        if len(answer) >= 6 and answer in normalize(row["prompt"]):
            leaks.append(row["prompt"])
        if row["question_type"] == "multiple_choice" and any(not option.strip() for option in options):
            bad_options.append(row["prompt"])

    categories = Counter(row["category"] for row in rows)
    sources = Counter(row["source"] for row in rows)
    turkish_hits = sorted({char for row in rows for char in " ".join(row.values()) if char in TURKISH_CHARS})
    repeated_shapes = {shape: count for shape, count in shapes.items() if count > MAX_SEMANTIC_SHAPE_COUNT}
    passed = bool(rows) and not (
        len(exact) != len(rows)
        or leaks
        or bad_options
        or turkish_hits
        or repeated_shapes
        or set(categories) != EXPECTED_CATEGORIES
        or len(sources) < 4
    )
    return {
        "rows": len(rows),
        "unique_prompts": len(exact),
        "categories": categories,
        "sources": sources,
        "leaks": leaks,
        "bad_options": bad_options,
        "turkish_hits": turkish_hits,
        "repeated_shapes": repeated_shapes,
        "passed": passed,
    }


def write_report(result: dict[str, object], path: Path = REPORT) -> None:
    path.parent.mkdir(exist_ok=True)
    categories = result["categories"]
    sources = result["sources"]
    repeated_shapes = result["repeated_shapes"]
    with path.open("w", encoding="utf-8") as report:
        report.write("# Editoryal Soru Bankası Denetimi\n\n")
        report.write(f"- Sonuç: **{'PASS' if result['passed'] else 'FAIL'}**\n")
        report.write(f"- Satır: {result['rows']}\n")
        report.write(f"- Benzersiz prompt: {result['unique_prompts']}\n")
        report.write(f"- Cevap sızıntısı: {len(result['leaks'])}\n")
        report.write(f"- Boş seçenek bulgusu: {len(result['bad_options'])}\n")
        report.write(f"- Türkçe karakter bulgusu: {', '.join(result['turkish_hits']) or 'yok'}\n")
        report.write(f"- Anlamsal şablon eşiğini aşan grup: {len(repeated_shapes)}\n")
        report.write(f"- Kaynak etiketi sayısı: {len(sources)}\n\n")
        report.write("## Kategori dağılımı\n\n")
        for category, count in sorted(categories.items()):
            report.write(f"- {category}: {count}\n")
        report.write("\n## Kaynak dağılımı\n\n")
        for source, count in sources.most_common():
            report.write(f"- `{source}`: {count}\n")
        report.write("\n## En yoğun anlamsal şablonlar\n\n")
        for shape, count in sorted(repeated_shapes.items(), key=lambda item: item[1], reverse=True)[:20]:
            report.write(f"- {count}x: `{shape}`\n")


def main() -> int:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SQL
    rows = sql_rows(path.read_text(encoding="utf-8"))
    result = audit(rows)
    write_report(result)
    print(f"editorial-audit={'PASS' if result['passed'] else 'FAIL'} rows={result['rows']} semantic_groups={len(result['repeated_shapes'])}")
    return 0 if result["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
