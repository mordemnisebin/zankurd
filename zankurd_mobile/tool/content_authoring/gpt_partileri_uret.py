#!/usr/bin/env python3
"""Soru bankasını sohbet ekranına yapıştırılabilir partilere böler.

## Niçin dosya yükleme değil, yapıştırma

Yüklenen dosyayı modeller çoğu zaman bir sanal ortamda Python'la işler:
sayar, örnekler, greple arar. Bu iş için işe yaramaz — 3214 sorunun her
birinin OKUNMASI gerekiyor. Sohbet ekranına yapıştırılan metin modelin
bağlamına girer ve gerçekten okunur.

## Niçin riske göre sıralı

Tek oturumda 23 parti bitmez. Sıra rastgele olsaydı yarıda kalan iş
rastgele bir kesit bırakırdı. Sıralama şu ölçütlere göre kurulur:

1. `cross_check.py` hükmü OLMAYAN kayıtlar önce — bankanın %64'ü.
2. İçlerinde en eski bankalar önce; en yeni banka (deepseek) üretim
   boru hattının yapısal kapılarından geçti, eskiler geçmedi.

Böylece iş sekizinci partide durursa bile en riskli 1200 kayıt
denetlenmiş olur.

## Niçin Türkçe ikiz yok

Türkçe ikizler payı iki katına çıkarıyor (306k → 171k token) ve parti
sayısını 23'ten 41'e taşıyordu. Asıl sorulan şey şıkların kalitesi;
o Kurmancî kayıttan görülür. Türkçe çeviri kayması ayrı ve daha düşük
öncelikli bir denetimdir.
"""
import json
import pathlib
import re
import sys

# Parti SORU SAYISINA değil KARAKTER BÜTÇESİNE göre bölünür.
#
# Sabit soru sayısıyla (140) partiler 22k ile 62k karakter arasında
# değişti: soru uzunlukları çok farklı. 62k'lık bir parti sohbet
# ekranına yapıştırılamaz — kutu onu dosyaya çevirir ve dosya yüklemek
# bu işi tam da kaçınmak istediğimiz yere götürür (model dosyayı okumak
# yerine Python'la işler). Bütçeye göre bölünce her parti aynı boyda.
# Varsayılan 22k: başlıkla birlikte ~24.5k karakter eder. Sohbet
# kutuları belli bir uzunluktan sonra yapıştırılanı DOSYAYA çevirir ve
# dosya yüklemek bu işi tam da kaçınmak istediğimiz yere götürür.
# Kutu yine de dosyaya çeviriyorsa komuta küçük bir sayı ver:
#   python3 tool/content_authoring/gpt_partileri_uret.py 12000
#
# `tek` verilirse bölme yapılmaz, hepsi tek dosyaya yazılır. Bağlam
# penceresi yeten bir modelde bütün bankayı bir arada görmek daha
# iyidir: "tekrar" kusuru ancak iki soru AYNI bağlamdayken bulunur,
# partilere bölünce parti sınırını aşan tekrarlar görünmez kalır.
BUDGET = (10**9 if (len(sys.argv) > 1 and sys.argv[1] == "tek")
          else int(sys.argv[1]) if len(sys.argv) > 1 else 22_000)
SINGLE = len(sys.argv) > 1 and sys.argv[1] == "tek"
OUT = pathlib.Path("docs/content_batches/gpt_partileri")

