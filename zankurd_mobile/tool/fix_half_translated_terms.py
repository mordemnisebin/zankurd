#!/usr/bin/env python3
"""Yarı çevrilmiş terimleri düzeltir.

Kurmancî gövdelerin içinde Kürtçe ada Türkçe bir sözcük yapışmış terimler
duruyordu — makine çevirisinin yarıda bıraktığı yerler:

    'Memê Alan destanı' tê çi wateyê?          → destana Memê Alan
    'Behdînan bölgesi' di erdnîgariyê de …      → herêma Behdînan
    'zembîlfiroş stranı' çi îfade dike?         → strana Zembîlfiroş
    Têgiha 'dengbêj makamı' çi pêk tîne?        → makama dengbêjan
    … ji bo 'İhsan Nuri Paşa' kîjan rast e?     → Îhsan Nûrî Paşa

Kurmancî okuyan biri için bunlar "biraz tuhaf" değil, doğrudan yanlış:
tamlama Kurmancîde ters kurulur (destana Memê Alan), Türkçe iyelik eki
(-ı, -sı) Kurmancîde yoktur ve İ harfi alfabede yer almaz.

Terimler yalnız gövdede değil şıklarda ve açıklamalarda da geçiyor;
değişiklik sorunun tamamına uygulanır ki aynı kavram iki ayrı adla
görünmesin.

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
    "Memê Alan destanı": "destana Memê Alan",
    "Dewrêşê Evdî destanı": "destana Dewrêşê Evdî",
    "Behdînan bölgesi": "herêma Behdînan",
    "zembîlfiroş stranı": "strana Zembîlfiroş",
    "dengbêj makamı": "makama dengbêjan",
    "İhsan Nuri Paşa": "Îhsan Nûrî Paşa",
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
            blob = json.dumps(question, ensure_ascii=False)
            replaced = blob
            for old, new in TERMS.items():
                replaced = replaced.replace(old, new)
            if replaced != blob:
                bank[bank.index(question)] = json.loads(replaced)
                changed += 1
        path.write_text(
            json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
    print(f"{changed} soruda yarı çevrilmiş terim düzeltildi.")


if __name__ == "__main__":
    main()
