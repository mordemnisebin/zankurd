#!/usr/bin/env python3
"""Yerel (denetlenmiş) soru bankası ile sunucu `questions` tablosunu eşitler.

Sunucuya YAZMAZ. Yalnız (1) salt okunur bir SELECT ile sunucu sorularını
okur, (2) yerel bankayı uygulamanın kendi süzgeciyle döker, (3) farkı SQL
göç dosyaları olarak yazar. Göçleri ana ajan inceler ve uygular.

Niçin (2026-10-01): oda ve düello soruları sunucudaki `questions`
tablosundan oynanır; kaynak doğru ise denetlenmiş yerel bankadır
(`assets/data/*.json` ∖ emekliler ∖ `QuestionContentPolicy.isPlayable`
dışı olanlar). Yerelde oynanabilir ~2500 sorunun yalnız ~1100'ü sunucuda
bulundu (Siyaset 0/64, Edebiyat 6/152, Cografya 18/204, Ziman 120/359…),
yani oyuncu tek başına gördüğü soruyu odada/düelloda görmüyordu. Tersi de
doğru: yerelde EMEKLİ edilmiş bazı sorular sunucuda hâlâ onaylı duruyordu.

## Üç adım

1. Yerel döküm: `flutter test tool/parity/dump_local_bank_test.dart`.
   Süzgeç Python'a kopyalanmaz; `QuestionBankLoader` + `QuestionContentPolicy`
   uygulamayla aynı kodu çalıştırır (`--local-json` ile hazır döküm verilir).
2. Sunucu dökümü: `supabase db query --linked` ile tek bir SELECT
   (`--server-json` ile hazır döküm verilir). INSERT/UPDATE/DDL ÇALIŞTIRMAZ;
   `run_select` SELECT dışını reddeder.
3. Sınıflandırma ve SQL üretimi.

## Eşleştirme (yerel soru -> sunucu satırı)

* Kimlik: `uuid5(NAMESPACE, 'zankurd-local:' + yerelId)` — son göçlerin şeması.
* Metin: normalleştirilmiş soru metni (NFKC + büyük/küçük harf + noktalama ve
  boşluk yok sayılır; DİYAKRİTİK korunur: ş/s, î/i farklı kelime olabilir)
  AYNI KATEGORİDE eşitse aynı soru sayılır. Doğru cevap metni de eşitse
  «özdeş» (cevap + şık kümesi), değilse «varyant» (aynı soru, başka
  yazım/şık: eski tohum, Türkçe şıklı kopya vb.).
* Yanlış eşleşme riski: soru metni kısa/genel olabilir («"mal" kî ye?»).
  Bu yüzden metin eşleşmesi KATEGORİ ister; emekli eşleşmesi ise metin +
  doğru cevap ister (yalnız metin yetmez). Eşleşme belirsizliği çıktıdaki
  `varyant` sayısında görünür; varyant satırlara dokunulmaz.

## Sınıflar (oynanabilir yerel soru başına)

  (a) sunucuda ONAYLI  — uuid5 ile (`a_uuid`) ya da metinle
      (`a_ozdes`, `a_varyant`);
  (b) sunucuda var ama ONAYSIZ — `b_uuid` (kimlik eşi; yeniden onaylanır ve
      metni yerel sürüme çekilir), `b_ozdes` (aynı içerik onaysız: editoryal
      bir kararın kendisi — DOKUNULMAZ, `--include-unapproved-identical` ile
      eklenir), `b_varyant` (sunucudaki onaysız satır başka yazım; yerel
      sürüm yeni uuid5 satırı olarak eklenir, eski satır onaysız KALIR);
  (c) sunucuda YOK — uuid5 satırı olarak eklenir;
  ayrıca `capraz` (aynı soru+cevap başka kategoride onaylı; eklenmez),
  `sema` (sunucu şemasına sığmayan: boşluk doldurma/cümle dizme, 4 şıksız),
  `gorsel_atlandi` (eklenecekti ama görselli: `--include-visual` yoksa
  eklenmez; mağazadaki eski sürümlerde yeni görsel dosyaları yok, oda/düelloda
  kırık görsel çıkar; 2.0.0 yayına çıkınca ayrı göçle eklenecek).

Sunucuda onaylı satırlardan, EMEKLİ/oynanamaz bir yerel soruyla soru metni +
doğru cevabı eşleşenler `bilinen kötü` sayılır ve ikinci dosyayla onaydan
çıkarılır (oynanabilir bir yerel soruyla eşleşenler çıkarılmaz).

Uuid5 ile eşleşen onaylı satırın metni yerel sürümden anlamlı biçimde
ayrışmışsa (soru metni, şık kümesi ya da doğru cevap; yalnız şık SIRASI
farkı sayılmaz) `drift` olarak yerel sürüme güncellenir.

## Kullanım (zankurd_mobile/ içinden)

  python3 tool/sync_local_parity_to_server.py            # raporla + SQL yaz
  python3 tool/sync_local_parity_to_server.py --check    # yalnız raporla
  python3 tool/sync_local_parity_to_server.py --server-json X --local-json Y

Çıktılar: kategori başına supabase/2026-10-01_local_parity_sync_<kategori>.sql
(ekleme) ve 2026-10-01_local_parity_update_<kategori>.sql (uuid5 eşli bayat
satırları yerel sürüme çekme), ayrıca
supabase/2026-10-01_retired_local_unapprove.sql. Tekrar çalıştırılabilir: iş
kalmadıysa mevcut göç dosyasının üzerine yazmaz. Ayrıntı döküm:
`.tmp/parity/detay.tsv`.
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import re
import subprocess
import sys
import unicodedata
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import sync_sinema_to_server as base  # noqa: E402

ROOT = base.ROOT
NAMESPACE = base.NAMESPACE
SQL_DIR = ROOT / "supabase"
RETIRED_SQL = SQL_DIR / "2026-10-01_retired_local_unapprove.sql"
WORK = ROOT / ".tmp" / "parity"

SERVER_QUERY = (
    "select q.id, c.name as category, q.prompt, q.option_a, q.option_b, "
    "q.option_c, q.option_d, q.correct_option, q.question_type, "
    "q.is_approved, q.review_status "
    "from questions q join categories c on c.id = q.category_id order by q.id"
)

# Yerel kategori adı = sunucu `categories.name` (önceki göçlerle aynı).
SERVER_CATEGORIES = {
    "Çand", "Cîhan", "Cografya", "Dîrok", "Edebiyat", "Muzîk",
    "Paradigma", "Sînema", "Siyaset", "Teknolojî", "Ziman",
}


# --------------------------------------------------------------- yardımcılar
def norm(s: str | None) -> str:
    s = unicodedata.normalize("NFKC", s or "").casefold()
    s = re.sub(r"[\W_]+", " ", s)
    return " ".join(s.split())


def canon_tf(s: str | None) -> str:
    n = norm(s)
    if n in ("rast", "rast e"):
        return "rast"
    if n in ("şaş", "şaş e"):
        return "şaş"
    return n


def local_uuid(local_id: str) -> str:
    return str(uuid.uuid5(NAMESPACE, "zankurd-local:" + local_id))


def is_tf(kind: str) -> bool:
    return kind in ("trueFalse", "true_false")


def ckey(kind: str, text: str | None) -> str:
    return canon_tf(text) if is_tf(kind) else norm(text)


def server_opts(r: dict) -> list[str]:
    return [r["option_a"], r["option_b"], r["option_c"], r["option_d"]]


def server_correct(r: dict) -> str:
    return server_opts(r)["ABCD".index(r["correct_option"])]


def same_content(q: dict, r: dict) -> bool:
    """Cevap + (çoktan seçmelide) şık KÜMESİ eşit; sıra önemsiz."""
    if ckey(q["type"], q["correctAnswer"]) != ckey(
        r["question_type"], server_correct(r)
    ):
        return False
    if is_tf(q["type"]):
        return True
    return sorted(map(norm, q["answers"])) == sorted(map(norm, server_opts(r)))


def run_select(sql: str) -> list[dict]:
    if not re.match(r"^\s*(select|with)\b", sql, re.I):
        raise SystemExit("run_select yalnız SELECT/WITH çalıştırır")
    # stdout bir BORU olursa supabase CLI çıktıyı ~630 KB'ta keser (bellek
    # içi okuma yarım JSON verir); dosyaya yönlendirmek tam çıktıyı verir.
    WORK.mkdir(parents=True, exist_ok=True)
    out_path = WORK / "_select_out.json"
    with out_path.open("w", encoding="utf-8") as out:
        proc = subprocess.run(
            ["supabase", "db", "query", "--linked", "-o", "json", sql],
            stdout=out,
            stderr=subprocess.PIPE,
            text=True,
            cwd=ROOT,
        )
    if proc.returncode != 0:
        raise SystemExit(f"supabase sorgusu başarısız:\n{proc.stderr[-800:]}")
    return json.loads(out_path.read_text(encoding="utf-8"))["rows"]


def dump_local(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, ZANKURD_PARITY_OUT=str(path))
    proc = subprocess.run(
        ["flutter", "test", "tool/parity/dump_local_bank_test.dart"],
        capture_output=True,
        text=True,
        cwd=ROOT,
        env=env,
    )
    if proc.returncode != 0:
        raise SystemExit(f"yerel döküm başarısız:\n{proc.stdout[-1500:]}")


# ------------------------------------------------------- sunucu satırı kurma
def insertable_reason(q: dict) -> str | None:
    """Sunucu şemasına sığmıyorsa nedeni; sığıyorsa None."""
    t = q["type"]
    if t not in ("multipleChoice", "trueFalse", "visual"):
        return f"tür:{t}"
    if q["category"] not in SERVER_CATEGORIES:
        return f"kategori:{q['category']}"
    answers = q["answers"]
    if t == "trueFalse":
        if len(answers) != 2 or canon_tf(q["correctAnswer"]) not in ("rast", "şaş"):
            return "doğru/yanlış biçimi"
    else:
        if len(answers) != 4:
            return "4 şık yok"
    if t == "visual":
        if not (q.get("imageUrl") or "").startswith("asset://"):
            return "görsel asset:// değil"
    else:
        if (q.get("imageUrl") or "").strip() or base.IMAGE_DEPENDENT.search(
            q["prompt"] + " " + (q.get("promptTr") or "")
        ):
            return "görsel (görselsiz anlamsız)"
    return None


def server_row(q: dict) -> dict:
    """Yerel soru -> sunucu satırı alanları (`base.to_row` ile aynı kurallar)."""
    t = q["type"]
    answers = list(q["answers"])
    if t == "trueFalse":
        opts = ["Rast", "Şaş", "-", "-"]
        correct = "A" if canon_tf(q["correctAnswer"]) == "rast" else "B"
        qtype = "true_false"
    else:
        opts = answers
        correct = "ABCD"[answers.index(q["correctAnswer"])]
        qtype = "visual" if t == "visual" else "multiple_choice"
    ex_ku = (q.get("explanationKu") or "").strip() or None
    ex_tr = (q.get("explanationTr") or "").strip() or None
    ex = ex_ku or (q.get("explanation") or "").strip() or None
    ref = (q.get("sourceReference") or "").strip() or None
    url = ref if ref and re.fullmatch(r"https?://\S+", ref) else None
    return {
        "id": local_uuid(q["id"]),
        "local_id": q["id"],
        "category": q["category"],
        "prompt": q["prompt"].strip(),
        "opts": opts,
        "correct": correct,
        "explanation": ex,
        "explanation_ku": ex_ku,
        "explanation_tr": ex_tr,
        "difficulty": max(1, min(5, int(q.get("difficulty") or 2))),
        "qtype": qtype,
        "image_url": (q.get("imageUrl") or "").strip() or None
        if t == "visual"
        else None,
        "source_url": url,
        "source_title": (q.get("sourceTitle") or "").strip() or None,
        "source_reference": ref,
        "quality_version": max(1, int(q.get("qualityVersion") or 1)),
    }


def insert_sql(r: dict) -> str:
    s = base.sql_str
    vals = [
        s(r["id"]),
        f"(select id from categories where name = {s(r['category'])})",
        "'ku-kmr'",
        s(r["prompt"]),
        *[s(o) for o in r["opts"]],
        s(r["correct"]),
        s(r["explanation"]),
        s(r["explanation_ku"]),
        s(r["explanation_tr"]),
        str(r["difficulty"]),
        "true",
        s(r["qtype"]),
        s(r["image_url"]),
        s(r["source_url"]),
        s(r["source_title"]),
        s(r["source_reference"]),
        "'approved'",
        "'Kurmancî'",
        str(r["quality_version"]),
        "now()",
    ]
    return "(" + ", ".join(vals) + ")"


# ------------------------------------------------------------ sınıflandırma
def _queue_insert(plan, stat, q, row, kind, include_visual) -> None:
    """Eklenecekse kuyruğa al; görselliyse bayrak yoksa yalnız say."""
    if q["type"] == "visual" and not include_visual:
        stat["gorsel_atlandi"] += 1
        plan["detail"].append(("gorsel_atlandi", q["id"], q["category"], kind))
        return
    plan["insert"].append((kind, row))


def classify(
    local: list[dict],
    server: list[dict],
    include_identical: bool,
    include_visual: bool,
):
    by_id = {r["id"]: r for r in server}
    by_pc: dict[tuple[str, str], list[dict]] = collections.defaultdict(list)
    by_p: dict[str, list[dict]] = collections.defaultdict(list)
    for r in server:
        by_pc[(r["category"], norm(r["prompt"]))].append(r)
        by_p[norm(r["prompt"])].append(r)

    playable = [q for q in local if q["playable"]]
    plan = {
        "stat": collections.defaultdict(collections.Counter),  # kategori -> sınıf
        "insert": [],  # (sınıf, satır)
        "update": [],  # uuid5 eşi onaylı/onaysız satırı yerel sürüme çek
        "reapprove": [],
        "detail": [],  # (sınıf, yerel id, kategori, not)
        "claimed": set(),  # yerel soruyla eşleşen sunucu satırları
    }
    for q in sorted(playable, key=lambda x: (x["category"], x["id"])):
        stat = plan["stat"][q["category"]]
        stat["yerel_oynanabilir"] += 1
        why = insertable_reason(q)
        if why:
            stat["sema"] += 1
            plan["detail"].append(("sema", q["id"], q["category"], why))
            continue
        row = server_row(q)
        u = row["id"]
        if u in by_id:
            r = by_id[u]
            plan["claimed"].add(u)
            drift = norm(q["prompt"]) != norm(r["prompt"]) or not same_content(q, r)
            if r["is_approved"]:
                stat["a_uuid"] += 1
                if drift:
                    stat["drift"] += 1
                    plan["update"].append(row)
                    plan["detail"].append(("drift", q["id"], q["category"], r["prompt"]))
            else:
                stat["b_uuid"] += 1
                plan["reapprove"].append(row)
                plan["detail"].append(("b_uuid", q["id"], q["category"], r["prompt"]))
            continue
        cands = by_pc.get((q["category"], norm(q["prompt"])), [])
        appr = [r for r in cands if r["is_approved"]]
        if appr:
            for r in appr:
                plan["claimed"].add(r["id"])
            if any(same_content(q, r) for r in appr):
                stat["a_ozdes"] += 1
            else:
                stat["a_varyant"] += 1
                note = "; ".join(server_correct(r) for r in appr)
                if is_tf(q["type"]):
                    note = "DOĞRU/YANLIŞ ÇELİŞKİSİ? sunucu: " + note
                plan["detail"].append(("a_varyant", q["id"], q["category"], note))
            continue
        if cands:
            if any(same_content(q, r) for r in cands):
                stat["b_ozdes"] += 1
                plan["detail"].append(
                    ("b_ozdes", q["id"], q["category"], "; ".join(r["id"] for r in cands))
                )
                if include_identical:
                    _queue_insert(plan, stat, q, row, "b_ozdes", include_visual)
            else:
                stat["b_varyant"] += 1
                _queue_insert(plan, stat, q, row, "b_varyant", include_visual)
            continue
        np_ = norm(q["prompt"])
        cross = [
            r
            for r in by_p.get(np_, [])
            if r["is_approved"]
            and r["category"] != q["category"]
            and ckey(q["type"], q["correctAnswer"])
            == ckey(r["question_type"], server_correct(r))
        ]
        if cross:
            stat["capraz"] += 1
            plan["detail"].append(
                ("capraz", q["id"], q["category"], ",".join(r["category"] for r in cross))
            )
            continue
        stat["c"] += 1
        _queue_insert(plan, stat, q, row, "c", include_visual)
    return plan


def find_retired_live(local: list[dict], server: list[dict], claimed: set[str]):
    """Sunucuda onaylı olup oynanamaz/emekli yerel soruyla eşleşen satırlar."""
    playable_keys = {
        (norm(q["prompt"]), ckey(q["type"], q["correctAnswer"]))
        for q in local
        if q["playable"]
    }
    by_id = {r["id"]: r for r in server}
    by_p: dict[str, list[dict]] = collections.defaultdict(list)
    for r in server:
        if r["is_approved"]:
            by_p[norm(r["prompt"])].append(r)
    hits: dict[str, dict] = {}
    for q in sorted(local, key=lambda x: x["id"]):
        if q["playable"]:
            continue
        key = (norm(q["prompt"]), ckey(q["type"], q["correctAnswer"]))
        if key in playable_keys:
            continue  # banka aynı içeriği başka kimlikle oynanabilir tutuyor
        found: list[tuple[dict, str]] = []
        u = by_id.get(local_uuid(q["id"]))
        if u is not None and u["is_approved"]:
            found.append((u, "uuid"))
        for r in by_p.get(key[0], []):
            if ckey(r["question_type"], server_correct(r)) == key[1]:
                found.append((r, "metin"))
        for r, how in found:
            if r["id"] in claimed:
                continue  # oynanabilir bir yerel sorunun sunucudaki karşılığı
            hits.setdefault(
                r["id"],
                {"server": r, "local_id": q["id"], "reason": q["reason"], "how": how},
            )
    return hits


# ------------------------------------------------------------- SQL yazımı
def ascii_slug(category: str) -> str:
    s = unicodedata.normalize("NFKD", category)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", "", s.casefold())


def insert_path(category: str) -> Path:
    return SQL_DIR / f"2026-10-01_local_parity_sync_{ascii_slug(category)}.sql"


def update_path(category: str) -> Path:
    return SQL_DIR / f"2026-10-01_local_parity_update_{ascii_slug(category)}.sql"


def _precondition(category: str) -> str:
    return (
        "-- Önkoşul: kategori sunucuda var (bu göç oluşturmaz).\n"
        "do $$\nbegin\n"
        f"  if not exists (select 1 from categories where name = {base.sql_str(category)}) then\n"
        f"    raise exception 'Eksik kategori: {category}';\n"
        "  end if;\nend\n$$;\n"
    )


def write_insert_sql(
    category: str, inserts: list[tuple[str, dict]], local_count: int, visual_skipped: int
) -> str:
    """Tek kategori için ekleme göçü (kendi önkoşulu ve kesin sayı doğrulamasıyla)."""
    s = base.sql_str
    inserts = sorted(inserts, key=lambda x: x[1]["local_id"])
    rows = [r for _, r in inserts]
    n = len(rows)
    kinds = collections.Counter(k for k, _ in inserts)
    by_type = collections.Counter(r["qtype"] for r in rows)
    types = ", ".join(f"{k} {v}" for k, v in sorted(by_type.items()))
    lines = [
        insert_sql(r) + ("," if i + 1 < n else "") + f" -- yerel: {r['local_id']}"
        for i, r in enumerate(rows)
    ]
    ids = ", ".join(s(r["id"]) for r in rows)
    header = f"""-- 2026-10-01: yerel denetlenmiş bankanın sunucuda EKSİK {n} {category} sorusu (canlı sunucu).
