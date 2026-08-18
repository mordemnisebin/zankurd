import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "supabase" / "2026-07-14_opentdb_translated_batch_5.csv"

ROWS = [
    ("Dîrok", 2, "Komploya barûtê ya 1605-an li dijî kîjan padîşahê Îngilîstanê hat amadekirin?", "James I.", "Elizabeth I.", "Charles II.", "Charles I.", "A", "Komploya barûtê ya 1605-an li dijî James I, padîşahê wê demê yê Îngilîstanê, hat amadekirin.", "opentdb_0153"),
    ("Dîrok", 2, "Şerê Duyemîn ê Boerê ku di 1899-an de dest pê kir, li kîjan herêmê hate şer kirin?", "Afrîkaya Başûr.", "Arjantîn.", "Nepal.", "Bulgaristan.", "A", "Şerê Duyemîn ê Boerê di Afrîkaya Başûr de di navbera Boeran û Împaratoriya Brîtanyayê de qewimî.", "opentdb_0156"),
    ("Dîrok", 2, "Piştî têkçûna xwe ya li Şerê Waterloo, Napolyon Bonaparte li kîjan giravê hate sirgûnkirin?", "Saint Helena.", "Elba.", "Korsîka.", "Giravên Kanarya.", "A", "Piştî Waterloo, Napolyon li girava Saint Helena hate sirgûnkirin; berê jî li Elba sirgûn bû.", "opentdb_0169"),
    ("Dîrok", 1, "Keştiya RMS Titanic di rêwîtiya xwe ya yekem de ji Southamptonê ber bi kîjan bajarê Amerîkî ve diçû?", "New York City.", "Boston.", "Philadelphia.", "Washington.", "A", "Titanic di rêwîtiya xwe ya yekem de ji Southamptonê ber bi New York City ve diçû.", "opentdb_0170"),
    ("Teknolojî", 1, "Di Windowsê de kîjan kurtasiya klavyeyê ji bo fonksiyona 'Copy' tê bikaranîn?", "Ctrl + C.", "Ctrl + X.", "Alt + C.", "Alt + X.", "A", "Kombînasyona Ctrl + C di Windowsê de ji bo kopîkirina nivîs an daneyan tê bikaranîn.", "opentdb_remaining_0327"),
    ("Teknolojî", 2, "Protokola înternetê ya di RFC 1459 de hatî belgekirin kîjan e?", "IRC.", "HTTP.", "HTTPS.", "FTP.", "A", "RFC 1459 standarda destpêkê ya protokola Internet Relay Chat, ango IRC, belge dike.", "opentdb_remaining_0328"),
    ("Teknolojî", 2, "Navê kêşeya ewlehiyê ya ku di Bashê de di sala 2014-an de hate dîtin çi bû?", "Shellshock.", "Heartbleed.", "Bashbug.", "Stagefright.", "A", "Kêşeya Shellshock di sala 2014-an de di şertên taybet ên Bashê de rê li ber xebitandina kodê ji dûr ve dikir.", "opentdb_remaining_0331"),
    ("Çand", 1, "Di tabloya 'Şîva Dawî' ya Leonardo da Vinci de, cilên Îsa bi kîjan cotrengê têne nîşandan?", "Sor û şîn.", "Sor û spî.", "Sor û zer.", "Sor û reş.", "A", "Li gorî bersiva OpenTDB, cilên Îsa di 'Şîva Dawî' de bi sor û şîn têne nîşandan.", "opentdb_0252"),
    ("Çand", 1, "Kîjan hunermend tabloya 'The Treachery of Images' ya bi wêneyê lûleyekê û nivîsa 'ev lûle nîne' çêkir?", "René Magritte.", "Henri Matisse.", "Amedeo Modigliani.", "Edvard Munch.", "A", "Tabloya 'The Treachery of Images' ya bi navê fransî 'La Trahison des Images' ji René Magritte re tê girêdan.", "opentdb_0256"),
    ("Çand", 2, "Wênekêş Piet Mondrian (1872–1944) endamê kîjan tevgerê hunerî bû?", "Neoplasticism.", "Precisionism.", "Kubîzm.", "Impressionism.", "A", "Piet Mondrian bi tevgera Neoplasticismê, ku bi kompozîsyonên geometriyî û rengên bingehîn tê naskirin, tê girêdan.", "opentdb_0272"),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note", "source_candidate_id"]


def main():
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        for i, row in enumerate(ROWS, 1):
            category, difficulty, prompt, a, b, c, d, correct, explanation, source_id = row
            options = [a, b, c, d]
            shift = (i - 1) % 4
            options = options[shift:] + options[:shift]
            writer.writerow({
                "id": f"opentdb_translated_5_{i:04d}",
                "category_key": category,
                "language_code": "ku-kmr",
                "prompt": prompt,
                "option_a": options[0], "option_b": options[1], "option_c": options[2], "option_d": options[3],
                "correct_option": "ABCD"[(4 - shift) % 4],
                "explanation": explanation,
                "difficulty": difficulty,
                "source_title": "Open Trivia Database API",
                "source_url": "https://opentdb.com/api_config.php",
                "publication_status": "PENDING_EDITORIAL_APPROVAL",
                "quality_note": "OpenTDB adayından seçildi; Kurmancî çeviri ve editoryal uyarlama yapıldı.",
                "source_candidate_id": source_id,
            })
    print(f"wrote {len(ROWS)} translated candidates")


if __name__ == "__main__":
    main()
