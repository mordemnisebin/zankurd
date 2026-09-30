#!/usr/bin/env python3
"""«Cîhan» kategorisini ve 40 bilim sorusunu sunucu göçüne (SQL) dönüştürür.

Sunucuya BAĞLANMAZ, SQL ÇALIŞTIRMAZ; yalnız şu dosyayı üretir/yeniler:
  supabase/2026-09-30_cihan_and_science.sql

Niçin (2026-09-30): uygulamaya yeni `Cîhan` (Dünya) kategorisi geldi ve
Paradigma («Bilim ve Düşünce») 40 yeni soru aldı. Hızlı düello ve oda kurma
konu listesi sunucudaki `categories` tablosundan (is_active) geliyor; Cîhan
orada yok, bilim soruları da sunucuda yok. Aynı yol `sync_sinema_to_server.py`
ile Sînema için izlenmişti; bu araç o aracın seçim kuralını, uuid5 şemasını
ve satır biçimini AYNEN yeniden kullanır (içe aktarır) — ikisi ayrışırsa aynı
yerel id iki farklı uuid alır.

Seçim kümesi (uygulamanın `QuestionContentPolicy.isPlayable` kuralının
Python karşılığı, bkz. `sync_sinema_to_server.load_playable_all`):
  * `Cîhan` kategorisinin TÜM oynanabilir soruları (çoktan seçmeli ve
    doğru/yanlış; görselli/boşluk doldurma atlanır ve sayılır);
  * `Paradigma` kategorisinden yalnız `bilim_` kimlikli 40 yeni soru (eski
    Paradigma soruları sunucuda zaten var/onaydan çıkarılmıştı; dokunulmaz).

Kullanım (proje kökü zankurd_mobile/ içinden):
  python3 tool/sync_categories_to_server.py            # SQL'i yazar
  python3 tool/sync_categories_to_server.py --check    # yalnız sayar/doğrular
"""
from __future__ import annotations

import argparse
import collections
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_sinema_to_server as base  # noqa: E402

ROOT = base.ROOT
OUT_SQL = ROOT / "supabase" / "2026-09-30_cihan_and_science.sql"

CIHAN = {"local": "Cîhan", "name": "Cîhan", "slug": "cihan"}
PARADIGMA_SLUG = "paradigma"  # sunucuda zaten var; burada oluşturulmaz
SCIENCE_PREFIX = "bilim_"


def select(playable: list[dict]):
    picked: dict[str, list[dict]] = {CIHAN["slug"]: [], PARADIGMA_SLUG: []}
    skipped = collections.Counter()
    skipped_ids: dict[str, list[str]] = collections.defaultdict(list)
    for q in playable:
        if q["category"] == CIHAN["local"]:
            slug = CIHAN["slug"]
        elif q["category"] == "Paradigma" and q["id"].startswith(SCIENCE_PREFIX):
            slug = PARADIGMA_SLUG
        else:
            continue
        t = q.get("type", "multipleChoice")
        if t not in ("multipleChoice", "trueFalse"):
            skipped[f"tür:{t}"] += 1
            skipped_ids[f"tür:{t}"].append(q["id"])
            continue
        if (q.get("imageUrl") or "").strip() or base.IMAGE_DEPENDENT.search(
            q["prompt"] + " " + (q.get("promptTr") or "")
        ):
            skipped["görsel"] += 1
            skipped_ids["görsel"].append(q["id"])
            continue
        picked[slug].append(q)
    return picked, skipped, skipped_ids


