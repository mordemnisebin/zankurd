import sys, json, re, csv
from pathlib import Path

content = Path(r"C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile\lib\src\data\offline_question_bank.dart").read_text(encoding='utf-8')

def dart_unquote(tok):
    t = tok[1:-1]
    t = t.replace("\\n", "\n").replace("\\'", "'").replace('\\"', '"')
    return t.replace("\\\\", "\\")

string_re = r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\""
qs = []
pos = 0
while True:
    idx = content.find("QuizQuestion(", pos)
    if idx < 0:
        break
    start = idx + len("QuizQuestion(")
    depth = 1
    i = start
    in_s = None
    esc = False
    while i < len(content) and depth > 0:
        ch = content[i]
        if in_s:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == in_s:
                in_s = None
        else:
            if ch in "'\"":
                in_s = ch
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
        i += 1
    body = content[start:i-1]
    pos = i

    def field(name):
        m = re.search(name + r":\s*(" + string_re + r")", body)
        return dart_unquote(m.group(1)) if m else None

    answers = re.search(r"answers:\s*\[(.*?)\]", body, re.S)
    ans = [dart_unquote(m.group(0)) for m in re.finditer(string_re, answers.group(1))] if answers else []
    typ = re.search(r"type:\s*QuestionType\.(\w+)", body)
    diff = re.search(r"difficulty:\s*(\d+)", body)
    img = field("imageUrl")
    qs.append({
        "id": field("id"), "category": field("category"), "prompt": field("prompt"),
        "answers": ans, "correct": field("correctAnswer"), "explanation": field("explanation"),
        "difficulty": int(diff.group(1)) if diff else 1,
        "type": typ.group(1) if typ else "multipleChoice", "image": img,
    })

print("offline parsed:", len(qs))
json.dump(qs, open('offline_bank.json', 'w', encoding='utf-8'), ensure_ascii=False)

live = json.load(open('live_prompts.json', encoding='utf-8'))
live_prompts = {r['prompt'].strip() for r in live}
missing = [q for q in qs if q['prompt'].strip() not in live_prompts]
print("offline'da olup canlida olmayan:", len(missing))
from collections import Counter
print(Counter(q['category'] for q in missing))
tmpl = [q for q in missing if q['explanation'] and re.match(r"^'.*' kavramı hakkında .* bağlamında bilgi edindirme amaçlanmıştır\.$", q['explanation'])]
print("eksikler arasinda sablon aciklamali:", len(tmpl))

csvqs = list(csv.DictReader(open(r"C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_soru_bankasi_cevapli_DUZELTILMIS.csv", encoding='utf-8-sig')))
print("CSV satir:", len(csvqs))
byprompt = {r['prompt'].strip(): r['correct_option'] for r in live}
present = [c for c in csvqs if c['soru'].strip() in byprompt]
print("CSV'den canlida prompt eslesen:", len(present))
mismatch = []
for c in present:
    liveco = byprompt[c['soru'].strip()]
    if c['dogru_secenek'].strip() != liveco:
        mismatch.append((c['id'], c['dogru_secenek'], liveco))
print("cevap harfi uyusmayan:", len(mismatch), mismatch[:15])
missing_csv = [c['id'] for c in csvqs if c['soru'].strip() not in byprompt]
print("canlida olmayan CSV id:", missing_csv)
json.dump({"missing_offline": missing, "csv_mismatch": mismatch, "csv_missing": missing_csv},
          open('diff.json', 'w', encoding='utf-8'), ensure_ascii=False)
json.dump(csvqs, open('csv_rows.json', 'w', encoding='utf-8'), ensure_ascii=False)
