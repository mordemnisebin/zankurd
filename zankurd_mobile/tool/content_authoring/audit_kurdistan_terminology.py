#!/usr/bin/env python3
"""Kürdistan coğrafya/adlandırma sözleşmesi ve editoryal perspektif denetimi.

Niçin ayrı ve RAPORLAYICI bir araç
----------------------------------
Bu denetim toplu kelime değiştirme DEĞİLDİR ve olamaz. "Nusaybin → Nisêbîn"
gibi bir eşleme kâğıt üzerinde masum görünür, ama:

* kaynak künyesinde (`sourceTitle`, `sourceReference`) geçen resmî ad
  bibliyografik kayıttır; ideolojik sebeple değiştirilemez (§3.5);
* aynı dizge tarihsel bir alıntının içinde geçebilir;
* bazı bağlamlarda devlet adı gerçekten gereklidir (idari, uluslararası,
  tarihsel) — yasak olan, yerin TEK ve ana kimliği olarak sunulmasıdır.

Bu yüzden araç yalnız **kullanıcıya görünen** alanları tarar, hiçbir şeyi
değiştirmez ve her eşleşmeyi question ID ile insan incelemesine bırakır.
Karar `decision` alanına elle yazılır.

2026-08-06'da bu projede iki kez toplu regex ile içerik bozuldu; o yüzden
"raporla, dokunma" ayrımı burada bilinçli bir tasarım kararıdır.
"""
from __future__ import annotations
import argparse, json, re, sys, collections

# Yalnız oyuncunun gördüğü alanlar. metadata/sourceReference KASITLI dışarıda.
VISIBLE = ["prompt", "promptTr", "explanation", "explanationKu", "explanationTr"]
VISIBLE_LISTS = ["answers", "answersTr"]

PARTS = {
    "bakur": ["Amed", "Nisêbîn", "Mêrdîn", "Wan", "Cizîr", "Colemêrg", "Şirnex",
              "Dêrsim", "Agirî", "Bedlîs", "Mûş", "Riha", "Sêrt", "Batman",
              "Qers", "Îdir", "Erzirom", "Meletî"],
    "rojava": ["Qamişlo", "Kobanê", "Efrîn", "Dêrik", "Amûdê", "Serê Kaniyê",
               "Hesekê", "Tirbespiyê", "Girkê Legê", "Minbic"],
    "basur": ["Hewlêr", "Silêmanî", "Duhok", "Helebce", "Kerkûk", "Zaxo",
              "Ranya", "Qeladizê", "Soran", "Şengal"],
    "rojhilat": ["Mahabad", "Sine", "Kirmaşan", "Urmiye", "Seqiz", "Bokan",
                 "Merîwan", "Pîranşar", "Serdeşt", "Îlam"],
}
PART_STATE = {"bakur": "Türkiye", "rojava": "Suriye",
              "basur": "Irak", "rojhilat": "İran"}
PART_TERMS = re.compile(
    r"Bakur[êe]?\s*(?:y[êe])?\s*Kurdistan|Rojava|Ba[sş][ûu]r[êe]?\s*(?:y[êe])?\s*Kurdistan"
    r"|Rojhilat[êe]?\s*(?:y[êe])?\s*Kurdistan|Kurdistan|Kürdistan", re.I)

