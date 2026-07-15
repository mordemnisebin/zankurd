import csv
import io
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT_CSV = ROOT / "supabase" / "2026-07-14_handcrafted_question_wave_1.csv"
OUT_SQL = ROOT / "supabase" / "2026-07-14_handcrafted_question_wave_1.sql"


ROWS = [
    {
        "id": "handcrafted_0001", "category_key": "Ziman", "difficulty": 2,
        "prompt": "Di kovara Hawarê de, piştî jimareya 23an çi guherî?",
        "a": "Kovara Hawarê bi tevahî rawestiya.",
        "b": "Hemû nivîs tenê bi alfabeya erebî hatin çapkirin.",
        "c": "Kovara Hawarê ji Şamê birêve çû Stenbolê.",
        "d": "Nivîsa Kurmancî tenê bi alfabeya latînî hate çapkirin.",
        "correct": "D",
        "explanation": "Li gorî arşîva Hawarê, 23 jimareyên ewil bi her du alfabeyan hatin çapkirin; ji jimareya 24an ve kovar tenê alfabeya latînî bi kar anî.",
        "source_title": "Hawar Archive – NYKCC", "source_url": "https://nykcc.org/langauge/hawar-archive/",
        "quality_note": "Soru, tek bir tarih yerine yayının alfabe geçişini sorgular; şıklar aynı olayın olası ama yanlış yorumlarıdır.",
    },
    {
        "id": "handcrafted_0002", "category_key": "Ziman", "difficulty": 3,
        "prompt": "Li gorî lêkolîna li ser wêjeya nivîskî ya Kurdî, dibistana Kurmancî ya klasîk bi taybetî bi kîjan herêmê ve tê girêdan?",
        "a": "Herêma Jazira û Botan",
        "b": "Herêma Farsê ya navîn",
        "c": "Geliyê Nilê ya li Misrê",
        "d": "Giravên Egeyê",
        "correct": "A",
        "explanation": "Lêkolîn dibêje ku dibistana Kurmancî ya klasîk zimanê edebî yê Jazira û Botan bikar aniye û navên wekî Melayê Cizîrî, Feqiyê Teyran û Ehmedê Xanî di nav pêşengên wê de ne.",
        "source_title": "Kurdish Written Literature – Encyclopaedia Iranica", "source_url": "https://www.iranicaonline.org/articles/kurdish-written-literature/",
        "quality_note": "Şıklar coğrafi olarak aynı türden tutuldu; doğru cevap yalnızca isim eşleştirmesiyle bulunmuyor.",
    },
    {
        "id": "handcrafted_0003", "category_key": "Edebiyat", "difficulty": 3,
        "prompt": "Kîjan taybetmendî forma helbestê ya Feqiyê Teyran girîng dike?",
        "a": "Ew yekem helbestvanê naskirî yê Kurdî ye ku ji bo helbestên vegotinê forma mesnewî bikar aniye.",
        "b": "Ew tenê nivîsarên rêzimanî di kovara Hawarê de diweşand.",
        "c": "Ew romana Mem û Zîn nivîsî.",
        "d": "Ew yekem nivîskarê Kurdî ye ku hemû berhemên xwe bi latînî nivîsî.",
        "correct": "A",
        "explanation": "Encyclopaedia Iranica Feqiyê Teyran wekî yekem helbestvanê naskirî yê Kurdî dide nasîn ku forma mesnewî ji bo helbestên vegotinê bikar aniye.",
        "source_title": "Kurdish Written Literature – Encyclopaedia Iranica", "source_url": "https://www.iranicaonline.org/articles/kurdish-written-literature/",
        "quality_note": "Çeldiriciler aynı edebiyat alanından seçildi; yanlışlar başka isim ve dönemleri karıştırıyor.",
    },
    {
        "id": "handcrafted_0004", "category_key": "Edebiyat", "difficulty": 2,
        "prompt": "Berhema Nûbihara Biçûkan a Ehmedê Xanî bi çi awayî tê pênasekirin?",
        "a": "Destanek dirêj a li ser evîna Mem û Zînê",
        "b": "Ferhengokek bi helbestê ku peyvên erebî bi wateyên Kurmancî re dide hev.",
        "c": "Kovarek siyasî ya ku li Şamê dihat weşandin.",
        "d": "Dîwanek tenê ji gazelên Melayê Cizîrî pêkhatî.",
        "correct": "B",
        "explanation": "Nûbihara Biçûkan ferhengokeke erebî-Kurmancî ye ku bi helbestê hatiye nivîsandin û ji bo xwendekarên dibistanê hatiye armanc kirin.",
        "source_title": "Ahmad-e Khani – Encyclopaedia Iranica", "source_url": "https://www.iranicaonline.org/articles/ahmad-e-kani/",
        "quality_note": "Soru, Xanî'yi yalnızca Mem û Zîn ile sınırlamayan tamamlayıcı bir bilgi ölçüyor.",
    },
    {
        "id": "handcrafted_0005", "category_key": "Dîrok", "difficulty": 2,
        "prompt": "Dîroka weşandina Hawarê kîjan rêzê rast nîşan dide?",
        "a": "1932–1935, paşê 1941–1943",
        "b": "1898–1902, paşê 1910–1912",
        "c": "1946–1950, paşê 1960–1963",
        "d": "1919–1923 bê rawestan",
        "correct": "A",
        "explanation": "Hawar li Şamê di navbera 1932 û 1935an de, û piştî navberekê dîsa di navbera 1941 û 1943an de hate weşandin.",
        "source_title": "Hawar Archive – NYKCC", "source_url": "https://nykcc.org/langauge/hawar-archive/",
        "quality_note": "Tarih seçenekleri yakın tutuldu; tek bir yıl ezberinden çok yayın dönemini ölçüyor.",
    },
    {
        "id": "handcrafted_0006", "category_key": "Dîrok", "difficulty": 3,
        "prompt": "Rojnameya Kurdistanê ya ku di sala 1898an de dest pê kir, li ku derê hat weşandin û kî wê damezrand?",
        "a": "Li Qahîreyê, ji aliyê Mîqdat Midhat Bedirxan ve",
        "b": "Li Şamê, ji aliyê Celadet Bedirxan ve",
        "c": "Li Silêmaniyê, ji aliyê Pîremêrd ve",
        "d": "Li Stenbolê, ji aliyê Melayê Cizîrî ve",
        "correct": "A",
        "explanation": "Rojnameya Kurdistanê di sala 1898an de li Qahîreyê ji aliyê Mîqdat Midhat Bedirxan ve hate destpêkirin.",
        "source_title": "The First Kurdish Newspaper – Kurdshop", "source_url": "https://kurdshop.net/en/history/3014",
        "quality_note": "Benzer Bedirxan isimleri ve farklı şehirler bilinçli çeldirici olarak kullanıldı.",
    },
    {
        "id": "handcrafted_0007", "category_key": "Cografya", "difficulty": 3,
        "prompt": "Di dîroka erdnîgariya îslamî de, navê Jibal bi kîjan herêmê re zêdetir tê girêdan?",
        "a": "Bi beşa navîn a zincîra Zagrosê, ku Kurdistan û Luristan dihewîne",
        "b": "Bi deşta Nilê ya li bakurê Afrîkayê",
        "c": "Bi herêma peravê ya li rojhilatê Deryaya Reş",
        "d": "Bi giravên ku li navbera Hindistan û Sri Lanka ne",
        "correct": "A",
        "explanation": "Di bikaranîna dîrokî de Jibal navê herêmeke çiyayî û newalî bû ku beşa navîn a Zagrosê, di nav de Kurdistan û Luristan, dihewand.",
        "source_title": "Jebal – Encyclopaedia Iranica", "source_url": "https://www.iranicaonline.org/articles/jebal/",
        "quality_note": "Soru, eski coğrafi adlandırmayı günümüz sınırlarıyla eşitleme hatasını azaltacak biçimde yazıldı.",
    },
    {
        "id": "handcrafted_0008", "category_key": "Cografya", "difficulty": 3,
        "prompt": "Kîjan agahî li ser Çiyayên Bahtiyarî rast e?",
        "a": "Ew beşek navîn a zincîra Zagrosê ne û Zardkûh li wan e.",
        "b": "Ew li navenda deşta Mezopotamyayê ne û çiyayên Zagrosê ji wan dûr in.",
        "c": "Ew navê çemekî ye ku ji Deryaya Reş derdikeve.",
        "d": "Ew zincîra çiyayên li bakurê Ewropayê ye.",
        "correct": "A",
        "explanation": "Çiyayên Bahtiyarî beşa navîn û herî bilind a pergala Zagrosê pêk tînin; Zardkûh jî li vê pergala çiyayî ye.",
        "source_title": "Bakhtiyari Mountains – Encyclopaedia Iranica", "source_url": "https://www.iranicaonline.org/articles/baktiari-mountains-of-the-zagros-range/",
        "quality_note": "Doğru şık iki coğrafi ilişkiyi birlikte kuruyor; yanlışlar farklı coğrafi nesne türleriyle karıştırmıyor, fakat anlamlı alternatifler sunuyor.",
    },
    {
        "id": "handcrafted_0009", "category_key": "Çand", "difficulty": 3,
        "prompt": "Di çîroka populer a Memê Alan de, çima tê gotin ku wê çîrokê bi taybetî li herêmên Kurmancîaxê re têkildar e?",
        "a": "Ji ber ku gelek guhertoyên devkî yên çîrokê li wan herêman hatine tomarkirin.",
        "b": "Ji ber ku çîrok tenê di kovara Hawarê de hatiye nivîsandin.",
        "c": "Ji ber ku Memê Alan navê yek ji çiyayên Zagrosê ye.",
        "d": "Ji ber ku çîrok bi eslê xwe ferhengokeke erebî ye.",
        "correct": "A",
        "explanation": "Lêkolînên li ser Memê Alan dibêjin ku di forma populer de ev romans bi taybetî bi herêmên Kurmancîaxê re tê girêdan; ew tenê berhemeke nivîskî nîne.",
        "source_title": "Mem-e Alan – Encyclopaedia Iranica", "source_url": "https://www.iranicaonline.org/articles/meme-alan/",
        "quality_note": "Soru, sözlü ve yazılı aktarım ayrımını ölçüyor; 'tek bir metin' yanılgısını özellikle engelliyor.",
    },
    {
        "id": "handcrafted_0010", "category_key": "Çand", "difficulty": 2,
        "prompt": "Dengbêjî di çanda devkî de bi kîjan erkê herî baş tê şirovekirin?",
        "a": "Bi veguhastina çîrok, destan, stran û bîranînan bi deng û gotinê",
        "b": "Bi nivîsandina hemû berhemên edebî bi yek alfabeyê",
        "c": "Bi amadekirina nexşeyên erdnîgarî ji bo rêwîtiyê",
        "d": "Bi komkirina tenê amûrên muzîkê yên kevn",
        "correct": "A",
        "explanation": "Dengbêjî kevneşopiyeke devkî ye ku çîrok, destan, stran û bîranîn bi deng, vegotin û tomarkirina hafîzeyê digihîne nifşên din.",
        "source_title": "Kurdish Art and Identity – Kurdipedia", "source_url": "https://www.kurdipedia.org/docviewer.aspx?book=20220816235906428748&lng=3",
        "quality_note": "Şıklar aynı kültürel alan çevresinde tutuldu; doğru cevap geleneğin işlevini anlatıyor.",
    },
    {
        "id": "handcrafted_0011", "category_key": "Muzîk", "difficulty": 2,
        "prompt": "Di performansa dengbêj de kîjan taybetmendî bingehîn e, lê amûra muzîkê şert nîne?",
        "a": "Amûra muzîkê ya ku her tim li pey dengê stranbêj dikeve.",
        "b": "Vegotina bi deng, bi stran û bi gotinê.",
        "c": "Pêdiviya ku hemû stran tenê bi notayên nivîskî bêne pêşkêşkirin.",
        "d": "Bikaranîna orkestraya mezin di her performansê de.",
        "correct": "B",
        "explanation": "Di kevneşopiya dengbêj de deng û vegotin bingeh in; hin performans dikarin bê amûrên muzîkê jî bêne kirin, ji ber vê yekê amûr şertê bingehîn nîne.",
        "source_title": "Dengbe-Lik and Melisma Technique – Batman University", "source_url": "https://dergipark.org.tr/tr/pub/buyasambid/article/320961",
        "quality_note": "Soru, 'müzik = mutlaka enstrüman' varsayımını sorguluyor; yanlışlar bilinçli olarak aşırı genelleme içeriyor.",
    },
    {
        "id": "handcrafted_0012", "category_key": "Muzîk", "difficulty": 2,
        "prompt": "Di peyva «dengbêj» de, «deng» û «bej» bi kîjan wateyên bingehîn re têne girêdan?",
        "a": "Reng û dîtin",
        "b": "Deng û gotin",
        "c": "Çiya û av",
        "d": "Roj û şev",
        "correct": "B",
        "explanation": "Di ravekirina peyvê de «deng» bi dengê mirovan, û «bej» bi gotin an vegotinê re tê girêdan; ev yek ji aliyên wateya dengbêjî ye.",
        "source_title": "The Dengbêj – Kurdipedia", "source_url": "https://kurdipedia.org/default.aspx/default.aspx?lng=4&q=20230727084402509827",
        "quality_note": "Kısa ama içerik taşıyan bir terminoloji sorusu; seçenekler biçimsel olarak benzer tutuldu.",
    },
    {
        "id": "handcrafted_0013", "category_key": "Siyaset", "difficulty": 3,
        "prompt": "Li gorî çarçoveya mafên mirovan, mafê beşdarbûna siyasî kîjan komê mafan dihewîne?",
        "a": "Tenê mafê dengdanê, bê mafê namzedbûnê",
        "b": "Beşdarbûna rasterast an bi nûnerên azad hilbijartî, dengdan û gihiştina wekhev bo karên giştî",
        "c": "Tenê mafê karê di sazîyekê de, bê mafê axaftinê",
        "d": "Tenê mafê endamtiya di partiyekê de, bê mafê dengdanê",
        "correct": "B",
        "explanation": "OHCHR beşdarbûna siyasî bi beşdarbûna rasterast an bi nûneran, mafê dengdanê û mafê gihiştina wekhev bo karên xizmeta giştî ve girê dide.",
        "source_title": "Human Rights and Elections – OHCHR", "source_url": "https://www.ohchr.org/Documents/Publications/Human-Rights-and-Elections.pdf",
        "quality_note": "Şıklar, katılımı yalnızca oy vermeye indirgeyen yaygın yanlış anlamaları ayırıyor.",
    },
    {
        "id": "handcrafted_0014", "category_key": "Siyaset", "difficulty": 3,
        "prompt": "Kîjan rewş mînakek ji beşdarbûna siyasî ya rasterast e?",
        "a": "Hemwelatiyek pêşniyarekê ji sazîya giştî re dişîne û di civînekî giştî de beşdar dibe.",
        "b": "Kesek tenê navê xwe di lîsteya stranên guhdarîkirî de dinivîse.",
        "c": "Kesek nexşeya malê xwe diguhezîne.",
        "d": "Kesek li ser dîroka malbata xwe dixwîne.",
        "correct": "A",
        "explanation": "Beşdarbûna siyasî ya rasterast dikare bi daxwaz, pêşniyar, axaftina giştî, kombûn an çalakiyên aştiyane yên civakî bê kirin; ew tenê dengdan nîne.",
        "source_title": "Handbook on Governance Statistics – OHCHR", "source_url": "https://www.ohchr.org/sites/default/files/Documents/Issues/HRIndicators/handbook_governance_statistics.pdf",
        "quality_note": "Soru tanımı günlük bir duruma taşıyor; üç yanlış seçenek siyaset dışı ama absürt olmayan eylemlerden seçildi.",
    },
    {
        "id": "handcrafted_0015", "category_key": "Paradigma", "difficulty": 3,
        "prompt": "Di analîza intersectionality de, çima tenê li ser yek cudahiyê, wekî zayendê, rawestan dikare kêmasî be?",
        "a": "Ji ber ku hemû kes di civakê de heman ezmûnê dijîn.",
        "b": "Ji ber ku şertên wekî zayend, nijad, çîn û seqemahî dikarin bi hev re bandorê li ezmûn û hêzê bikin.",
        "c": "Ji ber ku analîz divê tenê li ser dîroka dewletan be.",
        "d": "Ji ber ku cudahiyên civakî bi awayekî zanistî nayên lêkolînkirin.",
        "correct": "B",
        "explanation": "Intersectionality dişopîne ka çawa gelek xetên nasname û tunekirinê bi hev re û ne tenê bi awayekî cudaye bandorê li jiyana mirovan dikin.",
        "source_title": "Feminist Metaphysics – Stanford Encyclopedia of Philosophy", "source_url": "https://plato.stanford.edu/entries/feminism-metaphysics/",
        "quality_note": "Kavramsal soru, tanımı ezberletmek yerine tek eksenli analiz ile çoklu etkileşimi karşılaştırıyor.",
    },
    {
        "id": "handcrafted_0016", "category_key": "Paradigma", "difficulty": 3,
        "prompt": "Di felsefeya siyasî ya femînîst de, berfirehkirina qada «siyasetê» çi tê wate kirin?",
        "a": "Tenê karên parlamentoyê siyasî tên hesibandin.",
        "b": "Têkiliyên hêzê di civaka sivîl û malbatê de jî dikarin bibin mijara lêkolîna siyasî.",
        "c": "Siyaset ji her cure têkiliya civakî tamamen cuda ye.",
        "d": "Lêkolîn divê tenê li ser qanûnên aborî raweste.",
        "correct": "B",
        "explanation": "Felsefeya siyasî ya femînîst balê dikişîne ser vê yekê ku hêz û rêveberî tenê di dewletê de nayên dîtin; civaka sivîl û qada malbatê jî dikarin têkiliyên hêzê hilberînin.",
        "source_title": "Feminist Political Philosophy – Stanford Encyclopedia of Philosophy", "source_url": "https://plato.stanford.edu/archives/win2023/entries/feminism-political/",
        "quality_note": "Soru, paradigmanın kapsam değişimini ölçüyor; yanlışlar kavramı daraltan iddialar olarak yazıldı.",
    },
]


