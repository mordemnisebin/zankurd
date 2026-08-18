#!/usr/bin/env python3
"""Ajan çevirilerini yayımdaki bankalara uygular — mekanik kapıdan geçenleri.

Niçin doğru cevap burada TÜRETİLİYOR
------------------------------------
Ajandan yalnız `answersTr` istendi ve sırasının korunması şart koşuldu
(bkz. `prepare_tr_batches.py`). `correctAnswerTr` burada, Kurmancî şıklar
içindeki doğru cevabın İNDEKSİNDEN türetilir. Ajan doğru cevabı hiç
işaretlemediği için "yanlış şıkkı doğru işaretledi" hatası bu zincirde
yapısal olarak imkânsızdır.

Geriye kalan risk sözcük seçimidir ve onu iki şey karşılar: her partiyi
ikinci bir ajanın denetlemesi (iş akışının ikinci aşaması) ve aşağıdaki
mekanik kapı.

Mekanik kapı — geçemeyen kayıt UYGULANMAZ
-----------------------------------------
Reddedilen kayıt eski hâlinde kalır; model çevirisi tutarsız olduğunda zaten
Kurmancî'ye düşer (`_hasConsistentTurkishAnswers`). Yani kötü çeviriyi
uygulamamanın bedeli sıfırdır, uygulamanın bedeli bozuk bir turdur.
"""
from __future__ import annotations
import argparse, glob, json, os, re, unicodedata

