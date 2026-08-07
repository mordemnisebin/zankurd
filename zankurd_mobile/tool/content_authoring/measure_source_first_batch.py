#!/usr/bin/env python3
"""Source-first bir batch'i ölçer ve `*_metrics.json` üretir.

Sînema turunda ölçümler elle yazılmıştı ve bir tanesi (uzunluk yanlılığı)
commit gövdesine YANLIŞ girmişti; düzeltme `cinema_metrics.json` içinde
kayıtlı. Ölçüm elle yazıldığı sürece bu tekrar eder. Bu araç ölçümü
üretir, insan yalnız yorumlar.

Uzunluk yanlılığı iki ayrı sayıyla raporlanır ve ikisi karıştırılmaz:

* `naiveMaxTieCorrect` — doğru şık en uzunlardan biri (beraberlik de sayar).
  Yıl sorularında bütün şıklar 4 karakterdir; bu sayı orada anlamsızdır.
* `strictUniquelyLongestCorrect` — doğru şık TEK BAŞINA en uzun. Oyuncunun
  konuyu bilmeden kullanabileceği sinyal budur.
"""
from __future__ import annotations
import argparse, collections, json, re, unicodedata

BANKS = [
    "assets/data/offline_questions.json",
    "assets/data/editorial_questions.json",
    "assets/data/community_questions.json",
]

# Kendini yanlış ilan eden çeldirici: "... (yanlış)", "(ne rast)".
SELF_LABELLED = re.compile(r"\((?:yanlış|yanlis|şaş|sas|ne rast|geçersiz|gecersiz)\)", re.I)
# Şablon kimliği sızıntısı: sıfır dolgulu kayıt numarası. Yıl asla sıfırla
# başlamaz, bu yüzden desen `0\d{3}` ile sınırlı.
TEMPLATE_ID = re.compile(r"\(\s*0\d{3}\s*\)")
PLACEHOLDER = re.compile(r"\b(TODO|FIXME|XXX|lorem ipsum|placeholder)\b", re.I)

STOP = {
    "li", "di", "de", "ku", "ye", "e", "û", "bi", "ji", "wek", "çi", "kîjan",
    "gorî", "nav", "ser", "tê", "ne", "va", "vê", "van", "her", "an", "jî",
    "bir", "bu", "ve", "ile", "da", "den", "için", "hangi", "nedir", "göre",
    "the", "of", "in", "a", "is",
}


def words(s: str) -> set[str]:
    return {w for w in re.findall(r"[\w']+", s.lower()) if w not in STOP and len(w) > 2}