CSV_FIELDS = [
    "id", "category_key", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d",
    "correct_option", "explanation", "difficulty", "source_title", "source_url", "publication_status", "quality_note",
]


def sql_quote(value):
    return "'" + value.replace("'", "''") + "'"


def main():
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for row in ROWS:
            writer.writerow({
                "id": row["id"], "category_key": row["category_key"], "language_code": "ku-kmr",
                "prompt": row["prompt"], "option_a": row["a"], "option_b": row["b"],
                "option_c": row["c"], "option_d": row["d"], "correct_option": row["correct"],
                "explanation": row["explanation"], "difficulty": row["difficulty"],
                "source_title": row["source_title"], "source_url": row["source_url"],
                "publication_status": "PENDING_EDITORIAL_APPROVAL", "quality_note": row["quality_note"],
            })

    values = []
    for row in ROWS:
        values.append(
            "(" + ", ".join([
                "(select id from public.categories where name = " + sql_quote(row["category_key"]) + ")",
                sql_quote("ku-kmr"), sql_quote(row["prompt"]), sql_quote(row["a"]), sql_quote(row["b"]),
                sql_quote(row["c"]), sql_quote(row["d"]), sql_quote(row["correct"]),
                sql_quote(row["explanation"]), str(row["difficulty"]), "false", sql_quote("multiple_choice"),
                "NULL", sql_quote("handcrafted_question_wave_1"),
            ]) + ")"
        )
    sql = """-- İlk el yazımı soru paketi: 16 soru, her kategoriye iki soru.
-- is_approved bilerek false bırakıldı; canlı içeriğe alınmadan önce ikinci editoryal kontrol gerekir.
insert into public.questions (category_id, language_code, prompt, option_a, option_b, option_c, option_d, correct_option, explanation, difficulty, is_approved, question_type, image_url, source_url) values
""" + ",\n".join(values) + ";\n"
    OUT_SQL.write_text(sql, encoding="utf-8")
    print(f"wrote {len(ROWS)} rows")


if __name__ == "__main__":
    main()
