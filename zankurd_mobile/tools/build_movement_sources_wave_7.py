import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_OUT = ROOT / "supabase" / "2026-07-14_movement_sources_question_wave_7.csv"
SQL_OUT = ROOT / "supabase" / "2026-07-14_movement_sources_question_wave_7.sql"
SRC = "https://jineoloji.eu/en/2025/06/29/jineoloji-magazine-at-10-years-old-the-reunion-of-knowledge-stolen-from-women-with-women-part-1/"

ROWS = [
    ("Ziman", 2, "Di dosyayên «Rêbazên berxwedana jinan I û II» de, çima du dosya ji hev hatine veqetandin?", "Ji ber ku berxwedana jinan dikare gelek rêbaz û formên cuda dihewîne.", "Ji ber ku yek ji dosyayan li ser geologyayê ye.", "Ji ber ku yek ji dosyayan tenê ferhengok e.", "Ji ber ku du dosya heman navê kovarê ne.", "A", "Lîsteya kovarê du dosyayên li ser rêbazên berxwedana jinan dide nîşandan; ev dabeşkirin cûrbecûrbûna formên berxwedanê nîqaş dike.", "Women’s Resistance Methods I and II"),
    ("Ziman", 3, "Di dosyaya «Rêbaz û rastiya jinan» de, rastî bi kîjan çavkaniyê re tê pêwendîkirin?", "Bi ezmûn û dîtina jinan di jiyan û civakê de.", "Bi tenê bi rêzikên gramerê yên zimanekî re.", "Bi tenê bi nexşeya cografî ya herêmê re.", "Bi tenê bi navê sazîyên siyasî re.", "A", "Navê dosyayê rêbaz û rastiya jinan bi hev re dide nîqaşkirin û ezmûna jinan wekî çavkaniya fêmkirinê dixe pêş.", "Method and Truth Based on Women’s Reality"),
    ("Edebiyat", 2, "Di lîsteya Jineolojî Dergisî de, «xweparastina Jineolojî» bi kîjan wateyê re zêdetir nêzîk e?", "Bi parastina jiyanê, zanînê û hêza rêxistinê re, ne tenê bi çekê re.", "Bi tenê bi parastina pirtûkên kevn re.", "Bi tenê bi parastina navên bajarên dîrokî re.", "Bi tenê bi parastina muzîkê re.", "A", "Dosyaya xweparastinê di lîsteya kovarê de wekî mijareke Jineolojî tê; şirovekirina wê dikare parastina jiyan, zanîn û rêxistinê jî dihewîne.", "Jineolojî as Self-Defense"),
    ("Edebiyat", 3, "Di lîsteya Jineolojî Dergisî de, «Rêyên derketina ji krîza çandê» çi cureyê nivîsê nîşan dide?", "Nivîsek lêkolînî û çareseriyê ku krîzê nas dike û li rêyan digere.", "Nivîsek tenê li ser navên şairan.", "Nivîsek tenê li ser şêwaza çêkirina amûrên muzîkê.", "Nivîsek tenê li ser şertên avhewayê.", "A", "Sernavê dosyayê hem krîza çandê hem jî rêyên derketinê dide nîşandan; mijar tenê nasandin nîne, lêgerîna çareseriyê jî heye.", "Cultural Crisis and Ways Out of Crisis"),
    ("Dîrok", 2, "Di dîroka dosyayên Jineolojî Dergisî de, kîjan mijar li ser sedsala 21an tê lîstekirin?", "Sedsala jinan.", "Ronahî ya sala 1942an.", "Rojnameya Kurdistanê ya sala 1898an.", "Dîroka Memê Alan.", "A", "Di lîsteya 33 dosyayan de «Sedsala jinan» wekî mijareke ji bo sedsala 21an hatiye lîstekirin.", "21st Century; Women’s Century"),
    ("Dîrok", 3, "Di lîsteya kovarê de, «Rojhilat, Bakur, Rojava û Başûr» çi cureyê dabeşkirinê ye?", "Dabeşkirina qadên Kurdistanê ji bo nîqaş û lêkolînên herêmî.", "Dabeşkirina çar cureyên alfabeyê.", "Dabeşkirina çar komên muzîkê.", "Dabeşkirina çar navên pirtûkan.", "A", "Ev navên herêmî di lîsteya kovarê de wekî dosyayên taybet cih digirin û qadên cuda yên Kurdistanê nîşan didin.", "Rojhilat, Bakur, Rojava, Bashur"),
    ("Çand", 2, "Di dosyaya «Rêxistina potansiyela azadiyê: tevgerên civakî» de, tevgerên civakî çi dikin?", "Hêza civakê li dora azadiyê rêxistin dikin.", "Tenê kovarên kevn li gorî salê rêz dikin.", "Tenê nexşeyên çiyan dikin.", "Tenê peyvên stranên olî kom dikin.", "A", "Sernavê dosyayê tevgerên civakî bi rêxistina potansiyela azadiyê re girêdide û rola rêxistinê dixe pêş.", "Organizing the Potential of Freedom: Social Movements"),
    ("Çand", 3, "Di lîsteya kovarê de, «jiyana hevpar a azad; çima, çawa?» ji kîjan pirsa civakî dest pê dike?", "Çawa dikare mirovan bi azadî û wekhevî li hev bijîn.", "Çawa dikare tenê yek kes hemû biryaran bide.", "Çawa dikare çand ji jiyanê were veqetandin.", "Çawa dikare civak bê gotûbêjê were rêxistin.", "A", "Sernavê dosyayê pirsa çima û çawa ya jiyana hevpar a azad dike pêş û bi awayên jiyana wekhev re têkildar e.", "Free Coexistence; Why, How?"),
    ("Siyaset", 3, "Di dosyaya «Aboriya komunal a demokratîk» de, peyva komunalê çi dide nîşandan?", "Ku aborî bi hevkarî û bi beşdarbûna civakê tê nîqaşkirin.", "Ku aborî tenê karê kesekî ye.", "Ku aborî ji çand û civakê cuda ye.", "Ku aborî tenê navê kovareke dîrokî ye.", "A", "Pêwendiya «demokratîk» û «komunal» di sernavê dosyayê de aboriyê bi hevkarî û beşdarbûna civakê re girêdide.", "Democratic Communal Economy"),
    ("Siyaset", 3, "Di lîsteya Jineolojî Dergisî de, «îzolasyon û girtin» wekî kîjan cureyê mijarê tê pêşkêşkirin?", "Wekî pirsgirêkeke siyasî û civakî ya ku divê bê lêkolînkirin.", "Wekî navê cureyekî muzîkê.", "Wekî navê alfabeyeke nû.", "Wekî navê çiyayekî li Rojava.", "A", "Navê dosyayê îzolasyon û girtinê wekî mijareke siyasî-civakî dixe nav gotûbêjê; ew ne navê muzîk, alfabe an çiya ye.", "Isolation and Closure"),
    ("Paradigma", 3, "Di dosyaya «Kolonyalîzma li ser bingeha olparêziyê» de, çi têkiliya tê pêşkêşkirin?", "Têkiliya hêz, olparêzî û pêvajoyên kolonyalîzmê.", "Têkiliya muzîk û geologyayê.", "Têkiliya alfabeya Hawarê û ferhengoka Xanî.", "Têkiliya dengbêjî û avakirina kooperatîfan.", "A", "Sernavê dosyayê olparêzî û kolonyalîzmê bi hev re dide nîqaşkirin û li ser têkiliyên hêzê raweste.", "Religionism-Based Colonialism and Women’s Massacre Policies"),
    ("Paradigma", 3, "Di lîsteya kovarê de, «demografî» çima dikare wekî mijareke siyasî-civakî were xwendin?", "Ji ber ku nifûs, jiyan û dabeşbûna civakê bi biryar û hêzê re têkildar in.", "Ji ber ku demografî tenê hesabkirina çiyan e.", "Ji ber ku demografî tenê navê pirtûkekê ye.", "Ji ber ku demografî ji civakê bi tevahî cuda ye.", "A", "Dosyaya demografiyê di nav lîsteya kovarê de li kêleka siyaset, civak û jiyanê ye; nifûs û dabeşbûna civakê dikarin aliyên siyasî-civakî jî hebin.", "Demography"),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note"]

def q(v): return "'" + v.replace("'", "''") + "'"

def main():
    with CSV_OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS); w.writeheader()
        for i, row in enumerate(ROWS, 1):
            category, difficulty, prompt, a, b, c, d, correct, explanation, title = row
            w.writerow({"id": f"movement7_{i:04d}", "category_key": category, "language_code": "ku-kmr", "prompt": prompt, "option_a": a, "option_b": b, "option_c": c, "option_d": d, "correct_option": correct, "explanation": explanation, "difficulty": difficulty, "source_title": title, "source_url": SRC, "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "Hareket basın/yayın kaynağından elle yazıldı; ikinci editoryal kontrol bekliyor."})
    values=[]
    for category, difficulty, prompt, a, b, c, d, correct, explanation, title in ROWS:
        values.append("(" + ", ".join(["(select id from public.categories where name = " + q(category) + ")", q("ku-kmr"), q(prompt), q(a), q(b), q(c), q(d), q(correct), q(explanation), str(difficulty), "false", q("multiple_choice"), "NULL", q("movement_sources_question_wave_7")]) + ")")
    SQL_OUT.write_text("-- Hareket basın-yayın kaynaklarından üretilen yedinci el yazımı paket.\n-- Canlı yayın için onaylanmadı.\ninsert into public.questions (category_id, language_code, prompt, option_a, option_b, option_c, option_d, correct_option, explanation, difficulty, is_approved, question_type, image_url, source_url) values\n" + ",\n".join(values) + ";\n", encoding="utf-8")
    print(f"wrote {len(ROWS)} rows")

if __name__ == "__main__": main()