--
-- NİÇİN: oda ve düello soruları sunucudaki `questions` tablosundan oynanır;
-- kaynak doğru ise denetlenmiş yerel bankadır (question_bank_assets.dart ∖
-- retired_question_ids.dart ∖ QuestionContentPolicy.isPlayable dışı).
-- Sunucuda bu kategorideki yerel sorunun onaylı karşılığı (uuid5 ya da aynı
-- kategoride aynı soru metni) bulunmayanlar burada; oyuncu tek başına
-- gördüğü soruyu odada/düelloda görmüyordu. Kategori başına ayrı dosyadır
-- (her biri kendi önkoşulu ve kesin sayı doğrulamasıyla; kısmi uygulama olur).
--
-- KAÇ SATIR: {n} ({types}). Sınıf: sunucuda hiç yok (c) {kinds.get('c', 0)};
-- sunucuda yalnız onaysız ve başka yazımda (b_varyant) {kinds.get('b_varyant', 0)};
-- özdeş onaysız (b_ozdes, yalnız --include-unapproved-identical) {kinds.get('b_ozdes', 0)}.
--
-- ONAYSIZ SATIRLAR (b): sunucuda içeriği yereldekiyle ÖZDEŞ ve onaysız duran
-- sorulara DOKUNULMADI (onay kaldırma editoryal bir karardı). Başka yazımda
-- onaysız duranlar için eski satır yeniden onaylanmaz (eski metin canlıya
-- çıkardı); yerel sürüm yeni uuid5 satırı olarak eklenir, eski satır onaysız
-- kalır. Böylece aynı sorunun iki ONAYLI kopyası oluşmaz.
--
-- GÖRSELLİ SORULAR BU DOSYADA YOK: yerelde bu kategoride {visual_skipped} görselli
-- (`asset://`) soru atlandı. Mağazadaki eski uygulama sürümlerinde yeni görsel
-- dosyaları paketli değil; oda/düelloda kırık görsel çıkardı. 2.0.0 yayına
-- çıkınca ayrı bir göçle (`--include-visual`) eklenecek. Boşluk doldurma ve
-- cümle dizme gibi sunucu şemasına sığmayan türler de atlandı.
--
-- KATEGORİ: `categories.name` ile aranır; yoksa hiçbir şey eklenmeden işlem
-- geri alınır. Kategori OLUŞTURMAZ.
--
-- TEKRAR ÇALIŞTIRILABİLİR: `on conflict (id) do nothing`; ikinci çalıştırma
-- satır eklemez. Doğrulama bloğu bu dosyadaki {n} kimliğin hepsinin kategoride
-- ONAYLI durduğunu denetler; tutmazsa işlem geri alınır.
--
-- GERİ ALMA (yalnız bu göçün satırları):
--   delete from questions where id in (<bu dosyadaki kimlikler>);
--
-- Üretici: tool/sync_local_parity_to_server.py (YEREL_OYNANABILIR: {local_count})
-- Uygulama: supabase db query --linked -f supabase/{insert_path(category).name}
"""
    return f"""{header}
