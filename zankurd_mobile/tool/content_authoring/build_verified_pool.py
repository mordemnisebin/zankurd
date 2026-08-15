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

DEFAULT_INTAKE = "scratchpad/external_authoring/opus_intake_2026_08"
POOL = "docs/content/verified_external_pool_2026_08"
SOURCE_FIRST = "docs/content/source_first_expansion_2026_08"

CONTENT_FIELDS = ["prompt", "promptTr", "answers", "answersTr",
                  "correctAnswer", "correctAnswerTr",
                  "explanationKu", "explanationTr"]


def content_hash(q: dict) -> str:
    payload = json.dumps({f: q.get(f) for f in CONTENT_FIELDS},
                         ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:16]


def load_candidates(intake: str) -> dict:
    out = {}
    for pool in ("deepseek", "grok"):
        for f in sorted(glob.glob(f"{intake}/raw/{pool}/batch_*_questions.json")):
            for q in json.load(open(f, encoding="utf-8")):
                out[q["id"]] = (pool, q)
    return out


def existing_external_count() -> int:
    path = f"{POOL}/provenance.json"
    if not os.path.exists(path):
        return 0
    with open(path, encoding="utf-8") as fh:
        return sum(1 for p in json.load(fh)
                   if p.get("origin") != "source_first_verified")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="yazma; yalnız mevcut havuzla farkı bildir")
    ap.add_argument("--intake", default=DEFAULT_INTAKE,
                    help="dış aday intake dizini (varsayılan repo içi yol)")
    ap.add_argument("--allow-missing-intake", action="store_true",
                    help="dış kayıtları BİLEREK düşür; gerekçe commit gövdesine yazılmalı")
    a = ap.parse_args()

    # Girdiler repoda duruyor (`scratchpad/.../opus_intake_2026_08`, 32 dosya),
    # yani havuz repodan üretilebilir. Ama yol yoksa — yanlış çalışma dizini,
    # budanmış bir checkout, taşınmış bir klasör — glob boş döner, dış kayıtlar
    # sessizce sıfırlanır ve araç YİNE DE başarıyla çıkar. Havuzun küçülmesi
    # sessiz bir başarıya benzemeyecek; aracın kendi kuralının aynası budur:
    # doğrulanmamış kayıt havuza giremediği gibi, doğrulanmış kayıt da havuzdan
    # sessizce düşmemeli.
    if not os.path.isdir(a.intake) and existing_external_count() and not a.allow_missing_intake:
        print(f"HATA: intake dizini yok ({a.intake}) ama havuzda "
              f"{existing_external_count()} dış kayıt var. Yazmak onları silerdi.\n"
              f"    --intake <yol> ile girdileri göster, ya da düşüşü bilerek "
              f"kabul ediyorsan --allow-missing-intake kullan.")
        return 2

    cands = load_candidates(a.intake)
    questions, provenance, decisions = [], [], []
    metrics = collections.Counter()
    skipped = collections.Counter()

    for path in sorted(glob.glob(f"{a.intake}/decisions_*.json")):
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

    # ── source-first kayıtlar ────────────────────────────────────────────
    # Dış aday havuzundan AYRI bir köken. Aynı havuzda sayılırlar ama
    # `origin` alanı ikisini ayırır: external_verified kaynağı bir dış
    # modeldir, source_first_verified'ın kaynağı doğrudan açılmış kurumsal
    # sayfadır. Ayrımı kaybetmek, iki farklı kanıt rejimini tek sayıya
    # eritirdi.
    #
    # Yol tek bir kategoriye (cinema) sabitlenmişti; Çand/Muzîk eklendiğinde
    # araç onları GÖRMEZDİ ve havuz sessizce eksik kalırdı. Artık dizin
    # taranıyor: `<kategori>/<kategori>_questions.json` deseni yeter.
    for SF in sorted(glob.glob(f"{SOURCE_FIRST}/*/*_questions.json")):
        batch_dir = os.path.dirname(SF)
        name = os.path.basename(batch_dir)
        dec_path = f"{batch_dir}/{name}_decisions.json"
        verified_at = "2026-08-06"
        if os.path.exists(dec_path):
            with open(dec_path, encoding="utf-8") as fh:
                verified_at = json.load(fh).get("timestamp", verified_at)
        for q in json.load(open(SF, encoding="utf-8")):
            h = hashlib.sha256(json.dumps(
                {k: q.get(k) for k in ("promptKu", "promptTr", "answersKu",
                                       "answersTr", "correctIndex")},
                ensure_ascii=False, sort_keys=True).encode()).hexdigest()[:16]
            questions.append({
                "id": q["questionId"], "category": q["category"],
                "subcategory": q.get("subcategory"),
                "prompt": q["promptKu"], "promptTr": q["promptTr"],
                "answers": q["answersKu"], "answersTr": q["answersTr"],
                "correctAnswer": q["answersKu"][q["correctIndex"]],
                "correctAnswerTr": q["answersTr"][q["correctIndex"]],
                "explanationKu": q["explanationKu"],
                "explanationTr": q["explanationTr"],
                "difficulty": q.get("difficulty", 2),
                "type": q.get("questionType") or q.get("type", "multipleChoice")})
            provenance.append({
                "originalQuestionId": q["questionId"], "sourcePool": "source_first",
                "origin": "source_first_verified",
                "sourceBranch": None, "sourceCommit": None,
                "category": q["category"], "subcategory": q.get("subcategory"),
                "verificationLevel": q.get("sourceAccessLevel", "FETCHED_DIRECT"),
                "sourceReference": q["sourceReference"],
                "exactSupportingFact": q["exactSupportingFact"],
                "verifiedAt": verified_at, "reviewer": "opus-5",
                "finalContentHash": h, "activationStatus": "STAGED_VERIFIED"})
            decisions.append({"originalQuestionId": q["questionId"],
                              "OpusReviewDecision": "ACCEPTED_PRIMARY_DIRECT",
                              "OpusReviewReasons": ["doğrudan açılmış kurumsal sayfa"],
                              "subcategoryOld": None, "subcategoryNew": None})
            metrics[q["category"]] += 1
            metrics["level:" + q.get("sourceAccessLevel", "FETCHED_DIRECT")] += 1
            metrics["origin:source_first_verified"] += 1

    questions.sort(key=lambda x: x["id"])
    provenance.sort(key=lambda x: x["originalQuestionId"])
    decisions.sort(key=lambda x: x["originalQuestionId"])
    cat_metrics = {
        "totalStagedVerified": len(questions),
        "externalVerifiedCount": sum(1 for p in provenance
                                     if p.get("origin") != "source_first_verified"),
        "sourceFirstVerifiedCount": sum(1 for p in provenance
                                        if p.get("origin") == "source_first_verified"),
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
