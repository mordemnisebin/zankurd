#!/usr/bin/env python3
"""Uzunluk sızıntısı olan sorularda çeldiricileri biçime uydurur.

Ölçüm (2026-07-27): 1910 çok şıklı sorunun %34,3'ünde **en uzun şık doğru
şıktı**; rastgele bir bankada bu oran %25 olmalı. Yani hiçbir şey
bilmeyen bir oyuncu "en uzunu seç" diyerek dokuz puan kazanıyordu.

Sebep uzunluk değil biçim: 108 soruda doğru şık bir tanım cümlesiyken
çeldiriciler tarih, yer ya da kişi adıydı —

    'Qazi Muhammed' çi îfade dike?
      ✓ serokkomarê Komara Kurd a Mehabadê   (34)
        Birca Avê                             (9)
        Mesud Barzani                        (13)

Oyuncu tanımı arıyor; tek tanım biçimli şık zaten doğru olan. Bu, bilgi
değil biçim ölçmektir.

Düzeltme: uyumsuz çeldiriciler, **aynı kategorideki başka soruların doğru
cevaplarıyla** değiştirilir. Onlar da tanım biçimlidir ve benzer
uzunluktadır; böylece dört şık aynı biçimde görünür. Ödünç alınan metin
başka bir kavramı anlattığı için bu soruda yanlıştır.

Güvenlik: değiştirilen şık asla gövdede geçmez, doğru cevapla aynı olmaz
ve kendini yinelemez. Bankanın bekçileri (`all_banks_quality_test`,
`question_distractor_quality_test`) bu kuralları zaten doğruluyor;
betiğin çıktısı onlarla sınanır.
"""
import json
import random
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets/data"
BANKS = ["offline_questions.json", "editorial_questions.json"]

# Doğru şık, en uzun çeldiricinin bu katından uzunsa "biçim sızıntısı" sayılır.
LEAK_RATIO = 1.5
MIN_LENGTH = 12


def normalize(text: str) -> str:
    return " ".join(text.lower().split())


# `QuestionLanguagePolicy.detectLanguage`in Python karşılığı.
#
# Ödünç alınan çeldirici, doğru cevapla **aynı dilde** olmalı: yoksa
# "yabancı dilde çeldirici" bekçisi haklı olarak kırılır ve daha kötüsü,
# oyuncu dil farkından cevabı ayırt eder. Bu yüzden aynı sınıflandırıcı
# burada da uygulanır — bekçiyle aynı ölçüt, aynı sonuç.
_KU_WORDS = {
    "di", "bi", "ku", "ji", "li", "ye", "ne", "wê", "tê", "çi", "yê", "de",
    "her", "bo", "yek", "ew", "ev", "bû", "dike", "nav", "navê", "kîjan",
    "çend", "were", "hat", "hatiye", "xwe", "wek", "jî", "peyva", "wateya",
}
_TR_WORDS = {
    "ve", "bir", "ile", "için", "olan", "bu", "şu", "daha", "olarak", "kim",
    "hangi", "nedir", "kimdir", "yılında", "tarafından", "sonra", "göre",
    "eden", "edilen", "yapılan", "olduğu", "değil", "gibi", "veya", "olur",
}
_KU_CHARS = set("îûê")
_TR_CHARS = set("ğıöü")


# `question_distractor_quality_test` içindeki `_yearLike` ile aynı ölçüt.
#
# O bekçi, tarih içeren doğru cevabın yanına tarih içermeyen çeldirici
# konmasını yasaklar (ve tersini): "1946" ile bir tanım cümlesi yan yana
# durunca hangisinin aranan tür olduğu bakar bakmaz belli olur. Ödünç
# alınan çeldirici bu bakımdan da doğru cevaba benzemeli.
_YEAR_LIKE = re.compile(r"(\b\d{3,4}\b|yüzyıl|sedsal|y\.y\.|m\.ö|b\.z\.)", re.I)


def is_year_like(text: str) -> bool:
    return bool(_YEAR_LIKE.search(text))


def detect_language(text: str):
    lower = text.lower()
    words = set(re.findall(r"[a-zçêğıîöşûü']+", lower))
    ku = float(len(words & _KU_WORDS))
    tr = float(len(words & _TR_WORDS))
    for ch in lower:
        if ch in _KU_CHARS:
            ku += 0.34
        if ch in _TR_CHARS:
            tr += 0.34
    if ku == 0 and tr == 0:
        return None
    if ku >= tr * 1.5:
        return "ku"
    if tr >= ku * 1.5:
        return "tr"
    return None


def main() -> None:
    banks = {name: json.loads((ROOT / name).read_text(encoding="utf-8")) for name in BANKS}
    everything = [q for bank in banks.values() for q in bank]

    # Kategori başına tanım biçimli cevap havuzu: başka soruların doğru
    # cevapları. Yalnız yeterince uzun olanlar (kısa adlar havuza girmez).
    pool = defaultdict(list)
    for q in everything:
        answer = q["correctAnswer"]
        if len(answer) >= MIN_LENGTH:
            pool[q["category"]].append(answer)

    rng = random.Random(20260727)
    fixed = 0
    replaced = 0

    for bank in banks.values():
        for q in bank:
            answers = q["answers"]
            correct = q["correctAnswer"]
            if len(answers) < 3 or len(correct) < MIN_LENGTH:
                continue
            others = [a for a in answers if a != correct]
            if not others:
                continue
            if len(correct) <= LEAK_RATIO * max(len(a) for a in others):
                continue

            prompt_norm = normalize(q["prompt"])
            used = {normalize(a) for a in answers}
            target_language = detect_language(correct)
            target_year_like = is_year_like(correct)
            seen_candidates = set()
            candidates = []
            for c in pool[q["category"]]:
                key = normalize(c)
                # Havuzda aynı metin birden çok soruda geçebilir; iki kez
                # seçilirse şıklar yinelenir.
                if key in used or key in seen_candidates:
                    continue
                if key in prompt_norm:
                    continue
                if not (0.6 * len(correct) <= len(c) <= 1.4 * len(correct)):
                    continue
                if detect_language(c) != target_language:
                    continue
                if is_year_like(c) != target_year_like:
                    continue
                seen_candidates.add(key)
                candidates.append(c)
            if len(candidates) < len(others):
                continue

            rng.shuffle(candidates)
            new_answers = []
            picked = iter(candidates)
            for a in answers:
                if a == correct:
                    new_answers.append(a)
                    continue
                replacement = next(picked)
                used.add(normalize(replacement))
                new_answers.append(replacement)
                replaced += 1

            q["answers"] = new_answers
            fixed += 1

    for name, bank in banks.items():
        (ROOT / name).write_text(
            json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
    print(f"{fixed} soruda {replaced} çeldirici biçime uyduruldu.")


if __name__ == "__main__":
    main()
