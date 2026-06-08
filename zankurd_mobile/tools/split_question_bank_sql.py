from __future__ import annotations

from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "supabase" / "rich_question_bank_v2_parts"
CHUNK_SIZE = 225


def main() -> None:
    ns = runpy.run_path(str(ROOT / "tools" / "generate_rich_question_bank.py"))
    questions = ns["build_questions"]()
    esc = ns["esc"]
    source = ns["SOURCE"]

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    setup_sql = f"""alter table public.questions
  add column if not exists question_type text not null default 'multiple_choice';

alter table public.questions
  add column if not exists image_url text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'questions_question_type_check'
  ) then
    alter table public.questions
      add constraint questions_question_type_check
      check (question_type in ('multiple_choice', 'true_false', 'visual'));
  end if;
end;
$$;

insert into public.categories (name, slug, is_active)
values
  ('Ziman', 'ziman', true),
  ('Çand', 'cand', true),
  ('Dîrok', 'dirok', true),
  ('Edebiyat', 'edebiyat', true),
  ('Cografya', 'cografya', true),
  ('Muzîk', 'muzik', true)
on conflict (name) do update set is_active = excluded.is_active;

delete from public.questions
where source_url = '{source}';
"""
    (OUT_DIR / "00_setup.sql").write_text(setup_sql, encoding="utf-8")

    for chunk_index, start in enumerate(range(0, len(questions), CHUNK_SIZE), start=1):
        values: list[str] = []
        for q in questions[start : start + CHUNK_SIZE]:
            values.append(
                "("
                f"(select id from public.categories where name = {esc(q['category'])}), "
                "'ku-kmr', "
                f"{esc(q['prompt'])}, "
                f"{esc(q['a'])}, "
                f"{esc(q['b'])}, "
                f"{esc(q['c'])}, "
                f"{esc(q['d'])}, "
                f"{esc(q['correct'])}, "
                f"{esc(q['explanation'])}, "
                f"{q['difficulty']}, "
                "true, "
                f"{esc(q['question_type'])}, "
                f"{esc(q['image'])}, "
                f"{esc(source)}"
                ")"
            )

        insert_sql = f"""insert into public.questions (
  category_id,
  language_code,
  prompt,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option,
  explanation,
  difficulty,
  is_approved,
  question_type,
  image_url,
  source_url
)
values
{",\n".join(values)};
"""
        (OUT_DIR / f"{chunk_index:02d}_insert.sql").write_text(insert_sql, encoding="utf-8")

    readme = f"""Run these files in Supabase SQL Editor in order:

1. 00_setup.sql
2. 01_insert.sql
3. 02_insert.sql
4. 03_insert.sql
5. 04_insert.sql
6. 05_insert.sql
7. 06_insert.sql
8. 07_insert.sql
9. 08_insert.sql
10. 09_insert.sql
11. 10_insert.sql

Total questions: {len(questions)}
Rows per insert chunk: {CHUNK_SIZE}

Do not run the big rich_question_bank_v2.sql if the editor cannot paste it.
Use these smaller files instead.
"""
    (OUT_DIR / "README.txt").write_text(readme, encoding="utf-8")
    print(f"Wrote setup + chunks to {OUT_DIR}")


if __name__ == "__main__":
    main()
