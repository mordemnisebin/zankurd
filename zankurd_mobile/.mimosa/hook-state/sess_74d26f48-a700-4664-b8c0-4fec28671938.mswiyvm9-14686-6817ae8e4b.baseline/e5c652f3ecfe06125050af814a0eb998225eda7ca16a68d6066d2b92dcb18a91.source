import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "supabase" / "2026-07-14_opentdb_translated_batch_3.csv"

ROWS = [
    ("Çand", 2, "Le Corbusier bi taybetî bi kîjan şêwazê mîmariyê re tê girêdan?", "Mîmariya modern.", "Mîmariya gotîk.", "Barok.", "Rokoko.", "A", "Le Corbusier yek ji kesayetiyên girîng ên mîmariya modern bû.", "opentdb_0010"),
    ("Paradigma", 2, "Li El Teniente ya li Şîlê, kîjan metal tê derxistin?", "Sifir.", "Zêr.", "Nîkel.", "Alûmînyum.", "A", "El Teniente wekî yek ji mezintirîn kanên binerdî yên sifirê tê naskirin.", "opentdb_0018"),
    ("Dîrok", 1, "Di navbera serokên Dewletên Yekbûyî de, kî bi rishê herî dirêj tê naskirin?", "Abraham Lincoln.", "Thomas Jefferson.", "John F. Kennedy.", "Theodore Roosevelt.", "A", "Di triviaya OpenTDB de Abraham Lincoln wek serokê bi rishê herî dirêj tê naskirin.", "opentdb_0210"),
    ("Dîrok", 1, "Gerald Ford di kîjan salê de bû serokê Dewletên Yekbûyî?", "1974.", "1972.", "1976.", "1980.", "A", "Gerald Ford di 1974-an de piştî îstifaya Richard Nixon bû serok.", "opentdb_0215"),
    ("Siyaset", 2, "Kîjan welatê Giravên Pasîfîkê di bin monarşiyeke destûrî de ye?", "Tonga.", "Nauru.", "Palau.", "Mikronezya.", "A", "Tonga monarşiyeke destûrî ye û di nav welatên Giravên Pasîfîkê de cih digire.", "opentdb_0216"),
    ("Siyaset", 1, "Li gorî Destûra Dewletên Yekbûyî, kes divê kêmî çend salî be da ku bibe serok?", "35 salî.", "25 salî.", "30 salî.", "40 salî.", "A", "Destûra Dewletên Yekbûyî şert dike ku namzedê serokatiyê herî kêm 35 salî be.", "opentdb_0217"),
    ("Çand", 2, "Edvard Munch bi qasî çend guhertoyên bi boyax û pastel ên 'The Scream' çêkirine?", "Çar.", "Yek.", "Du.", "Deh.", "A", "Edvard Munch bi çend guhertoyên boyax û pastel ên The Scream tê naskirin; di pirsê OpenTDB de bersiva rast çar e.", "opentdb_0259"),
    ("Çand", 1, "Wêneyê Salvador Dalí ya 'The Persistence of Memory' di kîjan salê de hate qedandin?", "1931.", "1921.", "1941.", "1951.", "A", "The Persistence of Memory di 1931-an de hate qedandin.", "opentdb_0265"),
    ("Çand", 2, "Logoya Chupa Chupsê kî sêwirand?", "Salvador Dalí.", "Pablo Picasso.", "Joan Miró.", "Henri Matisse.", "A", "Logoya Chupa Chupsê ji aliyê Salvador Dalí ve hatiye sêwirandin.", "opentdb_0267"),
    ("Çand", 1, "Wêneyê 'The Scream' kî kişandiye?", "Edvard Munch.", "Claude Monet.", "Pablo Picasso.", "Paul Klee.", "A", "The Scream berhema hunermendê norwêcî Edvard Munch e.", "opentdb_0268"),
    ("Paradigma", 2, "Li gorî OpenTDB, teorîya Big Bang yekem car ji aliyê kîjan kesayetiyê ve hate pêşniyarkirin?", "Georges Lemaître.", "Isaac Newton.", "Galileo Galilei.", "Charles Darwin.", "A", "Georges Lemaître, fizikzan û keşîşê katolîk, di pêşxistina fikirê Big Bang de roleke bingehîn hebû.", "opentdb_0061"),
    ("Paradigma", 2, "Nexweşiya Alzheimerê bi taybetî kîjan beşê laşê mirovan bandor dike?", "Mêjî.", "Dil.", "Rîve.", "Hestî.", "A", "Alzheimer nexweşiyeke neurolojîk e ku bi taybetî mêjî û bîranîna mirovan bandor dike.", "opentdb_0062"),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note", "source_candidate_id"]

def main():
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS); writer.writeheader()
        for i, row in enumerate(ROWS, 1):
            category, difficulty, prompt, a, b, c, d, correct, explanation, source_id = row
            options = [a, b, c, d]; shift = (i - 1) % 4; options = options[shift:] + options[:shift]
            writer.writerow({"id": f"opentdb_translated_3_{i:04d}", "category_key": category, "language_code": "ku-kmr", "prompt": prompt, "option_a": options[0], "option_b": options[1], "option_c": options[2], "option_d": options[3], "correct_option": "ABCD"[(4 - shift) % 4], "explanation": explanation, "difficulty": difficulty, "source_title": "Open Trivia Database API", "source_url": "https://opentdb.com/api_config.php", "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "OpenTDB adayından seçildi; Kurmancî çeviri ve editoryal uyarlama yapıldı.", "source_candidate_id": source_id})
    print(f"wrote {len(ROWS)} translated candidates")

if __name__ == "__main__": main()