BASLIK = """Aşağıda bir Kurmancî bilgi yarışması uygulamasının soru bankasından
{n} soru var. Görevin bunların KALİTESİNİ denetlemek.

Her soru için şu kusurları ara. Parantezdekiler çıktıda kullanacağın
kodlardır; başka kod uydurma.

1. yanlis_anahtar     — ✓ ile işaretli cevap gerçekte yanlış.
2. birden_fazla_dogru — birden çok şık savunulabilir biçimde doğru.
3. mugla              — soru tek bir doğru cevaba işaret etmiyor;
                        tarih, kapsam ya da ölçüt belirsiz.
4. uydurma_olgu       — sorunun DAYANDIĞI önerme yanlış: olmayan bir
                        ödül, olmayan bir yayın, yanlış atfedilmiş eser.
                        Şıklardan bağımsız; soru kökünün kendisi yalan.
5. celdirici_sacma    — yanlış şıklar ciddiye alınamayacak kadar
                        alakasız; soru okunmadan bilinir.
6. cevap_sizdiran     — doğru şık biçimiyle kendini ele veriyor: tek
                        başına farklı kalıpta, tek başına ayrıntılı, ya
                        da soru kökündeki bir kelimeyi tekrar ediyor.
7. kategori_yanlis    — soru bulunduğu kategoriye ait değil.
8. dil_hatasi         — Kurmancî metinde Hawar alfabesi dışı harf
                        (ı, ğ, ö, ü, İ), ya da şıklar Kurmancî yerine
                        Türkçe yazılmış.
9. tekrar             — bu partideki başka bir soruyla aynı olgu.

ÇIKTI: yalnız JSON dizisi, başka hiçbir şey yazma.

[{{"id":"...","kusur":["mugla"],"not":"niçin kusurlu, somut","oneri":"düzeltme"}}]

Kurallar:
- Kusursuz bulduğun soruyu YAZMA. Liste yalnız bulgulardır.
- `not` somut olsun. "Kalitesiz", "geliştirilmeli" işe yaramaz —
  hangi şıkkın niçin sorunlu olduğunu söyle.
- Emin değilsen yazma. Şişirilmiş liste gerçek kusurları görünmez kılar.
- Sonuna şunu ekle: {{"_okunan": <bu partide incelediğin soru sayısı>}}

SORULAR:

"""


def main() -> int:
    manifest = pathlib.Path("lib/src/data/question_bank_assets.dart").read_text(
        encoding="utf-8")
    assets = re.findall(r"'(assets/data/[^']+\.json)'", manifest)
    checked = set(json.loads(
        pathlib.Path("docs/content_batches/capraz_kontrol.json").read_text(
            encoding="utf-8")))

    rows = []
    for order, asset in enumerate(assets):
        path = pathlib.Path(asset)
        if not path.exists():
            continue
        for question in json.loads(path.read_text(encoding="utf-8")):
            rows.append((question["id"] not in checked, order, question))

    # Denetimsizler önce; içlerinde manifest sırası (eskiden yeniye).
    rows.sort(key=lambda r: (not r[0], r[1]))

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.txt"):
        old.unlink()
    single = OUT / "TUM_SORULAR.txt"
    if single.exists():
        single.unlink()

    def render(question):
        answers = question.get("answers") or []
        letters = " ".join(
            f"{chr(65 + i)}) {a}" for i, a in enumerate(answers))
        return (f"[{question['id']}] {question.get('category', '?')}\n"
                f"S: {question['prompt']}\n"
                f"{letters}\n"
                f"✓ {question.get('correctAnswer', '')}\n")

    batches, current, size = [], [], 0
    for _, _, question in rows:
        block = render(question)
        if current and size + len(block) > BUDGET:
            batches.append(current)
            current, size = [], 0
        current.append(block)
        size += len(block)
    if current:
        batches.append(current)

    written = 0
    counts = []
    for number, chunk in enumerate(batches, start=1):
        body = BASLIK.format(n=len(chunk)) + "\n".join(chunk)
        name = "TUM_SORULAR.txt" if SINGLE else f"parti_{number:02d}.txt"
        (OUT / name).write_text(body, encoding="utf-8")
        counts.append(len(chunk))
        written += 1

    sizes = [len(p.read_text(encoding="utf-8")) for p in OUT.glob("*.txt")]
    unchecked = sum(1 for r in rows if r[0])
    # Denetimsizler başta olduğu için kaçıncı partide bittiklerini say.
    seen, boundary = 0, written
    for index, count in enumerate(counts, start=1):
        seen += count
        if seen >= unchecked:
            boundary = index
            break
    print(f"{len(rows)} soru -> {written} parti")
    print(f"parti: {min(counts)}-{max(counts)} soru, "
          f"{min(sizes):,}-{max(sizes):,} karakter")
    print(f"ilk {boundary} parti = çapraz kontrolü olmayan {unchecked} kayıt")
    print(f"-> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
