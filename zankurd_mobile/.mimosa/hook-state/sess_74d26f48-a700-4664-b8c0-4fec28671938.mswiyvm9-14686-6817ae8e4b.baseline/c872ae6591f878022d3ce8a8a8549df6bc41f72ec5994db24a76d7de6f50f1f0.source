import csv
import json
import os
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "supabase" / "2026-07-14_chat_all_kurmanci_questions_live.csv"
PROJECT_REF = "hupivnxgjtsfafulzspo"
BATCH_SIZE = 40


def sql_quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def run_sql(query: str):
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
    request = urllib.request.Request(
        url,
        data=json.dumps({"query": query}, ensure_ascii=False).encode("utf-8"),
        method="POST",
        headers={
            "Authorization": f"Bearer {os.environ['SUPABASE_ACCESS_TOKEN']}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            raw = response.read().decode("utf-8")
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"management SQL failed: HTTP {error.code}: {detail}") from error


def main():
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))

    run_sql("""
        insert into public.categories (name, slug, is_active)
        values ('Teknolojî', 'teknoloji', true)
        on conflict (name) do update set is_active = true;
    """)
    print("categories ensured")

    for start in range(0, len(rows), BATCH_SIZE):
        statements = []
        for row in rows[start:start + BATCH_SIZE]:
            values = ", ".join([
                sql_quote(row["category_key"]),
                sql_quote(row["language_code"]),
                sql_quote(row["prompt"]),
                sql_quote(row["option_a"]),
                sql_quote(row["option_b"]),
                sql_quote(row["option_c"]),
                sql_quote(row["option_d"]),
                sql_quote(row["correct_option"]),
                sql_quote(row["explanation"]),
                str(int(row["difficulty"])),
                sql_quote(row["source_url"]),
            ])
            statements.append(f"""
                insert into public.questions
                    (category_id, language_code, prompt, option_a, option_b, option_c,
                     option_d, correct_option, explanation, difficulty, is_approved,
                     question_type, image_url, source_url)
                select c.id, v.language_code, v.prompt, v.option_a, v.option_b,
                       v.option_c, v.option_d, v.correct_option, v.explanation,
                       v.difficulty, true, 'multiple_choice', null, v.source_url
                from (values ({values})) as v(
                    category_name, language_code, prompt, option_a, option_b,
                    option_c, option_d, correct_option, explanation, difficulty,
                    source_url)
                join public.categories c on c.name = v.category_name
                where not exists (
                    select 1 from public.questions q
                    where q.language_code = v.language_code
                      and lower(trim(q.prompt)) = lower(trim(v.prompt))
                );
            """)
        run_sql("\n".join(statements))
        print(f"processed {min(start + BATCH_SIZE, len(rows))}/{len(rows)}")
    print("management API live import complete")


if __name__ == "__main__":
    main()
