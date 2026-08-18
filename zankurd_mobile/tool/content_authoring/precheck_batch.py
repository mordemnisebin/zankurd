#!/usr/bin/env python3
"""Üretilen soru partisini `promote_question_bank.dart` kapısına sokmadan denetler.

Niçin var: kapı Dart tarafında koşar ve bir parti toptan reddedilirse gerekçeyi
`rejected_rows.csv`den okumak gerekir. Bu betik aynı kuralların ucuz olanlarını
üretimin hemen ardından uygular; böylece model çıktısı daha ilk turda
düzeltilebilir. Kapının yerine GEÇMEZ — pahalı kontroller (kanonik kopya
taraması, kategori dağılımı, dil uyumu) orada kalır.

Kurallar `tool/content_authoring/src/promotion.dart` içindeki
`content_promotion_v1` kapısından birebir alınmıştır.

Kullanım:
    python3 tool/content_authoring/precheck_batch.py parti.csv
    python3 tool/content_authoring/precheck_batch.py parti.csv --check-urls
"""
import csv
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

REQUIRED = [
    "id", "language_code", "category_key", "prompt",
    "option_a", "option_b", "option_c", "option_d",
    "correct_option", "explanation", "difficulty",
    "source_verified", "source_url", "publication_status", "confidence",
]
VERIFIED = {"verified", "doğrulandı", "dogrulandi", "evet", "yes", "true"}
PUBLISHABLE = {"reviewed", "approved", "published"}
# Kapı bu sözcükleri çözülmemiş editoryal sorun sayar; not alanına yazılmamalı.
UNRESOLVED = ["şablon", "tekrar", "sablon"]
TURKISH_ONLY = re.compile(r"[ığöüİ]")


def norm(value: str) -> str:
    return " ".join((value or "").strip().lower().split())


def template_key(prompt: str) -> str:
    """Kapının `templateKey` ölçüsünün BİREBİR karşılığı.

    İlk hâli "ilk üç sözcük + uzunluk kovası" idi ve fazla katıydı: aynı üç
    sözcükle başlayan her soruyu şablon sayıyordu. Gerçek kapı ise TÜM soru
    cümlesini karşılaştırır, yalnız tırnak içindeki terimleri ve sayıları
    maskeleyerek — yani iki soru ancak neredeyse aynı cümleyse çakışır.
    Yaklaşık ölçü 2149 satırlık ilk üretimde 800'den fazla iyi soruyu
    eliyordu (yalnız Ziman'da 237); ölçü kaynağına eşitlendi.
    """
    masked = re.sub(r'"[^"]*"', " TERM ", prompt)
    masked = re.sub(r"'[^']*'", " TERM ", masked)
    masked = re.sub(r"[«“][^»”]+[»”]", " TERM ", masked)
    masked = re.sub(r"\b\d+\b", " NUM ", masked)
    return norm(masked)


def url_alive(url: str) -> bool:
    """Kaynak adresi gerçekten açılıyor mu.

    Üretimi yapan ajana bu işi yaptırmak turlarını tüketiyordu ve CSV'ye hiç
    sıra gelmiyordu. Adres denetimi mekanik bir iştir; LLM turuna değil
    buraya ait.
    """
    # Yol kısmı yüzde-kodlanır: Kurmancî ve Türkçe başlıklar ASCII dışı harf
    # taşır ("…/wiki/Înternet") ve ham hâlleriyle istendiğinde istek düşer.
    # Kodlamayı atlamak bütün Kurmancî kaynaklarını "ölü" göstermek demekti.
    split = urllib.parse.urlsplit(url)
    encoded = urllib.parse.urlunsplit((
        split.scheme, split.netloc,
        urllib.parse.quote(split.path, safe="/%:@"),
        urllib.parse.quote(split.query, safe="=&%"), split.fragment,
    ))
    request = urllib.request.Request(encoded, headers={"User-Agent": "zankurd-precheck"})
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            return 200 <= response.status < 400
    except urllib.error.HTTPError as error:
        return 200 <= error.code < 400
    except Exception:
        return False