def row_sql(r: dict, slug: str) -> str:
    cat = f"(select id from categories where slug = {base.sql_str(slug)})"
    vals = [
        base.sql_str(r["id"]),
        cat,
        "'ku-kmr'",
        base.sql_str(r["prompt"]),
        *[base.sql_str(o) for o in r["opts"]],
        base.sql_str(r["correct"]),
        base.sql_str(r["explanation"]),
        base.sql_str(r["explanation_ku"]),
        base.sql_str(r["explanation_tr"]),
        str(r["difficulty"]),
        "true",
        base.sql_str(r["qtype"]),
        "NULL",
        base.sql_str(r["source_url"]),
        base.sql_str(r["source_title"]),
        base.sql_str(r["source_reference"]),
        "'approved'",
        "'Kurmancî'",
        str(r["quality_version"]),
        "now()",
    ]
    return "(" + ", ".join(vals) + ")"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="dosya yazma")
    args = ap.parse_args()

    playable, info = base.load_playable_all()
    picked, skipped, skipped_ids = select(playable)
    rows = {slug: [base.to_row(q) for q in qs] for slug, qs in picked.items()}
    n_cihan = len(rows[CIHAN["slug"]])
    n_sci = len(rows[PARADIGMA_SLUG])
    all_rows = rows[CIHAN["slug"]] + rows[PARADIGMA_SLUG]

    print(f"Yüklenen JSON kaydı      : {info['loaded_json']}")
    print(f"Emekli id sayısı         : {info['retired']}")
    print(f"Oynanabilir (tüm kategori, curated hariç): {len(playable)}")
    print(f"Cîhan seçilen            : {n_cihan}")
    print(f"Bilim (Paradigma) seçilen: {n_sci}")
    print(f"Atlanan                  : {dict(skipped)} {dict(skipped_ids)}")
    for slug, rs in rows.items():
        print(
            f"correct_option [{slug}]:",
            dict(sorted(collections.Counter(r["correct"] for r in rs).items())),
            "türler:",
            dict(collections.Counter(r["qtype"] for r in rs)),
        )
    if len({r["id"] for r in all_rows}) != len(all_rows):
        print("HATA: uuid çakışması", file=sys.stderr)
        return 1
    if n_sci != 40:
        print(f"HATA: 40 bilim sorusu bekleniyordu, {n_sci} bulundu", file=sys.stderr)
        return 1
    if args.check:
        return 0

    skip_lines = (
        "\n".join(f"--   - {k}: {c} soru atlandı" for k, c in sorted(skipped.items()))
        or "--   - (atlanan yok: seçim kümesindeki tüm sorular şemaya sığdı)"
    )
    header = f"""-- 2026-09-30: «Cîhan» kategorisi ({n_cihan} soru) + Paradigma'ya {n_sci} bilim sorusu (canlı sunucu).
--
-- NİÇİN: uygulamaya yeni `Cîhan` (Türkçe «Dünya») kategorisi geldi: Kürtlerle
-- doğrudan bağı olmayan nötr genel bilgi (dünya sineması, dünya coğrafyası,
-- tarih ve genel kültür; ürünün ~%30'u). Hızlı düello ve oda kurma konu
-- listesi sunucudaki `categories` tablosundan (is_active) geldiği için
-- kategori orada yoksa düello/odada görünmez. Ayrıca Paradigma
-- («Bilim ve Düşünce») 40 yeni kaynaklı soru aldı (bilim_0001…bilim_0040);
-- sunucuda Paradigma soruları çoğunlukla onaydan çıkarılmıştı
-- (2026-09-30_contested_questions_unapprove.sql).
--
-- KAÇ SORU: Cîhan {n_cihan}; Paradigma'ya {n_sci} (yeni, `bilim_` kimlikli).
--
-- SEÇİM KURALLARI (tool/sync_categories_to_server.py; seçim ve satır biçimi
-- tool/sync_sinema_to_server.py ile ortak, uygulamanın
-- QuestionContentPolicy.isPlayable kuralının Python karşılığı):
--   - question_bank_assets.dart bankaları; retired_question_ids.dart
--     emeklileri ve gizli kategoriler hariç;
--   - reviewStatus yok ya da approved; çoktan seçmelide tam 4 şık.
-- ATLANANLAR (sunucu şemasına sığmayan ya da görselsiz anlamını yitiren):
{skip_lines}
--
-- BİÇİM: metinler yalnız Kurmancî (prompt/şıklar); explanation = Kurmancî
-- açıklama; explanation_ku/explanation_tr yerel alanlardan. Hepsi
-- is_approved = true, review_status = 'approved'. Sunucu kategorisi
-- `Cîhan` (slug `cihan`) yeni oluşturulur; `paradigma` zaten vardır.
--
-- TEKRAR ÇALIŞTIRILABİLİR: kategori `where not exists` ile, sorular sabit
-- uuid5 kimlikleriyle (uuid5(ad alanı, "zankurd-local:" + yerel id), ad alanı
-- sync_sinema_to_server.py ile aynı) ve `on conflict (id) do nothing` ile
-- eklenir; ikinci çalıştırma 0 satır ekler. Tek işlemdir; doğrulama bloğu
-- beklenenin altında kalırsa işlem geri alınır.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from questions where id in (<bu dosyadaki id'ler>);
--   delete from categories where slug = 'cihan' and not exists
--     (select 1 from questions where category_id = categories.id);
--
-- Uygulama: supabase db query --linked -f supabase/2026-09-30_cihan_and_science.sql
"""
    cihan_values = ",\n".join(row_sql(r, CIHAN["slug"]) for r in rows[CIHAN["slug"]])
    sci_values = ",\n".join(row_sql(r, PARADIGMA_SLUG) for r in rows[PARADIGMA_SLUG])
    sci_ids = ", ".join(base.sql_str(r["id"]) for r in rows[PARADIGMA_SLUG])
    sql = f"""{header}
begin;

insert into categories (name, slug, is_active)
select {base.sql_str(CIHAN["name"])}, {base.sql_str(CIHAN["slug"])}, true
where not exists (select 1 from categories where slug = {base.sql_str(CIHAN["slug"])});

-- Cîhan ({n_cihan})
insert into questions ({base.COLUMNS})
values
{cihan_values}
on conflict (id) do nothing;

-- Paradigma / Bilim ve Düşünce ({n_sci} yeni soru)
insert into questions ({base.COLUMNS})
values
{sci_values}
on conflict (id) do nothing;

-- Doğrulama: beklenenin altındaysa işlem geri alınır.
do $$
declare
  v_cihan integer;
  v_sci integer;
  v_active boolean;
begin
  select is_active into v_active from categories where slug = 'cihan';
  if v_active is distinct from true then
    raise exception 'Cihan: kategori yok ya da pasif';
  end if;

  select count(*) into v_cihan
  from questions
  where category_id = (select id from categories where slug = 'cihan')
    and is_approved = true;
  if v_cihan < {n_cihan} then
    raise exception 'Cihan: beklenen en az {n_cihan} onayli soru, bulunan %', v_cihan;
  end if;

  select count(*) into v_sci
  from questions
  where id in ({sci_ids})
    and category_id = (select id from categories where slug = 'paradigma')
    and is_approved = true;
  if v_sci <> {n_sci} then
    raise exception 'Bilim: beklenen {n_sci} onayli Paradigma sorusu, bulunan %', v_sci;
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