# Kürtçe endonim yerine kullanılan devlet/uluslararası adlar.
EXONYMS = {
    "Nusaybin": "Nisêbîn", "Kamışlı": "Qamişlo", "Qamishli": "Qamişlo",
    "Kamishli": "Qamişlo", "Diyarbakır": "Amed", "Diyarbakir": "Amed",
    "Kobani": "Kobanê", "Afrin": "Efrîn", "Erbil": "Hewlêr", "Irbil": "Hewlêr",
    "Sulaymaniyah": "Silêmanî", "Süleymaniye": "Silêmanî",
    "Sanandaj": "Sine", "Kermanshah": "Kirmaşan", "Urmia": "Urmiye",
    "Hakkari": "Colemêrg", "Şırnak": "Şirnex", "Tunceli": "Dêrsim",
    "Mardin": "Mêrdîn", "Şanlıurfa": "Riha", "Urfa": "Riha", "Siirt": "Sêrt",
    "Bitlis": "Bedlîs", "Ağrı": "Agirî", "Muş": "Mûş",
    "Kars": "Qers", "Iğdır": "Îdir", "Erzurum": "Erzirom", "Malatya": "Meletî",
    "Cizre": "Cizîr", "Halabja": "Helebce", "Kirkuk": "Kerkûk",
    "Zakho": "Zaxo", "Sinjar": "Şengal", "Ras al-Ayn": "Serê Kaniyê",
    "Manbij": "Minbic", "Hasakah": "Hesekê", "Mahabat": "Mahabad",
}
STATES = re.compile(r"\b(Türkiye|Turkey|Suriye|Syria|Irak|Iraq|İran|Iran)\b", re.I)

# Ülke/devlet cevabına zorlayan soru kalıbı (§3.4).
COUNTRY_Q = re.compile(
    r"hangi\s+(ülke|devlet|ülkenin|devletin)|hangi\s+ülkede|ülkeye\s+bağlı"
    r"|kîjan\s+(welat|dewlet)|li\s+kîjan\s+welat", re.I)

# §4 — editoryal perspektif riskleri. Hepsi İNCELEME işaretidir, otomatik red değil.
PERSPECTIVE = {
    "denialist": re.compile(
        r"Kürt(ç|ce)\s*diye\s*bir\s*dil\s*yok|sözde\s*Kürt|güya\s*Kürt"
        r"|Kürtler\s*asl[ıi]nda\s*Türk|dağ\s*Türk", re.I),
    "assimilationist": re.compile(
        r"asimilasyon\s*(doğal|kaçınılmaz|olumlu|gerekli)"
        r"|tek\s*dil\s*tek\s*millet|medeni?le[şs]tirme", re.I),
    "criminalizing": re.compile(
        r"(Kürt|Kurd)\w*\s*(terör|terörist|bölücü|eşkıya|haydut)"
        r"|terör\s*örgütü\s*mensubu\s*Kürt", re.I),
    "misogynist": re.compile(
        r"kadın(lar)?\s*(zayıf|akılsız|eve\s*ait|erkeğe\s*bağlı)"
        r"|kadının\s*yeri\s*ev", re.I),
    "eco_normalizing": re.compile(
        r"baraj\w*\s*(sadece|yalnızca)\s*kalkınma|kalkınma\s*için\s*gerekli\s*(göç|yıkım)",
        re.I),
    "hateful": re.compile(
        r"\b(hepsi|tüm)\s+(Kürtler|Türkler|Araplar|Farslar)\s+\w*(kötü|hain|düşman)"
        r"|\w+\s*halkı\s*yok\s*edilmeli", re.I),
}

# Siyasileştirilmeyecek alanlar (§4.2).
NONPOLITICAL = {"Matematîk", "Fîzîk", "Kîmya", "Bîolojî", "Tenduristî",
                "Teknolojî", "Sînema", "Muzîk", "Ziman", "Mantiq"}

CITY_TO_PART = {c: p for p, cs in PARTS.items() for c in cs}


def visible_text(q):
    parts = [str(q.get(f) or "") for f in VISIBLE]
    for f in VISIBLE_LISTS:
        v = q.get(f)
        if isinstance(v, list):
            parts += [str(x) for x in v]
    return "\n".join(parts)


def ku_text(q):
    return "\n".join([str(q.get("prompt") or ""), str(q.get("explanationKu") or "")]
                     + [str(x) for x in (q.get("answers") or [])])


def tr_text(q):
    return "\n".join([str(q.get("promptTr") or ""), str(q.get("explanationTr") or "")]
                     + [str(x) for x in (q.get("answersTr") or [])])


