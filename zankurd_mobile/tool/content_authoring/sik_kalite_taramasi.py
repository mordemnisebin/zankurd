#!/usr/bin/env python3
"""Şık kalitesini MAKİNEYLE denetler — modele sormadan.

## Niçin ayrı bir tarama

`cross_check.py` modele soruyu çıplak sorar ve anahtarla karşılaştırır.
Güçlü bir sinyaldir ama yapısal bir körlüğü vardır: yalnız ŞIKKI denetler,
SORUYU denetlemez. Uydurma bir Nobel ödülü ya da uydurma bir UNESCO
kaydı, dört şıktan biri "doğru" olduğu sürece bu kontrolden temiz geçer.

Bu tarama tamamlayıcıdır ve modele hiç gitmez: bir sorunun saçma olduğunu
söylemek için yargı gerekir, ama bazı kusurlar SAYILABİLİR. Sayılabilenler
burada bulunur; kalanı modele bırakılır ve model bu listeyi GÖRMEZ —
listeyi görmemesi, dönüşünü denetlemek için kullanılır (bkz.
`spark_denetim.py`).

## Bulunan kusur sınıfları

* `ayni_sik`        — iki şık birebir ya da normalleştirilince aynı
* `uzunluk_sizmasi` — doğru şık diğerlerinden belirgin uzun/kısa
* `bicim_sizmasi`   — yalnız doğru şık sayı/tarih taşıyor (ya da tersi)
* `sorulan_terim_sik` — gövdede tırnakla anılan terim şık olarak da var
* `sik_sayisi`      — dörtten az/çok şık
* `anahtar_yok`     — doğru cevap şıklar arasında değil
* `tekrar_soru`     — başka bir kayıtla neredeyse aynı soru metni
* `bos_alan`        — soru, şık ya da açıklama boş
"""
import json
import pathlib
import re
import sys
import unicodedata
from collections import Counter, defaultdict


def normalize_prompt(text: str) -> str:
    """Soru metni karşılaştırması için gevşek normalleştirme.

    Noktalama burada anlam taşımaz: "Newroz nedir?" ile "Newroz nedir"
    aynı sorudur.
    """
    text = unicodedata.normalize("NFKD", (text or "").casefold())
    return re.sub(r"[^\w]+", " ", text).strip()


def normalize_option(text: str) -> str:
    """Şık karşılaştırması için DAR normalleştirme — yalnız kasa ve boşluk.

    İlk sürüm burada da noktalamayı siliyordu ve üç sahte bulgu üretti:
    `V = I × R` ile `V = I ÷ R` ikisi birden `v i r` oluyor, `1` ile `-1`
    ikisi birden `1` oluyordu (2026-08-19). Bu şıklarda işaretin KENDİSİ
    anlamın tamamıdır; silmek şıkları eşitler.

    Kusur yalnız sahte bulgu üretmedi: bu üç kayıt "gözden kaçması
    imkânsız" sayılıp `spark_denetim.py`nin kontrol kümesine kondu ve
    araç, onları bildirmediği için DÜRÜST bir dönüşü "kayıtlar okunmamış"
    diye reddetti. Yanlış bir denetçi, denetçisizlikten kötüdür.
    """
    return " ".join((text or "").casefold().split())


def has_digit(text: str) -> bool:
    return any(ch.isdigit() for ch in text or "")


# Gövdede tırnak içinde anılan terim. Ölçüt `all_banks_quality_test.dart`
# içindeki kardeş bekçiyle BİREBİR aynı tutulur; iki bekçi aynı kusuru
# farklı ölçerse hangisinin haklı olduğu tartışılır, kusur durur.
QUOTED_TERM = re.compile(r"""[«'"]([^«»'"]{2,60})[»'"]""")


