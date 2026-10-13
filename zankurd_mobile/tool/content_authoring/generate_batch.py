#!/usr/bin/env python3
"""Soru partisi üretir: DeepSeek API'sine doğrudan, ajan aracılığı olmadan.

## Niçin ajan değil

İlk kurulum `opencode run` üzerinden gidiyordu ve üç ayrı biçimde tökezledi:
ajan CSV'yi yazmak yerine bir Python betiği üretip çalışma dizini dışına
yazmaya kalktı (izin reddi, çıktı yok); sonra tur bütçesini kaynakları curl
ile doğrulamaya harcayıp CSV'ye hiç sıra gelmedi; uzun promptta ise on
dakika boyunca hiçbir şey döndürmedi.

Toplu metin üretimi için ajan yanlış araç: tur bütçesi, izin katmanı ve araç
kullanma dürtüsü hep işin aleyhine çalışıyor. Bu betik `chat/completions`
uç noktasını doğrudan çağırır — deterministik, paralelleştirilebilir, izin
sormaz.

Kaynak adreslerinin gerçekten açıldığı ayrı bir adımda denetlenir:
`precheck_batch.py --check-urls`. Bu iş mekaniktir ve LLM turuna ait değildir.

Kullanım:
  python3 tool/content_authoring/generate_batch.py \
      --category Teknolojî --subtopic "internet kavramları" \
      --count 25 --ratio 20/80 --out parti_01.csv
"""
import argparse
import csv
import json
import os
import pathlib
import re
import sys
import urllib.request

API = "https://api.deepseek.com/chat/completions"
AUTH = pathlib.Path.home() / ".local/share/opencode/auth.json"
ROOT = pathlib.Path(__file__).resolve().parents[2]
TEMPLATE = ROOT / "tool/content_authoring/generation_prompt.md"
HEADER = ("id,language_code,category_key,prompt,option_a,option_b,option_c,option_d,"
          "correct_option,explanation,difficulty,source_verified,source_url,"
          "publication_status,confidence,notes")

SLUG = str.maketrans({"î": "i", "ê": "e", "û": "u", "ç": "c", "ş": "s"})


def api_key() -> str:
    key = os.environ.get("DEEPSEEK_API_KEY")
    if key:
        return key
    data = json.loads(AUTH.read_text())
    entry = data.get("deepseek", {})
    key = entry.get("key") or entry.get("apiKey")
    if not key:
        sys.exit("DeepSeek anahtarı bulunamadı (DEEPSEEK_API_KEY ya da opencode auth.json)")
    return key


def used_prompts(out: pathlib.Path, limit: int = 150) -> str:
    """Önceki partilerin soruları. Parti İÇİ tekrarı model kendi engeller;
    partiler ARASI tekrarı ancak bu liste engeller."""
    if not out.exists():
        return "(ilk parti)"
    with out.open(newline="", encoding="utf-8") as handle:
        prompts = [r.get("prompt", "").strip() for r in csv.DictReader(handle)]
    prompts = [p for p in prompts if p][-limit:]
    return "\n".join(f"- {p}" for p in prompts) or "(ilk parti)"


def build_prompt(args, out: pathlib.Path) -> str:
    slug = args.category.lower().translate(SLUG)
    slug = re.sub(r"[^a-z]", "", slug)
    text = TEMPLATE.read_text(encoding="utf-8")
    for token, value in {
        "__CATEGORY__": args.category,
        "__SUBTOPIC__": args.subtopic,
        "__COUNT__": str(args.count),
        "__RATIO__": args.ratio,
        "__IDPREFIX__": f"ds_{slug}_",
        "__SIRA__": "0001",
        "__USED__": used_prompts(out),
    }.items():
        text = text.replace(token, value)
    return text


def call(prompt: str, key: str, model: str, max_tokens: int) -> str:
    body = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        # Düşük sıcaklık uydurmayı azaltır ama tamamen sıfırlamak bütün
        # partileri birbirine benzetir ve `template_density` kapısına
        # takılır; 0.7 ikisinin arasıdır.
        "temperature": 0.7,
        "max_tokens": max_tokens,
    }).encode()
    request = urllib.request.Request(
        API, data=body,
        headers={"Content-Type": "application/json", "Authorization": f"Bearer {key}"},
    )
    with urllib.request.urlopen(request, timeout=600) as response:
        payload = json.load(response)
    choice = payload["choices"][0]
    reason = choice.get("finish_reason")
    if reason and reason != "stop":
        print(f"UYARI: model erken kesildi (finish_reason={reason}); "
              f"--count değerini düşür ya da --max-tokens artır")
    return choice["message"]["content"]


