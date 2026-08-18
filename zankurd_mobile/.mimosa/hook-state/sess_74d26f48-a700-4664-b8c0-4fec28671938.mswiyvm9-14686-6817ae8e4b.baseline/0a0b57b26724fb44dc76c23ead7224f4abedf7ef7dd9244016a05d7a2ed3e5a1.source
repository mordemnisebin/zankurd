#!/usr/bin/env python3
"""Yeni yazılan soru batch'leri için kalite kapısı.

Üretici ajan kendi çıktısını onaylayamaz; her batch bu kapıdan geçer ve
DÜŞEN kayıtlar karantinaya taşınır. Kapı, 2026-08-06 gece genişletmesinin
sözleşmesini uygular.

Kullanım:
    python3 tool/content_authoring/validate_batch.py <batch.json> \
        [--existing-index <index.json>] [--quarantine <out.json>] \
        [--accepted <out.json>] [--json-report <report.json>]

Çıkış kodu 0 yalnız SIFIR sert ihlal varsa.

Niçin ayrı bir araç
-------------------
Depoda zaten çok sayıda denetim aracı var ama hepsi YAYIMLANMIŞ bankaları
tarıyor. Bu kapı üretim anında, henüz repoya girmeden çalışır: kusurlu
kayıt bankaya hiç girmez. Mevcut araçlar baştan yazılmadı; bu kapı onların
yakaladığı kusur sınıflarını üretim anına taşır.
"""
from __future__ import annotations
import argparse, json, math, re, sys, unicodedata, collections, hashlib

# ── normalisation ────────────────────────────────────────────────────────
_PUNCT = re.compile(r"[^\w\s]", re.UNICODE)
_WS = re.compile(r"\s+")

def norm(s: str) -> str:
    s = unicodedata.normalize("NFC", (s or "")).strip().lower()
    return _WS.sub(" ", _PUNCT.sub(" ", s)).strip()


# Şık karşılaştırması için AYRI bir normalleştirme.
#
# `norm()` bütün noktalama işaretlerini atar; prompt karşılaştırmasında
# doğru, şıklarda YIKICI: `V = I × R` ile `V = I ÷ R` ikisi de "v i r"ye
# çöküyor ve geçerli bir formül sorusu "çift şık" diye reddediliyordu
# (2026-08-06, tech_invent_0019/0026). Operatör şıkkın ta kendisidir.
#
# Burada yalnız baş/son noktalama kırpılır ve boşluk sadeleşir; içerideki
# matematik/sembol korunur. "Ankara" ile "Ankara." hâlâ aynı sayılır.
_EDGE_PUNCT = re.compile(r"^[^\w]+|[^\w]+$", re.UNICODE)


def norm_option(s: str) -> str:
    s = unicodedata.normalize("NFC", (s or "")).strip().lower()
    return _WS.sub(" ", _EDGE_PUNCT.sub("", s)).strip()

def tokens(s: str) -> set[str]:
    return {t for t in norm(s).split() if len(t) > 2}

# Kurmancî diakritikleri. Eksikse metin ya Türkçeleşmiş ya bozulmuş demektir.
KU_DIACRITICS = set("êîûşçÊÎÛŞÇ")
# Soranca/Arap alfabesi karışması
NON_LATIN = re.compile(r"[؀-ۿЀ-ӿ]")
# Kod işaretleri BÜYÜK HARF aranır. `re.I` ile "TODO" İspanyolca
# "Todo sobre mi madre" film adına takılıyordu (2026-08-06, cinema_0048):
# geçerli bir soru "yer tutucu" diye reddedildi.
PLACEHOLDER_CASED = re.compile(r"\b(TODO|FIXME|TBD|XXX)\b")
PLACEHOLDER_ANY = re.compile(r"(placeholder|lorem ipsum|\{\{|\}\})", re.I)


def has_placeholder(t: str) -> bool:
    return bool(PLACEHOLDER_CASED.search(t) or PLACEHOLDER_ANY.search(t))
# Yapay zekâ kalıpları (TR)
AI_TR = re.compile(r"\b(aşağıdakilerden hangisi doğrudur|bu bağlamda|önemli bir rol oynamaktadır|"
                   r"dikkat çekmektedir|olarak bilinmektedir|ifade edilebilir)\b", re.I)
HEDGE = re.compile(r"\b(genellikle|bazen|çoğunlukla|bir tür|olabilir|sanılmaktadır)\b", re.I)
ESCAPE_OPTS = re.compile(r"^\s*(hepsi|hiçbiri|yukarıdakilerin hepsi|hiçbiri değil|"
                         r"hemû|tu kes|yek jî na)\s*$", re.I)
