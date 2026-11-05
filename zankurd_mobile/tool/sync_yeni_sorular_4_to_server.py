#!/usr/bin/env python3
"""«Yeni sorular» bankasının (r16_<kategori>_<parti>_NN) sunucuda EKSİK sorularını SQL'e döker.

Sunucuya BAĞLANMAZ, SQL ÇALIŞTIRMAZ; yalnız şu dosyayı üretir/yeniler:
  supabase/2026-11-17_yeni_sorular_4.sql

Niçin (2026-11-17): Teknolojî, Edebiyat, Sînema, Muzîk, Paradigma, Siyaset, Cografya, Cîhan, Dîrok ve Çand ~700'e taşınıyor. `tool/data/yeni4_2026_11_17_server_only.json` (uygulamaya paketlenmez) bu on kategoriye
çapraz incelemeden geçmiş yeni sorular ekler.
Rekabetçi modlar sunucudan çeker; sorular server_only = true işaretlenir.

Seçim ve satır biçimi `sync_deepseek_verified_to_server.py` ve
`sync_sinema_to_server.py` ile ORTAK (içe aktarılır): aynı uuid5 şeması
(ad alanı 5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77 üzerinde
"zankurd-local:" + yerel id), aynı sütun kümesi, aynı oynanabilirlik kuralı,
kategori `categories.name` ile aranır, kategori OLUŞTURULMAZ,
`on conflict (id) do nothing`, doğrulama bloğu sayı tutmazsa işlemi geri alır.
Doğru/yanlış (`trueFalse`) sorular da çoktan seçmeli gibi taşınır.

Kullanım (proje kökü zankurd_mobile/ içinden):
  python3 tool/sync_yeni_sorular_4_to_server.py            # SQL'i yazar
  python3 tool/sync_yeni_sorular_4_to_server.py --check    # yalnız sayar/doğrular
"""
from __future__ import annotations

import argparse
import collections
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_deepseek_verified_to_server as dsv  # noqa: E402
import sync_sinema_to_server as base  # noqa: E402

ROOT = base.ROOT
OUT_SQL = ROOT / "supabase" / "2026-11-17_yeni_sorular_4.sql"
PREFIX = "r16_"

# `dsv.SERVER_NAME` Siyaset'i içermez (önceki göçler bu kategoriyi başka
# üreticilerle taşıdı; sunucuda `categories.name = 'Siyaset'` zaten var, bkz.
# 2026-10-01_local_parity_sync_siyaset.sql). Bu göç yine de kategori
# OLUŞTURMAZ: önkoşul bloğu yoksa işlemi geri alır.
SERVER_NAME = {**dsv.SERVER_NAME, "Siyaset": "Siyaset"}  # Teknolojî dsv'de var


SRC = ROOT / "tool" / "data" / "yeni4_2026_11_17_server_only.json"


def select() -> list[dict]:
    """Yerel banka YOK: paket 4 yalnız sunucuda yaşar (server_only = true)."""
    import json

    rows = []
    for q in json.loads(SRC.read_text(encoding="utf-8")):
        if not q["id"].startswith(PREFIX):
            raise SystemExit(f"beklenmeyen kimlik: {q['id']}")
        if not base.structurally_valid(q) or q.get("type", "multipleChoice") != "multipleChoice":
            raise SystemExit(f"geçersiz soru: {q['id']}")
        row = base.to_row(q)
        row["server_category"] = SERVER_NAME[q["category"]]
        rows.append(row)
    return rows


def row_sql(r: dict) -> str:
    return dsv.row_sql(r)[:-1] + ", true)"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="dosya yazma")
    args = ap.parse_args()

    rows = select()
    n = len(rows)
    per_cat = collections.Counter(r["server_category"] for r in rows)
    print(f"SQL'e yazılacak YENİ satır: {n} {dict(sorted(per_cat.items()))}")
    print(
        "correct_option dağılımı   :",
        dict(sorted(collections.Counter(r["correct"] for r in rows).items())),
    )
    if len({r["id"] for r in rows}) != n or n == 0:
        print("HATA: uuid çakışması ya da boş küme", file=sys.stderr)
        return 1
    if args.check:
        return 0

    cat_lines = "\n".join(f"--   - {k}: {c}" for k, c in sorted(per_cat.items()))
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
    header = f"""-- 2026-11-17: «yeni sorular» bankasından {n} yeni soru (canlı sunucu).
--
-- NİÇİN: Teknolojî, Edebiyat, Sînema, Muzîk, Paradigma, Siyaset, Cografya,
-- Cîhan, Dîrok ve Çand paket 3 sonrası ~560-640 onaylı soru; hedef ~700'e yaklaştırmak. `tool/data/yeni4_2026_11_17_server_only.json` ({n} soru; uygulamaya PAKETLENMEZ, server_only = true) ekler.
-- Taslak: ChatGPT (GPT-6 Extra High); jüri: Gemini 4 Argon (Yüksek, doğruluk +
-- Kurmancî yazım) ve ChatGPT yeni sohbet ya da Copilot; en az iki
-- bağımsız inceleyici ONAY demeden soru alınmadı (bkz. test başlığı).
-- Rekabetçi modlar bu sunucu-yalnız havuzdan çeker; cevap anahtarı istemcide olmaz.
--
-- KAÇ SORU: {n} yeni satır. Kategori dağılımı:
{cat_lines}
--
-- TEKRAR YOK: kimlikler uuid5(ad alanı, "zankurd-local:" + yerel id); bu
-- kimlikler daha önce hiçbir göçte yok. Yine de her satır
-- `on conflict (id) do nothing` ile eklenir; ikinci çalıştırma 0 satır ekler.
--
-- KATEGORİ: `categories.name` ile aranır (tekil). Başta gerekli kategorilerin
-- varlığı denetlenir; biri yoksa hiçbir şey eklenmeden işlem geri alınır. Bu
-- göç kategori OLUŞTURMAZ.
--
-- BİÇİM: metinler yalnız Kurmancî; explanation/explanation_ku/explanation_tr
-- yerel alanlardan; image_url NULL; hepsi is_approved = true,
-- review_status = 'approved'. Üretici: tool/sync_yeni_sorular_4_to_server.py.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   supabase/geri_al/2026-11-17_yeni_sorular_4_geri.sql
--
-- Uygulama: ana ajan, kuru çalıştırma (begin…rollback) sonrası canlıda.
"""
    sql = f"""{header}
begin;

-- server_only: istemci paketinde yerel karşılığı olmayan, yalnız sunucudan çekilen sorular
-- (rekabetçi modlar). Sütun W10 kolunda da eklenir; idempotent.
alter table public.questions add column if not exists server_only boolean not null default false;

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

insert into questions ({base.COLUMNS}, server_only)
values
{values}
on conflict (id) do nothing;

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
    rb = f"""-- Geri alma: 2026-11-17_yeni_sorular_4.sql göçünün eklediği {n} satırı siler
-- (yalnız bu kimlikler; başka soruya dokunmaz).
begin;

delete from questions
 where id in ({all_ids});

commit;
"""
    (ROOT / "supabase" / "geri_al" / "2026-11-17_yeni_sorular_4_geri.sql").write_text(rb, encoding="utf-8")
    print(f"Yazıldı: {OUT_SQL} ({len(sql)} bayt)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
