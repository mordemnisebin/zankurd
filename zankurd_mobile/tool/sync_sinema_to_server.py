#!/usr/bin/env python3
"""Yerel bankanın OYNANABİLİR Sînema sorularını sunucu göçüne (SQL) dönüştürür.

Sunucuya BAĞLANMAZ, SQL ÇALIŞTIRMAZ; yalnız iki dosya üretir/yeniler:
  supabase/2026-09-30_sinema_category_and_questions.sql

Niçin (2026-09-30 canlı denetimi): hızlı düello ve oda kurma konu listesi
sunucudaki `categories` tablosundan (is_active) geliyor; canlıda Sînema
kategorisi ve hiç sinema sorusu yoktu. Uygulamanın yerel bankasında ise
oynanabilir Sînema soruları var.

Seçim kümesi, uygulamanın `QuestionContentPolicy.isPlayable` kuralının
Python karşılığıdır (bkz. test/playable_inventory_test.dart):

  * `lib/src/data/question_bank_assets.dart` içindeki bankalar (yorum
    satırları hariç; DeepSeek karantinası orada zaten listede YOK) +
    `curated_question_bank.dart` (Sînema içermez; toplam sayı için sayılır);
  * `lib/src/config/retired_question_ids.dart` emeklileri hariç;
  * `hiddenCategoryIds` içindeki kategoriler hariç (Sînema görünür);
  * `metadata.reviewStatus` yok ya da `approved` (bilinmeyen değer Dart'ta
    `rejected` sayılır, burada da öyle);
  * yapısal geçerlilik: çoktan seçmelide tam 4 şık, doğru cevap şıklarda.

Sunucu şemasına sığanlar: `multipleChoice` (4 şık) ve `trueFalse`
(Rast/Şaş). Diğer türler (boşluk doldurma, cümle dizme, görselli) ve görsel
olmadan anlamını yitiren sorular ATLANIR ve sayılır.

Kullanım (proje kökü zankurd_mobile/ içinden):
  python3 tool/sync_sinema_to_server.py            # SQL'i yazar
  python3 tool/sync_sinema_to_server.py --check    # yalnız sayar/doğrular
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_SQL = ROOT / "supabase" / "2026-09-30_sinema_category_and_questions.sql"

# Sabit ad alanı: aynı yerel id her çalıştırmada aynı uuid'i verir, böylece
# `on conflict (id) do nothing` ile göç tekrar çalıştırılabilir. Bu değeri
# DEĞİŞTİRME; değişirse aynı sorular ikinci kez eklenir.
NAMESPACE = uuid.UUID("5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77")

CATEGORY_LOCAL = "Sînema"          # yerel bankadaki kanonik ad
CATEGORY_NAME = "Sînema"           # sunucu satırı (istemci bu adı tanır)
CATEGORY_SLUG = "sinema"

# "Görselsiz anlamını yitirir" işaretleri (Kurmancî + Türkçe istem).
IMAGE_DEPENDENT = re.compile(
    r"\b(di\s+w[êe]ney[êe]\s+de|li\s+w[êe]ney[êe]|w[êe]ney[êe]\s+de|"
    r"vî\s+w[êe]neyî|vê\s+w[êe]neyê|g[öo]rselde|resimde|fotoğrafta|"
    r"bu\s+g[öo]rsel|aşağıdaki\s+g[öo]rsel)\b",
    re.IGNORECASE,
)


def read_bank_assets() -> list[str]:
    src = (ROOT / "lib/src/data/question_bank_assets.dart").read_text(encoding="utf-8")
    no_comments = "\n".join(
        line for line in src.split("\n") if not line.strip().startswith("//")
    )
    return re.findall(r"'(assets/data/[^']+)'", no_comments)


def read_retired() -> set[str]:
    src = (ROOT / "lib/src/config/retired_question_ids.dart").read_text(
        encoding="utf-8"
    )
    body = src.split("retiredQuestionIds = <String>{", 1)[1].split("};", 1)[0]
    return set(re.findall(r"^\s*'([^']+)',", body, re.M))


def read_hidden_categories() -> set[str]:
    src = (ROOT / "lib/src/config/category_visibility.dart").read_text(
        encoding="utf-8"
    )
    body = src.split("hiddenCategoryIds = <String>{", 1)[1].split("};", 1)[0]
    return set(re.findall(r"'([^']+)'", body))


def review_status_ok(q: dict) -> bool:
    status = (q.get("metadata") or {}).get("reviewStatus")
    # Dart: null -> uygun; bilinmeyen değer -> rejected; approved -> uygun.
    return status is None or status == "approved"


def structurally_valid(q: dict) -> bool:
    if not q.get("prompt", "").strip() or not q.get("category", "").strip():
        return False
    answers = q.get("answers") or []
    t = q.get("type", "multipleChoice")
    if t == "fillInBlank":
        return len(answers) == 1 and bool(answers[0].strip())
    if t == "wordOrdering":
        return True  # sunucuya zaten alınmayacak; sayım için geçerli say
    if len(answers) < 2:
        return False
    if q.get("correctAnswer") not in answers:
        return False
    if t == "multipleChoice" and len(answers) < 4:
        return False
    if t == "visual" and not (q.get("imageUrl") or "").strip():
        return False
    return True


def load_playable_all() -> tuple[list[dict], dict]:
    """Oynanabilir tüm sorular (kategori bağımsız) ve sayım özeti."""
    retired = read_retired()
    hidden = read_hidden_categories()
    questions: list[dict] = []
    for asset in read_bank_assets():
        questions += json.loads((ROOT / asset).read_text(encoding="utf-8"))
    playable = [
        q
        for q in questions
        if q["category"] not in hidden
        and q["id"] not in retired
        and review_status_ok(q)
        and structurally_valid(q)
    ]
    return playable, {
        "loaded_json": len(questions),
        "retired": len(retired),
        "hidden": sorted(hidden),
    }


def sql_str(value: str | None) -> str:
    if value is None:
        return "NULL"
    if "\x00" in value:
        raise ValueError("NUL karakteri SQL metninde olamaz")
    return "'" + value.replace("'", "''") + "'"


def to_row(q: dict) -> dict:
    t = q.get("type", "multipleChoice")
    answers = list(q["answers"])
    meta = q.get("metadata") or {}
    if t == "trueFalse":
        if answers != ["Rast", "Şaş"]:
            raise ValueError(f"{q['id']}: beklenmeyen doğru/yanlış şıkları {answers}")
        opts = ["Rast", "Şaş", "-", "-"]
        qtype = "true_false"
    else:
        if len(answers) != 4:
            raise ValueError(f"{q['id']}: 4 şık yok")
        opts = answers
        qtype = "multiple_choice"
    letter = "ABCD"[answers.index(q["correctAnswer"])]
    ex_ku = (q.get("explanationKu") or "").strip() or None
    ex_tr = (q.get("explanationTr") or "").strip() or None
    ex = ex_ku or (q.get("explanation") or "").strip() or None
    ref = (meta.get("sourceReference") or "").strip() or None
    url = ref if ref and re.fullmatch(r"https?://\S+", ref) else None
    return {
        "id": str(uuid.uuid5(NAMESPACE, "zankurd-local:" + q["id"])),
        "local_id": q["id"],
        "prompt": q["prompt"].strip(),
        "opts": opts,
        "correct": letter,
        "explanation": ex,
        "explanation_ku": ex_ku,
        "explanation_tr": ex_tr,
        "difficulty": max(1, min(5, int(q.get("difficulty", 2)))),
        "qtype": qtype,
        "source_url": url,
        "source_title": (meta.get("sourceTitle") or "").strip() or None,
        "source_reference": ref,
        "quality_version": max(1, int(meta.get("qualityVersion") or 1)),
    }


def row_sql(r: dict) -> str:
    cat = f"(select id from categories where slug = {sql_str(CATEGORY_SLUG)})"
    vals = [
        sql_str(r["id"]),
        cat,
        "'ku-kmr'",
        sql_str(r["prompt"]),
        *[sql_str(o) for o in r["opts"]],
        sql_str(r["correct"]),
        sql_str(r["explanation"]),
        sql_str(r["explanation_ku"]),
        sql_str(r["explanation_tr"]),
        str(r["difficulty"]),
        "true",
        sql_str(r["qtype"]),
        "NULL",
        sql_str(r["source_url"]),
        sql_str(r["source_title"]),
        sql_str(r["source_reference"]),
        "'approved'",
        "'Kurmancî'",
        str(r["quality_version"]),
        "now()",
    ]
    return "(" + ", ".join(vals) + ")"


COLUMNS = (
    "id, category_id, language_code, prompt, option_a, option_b, option_c, "
    "option_d, correct_option, explanation, explanation_ku, explanation_tr, "
    "difficulty, is_approved, question_type, image_url, source_url, "
    "source_title, source_reference, review_status, dialect, quality_version, "
    "last_content_check_at"
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="dosya yazma")
    args = ap.parse_args()

    playable, info = load_playable_all()
    sinema = [q for q in playable if q["category"] == CATEGORY_LOCAL]

    picked: list[dict] = []
    skipped = collections.Counter()
    skipped_ids: dict[str, list[str]] = collections.defaultdict(list)
    for q in sinema:
        t = q.get("type", "multipleChoice")
        if t not in ("multipleChoice", "trueFalse"):
            skipped[f"tür:{t}"] += 1
            skipped_ids[f"tür:{t}"].append(q["id"])
            continue
        if (q.get("imageUrl") or "").strip() or IMAGE_DEPENDENT.search(
            q["prompt"] + " " + (q.get("promptTr") or "")
        ):
            skipped["görsel"] += 1
            skipped_ids["görsel"].append(q["id"])
            continue
        picked.append(q)

    rows = [to_row(q) for q in picked]
    kinds = collections.Counter(r["qtype"] for r in rows)
    print(f"Yüklenen JSON kaydı      : {info['loaded_json']}")
    print(f"Emekli id sayısı         : {info['retired']}")
    print(f"Gizli kategoriler        : {info['hidden']}")
    print(f"Oynanabilir (tüm kategori, curated hariç): {len(playable)}")
    print(f"Oynanabilir Sînema       : {len(sinema)}")
    print(f"Seçilen                  : {len(rows)} {dict(kinds)}")
    print(f"Atlanan                  : {dict(skipped)} {dict(skipped_ids)}")
    print(
        "correct_option dağılımı  :",
        dict(sorted(collections.Counter(r["correct"] for r in rows).items())),
    )
    print(
        "difficulty dağılımı      :",
        dict(sorted(collections.Counter(r["difficulty"] for r in rows).items())),
    )

    if len({r["id"] for r in rows}) != len(rows):
        print("HATA: uuid çakışması", file=sys.stderr)
        return 1
    if args.check:
        return 0

    n = len(rows)
    tf = kinds.get("true_false", 0)
    mc = kinds.get("multiple_choice", 0)
    skip_lines = (
        "\n".join(
            f"--   - {k}: {c} soru atlandı" for k, c in sorted(skipped.items())
        )
        or "--   - (atlanan yok: seçim kümesindeki tüm Sînema soruları şemaya sığdı)"
    )
    header = f"""-- 2026-09-30: Sînema kategorisi ve {n} sorusu (canlı sunucu).