begin;

{_precondition(category)}
insert into questions ({base.COLUMNS})
values
{chr(10).join(lines)}
on conflict (id) do nothing;

-- Doğrulama: bu dosyadaki kimliklerin hepsi {category} kategorisinde onaylı olmalı.
do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from questions
  where id in ({ids})
    and category_id = (select id from categories where name = {s(category)})
    and is_approved = true;
  if v_count <> {n} then
    raise exception '{category}: beklenen {n} onayli soru, bulunan %', v_count;
  end if;
end
$$;

commit;
"""


def write_update_sql(
    category: str, updates: list[dict], reapprove: list[dict], local_count: int
) -> str:
    """Tek kategori için eşitleme (uuid5 eşli satırları yerel sürüme çekme)."""
    s = base.sql_str
    rows = sorted(updates + reapprove, key=lambda r: r["local_id"])
    n = len(rows)
    vals = "\n".join(
        "  ("
        + ", ".join(
            [
                s(r["id"]) + "::uuid",
                s(r["prompt"]),
                *[s(o) for o in r["opts"]],
                s(r["correct"]),
                s(r["explanation"]),
                s(r["explanation_ku"]),
                s(r["explanation_tr"]),
            ]
        )
        + ")"
        + ("," if i + 1 < n else ";")
        + f" -- yerel: {r['local_id']}"
        for i, r in enumerate(rows)
    )
    header = f"""-- 2026-10-01: {category} kategorisinde sunucudaki {n} bayat satırı yerel denetlenmiş sürüme çek (canlı sunucu).
