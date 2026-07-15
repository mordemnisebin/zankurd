import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_OUT = ROOT / "supabase" / "2026-07-14_movement_sources_question_wave_5.csv"
SQL_OUT = ROOT / "supabase" / "2026-07-14_movement_sources_question_wave_5.sql"
SRC = "https://jineoloji.eu/en/2025/06/29/jineoloji-magazine-at-10-years-old-the-reunion-of-knowledge-stolen-from-women-with-women-part-1/"

ROWS = [
    ("Ziman", 3, "Di lîsteya Jineolojî Dergisî de, «Rastiya jinê bingehê rêbazê ye» bi kîjan mijarê re tê girêdan?", "Bi rêbazeke ku ezmûna jinan di hilberîna zanînê de dixe navendê.", "Bi rêbazeke ku ezmûna jinan ji lêkolînê dûr dixe.", "Bi rêbazeke ku ziman tenê wekî kodê teknîkî dibîne.", "Bi rêbazeke ku dîrokê ji civakê cuda dike.", "A", "Navê dosyayê li ser rêbaz û rastiya jinan raweste; ev nîşan dide ku ezmûna jinan wekî çavkaniya zanînê tê dîtin.", "Method and Truth Based on Women’s Reality"),
    ("Ziman", 2, "Di dosyaya «Perwerdehiya zimanê jiyanê» de, ziman bi kîjan têgehê re têkildar tê xwendin?", "Bi jiyan, perwerde û hilberîna zanînê re.", "Bi tenê rêzikên alfabeyê bê jiyana civakî.", "Bi tenê rêyên bazirganiyê.", "Bi tenê dîroka çiyayên Zagrosê.", "A", "Navê dosyayê zimanê bi jiyan û perwerdehiya civakî re dide hev; ew zimanê wekî mijareke jêbirî nayê dîtin.", "Science and Language of Life"),
    ("Edebiyat", 2, "Di dosyaya «Jineolojî wekî xweparastinê» de, xweparastin çi tê wate kirin?", "Tenê parastina leşkerî nîne; zanîn, rêxistin û parastina jiyanê jî dihewîne.", "Tenê parastina arşîvan e.", "Tenê parastina peyvên klasîk ên edebiyatê ye.", "Tenê parastina mal û milkê kesane ye.", "A", "Lîsteya kovarê xweparastinê wekî mijareke Jineolojî dide nîşandan; di vê çarçoveyê de ew dikare zanîn, rêxistin û parastina jiyanê jî dihewîne.", "Jineolojî as Self-Defense"),
    ("Edebiyat", 3, "Di pirtûka Women in the Kurdish Movement de, rola jinan di tevgerê de bi kîjan du aliyan re tê xwendin?", "Bi dijberiya rolên ferzkirî û avakirina nasnameyên siyasî yên nû.", "Bi tenê bi dabeşkirina navên bajar û çiyayan.", "Bi tenê bi karê arşîvkirina wêneyan.", "Bi tenê bi guherandina alfabeya kovaran.", "A", "Danasîna pirtûkê li ser jinên ku rolên li ser wan hatine ferz kirin diguherînin û di tevgera siyasî de nasnameyên xwe ava dikin raweste.", "Women in the Kurdish Movement – Springer"),
    ("Dîrok", 2, "Li gorî lîsteya dosyayên Jineolojî Dergisî, kîjan mijar bi perwerdehiya civakî re rasterast têkildar e?", "Polîtîkayên perwerdehiyê.", "Tenê dîroka ronahiyê.", "Tenê geologyaya çiyan.", "Tenê rêzikên çapkirina rojnameyan.", "A", "Di lîsteya kovarê de «Polîtîkayên perwerdehiyê» wekî dosyayeke cuda hatiye lîstekirin û mijara perwerdehiya civakî dixe pêş.", "Education Policies"),
    ("Dîrok", 3, "Di lîsteya kovarê de, «Sedsala jinan» wekî çi tê pêşkêşkirin?", "Wekî mijareke li ser rola jinan û dîroka civakî di sedsala 21an de.", "Wekî navê kovara Hawarê ya sala 1932an.", "Wekî navê yek ji çiyayên Rojava.", "Wekî ferhengoka Ehmedê Xanî.", "A", "Dosyaya «Sedsala jinan» mijara jinan di sedsala 21an de dixe navendê; ew ne navê kovar, çiya an ferhengokê ye.", "21st Century; Women’s Century"),
    ("Çand", 2, "Di dosyaya «Civîna azad; çima û çawa?» de, mijara sereke çi ye?", "Çawa dikare jiyana hevpar li ser bingehên azadî û wekheviyê bê avakirin.", "Çawa dikare tenê yek kom li ser hemû civakê biryar bide.", "Çawa dikare kovar bêyî nivîskar bêne çapkirin.", "Çawa dikare çiyayek bê nexşe bê pîvan.", "A", "Navê dosyayê pirsa çima û çawa ya civîna azad dike pêş; ev mijar li ser awayên jiyana hevpar û têkiliyên wekhev raweste.", "Free Coexistence; Why, How?"),
    ("Çand", 3, "Di lîsteya Jineolojî Dergisî de, «krîza çandê» bi kîjan nêzîkatiyê re tê pêşkêşkirin?", "Bi lêgerîna rêyên derketinê ji krîzê.", "Bi qebûlkirina krîzê wekî tiştekî ku nayê lêkolînkirin.", "Bi veguhastina krîza çandê bo mijara geologyayê.", "Bi rakirina çandê ji her gotûbêjê.", "A", "Dîroka kovarê dosyayek bi navê «Krîza çandê û rêyên derketinê» dide naskirin; navê wê lêkolîn û çareseriyê bi hev re dike.", "Cultural Crisis and Ways Out of Crisis"),
    ("Siyaset", 3, "Di lîsteya dosyayên Jineolojî Dergisî de, «siyaseta demokratîk» bi kîjan mijarê re dikare were xwendin?", "Bi awayên beşdarbûn û biryargirtina civakê.", "Bi tenê dîroka çapemeniyê.", "Bi tenê teknîka stranbêjiyê.", "Bi tenê şertên avhewaya herêmê.", "A", "Dosyaya siyaseta demokratîk di çarçoveya kovarê de bi mijarên civakî û rêxistinî re tê xwendin; beşdarbûn û biryargirtin du aliyên wê ne.", "Democratic Politics"),
    ("Siyaset", 3, "«Aboriya komunal a demokratîk» di lîsteya Jineolojî Dergisî de çi dide nîşandan?", "Aboriyê wekî mijareke civakî û rêxistinkirina hevpar dide nîqaşkirin.", "Aboriyê tenê wekî karê kesane dide pênasekirin.", "Aboriyê ji ekolojî û civakê bi tevahî cuda dike.", "Aboriyê tenê bi dîroka Hawarê re girê dide.", "A", "Navê dosyayê aboriya komunal û demokratîk bi hev re dide nîqaşkirin; ev nêzîkatî aboriyê di nav têkiliyên civakî de dixwîne.", "Democratic Communal Economy"),
    ("Paradigma", 3, "Di lîsteya Jineolojî Dergisî de, «jiyana ekolojîk» ji kîjan duduya têgehî re nêzîk e?", "Ji têkiliya civakê, jinan û xwezayê re.", "Ji têkiliya alfabeyê û hesabkirina bacan re.", "Ji têkiliya dîroka Hawarê û muzîka klasîk re.", "Ji têkiliya bajarên Ewropayê û ferhengokên erebî re.", "A", "Dosyaya jiyana ekolojîk di lîsteya kovarê de li kêleka dosyayên jin, civak û jiyanê tê dîtin; ev yek têkiliya civak û xwezayê dixe pêş.", "Ecological Life"),
    ("Paradigma", 3, "Di lîsteya kovarê de, «organîzekirina potansiyela azadiyê: tevgerên civakî» li ser çi raweste?", "Li ser hêza rêxistin û tevgerên civakî ji bo avakirina azadiyê.", "Li ser tenê pêvajoya çapkirina pirtûkekê.", "Li ser tenê dabeşkirina navên çiyan.", "Li ser tenê formên muzîka klasîk.", "A", "Navê dosyayê potansiyela azadiyê bi rêxistin û tevgerên civakî re girêdide; azadî li vir wekî pêvajoya hevpar tê xwendin.", "Organizing the Potential of Freedom: Social Movements"),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note"]

def q(value):
    return "'" + value.replace("'", "''") + "'"

def main():
    with CSV_OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for i, row in enumerate(ROWS, 1):
            category, difficulty, prompt, a, b, c, d, correct, explanation, title = row
            w.writerow({"id": f"movement5_{i:04d}", "category_key": category, "language_code": "ku-kmr", "prompt": prompt, "option_a": a, "option_b": b, "option_c": c, "option_d": d, "correct_option": correct, "explanation": explanation, "difficulty": difficulty, "source_title": title, "source_url": "https://link.springer.com/book/10.1007/978-3-030-24744-7" if "Springer" in title else SRC, "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "Hareket basın/yayın veya kitap kaynağından elle yazıldı; ikinci editoryal kontrol bekliyor."})
    values = []
    for category, difficulty, prompt, a, b, c, d, correct, explanation, title in ROWS:
        url = "https://link.springer.com/book/10.1007/978-3-030-24744-7" if "Springer" in title else SRC
        values.append("(" + ", ".join(["(select id from public.categories where name = " + q(category) + ")", q("ku-kmr"), q(prompt), q(a), q(b), q(c), q(d), q(correct), q(explanation), str(difficulty), "false", q("multiple_choice"), "NULL", q("movement_sources_question_wave_5")]) + ")")
    SQL_OUT.write_text("-- Hareket basın-yayın kaynaklarından üretilen beşinci el yazımı paket.\n-- Canlı yayın için onaylanmadı.\ninsert into public.questions (category_id, language_code, prompt, option_a, option_b, option_c, option_d, correct_option, explanation, difficulty, is_approved, question_type, image_url, source_url) values\n" + ",\n".join(values) + ";\n", encoding="utf-8")
    print(f"wrote {len(ROWS)} rows")

if __name__ == "__main__":
    main()
