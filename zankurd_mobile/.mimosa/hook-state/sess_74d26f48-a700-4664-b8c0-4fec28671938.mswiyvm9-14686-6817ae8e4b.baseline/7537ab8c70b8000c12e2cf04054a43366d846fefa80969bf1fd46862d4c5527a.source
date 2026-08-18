import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "supabase" / "2026-07-14_opentdb_translated_batch_2.csv"

ROWS = [
    ("Cografya", 1, "Kîjan şiklî bi gelemperî ji bo nîşana rawestan tê bikaranîn?", "Heştgoşe.", "Sêgoşe.", "Çargoşe.", "Dorpêç.", "A", "Nîşana rawestan bi gelemperî şiklê heştgoşeyê heye.", "opentdb_0012"),
    ("Siyaset", 1, "Li ser alaya Yekîtiya Ewropayê çend stêrk hene?", "12.", "10.", "15.", "27.", "A", "Li ser alaya Yekîtiya Ewropayê 12 stêrk hene; ew bi hejmareke nîşander a welatên endam ne.", "opentdb_0013"),
    ("Ziman", 1, "Di zimanê Spanî de peyva 'donkey' çi ye?", "Burro.", "Cheval.", "Gato.", "Perro.", "A", "Di zimanê Spanî de burro peyva ji bo ker e.", "opentdb_0014"),
    ("Cografya", 1, "Di yek mîlê de çend furlong hene?", "Heşt.", "Deh.", "Çar.", "Sîzdeh.", "A", "Yek mîl bi heşt furlongên kevneşopî re hevaheng e.", "opentdb_0015"),
    ("Cografya", 1, "Bi qasî çend ji sedî rûyê Erdê bi avê ve hatiye nixumandin?", "Nêzîkî 71 ji sedî.", "Nêzîkî 20 ji sedî.", "Nêzîkî 45 ji sedî.", "Nêzîkî 90 ji sedî.", "A", "Rûyê Erdê bi nêzîkî 71 ji sedî bi avê ve hatiye nixumandin.", "opentdb_0059"),
    ("Paradigma", 2, "Kîjan cure kevir ji germî û zexta pir zêde çêdibe?", "Kevirê metamorfîk.", "Kevirê sedimentî.", "Kevirê magmatîk.", "Kevirê şil.", "A", "Germî û zext dikarin kevirên berê biguherînin û kevirê metamorfîk çêbikin.", "opentdb_0066"),
    ("Paradigma", 1, "Osteoporoz bi taybetî kîjan beşê laşê lawaz dike?", "Hestiyan.", "Mûçeyan.", "Çavan.", "Pokan.", "A", "Osteoporoz nexweşiyeke hestiyan e ku çêdibe hestî hêsantir bişikên.", "opentdb_0067"),
    ("Dîrok", 2, "Kîjan bûyera wendabûna dînozorên ne-kuşkan re tê girêdan?", "Bûyera wendabûna Kretase–Paleogenê.", "Bûyera mezin a destpêka Çaryaryê.", "Şerê Somme.", "Rijandina Pompeî.", "A", "Lêkolînên zanistî wendabûna piraniya dînozorên ne-kuşkan bi bandora asteroîdekî û bûyera Kretase–Paleogenê re girêdidin.", "opentdb_0068"),
    ("Cografya", 1, "Kîjan eyaleta Dewletên Yekbûyî herî mezin e?", "Alaska.", "Texas.", "California.", "Montana.", "A", "Alaska herî mezin a eyaletên Dewletên Yekbûyî ye.", "opentdb_0112"),
    ("Cografya", 1, "Kîjan girava Japonê ji aliyê rûberê ve herî mezin e?", "Honshū.", "Hokkaidō.", "Kyūshū.", "Shikoku.", "A", "Honshū girava herî mezin a Japonê ye.", "opentdb_0113"),
    ("Cografya", 1, "Paytexta Ekuadorê kîjan bajar e?", "Quito.", "Guayaquil.", "Cuenca.", "Loja.", "A", "Paytexta Ekuadorê Quito e.", "opentdb_0116"),
    ("Ziman", 2, "Di alfabeya Yewnanî de, tîpa 15emîn kîjan e?", "Omicron.", "Nu.", "Xi.", "Pi.", "A", "Di rêza alfabeya Yewnanî de omicron tîpa 15emîn e.", "opentdb_0118"),
    ("Dîrok", 2, "Kîjan feldmarshalê Almanî bi navê 'Rovîyê Çolê' dihat naskirin?", "Erwin Rommel.", "Paul von Hindenburg.", "Erich Ludendorff.", "Georg von Kuchler.", "A", "Erwin Rommel bi navê Desert Fox, an Rovîyê Çolê, dihat naskirin.", "opentdb_0161"),
    ("Dîrok", 2, "Dorpêça Leningradê di Şerê Cîhanê yê Duyem de kengî hate rakirin?", "Di Çileya 1944-an de.", "Di Gulana 1942-an de.", "Di Cotmeha 1945-an de.", "Di Sibata 1941-an de.", "A", "Dorpêça Leningradê di Çileya 1944-an de, piştî nêzîkî 872 rojan, hate rakirin.", "opentdb_0163"),
    ("Dîrok", 2, "Kîjan welat cara yekem tiştek şand fezayê?", "Yekîtiya Sovyetê.", "Dewletên Yekbûyî.", "Fransa.", "Çîn.", "A", "Yekîtiya Sovyetê cara yekem tiştekî çêkirî şand fezayê bi Sputnik 1 re di 1957-an de.", "opentdb_0167"),
    ("Çand", 2, "Kîjan cih di nav heft ecêbên orîjînal ên cîhana kevn de nehatibû hejmartin?", "Koloseuma Romayê.", "Peykerê Zeus li Olimpiyayê.", "Baxçeyên Asîlan ên Babylonê.", "Piramîda Mezin a Gîzayê.", "A", "Koloseum di nav lîsteya heft ecêbên cîhana kevn de nebû; ew li ser lîsteyên paşerojê yên cûda tê dîtin.", "opentdb_0168"),
    ("Edebiyat", 2, "Navê berhema Machiavelli ya li ser desthilatdariya rêberan çi ye?", "The Prince.", "Utopia.", "Republic.", "Leviathan.", "A", "Machiavelli di The Prince de li ser desthilat, rêberî û stratejiyên siyasî nîqaş dike.", "opentdb_0209"),
    ("Siyaset", 2, "Kîjan organê sereke yê Neteweyên Yekbûyî ji 1994-an ve hat suspendkirin?", "Encûmena Rêveberiya Desthilatên Bawerî.", "Meclîsa Giştî.", "Dadgeha Navneteweyî ya Dadê.", "Sekreterya Giştî.", "A", "Encûmena Rêveberiya Desthilatên Bawerî ya Neteweyên Yekbûyî ji 1994-an ve karê xwe suspend kiriye.", "opentdb_0212"),
    ("Dîrok", 2, "Piştî Joseph Stalin, kî li ser Sekreteriya Giştî ya Partiya Komunîst a Sovyetê hat?", "Nikita Khrushchev.", "Leonid Brezhnev.", "Mikhail Gorbachev.", "Alexei Kosygin.", "A", "Nikita Khrushchev piştî mirina Stalinê bû kesayetiyeke sereke ya rêberiya Sovyetê.", "opentdb_0213"),
    ("Siyaset", 2, "Kî yekem serokê reş ê Afrîkaya Başûr bû?", "Nelson Mandela.", "Desmond Tutu.", "Thabo Mbeki.", "Kofi Annan.", "A", "Nelson Mandela di 1994-an de yekem serokê reş ê Afrîkaya Başûr bû.", "opentdb_0218"),
    ("Çand", 1, "Wêneyê Mona Lisa kî kişandiye?", "Leonardo da Vinci.", "Michelangelo.", "Raphael.", "Caravaggio.", "A", "Mona Lisa berhema Leonardo da Vinci ye.", "opentdb_0260"),
    ("Çand", 1, "Atolyeya hunermendê ku bi navê 'The Factory' dihat naskirin ji kîjan hunermendî re bû?", "Andy Warhol.", "Pablo Picasso.", "Salvador Dalí.", "Henri Matisse.", "A", "The Factory navê studyoya Andy Warhol bû ku hunermend û hilberînerên cuda li wir kom dibûn.", "opentdb_0262"),
    ("Çand", 1, "Pablo Picasso bi eslê xwe ji kîjan welatê bû?", "Spanya.", "Fransa.", "Îtalya.", "Portekîz.", "A", "Pablo Picasso hunermendê Spanî bû ku beşeke mezin a jiyana xwe li Fransayê derbas kir.", "opentdb_0263"),
    ("Edebiyat", 1, "Wêneyê 'The Starry Night' kî kişandiye?", "Vincent van Gogh.", "Claude Monet.", "Edvard Munch.", "Paul Gauguin.", "A", "The Starry Night berhema Vincent van Gogh e.", "opentdb_0266"),
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
            writer.writerow({"id": f"opentdb_translated_2_{i:04d}", "category_key": category, "language_code": "ku-kmr", "prompt": prompt, "option_a": options[0], "option_b": options[1], "option_c": options[2], "option_d": options[3], "correct_option": "ABCD"[(4 - shift) % 4], "explanation": explanation, "difficulty": difficulty, "source_title": "Open Trivia Database API", "source_url": "https://opentdb.com/api_config.php", "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "OpenTDB adayından seçildi; Kurmancî çeviri ve editoryal uyarlama yapıldı.", "source_candidate_id": source_id})
    print(f"wrote {len(ROWS)} translated candidates")

if __name__ == "__main__":
    main()