NEGATIVE = re.compile(r"\b(değildir|değil|olmayan|hangisi yanlış|ne dibe|nîne)\b", re.I)
# Şablon artığı: soru metninde iç slug ve kayıt numarası kalmış.
# 2026-08-06: Grok'un kalan 111 adayının 19'u böyleydi —
# "Temel tanım: «ewle (0025)» hangisidir?". `ewle` iç etiket, (0025) kayıt
# numarası; oyuncuya hiçbir şey ifade etmiyor. Mevcut `placeholder-*` kuralı
# TODO/XXX gibi işaretlere bakıyordu, bu biçimi görmüyordu ve 19'unu da
# kabul etmişti.
# Kayıt numarası SIFIR DOLGULUDUR (0025); yıl asla sıfırla başlamaz.
# İlk desen `\d{3,4}` idi ve meşru "(1929)" yılını da yakalıyordu.
PLACEHOLDER_ID = re.compile(r"\(\s*0\d{3}\s*\)")

# Şıkkın kendini yanlış ilan etmesi. Parantezli etiket en yaygın biçim,
# ama parantezsiz sonek de görüldü ("RAM e ne rast").
SELF_LABELED = re.compile(
    r"\(\s*(ne\s*rast(în)?|yanlış|yanlis|geçersiz|gecersiz|doğru\s*değil|"
    r"dogru\s*degil|not\s*correct|incorrect|false)\s*\)"
    r"|\s+(ne\s*rast(în)?|yanlış|geçersiz)\s*$",
    re.I,
)
VOLATILE = re.compile(r"\b(şu an|şu anda|günümüzde|bugün|halen|hâlen|en yeni|son olarak|"
                      r"niha|îro)\b", re.I)

REQUIRED = ["id", "category", "prompt", "answers", "correctAnswer",
            "promptTr", "answersTr", "correctAnswerTr", "explanation", "difficulty"]

MAX_PROMPT = 180   # mobil quiz ekranında okunabilir üst sınır
MAX_OPTION = 72
MIN_EXPL = 40


