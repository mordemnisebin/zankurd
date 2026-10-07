#!/usr/bin/env python3
"""Çok modelli doğrulanmış DeepSeek sorularının sunucuda EKSİK olanlarını SQL'e döker.

Sunucuya BAĞLANMAZ, SQL ÇALIŞTIRMAZ; yalnız şu dosyayı üretir/yeniler:
  supabase/2026-09-30_deepseek_verified_sync.sql

Niçin (2026-09-30): `assets/data/deepseek_verified_2026_09_30_questions.json`
(822 soru) uygulamada açıldı. Oda ve düello soruları sunucudan çeker;
`2026-09-30_cihan_and_science.sql` (canlıda uygulandı) bunlardan yalnız
Cîhan kategorisindekileri (300) ve 40 bilim sorusunu ekledi. Teknolojî ve
Kürt kategorilerindeki (Ziman, Çand, Dîrok, Edebiyat, Cografya, Muzîk,
Sînema) doğrulanmış sorular sunucuda yoktu: oyuncu tek başına oynarken
görüp odada/düelloda hiç görmüyordu.

Seçim ve satır biçimi `sync_sinema_to_server.py` ile ORTAK (içe aktarılır):
aynı uuid5 şeması, aynı sütun kümesi, aynı oynanabilirlik kuralı (emekli id
yok, reviewStatus approved/yok, çoktan seçmelide tam 4 şık). Sunucu şemasına
yalnız `multipleChoice` ve `trueFalse` sığar; diğer türler ve görselle
anlamlı sorular atlanır ve sayılır.

Tekrar ekleme yok: sunucuda zaten bulunanlar (aynı uuid5) SQL'e HİÇ
yazılmaz. "Sunucuda zaten var" kaynağı, canlıda uygulanmış iki göç dosyasıdır
(`2026-09-30_cihan_and_science.sql`, `2026-09-30_sinema_category_and_questions.sql`);
dosyadaki uuid'ler okunur ve çıkarılır. Üstüne `on conflict (id) do nothing`
ikinci güvencedir.

Kategori araması AD ile yapılır (`categories.name` tekildir; önceki göçlerle
aynı yol). Teknolojî için slug göçlerde hiç geçmediği için ad tek güvenli
anahtardır. Bir kategori sunucuda yoksa işlem, hiçbir soru eklenmeden
hata verip geri alınır (NULL category_id sessiz yazılmaz).

Kullanım (proje kökü zankurd_mobile/ içinden):
  python3 tool/sync_deepseek_verified_to_server.py            # SQL'i yazar
  python3 tool/sync_deepseek_verified_to_server.py --check    # yalnız sayar/doğrular
"""
from __future__ import annotations

import argparse
import collections
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_sinema_to_server as base  # noqa: E402

ROOT = base.ROOT
VERIFIED = ROOT / "assets" / "data" / "deepseek_verified_2026_09_30_questions.json"
OUT_SQL = ROOT / "supabase" / "2026-09-30_deepseek_verified_sync.sql"

# Sunucuda zaten bulunan sorular: canlıda uygulanmış göçlerin uuid'leri.
ALREADY_APPLIED = [
    ROOT / "supabase" / "2026-09-30_cihan_and_science.sql",
    ROOT / "supabase" / "2026-09-30_sinema_category_and_questions.sql",
]
UUID_RE = re.compile(
    r"^\('([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'"
)

# Yerel kategori -> sunucu `categories.name` (ikisi de kanonik ad; önceki
# göçlerde `where name = '…'` ile aynı yazımlar kullanıldı).
SERVER_NAME = {
    "Cîhan": "Cîhan",
    "Sînema": "Sînema",
    "Teknolojî": "Teknolojî",
    "Ziman": "Ziman",
    "Çand": "Çand",
    "Dîrok": "Dîrok",
    "Edebiyat": "Edebiyat",
    "Cografya": "Cografya",
    "Muzîk": "Muzîk",
    # Bilim ve Düşünce: sunucu adı hâlâ `Paradigma` (bkz. cihan_and_science.sql).
    "Paradigma": "Paradigma",
}
SCIENCE_PREFIX = "bilim_"


def already_on_server() -> set[str]:
    return set(applied_rows())


def applied_rows() -> dict[str, str]:
    """uuid -> uygulanmış göçteki değer satırının metni."""
    rows: dict[str, str] = {}
    for path in ALREADY_APPLIED:
        for line in path.read_text(encoding="utf-8").split("\n"):
            m = UUID_RE.match(line)
            if m:
                rows[m.group(1)] = line
    return rows


