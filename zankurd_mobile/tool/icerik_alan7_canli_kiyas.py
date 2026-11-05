#!/usr/bin/env python3
"""`2026-11-07_icerik_alan7.sql` hedefleri için CANLI ↔ yerel ↔ hedef karşılaştırması.

Niçin (2.1.2 W6, alan 6 "doğrulanmalı"): göç canlıda 247 alan uyguladı, 74'ü zaten
hedefteydi, 42 alanı CANLIDAKİ FARKLI DEĞER yüzünden atladı, 12 hedef satırı bulunamadı
(applied.md). Atlanan (soru, alan) çiftlerinde canlıda, yerel pakette ve hedefte ne yazdığı
bir yerde görünmüyor: körlemesine güncellemek yanlış olurdu. Bu araç YALNIZ OKUR.

Bu araç sunucuya BAĞLANMAZ ve hiçbir şey ÇALIŞTIRMAZ. İki adım:

  1. SQL üret (yalnız SELECT; `begin read only` ... `rollback`; canlıya dokunmaz):
       python3 tool/icerik_alan7_canli_kiyas.py sql > /tmp/alan7_kiyas.sql
     Ana ajan/sahip bunu canlıda çalıştırır ve çıktıyı kaydeder, örn.:
       supabase db query --linked -f /tmp/alan7_kiyas.sql > /tmp/alan7_canli.json
     (Her hedef için canlı değer + sınıf: uygula / zaten / farkli / atla / yok; sınıflama
      göçteki mantığın SELECT karşılığıdır, `atla` = sorunun başka hedefi `farkli`.)

  2. Raporla (yerel paketle birleştirir, TSV yazar):
       python3 tool/icerik_alan7_canli_kiyas.py rapor /tmp/alan7_canli.json > alan7_kiyas.tsv
     Çıktı yalnız ATLANAN/FARKLI/YOK satırlarını listeler: soru kimliği, yerel kimlik,
     alan, ESKİ (göçün beklediği), YENİ (hedef), CANLI, YEREL (paketteki değer), karar
     ipucu (canlı=yerel mi? canlı=yeni mi?). Karar insana aittir; araç hiçbir şeyi
     değiştirmez.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MIGRATION = ROOT / "supabase" / "2026-11-07_icerik_alan7.sql"
DATA = ROOT / "assets" / "data"

_STR = r"'(?:[^']|'')*'"
_ROW = re.compile(r"\(\s*(" + _STR + r")\s*,\s*(" + _STR + r")\s*,\s*(" + _STR + r")\s*,\s*(" + _STR + r")\s*,\s*(" + _STR + r")\s*,\s*(" + _STR + r")\s*\)")


def _unquote(lit: str) -> str:
    return lit[1:-1].replace("''", "'")


def load_targets(sql_text: str | None = None) -> list[dict]:
    """Göçün `insert into _hedef ... values` bloğundaki hedefleri okur."""
    text = sql_text if sql_text is not None else MIGRATION.read_text(encoding="utf-8")
    start = text.index("insert into _hedef")
    end = text.index(";\n", start)
    block = text[start:end]
    rows = []
    for m in _ROW.finditer(block):
        id_, yerel, sutun, eski, yeni, kaynak = (_unquote(g) for g in m.groups())
        rows.append(
            {"id": id_, "yerel": yerel, "sutun": sutun, "eski": eski, "yeni": yeni, "kaynak": kaynak}
        )
    return rows


def _lit(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def build_sql(targets: list[dict]) -> str:
    values = ",\n".join(
        "  ({},{},{},{},{},{})".format(
            _lit(t["id"]), _lit(t["yerel"]), _lit(t["sutun"]), _lit(t["eski"]), _lit(t["yeni"]), _lit(t["kaynak"])
        )
        for t in targets
    )
    # Sınıflama göçteki mantığın SELECT karşılığı: sik hedefi eski metni dört şıktan TAM
    # birinde bulursa 'uygula', yeni metin şıklardan birindeyse 'zaten', değilse 'farkli';
    # sik dışı alanlarda değer eskiyle/yeniyle karşılaştırılır.
    return f"""-- icerik_alan7 CANLI karşılaştırma (YALNIZ OKUR; tool/icerik_alan7_canli_kiyas.py ürettiği).
-- Canlıya yazmaz: salt okunur işlem, sonda rollback.
begin read only;

