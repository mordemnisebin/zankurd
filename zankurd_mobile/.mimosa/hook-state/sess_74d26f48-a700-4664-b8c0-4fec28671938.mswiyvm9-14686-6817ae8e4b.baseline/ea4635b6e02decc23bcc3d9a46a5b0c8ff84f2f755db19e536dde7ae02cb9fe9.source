"""Build a guarded live migration for remaining non-Kurmancî question text."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import time
import urllib.parse
import urllib.request
from collections import Counter
from functools import lru_cache
from pathlib import Path


PROJECT_REF = "hupivnxgjtsfafulzspo"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "supabase" / "2026-07-16_editorial_kurmanci_translation.sql"
KU_START = re.compile(r"^(?:Di|Bi|Ji|Li|Wateya|Kîjan|Çi|Ma|Rast e|Şaş e)\b")
TR_MARKERS = re.compile(
    r"\b(?:hangi|hangisi|nedir|neyi|neye|neyle|nasıl|neden|kimdir|kaç|nerede|"
    r"olarak|için|ile|ve|veya|değil|doğru|yanlış|anlamına|gelir|yazılmış|"
    r"bulunur|yaşamıştır|ülke|şehir|bölge|kültür|tarih|edebiyat|müzik|"
    r"coğrafya|toplum|sadece|önemlidir|ifadesi|kavramı|aşağıdaki|günümüzde)\b",
    re.IGNORECASE,
)
TERM_KU = {
    "kilim motifleri": "motîfên kilîmê",
    "misafirperverlik": "mêvanperwerî",
    "yerel kıyafetler": "cil û bergên herêmî",
    "ağıt": "şîn",
    "masal anlatımı": "vegotina çîrokan",
    "bayramlaşma": "pîrozbahîya cejnê",
    "halk mutfağı": "pêjgeha gelêrî",
    "birincil kaynak": "çavkaniya destpêkê",
    "sözlü tarih": "dîroka devkî",
    "kronoloji": "kronolojî",
    "arkeoloji": "arkeolojî",
    "göç": "koç",
    "yerleşik yaşam": "jiyana niştecih",
    "ticaret yolu": "rêya bazirganiyê",
    "kültürel etkileşim": "bandora çandî",
    "tarihsel yorum": "şîroveya dîrokî",
    "karakter": "karakter",
    "tema": "mijar",
    "mecaz": "mecaz",
    "kafiye": "serwa",
    "anlatıcı": "vebêjer",
    "diyalog": "dialog",
    "dağ": "çiya",
    "ova": "deşt",
    "su": "av",
    "akarsu": "çem",
    "göl": "gol",
    "orman": "daristan",
    "vadi": "newal",
    "hava": "hewa",
    "yer/toprak": "erd",
    "sınır": "sînor",
    "ezgili sözlü anlatım": "vegotina devkî ya bi awaz",
    "düzenli vuruş": "lêdanên birêkûpêk",
    "ezgi": "awaz",
    "şarkı": "stran",
    "vurmalı çalgı": "amûra lêdanê",
    "telli çalgı": "amûra têlî",
    "müziği yazma işareti": "nîşana nivîsandina muzîkê",
    "toplu söyleme": "bi komê stranbêjî",
    "tek kişinin icrası": "performansa kesekî",
}


def ku_term(value: str) -> str:
    return TERM_KU.get(value.casefold(), value)


def sql_literal(value: str | None) -> str:
    if value is None:
        return "null"
    return "'" + value.replace("'", "''") + "'"


def management_query(query: str) -> list[dict[str, object]]:
    token = os.environ.get("SUPABASE_ACCESS_TOKEN")
    if not token:
        raise SystemExit("SUPABASE_ACCESS_TOKEN is required")
    request = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query",
        data=json.dumps({"query": query}).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "Mozilla/5.0",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.load(response)


@lru_cache(maxsize=None)
def google_translate(text: str, source: str = "auto") -> tuple[str, str]:
    query = urllib.parse.urlencode(
        {"client": "gtx", "sl": source, "tl": "ku", "dt": "t", "q": text}
    )
    last_error: Exception | None = None
    for attempt in range(4):
        try:
            with urllib.request.urlopen(
                "https://translate.googleapis.com/translate_a/single?" + query,
                timeout=30,
            ) as response:
                payload = json.load(response)
            translated = "".join(part[0] for part in payload[0] if part and part[0])
            return translated.strip(), str(payload[2])
        except Exception as error:  # network retry, then fail closed
            last_error = error
            time.sleep(0.4 * (attempt + 1))
    raise RuntimeError(f"Translation failed after retries: {last_error}")


def translate_preserving_quotes(text: str, source: str = "auto") -> tuple[str, str]:
    quoted = re.findall(r'["“][^"”]+["”]', text)
    masked = text
    for index, value in enumerate(quoted):
        masked = masked.replace(value, f"ZXQ{index}QXZ", 1)
    translated, detected = google_translate(masked, source)
    for index, value in enumerate(quoted):
        translated = translated.replace(f"ZXQ{index}QXZ", value)
    return translated, detected


def manual_prompt(text: str) -> str | None:
    patterns = (
        (
            r'^Peyva ("[^"]+") ("[^"]+") anlamına gelir\.$',
            lambda m: f"Peyva {m[1]} bi Tirkî tê wateya {m[2]}.",
        ),
        (
            r'^Kurmancî\'de ("[^"]+") hangi sayıdır\?$',
            lambda m: f"Di Kurmancî de {m[1]} kîjan hejmar e?",
        ),
        (
            r'^Kurmancî\'de ("[^"]+") hangi renktir\?$',
            lambda m: f"Di Kurmancî de {m[1]} kîjan reng e?",
        ),
        (
            r'^Kurmancî\'de ("[^"]+") ne demek\?$',
            lambda m: f"Di Kurmancî de wateya {m[1]} çi ye?",
        ),
        (
            r'^("[^"]+") Türkçesi\?$',
            lambda m: f"Wateya {m[1]} bi Tirkî çi ye?",
        ),
        (
            r'^("[^"]+") ne demek\?$',
            lambda m: f"Wateya {m[1]} bi Tirkî çi ye?",
        ),
        (
            r'^("[^"]+") ne anlama gelir\?$',
            lambda m: f"Wateya {m[1]} bi Tirkî çi ye?",
        ),
        (
            r'^Kürt kültüründe (.+) en çok hangi alanla ilişkilidir\?$',
            lambda m: f"Di çanda Kurdî de {ku_term(m[1])} herî zêde bi kîjan qadê re têkildar e?",
        ),
        (
            r'^Kürt kültüründe (.+) kültürel hafızayla ilişkilendirilebilir\.$',
            lambda m: f"Di çanda Kurdî de {ku_term(m[1])} bi bîra çandî re têkildar e.",
        ),
        (
            r'^Kürt kültüründe (.+) sadece teknik bir ölçü birimidir\.$',
            lambda m: f"Di çanda Kurdî de {ku_term(m[1])} tenê yekeyeke pîvanê ya teknîkî ye.",
        ),
        (
            r'^Kürt kültüründe (.+) hakkında hangisi daha doğrudur\?$',
            lambda m: f"Di derbarê {ku_term(m[1])} de kîjan rasttir e?",
        ),
        (
            r'^Kürt ve Kürdistan tarihini çalışırken (.+) neyi ifade eder\?$',
            lambda m: f"Di lêkolîna dîroka Kurd û Kurdistanê de {ku_term(m[1])} çi tê wateyê?",
        ),
        (
            r'^(.+) Kürt ve Kürdistan tarihini anlamada kullanılabilir\.$',
            lambda m: f"{ku_term(m[1])} ji bo têgihîştina dîroka Kurd û Kurdistanê dikare were bikaranîn.",
        ),
        (
            r'^Kürt ve Kürdistan tarihi için (.+) kavramının en uygun açıklaması hangisidir\?$',
            lambda m: f"Ji bo dîroka Kurd û Kurdistanê ravekirina herî rast a têgeha {ku_term(m[1])} kîjan e?",
        ),
        (
            r'^Kürt edebiyatında (.+) ne anlama gelir\?$',
            lambda m: f"Di edebiyata Kurdî de {ku_term(m[1])} çi tê wateyê?",
        ),
        (
            r'^(.+) Kürt edebiyatıyla ilgili bir kavramdır\.$',
            lambda m: f"{ku_term(m[1])} têgeheke edebiyata Kurdî ye.",
        ),
        (
            r'^Kürdistan coğrafyası bağlamında Kurmancîde ("[^"]+") neye yakındır\?$',
            lambda m: f"Di erdnîgariya Kurdistanê de peyva {m[1]} bi Tirkî çi ye?",
        ),
        (
            r'^(.+) Kürdistan coğrafyasını anlamada kullanılabilecek kavramlardan biridir\.$',
            lambda m: f"{ku_term(m[1])} yek ji têgehên ji bo têgihîştina erdnîgariya Kurdistanê ye.",
        ),
        (
            r'^Kürdistan coğrafyasında (.+) için en uygun Kurmancî kelime hangisidir\?$',
            lambda m: f"Di Kurmancî de ji bo peyva Tirkî \"{m[1]}\" peyva herî rast kîjan e?",
        ),
        (
            r'^Kürt müziğinde (.+) neyle ilgilidir\?$',
            lambda m: f"Di muzîka Kurdî de {ku_term(m[1])} bi çi re têkildar e?",
        ),
        (
            r'^(.+) Kürt müziğiyle ilişkilendirilebilir\.$',
            lambda m: f"{ku_term(m[1])} bi muzîka Kurdî re têkildar e.",
        ),
        (
            r'^Kürt müziğinde (.+) ifadesi en çok hangi kavramı açıklar\?$',
            lambda m: f"Di muzîka Kurdî de ravekirina \"{ku_term(m[1])}\" kîjan têgehê diyar dike?",
        ),
    )
    for pattern, replacement in patterns:
        match = re.match(pattern, text)
        if match:
            return replacement(match)
    fixed = {
        "Kürt ve Kürdistan tarihi yalnızca savaş adlarını ezberlemekten oluşur.":
            "Dîroka Kurd û Kurdistanê tenê ji ezberkirina navên şeran pêk tê.",
        "Mem û Zîn genellikle Ehmedê Xanî ve Kürt edebiyatı ile ilişkilendirilir.":
            "Mem û Zîn bi gelemperî bi Ehmedê Xanî û edebiyata Kurdî re tê girêdan.",
        "Aşağıdakilerden hangisi Kürt edebiyatıyla ilişkilendirilen bir isimdir?":
            "Ji yên jêrîn kîjan kes bi edebiyata Kurdî re tê girêdan?",
        "Kürdistan coğrafyasında iklim, bitki örtüsü ve yeryüzü şekilleri önemlidir.":
            "Di erdnîgariya Kurdistanê de avhewa, şînkatî û teşeyên rûerdê girîng in.",
        "Dengbêjlik Kürt sözlü kültürü ve ezgiyle ilişkilendirilebilir.":
            "Dengbêjî bi çanda devkî û awaza Kurdî re têkildar e.",
    }
    if text in fixed:
        return fixed[text]
    return None


def prompt_translation(text: str) -> tuple[str, str]:
    manual = manual_prompt(text)
    if manual:
        return manual, "manual"
    if text.startswith(('Bi Kurmancî "', "Di Kurmancî de", "Wateya peyva")):
        return text, "ku"
    if KU_START.match(text):
        return text, "ku"
    source = "tr" if TR_MARKERS.search(text) or text.startswith("Kurmancî'de") else "auto"
    translated, detected = translate_preserving_quotes(text, source)
    if source == "auto" and detected != "tr":
        return text, detected
    return translated, detected


def explanation_translation(text: str | None) -> tuple[str | None, str]:
    if not text:
        return text, "empty"
    match = re.match(r'^("[^"]+") ([^"]+) anlamına gelir\.$', text)
    if match:
        return f'{match[1]} bi Tirkî tê wateya "{match[2]}".', "manual"
    match = re.match(r'^("[^"]+") ([^"]+) demektir\.$', text)
    if match:
        return f'{match[1]} bi Tirkî tê wateya "{match[2]}".', "manual"
    translated, detected = translate_preserving_quotes(text, "auto")
    if detected == "ku":
        return text, detected
    return translated, detected


def translate_row(row: dict[str, object]) -> tuple[dict[str, object] | None, Counter[str]]:
    stats: Counter[str] = Counter()
    prompt = str(row["prompt"])
    new_prompt, prompt_language = prompt_translation(prompt)
    stats[f"prompt:{prompt_language}"] += 1
    prompt_changed = new_prompt != prompt

    explanation = row.get("explanation")
    explanation_text = str(explanation) if explanation is not None else None
    needs_explanation = prompt_changed or (
        row.get("source_url") == "zankurd_seed_rich_v2"
        and not row.get("explanation_ku")
    )
    new_explanation = explanation_text
    explanation_language = "skipped"
    if needs_explanation:
        new_explanation, explanation_language = explanation_translation(explanation_text)
    stats[f"explanation:{explanation_language}"] += 1
    explanation_changed = new_explanation != explanation_text

    if not prompt_changed and not explanation_changed:
        return None, stats

    original_tr = row.get("explanation_tr")
    if explanation_changed and explanation_language == "tr" and not original_tr:
        original_tr = explanation_text
    patched = {
        **row,
        "prompt": new_prompt,
        "explanation": new_explanation,
        "explanation_ku": new_explanation if explanation_changed else row.get("explanation_ku"),
        "explanation_tr": original_tr,
    }
    return patched, stats


def render_sql(rows: list[dict[str, object]]) -> str:
    ids = ", ".join(sql_literal(str(row["id"])) for row in rows)
    blocks = [
        "-- Generated editorial translation patch; prompt/options answers are guarded.",
        "begin;",
        "create table if not exists questions_editorial_backup_20260716_phase2",
        "  as select * from questions where false;",
        "insert into questions_editorial_backup_20260716_phase2",
        f"select q.* from questions q where q.id in ({ids})",
        "and not exists (select 1 from questions_editorial_backup_20260716_phase2 b where b.id=q.id);",
    ]
    for start in range(0, len(rows), 150):
        values = []
        for row in rows[start : start + 150]:
            values.append(
                "(" + ", ".join(
                    sql_literal(row.get(key) if row.get(key) is None else str(row[key]))
                    for key in (
                        "id",
                        "prompt",
                        "explanation",
                        "explanation_ku",
                        "explanation_tr",
                        "correct_option",
                    )
                ) + ")"
            )
        blocks.extend(
            [
                "with patch(id,prompt,explanation,explanation_ku,explanation_tr,correct_option) as (values",
                ",\n".join(values),
                ") update questions q set",
                "  prompt=p.prompt, explanation=p.explanation, explanation_ku=p.explanation_ku,",
                "  explanation_tr=p.explanation_tr, quality_version=coalesce(q.quality_version,0)+1, updated_at=now()",
                "from patch p where q.id=p.id::uuid and q.correct_option=p.correct_option and q.is_approved;",
            ]
        )
    blocks.extend(["commit;", ""])
    return "\n".join(blocks)


def self_test() -> None:
    assert manual_prompt('Peyva "nav" "söz" anlamına gelir.') == (
        'Peyva "nav" bi Tirkî tê wateya "söz".'
    )
    assert manual_prompt('Kurmancî\'de "sed" hangi sayıdır?') == (
        'Di Kurmancî de "sed" kîjan hejmar e?'
    )
    assert prompt_translation('Bi Kurmancî "doğru" çi ye?')[0] == (
        'Bi Kurmancî "doğru" çi ye?'
    )
    assert manual_prompt(
        "Kürt kültüründe govend en çok hangi alanla ilişkilidir?"
    ) == "Di çanda Kurdî de govend herî zêde bi kîjan qadê re têkildar e?"
    assert manual_prompt(
        'Kürdistan coğrafyası bağlamında Kurmancîde "çiya" neye yakındır?'
    ) == 'Di erdnîgariya Kurdistanê de peyva "çiya" bi Tirkî çi ye?'
    assert ku_term("Sözlü tarih") == "dîroka devkî"
    assert explanation_translation(
        '"Navê te çi ye?" adın ne? anlamına gelir.'
    )[0] == '"Navê te çi ye?" bi Tirkî tê wateya "adın ne?".'


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    self_test()
    if args.self_test:
        print("self-test: ok")
        return

    rows = management_query(
        "select id,prompt,explanation,explanation_ku,explanation_tr,source_url,correct_option "
        "from public.questions where is_approved order by id"
    )
    translated: list[dict[str, object]] = []
    stats: Counter[str] = Counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        for patched, row_stats in executor.map(translate_row, rows):
            stats.update(row_stats)
            if patched:
                translated.append(patched)

    if not translated:
        raise SystemExit("No translations generated")
    if len({row["id"] for row in translated}) != len(translated):
        raise SystemExit("Duplicate question IDs in generated patch")
    for row in translated:
        if not str(row["prompt"]).strip() or row["correct_option"] not in "ABCD":
            raise SystemExit(f"Invalid generated row: {row['id']}")

    args.output.write_text(render_sql(translated), encoding="utf-8")
    print(json.dumps({"fetched": len(rows), "updates": len(translated), **stats}, ensure_ascii=False, indent=2))
    print(f"wrote: {args.output}")


if __name__ == "__main__":
    main()
