from __future__ import annotations

from pathlib import Path
import csv
import re


SOURCE = "zankurd_seed_rich_v2"
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "supabase" / "rich_question_bank_v2.sql"
CSV_OUTPUT = ROOT / "supabase" / "rich_question_bank_v2_questions.csv"
PARTS_DIR = ROOT / "supabase" / "rich_question_bank_v2_parts"
FILLER_OPTIONS = {"", "-"}


def esc(value: str | None) -> str:
    if value is None:
        return "null"
    return "'" + value.replace("'", "''") + "'"


def row(
    category: str,
    prompt: str,
    answers: list[str],
    correct_index: int,
    explanation: str,
    difficulty: int,
    question_type: str = "multiple_choice",
    image: str | None = None,
) -> dict[str, object]:
    padded = (answers + ["-", "-", "-", "-"])[:4]
    return {
        "category": category,
        "prompt": prompt,
        "a": padded[0],
        "b": padded[1],
        "c": padded[2],
        "d": padded[3],
        "correct": "ABCD"[correct_index],
        "explanation": explanation,
        "difficulty": difficulty,
        "question_type": question_type,
        "image": image,
    }


def tf(category: str, prompt: str, correct: bool, explanation: str, difficulty: int) -> dict[str, object]:
    return row(
        category,
        prompt,
        ["Rast", "Şaş"],
        0 if correct else 1,
        explanation,
        difficulty,
        "true_false",
    )


def visual(
    category: str,
    prompt: str,
    answers: list[str],
    correct_index: int,
    explanation: str,
    difficulty: int,
    label: str,
) -> dict[str, object]:
    image = f"asset://assets/question_images/{slugify(label)}.png"
    return row(category, prompt, answers, correct_index, explanation, difficulty, "visual", image)


def slugify(value: str) -> str:
    replacements = {
        "ç": "c",
        "Ç": "c",
        "î": "i",
        "Î": "i",
        "û": "u",
        "Û": "u",
        "ê": "e",
        "Ê": "e",
        "ş": "s",
        "Ş": "s",
        "ı": "i",
        "İ": "i",
        "ğ": "g",
        "Ğ": "g",
        "ö": "o",
        "Ö": "o",
        "ü": "u",
        "Ü": "u",
        "é": "e",
    }
    for source, target in replacements.items():
        value = value.replace(source, target)
    value = re.sub(r"[^a-zA-Z0-9]+", "_", value).strip("_").lower()
    return value or "question"


