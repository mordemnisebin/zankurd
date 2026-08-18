import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "supabase" / "2026-07-14_opentdb_translated_batch_4.csv"

ROWS = [
    ("Cografya", 1, "Çend eyaletên Dewletên Yekbûyî bi tîpa K dest pê dikin?", "Du.", "Yek.", "Sê.", "Tu yek.", "A", "Kansas û Kentucky du eyaletên Dewletên Yekbûyî ne ku bi tîpa K dest pê dikin.", "opentdb_0109"),
    ("Cografya", 1, "Paytexta Bermudayê kîjan bajar e?", "Hamilton.", "Santo Domingo.", "San Juan.", "Havana.", "A", "Hamilton paytexta Bermudayê ye.", "opentdb_0114"),
    ("Cografya", 1, "Bajarê Portsmouthê di kîjan wîlayeta Îngilîstanê de ye?", "Hampshire.", "Oxfordshire.", "Buckinghamshire.", "Surrey.", "A", "Portsmouth di wîlayeta Hampshire ya Îngilîstanê de ye.", "opentdb_0117"),
    ("Dîrok", 2, "Di 1845-an de, li Zelanda Nû rêze şerên navê kîjan gelê xwecihî li ser wan bû dest pê kir?", "Māori.", "Papua.", "Aborîjen.", "Polînezî.", "A", "Şerên Zelanda Nû yên ku di 1845-an de dest pê kirin bi gelê Māori re hatine navandin.", "opentdb_0159"),
    ("Dîrok", 1, "Kîjan welat ne beşek ji Yekîtiya Sovyetê bû?", "Afganistan.", "Turkmenistan.", "Qazaxistan.", "Uzbekistan.", "A", "Afganistan beşek ji Yekîtiya Sovyetê nebû; sê welatên din di nav komarên Sovyetê de bûn.", "opentdb_0160"),
    ("Dîrok", 3, "Kîjan şer gelek caran wek destpêka ketina Împaratoriya Romaya Rojava tê dîtin?", "Şerê Adrianople.", "Şerê Thessalonica.", "Şerê Pollentia.", "Şerê Constantinople.", "A", "Şerê Adrianople ya 378-an gelek caran wek bûyereka nîşander di qelsbûna Împaratoriya Romaya Rojava de tê dîtin.", "opentdb_0165"),
    ("Dîrok", 2, "Di Şerê Cîhanê yê Yekem de, padîşahên kîjan welatan bi xwînê bi hev re girêdayî bûn?", "Îngilîstan, Almanya û Rûsya.", "Fransa, Rûsya û Almanya.", "Serbistan, Rûsya û Xirwatistan.", "Almanya, Spanya û Awûstûrya.", "A", "Malbatên padîşahî yên Îngilîstan, Almanya û Rûsya di destpêka Şerê Cîhanê yê Yekem de bi têkiliyên malbatî ve girêdayî bûn.", "opentdb_0166"),
    ("Çand", 1, "Wêneyê Mona Lisa di kîjan salê de hate qedandin?", "1504.", "1487.", "1523.", "1511.", "A", "Mona Lisa bi gelemperî bi sala 1504-an re tê girêdan.", "opentdb_0261"),
    ("Çand", 1, "Albrecht Durer wêneyê 'The Young Hare' di kîjan salê de çêkir?", "1502.", "1702.", "1402.", "1602.", "A", "Albrecht Durer The Young Hare di 1502-an de çêkir.", "opentdb_0264"),
    ("Paradigma", 2, "Di zanîna biyolojiyê de, XYY çi cure guhertina genetîkî nîşan dide?", "Hebûna kromozomeke Y ya zêde.", "Kêm bûna kromozomeke X.", "Hebûna du kromozomên X yên zêde.", "Hebûna kromozomeke M ya zêde.", "A", "Di pirsê OpenTDB de bersiva rast hebûna kromozomeke Y ya zêde ye; ev pirs divê bi zimanekî agahdar û ne-stigmatîzekar bê bikaranîn.", "opentdb_0064"),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note", "source_candidate_id"]

def main():
    with OUT.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS); writer.writeheader()
        for i, row in enumerate(ROWS, 1):
            category, difficulty, prompt, a, b, c, d, correct, explanation, source_id = row
            options = [a, b, c, d]; shift = (i - 1) % 4; options = options[shift:] + options[:shift]
            writer.writerow({"id": f"opentdb_translated_4_{i:04d}", "category_key": category, "language_code": "ku-kmr", "prompt": prompt, "option_a": options[0], "option_b": options[1], "option_c": options[2], "option_d": options[3], "correct_option": "ABCD"[(4 - shift) % 4], "explanation": explanation, "difficulty": difficulty, "source_title": "Open Trivia Database API", "source_url": "https://opentdb.com/api_config.php", "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "OpenTDB adayından seçildi; Kurmancî çeviri ve editoryal uyarlama yapıldı.", "source_candidate_id": source_id})
    print(f"wrote {len(ROWS)} translated candidates")

if __name__ == "__main__": main()