class Gate:
    def __init__(self, existing_prompts=None, existing_ids=None):
        self.existing_prompts = existing_prompts or {}
        self.existing_ids = set(existing_ids or [])
        # Near-duplicate taraması BATCH İÇİYLE sınırlıydı; mevcut bankaya
        # karşı bakmıyordu. Bu yüzden `ziman_x_0038` ("Hejmara «deh» bi
        # tirkî çend e?") kapıdan geçti ve yayımlanmış `offline_2035`
        # ("Hejmara «deh» bi Tirkî çi ye?") ile aynı bilgiyi soruyordu —
        # depo denetimi yakaladı, ben yakalayamadım (2026-08-06).
        self.existing_token_sets = [tokens(p) for p in (existing_prompts or [])]
        self.hard = collections.Counter()
        self.rows_ok = []
        self.rows_bad = []

    # ── per-row hard rules ───────────────────────────────────────────────
    def check_row(self, q, seen_ids, seen_prompts):
        errs = []
        for f in REQUIRED:
            if f not in q or q[f] in (None, "", []):
                errs.append(f"missing:{f}")
        if errs:
            return errs

        qid = str(q["id"])
        if qid in seen_ids or qid in self.existing_ids:
            errs.append("duplicate-id")
        if not re.fullmatch(r"[a-z0-9_]+", qid):
            errs.append("bad-id-format")

        ku_a, tr_a = list(q["answers"]), list(q["answersTr"])
        if len(ku_a) != len(tr_a):
            errs.append("answers-length-mismatch")
        if len(ku_a) < 4:
            errs.append("too-few-options")
        for arr, tag in ((ku_a, "ku"), (tr_a, "tr")):
            if any(not str(x).strip() for x in arr):
                errs.append(f"empty-option-{tag}")
            if len({norm_option(x) for x in arr}) != len(arr):
                errs.append(f"duplicate-option-{tag}")
            if any(ESCAPE_OPTS.match(str(x)) for x in arr):
                errs.append(f"escape-option-{tag}")
            if any(len(str(x)) > MAX_OPTION for x in arr):
                errs.append(f"option-too-long-{tag}")

        if q["correctAnswer"] not in ku_a:
            errs.append("correct-not-in-answers-ku")
        if q["correctAnswerTr"] not in tr_a:
            errs.append("correct-not-in-answers-tr")
        # iki dilde doğru cevap AYNI indekste olmalı
        try:
            if ku_a.index(q["correctAnswer"]) != tr_a.index(q["correctAnswerTr"]):
                errs.append("bilingual-correct-index-mismatch")
        except ValueError:
            pass

        p_ku, p_tr = str(q["prompt"]), str(q["promptTr"])
        if len(p_ku) > MAX_PROMPT or len(p_tr) > MAX_PROMPT:
            errs.append("prompt-too-long")
        if norm(p_ku) == norm(p_tr):
            errs.append("tr-ku-prompt-identical")
        for txt, tag in ((p_ku, "ku"), (p_tr, "tr")):
            if has_placeholder(txt):
                errs.append(f"placeholder-{tag}")
            if NON_LATIN.search(txt):
                errs.append(f"non-latin-script-{tag}")
        if not (KU_DIACRITICS & set(p_ku + " ".join(ku_a))):
            errs.append("ku-missing-diacritics")
        if AI_TR.search(p_tr):
            errs.append("ai-boilerplate-tr")
        if NEGATIVE.search(p_ku) or NEGATIVE.search(p_tr):
            errs.append("negative-stem")
        if VOLATILE.search(p_ku) or VOLATILE.search(p_tr):
            errs.append("volatile-fact")

        # answer leak: doğru cevap soru kökünde geçiyor
        ca = norm(q["correctAnswer"]); ca_tr = norm(q["correctAnswerTr"])
        if ca and len(ca) > 3 and ca in norm(p_ku):
            errs.append("answer-leak-ku")
        if ca_tr and len(ca_tr) > 3 and ca_tr in norm(p_tr):
            errs.append("answer-leak-tr")

        # Çeldirici KENDİNİ yanlış ilan etmemeli.
        #
        # 2026-08-06: dış havuzda 407 Grok adayının 296'sı (%72,7) şıklarında
        # "(ne rast)", "(yanlış)", "(geçersiz)" gibi etiketler taşıyordu —
        # ör. `["512 KB (yanlış)", ...]`. Oyuncu konuyu bilmeden etiketsiz
        # şıkkı seçip kazanır. Mevcut `answer-leak-*` kuralı bunu görmüyordu,
        # çünkü o yalnız doğru cevabın SORU KÖKÜNDE geçmesine bakıyor; buradaki
        # sızıntı şıkkın kendi içinde. Kapı 8 batch'in hepsine PASS demişti.
        for opt in ku_a + tr_a:
            if SELF_LABELED.search(str(opt)):
                errs.append("distractor-self-labeled")
                break

        if PLACEHOLDER_ID.search(p_ku) or PLACEHOLDER_ID.search(p_tr):
            errs.append("placeholder-id-leak")

        expl = str(q.get("explanation") or "")
        if len(expl) < MIN_EXPL:
            errs.append("explanation-too-short")
        if HEDGE.search(expl) and len(expl) < 80:
            errs.append("explanation-hedging")
        # açıklama yalnız doğru şıkkı tekrar etmemeli
        if norm(expl) == ca or norm(expl) == ca_tr:
            errs.append("explanation-restates-answer")

        d = q.get("difficulty")
        if not isinstance(d, int) or not 1 <= d <= 5:
            errs.append("bad-difficulty")

        # exact duplicate prompt (batch içi + mevcut banka)
        np = norm(p_ku)
        if np in seen_prompts or np in self.existing_prompts:
            errs.append("duplicate-prompt")
        t = tokens(p_ku)
        for et in self.existing_token_sets:
            u = t | et
            if u and len(t & et) / len(u) >= 0.7:
                errs.append("near-duplicate-of-existing")
                break

        return errs

    def run(self, rows):
        seen_ids, seen_prompts = set(), set()
        for q in rows:
            errs = self.check_row(q, seen_ids, seen_prompts)
            if errs:
                self.rows_bad.append({"question": q, "reasons": errs})
                for e in errs:
                    self.hard[e] += 1
            else:
                seen_ids.add(str(q["id"]))
                seen_prompts.add(norm(q["prompt"]))
                self.rows_ok.append(q)
        return self

    # ── batch-level distribution rules ───────────────────────────────────
    def distribution(self):
        rep = {}
        ok = self.rows_ok
        n = len(ok)
        rep["accepted"] = n
        rep["rejected"] = len(self.rows_bad)
        if not n:
            return rep

        pos = collections.Counter(q["answers"].index(q["correctAnswer"]) for q in ok)
        rep["position"] = {k: round(100 * v / n, 1) for k, v in sorted(pos.items())}
        # %23–27 bandı YAYIMLANAN BÜTÜN için anlamlıdır, tek batch için
        # değil: n=55'te bir pozisyonun payının standart sapması ~%5,8, yani
        # ±%2'lik bant 0,34 SD eder ve hiç önyargısı olmayan batch bile
        # gürültüden düşer (2026-08-06, cinema %22,2 ile düştü). Batch bandı
        # örnekleme göre; sıkı bant kümülatif korpusa uygulanır.
        pos_tol = max(3.0, 2.5 * math.sqrt(0.25 * 0.75 / n) * 100)
        rep["position_tolerance"] = round(pos_tol, 1)
        rep["position_ok"] = all(
            abs(100 * pos.get(i, 0) / n - 25.0) <= pos_tol for i in range(4))

        run_len, worst, prev = 0, 0, None
        for q in ok:
            i = q["answers"].index(q["correctAnswer"])
            run_len = run_len + 1 if i == prev else 1
            prev = i
            worst = max(worst, run_len)
        rep["longest_same_position_run"] = worst
        rep["run_ok"] = worst <= 3

        longest_correct = sum(1 for q in ok
                              if max(q["answers"], key=len) == q["correctAnswer"])
        pct = 100 * longest_correct / n
        rep["longest_option_is_correct_pct"] = round(pct, 1)
        # Tolerans SABİT olamaz: dört şıkta doğru cevabın en uzun olması
        # şans eseri %25'tir ve n=55'te bu oranın standart sapması ~%5,8'dir.
        # Sabit ±10 bandı, hiç önyargısı olmayan bir batch'i salt gürültüyle
        # reddediyordu (2026-08-06, tech_invent %14,5 ile düştü). Bant artık
        # örneklem büyüklüğüne göre daralır: küçük batch'te geniş, büyük
        # batch'te sıkı.
        sd = math.sqrt(0.25 * 0.75 / n) * 100
        rep["length_bias_tolerance"] = round(max(6.0, 2.5 * sd), 1)
        rep["length_bias_ok"] = abs(pct - 25.0) <= rep["length_bias_tolerance"]

        diff = collections.Counter(q["difficulty"] for q in ok)
        rep["difficulty"] = {k: round(100 * v / n, 1) for k, v in sorted(diff.items())}

        # near-duplicate (semantic-ish: token Jaccard)
        near, toks = 0, [tokens(q["prompt"]) for q in ok]
        buckets = collections.defaultdict(list)
        for idx, t in enumerate(toks):
            for tok in list(t)[:4]:
                buckets[tok].append(idx)
        seen_pairs = set()
        for idxs in buckets.values():
            for a in range(len(idxs)):
                for b in range(a + 1, len(idxs)):
                    i, j = idxs[a], idxs[b]
                    if (i, j) in seen_pairs:
                        continue
                    seen_pairs.add((i, j))
                    u = toks[i] | toks[j]
                    if u and len(toks[i] & toks[j]) / len(u) >= 0.82:
                        near += 1
        rep["near_duplicate_pairs"] = near
        rep["near_duplicate_pct"] = round(100 * near / n, 2)
        rep["near_duplicate_ok"] = (100 * near / n) <= 0.5

        starts = collections.Counter(" ".join(norm(q["prompt"]).split()[:3]) for q in ok)
        top = starts.most_common(1)[0][1] if starts else 0
        rep["top_prompt_template_pct"] = round(100 * top / n, 1)
        rep["template_ok"] = (100 * top / n) <= 12.0
        return rep