def select():
    verified_ids = {q["id"] for q in json.loads(VERIFIED.read_text(encoding="utf-8"))}
    playable, info = base.load_playable_all()
    # Doğrulanmış DeepSeek kopyası + kaynaklı bilim soruları (Paradigma).
    # İlk 40 bilim sorusu cihan_and_science.sql ile sunucuda; 41–70 yenidir.
    candidates = [
        q
        for q in playable
        if q["id"] in verified_ids
        or (q["category"] == "Paradigma" and q["id"].startswith(SCIENCE_PREFIX))
    ]
    not_playable = len(verified_ids) - sum(
        1 for q in candidates if q["id"] in verified_ids
    )
    applied = applied_rows()
    on_server = set(applied)

    picked: list[dict] = []
    skipped = collections.Counter()
    skipped_ids: dict[str, list[str]] = collections.defaultdict(list)
    duplicates = collections.Counter()
    backfill: list[dict] = []
    for q in candidates:
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
        if q["category"] not in SERVER_NAME:
            skipped[f"kategori:{q['category']}"] += 1
            skipped_ids[f"kategori:{q['category']}"].append(q["id"])
            continue
        row = base.to_row(q)
        if row["id"] in on_server:
            duplicates[q["category"]] += 1
            # Sunucudaki satır kaynaksız eklenmiş olabilir (kaynak sonradan
            # bulundu); boşsa doldurulur, doluysa dokunulmaz.
            if row["source_reference"] and row["source_reference"] not in applied[row["id"]]:
                backfill.append(row)
            continue
        row["server_category"] = SERVER_NAME[q["category"]]
        picked.append(row)
    return {
        "verified": len(verified_ids),
        "not_playable": not_playable,
        "candidates": len(candidates),
        "picked": picked,
        "skipped": skipped,
        "skipped_ids": skipped_ids,
        "already": duplicates,
        "backfill": backfill,
        "info": info,
    }