def bank_prompts() -> list[str]:
    out: list[str] = []
    for path in BANKS:
        with open(path, encoding="utf-8") as fh:
            for q in json.load(fh):
                for k in ("prompt", "promptTr", "promptKu"):
                    if q.get(k):
                        out.append(q[k])
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("questions")
    ap.add_argument("--out", required=True)
    ap.add_argument("--peer", action="append", default=[],
                    help="aynı turda üretilen diğer batch (çapraz duplicate)")
    a = ap.parse_args()

    with open(a.questions, encoding="utf-8") as fh:
        qs = json.load(fh)
    peers = []
    for p in a.peer:
        with open(p, encoding="utf-8") as fh:
            peers.extend(json.load(fh))

    problems: list[str] = []
    pos = collections.Counter()
    fams = collections.Counter()
    levels = collections.Counter()
    risks = collections.Counter()
    diffs = collections.Counter()
    naive_long = strict_long = strict_short = 0

    for q in qs:
        ku, tr = q["answersKu"], q["answersTr"]
        qid = q["questionId"]
        ci = q["correctIndex"]
        if len(ku) != 4 or len(tr) != 4:
            problems.append(f"{qid}: şık sayısı 4 değil")
        if not 0 <= ci < len(ku):
            problems.append(f"{qid}: correctIndex aralık dışı")
            continue
        if len(set(ku)) != len(ku) or len(set(tr)) != len(tr):
            problems.append(f"{qid}: yinelenen şık")
        pos[ci] += 1
        fams[q["claimId"].rsplit("_", 1)[0]] += 1
        levels[q["sourceAccessLevel"]] += 1
        risks[q["riskClass"]] += 1
        diffs[q["difficulty"]] += 1

        for field in [q["promptKu"], q["promptTr"], q["explanationKu"],
                      q["explanationTr"], *ku, *tr]:
            if SELF_LABELLED.search(field):
                problems.append(f"{qid}: kendini yanlış ilan eden metin -> {field}")
            if TEMPLATE_ID.search(field):
                problems.append(f"{qid}: şablon kimliği -> {field}")
            if PLACEHOLDER.search(field):
                problems.append(f"{qid}: yer tutucu -> {field}")

        # Döngüsellik: doğru şıkkın anlamlı sözcükleri soru kökünde geçiyorsa
        # oyuncu konuyu bilmeden kazanır. Türkçe ve Kurmancî ayrı ölçülür.
        for prompt, answers in ((q["promptKu"], ku), (q["promptTr"], tr)):
            aw = words(answers[ci])
            if aw and aw <= words(prompt):
                problems.append(f"{qid}: döngüsel — «{answers[ci]}» kökte geçiyor")

        for arr in (ku, tr):
            lens = [len(x) for x in arr]
            if lens[ci] == max(lens):
                naive_long += 1
                if lens.count(max(lens)) == 1:
                    strict_long += 1
            if lens[ci] == min(lens) and lens.count(min(lens)) == 1:
                strict_short += 1

    # Canlı bankalara ve turdaşlara karşı yakın-yineleme.
    live = [words(p) for p in bank_prompts()]
    peer_prompts = [(p["questionId"], words(p["promptKu"])) for p in peers]
    for q in qs:
        me = words(q["promptKu"])
        if not me:
            continue
        for other in live:
            if other and len(me & other) / len(me | other) >= 0.55:
                problems.append(f"{q['questionId']}: canlı bankada yakın eş")
                break
        for pid, other in peer_prompts:
            if other and len(me & other) / len(me | other) >= 0.55:
                problems.append(f"{q['questionId']}: turdaş {pid} ile yakın eş")

    n = len(qs)
    metrics = {
        "produced": n,
        "claimFamilies": dict(sorted(fams.items())),
        "correctIndexDistribution": {str(k): v for k, v in sorted(pos.items())},
        "maxPositionSharePct": round(100 * max(pos.values()) / n, 1) if n else 0,
        "difficultyDistribution": {str(k): v for k, v in sorted(diffs.items())},
        "riskClasses": dict(sorted(risks.items())),
        "sourceAccessLevels": dict(sorted(levels.items())),
        "naiveMaxTieCorrect": naive_long,
        "strictUniquelyLongestCorrect": strict_long,
        "strictUniquelyLongestPct": round(100 * strict_long / (2 * n), 1) if n else 0,
        "strictUniquelyShortestCorrect": strict_short,
        "lengthBiasNote": ("İki ölçüm ayrı tutulur. Naif sayı yıl sorularında "
                           "beraberlik yüzünden şişer; oyuncuya sinyal veren "
                           "ölçüm `strictUniquelyLongestCorrect`'tir. Kurmancî "
                           "ve Türkçe şık dizileri ayrı ayrı sayılır, bu yüzden "
                           "payda 2n'dir."),
        "selfLabelledDistractors": 0,
        "templateIdLeaks": 0,
        "circularQuestions": 0,
        "duplicateAgainstLiveBanks": 0,
        "problems": problems,
    }
    for p in problems:
        if "kendini yanlış" in p:
            metrics["selfLabelledDistractors"] += 1
        elif "şablon kimliği" in p:
            metrics["templateIdLeaks"] += 1
        elif "döngüsel" in p:
            metrics["circularQuestions"] += 1
        elif "yakın eş" in p:
            metrics["duplicateAgainstLiveBanks"] += 1

    with open(a.out, "w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print(json.dumps(metrics, ensure_ascii=False, indent=2))
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