with h(id, yerel, sutun, eski, yeni, kaynak) as (values
{values}
),
v as (
  select h.*, q.id as qid, q.correct_option as canli_dogru, q.prompt as c_prompt,
         q.option_a, q.option_b, q.option_c, q.option_d,
         q.explanation as c_explanation, q.explanation_ku as c_explanation_ku,
         q.explanation_tr as c_explanation_tr,
         array[q.option_a, q.option_b, q.option_c, q.option_d] as siklar
  from h left join public.questions q on q.id = h.id::uuid
),
s as (
  select v.*,
    case v.sutun when 'prompt' then v.c_prompt when 'explanation' then v.c_explanation
      when 'explanation_ku' then v.c_explanation_ku when 'explanation_tr' then v.c_explanation_tr end as canli_alan,
    (select count(*) from unnest(v.siklar) x where x = v.eski) as eski_sik_n,
    (select count(*) from unnest(v.siklar) x where x = v.yeni) as yeni_sik_n
  from v
),
d as (
  select s.*,
    case
      when s.qid is null then 'yok'
      when s.sutun = 'sik' and s.eski_sik_n = 1 then 'uygula'
      when s.sutun = 'sik' and s.yeni_sik_n >= 1 then 'zaten'
      when s.sutun = 'sik' then 'farkli'
      when s.canli_alan is not distinct from s.eski then 'uygula'
      when s.canli_alan is not distinct from s.yeni then 'zaten'
      else 'farkli'
    end as durum0
  from s
),
e as (
  select d.*,
    case when d.durum0 = 'uygula'
          and bool_or(d.durum0 = 'farkli') over (partition by d.id) then 'atla' else d.durum0 end as durum
  from d
)
select jsonb_pretty(coalesce(jsonb_agg(jsonb_build_object(
  'id', e.id, 'yerel', e.yerel, 'sutun', e.sutun, 'kaynak', e.kaynak,
  'eski', e.eski, 'yeni', e.yeni, 'durum', e.durum,
  'canli', case when e.sutun = 'sik' then to_jsonb(e.siklar) else to_jsonb(e.canli_alan) end,
  'canli_prompt', e.c_prompt, 'canli_dogru', e.canli_dogru
) order by e.yerel, e.sutun, e.eski), '[]'::jsonb)) as alan7_kiyas
from e;

rollback;
"""


def find_rows(obj) -> list[dict]:
    """Canlı çıktıdan hedef satırlarını bulur (CLI çıktı sarmalayıcısından bağımsız)."""
    if isinstance(obj, str):
        try:
            return find_rows(json.loads(obj))
        except ValueError:
            return []
    if isinstance(obj, list):
        if obj and all(isinstance(x, dict) and "yerel" in x and "durum" in x for x in obj):
            return obj
        for x in obj:
            found = find_rows(x)
            if found:
                return found
        return []
    if isinstance(obj, dict):
        for x in obj.values():
            found = find_rows(x)
            if found:
                return found
    return []


def load_local_bank() -> dict[str, dict]:
    bank: dict[str, dict] = {}
    for path in sorted(DATA.glob("*.json")):
        try:
            rows = json.loads(path.read_text(encoding="utf-8"))
        except ValueError:
            continue
        if not isinstance(rows, list):
            continue
        for q in rows:
            if isinstance(q, dict) and isinstance(q.get("id"), str):
                bank[q["id"]] = q  # sonraki banka kazanır (yükleyiciyle aynı sıra değil; yalnız ipucu)
    return bank


def local_value(q: dict | None, row: dict):
    if q is None:
        return None
    sutun = row["sutun"]
    if sutun == "prompt":
        return q.get("prompt")
    if sutun == "explanation":
        return q.get("explanation")
    if sutun == "explanation_ku":
        return q.get("explanationKu")
    if sutun == "explanation_tr":
        return q.get("explanationTr")
    if sutun == "sik":
        return q.get("answers")
    return None


def _cell(v) -> str:
    if v is None:
        return ""
    if not isinstance(v, str):
        v = json.dumps(v, ensure_ascii=False)
    return v.replace("\t", " ").replace("\n", "\\n")


def report(rows: list[dict], bank: dict[str, dict]) -> str:
    out = ["soru_id\tyerel_id\talan\tdurum\teski\tyeni\tcanli\tyerel\tcanli_esittir\tipucu"]
    counts: dict[str, int] = {}
    for row in rows:
        counts[row["durum"]] = counts.get(row["durum"], 0) + 1
        if row["durum"] not in ("atla", "farkli", "yok"):
            continue
        q = bank.get(row["yerel"])
        yerel = local_value(q, row)
        canli = row.get("canli")
        if row["sutun"] == "sik":
            canli_cmp = row["eski"] in (canli or [])
            esit = []
            if canli and row["yeni"] in canli:
                esit.append("canli sikki=yeni")
            if isinstance(yerel, list) and canli and set(yerel) == set(canli):
                esit.append("canli sikleri=yerel")
            ipucu = "; ".join(esit) or "canli sik kumesi hedeften ve yerelden farkli"
            canli_esittir = "eski sik canlida " + ("VAR" if canli_cmp else "YOK")
        else:
            esit = []
            if canli == row["yeni"]:
                esit.append("canli=yeni")
            if yerel is not None and canli == yerel:
                esit.append("canli=yerel")
            if canli == row["eski"]:
                esit.append("canli=eski")
            ipucu = "; ".join(esit) or "canli eski/yeni/yerelden FARKLI (elle bak)"
            canli_esittir = ""
        if row["kaynak"] == "server":
            ipucu += " [yalniz sunucu sorusu: yerel paket yok]"
        out.append(
            "\t".join(
                _cell(x)
                for x in (
                    row["id"], row["yerel"], row["sutun"], row["durum"], row["eski"], row["yeni"],
                    canli, yerel, canli_esittir, ipucu,
                )
            )
        )
    sys.stderr.write("durum sayilari: " + json.dumps(counts, ensure_ascii=False, sort_keys=True) + "\n")
    return "\n".join(out) + "\n"


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "sql":
        sys.stdout.write(build_sql(load_targets()))
        return 0
    if len(argv) >= 3 and argv[1] == "rapor":
        data = json.loads(Path(argv[2]).read_text(encoding="utf-8"))
        rows = find_rows(data)
        if not rows:
            sys.stderr.write("canli ciktida hedef satiri bulunamadi\n")
            return 2
        sys.stdout.write(report(rows, load_local_bank()))
        return 0
    sys.stderr.write(__doc__ or "")
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
