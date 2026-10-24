#!/usr/bin/env python3
"""«Kolay» bankasının (kolay_<kategori>_NN) sunucuda EKSİK sorularını SQL'e döker.

Sunucuya BAĞLANMAZ, SQL ÇALIŞTIRMAZ; yalnız şu dosyayı üretir/yeniler:
  supabase/2026-10-19_kolay_ekle.sql

Niçin (2026-10-19): 455 fazla zor "kolay" soru zorluk 3'e çekilince Sînema,
Edebiyat, Siyaset ve Dîrok kolay havuzları inceldi.
`assets/data/kolay_2026_10_19_questions.json` zorluk-1 sorular ekler.
Oda ve düello soruları sunucudan çeker.

Seçim ve satır biçimi `sync_deepseek_verified_to_server.py` ve
`sync_sinema_to_server.py` ile ORTAK (içe aktarılır): aynı uuid5 şeması
(ad alanı 5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77 üzerinde
"zankurd-local:" + yerel id), aynı sütun kümesi, aynı oynanabilirlik kuralı,
kategori `categories.name` ile aranır, kategori OLUŞTURULMAZ,
`on conflict (id) do nothing`, doğrulama bloğu sayı tutmazsa işlemi geri alır.
Doğru/yanlış (`trueFalse`) sorular da çoktan seçmeli gibi taşınır.

Kullanım (proje kökü zankurd_mobile/ içinden):
  python3 tool/sync_kolay_to_server.py            # SQL'i yazar
  python3 tool/sync_kolay_to_server.py --check    # yalnız sayar/doğrular
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
OUT_SQL = ROOT / "supabase" / "2026-10-19_kolay_ekle.sql"
PREFIX = "kolay_"

# `dsv.SERVER_NAME` Siyaset'i içermez (önceki göçler bu kategoriyi başka
# üreticilerle taşıdı; sunucuda `categories.name = 'Siyaset'` zaten var, bkz.
# 2026-10-01_local_parity_sync_siyaset.sql). Bu göç yine de kategori
# OLUŞTURMAZ: önkoşul bloğu yoksa işlemi geri alır.
SERVER_NAME = {**dsv.SERVER_NAME, "Siyaset": "Siyaset"}


def select() -> list[dict]:
    playable, _ = base.load_playable_all()
    rows = []
    for q in playable:
        if not q["id"].startswith(PREFIX):
            continue
        if q.get("type", "multipleChoice") not in ("multipleChoice", "trueFalse"):
            raise SystemExit(f"beklenmeyen tür: {q['id']}")
        row = base.to_row(q)
        row["server_category"] = SERVER_NAME[q["category"]]
        rows.append(row)
    return rows


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
    values = ",\n".join(dsv.row_sql(r) for r in rows)
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
    header = f"""-- 2026-10-19: «kolay» bankasından {n} yeni zorluk-1 soru (canlı sunucu).
--
-- NİÇİN: 455 fazla zor "kolay" soru zorluk 3'e çekilince Sînema, Edebiyat,
-- Siyaset ve Dîrok kolay havuzları inceldi. `assets/data/kolay_2026_10_19_questions.json`
-- {n} soru ekledi (DeepSeek V4.1 taslağı; iki bağımsız jüri, Gemini 3.1 Pro ve
-- Grok/ChatGPT, ikisi de KABUL dedi; kalite kapısı yakın tekrarları elendi).
-- Oda ve düello soruları sunucudan çeker; bu sorular sunucuda yoktu.
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
-- review_status = 'approved'. Üretici: tool/sync_kolay_to_server.py.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from questions where id in (<bu dosyadaki id'ler>);
--
-- Uygulama: supabase db query --linked -f supabase/2026-10-19_kolay_ekle.sql
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