--
-- NİÇİN: kimliği uuid5('zankurd-local:' + yerel id) olan bu satırlar daha önce
-- yerel bankadan sunucuya eklendi; sonra yerelde metin düzeltildi (Kurmancî
-- yazım/terim düzeltmeleri, bir doğru cevap farkı) ama sunucu eski kopyayla
-- kaldı. Kimlik uuid5 olduğu için eşleşme kesindir. Yalnız soru metni, şık
-- KÜMESİ ya da doğru cevap ayrışanlar alınır; şık SIRASI farkı sayılmadı.
-- Güncellenen: {len(updates)}; onaysızken yeniden onaylanan: {len(reapprove)}.
--
-- Alanlar: prompt, option_a-d, correct_option, explanation(_ku/_tr);
-- is_approved = true, review_status = 'approved', updated_at = now().
--
-- TEKRAR ÇALIŞTIRILABİLİR: aynı değerleri yazar. Doğrulama bloğu {n} satırın
-- yerel metne eşit olduğunu denetler; tutmazsa işlem geri alınır.
--
-- GERİ ALMA: eski metin bu dosyada YOK; gerekirse sunucu dökümünden
-- (`tool/sync_local_parity_to_server.py` çalıştırılırken `.tmp/parity/
-- server_questions.json`) alınır. Yeniden onaylananlar için is_approved = false.
--
-- Üretici: tool/sync_local_parity_to_server.py (YEREL_OYNANABILIR: {local_count})
-- Uygulama: supabase db query --linked -f supabase/{update_path(category).name}
"""
    return f"""{header}