def build_questions() -> list[dict[str, object]]:
    questions: list[dict[str, object]] = []
    bands = ["Temel", "Pekiştirme", "Ustalık"]

    vocab = [
        ("av", "su", "agir", "ateş"),
        ("roj", "gün/güneş", "şev", "gece"),
        ("mal", "ev", "dibistan", "okul"),
        ("pirtûk", "kitap", "nivîs", "yazı"),
        ("zanîn", "bilmek", "çûn", "gitmek"),
        ("hatin", "gelmek", "xwendin", "okumak"),
        ("çiya", "dağ", "deşt", "ova"),
        ("dil", "kalp/dil", "dest", "el"),
        ("heval", "arkadaş", "malbat", "aile"),
        ("bajar", "şehir", "gund", "köy"),
        ("nan", "ekmek", "şîr", "süt"),
        ("rê", "yol", "derî", "kapı"),
        ("spas", "teşekkür", "silav", "selam"),
        ("xweş", "güzel/iyi", "germ", "sıcak"),
        ("sar", "soğuk", "mezin", "büyük"),
        ("biçûk", "küçük", "nû", "yeni"),
        ("kevin", "eski", "zû", "erken"),
        ("îro", "bugün", "sibê", "yarın"),
        ("duh", "dün", "dem", "zaman"),
        ("nav", "ad/isim", "peyiv", "söz"),
        ("zarok", "çocuk", "mamoste", "öğretmen"),
        ("xwendekar", "öğrenci", "kom", "grup"),
        ("rast", "doğru", "şaş", "yanlış"),
        ("pir", "çok", "kêm", "az"),
        ("destpêk", "başlangıç", "dawî", "son"),
    ]
    for variant in range(3):
        band = bands[variant]
        for i, (term, meaning, distractor, distractor_meaning) in enumerate(vocab):
            difficulty = 1 + ((i + variant) % 5)
            questions.append(row("Ziman", f'{band}: Di Kurmancî de peyva "{term}" bi Tirkî çi ye?', [meaning, distractor_meaning, "harita", "müzik"], 0, f'"{term}" kelimesi "{meaning}" anlamına gelir.', difficulty))
            questions.append(row("Ziman", f'{band}: "{meaning}" anlamına gelen Kurmancî kelime hangisidir?', [term, distractor, "newroz", "govend"], 0, f'"{meaning}" için doğru karşılık "{term}"tir.', difficulty))
            questions.append(tf("Ziman", f'{band}: Peyva "{term}" "{meaning}" anlamına gelir.', True, f'"{term}" için doğru anlam "{meaning}"tir.', difficulty))
            questions.append(tf("Ziman", f'{band}: Peyva "{term}" "{distractor_meaning}" anlamına gelir.', False, f'"{term}" "{meaning}" demektir; "{distractor}" ise "{distractor_meaning}" anlamına gelir.', difficulty))
            questions.append(visual("Ziman", f'{band}: Görsel etiketi "{term}" kavramını gösteriyor. Doğru anlam hangisidir?', [meaning, distractor_meaning, "tarih", "ödül"], 0, f'Görsel soru "{term}" kelimesini pekiştirir.', difficulty, term))

    culture = [
        ("Newroz", "baharın gelişi ve yenilenme", "21 Adar", 1),
        ("govend", "toplu halk oyunu", "düğün ve kutlama", 1),
        ("dengbêj", "sözlü anlatım ve ezgili hikaye", "sözlü kültür", 2),
        ("kilim motifleri", "kültürel sembol ve renk hafızası", "el sanatı", 2),
        ("misafirperverlik", "toplumsal dayanışma", "gündelik kültür", 1),
        ("yerel kıyafetler", "kimlik ve bölgesel çeşitlilik", "gelenek", 2),
        ("ağıt", "duygu ve toplumsal hafıza", "sözlü gelenek", 3),
        ("masal anlatımı", "kuşaktan kuşağa aktarılan anlatı", "sözlü kültür", 2),
        ("bayramlaşma", "toplumsal bağları güçlendirme", "ziyaret", 1),
        ("halk mutfağı", "yerel yaşam ve paylaşım", "sofra kültürü", 2),
    ]
    for i in range(75):
        topic, meaning, context, base_diff = culture[i % len(culture)]
        band = bands[(i // len(culture)) % len(bands)]
        difficulty = min(5, base_diff + (i // len(culture)))
        questions.append(row("Çand", f"{band}: Kürt kültüründe {topic} en çok hangi alanla ilişkilidir?", [meaning, "matematik işlemi", "kimyasal deney", "spor kuralı"], 0, f"{topic}, Kürt kültüründe {context} bağlamında değerlendirilir.", difficulty))
        questions.append(tf("Çand", f"{band}: Kürt kültüründe {topic} kültürel hafızayla ilişkilendirilebilir.", True, f"{topic}, Kürt kültürü ve toplumsal hafıza içinde anlam kazanır.", difficulty))
        questions.append(tf("Çand", f"{band}: Kürt kültüründe {topic} sadece teknik bir ölçü birimidir.", False, f"{topic} teknik ölçüden çok kültürel bir başlıktır.", difficulty))
        questions.append(visual("Çand", f"{band}: Görseldeki {topic} etiketi Kürt kültüründe hangi kategoriyle ilgilidir?", ["Çand", "Cografya", "Ziman", "Muzîk"], 0, f"{topic} Kürt kültürü kategorisinde ele alınır.", difficulty, topic))
        questions.append(row("Çand", f"{band}: Kürt kültüründe {topic} hakkında hangisi daha doğrudur?", [f"{context} ile ilişkilidir", "sadece sayı sistemidir", "sadece gök cismidir", "sadece trafik işaretidir"], 0, f"{topic}, Kürt kültüründe {context} alanıyla bağlantılıdır.", difficulty))

    history = [
        ("birincil kaynak", "döneminden kalan doğrudan belge veya nesne"),
        ("sözlü tarih", "tanıklık ve anlatılarla geçmişi anlama yöntemi"),
        ("kronoloji", "olayları zaman sırasına koyma"),
        ("arkeoloji", "maddi kalıntılarla geçmişi araştırma"),
        ("Mezopotamya", "Dicle ve Fırat çevresindeki tarihsel bölge"),
        ("göç", "toplulukların yer değiştirmesi"),
        ("yerleşik yaşam", "kalıcı yerleşim düzeni"),
        ("ticaret yolu", "bölgeler arası alışveriş güzergahı"),
        ("kültürel etkileşim", "toplumların birbirini etkilemesi"),
        ("tarihsel yorum", "kanıtlardan anlam çıkarma"),
    ]
    for i in range(75):
        topic, desc = history[i % len(history)]
        band = bands[(i // len(history)) % len(bands)]
        difficulty = 1 + (i % 5)
        questions.append(row("Dîrok", f"{band}: Kürt ve Kürdistan tarihini çalışırken {topic} neyi ifade eder?", [desc, "sadece müzik notası", "sadece hava durumu", "sadece renk adı"], 0, f"{topic}, Kürt ve Kürdistan tarihi araştırmalarında {desc} olarak kullanılabilir.", difficulty))
        questions.append(tf("Dîrok", f"{band}: {topic.capitalize()} Kürt ve Kürdistan tarihini anlamada kullanılabilir.", True, f"{topic} tarihsel düşünme için yararlı bir kavramdır.", difficulty))
        questions.append(tf("Dîrok", f"{band}: Kürt ve Kürdistan tarihi yalnızca savaş adlarını ezberlemekten oluşur.", False, "Tarih; kültür, ekonomi, dil, göç, kaynak ve gündelik yaşamı da inceler.", difficulty))
        questions.append(visual("Dîrok", f"{band}: Görseldeki '{topic}' etiketi Kürt/Kürdistan bağlamında hangi alana yakındır?", ["Dîrok", "Muzîk", "Spor", "Kimya"], 0, f"{topic} Kürt ve Kürdistan tarihi kategorisindeki kavramlardan biridir.", difficulty, topic))
        questions.append(row("Dîrok", f"{band}: Kürt ve Kürdistan tarihi için {topic} kavramının en uygun açıklaması hangisidir?", [desc, "bir yemek tarifi", "bir telefon modeli", "bir renk tonu"], 0, f"Doğru açıklama: {desc}.", difficulty))

    literature = [
        ("çîrok", "hikaye"),
        ("helbest", "şiir"),
        ("roman", "uzun anlatı"),
        ("destan", "kahramanlık anlatısı"),
        ("karakter", "anlatı kişisi"),
        ("tema", "ana düşünce"),
        ("mecaz", "dolaylı/anlam aktarımlı anlatım"),
        ("kafiye", "ses uyumu"),
        ("anlatıcı", "hikayeyi aktaran ses"),
        ("diyalog", "karşılıklı konuşma"),
    ]
    authors = ["Ehmedê Xanî", "Cegerxwîn", "Melayê Cizîrî", "Feqiyê Teyran"]
    for i in range(75):
        term, desc = literature[i % len(literature)]
        band = bands[(i // len(literature)) % len(bands)]
        difficulty = 1 + (i % 5)
        questions.append(row("Edebiyat", f"{band}: Kürt edebiyatında {term} ne anlama gelir?", [desc, "coğrafi yön", "matematik sembolü", "maden türü"], 0, f"{term}, Kürt edebiyatı alanında {desc} anlamında kullanılır.", difficulty))
        questions.append(tf("Edebiyat", f"{band}: {term.capitalize()} Kürt edebiyatıyla ilgili bir kavramdır.", True, f"{term} edebi metinleri anlamada kullanılan bir kavramdır.", difficulty))
        questions.append(tf("Edebiyat", f"{band}: Mem û Zîn genellikle Ehmedê Xanî ve Kürt edebiyatı ile ilişkilendirilir.", True, "Mem û Zîn, Ehmedê Xanî ile özdeşleşmiş klasik bir eserdir.", 2))
        questions.append(visual("Edebiyat", f"{band}: Görseldeki '{term}' etiketi hangi öğrenme kategorisine girer?", ["Edebiyat", "Cografya", "Muzîk", "Kimya"], 0, f"{term} Kürt edebiyatı kategorisinde değerlendirilir.", difficulty, term))
        questions.append(row("Edebiyat", f"{band}: Aşağıdakilerden hangisi Kürt edebiyatıyla ilişkilendirilen bir isimdir?", [authors[i % len(authors)], "Galileo Galilei", "Isaac Newton", "Napoleon"], 0, "Seçilen isim Kürt edebiyatı bağlamında bilinen isimlerdendir.", difficulty))

    geography = [
        ("çiya", "dağ"),
        ("deşt", "ova"),
        ("av", "su"),
        ("çem", "akarsu"),
        ("gol", "göl"),
        ("daristan", "orman"),
        ("newal", "vadi"),
        ("hewa", "hava"),
        ("erd", "yer/toprak"),
        ("sînor", "sınır"),
    ]
    for i in range(75):
        term, desc = geography[i % len(geography)]
        band = bands[(i // len(geography)) % len(bands)]
        difficulty = 1 + (i % 5)
        questions.append(row("Cografya", f'{band}: Kürdistan coğrafyası bağlamında Kurmancîde "{term}" neye yakındır?', [desc, "müzik notası", "edebi kişi", "alışveriş fişi"], 0, f'"{term}" coğrafya bağlamında "{desc}" anlamına gelir.', difficulty))
        questions.append(tf("Cografya", f"{band}: {desc.capitalize()} Kürdistan coğrafyasını anlamada kullanılabilecek kavramlardan biridir.", True, "Coğrafya doğal ve beşeri çevreyi inceler.", difficulty))
        questions.append(tf("Cografya", f"{band}: Kürdistan coğrafyasında iklim, bitki örtüsü ve yeryüzü şekilleri önemlidir.", True, "Bu başlıklar coğrafyanın temel konularındandır.", difficulty))
        questions.append(visual("Cografya", f"{band}: Görseldeki '{term}' etiketi Kürdistan coğrafyasında hangi kategoriye aittir?", ["Cografya", "Edebiyat", "Muzîk", "Dil bilgisi"], 0, f"{term} coğrafi bir kavram olarak kullanılabilir.", difficulty, term))
        questions.append(row("Cografya", f"{band}: Kürdistan coğrafyasında {desc} için en uygun Kurmancî kelime hangisidir?", [term, "helbest", "govend", "dengbêj"], 0, f"{desc.capitalize()} için doğru kelime '{term}'tir.", difficulty))

    music = [
        ("dengbêj", "ezgili sözlü anlatım"),
        ("ritim", "düzenli vuruş"),
        ("melodî", "ezgi"),
        ("stran", "şarkı"),
        ("def", "vurmalı çalgı"),
        ("erbane", "vurmalı çalgı"),
        ("tembûr", "telli çalgı"),
        ("nota", "müziği yazma işareti"),
        ("koro", "toplu söyleme"),
        ("solo", "tek kişinin icrası"),
    ]
    for i in range(75):
        term, desc = music[i % len(music)]
        band = bands[(i // len(music)) % len(bands)]
        difficulty = 1 + (i % 5)
        questions.append(row("Muzîk", f"{band}: Kürt müziğinde {term} neyle ilgilidir?", [desc, "harita çizimi", "fiil çekimi", "toprak ölçümü"], 0, f"{term}, Kürt müziği alanında {desc} ile ilişkilidir.", difficulty))
        questions.append(tf("Muzîk", f"{band}: {term.capitalize()} Kürt müziğiyle ilişkilendirilebilir.", True, f"{term} müzik kültüründe kullanılan bir kavramdır.", difficulty))
        questions.append(tf("Muzîk", f"{band}: Dengbêjlik Kürt sözlü kültürü ve ezgiyle ilişkilendirilebilir.", True, "Dengbêjlik ezgili sözlü anlatım geleneğidir.", 1))
        questions.append(visual("Muzîk", f"{band}: Görseldeki '{term}' etiketi Kürt müziğinde hangi kategoriye aittir?", ["Muzîk", "Dîrok", "Cografya", "Ziman"], 0, f"{term} Kürt müziği kategorisinde ele alınır.", difficulty, term))
        questions.append(row("Muzîk", f"{band}: Kürt müziğinde {desc} ifadesi en çok hangi kavramı açıklar?", [term, "çiya", "çîrok", "newal"], 0, f"Doğru kavram '{term}'tir.", difficulty))

    return questions


def dedupe_questions(questions: list[dict[str, object]]) -> list[dict[str, object]]:
    unique: list[dict[str, object]] = []
    seen: set[str] = set()
    for question in questions:
        prompt = str(question["prompt"]).strip().casefold()
        if prompt in seen:
            continue
        seen.add(prompt)
        unique.append(question)
    return unique


def generated_questions() -> list[dict[str, object]]:
    return dedupe_questions(build_questions())


def answer_leaks(questions: list[dict[str, object]]) -> list[dict[str, object]]:
    leaks: list[dict[str, object]] = []
    for question in questions:
        correct_key = str(question["correct"]).strip().lower()
        correct_text = str(question.get(correct_key, "")).strip().casefold()
        prompt = str(question["prompt"]).strip().casefold()
        if correct_text in FILLER_OPTIONS:
            continue
        if len(correct_text) >= 6 and correct_text in prompt:
            leaks.append(question)
    return leaks


def assert_quality(questions: list[dict[str, object]]) -> None:
    leaks = answer_leaks(questions)
    if leaks:
        examples = "\n".join(
            f"- {question['category']}: {question['prompt']}" for question in leaks[:10]
        )
        raise SystemExit(
            f"Generated question bank has {len(leaks)} answer leaks:\n{examples}"
        )


def setup_sql() -> str:
    return f"""alter table public.questions
  add column if not exists question_type text not null default 'multiple_choice';

alter table public.questions
  add column if not exists image_url text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'questions_question_type_check'
  ) then
    alter table public.questions
      add constraint questions_question_type_check
      check (question_type in ('multiple_choice', 'true_false', 'visual'));
  end if;
end;
$$;

insert into public.categories (name, slug, is_active)
values
  ('Ziman', 'ziman', true),
  ('Çand', 'cand', true),
  ('Dîrok', 'dirok', true),
  ('Edebiyat', 'edebiyat', true),
  ('Cografya', 'cografya', true),
  ('Muzîk', 'muzik', true)
on conflict (name) do update set is_active = excluded.is_active;

delete from public.questions
where source_url = '{SOURCE}';
"""


def insert_sql(values: list[str]) -> str:
    return f"""insert into public.questions (
  category_id,
  language_code,
  prompt,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option,
  explanation,
  difficulty,
  is_approved,
  question_type,
  image_url,
  source_url
)
values
{",\n".join(values)};
"""


def question_values(questions: list[dict[str, object]]) -> list[str]:
    values: list[str] = []
    for q in questions:
        values.append(
            "("
            f"(select id from public.categories where name = {esc(q['category'])}), "
            "'ku-kmr', "
            f"{esc(q['prompt'])}, "
            f"{esc(q['a'])}, "
            f"{esc(q['b'])}, "
            f"{esc(q['c'])}, "
            f"{esc(q['d'])}, "
            f"{esc(q['correct'])}, "
            f"{esc(q['explanation'])}, "
            f"{q['difficulty']}, "
            "true, "
            f"{esc(q['question_type'])}, "
            f"{esc(q['image'])}, "
            f"{esc(SOURCE)}"
            ")"
        )
    return values


def write_csv(questions: list[dict[str, object]]) -> None:
    with CSV_OUTPUT.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(
            file,
            fieldnames=[
                "category",
                "prompt",
                "a",
                "b",
                "c",
                "d",
                "correct",
                "explanation",
                "difficulty",
                "question_type",
                "image",
            ],
        )
        writer.writeheader()
        writer.writerows(questions)


def write_parts(values: list[str]) -> None:
    PARTS_DIR.mkdir(parents=True, exist_ok=True)
    for path in PARTS_DIR.glob("*.sql"):
        path.unlink(missing_ok=True)

    (PARTS_DIR / "00_setup.sql").write_text(setup_sql(), encoding="utf-8")
    chunk_size = 125
    for index, start in enumerate(range(0, len(values), chunk_size), start=1):
        chunk = values[start : start + chunk_size]
        (PARTS_DIR / f"{index:02d}_insert.sql").write_text(
            insert_sql(chunk),
            encoding="utf-8",
        )
    (PARTS_DIR / "README.txt").write_text(
        "Run 00_setup.sql first, then run the numbered insert files in order.\n"
        "These files are generated from tools/generate_rich_question_bank.py.\n",
        encoding="utf-8",
    )


def main() -> None:
    questions = generated_questions()
    assert_quality(questions)
    values = question_values(questions)
    sql = setup_sql() + "\n" + insert_sql(values)
    OUTPUT.write_text(sql, encoding="utf-8")
    write_csv(questions)
    write_parts(values)
    print(f"Wrote {len(questions)} unique questions to {OUTPUT}")


if __name__ == "__main__":
    main()
