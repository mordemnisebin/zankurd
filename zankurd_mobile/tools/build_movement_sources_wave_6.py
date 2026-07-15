import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_OUT = ROOT / "supabase" / "2026-07-14_movement_sources_question_wave_6.csv"
SQL_OUT = ROOT / "supabase" / "2026-07-14_movement_sources_question_wave_6.sql"
SRC = "https://jineoloji.eu/en/2025/06/29/jineoloji-magazine-at-10-years-old-the-reunion-of-knowledge-stolen-from-women-with-women-part-1/"

ROWS = [
    ("Ziman", 2, "Di lîsteya Jineolojî Dergisî de, «zayendîtiyê: ji pîrozahiyê ber bi îdeolojiya hêzê» bi kîjan qadê re têkildar e?", "Bi têkiliyên zayendî, beden û hêzê re.", "Bi tenê bi dîroka alfabeya Hawarê re.", "Bi tenê bi rêbazên pîvandina çiyan re.", "Bi tenê bi ferhengoka peyvên aborî re.", "A", "Navê dosyayê zayendîtiyê ji pîrozahî ber bi îdeolojiya hêzê dide nîqaşkirin û têkiliya beden, zayend û hêzê dixe pêş.", "Sexuality, From Sacredness to Power Ideology"),
    ("Ziman", 3, "Di dosyaya «kolonyalîzm û polîtîkayên komkujiyê yên jinan» de, peyva kolonyalîzmê bi kîjan pêvajoyê re tê xwendin?", "Bi pêvajoyên serdestiyê û bandora wan li ser jinan û civakê re.", "Bi tenê bi çêkirina ferhengokên zimanî re.", "Bi tenê bi rêxistina konseran re.", "Bi tenê bi avakirina rêyên hesinî re.", "A", "Navê dosyayê kolonyalîzmê bi polîtîkayên serdestiyê û komkujiyê yên li ser jinan re dide têkildar kirin.", "Colonialism"),
    ("Edebiyat", 2, "Di lîsteya kovarê de, «nîqaşên malbatê» çi dide nîşandan?", "Malbat wekî mijareke civakî û qadeke gotûbêjê tê lêkolînkirin.", "Malbat tenê wekî navê yekîneyeke arşîvê tê bikaranîn.", "Malbat bi dîroka çiyayên Zagrosê re heman wateyê dide.", "Malbat tenê wekî cureyekî muzîkê tê pênasekirin.", "A", "Navê dosyayê nîqaşên malbatê dixe navendê û malbatê wekî mijareke civakî ya tê nîqaşkirin pêşkêş dike.", "Family Discussions"),
    ("Edebiyat", 3, "Pirtûkxaneya Jinên Kurdistanê Jineolojî bi kîjan awayî dide pêşkêşkirin?", "Wekî zanista jinê û jiyanê ku ji ezmûnên têkoşîna jinan tê xwarin.", "Wekî ferhengoka peyvên erebî ya ji bo dibistanê.", "Wekî dîroka kovara Ronahî ya li Şamê.", "Wekî pirtûka tenê li ser geologyaya çiyayên Kurdistanê.", "A", "Danasîna pirtûkxanê Jineolojî wekî zanista jinê û jiyanê dide pênasekirin û wê bi ezmûnên têkoşînên jinan ve girê dide.", "Kurdish Women’s Library – What is Jineolojî"),
    ("Dîrok", 2, "Di lîsteya dosyayên Jineolojî Dergisî de, «Rojhilat, Bakur, Rojava, Başûr» çi dide nîşandan?", "Ku kovar ji bo her çar qadên Kurdistanê dosyayên taybet jî amade kiriye.", "Ku kovar tenê li Rojava hatiye çapkirin.", "Ku ev nav hemû navên çiyayên herêmê ne.", "Ku ev navên çar alfabeyên Kurdî ne.", "A", "Di lîsteya kovarê de dosyayên bi navên Rojhilat, Bakur, Rojava û Başûr cih digirin; ev dabeşkirina qadên Kurdistanê ye.", "Rojhilat, Bakur, Rojava, Bashur"),
    ("Dîrok", 3, "Di lîsteya Jineolojî Dergisî de, «dîmdemografî» bi kîjan mijarê re tê girêdan?", "Bi şert û pêvajoyên nifûsê û têkiliyên wan bi civakê re.", "Bi tenê bi dîroka kovaran re.", "Bi tenê bi rêzikên stranên dengbêjan re.", "Bi tenê bi avhewaya çiyayên Bahtiyarî re.", "A", "Dosyaya demografiyê mijarên nifûsê û têkiliyên wan bi rêxistina civakê re dixe nav gotûbêjê.", "Demography"),
    ("Çand", 2, "Di lîsteya dosyayên Jineolojî Dergisî de, «nîqaşên ciwanan» çi dide pêş?", "Cih û pirsgirêkên ciwanan di civakê û tevgerên civakî de.", "Tenê dîroka çapkirina pirtûkên klasîk.", "Tenê rêzikên hesabkirina aborî.", "Tenê cûreyên darên Zagrosê.", "A", "Navê dosyayê ciwanan wekî qadeke civakî ya tê nîqaşkirin nîşan dide; mijara wê ji pirtûk û geologyayê cuda ye.", "Youth Discussions"),
    ("Çand", 3, "Di nav 33 dosyayên Jineolojî Dergisî de, kîjan dosya rasterast bi ziman û çandê re têkildar e?", "Krîza çandê û rêyên derketinê ji wê.", "Tenê konfederalîzma jinan.", "Tenê dîroka siyasî ya Kurdistanê.", "Tenê xweza û rûberûbûna çiyan.", "A", "Di lîsteya dosyayan de krîza çandê wekî mijareke cuda hatiye dîtin û bi rêyên derketinê re hatiye girêdan.", "Cultural Crisis and Ways Out of Crisis"),
    ("Siyaset", 3, "Di lîsteya kovarê de, «kolonyalîzm» û «siyaseta demokratîk» çi nîşan didin?", "Kovar hem serdestî û kolonyalîzmê hem jî rêyên siyaseta demokratîk wekî mijarên cuda lêkolîn dike.", "Kovar tenê li ser kolonyalîzmê raweste û siyaseta demokratîk qet nabêje.", "Kovar hemû mijarên siyasî ji nav dibe.", "Kovar ev navan tenê ji bo navên dosyayan bê wate bi kar tîne.", "A", "Di lîsteya kovarê de kolonyalîzm û siyaseta demokratîk wekî du dosyayên cuda hene; ev yek berfirehiya gotûbêja siyasî nîşan dide.", "Colonialism; Democratic Politics"),
    ("Siyaset", 3, "«Konfederalîzma jinan» di lîsteya Jineolojî Dergisî de bi kîjan têgehê re têkildar tê xwendin?", "Bi rêxistina jinan û avakirina têkiliyên siyasî yên hevpar re.", "Bi tenê bi dabeşkirina zaravayên Kurdî re.", "Bi tenê bi parastina wêneyên arşîvê re.", "Bi tenê bi çêkirina ferhengokê re.", "A", "Dosyaya konfederalîzma jinan li ser rêxistina jinan û têkiliyên wan di qadên siyasî-civakî de dixe nîqaşê.", "Women’s Confederalism"),
    ("Paradigma", 3, "Di dosyaya «Jiyana ekolojîk» de, têkiliya xweza û civakê bi kîjan nêzîkatiyê tê dîtin?", "Wekî têkiliyeke hevpar ku li ser awayê jiyanê û rêxistina civakê bandor dike.", "Wekî du qadên ku qet hev nakevin.", "Wekî mijarek tenê ji bo nexşeyên erdnîgarî.", "Wekî mijarek ku tenê bi muzîkê re têkildar e.", "A", "Navê dosyayê jiyana ekolojîkê bi jiyan û civakê re dide hev; nêzîkatiya wê têkiliya xweza û civakê wekî têkiliyeke hevpar dixwîne.", "Ecological Life"),
    ("Paradigma", 3, "Di lîsteya Jineolojî Dergisî de, «ji zanistparêziyê derbasbûn» çi dide nîqaşkirin?", "Sînor û şertên zanîna ku xwe tenê bi metodên serdest re nas dike.", "Tenê rêbazên çêkirina kovarê.", "Tenê dîroka çiyayên Kurdistanê.", "Tenê dabeşkirina muzîkê li ser amûran.", "A", "Navê dosyayê ji derbasbûna zanistparêziyê re têkildar e û sînorên zanîna serdest dixe nîqaşê.", "Transcending Scientism"),
]

