#!/usr/bin/env python3
"""Run the dedup migration SQL against Supabase via Management API.

Usage:
    SUPABASE_ACCESS_TOKEN=sbp_xxx python3 tools/run_dedup_migration.py
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
import urllib.request

PROJECT_REF = "hupivnxgjtsfafulzspo"
SQL_FILE = Path(__file__).resolve().parents[1] / "supabase" / "2026-07-22_deduplicate_questions.sql"


def management_query(sql: str) -> list[dict]:
    token = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
    if not token:
        print("ERROR: SUPABASE_ACCESS_TOKEN is required.")
        print("Get yours at: https://supabase.com/dashboard/account/tokens")
        print("Then run: SUPABASE_ACCESS_TOKEN=sbp_xxx python3 tools/run_dedup_migration.py")
        sys.exit(1)

    body = json.dumps({"query": sql}).encode("utf-8")
    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "ZanKurd-Migration/1.0",
        },
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw) if raw else []


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "dry-run"

    sql_text = SQL_FILE.read_text(encoding="utf-8")

    if mode == "dry-run":
        # BOLUM 1: SELECT query
        print("=== DRY-RUN: Fetching affected questions ===")
        select_sql = sql_text.split("-- BOLUM 2")[0]
        # Remove the comment header, keep only the SELECT
        select_sql = select_sql[select_sql.index("SELECT q.id"):]
        # Remove trailing semicolons/whitespace
        select_sql = select_sql.strip().rstrip(";") + ";"

        rows = management_query(select_sql)
        print(f"Affected questions found: {len(rows)}")
        if rows:
            # Show summary by prompt
            prompts = {}
            for r in rows:
                p = r.get("prompt", "")[:60]
                prompts[p] = prompts.get(p, 0) + 1
            print(f"Unique prompts: {len(prompts)}")
            for p, c in sorted(prompts.items(), key=lambda x: -x[1])[:20]:
                print(f"  [{c}x] {p}")
            if len(prompts) > 20:
                print(f"  ... and {len(prompts) - 20} more")
        print("\nTo apply the migration, run:")
        print("  python3 tools/run_dedup_migration.py apply")

    elif mode == "apply":
        # BOLUM 2: UPDATE query (within BEGIN/COMMIT)
        print("=== APPLYING MIGRATION ===")
        # Extract the UPDATE ... COMMIT block
        update_start = sql_text.index("BEGIN;")
        update_end = sql_text.index("COMMIT;") + len("COMMIT;")
        update_block = sql_text[update_start:update_end]

        result = management_query(update_block)
        print(f"Migration result: {result}")

        # Verify
        print("\n=== VERIFICATION ===")
        verify_sql = (
            "SELECT count(*) AS total, "
            "count(*) FILTER (WHERE is_approved = true) AS approved, "
            "count(*) FILTER (WHERE is_approved = false) AS disabled, "
            "count(*) FILTER (WHERE reviewed_by = 'dedup_migration') AS dedup_affected "
            "FROM public.questions;"
        )
        verify = management_query(verify_sql)
        if verify:
            row = verify[0]
            print(f"Total questions:    {row.get('total', 'N/A')}")
            print(f"Approved:           {row.get('approved', 'N/A')}")
            print(f"Disabled:           {row.get('disabled', 'N/A')}")
            print(f"Dedup affected:     {row.get('dedup_affected', 'N/A')}")

    else:
        print(f"Unknown mode: {mode}")
        print("Usage: python3 tools/run_dedup_migration.py [dry-run|apply]")
        sys.exit(1)


if __name__ == "__main__":
    main()
