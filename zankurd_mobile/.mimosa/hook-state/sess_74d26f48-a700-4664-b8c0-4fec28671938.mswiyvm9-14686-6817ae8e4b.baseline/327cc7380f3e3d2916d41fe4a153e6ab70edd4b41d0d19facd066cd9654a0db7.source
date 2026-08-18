#!/usr/bin/env python3
"""Yarı çevrilmiş terimleri düzeltir.

Kurmancî gövdelerin içinde Kürtçe ada Türkçe bir sözcük yapışmış terimler
duruyordu — makine çevirisinin yarıda bıraktığı yerler:

    'Memê Alan destanı' tê çi wateyê?          → destana Memê Alan
    'Behdînan bölgesi' di erdnîgariyê de …      → herêma Behdînan
    'zembîlfiroş stranı' çi îfade dike?         → strana Zembîlfiroş
    Têgiha 'dengbêj makamı' çi pêk tîne?        → makama dengbêjan
    … ji bo 'İhsan Nuri Paşa' kîjan rast e?     → Îhsan Nûrî Paşa

Üç soruda ise doğru cevabın kendisi Türkçe bir cümleydi ("Ehmedê
Xanî'nin Mem û Zîn'e ilham aldığı halk destanı"); Kurmancî şıkların
arasındaki tek Türkçe metin olduğu için soruyu okumaya bile gerek yoktu.
Harf tabanlı dil ölçütü bunu göremiyordu: cümle hem Kurmancî (ê, û, î)
hem Türkçe (ğ, ı) harf taşıdığı için "nötr" sayılıyordu.

Kurmancî okuyan biri için bunlar "biraz tuhaf" değil, doğrudan yanlış:
tamlama Kurmancîde ters kurulur (destana Memê Alan), Türkçe iyelik eki
(-ı, -sı) Kurmancîde yoktur ve İ harfi alfabede yer almaz.

Terimler yalnız gövdede değil şıklarda ve Kurmancî açıklamada da
geçiyor; değişiklik o alanlara uygulanır ki aynı kavram iki ayrı adla
görünmesin. **Türkçe açıklama dışarıda bırakılır** — orada "Memê Alan
destanı" zaten doğru Türkçedir. İlk yazımda değişiklik sorunun tamamına
uygulanmış ve Türkçe açıklamalar Kurmancîleşmişti; bankanın "Türkçe
arayüzde açıklama Kurmancî kalmıyor" mandalı bunu hemen yakaladı.

Bir gövde ayrıca belirsizdi: "Wateya 'ji kerema xwe' 'teşekkür ederim' e?"
İki tırnaklı ifade yan yana duruyor ama hangisinin hangi dilde olduğu
yazmıyordu. "bi Tirkî" eklenince hem soru netleşiyor hem de Türkçe
ifadenin niçin orada olduğu belli oluyor.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets/data"
BANKS = ["offline_questions.json", "editorial_questions.json"]

TERMS = {
    # Türkçe terim, Kurmancî gövdenin içinde. Üçüncüsü bir cümle: doğru
    # cevap olarak duruyordu ve tek Türkçe şık olduğu için soruyu okumadan
    # seçilebiliyordu (üç soru aynı cevabı paylaşıyordu).
    "birincil kaynak": "çavkaniya yekemîn",
    "ulus devlet": "dewleta netewe",
    "Ehmedê Xanî'nin Mem û Zîn'e ilham aldığı halk destanı": (
        "destana gelêrî ya ku Ehmedê Xanî jê îlham girt bo Mem û Zîn"
    ),
    "Memê Alan destanı": "destana Memê Alan",
    "Dewrêşê Evdî destanı": "destana Dewrêşê Evdî",
    "Behdînan bölgesi": "herêma Behdînan",
    "zembîlfiroş stranı": "strana Zembîlfiroş",
    "dengbêj makamı": "makama dengbêjan",
    "İhsan Nuri Paşa": "Îhsan Nûrî Paşa",
}


# Terim değişimi ilk yazımda `explanation` alanına da uygulanmış ve orada
# Türkçe iyelik ekiyle çakışmıştı: "Behdînan bölgesinin ünlü dengbêjidir"
# → "herêma Behdînannin ünlü dengbêjidir". Alan artık dokunulmuyor ama
# hasar kaldı; elle onarılıyor ve soruya iki dilli açıklama veriliyor.
EXPLANATION_PATCHES = {
    "offline_2201": {
        "explanation": "Kawîs Axa, Behdînan bölgesinin ünlü dengbêjidir.",
        "explanationTr": "Kawîs Axa, Behdînan bölgesinin ünlü dengbêjidir.",
        "explanationKu": "Kawîs Axa dengbêjekî navdar ê herêma Behdînan e.",
    },
}


PROMPT_PATCHES = {
    "offline_curated_30014": (
        "Wateya 'ji kerema xwe' bi Tirkî 'teşekkür ederim' e?"
    ),
}


def main() -> None:
    changed = 0
    for name in BANKS:
        path = ROOT / name
        raw = path.read_text(encoding="utf-8")
        bank = json.loads(raw)
        for question in bank:
            prompt = PROMPT_PATCHES.get(question["id"])
            if prompt is not None:
                question["prompt"] = prompt
                changed += 1

            fixes = EXPLANATION_PATCHES.get(question["id"])
            if fixes is not None:
                question.update(fixes)
                changed += 1

            touched = False
            for field in ("prompt", "correctAnswer", "explanationKu"):
                value = question.get(field)
                if not isinstance(value, str):
                    continue
                new_value = value
                for old, new in TERMS.items():
                    new_value = new_value.replace(old, new)
                if new_value != value:
                    question[field] = new_value
                    touched = True

            answers = question.get("answers")
            if isinstance(answers, list):
                new_answers = []
                for answer in answers:
                    new_answer = answer
                    for old, new in TERMS.items():
                        new_answer = new_answer.replace(old, new)
                    new_answers.append(new_answer)
                if new_answers != answers:
                    question["answers"] = new_answers
                    touched = True

            if touched:
                changed += 1
        path.write_text(
            json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
    print(f"{changed} soruda yarı çevrilmiş terim düzeltildi.")


if __name__ == "__main__":
    main()
