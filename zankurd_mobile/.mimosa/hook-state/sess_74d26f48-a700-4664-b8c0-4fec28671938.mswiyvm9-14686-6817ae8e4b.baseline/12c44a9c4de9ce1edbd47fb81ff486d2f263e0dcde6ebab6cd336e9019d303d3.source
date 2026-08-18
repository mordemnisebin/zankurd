from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "supabase" / "2026-07-14_editorial_kurmanci_question_wave_2_for_ai_review.csv"
REVIEWED = ROOT / "supabase" / "wave2_reviewed.csv"
CURATED = ROOT / "supabase" / "wave2_curated_publish_candidates.csv"
QUARANTINE = ROOT / "supabase" / "wave2_quarantine_for_further_review.csv"

MANUAL_CORRECTIONS = {
    "wave2_00007": "Rênivîsa Hawarê pergala nivîsê ya bi tîpên latînî ye ku Celadet Alî Bedirxan ji bo Kurmancî amade kir; di kovara Hawarê de ji sala 1932an ve hat bikaranîn.",
    "wave2_00009": "Dema borî ya dûr bi paşgira '-bû' tê çêkirin û kiryareke ku beriya kiryareke din a di rabirdûyê de qediyaye nîşan dide.",
    "wave2_03760": "Qerejdax çiyayekî volkanîk ê bazaltî ye ku deşta Amedê ji ya Rihayê vediqetîne.",
    "wave2_06255": "Şakiro dengbêjekî mezin bû ku wekî 'Şahê Dengbêjan' hate naskirin.",
}


def load(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as file:
        return list(csv.DictReader(file))


def score(row: dict[str, str]) -> tuple[int, float, int]:
    source_score = 1 if row.get("source_verified") != "Hayır" else 0
    return (source_score, float(row.get("confidence_0_to_1") or 0), -len(row.get("reason_turkish") or ""))


def main() -> None:
    base = {row["review_id"]: row for row in load(BASE)}
    reviewed = load(REVIEWED)
    merged = [{**base[row["review_id"]], **row} for row in reviewed]

    by_concept: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in merged:
        if row["verdict"] == "PASS":
            key = (row.get("corrected_explanation") or row["corrected_prompt"]).casefold().strip()
            by_concept[key].append(row)

    selected = [max(candidates, key=score) for candidates in by_concept.values()]
    selected.sort(key=lambda row: row["review_id"])
    selected_ids = {row["review_id"] for row in selected}

    fields = [
        "review_id", "category_key", "language_code", "corrected_prompt",
        "corrected_option_a", "corrected_option_b", "corrected_option_c",
        "corrected_option_d", "corrected_correct_option", "corrected_explanation",
        "confidence_0_to_1", "source_verified", "better_source_url",
        "issue_type", "publication_status", "review_notes",
    ]

    def write(path: Path, rows: list[dict[str, str]], status: str) -> None:
        with path.open("w", encoding="utf-8", newline="") as file:
            writer = csv.DictWriter(file, fieldnames=fields)
            writer.writeheader()
            for row in rows:
                if row["review_id"] in MANUAL_CORRECTIONS:
                    row["corrected_explanation"] = MANUAL_CORRECTIONS[row["review_id"]]
                writer.writerow({
                    "review_id": row["review_id"],
                    "category_key": row["category_key"],
                    "language_code": row["language_code"],
                    "corrected_prompt": row["corrected_prompt"],
                    "corrected_option_a": row["corrected_option_a"],
                    "corrected_option_b": row["corrected_option_b"],
                    "corrected_option_c": row["corrected_option_c"],
                    "corrected_option_d": row["corrected_option_d"],
                    "corrected_correct_option": row["corrected_correct_option"],
                    "corrected_explanation": row["corrected_explanation"],
                    "confidence_0_to_1": row["confidence_0_to_1"],
                    "source_verified": row["source_verified"],
                    "better_source_url": row["better_source_url"],
                    "issue_type": row["issue_type"],
                    "publication_status": status,
                    "review_notes": "Tek kavram için tek soru tutuldu; şablon tekrarları elendi."
                    if status == "CURATED_CANDIDATE"
                    else row["reason_turkish"],
                    })

    write(CURATED, selected, "CURATED_CANDIDATE")
    write(QUARANTINE, [row for row in merged if row["review_id"] not in selected_ids], "QUARANTINED")
    print(f"curated={len(selected)} quarantine={len(merged) - len(selected)}")


if __name__ == "__main__":
    main()