def scan(questions: list, source: str) -> list:
    findings = []

    def add(question, kind, detail):
        findings.append({
            "id": question.get("id", "?"),
            "banka": source,
            "kusur": kind,
            "ayrinti": detail,
            "soru": (question.get("prompt") or "")[:90],
        })

    by_prompt = defaultdict(list)
    for question in questions:
        prompt = question.get("prompt") or ""
        answers = question.get("answers") or []
        correct = question.get("correctAnswer") or ""

        if not prompt.strip() or not correct.strip():
            add(question, "bos_alan", "soru ya da doğru cevap boş")
            continue

        by_prompt[normalize_prompt(prompt)].append(question.get("id"))

        # Yazılı cevap ve sıralama soruları şık taşımaz; şık kuralları
        # onlara uygulanmaz, yoksa her biri sahte bulgu üretir.
        if question.get("type") in {"fillInBlank", "wordOrdering"}:
            continue

        # Doğru/yanlış soruları İKİ şıklıdır ve bu doğrudur.
        #
        # İlk koşumda dört şık kuralı onlara da uygulandı ve 555 sahte
        # bulgu üretti — bulguların %93'ü. Sayıca ezici bir sahte yığın,
        # gerçek 41 bulguyu görünmez kılar; "596 kusur bulundu" başlığı
        # da bankayı olduğundan çok daha kötü gösterir. Uzunluk ve biçim
        # kuralları da burada anlamsız: "Doğru"/"Yanlış" ikilisinde
        # uzunluk farkı ipucu değildir.
        if question.get("type") == "trueFalse":
            if len(answers) != 2:
                add(question, "sik_sayisi", f"doğru/yanlış sorusunda {len(answers)} şık")
            continue

        if len(answers) != 4:
            add(question, "sik_sayisi", f"{len(answers)} şık")
            continue

        # Sorulan terim şık olarak da duruyor.
        #
        # ## Kusur
        #
        # 2026-08-23'te `ds_sinema_0193` böyleydi: gövde «Moana» filmini
        # tırnak içinde anıyor, şıklardan biri de "Moana"ydı. Doğru cevap
        # sızmıyordu (cevap "Te Fiti"), ama şık kümesi eserin ADINI bir
        # KARAKTER gibi listeliyordu; okuyan kişi aynı sözcüğü iki ayrı
        # anlamda görüyordu.
        #
        # ## Niçin sessiz kaldı
        #
        # Kural aslında YAZILI: `test/all_banks_quality_test.dart` içinde
        # "hiçbir kaynakta sorulan terim şık olarak durmuyor" diye bir
        # bekçi var. Ama o bekçi bankaları elle sayılmış bir haritadan
        # okur ve `deepseek_2026_08_18_questions.json` o haritada YOKTUR
        # (bkz. iş listesi A9). Yani kural, 1110 soruluk banka için hiç
        # koşmadı. Bu tarama ise banka listesini
        # `question_bank_assets.dart` manifestosundan okur — yeni bir
        # banka eklendiğinde kendiliğinden kapsar. Kuralın burada da
        # durmasının sebebi budur: elle tutulan liste unutulur, manifesto
        # unutulmaz.
        terms = {m.group(1).strip().casefold()
                 for m in QUOTED_TERM.finditer(prompt)}
        if terms:
            for answer in answers:
                if answer.strip().casefold() in terms:
                    add(question, "sorulan_terim_sik",
                        f"gövdede anılan terim şık olarak da duruyor: {answer!r}")
                    break

        if correct not in answers:
            add(question, "anahtar_yok", f"doğru cevap şıklarda yok: {correct!r}")
            continue

        normalized = [normalize_option(a) for a in answers]
        duplicates = [t for t, n in Counter(normalized).items() if n > 1]
        if duplicates:
            add(question, "ayni_sik", f"tekrar eden şık: {duplicates[0]!r}")

        others = [a for a in answers if a != correct]
        if others:
            correct_len = len(correct)
            other_lens = [len(a) for a in others]
            longest_other = max(other_lens)
            shortest_other = min(other_lens)
            # Eşik deneysel: doğru şık en uzun çeldiriciden 1.6 kat uzunsa
            # ya da en kısasının yarısından kısaysa, oyuncu soruyu
            # okumadan da bilebilir.
            if correct_len > longest_other * 1.6 and correct_len - longest_other > 12:
                add(question, "uzunluk_sizmasi",
                    f"doğru {correct_len} krk, en uzun çeldirici {longest_other}")
            elif correct_len * 2 < shortest_other and shortest_other - correct_len > 12:
                add(question, "uzunluk_sizmasi",
                    f"doğru {correct_len} krk, en kısa çeldirici {shortest_other}")

            correct_digit = has_digit(correct)
            if correct_digit != any(has_digit(a) for a in others) and correct_digit != all(
                has_digit(a) for a in others
            ):
                if correct_digit and not any(has_digit(a) for a in others):
                    add(question, "bicim_sizmasi", "yalnız doğru şık sayı taşıyor")
                elif not correct_digit and all(has_digit(a) for a in others):
                    add(question, "bicim_sizmasi", "yalnız doğru şık sayısız")

    for key, ids in by_prompt.items():
        if len(ids) > 1 and key:
            findings.append({
                "id": ids[0], "banka": source, "kusur": "tekrar_soru",
                "ayrinti": f"aynı soru metni: {', '.join(str(i) for i in ids[1:])}",
                "soru": key[:90],
            })
    return findings


