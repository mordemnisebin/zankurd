#!/usr/bin/env python3
"""Kalan yedi soruda doğru cevabın biçimle ele vermesini bitirir.

`fix_length_leak_distractors.py` bankadaki 103 soruyu aynı kategoriden
ödünç cevaplarla düzeltmişti; oran %34,3'ten %29,7'ye indi. Geriye,
otomatik ödünç almanın çözemediği yedi soru kaldı: havuzda aynı biçim ve
uzunlukta yeterli aday yoktu.

Bunlar elle yazıldı. İki ayrı kusur var ve ikisi de aynı yerde görünür:

1. **Biçim.** Doğru şık bir gerekçe/tanım cümlesiyken çeldiriciler iki
   kelimeydi ("Ji ber ku hêdîtir in"). Oyuncu gerekçe arar; tek gerekçe
   biçimli şık zaten doğru olandır. Çeldiriciler aynı boyda gerekçelere
   çevrildi — hepsi makul, hepsi yanlış.

2. **Eğik çizgi.** İki soruda doğru cevap iki eşanlamlıyı birden
   taşıyordu ("Kolin / Çal", "uzun hava / türkü"). Bu, şıkkı tek başına
   diğerlerinin iki katı uzunlukta yapıyordu; üstelik açıklama zaten
   ikinci karşılığı söylüyor. Tek kelimeye indirildi.

Bir soru ayrıca içerik olarak bozuktu: `offline_curated_21446` "kîjan
têgeh" (hangi terim) diye soruyup cevap olarak bir grup adı bekliyordu,
üstelik gövde "Di nirxandina xwendekaran de" gibi anlamsız bir dolgu ile
başlıyordu — makine üretimi bir kalıntı. Gövde sadeleştirildi; bankanın
kendi iddiası (Koma Wetan = ilk Kürt rock grubu) değiştirilmedi, yalnız
soruluş biçimi düzeltildi.

Bekçiler (`question_distractor_quality_test`, `all_banks_quality_test`)
yeni şıkları da denetler: aynı dil, aynı tarih-biçimi, yinelenmeyen ve
gövdede geçmeyen şıklar.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets/data"

# id -> (yeni gövde | None, yeni şıklar, yeni doğru cevap, eski ham dizin)
#
# Şık sırası önemli: doğru cevabın **ham dizini** eskisiyle aynı kalmalı.
# `displayAnswers` şıkları id'den türeyen sabit bir kaydırmayla döndürür,
# yani ham dizin görünen harfi (A/B/C/D) belirler ve bankanın tamamında
# doğru cevabın harflere dağılımı bir bekçiyle dengede tutulur
# (`question_bank_test`: yayılım en fazla 1). İlk yazımda şıkları
# okunaklı sırayla dizmek o dengeyi bozdu ve bekçi haklı olarak kırıldı.
PATCHES = {
    "offline_curated_21446": (
        "Koma Wetan di muzîka kurdî de bi çi tê nasîn?",
        [
            "Koma yekem a muzîka klasîk a kurdî",
            "Korek a stranên dînî yên kurdî",
            "Koma yekem a muzîka jazz a kurdî",
            "Koma yekem a muzîka rock a kurdî",
        ],
        "Koma yekem a muzîka rock a kurdî",
        3,
    ),
    "offline_curated_30011": (
        None,
        [
            "Depoya daneyan (DB)",
            "Hêmana dîtbarî (UI)",
            "Girêdana torê (net)",
            "Rêbaza hesabê (algorîtma)",
        ],
        "Hêmana dîtbarî (UI)",
        1,
    ),
    "offline_curated_30029": (
        None,
        ["Kolin", "Dîwar", "Dar", "Rê"],
        "Kolin",
        0,
    ),
    "offline_tek_0009": (
        None,
        [
            "Ji ber ku sînyal li hewayê belav dibe û herkes dikare bigire",
            "Ji ber ku girêdanên bêqablo her tim hêdîtir dixebitin",
            "Ji ber ku amûrên bêqablo kêmtir enerjiyê xerc dikin",
            "Ji ber ku qabloyên wan ji yên din kurttir tên çêkirin",
        ],
        "Ji ber ku sînyal li hewayê belav dibe û herkes dikare bigire",
        0,
    ),
    "offline_tek_0015": (
        None,
        [
            "Ji ber ku şîfreyên dirêj hêsantir tên bîranîn û parastin",
            "Ji ber ku şîfreyên dirêj di bîrê de kêmtir cih digirin",
            "Ji ber ku şîfreyên dirêj girêdana torê lezdar dikin",
            "Ji ber ku hejmara kombînasyonan bi dirêjiyê re bi lez zêde dibe",
        ],
        "Ji ber ku hejmara kombînasyonan bi dirêjiyê re bi lez zêde dibe",
        3,
    ),
    "edit_muzik_0016": (
        None,
        [
            "Dengbêjeke jin a navdar a sedsala 20em",
            "Nivîskareke romanên dîrokî yên sedsala 20em",
            "Damezrînera kovareke edebî ya Stenbolê",
            "Lêdera yekem a jin a tembûrê li Amedê",
        ],
        "Dengbêjeke jin a navdar a sedsala 20em",
        0,
    ),
    "edit_muzik_0026": (
        None,
        ["türkü", "dans", "saz", "düğün"],
        "türkü",
        0,
    ),
}


def main() -> None:
    patched = 0
    for name in ("offline_questions.json", "editorial_questions.json"):
        path = ROOT / name
        bank = json.loads(path.read_text(encoding="utf-8"))
        for question in bank:
            patch = PATCHES.get(question["id"])
            if patch is None:
                continue
            prompt, answers, correct, raw_index = patch
            assert correct in answers, question["id"]
            assert len(set(answers)) == len(answers), question["id"]
            others = [a for a in answers if a != correct]
            assert len(correct) <= 1.2 * max(len(a) for a in others), question["id"]
            # Ham dizin değişirse doğru cevabın görünen harfi değişir ve
            # bankanın A/B/C/D dengesi bozulur.
            assert answers.index(correct) == raw_index, question["id"]
            assert question["answers"].index(question["correctAnswer"]) == raw_index, (
                question["id"]
            )
            if prompt is not None:
                question["prompt"] = prompt
            question["answers"] = answers
            question["correctAnswer"] = correct
            patched += 1
        path.write_text(
            json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
    print(f"{patched}/{len(PATCHES)} soru düzeltildi.")


if __name__ == "__main__":
    main()
