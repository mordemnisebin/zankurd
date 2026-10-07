#!/usr/bin/env python3
"""Çapraz kontrol için KÖR parti üretir — anahtarı GÖSTERMEDEN.

## Niçin bu araç

`cross_check.py` aynı işi yapıyordu ama DeepSeek API'sine bağlıydı ve
kredi bitti (HTTP 402). Bankanın %62'si (1810 soru) hiçbir anahtar
denetiminden geçmemiş durumda ve bu, uygulamanın en pahalı kusur
sınıfının önündeki tek kapı.

Çözüm sağlayıcı değiştirmek değil, işi KOŞUYA taşımak: bulut koşusunun
kendisi zaten bir dil modeli oturumu. Ona soruyu çıplak verip cevabını
almak, DeepSeek'e sormakla aynı sinyali üretir.

## Niçin anahtar gizleniyor

Gösterilseydi model neredeyse her zaman onaylardı — kendi çıktısını
savunma eğilimi ölçümü değersizleştirir. Bu dosya `correctAnswer` alanını
partiye HİÇ yazmaz; doğrulama ayrı bir adımda, `kor_cevap_karsilastir.py`
ile yapılır.

## Niçin şıklar yeniden karıştırılmıyor

Karıştırmak cazip ama yanlış: model harf değil METİN döndürüyor ve
karşılaştırma metinle yapılıyor. Sıra bozulursa hiçbir şey bozulmaz ama
kazanılan bir şey de yok — buna karşılık partiyi üreten ile
karşılaştıran arasında bir tutarsızlık riski doğar. Sıra bankadaki gibi
bırakılır.
"""
import json
import pathlib
import re
import sys

BUDGET = 40_000
OUT = pathlib.Path("docs/content_batches/kor_partiler")
HUKUM = pathlib.Path("docs/content_batches/capraz_kontrol.json")

BASLIK = """Aşağıda {n} çoktan seçmeli soru var. Her biri için DOĞRU şıkkı seç.

- Yalnız JSON dizisi döndür, başka hiçbir şey yazma.
- Biçim: [{{"id":"...","cevap":"<şıkkın TAM METNİ>"}}]
- Cevabı şıklardan birinin metnini AYNEN kopyalayarak yaz; harf yazma.
- Emin değilsen "?" yaz. Tahmin etme — emin olmadığını söylemek,
  yanlış bir kesinlikten daha değerli.

Sorular Kurmancî. Doğru cevap sana GÖSTERİLMİYOR; bu kasıtlı.
Gösterilseydi kendi seçimini savunma eğilimi ölçümü değersizleştirirdi.

SORULAR:

"""


def main() -> int:
    manifest = pathlib.Path("lib/src/data/question_bank_assets.dart").read_text(
        encoding="utf-8")
    assets = re.findall(r"'(assets/data/[^']+\.json)'", manifest)

    checked = set()
    if HUKUM.exists():
        checked = set(json.loads(HUKUM.read_text(encoding="utf-8")))

    pending = []
    for index, asset in enumerate(assets):
        path = pathlib.Path(asset)
        if not path.exists():
            continue
        for question in json.loads(path.read_text(encoding="utf-8")):
            if question["id"] in checked:
                continue
            answers = question.get("answers") or []
            # Yazılı cevap ve sıralama soruları şık taşımaz; kör sorma
            # yöntemi onlara uygulanamaz.
            if question.get("type") in {"fillInBlank", "wordOrdering"}:
                continue
            if len(answers) < 2:
                continue
            pending.append((index, question))

    # En eski banka önce: `cross_check` hükmü olmayanların çoğu orada ve
    # üretim boru hattının yapısal kapılarından geçmemiş olanlar da.
    pending.sort(key=lambda row: row[0])

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.txt"):
        old.unlink()

    def render(question):
        lines = [f"[{question['id']}]", f"S: {question['prompt']}"]
        for i, answer in enumerate(question["answers"]):
            lines.append(f"  {chr(65 + i)}) {answer}")
        return "\n".join(lines) + "\n"

    batches, current, size = [], [], 0
    for _, question in pending:
        block = render(question)
        if current and size + len(block) > BUDGET:
            batches.append(current)
            current, size = [], 0
        current.append(block)
        size += len(block)
    if current:
        batches.append(current)

    for number, chunk in enumerate(batches, start=1):
        body = BASLIK.format(n=len(chunk)) + "\n".join(chunk)
        (OUT / f"kor_{number:02d}.txt").write_text(body, encoding="utf-8")

    print(f"hükmü olmayan soru: {len(pending)}")
    print(f"parti: {len(batches)}  (~{BUDGET // 1000}k karakter)")
    print(f"-> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
