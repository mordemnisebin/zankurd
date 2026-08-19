#!/usr/bin/env python3
"""Soruları cevap anahtarını GÖSTERMEDEN modele sorar ve karşılaştırır.

## Niçin bu yöntem

Uygulama yayına çıkıyor; artık en pahalı şey yanlış soru. Ama 1240 sorunun
her iddiasını kaynağından tek tek doğrulamak mümkün değil.

Bunun yerine ucuz ve güçlü bir sinyal kullanılır: modele soru ÇIPLAK
sorulur — dört şık var, doğru olanı seç. Kendi yazdığı anahtarla çelişirse
o soru şüphelidir. Çelişki tek başına "yanlış" demek değildir (soru muğlak
olabilir, iki şık da doğru olabilir) ama insan denetimi gereken KÜÇÜK kümeyi
belirler.

Anahtar bilerek gösterilmez: gösterilseydi model neredeyse her zaman
onaylardı — kendi çıktısını savunma eğilimi ölçümü değersizleştirir.

Kullanım:
  python3 tool/content_authoring/cross_check.py banka.json rapor.json
"""
import json
import pathlib
import sys
import time
import urllib.request

API = "https://api.deepseek.com/chat/completions"
AUTH = pathlib.Path.home() / ".local/share/opencode/auth.json"
CHUNK = 15

TALIMAT = """Aşağıdaki Kurmancî çoktan seçmeli soruları yanıtla.

- Her soru için yalnız doğru şıkkın harfini ver (A, B, C, D).
- Emin değilsen "?" yaz. Tahmin etme.
- Yalnız JSON dizisi döndür, başka hiçbir şey yazma.

Bicim: [{"id":"...","cevap":"A"}]

Sorular:
"""


def api_key() -> str:
    data = json.loads(AUTH.read_text())
    entry = data.get("deepseek", {})
    return entry.get("key") or entry.get("apiKey")


def ask(payload: str, key: str) -> list:
    body = json.dumps({
        "model": "deepseek-chat",
        "messages": [{"role": "user", "content": payload}],
        "temperature": 0.0,
        "max_tokens": 2000,
    }).encode()
    request = urllib.request.Request(
        API, data=body,
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + key})
    with urllib.request.urlopen(request, timeout=180) as response:
        text = json.load(response)["choices"][0]["message"]["content"]
    start, end = text.find("["), text.rfind("]")
    if start < 0 or end <= start:
        return []
    try:
        return [x for x in json.loads(text[start:end + 1]) if isinstance(x, dict)]
    except json.JSONDecodeError:
        return []


def main(bank_path: str, out_path: str) -> int:
    questions = json.loads(pathlib.Path(bank_path).read_text(encoding="utf-8"))
    key = api_key()
    out = pathlib.Path(out_path)
    verdicts = {}
    if out.exists():
        verdicts = json.loads(out.read_text(encoding="utf-8"))
        print(str(len(verdicts)) + " soru zaten sorulmuş, kalanı sürüyor")

    pending = [q for q in questions if q["id"] not in verdicts]
    for index in range(0, len(pending), CHUNK):
        chunk = pending[index:index + CHUNK]
        payload = TALIMAT + json.dumps([
            {"id": q["id"], "soru": q["prompt"],
             "A": q["answers"][0], "B": q["answers"][1],
             "C": q["answers"][2], "D": q["answers"][3]}
            for q in chunk], ensure_ascii=False)
        answers = []
        for attempt in range(3):
            try:
                answers = ask(payload, key)
            except Exception as error:
                print("  hata: " + str(error)[:50])
            if answers:
                break
            time.sleep(4)
        # Harf DEĞİL, şıkkın METNİ saklanır. Harf kaydetmek bir tuzaktı:
        # `rebalance_answer_positions.py` şık sırasını değiştirdiğinde
        # kaydedilen harfler başka şıkları göstermeye başlıyor ve doğrulama
        # sessizce anlamsızlaşıyordu. Metin sıralamadan bağımsızdır.
        index_by_id = {q["id"]: q for q in chunk}
        for item in answers:
            qid = item.get("id")
            letter = str(item.get("cevap", "?")).strip().upper()[:1]
            if not qid or qid not in index_by_id:
                continue
            if letter in "ABCD" and letter:
                verdicts[qid] = index_by_id[qid]["answers"]["ABCD".index(letter)]
            else:
                verdicts[qid] = "?"
        # Modelin YANITINDA HİÇ GEÇMEYEN soru da "?" sayılır.
        #
        # Eskiden yalnız dönen kayıtlar yazılıyordu; model bir soruyu
        # atlarsa o soru hükümsüz kalıyor, `answer_key_consensus_test`
        # "çapraz doğrulamadan geçmemiş" diye düşüyor ve yeniden koşturmak
        # da çare olmuyordu — model aynı soruyu yine atlıyor. Bekçi böylece
        # kilitleniyordu (2026-08-19, ds_ziman_1260). Sorulmuş ama yanıt
        # alınamamış olmak zaten "?"nin tanımıdır.
        for question in chunk:
            verdicts.setdefault(question["id"], "?")
        out.write_text(json.dumps(verdicts, ensure_ascii=False, indent=1),
                       encoding="utf-8")
        if index % (CHUNK * 10) == 0:
            print("  " + str(len(verdicts)) + "/" + str(len(questions)), flush=True)

    agree = disagree = unsure = 0
    flagged = []
    for question in questions:
        given = verdicts.get(question["id"])
        if not given or given == "?":
            unsure += 1
            continue
        correct = question["correctAnswer"]
        if given == correct:
            agree += 1
        else:
            disagree += 1
            flagged.append(question["id"])

    print("\nuyuşan: %d   çelişen: %d   emin değil: %d" % (agree, disagree, unsure))
    print("çelişki oranı: %%%.1f" % (100 * disagree / max(agree + disagree, 1)))
    pathlib.Path("docs/content_batches/celiskiler.json").write_text(
        json.dumps(flagged, ensure_ascii=False, indent=1), encoding="utf-8")
    print("çelişen id'ler -> docs/content_batches/celiskiler.json")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
