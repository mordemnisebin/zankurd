#!/usr/bin/env python3
"""Adlandırılmış onarım manifestini yayımdaki bankalara uygular.

Niçin manifest, niçin regex değil
---------------------------------
Bu depoda kural açık: yayımdaki JSON üzerinde toplu regex yapılmaz. Sebebi
yaşanmış: bir sözcüğü her yerde değiştiren bir geçiş, o sözcüğün meşru
kullanıldığı kayıtları da bozar ve fark commit'e karıştığında hangi kaydın
niçin değiştiği bir daha okunamaz.

Bu araç bunun tersini yapar: her kayıt manifestte **id ile** adlandırılır,
her değişikliğin yanında niçini yazılıdır ve araç yalnız adlandırılanlara
dokunur. Manifest, değişikliğin denetim günlüğüdür.

Güvenlik kilitleri
------------------
- Doğru cevap ASLA değiştirilmez. Bir `replace` girdisi doğru cevabı
  hedeflerse araç hata verip durur — çeldirici onarımı sessizce cevabı
  kaydıramaz.
- Onarımdan sonra doğru cevabın hâlâ şıklar arasında olduğu doğrulanır.
- Şık sayısı değişmez.
- Araç idempotenttir: ikinci çalıştırma hiçbir şeyi değiştirmez.
"""
from __future__ import annotations
import argparse, json, os, sys

BANKS = [
    "assets/data/sentence_building_questions.json",
    "assets/data/community_questions.json",
    "assets/data/editorial_questions.json",
    "assets/data/offline_questions.json",
    "assets/data/expansion_2026_08_questions.json",
    "assets/data/source_first_2026_08_questions.json",
]


def load_banks() -> dict[str, list[dict]]:
    return {p: json.load(open(p, encoding="utf-8")) for p in BANKS}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("manifest")
    ap.add_argument("--check", action="store_true", help="yazma, yalnız farkı bildir")
    a = ap.parse_args()

    man = json.load(open(a.manifest, encoding="utf-8"))
    banks = load_banks()
    index = {q["id"]: (path, q) for path, rows in banks.items() for q in rows}

    removed, patched_opts, patched_expl, already = [], [], [], []
    errors: list[str] = []

    # ── 1. Kaldırma ────────────────────────────────────────────────────
    remove_ids: set[str] = set()
    for group in man.get("remove", []):
        for qid in group["ids"]:
            if qid in index:
                remove_ids.add(qid)
                removed.append((qid, group["reason"]))
            else:
                already.append(qid)

    # ── 2. Şık onarımı ─────────────────────────────────────────────────
    for patch in man.get("patchOptions", []):
        qid = patch["id"]
        if qid in remove_ids:
            errors.append(f"{qid}: hem kaldırılıyor hem yamanıyor")
            continue
        if qid not in index:
            already.append(qid)
            continue
        _, q = index[qid]
        correct = q.get("correctAnswer")
        for old, new in patch["replace"].items():
            if old == correct:
                errors.append(
                    f"{qid}: «{old}» DOĞRU CEVAP — çeldirici onarımı cevabı değiştiremez"
                )
                continue
            for field in ("answers", "answersTr"):
                opts = q.get(field)
                if not isinstance(opts, list):
                    continue
                if old in opts:
                    opts[opts.index(old)] = new
                    patched_opts.append((qid, field, old, new))
        if correct is not None and correct not in (q.get("answers") or []):
            errors.append(f"{qid}: onarımdan sonra doğru cevap şıklarda yok")

    # ── 3. Açıklama onarımı ────────────────────────────────────────────
    for patch in man.get("patchExplanations", []):
        qid = patch["id"]
        if qid in remove_ids:
            errors.append(f"{qid}: hem kaldırılıyor hem yamanıyor")
            continue
        if qid not in index:
            already.append(qid)
            continue
        _, q = index[qid]
        changed = False
        for key in ("explanationKu", "explanationTr"):
            if key in patch and q.get(key) != patch[key]:
                q[key] = patch[key]
                changed = True
        # `explanation` eski şemada Türkçe varsayılandır; model çeviri yoksa
        # buraya düşer (bkz. quiz_question.dart resolveRawExplanation).
        if "explanationTr" in patch and q.get("explanation") != patch["explanationTr"]:
            q["explanation"] = patch["explanationTr"]
            changed = True
        if changed:
            patched_expl.append(qid)

    if errors:
        for e in errors:
            print(f"HATA: {e}", file=sys.stderr)
        return 1

    for path in banks:
        banks[path] = [q for q in banks[path] if q["id"] not in remove_ids]

    total = sum(len(v) for v in banks.values())
    summary = {
        "removed": len(removed),
        "removedByReason": {
            r: sum(1 for _, rr in removed if rr == r) for _, r in removed
        },
        "patchedOptionFields": len(patched_opts),
        "patchedExplanations": len(patched_expl),
        "alreadyApplied": len(already),
        "bankTotalAfter": total,
        "idempotent": not (removed or patched_opts or patched_expl),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    for qid, field, old, new in patched_opts:
        print(f"  şık  {qid} {field}: «{old}» → «{new}»")

    if a.check:
        return 0

    for path, rows in banks.items():
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(rows, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
