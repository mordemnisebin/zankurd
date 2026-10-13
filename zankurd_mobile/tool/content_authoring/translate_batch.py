#!/usr/bin/env python3
"""Kurmancî soruların Türkçe ikizlerini üretir.

## Niçin ayrı aşama

Uygulama iki dilli: `prompt`/`promptTr`, `answers`/`answersTr`,
`explanationKu`/`explanationTr`. `bilingual_bank_integrity_test` Türkçe
alanların ya HEP birlikte ya hiç bulunmasını, `language_pool_parity_test`
ise her soru tipinin iki dilde de aynı genişlikte oynanabilmesini şart
koşuyor. Yani Kurmancî-only soru bankaya giremez.

Çeviri üretimden AYRI koşar: modelden aynı anda hem yeni bilgi üretmesini
hem çeviri yapmasını istemek ikisini birden bozuyordu. Çeviri ayrıca
kolay iş — model burada bilgi uydurmuyor, yalnız dil değiştiriyor.

Kullanım:
  python3 tool/content_authoring/translate_batch.py girdi.json çıktı.json
"""
import json
import pathlib
import sys
import time
import urllib.request

API = "https://api.deepseek.com/chat/completions"
AUTH = pathlib.Path.home() / ".local/share/opencode/auth.json"
CHUNK = 20

TALIMAT = """Aşağıdaki Kurmancî soruları Türkçeye çevir.

Kurallar:
- Yalnız JSON dizisi döndür; açıklama, kod çiti, giriş cümlesi YOK.
- Her kayıt için: id (aynen kopyala), promptTr, answersTr (dört eleman,
  sırası ORİJİNALLE AYNI), explanationTr.
- answersTr sırası bozulamaz: doğru cevap orijinalde kaçıncı sıradaysa
  çeviride de aynı sırada olmalı.
- Özel adları çevirme (Shakespeare, Newroz, Dîcle -> Dicle gibi Türkçede
  yerleşik karşılığı varsa onu kullan).
- Doğal Türkçe yaz; kelimesi kelimesine değil, anlamı aktar.

Biçim:
[{"id":"...","promptTr":"...","answersTr":["a","b","c","d"],"explanationTr":"..."}]

Sorular:
"""


def api_key() -> str:
    data = json.loads(AUTH.read_text())
    entry = data.get("deepseek", {})
    key = entry.get("key") or entry.get("apiKey")
    if not key:
        sys.exit("DeepSeek anahtarı bulunamadı")
    return key


def call(payload: str, key: str) -> str:
    body = json.dumps({
        "model": "deepseek-chat",
        "messages": [{"role": "user", "content": payload}],
        # Çeviride yaratıcılık istenmez: düşük sıcaklık sadık çeviri verir.
        "temperature": 0.2,
        "max_tokens": 8000,
    }).encode()
    request = urllib.request.Request(
        API, data=body,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"})
    # Asılı kalan tek istek bütün çeviriyi durduruyordu (20 dk ilerleme yok).
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.load(response)["choices"][0]["message"]["content"]


def parse(text: str) -> list[dict]:
    start, end = text.find("["), text.rfind("]")
    if start < 0 or end <= start:
        return []
    try:
        return [x for x in json.loads(text[start:end + 1]) if isinstance(x, dict)]
    except json.JSONDecodeError:
        return []


def main(src: str, dst: str) -> int:
    questions = json.loads(pathlib.Path(src).read_text(encoding="utf-8"))
    key = api_key()
    done: dict[str, dict] = {}

    out = pathlib.Path(dst)
    if out.exists():  # kaldığı yerden devam
        done = {q["id"]: q for q in json.loads(out.read_text(encoding="utf-8"))}
        print(f"{len(done)} kayıt zaten çevrilmiş, kalanı sürüyor")

    pending = [q for q in questions if q["id"] not in done]
    for index in range(0, len(pending), CHUNK):
        chunk = pending[index:index + CHUNK]
        payload = TALIMAT + json.dumps([
            {"id": q["id"], "prompt": q["prompt"],
             "answers": q["answers"], "explanation": q.get("explanation", "")}
            for q in chunk], ensure_ascii=False)
        for attempt in range(3):
            try:
                items = parse(call(payload, key))
            except Exception as error:
                print(f"  hata: {str(error)[:60]}")
                items = []
            if items:
                break
            time.sleep(4)
        for item in items:
            if item.get("id") and len(item.get("answersTr") or []) == 4:
                done[item["id"]] = item
        out.write_text(json.dumps(list(done.values()), ensure_ascii=False, indent=1),
                       encoding="utf-8")
        print(f"  {len(done)}/{len(questions)} çevrildi", flush=True)

    print(f"toplam {len(done)}/{len(questions)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