begin;

{_precondition(category)}
create temp table _parity_guncel(
  id uuid primary key, prompt text, option_a text, option_b text,
  option_c text, option_d text, correct_option text,
  explanation text, explanation_ku text, explanation_tr text
) on commit drop;
insert into _parity_guncel values
{vals}

do $$
declare
  v_known int;
begin
  select count(*) into v_known
  from questions q join _parity_guncel g on g.id = q.id
  where q.category_id = (select id from categories where name = {s(category)});
  if v_known <> {n} then
    raise exception '{category}: güncellenecek {n} satırdan yalnız % sunucuda', v_known;
  end if;
end
$$;

update questions q
set prompt = g.prompt,
    option_a = g.option_a, option_b = g.option_b,
    option_c = g.option_c, option_d = g.option_d,
    correct_option = g.correct_option,
    explanation = g.explanation,
    explanation_ku = g.explanation_ku,
    explanation_tr = g.explanation_tr,
    is_approved = true,
    review_status = 'approved',
    updated_at = now()
from _parity_guncel g
where g.id = q.id;

do $$
declare
  v_count integer;
begin
  select count(*) into v_count
  from questions q join _parity_guncel g on g.id = q.id
  where q.is_approved = true
    and q.prompt = g.prompt
    and q.correct_option = g.correct_option
    and q.option_a = g.option_a and q.option_b = g.option_b
    and q.option_c = g.option_c and q.option_d = g.option_d;
  if v_count <> {n} then
    raise exception '{category}: beklenen {n} güncel onayli satir, bulunan %', v_count;
  end if;
