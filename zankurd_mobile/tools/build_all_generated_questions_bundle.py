import csv
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SUPABASE = ROOT / "supabase"
CSV_OUT = SUPABASE / "2026-07-14_all_generated_questions_master.csv"
SQL_OUT = SUPABASE / "2026-07-14_all_generated_questions_master.sql"

PREFIXES = (
    "2026-07-14_handcrafted_question_wave_1.csv",
    "2026-07-14_movement_sources_question_wave_2.csv",
    "2026-07-14_movement_sources_question_wave_3.csv",
    "2026-07-14_movement_sources_question_wave_4.csv",
    "2026-07-14_movement_sources_question_wave_5.csv",
    "2026-07-14_movement_sources_question_wave_6.csv",
    "2026-07-14_movement_sources_question_wave_7.csv",
    "2026-07-14_movement_sources_question_wave_8.csv",
    "2026-07-14_general_culture_question_wave_1.csv",
    "2026-07-14_general_culture_question_wave_2.csv",
    "2026-07-14_general_culture_question_wave_3.csv",
    "2026-07-14_general_culture_question_wave_4.csv",
    "2026-07-14_general_culture_question_wave_5.csv",
    "2026-07-14_general_culture_question_wave_6.csv",
    "2026-07-14_general_culture_question_wave_7.csv",
    "2026-07-14_general_culture_question_wave_8.csv",
    "2026-07-14_opentdb_translated_batch_1.csv",
    "2026-07-14_opentdb_translated_batch_2.csv",
)

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note"]

def q(value):
    return "'" + value.replace("'", "''") + "'"

def main():
    rows = []
    source_files = []
    for name in PREFIXES:
        path = SUPABASE / name
        source_files.append(name)
        with path.open(encoding="utf-8-sig", newline="") as f:
            rows.extend({field: row.get(field, "") for field in FIELDS} for row in csv.DictReader(f))

    if len(rows) != len({row["id"] for row in rows}):
        raise ValueError("duplicate ids in generated question bundle")
    if len(rows) != len({row["prompt"] for row in rows}):
        raise ValueError("duplicate prompts in generated question bundle")

    with CSV_OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    values = []
    for row in rows:
        values.append("(" + ", ".join([
            "(select id from public.categories where name = " + q(row["category_key"]) + ")",
            q(row["language_code"]),
            q(row["prompt"]),
            q(row["option_a"]),
            q(row["option_b"]),
            q(row["option_c"]),
            q(row["option_d"]),
            q(row["correct_option"]),
            q(row["explanation"]),
            str(row["difficulty"]),
            "false",
            q("multiple_choice"),
            "NULL",
            q(row["source_url"]),
        ]) + ")")

    header = "-- Birleştirilmiş, editoryal inceleme bekleyen 285 soru.\n-- Kaynak dalga CSV dosyaları: " + ", ".join(source_files) + "\n-- Canlı yayın için onaylanmadı; is_approved=false.\n"
    SQL_OUT.write_text(header + "insert into public.questions (category_id, language_code, prompt, option_a, option_b, option_c, option_d, correct_option, explanation, difficulty, is_approved, question_type, image_url, source_url) values\n" + ",\n".join(values) + ";\n", encoding="utf-8")
    print("rows", len(rows), "categories", dict(Counter(row["category_key"] for row in rows)), "sources", len({row["source_url"] for row in rows}))

if __name__ == "__main__":
    main()
