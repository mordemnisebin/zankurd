#!/usr/bin/env python3
"""Başka bir ajanın şık kalitesi bulgularını DENETLER.

## Niçin bu araç var

2026-08-19'da aynı depoda bir ajana 191 kayıtlık bir "zorluk ve gerekçe
iyileştirmesi" verildi. Dönen iş kusursuz görünüyordu; gerçekte yalnız
`difficulty` alanı değişmişti ve değer, kategori sayacının 3'e bölümünden
üretilmişti — soru metinlerine hiç dokunulmamıştı. Aynı gün bir çapraz
kontrol dosyası, doğru cevabı kendi kendine "onaylayan" bir satırla
bozuldu ve 55 hüküm çöpe gitti.

İkisinin de ortak noktası: ajanın RAPORU doğruydu, İŞİ değildi. Bu araç
raporu hiç okumaz; dönen bulguları bankanın kendisiyle karşılaştırır.

## Neyi denetler

1. **Kimlik gerçekliği** — her `id` bankada var mı.
2. **Kod geçerliliği** — `kusur` kapalı listeden mi.
3. **İçerik tutarlılığı** — bulgunun iddiası kayda uyuyor mu (ör.
   `ayni_sik` diyorsa şıklarda gerçekten tekrar var mı).
4. **Kontrol kümesi** — `sik_kalite_taramasi.py` makineyle bulunan ve
   GÖZDEN KAÇMASI imkânsız kusurları biliyor (birebir aynı iki şık,
   doğru cevabın şıklarda hiç olmaması). Ajana bu liste VERİLMEZ. Dönen
   bulgular bunların hiçbirini içermiyorsa ajan kayıtları okumamıştır.
5. **Şablon kokusu** — notlar birbirinin kopyasıysa iş üretilmiş değil,
   doldurulmuştur.
"""
import json
import pathlib
import re
import sys
import unicodedata
from collections import Counter

GECERLI_KUSURLAR = {
    "yanlis_anahtar", "birden_fazla_dogru", "mugla", "uydurma_olgu",
    "celdirici_sacma", "cevap_sizdiran", "kategori_yanlis", "dil_hatasi",
    "tekrar",
}


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKD", (text or "").casefold())
    return re.sub(r"[^\w]+", " ", text).strip()


def load_bank() -> dict:
    manifest = pathlib.Path("lib/src/data/question_bank_assets.dart").read_text(
        encoding="utf-8")
    bank = {}
    for asset in re.findall(r"'(assets/data/[^']+\.json)'", manifest):
        path = pathlib.Path(asset)
        if not path.exists():
            continue
        for question in json.loads(path.read_text(encoding="utf-8")):
            bank[question["id"]] = question
    return bank


def control_set() -> set:
    """Gözden kaçması imkânsız kusurlar — ajana verilmez, dönüşü sınar."""
    path = pathlib.Path("docs/content_batches/sik_kalite_bulgulari.json")
    if not path.exists():
        return set()
    return {
        f["id"] for f in json.loads(path.read_text(encoding="utf-8"))
        if f["kusur"] in {"ayni_sik", "anahtar_yok"}
    }


def main() -> int:
    bank = load_bank()
    control = control_set()
    folder = pathlib.Path("docs/content_batches/spark_bulgular")
    if not folder.exists() or not any(folder.glob("*.json")):
        print("bulgu dosyası yok: " + str(folder))
        return 1

    findings, bad_id, bad_code, mismatch = [], [], [], []
    for file in sorted(folder.glob("*.json")):
        try:
            data = json.loads(file.read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            print(f"{file.name}: BOZUK JSON — {error}")
            return 1
        if not isinstance(data, list):
            print(f"{file.name}: dizi bekleniyordu")
            return 1
        findings.extend(data)

    for finding in findings:
        qid = finding.get("id")
        question = bank.get(qid)
        if question is None:
            bad_id.append(qid)
            continue
        kinds = finding.get("kusur") or []
        if isinstance(kinds, str):
            kinds = [kinds]
        unknown = [k for k in kinds if k not in GECERLI_KUSURLAR]
        if not kinds or unknown:
            bad_code.append((qid, unknown or "boş"))

        # İçerik tutarlılığı: iddia edilebilir olanları örnekle.
        answers = question.get("answers") or []
        if "ayni_sik" in kinds:
            normalized = [normalize(a) for a in answers]
            if len(set(normalized)) == len(normalized):
                mismatch.append((qid, "ayni_sik ama tekrar eden şık yok"))
        if "yanlis_anahtar" in kinds and question.get("correctAnswer") not in answers:
            mismatch.append((qid, "anahtar zaten şıklarda değil, farklı kusur"))

    ids = [f.get("id") for f in findings]
    duplicate_ids = [i for i, n in Counter(ids).items() if n > 1]
    notes = [(f.get("not") or "").strip() for f in findings]
    repeated_notes = [n for n, c in Counter(notes).items() if n and c > 2]

    caught = control & set(ids)
    print(f"bulgu: {len(findings)}   banka: {len(bank)} kayıt")
    print(f"  geçersiz kimlik      : {len(bad_id)}")
    print(f"  geçersiz kusur kodu  : {len(bad_code)}")
    print(f"  kayıtla çelişen iddia: {len(mismatch)}")
    print(f"  yinelenen kimlik     : {len(duplicate_ids)}")
    print(f"  şablon not           : {len(repeated_notes)} kalıp")
    if control:
        print(f"  kontrol kümesi       : {len(caught)}/{len(control)} yakalandı")

    for label, rows in (("geçersiz kimlik", bad_id[:5]),
                        ("geçersiz kod", bad_code[:5]),
                        ("çelişen iddia", mismatch[:5])):
        for row in rows:
            print(f"    {label}: {row}")

    print()
    problems = len(bad_id) + len(bad_code) + len(mismatch)
    if control and not caught:
        print("SONUÇ: GÜVENİLMEZ — makineyle bulunmuş, gözden kaçması")
        print("imkânsız kusurların hiçbiri dönmemiş. Kayıtlar okunmamış.")
        return 2
    if problems > max(3, len(findings) * 0.05):
        print("SONUÇ: GÜVENİLMEZ — bulguların %5'inden fazlası bankayla")
        print("uyuşmuyor. Elden geçirmeden önce iş yeniden istenmeli.")
        return 2
    print("SONUÇ: elden geçirmeye uygun. Bulgular bankayla tutarlı;")
    print("kalanı insan kararıdır — bu araç doğruluğu değil, İŞİN")
    print("gerçekten yapıldığını denetler.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
