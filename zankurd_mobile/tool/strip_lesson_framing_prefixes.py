#!/usr/bin/env python3
"""Anlamsız ders çerçevesi öneklerini siler ve açığa çıkan kopyaları atar.

Bankadaki 2387 sorunun **479'u** şu iki kalıptan biriyle başlıyordu:

    Di gotûbêja dersê de, di qada ziman de têgeha 'ergatîf' bi kîjan
    ravekirinê çêtir tê fêmkirin?

    Di nirxandina xwendekaran de, di qada ziman de têgeha 'ergatîf' bi
    kîjan ravekirinê çêtir tê fêmkirin?

"Ders tartışmasında" ve "öğrenci değerlendirmesinde" — ikisi de hiçbir
şey söylemiyor; makine üretiminden kalma çerçeve cümleleri. Oyuncu her
soruda önce bu dolguyu okuyor.

Asıl kusur önek silinince görünür oluyor: **aynı soru üç kez var.**
Yukarıdaki iki örnek, öneksiz bir üçüncüsüyle birlikte tıpatıp aynı
soru, aynı doğru cevap; yalnız çeldiricilerin sırası karışık. 240 grubun
239'u üçlü. Yani bir oyuncu aynı soruyu bir turda üç kez görebiliyordu.

Bankanın "kategori içinde gövdeler benzersiz" bekçisi bunu göremiyordu,
çünkü önekler gövdeleri farklı kılıyordu — dolgu, bekçiyi de atlatıyordu.

Aynı sınıftan iki dolgu daha var: **"di qada Cografyaê de"** ve
**"li qada ziman"**.
Kategori adı zaten soru kartının üstünde çip olarak yazıyor, yani cümle
ekranda görünen bir şeyi tekrar ediyor. Üstelik bu adlar bankanın iç
anahtarları ("Cografya") ve Kurmancî çekimleri de bozuk: "Cografyaê"
yerine "Cografyayê", "Paradigmaê" yerine "Paradîgmayê" olmalıydı. Yani
dolgu hem gereksiz hem yanlıştı; 98 gövdede geçiyordu.

İkincisi 80 gövdede: "Kîjan têgeh **li qada ziman** bi vê ravekirinê tê
nasîn: '…'?" Burada da kategori adı bankanın küçük harfli iç anahtarıydı
ve cümleye hiçbir şey katmıyordu.

Betik iki iş yapar:
1. Dolguları siler ve kalan cümleyi büyük harfle başlatır.
2. (kategori, gövde, doğru cevap) üçlüsüne göre tekilleştirir; dolgusuz
   asıl kaydı tutar, kopyaları atar.

Bekçiler bankanın geri kalanını korur. Seviye bantlarında yeterli
benzersiz gövde kalıyor. Doğru cevabın A/B/C/D dağılımı ise kopyalar
atılınca bozuluyor — 240 grubun her birinden iki kayıt çıkınca dağılım
[275, 277, 275, 276] oldu, bekçi en fazla 1 yayılıma izin veriyor. Bu
yüzden betik sonda dengeyi geri kurar: en kalabalık harften en tenha
harfe, gereken en az sayıda soruda şıkları döndürerek. Şık sırası zaten
`displayAnswers` tarafından id'ye göre kaydırıldığı için bu, oyuncunun
gördüğü şık sırasını rastgele bozmaz; yalnız doğru cevabın harfini
değiştirir.
"""
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets/data"
BANKS = ["offline_questions.json", "editorial_questions.json"]

PREFIX = re.compile(
    r"^(Di gotûbêja dersê de|Di nirxandina xwendekaran de|Di çarçoveya dersê de)"
    r",\s*"
)
# Kategori çerçevesi: hem gövdenin başında hem ortasında geçiyor.
FIELD_PREFIX = re.compile(r"^di qada [^ ]+ de,?\s*", re.IGNORECASE)
FIELD_INLINE = re.compile(r"\b(di|li) qada [^ ]+( de)?\s*", re.IGNORECASE)


def strip_prefix(prompt: str) -> str:
    stripped = PREFIX.sub("", prompt)
    if stripped != prompt:
        return stripped[0].upper() + stripped[1:] if stripped else prompt

    stripped = FIELD_PREFIX.sub("", prompt)
    if stripped != prompt:
        return stripped[0].upper() + stripped[1:] if stripped else prompt

    stripped = FIELD_INLINE.sub("", prompt)
    if stripped != prompt:
        return re.sub(r"\s{2,}", " ", stripped).strip()
    return prompt


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def display_index(question) -> int:
    """`QuizQuestion.displayAnswers`in Python karşılığı."""
    answers = question["answers"]
    size = len(answers)
    seed = sum(ord(c) for c in question["id"])
    offset = seed % size or 1
    rotated = answers[offset:] + answers[:offset]
    return rotated.index(question["correctAnswer"])


def set_display_index(question, target: int) -> None:
    """Doğru cevabı, görünen konumu [target] olacak şekilde yeniden dizer."""
    answers = question["answers"]
    size = len(answers)
    seed = sum(ord(c) for c in question["id"])
    offset = seed % size or 1
    raw = (target + offset) % size
    others = [a for a in answers if a != question["correctAnswer"]]
    question["answers"] = others[:raw] + [question["correctAnswer"]] + others[raw:]


def rebalance(bank) -> int:
    """Doğru cevabın A/B/C/D dağılımını yayılım <= 1 olacak hâle getirir."""
    quads = [q for q in bank if len(q["answers"]) == 4]
    counts = [0, 0, 0, 0]
    for question in quads:
        counts[display_index(question)] += 1

    moved = 0
    while max(counts) - min(counts) > 1:
        source = counts.index(max(counts))
        target = counts.index(min(counts))
        victim = next(q for q in quads if display_index(q) == source)
        set_display_index(victim, target)
        counts[source] -= 1
        counts[target] += 1
        moved += 1
    return moved


def main() -> None:
    banks = {
        name: json.loads((ROOT / name).read_text(encoding="utf-8")) for name in BANKS
    }

    stripped = 0
    for bank in banks.values():
        for question in bank:
            new_prompt = strip_prefix(question["prompt"])
            if new_prompt != question["prompt"]:
                question["prompt"] = new_prompt
                question["_had_prefix"] = True
                stripped += 1

    # Tekilleştirme: önekli olmayan asıl kayıt tutulur.
    groups = defaultdict(list)
    for bank in banks.values():
        for question in bank:
            key = (
                question["category"],
                normalize(question["prompt"]),
                normalize(question["correctAnswer"]),
            )
            groups[key].append(question)

    drop = set()
    for members in groups.values():
        if len(members) < 2:
            continue
        members.sort(key=lambda q: (q.get("_had_prefix", False), q["id"]))
        for extra in members[1:]:
            drop.add(extra["id"])

    kept_banks = {}
    for name, bank in banks.items():
        kept = [q for q in bank if q["id"] not in drop]
        for question in kept:
            question.pop("_had_prefix", None)
        kept_banks[name] = kept

    moved = rebalance(kept_banks["offline_questions.json"])

    for name, kept in kept_banks.items():
        (ROOT / name).write_text(
            json.dumps(kept, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )

    print(
        f"{stripped} önek silindi, {len(drop)} kopya soru atıldı, "
        f"{moved} soruda doğru cevabın harfi dengelendi."
    )


if __name__ == "__main__":
    main()