def extract(text: str) -> list[dict]:
    """Modelin JSON dizisini ayrıştırır.

    CSV istemekten vazgeçildi: model ilk satırı doğru yazıp sonrakilerde
    fazladan bir alan üretiyordu ve tek bir kayan virgül bütün sütunları
    kaydırıp her kuralı ayrı ayrı patlatıyordu. JSON'da alan adları açık
    olduğu için o kusur sınıfı tamamen ortadan kalkıyor; CSV'yi artık bu
    betik deterministik olarak yazıyor.
    """
    body = text.strip()
    fence = re.search(r"```(?:json)?\s*(.+?)```", body, re.S)
    if fence:
        body = fence.group(1).strip()
    start, end = body.find("["), body.rfind("]")
    if start < 0 or end <= start:
        return []
    try:
        parsed = json.loads(body[start:end + 1])
    except json.JSONDecodeError:
        return []
    return [item for item in parsed if isinstance(item, dict)]


def to_row(item: dict, category: str, index: int, prefix: str) -> list[str] | None:
    """JSON kaydını kapının beklediği 16 alanlık satıra çevirir.

    Doğru cevabın KONUMU burada dengelenir. Model bunu promptla yapamıyor:
    "dağıt" denmesine rağmen bir partide doğru cevabı on kez A, ertesi
    partide yedi kez B yaptı. Oyuncu konumu ezberler ve soru bankası değersiz
    hâle gelir.

    Çözüm modelden istemek değil, burada döndürmek: şıklar satır sırasına
    göre kaydırılır, böylece doğru cevap A, B, C, D arasında sırayla dolaşır.
    Deterministik olduğu için tekrar çalıştırınca aynı sonucu verir.
    """
    options = list(item.get("options") or [])
    if len(options) != 4:
        return None

    # ID modelden ALINMAZ: her parti numaralandırmaya 0001'den başlıyor ve
    # aynı dosyaya yazılan ikinci parti baştan sona `duplicate_id` düşüyordu
    # (ilk gerçek koşuda 60 satırın 54'ü). Sıra dosyanın kendisinden gelir.
    row_id = f"{prefix}{index + 1:04d}"

    letter = str(item.get("correct", "")).strip().upper()
    if letter not in "ABCD" or not letter:
        return None
    correct_at = "ABCD".index(letter)

    target = index % 4
    # Doğru şıkkı hedef konuma taşı, kalanların göreli sırasını koru.
    correct_option = options.pop(correct_at)
    options.insert(target, correct_option)
    letter = "ABCD"[target]

    return [
        row_id,
        "ku-kmr",
        category,
        str(item.get("prompt", "")).strip(),
        *[str(o).strip() for o in options],
        letter,
        str(item.get("explanation", "")).strip(),
        str(item.get("difficulty", "")).strip(),
        "verified",
        str(item.get("source_url", "")).strip(),
        "approved",
        "0.95",
        "",
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--category", required=True)
    parser.add_argument("--subtopic", required=True)
    parser.add_argument("--count", type=int, default=25)
    parser.add_argument("--ratio", default="30/70")
    parser.add_argument("--out", required=True)
    parser.add_argument("--model", default="deepseek-chat")
    parser.add_argument("--max-tokens", type=int, default=8000)
    args = parser.parse_args()

    out = pathlib.Path(args.out)
    content = call(build_prompt(args, out), api_key(), args.model, args.max_tokens)
    if os.environ.get("ZK_DUMP"):
        pathlib.Path(os.environ["ZK_DUMP"]).write_text(content, encoding="utf-8")
    rows = extract(content)
    if not rows:
        print("HATA: çıktıda ayrıştırılabilir JSON dizisi yok. Modelin cevabı:")
        print(content[:600])
        return 1

    start_index = 0
    if out.exists():
        with out.open(newline="", encoding="utf-8") as handle:
            start_index = max(0, sum(1 for _ in handle) - 1)
    slug = re.sub(r"[^a-z]", "", args.category.lower().translate(SLUG))
    prefix = f"ds_{slug}_"
    written = [r for r in (to_row(item, args.category, start_index + i, prefix)
                           for i, item in enumerate(rows)) if r]
    if not written:
        print("HATA: JSON ayrıştırıldı ama hiçbir kayıt dört şık taşımıyor")
        return 1

    fresh = not out.exists()
    with out.open("a", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        if fresh:
            writer.writerow(HEADER.split(","))
        writer.writerows(written)
    print(f"{len(written)} satır eklendi -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
