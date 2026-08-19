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
4. **Kapsam** — ajan her banka için kaç kayıt okuduğunu beyan eder;
   beyan bankanın gerçek boyutuyla karşılaştırılır. En sağlam sinyal
   budur çünkü örnek büyüklüğünden bağımsızdır: 1155 kayıtlık bir
   dosya için "909 okudum" demek, işin eksik olduğunun tartışmasız
   kanıtıdır. İlk koşumda Spark tam olarak bunu yaptı (2026-08-19).

5. **Kontrol kümesi** — makineyle bulunmuş, dikkatli bir okumada
   kaçırılması zor kusurlar. Ajana verilmez.

   Bu ölçüt YUMUŞAK tutulur ve tek başına iş reddettirmez. İlk sürümde
   sertti ve dürüst bir dönüşü haksız yere reddetti: kontrol kümesi
   `ayni_sik` bulgularından kuruluydu, o bulguların üçü de taramanın
   kendi normalleştirme kusurundan doğan sahte bulgulardı (`V = I × R`
   ile `V = I ÷ R` aynı sayılıyordu). Ajan onları bildirmemekte
   haklıydı; araç yine de "kayıtlar okunmamış" dedi. Bir denetçinin
   kendi ölçütü yanlışsa, denetçisizlikten kötüdür.
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
    """Kaçırılması zor kusurlar — ajana verilmez, dönüşü sınar.

    Yalnız NESNEL olarak doğrulanabilir sınıflar kullanılır: iki kaydın
    aynı soruyu sorması, doğru cevabın şıklarda hiç bulunmaması. Öznel
    sınıflar (uzunluk/biçim sızması) buraya girmez — onlar eşik
    meselesidir ve bir ajanın farklı karar vermesi kusur değildir.
    """
    path = pathlib.Path("docs/content_batches/sik_kalite_bulgulari.json")
    if not path.exists():
        return set()
    ids = set()
    for finding in json.loads(path.read_text(encoding="utf-8")):
        if finding["kusur"] not in {"tekrar_soru", "anahtar_yok", "ayni_sik"}:
            continue
        ids.add(finding["id"])
        # `tekrar_soru` eşin ikinci kimliğini ayrıntıya yazar; ajan
        # çiftin hangi ucunu bildirdiyse sayılmalı.
        ids.update(re.findall(r"\b[a-z_]+_\d{3,4}\b", finding["ayrinti"]))
    return ids


def coverage(folder: pathlib.Path) -> list:
    """Beyan edilen okuma sayısını gerçekle karşılaştırır.

    İki akış var ve ikisi de desteklenir:

    * **Banka akışı** (dosya erişimi olan ajan) — `_ozet.json` içinde
      banka başına `okunan_kayit`.
    * **Parti akışı** (sohbet ekranına yapıştırma) — her parti dönüşünün
      sonundaki `{"_okunan": N}`, o partinin soru sayısıyla karşılaştırılır.

    Parti akışı daha sıkıdır: kapsam banka başına değil parti başına
    ölçülür, dolayısıyla eksik okuma nerede olduğu belli olur.
    """
    rows = []

    summary = folder / "_ozet.json"
    if summary.exists():
        for entry in json.loads(summary.read_text(encoding="utf-8")):
            asset = pathlib.Path("assets/data") / entry.get("banka", "")
            actual = (len(json.loads(asset.read_text(encoding="utf-8")))
                      if asset.exists() else None)
            rows.append((entry.get("banka"), actual, entry.get("okunan_kayit")))

    batches = pathlib.Path("docs/content_batches/gpt_partileri")
    for file in sorted(folder.glob("parti_*.json")):
        source = batches / (file.stem + ".txt")
        if not source.exists():
            rows.append((file.stem, None, None))
            continue
        # Partideki soru sayısı: satır başındaki [kimlik] etiketleri.
        # Başlıktaki JSON örneği de `[` ile başlar; kimlik deseni
        # tırnak içermediği için o satır eşleşmez.
        actual = len(re.findall(r"^\[([A-Za-z0-9_\-]+)\]", 
                                source.read_text(encoding="utf-8"), re.M))
        declared = None
        for item in json.loads(file.read_text(encoding="utf-8")):
            if isinstance(item, dict) and "_okunan" in item:
                declared = item["_okunan"]
        rows.append((file.stem, actual, declared))
    return rows


def main() -> int:
    bank = load_bank()
    control = control_set()
    folder = pathlib.Path(
        sys.argv[1] if len(sys.argv) > 1
        else "docs/content_batches/spark_bulgular")
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
        # `{"_okunan": N}` bir bulgu değil, kapsam beyanıdır.
        findings.extend(
            x for x in data if not (isinstance(x, dict) and "_okunan" in x))

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
    cov = coverage(folder)
    gaps = [(name, actual, read) for name, actual, read in cov
            if actual is None or read is None or read != actual]

    print(f"bulgu: {len(findings)}   banka: {len(bank)} kayıt")
    print(f"  geçersiz kimlik      : {len(bad_id)}")
    print(f"  geçersiz kusur kodu  : {len(bad_code)}")
    print(f"  kayıtla çelişen iddia: {len(mismatch)}")
    print(f"  yinelenen kimlik     : {len(duplicate_ids)}")
    print(f"  şablon not           : {len(repeated_notes)} kalıp")
    if control:
        print(f"  kontrol kümesi       : {len(caught)}/{len(control)} yakalandı")
    if not cov:
        print("  kapsam beyanı        : YOK (_ozet.json yazılmamış)")
    else:
        print(f"  kapsam açığı         : {len(gaps)}/{len(cov)} banka")
        for name, actual, read in gaps[:6]:
            print(f"    {name}: beyan {read}, gerçek {actual}")

    for label, rows in (("geçersiz kimlik", bad_id[:5]),
                        ("geçersiz kod", bad_code[:5]),
                        ("çelişen iddia", mismatch[:5])):
        for row in rows:
            print(f"    {label}: {row}")

    print()
    problems = len(bad_id) + len(bad_code) + len(mismatch)
    if not cov:
        print("SONUÇ: EKSİK — kapsam beyanı yok. Bulgular tutarlı olabilir")
        print("ama işin bankanın TAMAMINI kapsadığı doğrulanamıyor.")
        return 3
    if gaps:
        print("SONUÇ: EKSİK — beyan edilen okuma bankanın boyutunu")
        print("tutmuyor. Bulgular geçerli olabilir; iş yarım.")
        return 3
    if problems > max(3, len(findings) * 0.05):
        print("SONUÇ: GÜVENİLMEZ — bulguların %5'inden fazlası bankayla")
        print("uyuşmuyor. Elden geçirmeden önce iş yeniden istenmeli.")
        return 2
    if control and not caught:
        print("UYARI: kaçırılması zor kusurların hiçbiri dönmemiş.")
        print("Tek başına ret sebebi değil — ölçüt küçük ve yanılabilir —")
        print("ama elden geçirirken derinliği sorgula.\n")
    print("SONUÇ: elden geçirmeye uygun. Bulgular bankayla tutarlı;")
    print("kalanı insan kararıdır — bu araç doğruluğu değil, İŞİN")
    print("gerçekten yapıldığını denetler.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