def load_index(path):
    if not path:
        return {}, []
    d = json.load(open(path, encoding="utf-8"))
    return set(d.get("prompts", [])), d.get("ids", [])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("batch")
    ap.add_argument("--existing-index")
    ap.add_argument("--quarantine")
    ap.add_argument("--accepted")
    ap.add_argument("--json-report")
    a = ap.parse_args()

    rows = json.load(open(a.batch, encoding="utf-8"))
    if isinstance(rows, dict):
        rows = rows.get("questions", [])
    prompts, ids = load_index(a.existing_index)
    g = Gate(prompts, ids).run(rows)
    rep = g.distribution()
    rep["hard_violations"] = dict(g.hard)

    print(f"batch            : {a.batch}")
    print(f"input rows       : {len(rows)}")
    print(f"accepted         : {rep['accepted']}")
    print(f"rejected         : {rep['rejected']}")
    if g.hard:
        print("hard violations  :")
        for k, v in g.hard.most_common():
            print(f"    {k:<34} {v}")
    for k in ("position", "longest_same_position_run", "longest_option_is_correct_pct",
              "difficulty", "near_duplicate_pct", "top_prompt_template_pct"):
        if k in rep:
            print(f"{k:<17}: {rep[k]}")

    gates = {k: rep[k] for k in rep if k.endswith("_ok")}
    print("distribution gates:", gates)

    if a.accepted:
        json.dump(g.rows_ok, open(a.accepted, "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
    if a.quarantine:
        json.dump(g.rows_bad, open(a.quarantine, "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)
    if a.json_report:
        json.dump(rep, open(a.json_report, "w", encoding="utf-8"),
                  ensure_ascii=False, indent=1)

    ok = (not g.hard) and all(gates.values())
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
