#!/usr/bin/env python3
"""Aynı olguyu soran yinelenmiş kayıtları ayıklar.

## Niçin

Banka on ayrı dosyadan, farklı zamanlarda, farklı araçlarla üretildi ve
hiçbir aşamada BANKALAR ARASI tekrar denetimi yapılmadı. Sonuç: "agir"
kelimesinin anlamı üç ayrı soruda, Gola Wanê'nin tanımı iki ayrı soruda,
"pirtûk"un Türkçesi üç ayrı soruda soruluyor. Oyuncu bir turda aynı
olguyu iki kez görebiliyor.

`SeenQuestionStore` bunu çözmez: kayıtların kimlikleri farklı olduğu
için "görüldü" mantığı onları ayrı sorular sayar. Tekrar KAYNAKTA
çözülmeli.

## Hangisi kalır

Kümedeki kayıtlar şu sıraya göre puanlanır, en yüksek puanlı kalır:

0. **Banka dışından referans alınan ya da GÖRSEL taşıyan.** Bu ölçüt
   diğerlerinin hepsini ezer. Görsel taşıyan kayıt silinince pakete
   giren `.webp` dosyası hiçbir yerden kullanılmaz hâle geliyor;
   `asset_usage_test` bunu yakaladı (kevin, rast, pir). Görselli
   sorular zaten kıt ve bir görselin sorusunu silmek görselin kendisini
   de çöpe atmak demek. 503 kimliğin 19'u `explanation_overrides.dart`, bazı widget'lar
   ve testlerden adıyla anılıyor; silinirse geçersiz kılma öksüz kalır
   ve testler kırılır. Referanslı kayıt kümesinde daima kalan olur.
1. Açıklaması olan (oyuncu tur sonunda niçinini okuyabilsin).
2. İki dili de tam olan (`promptTr` + `answersTr`).
3. Çoktan seçmeli, doğru/yanlış değil — dört şık iki şıktan çok bilgi
   taşır ve tahminle bilinme olasılığı yarıdır.
4. Şık sayısı çok olan.
5. Eşitlik bozulmazsa manifest sırasında SONRAKİ banka: aynı kimlik
   çakışmasında da sonraki kazanıyor, tutarlı olsun.

Silinen kayıtlar `docs/content_batches/ayiklanan_tekrarlar.json` altına
tam hâliyle yazılır — geri almak için.
"""
import json
import pathlib
import re
import sys
from collections import defaultdict

BULGU = pathlib.Path("docs/content_batches/gpt_bulgular/tum.json")
YEDEK = pathlib.Path("docs/content_batches/ayiklanan_tekrarlar.json")


def clusters(findings: list) -> list:
    parent = {}

    def find(node):
        parent.setdefault(node, node)
        while parent[node] != node:
            parent[node] = parent[parent[node]]
            node = parent[node]
        return node

    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    for finding in findings:
        kinds = finding.get("kusur") or []
        if "tekrar" not in kinds:
            continue
        partners = re.findall(r"\b[a-z]+[a-z0-9_]*_\d{3,5}\b",
                              finding.get("not", ""))
        find(finding["id"])
        for partner in partners:
            union(finding["id"], partner)

    groups = defaultdict(list)
    for node in parent:
        groups[find(node)].append(node)
    return [sorted(v) for v in groups.values() if len(v) > 1]


def referenced() -> set:
    """Banka dosyaları DIŞINDA adı geçen soru kimlikleri.

    `explanation_overrides.dart` bir kayda özel açıklama bağlar; kayıt
    silinirse bağ öksüz kalır. Testler ve bazı widget'lar da kimlikleri
    doğrudan anar ve silme onları kırar. Bu küme silmeye kapalıdır.
    """
    ids = set()
    roots = [pathlib.Path("lib"), pathlib.Path("test"),
             pathlib.Path("tool")]
    pattern = re.compile(r"['\"]([a-z][a-z0-9_]*_\d{3,5})['\"]")
    for root in roots:
        if not root.exists():
            continue
        for file in root.rglob("*"):
            if file.suffix not in {".dart", ".py", ".json"} or not file.is_file():
                continue
            try:
                ids.update(pattern.findall(file.read_text(encoding="utf-8")))
            except (UnicodeDecodeError, OSError):
                continue
    return ids


def score(question: dict, bank_order: int, protected: set) -> tuple:
    explanation = (question.get("explanation") or "").strip()
    bilingual = bool(question.get("promptTr")) and bool(question.get("answersTr"))
    kind = question.get("type") or "multipleChoice"
    return (
        1 if (question["id"] in protected or question.get("imageUrl")) else 0,
        1 if explanation else 0,
        1 if bilingual else 0,
        0 if kind == "trueFalse" else 1,
        len(question.get("answers") or []),
        bank_order,
    )


def main() -> int:
    manifest = pathlib.Path("lib/src/data/question_bank_assets.dart").read_text(
        encoding="utf-8")
    assets = re.findall(r"'(assets/data/[^']+\.json)'", manifest)

    banks = {}
    where, order = {}, {}
    for index, asset in enumerate(assets):
        path = pathlib.Path(asset)
        if not path.exists():
            continue
        banks[asset] = json.loads(path.read_text(encoding="utf-8"))
        for question in banks[asset]:
            where[question["id"]] = asset
            order[question["id"]] = index

    findings = [f for f in json.loads(BULGU.read_text(encoding="utf-8"))
                if "_okunan" not in f]
    groups = clusters(findings)
    protected = referenced()

    drop, keep_log = set(), []
    for group in groups:
        present = [q for q in group if q in where]
        if len(present) < 2:
            continue
        best = max(present, key=lambda i: score(
            next(x for x in banks[where[i]] if x["id"] == i),
            order[i], protected))
        for qid in present:
            # Bir kümede birden çok korunan kayıt varsa hiçbiri silinmez:
            # silinen her biri bir bağı ya da bir görseli koparırdı.
            record = next(x for x in banks[where[qid]] if x["id"] == qid)
            if qid != best and qid not in protected and not record.get("imageUrl"):
                drop.add(qid)
        keep_log.append({"kalan": best, "elenen": [q for q in present if q != best]})

    if "--uygula" not in sys.argv:
        print(f"küme: {len(groups)}   elenecek: {len(drop)}")
        print(f"referans yüzünden korunan: "
              f"{len({i for g in groups for i in g} & protected)}")
        print("uygulamak için: --uygula")
        return 0

    removed = []
    for asset, questions in banks.items():
        kept = [q for q in questions if q["id"] not in drop]
        if len(kept) != len(questions):
            removed.extend(q for q in questions if q["id"] in drop)
            pathlib.Path(asset).write_text(
                json.dumps(kept, ensure_ascii=False, indent=1), encoding="utf-8")
            print(f"  {pathlib.Path(asset).name}: "
                  f"{len(questions)} -> {len(kept)}")

    YEDEK.write_text(json.dumps(
        {"elenen_kayitlar": removed, "kume_kararlari": keep_log},
        ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n{len(removed)} kayıt elendi -> {YEDEK}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