def row_sql(r: dict) -> str:
    # `base.row_sql` slug ile arar; burada ad ile aranır (bkz. modül başlığı).
    cat = f"(select id from categories where name = {base.sql_str(r['server_category'])})"
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

    s = select()
    rows: list[dict] = s["picked"]
    per_cat = collections.Counter(r["server_category"] for r in rows)
    n = len(rows)

    print(f"Doğrulanmış dosyadaki kayıt  : {s['verified']}")
    print(f"Oynanamaz (emekli vb.)       : {s['not_playable']}")
    print(f"Oynanabilir aday (doğrulanmış + bilim): {s['candidates']}")
    print(f"Sunucuda zaten var (çıkarıldı): {sum(s['already'].values())} {dict(s['already'])}")
    print(f"Kaynağı sonradan bulunan sunucu satırı: {len(s['backfill'])}")
    print(f"Atlanan                      : {dict(s['skipped'])} {dict(s['skipped_ids'])}")
    print(f"SQL'e yazılacak YENİ satır   : {n} {dict(sorted(per_cat.items()))}")
    print(
        "correct_option dağılımı      :",
        dict(sorted(collections.Counter(r["correct"] for r in rows).items())),
    )
    print("türler                       :", dict(collections.Counter(r["qtype"] for r in rows)))
    if len({r["id"] for r in rows}) != n:
        print("HATA: uuid çakışması", file=sys.stderr)
        return 1
    if n == 0:
        print("HATA: eklenecek soru yok", file=sys.stderr)
        return 1
    if args.check:
        return 0

    skip_lines = (
        "\n".join(f"--   - {k}: {c} soru atlandı" for k, c in sorted(s["skipped"].items()))
        or "--   - (atlanan yok: seçim kümesindeki tüm sorular şemaya sığdı)"
    )
    cat_lines = "\n".join(
        f"--   - {name}: {c}" for name, c in sorted(per_cat.items())
    )
    already_total = sum(s["already"].values())
    header = f"""-- 2026-09-30: çok modelli doğrulanmış DeepSeek sorularından sunucuda EKSİK {n} soru (canlı sunucu).
--
-- NİÇİN: `assets/data/deepseek_verified_2026_09_30_questions.json` ({s['verified']} soru)
-- uygulamada açıldı; ayrıca Paradigma'ya (Bilim ve Düşünce) 30 yeni kaynaklı
-- bilim sorusu (bilim_0041…0070) geldi — ilk 40'ı cihan_and_science.sql ile
-- sunucuda. Oda ve düello soruları sunucudan çeker;
-- `2026-09-30_cihan_and_science.sql` bunlardan yalnız Cîhan'dakileri
-- ({s['already'].get('Cîhan', 0)}) ve ilk {s['already'].get('Paradigma', 0)} bilim sorusunu ekledi. Teknolojî ve Kürt kategorilerindeki doğrulanmış
-- sorular sunucuda yoktu: tek kişilik modda görünen soru odada/düelloda
-- hiç gelmiyordu.
--
-- KAÇ SORU: {n} yeni satır. Kategori dağılımı:
{cat_lines}
--
-- TEKRAR YOK: sunucuda zaten bulunan {already_total} soru (aynı uuid5; {dict(s['already'])})
-- bu dosyaya HİÇ yazılmadı. Yine de her satır `on conflict (id) do nothing`
-- ile eklenir; ikinci çalıştırma 0 satır ekler.
--
-- KAYNAK DOLDURMA: sunucuda zaten olan {len(s['backfill'])} satırın kaynağı sonradan
-- bulundu (ChatGPT web araması); `update … where source_reference is null`
-- yalnız boş alanı doldurur, dolu kaynağa dokunmaz.
--
-- SEÇİM KURALLARI (tool/sync_deepseek_verified_to_server.py; seçim ve satır
-- biçimi tool/sync_sinema_to_server.py ile ortak, uygulamanın
-- QuestionContentPolicy.isPlayable kuralının Python karşılığı):
--   - retired_question_ids.dart emeklileri ve gizli kategoriler hariç;
--   - reviewStatus yok ya da approved; çoktan seçmelide tam 4 şık;
--   - yalnız multiple_choice ve true_false.
-- ATLANANLAR (sunucu şemasına sığmayan ya da görselsiz anlamını yitiren):
{skip_lines}
--
-- KATEGORİ: `categories.name` ile aranır (tekil; önceki göçlerle aynı). Başta
-- gerekli tüm kategorilerin varlığı denetlenir; biri yoksa hiçbir şey
-- eklenmeden işlem geri alınır. Bu göç kategori OLUŞTURMAZ.
--
-- BİÇİM: metinler yalnız Kurmancî; explanation/explanation_ku/explanation_tr
-- yerel alanlardan; image_url NULL; hepsi is_approved = true,
-- review_status = 'approved'.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from questions where id in (<bu dosyadaki id'ler>);
--
-- Uygulama: supabase db query --linked -f supabase/2026-09-30_deepseek_verified_sync.sql
"""
    backfill_sql = "".join(
        f"""
update questions
set source_url = {base.sql_str(r["source_url"])},
    source_title = {base.sql_str(r["source_title"])},
    source_reference = {base.sql_str(r["source_reference"])}
where id = {base.sql_str(r["id"])}
  and source_reference is null;
"""
        for r in s["backfill"]
    )
    if backfill_sql:
        backfill_sql = (
            "\n-- Sunucuda zaten olup kaynaksız eklenmiş satır(lar): kaynak "
            "sonradan bulundu; yalnız boşsa doldurulur."
            + backfill_sql
        )
    cat_names = ", ".join(base.sql_str(c) for c in sorted(per_cat))
    values = ",\n".join(row_sql(r) for r in rows)
    ids_by_cat: dict[str, list[str]] = collections.defaultdict(list)
    for r in rows:
        ids_by_cat[r["server_category"]].append(r["id"])
    all_ids = ", ".join(base.sql_str(r["id"]) for r in rows)
    per_cat_checks = "\n".join(
        f"""
  select count(*) into v_count
  from questions
  where id in ({", ".join(base.sql_str(i) for i in ids_by_cat[name])})
    and category_id = (select id from categories where name = {base.sql_str(name)})
    and is_approved = true;
  if v_count <> {c} then
    raise exception '{name}: beklenen {c} onayli soru, bulunan %', v_count;
  end if;"""
        for name, c in sorted(per_cat.items())
    )
    sql = f"""{header}
begin;

-- Önkoşul: gerekli kategorilerin hepsi sunucuda var (bu göç oluşturmaz).
do $$
declare
  v_missing text;
begin
  select string_agg(n, ', ') into v_missing
  from unnest(array[{cat_names}]) as t(n)
  where not exists (select 1 from categories where name = n);
  if v_missing is not null then
    raise exception 'Eksik kategori(ler): %', v_missing;
  end if;
end
$$;

insert into questions ({base.COLUMNS})
values
{values}
on conflict (id) do nothing;
{backfill_sql}
-- Doğrulama: her kategori için bu dosyadaki kimliklerin hepsi o kategoride
-- onaylı olarak durmalı; aksi halde işlem geri alınır.
do $$
declare
  v_count integer;
begin
{per_cat_checks}

  select count(*) into v_count
  from questions
  where id in ({all_ids})
    and is_approved = true;
  if v_count <> {n} then
    raise exception 'Toplam: beklenen {n} onayli soru, bulunan %', v_count;
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
