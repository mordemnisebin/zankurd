#!/usr/bin/env python3
"""Sînema kategorisine editoryal soru ekler.

Kategori 21 soruyla açıktı; bir düello 10 soru olduğu için havuz iki turda
tükeniyor ve sorular tekrar etmeye başlıyordu. Diğer kategoriler 260-339
arasında. Teknolojî'de olduğu gibi kategoriyi kapatmak yerine doldurmak
seçildi: ürünün amacı yalnız Kürt kültürü değil, genel dünya bilgisi de.

Sorular editoryal biçimi izler — gövde ve şıklar Kurmancî, açıklama iki
dilde. Bankanın 2357 sorusunun gövdesi Kurmancî'dir; içerik dili arayüz
diline göre değişmez, yalnız açıklama değişir.
"""
import json
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "assets/data/editorial_questions.json"

# (zorluk, gövde, [şıklar], doğru, açıklama_ku, açıklama_tr, kaynak)
#
# Kaynak zorunlu: editoryal banka sözleşmesi her sorunun doğrulanabilir bir
# referansı olmasını ister (`test/editorial_question_bank_test.dart`).
QUESTIONS = [
    # ── Kürt sineması ──
    (
        3,
        "Fîlmê «Yol» di sala 1982'an de Palmiya Zêrîn a Cannesê bi kîjan fîlmî re parve kir?",
        ["Missing", "Gandhi", "E.T.", "Fanny û Alexander"],
        "Missing",
        "Di Festîvala Cannesê ya sala 1982'yan de Palmiya Zêrîn di navbera du fîlman de hate parvekirin; ya duyem fîlmê Costa-Gavras bû.",
        "1982 Cannes Film Festivali'nde Altın Palmiye iki film arasında paylaştırıldı; diğeri Costa-Gavras'ın filmiydi.",

        "Festival de Cannes, arşîva xelatan: Palme d'Or 1982 (Yol / Missing)",
    ),
    (
        3,
        "Fîlmê «Dema Hespên Serxweş» di sala 2000'î de li Cannesê kîjan xelat wergirt?",
        ["Caméra d'Or", "Palmiya Zêrîn", "Xelata Mezin a Jûriyê", "Şêrê Zêrîn"],
        "Caméra d'Or",
        "Caméra d'Or xelata fîlmê yekem ê derhênerekî ye; Bahman Ghobadi ew di sala 2000'î de wergirt.",
        "Caméra d'Or, bir yönetmenin ilk filmine verilen ödüldür; Bahman Ghobadi bu ödülü 2000 yılında aldı.",

        "Festival de Cannes, arşîva Caméra d'Or 2000",
    ),
    (
        3,
        "Bûyera fîlmê «Kûsî jî Difirin» li ku derê diqewime?",
        [
            "Li kampeke penaberan a Kurdistana Iraqê",
            "Li taxeke Stenbolê",
            "Li navenda Tehranê",
            "Li benderekê li Beyrûdê",
        ],
        "Li kampeke penaberan a Kurdistana Iraqê",
        "Fîlm berî şerê sala 2003'yan, di nav zarokên kampekê de derbas dibe.",
        "Film, 2003 savaşının hemen öncesinde bir mülteci kampındaki çocuklar arasında geçer.",

        "Bahman Ghobadi, Kûsî jî Difirin (2004) — dosyaya çapemeniyê ya fîlm",
    ),
    (
        4,
        "Fîlmê «Vodka Lemon» li kîjan welatî hatiye kişandin?",
        ["Ermenistan", "Gurcistan", "Azerbaycan", "Ûkrayna"],
        "Ermenistan",
        "Hiner Saleem fîlm li gundekî ku kurdên êzidî lê dijîn kişand.",
        "Hiner Saleem, filmi Ezidi Kürtlerin yaşadığı bir köyde çekti.",

        "Hiner Saleem, Vodka Lemon (2003) — Festîvala Venedîkê, dosyaya fîlm",
    ),
    (
        4,
        "Kazim Öz di destpêka kariyera xwe de li kîjan saziya çandî xebitî?",
        [
            "Navenda Çanda Mezopotamyayê",
            "Enstîtuya Kurdî ya Parîsê",
            "Akademiya Fîlman a Berlînê",
            "Yekîtiya Nivîskarên Tirkiyeyê",
        ],
        "Navenda Çanda Mezopotamyayê",
        "Fîlmên wî yên pêşîn di nav xebata vê saziyê de hatin çêkirin.",
        "İlk filmleri bu kurumun bünyesindeki çalışmalar içinde üretildi.",

        "Navenda Çanda Mezopotamyayê (NÇM), arşîva xebatên sînemayê 1996-2000",
    ),
    (
        2,
        "Gora Yilmaz Guney li kîjan bajarî ye?",
        ["Parîs", "Stenbol", "Adana", "Berlîn"],
        "Parîs",
        "Ew di sala 1984'an de li sirgûnê koça dawî kir û li goristana Père-Lachaise hate veşartin.",
        "1984'te sürgünde hayatını kaybetti ve Père-Lachaise mezarlığına defnedildi.",

        "Goristana Père-Lachaise, Parîs — tomara goran (Yilmaz Guney, 1984)",
    ),
    (
        3,
        "Fîlmê «Klama Dayîka Min» xelata fîlmê herî baş li kîjan festîvalê wergirt?",
        [
            "Festîvala Fîlman a Stenbolê",
            "Festîvala Cannesê",
            "Festîvala Berlînê",
            "Festîvala Venedîkê",
        ],
        "Festîvala Fîlman a Stenbolê",
        "Fîlmê Erol Mintaş di sala 2014'an de li wê festîvalê xelata sereke wergirt.",
        "Erol Mintaş'ın filmi 2014'te bu festivalde ana ödülü kazandı.",

        "Festîvala Fîlman a Navneteweyî ya Stenbolê, arşîva xelatan 2014",
    ),
    (
        2,
        "Festîvala Fîlman a Duhokê li kîjan welatî tê lidarxistin?",
        ["Iraq", "Îran", "Sûriye", "Ermenistan"],
        "Iraq",
        "Festîval li Herêma Kurdistanê tê lidarxistin û fîlmên kurdî yên nû li wir tên nîşandan.",
        "Festival Kürdistan Bölgesi'nde düzenlenir ve yeni Kürt filmleri orada gösterilir.",

        "Duhok International Film Festival — agahiyên fermî yên festîvalê",
    ),
    (
        5,
        "Fîlmê «Zare» (1926), yek ji fîlmên herî kevn ên li ser jiyana kurdan, li kîjan welatî hatiye kişandin?",
        ["Yekîtiya Soviyetê", "Fransa", "Misir", "Îtalya"],
        "Yekîtiya Soviyetê",
        "Fîlm li Ermenistana Soviyetê hate kişandin û jiyana kurdên êzidî nîşan dide.",
        "Film Sovyet Ermenistanı'nda çekildi ve Ezidi Kürtlerin yaşamını anlatır.",

        "Hamo Beknazarian, Zare (1926), Ermenfilm — arşîva sînemaya Soviyetê",
    ),
    (
        4,
        "Di fîlmê «Dema Hespên Serxweş» de lîstikvan bi piranî ji kîjan komê hatine hilbijartin?",
        [
            "Ji gundiyên herêmê yên ne pîşeyî",
            "Ji lîstikvanên şanoya Tehranê",
            "Ji lîstikvanên navdar ên Hollywoodê",
            "Ji stranbêjên navdar ên herêmê",
        ],
        "Ji gundiyên herêmê yên ne pîşeyî",
        "Derhêner li şûna lîstikvanên pîşeyî mirovên ji herêmê bi kar anî; ev hilbijartin fîlm nêzîkî belgefîlmê dike.",
        "Yönetmen profesyonel oyuncular yerine yörenin insanlarını kullandı; bu seçim filmi belgesele yaklaştırır.",

        "Bahman Ghobadi, Dema Hespên Serxweş (2000) — hevpeyvînên derhêner",
    ),
    # ── Dünya sineması ──
    (
        1,
        "Fîlmê «Parazît» ji kîjan welatî ye?",
        ["Koreya Başûr", "Japonya", "Çîn", "Taylandistan"],
        "Koreya Başûr",
        "Derhênerê fîlm Bong Joon-ho ye; fîlm di sala 2019'an de derket.",
        "Filmin yönetmeni Bong Joon-ho'dur; film 2019 yılında gösterime girdi.",

        "Bong Joon-ho, Parasite (2019) — CJ Entertainment, agahiyên belavkirinê",
    ),
    (
        3,
        "Kîjan fîlm bû yekem berhema ne bi îngilîzî ku Oscara Fîlmê Herî Baş wergirt?",
        ["Parazît", "Roma", "Amélie", "Rashomon"],
        "Parazît",
        "Ev di sala 2020'yî de qewimî û di dîroka Oscaran de bû bûyereke yekem car.",
        "Bu 2020 yılında gerçekleşti ve Oscar tarihinde ilk kez yaşandı.",

        "Academy of Motion Picture Arts and Sciences, arşîva Oscaran 2020",
    ),
    (
        2,
        "Derhênerê fîlmê «Heft Samurai» (1954) kî ye?",
        ["Akira Kurosawa", "Yasujiro Ozu", "Kenji Mizoguchi", "Hirokazu Kore-eda"],
        "Akira Kurosawa",
        "Fîlm bandoreke mezin li sînemaya cîhanê kir û gelek caran ji nû ve hate çêkirin.",
        "Film dünya sinemasını derinden etkiledi ve defalarca yeniden çevrildi.",

        "Akira Kurosawa, Shichinin no Samurai (1954) — Toho, arşîva fîlman",
    ),
    (
        3,
        "Fîlmê yekem ê bi diyalogên bideng ê Charlie Chaplin kîjan e?",
        ["Dîktatorê Mezin", "Ronahiyên Bajêr", "Demên Nûjen", "Zarok"],
        "Dîktatorê Mezin",
        "Chaplin heta sala 1940'î bi piranî bêdeng xebitî; ev fîlm cara pêşîn bi tevahî bi axaftin e.",
        "Chaplin 1940'a kadar ağırlıkla sessiz çalıştı; bu film ilk kez baştan sona konuşmalıdır.",

        "Charlie Chaplin, The Great Dictator (1940) — Chaplin Office, arşîv",
    ),
    (
        2,
        "Derhênerê anîmasyona «Spirited Away» kî ye?",
        ["Hayao Miyazaki", "Isao Takahata", "Makoto Shinkai", "Satoshi Kon"],
        "Hayao Miyazaki",
        "Fîlm di sala 2003'yan de Oscara anîmasyona herî baş wergirt.",
        "Film 2003 yılında en iyi animasyon Oscar'ını kazandı.",

        "Studio Ghibli, Sen to Chihiro no Kamikakushi (2001) — arşîva stûdyoyê",
    ),
    (
        2,
        "Fîlmên «Psycho» û «Vertigo» ji hêla kîjan derhêner ve hatine kişandin?",
        ["Alfred Hitchcock", "Orson Welles", "Billy Wilder", "John Ford"],
        "Alfred Hitchcock",
        "Ew bi fîlmên xwe yên tirsê û tansiyonê tê nasîn.",
        "Gerilim ve tansiyon filmleriyle tanınır.",

        "British Film Institute, dosyaya Alfred Hitchcock",
    ),
    (
        3,
        "Derhênerê fîlmê «2001: A Space Odyssey» kî ye?",
        ["Stanley Kubrick", "Ridley Scott", "George Lucas", "Steven Spielberg"],
        "Stanley Kubrick",
        "Fîlm di sala 1968'an de derket û zimanê dîmenî yê sînemaya zanistî guhert.",
        "Film 1968'de gösterime girdi ve bilim kurgu sinemasının görsel dilini değiştirdi.",

        "Stanley Kubrick, 2001: A Space Odyssey (1968) — MGM, arşîva fîlman",
    ),
    (
        3,
        "Yekem pêşandana fîlman a ji bo gel di sala 1895'an de li Parîsê ji hêla kê ve hate lidarxistin?",
        ["Birayên Lumière", "Thomas Edison", "Georges Méliès", "Birayên Warner"],
        "Birayên Lumière",
        "Ew pêşandan destpêka sînemaya bazirganî tê hesibandin.",
        "O gösterim, ticari sinemanın başlangıcı sayılır.",

        "Institut Lumière, Lyon — tomara pêşandana 28'ê Kanûna 1895'an",
    ),
    (
        2,
        "Xelata herî mezin a Festîvala Venedîkê çi ye?",
        ["Şêrê Zêrîn", "Hirça Zêrîn", "Palmiya Zêrîn", "Globa Zêrîn"],
        "Şêrê Zêrîn",
        "Her festîvalek sembola xwe heye: li Berlînê hirç, li Cannesê palmî.",
        "Her festivalin kendi simgesi vardır: Berlin'de ayı, Cannes'da palmiye.",

        "La Biennale di Venezia, agahiyên fermî yên xelata Leone d'Oro",
    ),
    (
        2,
        "Fîlmê «Cinema Paradiso» ji kîjan welatî ye?",
        ["Îtalya", "Fransa", "Spanya", "Yûnanistan"],
        "Îtalya",
        "Derhênerê wê Giuseppe Tornatore ye; fîlm li ser hezkirina sînemayê ye.",
        "Yönetmeni Giuseppe Tornatore'dir; film sinema sevgisi üzerinedir.",

        "Giuseppe Tornatore, Nuovo Cinema Paradiso (1988) — Cristaldifilm",
    ),
    (
        4,
        "Fîlmê «Diziyên Bîsikletê» (1948) mînaka kîjan tevgera sînemayî ye?",
        [
            "Neorealîzma Îtalî",
            "Ekspresyonîzma Alman",
            "Pêla Nû ya Fransî",
            "Sînemaya Sovyetî",
        ],
        "Neorealîzma Îtalî",
        "Ev tevger piştî şer bi kişandina li kolanan û bi lîstikvanên ne pîşeyî tê nasîn.",
        "Bu akım savaş sonrasında sokakta çekim yapmasıyla ve profesyonel olmayan oyuncularıyla tanınır.",

        "Vittorio De Sica, Ladri di biciclette (1948) — Cineteca di Bologna",
    ),
    (
        5,
        "Derhênerê fîlmê «Keştiya Şer Potemkin» (1925) û teorîsyenê montajê kî ye?",
        ["Sergey Eisenstein", "Dziga Vertov", "Lev Kuleşov", "Andrey Tarkovski"],
        "Sergey Eisenstein",
        "Ew nîşan da ku wate ne tenê di dîmenê de, di rêza dîmenan de jî çêdibe.",
        "Anlamın yalnız görüntüde değil, görüntülerin sıralanışında da oluştuğunu gösterdi.",

        "Sergei Eisenstein, Bronenosets Potyomkin (1925) — Goskino, arşîv",
    ),
    (
        3,
        "Ingmar Bergman ji kîjan welatî ye?",
        ["Swêd", "Danîmarka", "Norwec", "Fînlandiya"],
        "Swêd",
        "Fîlmên wî bi pirsên hebûnê û bi dîmenên hişk ên bakur têne nasîn.",
        "Filmleri varoluş sorularıyla ve kuzeyin sert görüntüleriyle tanınır.",

        "Svenska Filminstitutet, dosyaya Ingmar Bergman",
    ),
    (
        4,
        "Fîlmê «Rashomon» (1950) bi kîjan taybetmendiya vegotinê tê nasîn?",
        [
            "Heman bûyer ji devê şahidên cuda bi awayên nakok tê vegotin",
            "Fîlm bi tevahî di yek plana dirêj de hatiye kişandin",
            "Di fîlm de qet diyalog tune ye",
            "Bûyer ji dawiyê ber bi destpêkê ve tê vegotin",
        ],
        "Heman bûyer ji devê şahidên cuda bi awayên nakok tê vegotin",
        "Ev awayê vegotinê îro jî bi navê fîlm tê binavkirin.",
        "Bu anlatım biçimi bugün hâlâ filmin adıyla anılır.",

        "Akira Kurosawa, Rashomon (1950) — Daiei, arşîva fîlman",
    ),
]


def main() -> None:
    bank = json.loads(PATH.read_text(encoding="utf-8"))
    existing = {q["id"] for q in bank}

    added = 0
    for index, (difficulty, prompt, answers, correct, ku, tr, source) in enumerate(
        QUESTIONS, start=1
    ):
        qid = f"edit_sinema_{index:04d}"
        if qid in existing:
            continue
        assert correct in answers, qid
        assert len(set(answers)) == len(answers), qid
        bank.append(
            {
                "type": "multipleChoice",
                "difficulty": difficulty,
                "id": qid,
                "category": "Sînema",
                "prompt": prompt,
                "answers": answers,
                "correctAnswer": correct,
                "explanation": tr,
                "explanationKu": ku,
                "explanationTr": tr,
                "metadata": {
                    "reviewStatus": "approved",
                    "dialect": "Kurmancî",
                    "sourceTitle": "Editoryal — sînemaya kurdî û ya cîhanê",
                    "sourceReference": source,
                    "qualityVersion": 2,
                },
            }
        )
        added += 1

    PATH.write_text(
        json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    print(f"{added} soru eklendi; banka {len(bank)} soru.")


if __name__ == "__main__":
    main()