--
-- NİÇİN: 2026-09-30 canlı denetiminde hızlı düello ve oda kurma konu listesi
-- sunucudaki `categories` tablosundan (is_active) geldiği hâlde orada
-- Sînema kategorisi yoktu; sunucuda hiç sinema sorusu da yoktu. Uygulamanın
-- yerel bankasında ise oynanabilir Sînema soruları vardı, yani tek kişilik
-- modda görünen konu düello/odada eksikti. İstemci sunucu kategori adını
-- 'Sînema' olarak tanır (CategoryVisuals kanonik ad; 'Sinema'/'Film' takma
-- adları da ona eşlenir), bu yüzden satır adı `Sînema`, slug `sinema`.
--
-- KAÇ SORU: {n} ({mc} çoktan seçmeli + {tf} doğru/yanlış).
--
-- SEÇİM KURALLARI (tool/sync_sinema_to_server.py, uygulamanın
-- QuestionContentPolicy.isPlayable kuralının Python karşılığı):
--   - question_bank_assets.dart bankaları; retired_question_ids.dart
--     emeklileri ve gizli kategoriler hariç;
--   - reviewStatus yok ya da approved; çoktan seçmelide tam 4 şık.
--   - Doğrulama: bu küme test/playable_inventory_test.dart'ın saydığı
--     oynanabilir kümeyle aynıdır; Sînema sayısı {len(sinema)}.
-- ATLANANLAR (sunucu şemasına sığmayan ya da görselsiz anlamını yitiren):
{skip_lines}
--
-- BİÇİM: metinler yalnız Kurmancî (prompt/şıklar); doğru/yanlış satırları
-- canlıdaki biçimle aynı: option_a 'Rast', option_b 'Şaş', option_c/d '-'.
-- explanation = Kurmancî açıklama; explanation_ku/explanation_tr yerel
-- alanlardan. Görsel yok (image_url NULL). Hepsi is_approved = true,
-- review_status = 'approved' (yerelde reviewStatus'u olmayan kayıtlar
-- uygulamada da oynanabilir sayıldığı için aynı kabul).
--
-- TEKRAR ÇALIŞTIRILABİLİR: kategori `where not exists` ile, sorular sabit
-- uuid5 kimlikleriyle (uuid5(ad alanı, "zankurd-local:" + yerel id)) ve
-- `on conflict (id) do nothing` ile eklenir; ikinci çalıştırma 0 satır ekler.
-- Tek işlemdir; sayı beklenenin altındaysa işlem geri alınır.
--
-- GERİ ALMA:
--   delete from questions where category_id = (select id from categories where slug = 'sinema');
--   delete from categories where slug = 'sinema';
-- (Yalnız bu göçün soruları değil kategorideki tüm sorular silinir; kategoride
-- başka soru eklendiyse id'ye göre silin.)
--
-- Doğrulama (salt okunur): 2026-09-30_sinema_verify.sql
"""
    body = ",\n".join(row_sql(r) for r in rows)
    sql = f"""{header}
begin;

insert into categories (name, slug, is_active)
select {sql_str(CATEGORY_NAME)}, {sql_str(CATEGORY_SLUG)}, true
where not exists (select 1 from categories where slug = {sql_str(CATEGORY_SLUG)});

insert into questions ({COLUMNS})
values
{body}
on conflict (id) do nothing;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from questions
  where category_id = (select id from categories where slug = {sql_str(CATEGORY_SLUG)})
    and is_approved = true;
  if v_count < {n} then
    raise exception 'Sinema: beklenen en az {n} onayli soru, bulunan %', v_count;
  end if;
end
$$;

commit;
"""
    OUT_SQL.write_text(sql, encoding="utf-8")
    print(f"Yazıldı: {OUT_SQL} ({len(sql)} bayt)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
