#!/usr/bin/env python3
"""Sorunun istediği türden olmayan şıkları düzeltir.

"Hangi dilde yazdı?" diye sorup şık olarak kitap adı vermek, soruyu
imkânsız değil **gereksiz** kılar: dil olmayan üç şık zaten elenir.

    Cigerxwîn berhemên xwe bi kîjan zimanî nivîsandiye?
      ✓ Kürtçe (Kurmancî)
        Dîwana xwe ya klasîk       ← kitap
        Siyabend û Xecê            ← destan
        dest jî rû dişo            ← atasözü

Üçü de "bi kîjan zimanî" soran sorulardı. İkisi eski makine havuzundan
kalma; üçüncüsü ise **bu denetimde bozuldu**: `edit_sinema_0026` elle
yazılmış, dört şıkkı da dil olan bir soruydu. Uzunluk sızıntısını
kapatan betik ("doğru cevap çeldiricilerin 1,5 katından uzun") onun
çeldiricilerini aynı kategoriden ödünç cevaplarla değiştirdi ve
"Neorealîzma Îtalî", "Birayên Lumière" gibi dil olmayan şıklar bıraktı.

Ödünç alma betiği dili, tarihi ve uzunluğu denetliyor ama **türü**
denetlemiyor — bir sorunun neyi sorduğunu bilmiyor. Bu, o yaklaşımın
sınırı: biçimi düzeltirken anlamı bozabiliyor. Bu yüzden bu üç soru elle
yazıldı ve doğru cevabın ham dizini korundu (A/B/C/D dengesi için).

`offline_2110` de aynı sınıftan: "Göbekli Tepe hangi şehrin yakınında?"
diye soruyor ama şıklarda bir mevsim ("zivistan / Berfanbar"), bir siyasi
parti ("YNK") ve bir şehir çifti ("Roma û Atîna") duruyordu. Tek gerçek
aday doğru cevaptı.

`offline_0080` ayrı bir kusur: resimdeki Kurmancî sözcüğün Türkçe
karşılığı soruluyor ama şıkların ikisi Kurmancî ("gel!", "heval").
Dört şık da Türkçe olmalı.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets/data"
BANKS = ["offline_questions.json", "editorial_questions.json"]

# id -> (şıklar, doğru cevap, korunacak ham dizin)
PATCHES = {
    "offline_2674": (
        [
            "Tirkî (bi devoka Stenbolê)",
            "Erebî (ya klasîk)",
            "Farisî (ya klasîk)",
            "Kurdî (Kurmancî)",
        ],
        "Kurdî (Kurmancî)",
        3,
    ),
    "offline_2699": (
        [
            "Swêdî (zimanê welatê sirgûnê)",
            "Erebî (ya klasîk)",
            "Farisî (ya klasîk)",
            "Kurdî (Kurmancî)",
        ],
        "Kurdî (Kurmancî)",
        3,
    ),
    "edit_sinema_0026": (
        [
            "Kurdî (Soranî û Kurmancî)",
            "Farisî (bi devoka herêmê)",
            "Erebî (bi devoka Iraqê)",
            "Tirkî (bi jêrnivîsa kurdî)",
        ],
        "Kurdî (Soranî û Kurmancî)",
        0,
    ),
    "offline_2110": (
        ["Riha", "Amed", "Mêrdîn", "Wan"],
        "Riha",
        0,
    ),
    "offline_0080": (
        ["Kitap", "küçük", "gel", "arkadaş"],
        "küçük",
        1,
    ),
}


def main() -> None:
    patched = 0
    for name in BANKS:
        path = ROOT / name
        bank = json.loads(path.read_text(encoding="utf-8"))
        for question in bank:
            patch = PATCHES.get(question["id"])
            if patch is None:
                continue
            answers, correct, raw_index = patch
            assert correct in answers, question["id"]
            assert len(set(answers)) == len(answers), question["id"]
            assert answers.index(correct) == raw_index, question["id"]
            assert (
                question["answers"].index(question["correctAnswer"]) == raw_index
            ), question["id"]
            question["answers"] = answers
            question["correctAnswer"] = correct
            patched += 1
        path.write_text(
            json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
    print(f"{patched}/{len(PATCHES)} soruda şıklar sorunun türüne uyduruldu.")


if __name__ == "__main__":
    main()
