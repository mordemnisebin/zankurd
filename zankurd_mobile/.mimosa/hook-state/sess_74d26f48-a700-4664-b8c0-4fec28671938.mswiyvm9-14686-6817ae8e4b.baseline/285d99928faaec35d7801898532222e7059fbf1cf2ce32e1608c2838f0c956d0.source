from __future__ import annotations

from pathlib import Path
import runpy


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    ns = runpy.run_path(str(ROOT / "tools" / "generate_rich_question_bank.py"))
    questions = ns["generated_questions"]()
    ns["assert_quality"](questions)
    values = ns["question_values"](questions)
    ns["write_parts"](values)
    print(f"Wrote setup + chunks to {ROOT / 'supabase' / 'rich_question_bank_v2_parts'}")


if __name__ == "__main__":
    main()
