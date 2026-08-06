#!/usr/bin/env python3
"""Kategoriler arası DOĞRULANMIŞ intake havuzunu kurar.

Havuz, kabul edilmiş ama henüz runtime'a bağlanmamış kayıtların tek yeridir.
Kaynak, karar manifestleridir (`decisions_*.json`); bu araç onlardan türetir.

Niçin türetici bir araç, elle düzenlenen bir dosya değil
--------------------------------------------------------
Havuz elle düzenlenseydi iki kayıt kaynağı oluşurdu: karar manifesti ve
havuz. İkisi zamanla ayrışır ve "hangisi doğru" sorusunun cevabı kalmaz —
bu projede tam olarak bu, banka listesi dört yere kopyalandığında yaşandı
(bkz. `question_bank_assets.dart`).

Araç **deterministik ve idempotent**tir: aynı girdilerle tekrar
çalıştırıldığında aynı dosyayı üretir. `finalContentHash` yalnız içerik
alanlarından hesaplanır, karar/zaman alanlarından değil; böylece bir kaydın
gerekçesi güncellendiğinde hash değişmez.

Havuza yalnız ACCEPTED_* kararı olan ve gerçek `sourceReference` taşıyan
kayıtlar girer. Doğrulanmamış kayıt havuza giremez — eşiği doldurmak için
bile.
"""
from __future__ import annotations
import argparse, glob, hashlib, json, os, collections

INTAKE = "scratchpad/external_authoring/opus_intake_2026_08"
POOL = "docs/content/verified_external_pool_2026_08"
RAW = {"deepseek": f"{INTAKE}/raw/deepseek", "grok": f"{INTAKE}/raw/grok"}

CONTENT_FIELDS = ["prompt", "promptTr", "answers", "answersTr",
                  "correctAnswer", "correctAnswerTr",
                  "explanationKu", "explanationTr"]


def content_hash(q: dict) -> str:
    payload = json.dumps({f: q.get(f) for f in CONTENT_FIELDS},
                         ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def load_candidates() -> dict:
    out = {}
    for pool, d in RAW.items():
        for f in sorted(glob.glob(f"{d}/batch_*_questions.json")):
            for q in json.load(open(f, encoding="utf-8")):
                out[q["id"]] = (pool, q)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="yazma; yalnız mevcut havuzla farkı bildir")
    a = ap.parse_args()

    cands = load_candidates()
    questions, provenance, decisions = [], [], []
    metrics = collections.Counter()
    skipped = collections.Counter()

    for path in sorted(glob.glob(f"{INTAKE}/decisions_*.json")):
        if path.endswith("decisions_grok_rejected.json"):
            continue
        for r in json.load(open(path, encoding="utf-8")):
            dec = r.get("OpusReviewDecision", "")
            if not dec.startswith("ACCEPTED"):
                skipped[dec] += 1
                continue
            ref = r.get("verifiedSourceReference")
            if not ref:
                # Kabul kararı var ama gerçek kaynak yok: havuza GİRMEZ.
                # Bu sessizce atlanmaz, sayılır.
                skipped["ACCEPTED_WITHOUT_SOURCE"] += 1
                continue
            qid = r["questionId"]
            pool, q = cands[qid]
            h = content_hash(q)
            sub = r.get("subcategoryNew") or q.get("subcategory")
            questions.append({**{k: q.get(k) for k in CONTENT_FIELDS},
                              "id": qid, "category": q.get("category"),
                              "subcategory": sub,
                              "difficulty": q.get("difficulty"),
                              "type": q.get("type", "multipleChoice")})
            provenance.append({
                "originalQuestionId": qid, "sourcePool": pool,
                "sourceBranch": r.get("sourceBranch"),
                "sourceCommit": r.get("sourceCommit"),
                "category": q.get("category"), "subcategory": sub,
                "verificationLevel": r.get("sourceVerificationLevel"),
                "sourceReference": ref,
                "exactSupportingFact": r.get("exactSupportingFact"),
                "verifiedAt": r.get("verifiedAt"), "reviewer": r.get("reviewer"),
                "finalContentHash": h, "activationStatus": "STAGED_VERIFIED",
            })
            decisions.append({"originalQuestionId": qid,
                              "OpusReviewDecision": dec,
                              "OpusReviewReasons": r.get("OpusReviewReasons"),
                              "subcategoryOld": r.get("subcategoryOld"),
                              "subcategoryNew": r.get("subcategoryNew")})
            metrics[q.get("category")] += 1
            metrics[f"level:{r.get('sourceVerificationLevel')}"] += 1

    questions.sort(key=lambda x: x["id"])
    provenance.sort(key=lambda x: x["originalQuestionId"])
    decisions.sort(key=lambda x: x["originalQuestionId"])
    cat_metrics = {
        "totalStagedVerified": len(questions),
        "byCategory": {k: v for k, v in sorted(metrics.items())
                       if not k.startswith("level:")},
        "byVerificationLevel": {k[6:]: v for k, v in sorted(metrics.items())
                                if k.startswith("level:")},
        "skippedByDecision": dict(sorted(skipped.items())),
        "activationThreshold": 100,
        "readyForBulkActivation": len(questions) >= 100,
    }

    if a.check:
        old = json.load(open(f"{POOL}/questions.json", encoding="utf-8")) \
            if os.path.exists(f"{POOL}/questions.json") else []
        print(f"mevcut {len(old)} -> üretilen {len(questions)} "
              f"| idempotent: {'YES' if old == questions else 'NO'}")
        return 0

    os.makedirs(POOL, exist_ok=True)
    for name, data in (("questions", questions), ("provenance", provenance),
                       ("decisions", decisions), ("category_metrics", cat_metrics)):
        with open(f"{POOL}/{name}.json", "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
    print(json.dumps(cat_metrics, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