BANKS = [
    "assets/data/sentence_building_questions.json",
    "assets/data/community_questions.json",
    "assets/data/editorial_questions.json",
    "assets/data/offline_questions.json",
    "assets/data/expansion_2026_08_questions.json",
    "assets/data/source_first_2026_08_questions.json",
]
IN_DIR = "scratchpad/tr_expansion"


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s.casefold())
    return re.sub(r"[^\w\s]", "", s).strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--skip", nargs="*", default=[], help="denetimde blocker çıkan id'ler")
    a = ap.parse_args()
    skip = set(a.skip)

    banks = {p: json.load(open(p, encoding="utf-8")) for p in BANKS}
    index = {q["id"]: q for rows in banks.values() for q in rows}

    # Girdi partileri: trueFalse/wordOrdering için önceden hesaplanmış
    # `answersTr` ve `needsOptions` bayrağı buradan gelir.
    prepared: dict[str, dict] = {}
    for f in sorted(glob.glob(f"{IN_DIR}/batch_*.json")):
        for e in json.load(open(f, encoding="utf-8")):
            prepared[e["id"]] = e

    applied, rejected = 0, []
    seen: set[str] = set()

    for f in sorted(glob.glob(f"{IN_DIR}/out_*.json")):
        try:
            rows = json.load(open(f, encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            rejected.append((os.path.basename(f), "parse", str(exc)[:80]))
            continue
        for r in rows:
            qid = r.get("id")
            if not qid or qid in seen:
                continue
            seen.add(qid)
            if qid in skip:
                rejected.append((qid, "denetim_blocker", "ikinci ajan reddetti"))
                continue
            q = index.get(qid)
            prep = prepared.get(qid)
            if q is None or prep is None:
                rejected.append((qid, "bilinmeyen_id", ""))
                continue

            prompt_tr = (r.get("promptTr") or "").strip()
            if not prompt_tr:
                rejected.append((qid, "bos_prompt", ""))
                continue
            # Kurmancî metnin aynen kopyalanması çeviri değildir.
            if norm(prompt_tr) == norm(q["prompt"]):
                rejected.append((qid, "cevrilmemis_prompt", prompt_tr[:50]))
                continue

            answers = q.get("answers") or []
            correct = q.get("correctAnswer")

            # Şıkları ajandan alma kuralı: `needsOptions` false ise şıklar
            # hazırlıkta belirlendi (Doğru/Yanlış eşlemesi) ya da hiç
            # çevrilmez (cümle kurma kelime havuzu).
            if prep.get("needsOptions"):
                raw_tr = r.get("answersTr")
                if not isinstance(raw_tr, list):
                    rejected.append((qid, "sik_yok", ""))
                    continue
                raw_tr = [str(x).strip() for x in raw_tr]
            else:
                raw_tr = prep.get("answersTr")
                if raw_tr is None:
                    # Cümle kurma: `answers` kelime havuzudur, çevrilmez;
                    # yalnız soru metni Türkçeleşir.
                    if q.get("promptTr") != prompt_tr:
                        q["promptTr"] = prompt_tr
                        applied += 1
                    continue

            # ── Şıkları İNDEKSE DEĞİL METNE göre hizala ──────────────────
            # Ajan `answersTr`yi partideki sıraya göre üretti. Ama parti
            # hazırlandıktan sonra `rebalance_answer_positions.py` bankadaki
            # şıkları karıştırmış olabilir (ve karıştırdı: 172 soru). İndekse
            # güvenmek, tam da önlemek için kurduğumuz hatayı — yanlış şıkkın
            # doğru işaretlenmesini — arka kapıdan geri getirirdi.
            #
            # Bu yüzden eşleme Kurmancî şık METNİ üzerinden kurulur ve
            # bankanın GÜNCEL sırasına göre yeniden dizilir.
            batch_answers = prep.get("answers") or []
            if len(raw_tr) != len(batch_answers):
                rejected.append(
                    (qid, "sik_sayisi", f"{len(raw_tr)} != {len(batch_answers)}")
                )
                continue
            mapping = dict(zip(batch_answers, raw_tr))
            missing = [o for o in answers if o not in mapping]
            if missing:
                # Şık metni onarım manifestiyle değişmiş: çeviri eskiye ait.
                rejected.append((qid, "sik_metni_degismis", missing[0][:50]))
                continue
            answers_tr = [mapping[o] for o in answers]
            if any(not x for x in answers_tr):
                rejected.append((qid, "bos_sik", ""))
                continue
            if len({norm(x) for x in answers_tr}) != len(answers_tr):
                rejected.append((qid, "yinelenen_sik", str(answers_tr)[:70]))
                continue
            if correct not in mapping:
                rejected.append((qid, "dogru_cevap_eslesmedi", str(correct)[:50]))
                continue
            correct_tr = mapping[correct]

            # ── Sızıntı: yalnız ÇEVİRİNİN AÇTIĞI sızıntı sayılır ─────────
            # Kurmancî aslında da doğru cevap soru metninde geçiyorsa bu
            # çevirinin değil sorunun özelliğidir ve `all_banks_quality`
            # bekçisinin alanıdır.
            #
            # Doğru/yanlış soruları bu kuralın tamamen dışındadır: kalıbın
            # kendisi ("Rast e an şaş e:" → "Doğru mu yanlış mı:") her iki
            # şıkkı da barındırır, dolayısıyla ölçüm anlamsızdır. Dahası iki
            # dil arasında ASİMETRİKTİR ve bu asimetri 224 geçerli çeviriyi
            # sessizce reddetmişti: `norm("Şaş")` üç harftir ("sas") ve dört
            # harflik kısa-metin eşiğinin altında kalıp Kurmancî tarafta hiç
            # ölçülmez; `norm("Yanlış")` altı harftir ve Türkçe tarafta
            # ölçülür. Sonuç: her doğru/yanlış çevirisi "çevirinin açtığı
            # sızıntı" görünüyordu.
            if q.get("type") != "trueFalse":
                ku_leaks = len(norm(correct)) >= 4 and norm(correct) in norm(q["prompt"])
                tr_leaks = (
                    len(norm(correct_tr)) >= 4 and norm(correct_tr) in norm(prompt_tr)
                )
                if tr_leaks and not ku_leaks:
                    rejected.append((qid, "cevirinin_actigi_sizinti", correct_tr[:40]))
                    continue

            q["promptTr"] = prompt_tr
            q["answersTr"] = answers_tr
            q["correctAnswerTr"] = correct_tr
            applied += 1

    by_reason: dict[str, int] = {}
    for _, why, _ in rejected:
        by_reason[why] = by_reason.get(why, 0) + 1

    total = sum(len(v) for v in banks.values())
    full_tr = sum(
        1
        for rows in banks.values()
        for q in rows
        if (q.get("promptTr") or "").strip()
        and q.get("answersTr")
        and q.get("correctAnswerTr") in (q.get("answersTr") or [])
        and len(q.get("answersTr") or []) == len(q.get("answers") or [])
    )
    print(
        json.dumps(
            {
                "seen": len(seen),
                "applied": applied,
                "rejected": len(rejected),
                "rejectedByReason": by_reason,
                "bankTotal": total,
                "fullTurkishAfter": full_tr,
                "coveragePercent": round(full_tr / total * 100, 1),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    for qid, why, detail in rejected[:40]:
        print(f"  RED {qid:22s} {why:20s} {detail}")

    if not a.check:
        for path, rows in banks.items():
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(rows, fh, ensure_ascii=False, indent=2)
                fh.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