FIELDS = ["id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d", "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note"]

def q(v): return "'" + v.replace("'", "''") + "'"

def main():
    with CSV_OUT.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS); w.writeheader()
        for i, row in enumerate(ROWS, 1):
            category, difficulty, prompt, a, b, c, d, correct, explanation, title = row
            url = "https://pirtukxaneyajinenkurdistan.com/en/post/what-is-jineoloji/" if "Kurdish Women" in title else SRC
            w.writerow({"id": f"movement6_{i:04d}", "category_key": category, "language_code": "ku-kmr", "prompt": prompt, "option_a": a, "option_b": b, "option_c": c, "option_d": d, "correct_option": correct, "explanation": explanation, "difficulty": difficulty, "source_title": title, "source_url": url, "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": "Hareket basın/yayın kaynağından elle yazıldı; ikinci editoryal kontrol bekliyor."})
    values=[]
    for category, difficulty, prompt, a, b, c, d, correct, explanation, title in ROWS:
        url = "https://pirtukxaneyajinenkurdistan.com/en/post/what-is-jineoloji/" if "Kurdish Women" in title else SRC
        values.append("(" + ", ".join(["(select id from public.categories where name = " + q(category) + ")", q("ku-kmr"), q(prompt), q(a), q(b), q(c), q(d), q(correct), q(explanation), str(difficulty), "false", q("multiple_choice"), "NULL", q("movement_sources_question_wave_6")]) + ")")
    SQL_OUT.write_text("-- Hareket basın-yayın kaynaklarından üretilen altıncı el yazımı paket.\n-- Canlı yayın için onaylanmadı.\ninsert into public.questions (category_id, language_code, prompt, option_a, option_b, option_c, option_d, correct_option, explanation, difficulty, is_approved, question_type, image_url, source_url) values\n" + ",\n".join(values) + ";\n", encoding="utf-8")
    print(f"wrote {len(ROWS)} rows")

if __name__ == "__main__": main()