# Bekçi mandalı: bu sayının üstüne çıkan her koşu çıkış kodu 1 verir.
#
# ## Kusur
#
# 2026-08-22'ye kadar bu araç yalnız SAYIYOR, hiçbir şeyi bağlamıyordu.
# 22 sızma bulgusu üç ay boyunca `sik_kalite_bulgulari.json` içinde
# yazılı durdu ve kimse görmedi — çünkü araç 22 bulguyla da çıkış kodu 0
# veriyordu. Ne CI, ne `flutter test`, ne de başka bir bekçi bu dosyayı
# okuyor: bulgu üreten ama hüküm vermeyen bir denetçi, denetçisizlikle
# aynı şeydir.
#
# ## Niçin sessiz kaldı
#
# Kusurun kendisi de sessizdi. Sızmanın belirtisi yanlış bir cevap değil,
# fazla kolay bir sorudur: "yalnız doğru şık sayı taşıyor" ya da "doğru
# şık çeldiricilerden belirgin uzun" diyen bir soru oynanabilir, doğru
# anahtarlı ve iki dilde eksiksizdir. Bütün yapısal bekçiler onu
# onaylar; yalnız oyuncu, soruyu okumadan da bilir.
#
# Mandal yalnız İNDİRİLİR. Yeni bir sızmayı kapatmadan bu sayıyı
# yükseltmek, kusuru düzeltmek değil bekçiyi susturmaktır.
FINDING_RATCHET = 0


def main() -> int:
    manifest = pathlib.Path("lib/src/data/question_bank_assets.dart").read_text(
        encoding="utf-8")
    assets = re.findall(r"'(assets/data/[^']+\.json)'", manifest)

    all_findings = []
    for asset in assets:
        path = pathlib.Path(asset)
        if not path.exists():
            continue
        questions = json.loads(path.read_text(encoding="utf-8"))
        all_findings.extend(scan(questions, path.name))

    counts = Counter(f["kusur"] for f in all_findings)
    print(f"{len(all_findings)} bulgu\n")
    for kind, count in counts.most_common():
        print(f"  {kind:18} {count}")

    out = pathlib.Path("docs/content_batches/sik_kalite_bulgulari.json")
    out.write_text(json.dumps(all_findings, ensure_ascii=False, indent=1),
                   encoding="utf-8")
    print(f"\n-> {out}")

    if len(all_findings) > FINDING_RATCHET:
        print(f"\nMANDAL DÜŞTÜ: {len(all_findings)} bulgu > "
              f"{FINDING_RATCHET}. Sızan kayıtlar yukarıdaki dosyada.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
