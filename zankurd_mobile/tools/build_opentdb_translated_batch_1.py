import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "supabase" / "2026-07-14_opentdb_translated_batch_1.csv"

ROWS = [
    ("Cografya", 1, "Di kîjan herêmê de nebatê ananasê bi xwezayî hatiye naskirin?", "Amerîkaya Başûr.", "Ewropa.", "Asyaya Rojhilat.", "Afrîkaya Bakur.", "A", "Di hevoka OpenTDB de bersiva rast Amerîkaya Başûr e; ev pirs ji bo dîtina jiyana nebatan bi cografya re tê girêdan.", "opentdb_0001"),
    ("Ziman", 1, "Holandîaxêver navê zimanê xwe bi gelemperî çi dibêjin?", "Nederlands.", "Deutsch.", "Svenska.", "Magyar.", "A", "Di OpenTDB de bersiva rast Nederlands e, ku navê holandî yê zimanê xwe ye.", "opentdb_0003"),
    ("Paradigma", 2, "Di mantiqê de, 'êrîşa li ser kesayetiyê' çi xeletiyek e?", "Ad hominem.", "False dilemma.", "Red herring.", "Straw man.", "A", "Ad hominem li şûna bersivdayîna argumentê li ser kesayetiyê ya kesê din êrîş dike.", "opentdb_0006"),
    ("Dîrok", 2, "Di dîroka Japonê de, şogûn kî bûn?", "Fermandarên leşkerî yên ku demeke dirêj desthilatdar bûn.", "Komeke nivîskarên sarayê.", "Rêberên bazirganiyê yên deryayî.", "Nivîskarên perestgehê.", "A", "Şogûn navê fermandarên leşkerî yên Japonê bû ku di demên cuda de desthilatdariya siyasî bi rê ve dibirin.", "opentdb_0008"),
    ("Ziman", 1, "Di DNA-yê de, guanîn bi kîjan nukleotîdê re cot dibe?", "Sîtosîn.", "Tîmîn.", "Uracil.", "Adenîn.", "A", "Di hevokên OpenTDB de bersiva rast sîtosîn e; di DNA-yê de guanîn û sîtosîn cotek çêdikin.", "opentdb_0051"),
    ("Paradigma", 1, "100 dereceya Celsius bi qasî çend dereceya Fahrenheit e?", "212.", "100.", "180.", "32.", "A", "100°C bi 212°F re hevaheng e.", "opentdb_0052"),
    ("Paradigma", 2, "Di hucreyê de, kîjan organel wekî 'santrala hêzê' tê binavkirin?", "Mîtokondrî.", "Rîbozom.", "Çekirdek.", "Lîzozom.", "A", "Mîtokondrî enerjiya ku hucre ji bo karên xwe bikar tîne çêdike; ji ber vê yekê bi wê navê tê naskirin.", "opentdb_0058"),
    ("Paradigma", 1, "Di ava deîyonîzekirî de bi taybetî çi hatiye kêmkirin?", "Îyonên mîneral û yên din ên hildayî.", "Hemû molekulên avê.", "Rengê avê.", "Oksîjena di nav hewayê de.", "A", "Ava deîyonîzekirî ji bo kêmkirina îyonên hildayî tê parastin; ew ne wekî rakirina hemû molekulên avê ye.", "opentdb_0055"),
    ("Cografya", 1, "Paytexta Skotlandê kîjan bajar e?", "Edinburgh.", "Glasgow.", "Aberdeen.", "Dundee.", "A", "Paytexta Skotlandê Edinburgh e.", "opentdb_0104"),
    ("Cografya", 1, "Nîvgirava ku Spanya û Portekîz tê de ne çi ye?", "Nîvgirava Îberî.", "Nîvgirava Balkanê.", "Nîvgirava Skandinavî.", "Nîvgirava Arabistanê.", "A", "Spanya û Portekîz li ser Nîvgirava Îberî ya li başûrê rojavayê Ewropayê ne.", "opentdb_0105"),
    ("Cografya", 2, "Rûsya bi gelemperî bi çend herêmên demjimêrê tê pênasekirin?", "11.", "5.", "7.", "15.", "A", "Di pirsê OpenTDB de bersiva rast 11 herêmên demjimêrê ye.", "opentdb_0102"),
    ("Dîrok", 2, "Di dema 'Serdema Terorê' ya Şoreşa Fransayê de, kî kesayetiyek navdar bû?", "Maximilien Robespierre.", "Napoleon Bonaparte.", "Louis XIV.", "Charles de Gaulle.", "A", "Robespierre bi Komîteya Rizgariya Giştî û Serdema Terorê ya 1793–1794 re tê girêdan.", "opentdb_0151"),
    ("Dîrok", 2, "Şerê Somme di kîjan salê de dest pê kir?", "1916.", "1914.", "1918.", "1920.", "A", "Şerê Somme di 1ê Tîrmeha 1916-an de di Şerê Cîhanê yê Yekem de dest pê kir.", "opentdb_0152"),
    ("Dîrok", 2, "Salnameya Gregorianê cara yekem bi fermî di kîjan salê de hate pejirandin?", "1582.", "1492.", "1600.", "1701.", "A", "Salnameya Gregorianê di 1582-an de ji aliyê Papa Gregory XIII ve hate danîn û hin welatên Ewropayê ew pejirandin.", "opentdb_0154"),
    ("Dîrok", 1, "Manfred von Richthofen bi kîjan navê tê naskirin?", "Baronê Sor.", "Şêrê Spî.", "Pîlotê Reş.", "Kaptanê Kesk.", "A", "Manfred von Richthofen, pîlotê Alman ê Şerê Cîhanê yê Yekem, bi navê Baronê Sor tê naskirin.", "opentdb_0157"),
    ("Siyaset", 2, "Skandalê Watergate di kîjan salê de derket pêş?", "1972.", "1964.", "1980.", "1991.", "A", "Skandalê Watergate piştî ketina navenda Demokratan a Watergate di 1972-an de dest pê kir û paşê bû krîzeke siyasî.", "opentdb_0203"),
    ("Siyaset", 2, "Di destpêka Şerê Cîhanê yê Duyem de, serokwezîrê Brîtanyayê kî bû?", "Neville Chamberlain.", "Winston Churchill.", "Clement Attlee.", "Anthony Eden.", "A", "Di destpêka Şerê Cîhanê yê Duyem de Neville Chamberlain serokwezîrê Brîtanyayê bû; Churchill paşê li şûna wî hat.", "opentdb_0204"),
    ("Siyaset", 2, "Kîjan eyaleta Dewletên Yekbûyî di 1869-an de mafê dengdanê ji jinan re nas kir?", "Wyoming.", "New York.", "California.", "Texas.", "A", "Wyoming di 1869-an de mafê dengdanê ji jinan re nas kir û bi vê yekê di dîroka dengdanê de cih girt.", "opentdb_0205"),
    ("Siyaset", 2, "Montenegro di 2017-an de bû endamê çendemîn ê NATO-yê?", "29emîn.", "25emîn.", "31emîn.", "27emîn.", "A", "Montenegro di 2017-an de wek endamê 29emîn ê NATO-yê hate pejirandin.", "opentdb_0206"),
    ("Çand", 1, "Di mîmariya gotîk de, kîjan taybetmendî gelek caran tê dîtin?", "Qemerên tûj û hûrên bilind.", "Tenê dîwarên bê pencere.", "Qubeyên ku tenê li ser avên şil in.", "Avahiyên bê sînor û bê bingeh.", "A", "Qemerên tûj û rêzên bilind taybetmendiyên naskirî yên mîmariya gotîk in.", "opentdb_0251"),
    ("Çand", 1, "Wêneyê 'Nighthawks' kî kişandiye?", "Edward Hopper.", "Salvador Dalí.", "Pablo Picasso.", "Claude Monet.", "A", "Nighthawks berhema hunermendê Amerîkî Edward Hopper e.", "opentdb_0253"),
    ("Çand", 2, "Kîjan hunermend 'The Persistence of Memory' kişandiye?", "Salvador Dalí.", "Vincent van Gogh.", "Henri Matisse.", "Paul Cézanne.", "A", "The Persistence of Memory berhema Salvador Dalí ye û bi saetên nerm re tê naskirin.", "opentdb_0254"),
    ("Çand", 1, "Vincent van Gogh bi eslê xwe ji kîjan welatê bû?", "Holanda.", "Belçîka.", "Îtalya.", "Spanya.", "A", "Vincent van Gogh hunermendê holandî bû.", "opentdb_0257"),
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
            writer.writerow({"id": f"opentdb_translated_1_{i:04d}", "category_key": category, "language_code": "ku-kmr", "prompt": prompt, "option_a": options[0], "option_b": options[1], "option_c": options[2], "option_d": options[3], "correct_option": "ABCD"[(4 - shift) % 4], "explanation": explanation, "difficulty": difficulty, "source_title": "Open Trivia Database API", "source_url": "https://opentdb.com/api_config.php", "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "OpenTDB adayından seçildi; Kurmancî çeviri ve editoryal uyarlama yapıldı.", "source_candidate_id": source_id})
    print(f"wrote {len(ROWS)} translated candidates")

if __name__ == "__main__":
    main()
