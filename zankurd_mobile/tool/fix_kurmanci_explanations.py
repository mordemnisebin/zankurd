#!/usr/bin/env python3
"""Kurmancî açıklamalarına sızmış Türkçeyi temizler.

Kurmancî alfabesinde ı, ğ, ö, ü yoktur. Bu harfleri arayan bir tarama
(alıntı içindekiler hariç) `explanationKu` alanlarında beş kaçak buldu:

* `offline_0652` ve `offline_2520`: Kurmancî açıklama alanında **baştan
  sona Türkçe cümle** duruyordu — yani Kurmancî arayüzde soru Kurmancî,
  açıklaması Türkçeydi. `explanationTr` ile birebir aynı metindi, yani
  bir zamanlar Kurmancîsi hiç yazılmamış, Türkçesi kopyalanmıştı.
* `offline_tf_par_0019/0020/0021`: Kurmancî cümlenin ortasında "ölçüya"
  duruyordu; Kurmancîsi "pîvana" — üstelik cümle tam o kavramı ("pîvana
  azadiyê") tanımlıyordu. İkisinde gövdede, birinde açıklamada.
* `offline_curated_30016` ve `edit_ziman_0038`: Türkçe karşılıklar
  tırnaksız yazılmıştı ("ji bo günaydın an iyi günler"). Bankanın kendi
  kuralı bunları «» ya da "" içine alır; tırnaksız hâlde Kurmancî cümlenin
  parçasıymış gibi okunuyor.

Parantez içi karşılıklar (`dergehvan (kapıcı)`) bilinçli bir sözlük
biçimidir; onlara dokunulmaz.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "assets/data"

# id -> (yeni explanationKu | None, yeni explanationTr | None)
PATCHES = {
    "offline_0652": (
        "Peyva «çîrok» cureyekî vegotinê nîşan dide: bûyerên ku tên "
        "gotin an nivîsandin.",
        None,
    ),
    "offline_2520": (
        "Mela Ehmedê Xasî bi nivîsandina yek ji mewlûdên kirmanckî "
        "(zazakî) yên pêşîn tê nasîn.",
        None,
    ),
    "offline_tf_par_0021": (
        "Na — ev ravekirina «zayenda civakî» e; «pîvana azadiyê» tê vê "
        "wateyê: pîvana ku azadiya civakê bi azadiya jinê tê nirxandin.",
        None,
    ),
    "offline_curated_30016": (
        "«Rojbaş» ji bo «günaydın» an «iyi günler» tê bikaranîn.",
        None,
    ),
    "edit_ziman_0038": (
        '"Spas" bi Tirkî "teşekkür" e; "spas dikim" = "teşekkür ederim".',
        None,
    ),
}


# id -> yeni gövde
PROMPT_PATCHES = {
    "offline_tf_par_0019": (
        "Têgeha «civaka bêhiyerarşî» wiha tê ravekirin: pîvana ku azadiya "
        "civakê bi azadiya jinê tê nirxandin. Ev rast e an şaş e?"
    ),
    "offline_tf_par_0020": (
        "Binirxîne: li gorî vê ravekirinê «pîvana azadiyê» ev e — pîvana ku "
        "azadiya civakê bi azadiya jinê tê nirxandin. Rast e an şaş e?"
    ),
}


def main() -> None:
    patched = 0
    for name in ("offline_questions.json", "editorial_questions.json"):
        path = ROOT / name
        bank = json.loads(path.read_text(encoding="utf-8"))
        for question in bank:
            prompt = PROMPT_PATCHES.get(question["id"])
            if prompt is not None:
                question["prompt"] = prompt
                patched += 1
            patch = PATCHES.get(question["id"])
            if patch is None:
                continue
            ku, tr = patch
            question["explanationKu"] = ku
            if tr is not None:
                question["explanationTr"] = tr
            patched += 1
        path.write_text(
            json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
        )
    print(f"{patched}/{len(PATCHES) + len(PROMPT_PATCHES)} metin düzeltildi.")


if __name__ == "__main__":
    main()