end
$$;

commit;
"""



def write_retired_sql(hits: dict[str, dict], local_count: int) -> tuple[str, dict]:
    s = base.sql_str
    if not hits:
        return "", {}
    items = sorted(
        hits.values(), key=lambda h: (h["server"]["category"], h["server"]["id"])
    )
    n = len(items)
    per_cat = collections.Counter(h["server"]["category"] for h in items)
    by_reason = collections.Counter((h["reason"], h["how"]) for h in items)
    cat_lines = "\n".join(f"--   - {c}: {k}" for c, k in sorted(per_cat.items()))
    reason_lines = "\n".join(
        f"--   - {r} / eşleşme {how}: {k}" for (r, how), k in sorted(by_reason.items())
    )
    header = f"""-- 2026-10-01: yerelde EMEKLİ/oynanamaz olup sunucuda hâlâ onaylı duran {n} bilinen-kötü soru onaydan çıkarıldı.
--
-- NİÇİN: yerel banka denetlenir ve kusurlu sorular `retired_question_ids.dart`
-- ile emekliye ayrılır (şablon tanım takası, tür ipucu sızan şıklar, kopya
-- şık, Kürt bağı olmayan genel kültür…) ya da `reviewStatus` ile elenir.
-- Ama oda ve düello sunucudan oynar ve bu kayıtlar sunucuya HİÇ yansımamıştı:
-- yerelde atılan soru odada sorulmaya devam ediyordu. Eşleşme: sunucudaki
-- ONAYLI satırın soru metni + doğru cevabı, oynanamaz bir yerel sorununkiyle
-- eşit (ya da kimliği o yerel sorunun uuid5'i). Bankanın aynı içeriği başka
-- bir kimlikle OYNANABİLİR tuttuğu ve oynanabilir bir yerel sorunun sunucu
-- karşılığı olan satırlar çıkarılmaz.
--
-- KAÇ SORU: {n} satır. Sunucu kategorisine göre:
{cat_lines}
-- Yerel elenme nedeni / eşleşme yolu:
{reason_lines}
--
-- Sorular SİLİNMEZ: yalnız is_approved = false (review_status değişmez).
-- Her satırın yanındaki `-- yerel:` yorumu, eşleştiği yerel kimliği gösterir.
--
-- TEKRAR ÇALIŞTIRILABİLİR: zaten onaysız olan satır tekrar onaysız yapılır
-- (değişiklik yok). Doğrulama: listedeki hiçbir satır onaylı kalmamalı ve
-- kategori dağılımı yukarıdakiyle aynı olmalı; tutmazsa tümü geri alınır.
--
-- GERİ ALMA: aynı id listesiyle `update questions set is_approved = true
--   where id in (…)` (çıkarılan kümenin tamamı bu dosyadaki listedir).
--
-- Üretici: tool/sync_local_parity_to_server.py (YEREL_OYNANABILIR: {local_count})
-- Uygulama: supabase db query --linked -f supabase/2026-10-01_retired_local_unapprove.sql
"""
    vals = []
    for i, h in enumerate(items):
        r = h["server"]
        comma = "," if i + 1 < n else ";"
        vals.append(
            f"  ({s(r['id'])}::uuid, {s(r['category'])}){comma} "
            f"-- yerel: {h['local_id']} ({h['reason']}, {h['how']})"
        )
    cat_checks = "".join(
        f"""
  select count(*) into v_count
  from questions q join _canli_emekli e on e.id = q.id
  where q.category_id = (select id from categories where name = {s(c)});
  if v_count <> {k} then
    raise exception '{c}: listede beklenen {k} satir, bulunan %', v_count;
  end if;"""
        for c, k in sorted(per_cat.items())
    )
    sql = f"""{header}
begin;

create temp table _canli_emekli(id uuid primary key, category text) on commit drop;
insert into _canli_emekli(id, category) values
{chr(10).join(vals)}

do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from questions q join _canli_emekli e on e.id = q.id;
  if v_count <> {n} then
    raise exception 'listedeki % id''den yalnız % sunucuda', {n}, v_count;
  end if;
end
$$;

update questions q set is_approved = false
from _canli_emekli e
where e.id = q.id and q.is_approved = true;

do $$
declare
  v_count int;
begin
  select count(*) into v_count
  from questions q join _canli_emekli e on e.id = q.id
  where q.is_approved = true;
  if v_count <> 0 then
    raise exception 'emekli listesinden % soru hala onayli', v_count;
  end if;
{cat_checks}
end
$$;

commit;
"""
    return sql, {"rows": n, "per_cat": per_cat, "by_reason": by_reason}


# ---------------------------------------------------------------------- main
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="dosya yazma, yalnız rapor")
    ap.add_argument("--local-json", help="hazır yerel döküm (flutter çalıştırma)")
    ap.add_argument("--server-json", help="hazır sunucu dökümü (sorgu çalıştırma)")
    ap.add_argument(
        "--include-unapproved-identical",
        action="store_true",
        help="sunucuda ÖZDEŞ içerikle onaysız duranlar için de yeni satır ekle",
    )
    ap.add_argument(
        "--include-visual",
        action="store_true",
        help="görselli (asset://) soruları da ekle; varsayılan atlar (eski "
        "uygulama sürümlerinde yeni görsel dosyaları yok, kırık görsel çıkar)",
    )
    ap.add_argument("--work-dir", default=str(WORK))
    args = ap.parse_args()
    work = Path(args.work_dir)
    work.mkdir(parents=True, exist_ok=True)

    local_path = Path(args.local_json) if args.local_json else work / "local_bank.json"
    if not args.local_json:
        dump_local(local_path)
    local = json.loads(local_path.read_text(encoding="utf-8"))

    if args.server_json:
        raw = json.loads(Path(args.server_json).read_text(encoding="utf-8"))
        server = raw["rows"] if isinstance(raw, dict) else raw
    else:
        server = run_select(SERVER_QUERY)
        (work / "server_questions.json").write_text(
            json.dumps(server, ensure_ascii=False), encoding="utf-8"
        )

    playable_total = sum(1 for q in local if q["playable"])
    plan = classify(
        local, server, args.include_unapproved_identical, args.include_visual
    )
    hits = find_retired_live(local, server, plan["claimed"])

    # ---- rapor
    stat = plan["stat"]
    cols = [
        "yerel_oynanabilir", "a_uuid", "a_ozdes", "a_varyant", "b_uuid",
        "b_ozdes", "b_varyant", "capraz", "c", "gorsel_atlandi", "sema", "drift",
    ]
    print(f"Yerel yüklenen: {len(local)}  oynanabilir: {playable_total}")
    print(f"Sunucu satırı: {len(server)}  onaylı: {sum(1 for r in server if r['is_approved'])}")
    print("kategori".ljust(11) + "".join(c[:9].rjust(10) for c in cols))
    tot = collections.Counter()
    for cat in sorted(stat):
        print(cat.ljust(11) + "".join(str(stat[cat][c]).rjust(10) for c in cols))
        tot.update(stat[cat])
    print("TOPLAM".ljust(11) + "".join(str(tot[c]).rjust(10) for c in cols))

    approved_before = collections.Counter(
        r["category"] for r in server if r["is_approved"]
    )
    ins_cat = collections.Counter(r["category"] for _, r in plan["insert"])
    reap_cat = collections.Counter(r["category"] for r in plan["reapprove"])
    ret_cat = collections.Counter(h["server"]["category"] for h in hits.values())
    print("\nOnaylı sunucu sorusu (önce -> sonra: + ekleme/yeniden onay, - emekli):")
    cats = sorted(set(approved_before) | set(ins_cat) | set(ret_cat))
    after_total = 0
    for cat in cats:
        a = approved_before[cat]
        z = a + ins_cat[cat] + reap_cat[cat] - ret_cat[cat]
        after_total += z
        print(
            f"  {cat.ljust(10)} {a:5d} -> {z:5d}   "
            f"(+{ins_cat[cat] + reap_cat[cat]} -{ret_cat[cat]})"
        )
    print(
        f"  {'TOPLAM'.ljust(10)} {sum(approved_before.values()):5d} -> {after_total:5d}"
    )
    print(f"\nEmekli/oynanamaz yerel soruyla eşleşen onaylı sunucu satırı: {len(hits)}")
    for h in sorted(hits.values(), key=lambda h: h["local_id"])[:8]:
        print(f"  {h['local_id']} ({h['reason']}, {h['how']}): {h['server']['prompt'][:80]}")

    detail = work / "detay.tsv"
    with detail.open("w", encoding="utf-8") as fh:
        for kind, lid, cat, note in plan["detail"]:
            fh.write(f"{kind}\t{lid}\t{cat}\t{note}\n")
        for h in hits.values():
            r = h["server"]
            fh.write(
                f"emekli_canli\t{h['local_id']}\t{r['category']}\t{r['id']} {h['how']} {r['prompt']}\n"
            )
    print(f"Ayrıntı: {detail}")

    if args.check:
        return 0

    ins_by_cat: dict[str, list[tuple[str, dict]]] = collections.defaultdict(list)
    for kind, r in plan["insert"]:
        ins_by_cat[r["category"]].append((kind, r))
    upd_by_cat: dict[str, list[dict]] = collections.defaultdict(list)
    rea_by_cat: dict[str, list[dict]] = collections.defaultdict(list)
    for r in plan["update"]:
        upd_by_cat[r["category"]].append(r)
    for r in plan["reapprove"]:
        rea_by_cat[r["category"]].append(r)
    for cat in sorted(ins_by_cat):
        sql = write_insert_sql(
            cat, ins_by_cat[cat], playable_total, stat[cat]["gorsel_atlandi"]
        )
        path = insert_path(cat)
        path.write_text(sql, encoding="utf-8")
        print(f"Yazıldı: {path.name} ({len(sql)} bayt, {len(ins_by_cat[cat])} ekleme)")
    for cat in sorted(set(upd_by_cat) | set(rea_by_cat)):
        sql = write_update_sql(cat, upd_by_cat[cat], rea_by_cat[cat], playable_total)
        path = update_path(cat)
        path.write_text(sql, encoding="utf-8")
        print(f"Yazıldı: {path.name} ({len(sql)} bayt)")
    if not ins_by_cat and not upd_by_cat and not rea_by_cat:
        print("Eşitleme göçleri: iş yok, dosyalara dokunulmadı.")
    ret_sql, ret_info = write_retired_sql(hits, playable_total)
    if ret_sql:
        RETIRED_SQL.write_text(ret_sql, encoding="utf-8")
        print(f"Yazıldı: {RETIRED_SQL} ({len(ret_sql)} bayt, {ret_info['rows']} satır)")
    else:
        print("Emekli göçü: iş yok, dosyaya dokunulmadı.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
