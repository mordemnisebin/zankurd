"""Supabase'deki soru bankasini programatik kalite taramasindan gecirir.

Kontroller:
  1. Soru icinde dogru cevabin gecmesi (cevap sizintisi)
  2. Ayni soru icinde tekrarlanan gercek secenekler ("-" dolgusu sayilmaz)
  3. Bos secenek (multiple_choice/visual icin)
  4. Ayni prompt'un birden fazla onayli kopyasi (tekrar sisirmesi)
  5. correct_option gecersizligi

Cikti:
  - reports/question_audit_report.md
  - supabase/dedupe_and_fix_questions.sql
      * her prompt grubundan tek satir onayli kalir (digerleri is_approved=false)
      * cevap sizintisi olan satirlarin onayi kaldirilir
"""

import json
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://hupivnxgjtsfafulzspo.supabase.co/rest/v1"
KEY = "sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s"

FILLER = {"", "-"}


def fetch_all():
    rows = []
    offset = 0
    page = 1000
    while True:
        url = (
            f"{BASE}/questions?select=id,prompt,option_a,option_b,option_c,"
            f"option_d,correct_option,explanation,question_type,difficulty,"
            f"is_approved,categories(name)&order=id"
        )
        req = urllib.request.Request(url)
        req.add_header("apikey", KEY)
        req.add_header("Authorization", f"Bearer {KEY}")
        req.add_header("Range", f"{offset}-{offset + page - 1}")
        with urllib.request.urlopen(req) as resp:
            chunk = json.loads(resp.read().decode())
        rows.extend(chunk)
        if len(chunk) < page:
            break
        offset += page
    return rows


def norm(text):
    return (text or "").strip().lower()


def main():
    rows = fetch_all()
    issues = []
    leak_ids = []

    groups = defaultdict(list)
    for r in rows:
        groups[norm(r["prompt"])].append(r)

    for r in rows:
        qid = r["id"]
        prompt = norm(r["prompt"])
        options = {
            "A": norm(r.get("option_a")),
            "B": norm(r.get("option_b")),
            "C": norm(r.get("option_c")),
            "D": norm(r.get("option_d")),
        }
        correct_key = (r.get("correct_option") or "").strip().upper()
        qtype = r.get("question_type") or "multiple_choice"

        if correct_key not in options or options[correct_key] in FILLER:
            issues.append((qid, "BAD_CORRECT_KEY", f"correct={correct_key!r}"))
            continue

        correct_text = options[correct_key]
        if len(correct_text) >= 6 and correct_text in prompt:
            issues.append((qid, "ANSWER_LEAK", f"'{correct_text[:40]}' in prompt"))
            leak_ids.append(qid)

        real = [v for v in options.values() if v not in FILLER]
        dupes = [v for v, c in Counter(real).items() if c > 1]
        if dupes:
            issues.append((qid, "DUP_OPTIONS", f"{dupes[:2]}"))

        if qtype in ("multiple_choice", "visual") and len(real) < 4:
            issues.append((qid, "MISSING_OPTION", f"{len(real)}/4"))

    dup_groups = {k: v for k, v in groups.items() if len(v) > 1}
    dup_extra_rows = sum(len(v) - 1 for v in dup_groups.values())

    by_code = Counter(code for _, code, _ in issues)

    reports = ROOT / "reports"
    reports.mkdir(exist_ok=True)
    report = reports / "question_audit_report.md"
    with report.open("w", encoding="utf-8") as f:
        f.write("# Soru Bankasi Kalite Raporu\n\n")
        f.write(f"- Toplam satir: {len(rows)}\n")
        f.write(f"- Benzersiz prompt: {len(groups)}\n")
        f.write(f"- Tekrarlanan prompt grubu: {len(dup_groups)}\n")
        f.write(f"- Tekrardan gelen fazla satir: {dup_extra_rows}\n\n")
        f.write("## Yapisal bulgular\n\n")
        for code, count in by_code.most_common():
            f.write(f"- {code}: {count}\n")
        f.write("\n## Onerilen aksiyon\n\n")
        f.write(
            "supabase/dedupe_and_fix_questions.sql calistirildiginda her prompt'tan\n"
            "tek satir onayli kalir ve cevap sizintili satirlarin onayi kaldirilir.\n"
        )
        f.write("\n## Cevap sizintisi detaylari\n\n")
        for qid, code, detail in issues:
            if code == "ANSWER_LEAK":
                f.write(f"- `{qid}` {detail}\n")

    sql = ROOT / "supabase" / "dedupe_and_fix_questions.sql"
    with sql.open("w", encoding="utf-8") as f:
        f.write(
            "-- ZanKurd soru bankasi tekillestirme + kalite duzeltmesi\n"
            "-- 1) Ayni prompt'un kopyalarindan yalnizca biri onayli kalir\n"
            "--    (en dusuk zorluk, sonra en eski id tercih edilir).\n"
            "-- 2) Cevap sizintisi tespit edilen satirlarin onayi kaldirilir.\n"
            "-- Satirlar SILINMEZ; is_approved=false yapilir, admin sonra duzeltebilir.\n\n"
            "update public.questions\n"
            "set is_approved = false\n"
            "where id not in (\n"
            "  select distinct on (lower(trim(prompt))) id\n"
            "  from public.questions\n"
            "  order by lower(trim(prompt)), difficulty, created_at, id\n"
            ");\n\n"
        )
        if leak_ids:
            f.write("update public.questions set is_approved = false\nwhere id in (\n")
            f.write(",\n".join(f"  '{q}'" for q in sorted(set(leak_ids))))
            f.write("\n);\n")

    print(f"Toplam satir       : {len(rows)}")
    print(f"Benzersiz prompt   : {len(groups)}")
    print(f"Fazla kopya satir  : {dup_extra_rows}")
    for code, count in by_code.most_common():
        print(f"  {code}: {count}")
    print(f"Rapor: {report}")
    print(f"SQL  : {sql}")


if __name__ == "__main__":
    main()