def main(path: str, check_urls: bool = False, write_clean: str | None = None) -> int:
    with open(path, newline="", encoding="utf-8") as handle:
        raw_rows = list(csv.reader(handle))
    with open(path, newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))

    # Alan sayısı önce ölçülür: bir satırda fazladan/eksik virgül varsa
    # bütün sütunlar kayar ve geri kalan her kural ayrı ayrı patlar. O hâlde
    # rapor sekiz gerekçe gösterir ve kök neden görünmez olur.
    if raw_rows:
        expected = len(raw_rows[0])
        shifted = [i for i, r in enumerate(raw_rows[1:], start=2)
                   if r and len(r) != expected]
        if shifted:
            print(f"HATA: {len(shifted)} satırda alan sayısı {expected} değil "
                  f"(ilk örnekler: {shifted[:8]})")
            print("Kök neden budur; sütunlar kaydığı için diğer kurallar da patlar.")
            return 1
    if not rows:
        print("HATA: parti boş")
        return 1

    missing_cols = [c for c in REQUIRED if c not in rows[0]]
    if missing_cols:
        print(f"HATA: eksik sütunlar: {', '.join(missing_cols)}")
        return 1

    seen_ids, seen_prompts, seen_expl = set(), set(), set()
    templates = Counter()
    problems = []

    for i, row in enumerate(rows, start=2):
        bad = []
        rid = (row["id"] or "").strip()
        prompt = (row["prompt"] or "").strip()
        expl = (row["explanation"] or "").strip()
        options = [(row[f"option_{c}"] or "").strip() for c in "abcd"]

        if not rid:
            bad.append("missing_id")
        elif rid in seen_ids:
            bad.append("duplicate_id")
        seen_ids.add(rid)

        if (row["language_code"] or "").strip().lower() != "ku-kmr":
            bad.append("unsupported_locale")
        if not (row["category_key"] or "").strip():
            bad.append("missing_category")

        if not prompt:
            bad.append("empty_prompt")
        elif len(prompt.split()) < 5:
            bad.append("prompt_too_simple")
        elif norm(prompt) in seen_prompts:
            bad.append("canonical_duplicate")
        seen_prompts.add(norm(prompt))

        if len(options) != 4 or any(not o for o in options):
            bad.append("invalid_options")
        elif len({norm(o) for o in options}) != 4:
            bad.append("duplicate_option")

        correct = (row["correct_option"] or "").strip()
        if correct.upper() in {"A", "B", "C", "D"}:
            answer = options["ABCD".index(correct.upper())]
        else:
            matches = [o for o in options if norm(o) == norm(correct)]
            answer = matches[0] if len(matches) == 1 else ""
            if not answer:
                bad.append("invalid_correct_answer")

        if len(expl) < 24:
            bad.append("short_explanation")
        elif norm(expl) in seen_expl:
            bad.append("explanation_duplicate")
        elif answer and norm(expl).startswith(norm(answer)) and \
                len(norm(expl)) <= len(norm(answer)) + 18:
            bad.append("explanation_repeats_answer")
        seen_expl.add(norm(expl))

        try:
            difficulty = int((row["difficulty"] or "").strip())
            if difficulty < 1 or difficulty > 3:
                bad.append("invalid_difficulty")
        except ValueError:
            bad.append("missing_difficulty")

        try:
            if float((row["confidence"] or "").strip()) < 0.9:
                bad.append("low_confidence")
        except ValueError:
            bad.append("missing_confidence")

        if norm(row["source_verified"]) not in VERIFIED:
            bad.append("unverified_source")
        if not (row["source_url"] or "").strip().startswith("https://"):
            bad.append("missing_source_url")
        if norm(row["publication_status"]) not in PUBLISHABLE:
            bad.append("unpublishable_status")

        note = norm(row.get("notes", "") or "") + " " + norm(row.get("issue_type", "") or "")
        if any(word in note for word in UNRESOLVED):
            bad.append("editorial_issue")

        # Kurmancî taşıyıcı cümlede Türkçeye özgü harf olmamalı; tırnak içi
        # (çevrilecek Türkçe) muaf — `question_bank_kurmanci_carrier_test`
        # ile aynı kural.
        carrier = re.sub(r'"[^"]*"|\([^)]*\)', " ", prompt)
        if TURKISH_ONLY.search(carrier):
            bad.append("turkish_letter_in_kurmanci")

        key = template_key(prompt)
        templates[key] += 1
        if templates[key] > 3:
            bad.append("template_density")

        if bad:
            problems.append((i, rid or "?", bad))

    if check_urls:
        urls = sorted({(r.get("source_url") or "").strip() for r in rows
                       if (r.get("source_url") or "").strip().startswith("https://")})
        with ThreadPoolExecutor(max_workers=8) as pool:
            alive = dict(zip(urls, pool.map(url_alive, urls)))
        dead = [u for u, ok in alive.items() if not ok]
        for i, row in enumerate(rows, start=2):
            url = (row.get("source_url") or "").strip()
            if url in alive and not alive[url]:
                problems.append((i, (row.get("id") or "?").strip(), ["dead_source_url"]))
        if dead:
            print(f"ölü kaynak adresi: {len(dead)}/{len(urls)}")
            for u in dead[:10]:
                print(f"   {u}")

    # ── Parti geneli kalite ölçüleri ───────────────────────────────────
    # Bunlar satır bazında kusur değil; ancak partinin TAMAMINA bakınca
    # görünürler ve kapı onları hiç ölçmez. İlk gerçek üretimde doğru cevap
    # on satırın onunda da A çıktı — oyuncu "hep A'yı seç" diye öğrenir.
    letters = Counter()
    for row in rows:
        correct = (row.get("correct_option") or "").strip().upper()
        if correct in "ABCD" and correct:
            letters[correct] += 1
    total_letters = sum(letters.values())
    if total_letters >= 8:
        top, top_n = letters.most_common(1)[0]
        share = top_n / total_letters
        dagilim = " ".join(f"{h}={letters.get(h, 0)}" for h in "ABCD")
        if share > 0.45:
            print(f"UYARI: doğru cevap {top} şıkkında yığılmış "
                  f"(%{share * 100:.0f}) — dağılım: {dagilim}")
            print("       Oyuncu konumu ezberler; promptta dağılım şart koş.")
        else:
            print(f"doğru cevap dağılımı dengeli: {dagilim}")

    # Aynı çeldirici bütün partide dolaşıyorsa sorular birbirinin kopyası
    # gibi hissettirir ve şıklar inandırıcılığını yitirir.
    fillers = Counter()
    for row in rows:
        for col in "abcd":
            value = norm(row.get(f"option_{col}", ""))
            if value:
                fillers[value] += 1
    overused = [(v, n) for v, n in fillers.most_common(5) if n > max(3, len(rows) // 3)]
    if overused:
        print("UYARI: aşırı tekrar eden çeldiriciler: "
              + ", ".join(f"{v} ({n}x)" for v, n in overused))

    # Bir satır hem satır kurallarından hem URL denetiminden düşebilir;
    # ikisi ayrı ayrı sayılınca "temiz" eksiye iniyordu.
    merged: dict[int, tuple[int, str, list[str]]] = {}
    for line, rid, reasons in problems:
        if line in merged:
            merged[line][2].extend(reasons)
        else:
            merged[line] = (line, rid, list(reasons))
    problems = [merged[k] for k in sorted(merged)]

    if write_clean:
        bad_lines = {line for line, _, _ in problems}
        keep = [row for i, row in enumerate(rows, start=2) if i not in bad_lines]
        with open(write_clean, "w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
            writer.writeheader()
            writer.writerows(keep)
        print(f"temiz satırlar yazıldı -> {write_clean} ({len(keep)})")

    print(f"satır: {len(rows)}   sorunlu: {len(problems)}   temiz: {len(rows) - len(problems)}")
    if problems:
        counts = Counter(r for _, _, reasons in problems for r in reasons)
        print("\ngerekçeler:")
        for reason, n in counts.most_common():
            print(f"  {n:5d}  {reason}")
        print("\nilk 15 sorunlu satır:")
        for line, rid, reasons in problems[:15]:
            print(f"  satır {line} ({rid}): {', '.join(reasons)}")
    return 1 if problems else 0


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        print(__doc__)
        sys.exit(2)
    clean_out = None
    for arg in sys.argv:
        if arg.startswith("--write-clean="):
            clean_out = arg.split("=", 1)[1]
    sys.exit(main(args[0], check_urls="--check-urls" in sys.argv,
                  write_clean=clean_out))
