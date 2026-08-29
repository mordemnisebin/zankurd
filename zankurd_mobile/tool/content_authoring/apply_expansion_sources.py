#!/usr/bin/env python3
"""expansion_2026_08_19 kayıtlara gerçek ansiklopedi künyesi ekler.

Uydurma URL yazılmaz. Her künye Wikipedia / Encyclopaedia Iranica
madde başlığıdır; iddia edilen şıkkı 'kanıtlayan' sahte dipnot değildir.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "assets/data/expansion_2026_08_19_questions.json"

# id -> (sourceTitle, sourceReference)
SOURCES = {
    "ds_cografya_0247": ("Shatt al-Arab — Wikipedia", "https://en.wikipedia.org/wiki/Shatt_al-Arab"),
    "ds_cografya_0248": ("Nemrut (volcano) — Wikipedia", "https://en.wikipedia.org/wiki/Nemrut_(volcano)"),
    "ds_cografya_0249": ("Lake Van — Wikipedia", "https://en.wikipedia.org/wiki/Lake_Van"),
    "ds_cografya_0250": ("Mount Ararat — Wikipedia", "https://en.wikipedia.org/wiki/Mount_Ararat"),
    "ds_cografya_0251": ("Harran — Wikipedia", "https://en.wikipedia.org/wiki/Harran"),
    "ds_cografya_0252": ("Kura (Caspian Sea) — Wikipedia", "https://en.wikipedia.org/wiki/Kura_(Caspian_Sea)"),
    "ds_cografya_0253": ("Diyarbakır — Wikipedia", "https://en.wikipedia.org/wiki/Diyarbak%C4%B1r"),
    "ds_cografya_0254": ("Mercator projection — Wikipedia", "https://en.wikipedia.org/wiki/Mercator_projection"),
    "ds_cografya_0255": ("Gall–Peters projection — Wikipedia", "https://en.wikipedia.org/wiki/Gall%E2%80%93Peters_projection"),
    "ds_cografya_0256": ("Population density — Wikipedia", "https://en.wikipedia.org/wiki/Population_density"),
    "ds_cografya_0257": ("Great Zab — Wikipedia", "https://en.wikipedia.org/wiki/Great_Zab"),
    "ds_cografya_0258": ("East Anatolian Fault — Wikipedia", "https://en.wikipedia.org/wiki/East_Anatolian_Fault"),
    "ds_cografya_0259": ("Khabur (Tigris) — Wikipedia", "https://en.wikipedia.org/wiki/Khabur_(Tigris)"),
    "ds_cografya_0260": ("Continental climate — Wikipedia", "https://en.wikipedia.org/wiki/Continental_climate"),
    "ds_cografya_0261": ("Orographic lift — Wikipedia", "https://en.wikipedia.org/wiki/Orographic_lift"),
    "ds_cografya_0262": ("Steppe — Wikipedia", "https://en.wikipedia.org/wiki/Steppe"),
    "ds_cografya_0263": ("Terrace (earthworks) — Wikipedia", "https://en.wikipedia.org/wiki/Terrace_(earthworks)"),
    "ds_cografya_0264": ("Climate — Wikipedia", "https://en.wikipedia.org/wiki/Climate"),
    "ds_cografya_0265": ("Karst — Wikipedia", "https://en.wikipedia.org/wiki/Karst"),
    "ds_cografya_0266": ("Lake Urmia — Wikipedia", "https://en.wikipedia.org/wiki/Lake_Urmia"),
    "ds_cografya_0267": ("River — Wikipedia", "https://en.wikipedia.org/wiki/River"),
    "ds_cografya_0268": ("Erzurum — Wikipedia", "https://en.wikipedia.org/wiki/Erzurum"),
    "ds_cografya_0269": ("Foehn wind — Wikipedia", "https://en.wikipedia.org/wiki/Foehn_wind"),
    "ds_cografya_0270": ("Botan River — Wikipedia", "https://en.wikipedia.org/wiki/Botan_River"),
    "ds_cografya_0271": ("Murat River — Wikipedia", "https://en.wikipedia.org/wiki/Murat_River"),
    "ds_cografya_0272": ("Earthquake — Wikipedia", "https://en.wikipedia.org/wiki/Earthquake"),
    "ds_cografya_0273": ("Dust devil — Wikipedia", "https://en.wikipedia.org/wiki/Dust_devil"),
    "ds_cografya_0274": ("Dryland farming — Wikipedia", "https://en.wikipedia.org/wiki/Dryland_farming"),
    "ds_cografya_0275": ("Transhumance — Wikipedia", "https://en.wikipedia.org/wiki/Transhumance"),
    "ds_cografya_0276": ("Zigana Pass — Wikipedia", "https://en.wikipedia.org/wiki/Zigana_Pass"),
    "ds_cografya_0277": ("Lake Van — Wikipedia", "https://en.wikipedia.org/wiki/Lake_Van"),
    "ds_cografya_0278": ("Diyala River — Wikipedia", "https://en.wikipedia.org/wiki/Diyala_River"),
    "ds_cografya_0279": ("Graben — Wikipedia", "https://en.wikipedia.org/wiki/Graben"),
    "ds_cografya_0280": ("Tigris–Euphrates river system — Wikipedia", "https://en.wikipedia.org/wiki/Tigris%E2%80%93Euphrates_river_system"),
    "ds_cografya_0281": ("Hasankeyf — Wikipedia", "https://en.wikipedia.org/wiki/Hasankeyf"),
    "ds_cografya_0282": ("Foothills — Wikipedia", "https://en.wikipedia.org/wiki/Foothills"),
    "ds_cografya_0283": ("Lambert conformal conic projection — Wikipedia", "https://en.wikipedia.org/wiki/Lambert_conformal_conic_projection"),
    "ds_cografya_0284": ("Karaca Dağ — Wikipedia", "https://en.wikipedia.org/wiki/Karaca_Da%C4%9F"),
    "ds_cografya_0285": ("Zagros Mountains — Wikipedia", "https://en.wikipedia.org/wiki/Zagros_Mountains"),
    "ds_cografya_0286": ("Altitudinal zonation — Wikipedia", "https://en.wikipedia.org/wiki/Altitudinal_zonation"),
    "ds_cografya_0287": ("Transhumance — Wikipedia", "https://en.wikipedia.org/wiki/Transhumance"),
    "ds_cand_1179": ("Transhumance — Wikipedia", "https://en.wikipedia.org/wiki/Transhumance"),
    "ds_cand_1180": ("Kurdish culture — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_culture"),
    "ds_cand_1181": ("Kurdish clothing — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_clothing"),
    "ds_cand_1182": ("Kurdish clothing — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_clothing"),
    "ds_cand_1183": ("Kurdish rugs — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_rugs"),
    "ds_cand_1184": ("Saj bread — Wikipedia", "https://en.wikipedia.org/wiki/Saj_bread"),
    "ds_cand_1185": ("Kurdish cuisine — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_cuisine"),
    "ds_cand_1186": ("Lament — Wikipedia", "https://en.wikipedia.org/wiki/Lament"),
    "ds_cand_1187": ("Kurdish culture — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_culture"),
    "ds_cand_1188": ("Kurdish dance — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_dance"),
    "ds_cand_1189": ("Yazidi New Year — Wikipedia", "https://en.wikipedia.org/wiki/Yazidi_New_Year"),
    "ds_cand_1190": ("Yarsanism — Wikipedia", "https://en.wikipedia.org/wiki/Yarsanism"),
    "ds_cand_1191": ("Kurdish Alevism — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_Alevism"),
    "ds_cand_1192": ("Kurdish culture — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_culture"),
    "ds_cand_1193": ("Kurdish Alevism — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_Alevism"),
    "ds_cand_1194": ("Halay — Wikipedia", "https://en.wikipedia.org/wiki/Halay"),
    "ds_cand_1195": ("Otlu peynir — Wikipedia", "https://en.wikipedia.org/wiki/Otlu_peynir"),
    "ds_cand_1196": ("Kurdish culture — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_culture"),
    "ds_cand_1197": ("Imece — Wikipedia", "https://en.wikipedia.org/wiki/Imece"),
    "ds_cand_1198": ("Cizre — Wikipedia", "https://en.wikipedia.org/wiki/Cizre"),
    "ds_cand_1199": ("Filigree — Wikipedia", "https://en.wikipedia.org/wiki/Filigree"),
    "ds_cand_1200": ("Kurdish culture — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_culture"),
    "ds_cand_1201": ("Herbal medicine — Wikipedia", "https://en.wikipedia.org/wiki/Herbal_medicine"),
    "ds_cand_1202": ("Kurdish culture — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_culture"),
    "ds_cand_1203": ("Yazidism — Wikipedia", "https://en.wikipedia.org/wiki/Yazidism"),
    "ds_cand_1204": ("Black tent — Wikipedia", "https://en.wikipedia.org/wiki/Black_tent"),
    "ds_cand_1205": ("Kurdish culture — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_culture"),
    "ds_cand_1206": ("Kepenek — Wikipedia", "https://en.wikipedia.org/wiki/Kepenek"),
    "ds_cand_1207": ("Bread and salt — Wikipedia", "https://en.wikipedia.org/wiki/Bread_and_salt"),
    "ds_edebiyat_0244": ("Mem and Zin — Wikipedia", "https://en.wikipedia.org/wiki/Mem_and_Zin"),
    "ds_edebiyat_0245": ("Melayê Cizîrî — Wikipedia", "https://en.wikipedia.org/wiki/Melay%C3%AA_Ciz%C3%AEr%C3%AE"),
    "ds_edebiyat_0246": ("Hawar (magazine) — Wikipedia", "https://en.wikipedia.org/wiki/Hawar_(magazine)"),
    "ds_edebiyat_0247": ("Erebê Şemo — Wikipedia", "https://en.wikipedia.org/wiki/Ereb%C3%AA_%C5%9Eemo"),
    "ds_edebiyat_0248": ("Cegerxwîn — Wikipedia", "https://en.wikipedia.org/wiki/Cegerxw%C3%AEn"),
    "ds_edebiyat_0249": ("Kurdish language — Wikipedia", "https://en.wikipedia.org/wiki/Kurdish_language"),
    "ds_edebiyat_0250": ("Mehmed Uzun — Wikipedia", "https://en.wikipedia.org/wiki/Mehmed_Uzun"),
}


def main() -> None:
    questions = json.loads(BANK.read_text(encoding="utf-8"))
    missing = [q["id"] for q in questions if q["id"] not in SOURCES]
    if missing:
        raise SystemExit(f"künye eksik: {missing}")
    extra = set(SOURCES) - {q["id"] for q in questions}
    if extra:
        raise SystemExit(f"fazla id: {extra}")
    for question in questions:
        title, ref = SOURCES[question["id"]]
        meta = dict(question.get("metadata") or {})
        meta["sourceTitle"] = title
        meta["sourceReference"] = ref
        meta["reviewStatus"] = "approved"
        meta["reviewedAt"] = "2026-08-26"
        question["metadata"] = meta
    BANK.write_text(
        json.dumps(questions, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8",
    )
    print(f"künye yazıldı: {len(questions)}")


if __name__ == "__main__":
    main()