def audit_one(q):
    """(classes, findings) — otomatik değişiklik YOK."""
    text = visible_text(q)
    classes, notes = set(), []

    cities = sorted({c for c in CITY_TO_PART if re.search(rf"\b{re.escape(c)}\b", text)})
    exos = sorted({e for e in EXONYMS if re.search(rf"\b{re.escape(e)}\b", text)})
    has_part = bool(PART_TERMS.search(text))
    has_state = bool(STATES.search(text))

    if cities or exos:
        if COUNTRY_Q.search(str(q.get("promptTr") or "") + " " + str(q.get("prompt") or "")):
            classes.add("POLITICAL_STATUS_QUESTION_REJECTED")
            notes.append(f"ülke/devlet cevabına zorluyor: {cities or exos}")
        if has_state and not has_part:
            classes.add("REGION_FRAME_REWRITE")
            notes.append(f"yalnız devlet çerçevesi: {cities or exos}")
        mapped = [e for e in exos if EXONYMS.get(e)]
        if mapped:
            classes.add("KURDISH_ENDONYM_REWRITE")
            notes.append("exonim: " + ", ".join(
                f"{e}->{EXONYMS[e]}" for e in mapped))
        # iki dilli çerçeve tutarlılığı (§3.6)
        if bool(PART_TERMS.search(ku_text(q))) != bool(PART_TERMS.search(tr_text(q))):
            classes.add("REGION_FRAME_REWRITE")
            notes.append("KU/TR coğrafi çerçeve farklı")

    for name, rx in PERSPECTIVE.items():
        m = rx.search(text)
        if m:
            if name in ("denialist",):
                classes.add("REJECTED_DENIALIST_FRAME")
            elif name in ("hateful",):
                classes.add("REJECTED_HATEFUL_FRAME")
            else:
                classes.add("FREEDOM_MOVEMENT_PERSPECTIVE_REVIEW")
            notes.append(f"{name}: '{m.group(0)[:60]}'")

    if not classes:
        classes.add("NOT_APPLICABLE_NONPOLITICAL_CONTENT"
                    if q.get("category") in NONPOLITICAL and not cities
                    else "TERMINOLOGY_OK")
    return sorted(classes), notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--manifest")
    a = ap.parse_args()

    tally, rows = collections.Counter(), []
    for path in a.paths:
        data = json.load(open(path, encoding="utf-8"))
        if not isinstance(data, list):
            print(f"atlandı (liste değil): {path}")
            continue
        for q in data:
            # Bazı asset'ler soru değil yardımcı veri tutar; sessizce
            # çökmek yerine atla ki denetim bütün bankaları tarayabilsin.
            if not isinstance(q, dict):
                continue
            classes, notes = audit_one(q)
            for c in classes:
                tally[c] += 1
            if classes != ["TERMINOLOGY_OK"] and classes != [
                    "NOT_APPLICABLE_NONPOLITICAL_CONTENT"]:
                rows.append({
                    "questionId": q.get("id"), "sourceFile": path,
                    "category": q.get("category"), "classes": classes,
                    "findings": notes,
                    "oldPromptKu": q.get("prompt"), "newPromptKu": None,
                    "oldPromptTr": q.get("promptTr"), "newPromptTr": None,
                    "oldExplanationKu": q.get("explanationKu"), "newExplanationKu": None,
                    "oldExplanationTr": q.get("explanationTr"), "newExplanationTr": None,
                    "decision": None, "reason": None, "supportingSource": None,
                    "reviewer": None, "timestamp": None,
                })

    for k, v in sorted(tally.items(), key=lambda x: -x[1]):
        print(f"{k:44s} {v}")
    print(f"\nincelenecek kayıt: {len(rows)}")
    if a.manifest:
        json.dump(rows, open(a.manifest, "w", encoding="utf-8"),
                  ensure_ascii=False, indent=2)
        print("manifest:", a.manifest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
