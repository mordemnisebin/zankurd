#!/usr/bin/env python3
"""Derse etiketli alıştırma sorularını (`ders_2026_10_01_*`) sunucu göçüne döker.

Sunucuya BAĞLANMAZ, SQL ÇALIŞTIRMAZ; yalnız şu dosyayı üretir/yeniler:
  supabase/2026-10-01_ders_sync.sql

Niçin (2026-10-01): `assets/data/ders_2026_10_01_questions.json` (74 soru)
uygulamada açıldı; sorular genel Ziman/Çand havuzuna da girdiği için
oda ve düello sunucudan çektiğinde bunları göremezdi. Seçim ve satır
biçimi `sync_sinema_to_server.py` / `sync_deepseek_verified_to_server.py`
ile ORTAK: aynı uuid5 şeması (ad alanı 5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77,
girdi `'zankurd-local:' + id`), aynı sütun kümesi, aynı oynanabilirlik
kuralı. Kategori `categories.name` ile aranır; yoksa işlem geri alınır.

Tekrar çalıştırılabilir: `on conflict (id) do nothing`.

Kullanım (zankurd_mobile/ içinden):
  python3 tool/sync_ders_to_server.py            # SQL'i yazar
  python3 tool/sync_ders_to_server.py --check    # yalnız sayar/doğrular
"""
from __future__ import annotations

import argparse
import collections
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_deepseek_verified_to_server as dsync  # noqa: E402
import sync_sinema_to_server as base  # noqa: E402

ROOT = base.ROOT
OUT_SQL = ROOT / "supabase" / "2026-10-01_ders_sync.sql"
PREFIX = "ders_2026_10_01_"
SERVER_NAME = {"Ziman": "Ziman", "Çand": "Çand"}


def select() -> tuple[list[dict], int]:
    playable, _ = base.load_playable_all()
    mine = [q for q in playable if q["id"].startswith(PREFIX)]
    picked = []
    for q in mine:
        if q.get("type", "multipleChoice") != "multipleChoice":
            raise SystemExit(f"{q['id']}: beklenmeyen tür")
        row = base.to_row(q)
        row["server_category"] = SERVER_NAME[q["category"]]
        picked.append(row)
    return picked, len(mine)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="dosya yazma")
    args = ap.parse_args()

    rows, n_playable = select()
    n = len(rows)
    per_cat = collections.Counter(r["server_category"] for r in rows)
    print(f"Oynanabilir ders sorusu : {n_playable}")
    print(f"SQL'e yazılacak satır   : {n} {dict(sorted(per_cat.items()))}")
    print(
        "correct_option dağılımı :",
        dict(sorted(collections.Counter(r["correct"] for r in rows).items())),
    )
    if len({r["id"] for r in rows}) != n or n == 0:
        print("HATA: uuid çakışması ya da boş küme", file=sys.stderr)
        return 1
    if args.check:
        return 0

    cat_lines = "\n".join(f"--   - {k}: {c}" for k, c in sorted(per_cat.items()))
    cat_names = ", ".join(base.sql_str(c) for c in sorted(per_cat))
    values = ",\n".join(dsync.row_sql(r) for r in rows)
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
    header = f"""-- 2026-10-01: derse etiketli {n} alıştırma sorusu (canlı sunucu).
--
-- NİÇİN: `assets/data/ders_2026_10_01_questions.json` ({n} soru) uygulamada
-- açıldı: 14 dersin uçtaki alıştırması etiketli sorudan yoksundu. Bu
-- sorular genel Ziman/Çand havuzunda da oynanır; oda ve düello soruları
-- sunucudan çektiği için sunucuda olmayan soru tek kişilik modda görünüp
-- çok oyunculuda hiç gelmezdi.
--
-- KAÇ SORU: {n} yeni satır. Kategori dağılımı:
{cat_lines}
--
-- BİÇİM: seçim ve satır biçimi tool/sync_sinema_to_server.py ile ortak
-- (uuid5, ad alanı 5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77, girdi
-- 'zankurd-local:' + yerel id). Metinler yalnız Kurmancî; explanation_ku/
-- explanation_tr yerel alanlardan; image_url NULL; hepsi is_approved = true,
-- review_status = 'approved'. Bu göç kategori OLUŞTURMAZ.
--
-- TEKRAR ÇALIŞTIRILABİLİR: `on conflict (id) do nothing`; ikinci çalıştırma
-- 0 satır ekler. Kategori yoksa ya da sayı tutmazsa işlem geri alınır.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from questions where id in (<bu dosyadaki id'ler>);
--
-- Üretici: tool/sync_ders_to_server.py
-- Uygulama (ana ajan/kullanıcı; bu dosya ÇALIŞTIRILMADI):
--   supabase db query --linked -f supabase/2026-10-01_ders_sync.sql
"""
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

-- Doğrulama: bu dosyadaki kimliklerin hepsi kendi kategorisinde onaylı
-- olarak durmalı; aksi halde işlem geri alınır.
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
