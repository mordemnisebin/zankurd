#!/usr/bin/env python3
"""Sînema kategorisinin üst seviyesine zor soru ekler.

Seviye sistemi kategoriyi beş banda böler; en üst bant ("Mamoste")
zorluk 4-5'ten 15 soru ister. Sînema'da o bantta yalnız 11 soru vardı —
tur eksik başlıyor, oyuncu 15 yerine 11 soru görüyordu. Sessiz bir
eksiklik: hata yok, yalnız kısa bir tur.

Eklenen altı soru zorluk 4-5'te ve mevcut sorulardan farklı konularda;
her birinin doğrulanabilir bir kaynağı var (editoryal banka sözleşmesi).
"""
import json
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "assets/data/editorial_questions.json"

QUESTIONS = [
    (
        4,
        "Fîlmê «Sûrû» (1978) ji hêla kîjan derhêner ve hatiye kişandin?",
        ["Zeki Ökten", "Şerîf Gören", "Atif Yilmaz", "Ömer Lütfi Akad"],
        "Zeki Ökten",
        "Senaryo ya Yilmaz Guney bû; wî di girtîgehê de nivîsand û derhênerî "
        "ji Zeki Ökten re ma.",
        "Senaryo Yılmaz Güney'e aitti; cezaevinde yazdı ve yönetmenlik Zeki "
        "Ökten'e kaldı.",
        "Güney Film / Zeki Ökten, Sürü (1978) — arşîva fîlman",
    ),
    (
        5,
        "Fîlmê «Dema Hespên Serxweş» bi kîjan zimanî hatiye kişandin?",
        ["Kurdî (Soranî û Kurmancî)", "Farisî", "Erebî", "Tirkî"],
        "Kurdî (Soranî û Kurmancî)",
        "Fîlm bi zimanê gel ê herêmê hate kişandin; ev jî wê di nav fîlmên "
        "yekem ên bi kurdî de bi cih dike.",
        "Film yörenin kendi diliyle çekildi; bu da onu Kürtçe çekilen ilk "
        "filmler arasına yerleştirir.",
        "Bahman Ghobadi, Dema Hespên Serxweş (2000) — dosyaya festîvalê",
    ),
    (
        5,
        "Fîlmê «Cîranê Min Totoro» ji hêla kîjan stûdyoyê ve hatiye çêkirin?",
        ["Studio Ghibli", "Toei Animation", "Madhouse", "Pixar"],
        "Studio Ghibli",
        "Karakterê Totoro paşê bû nîşana fermî ya heman stûdyoyê.",
        "Totoro karakteri sonradan aynı stüdyonun resmî simgesi oldu.",
        "Studio Ghibli, Tonari no Totoro (1988) — arşîva stûdyoyê",
    ),
    (
        4,
        "Di sînemayê de «plansekans» çi ye?",
        [
          "Dîmenek ku bêyî qutkirinê di yek girtinê de tê kişandin",
          "Dîmenek ku tenê bi dengê derve tê vegotin",
          "Rêza dîmenên ku ji dawiyê ber bi destpêkê ve diçin",
          "Dîmenek ku bi du kameran ji heman goşeyê tê girtin",
        ],
        "Dîmenek ku bêyî qutkirinê di yek girtinê de tê kişandin",
        "Ji ber ku qutkirin tune ye, lîstikvan û kamera divê tevgera xwe "
        "bi hev re rêk bixin; ev jî wê teknîkî dijwar dike.",
        "Kesme olmadığı için oyuncu ve kamera hareketlerini birlikte "
        "kurgulamak zorundadır; teknik zorluğu buradan gelir.",
        "David Bordwell & Kristin Thompson, Film Art — beşa mîzansenê",
    ),
    (
        5,
        "Fîlmê «Yol» ji ber çi sedemî demek dirêj li Tirkiyeyê nehat nîşandan?",
        [
          "Fîlm hate qedexekirin",
          "Kopyayên fîlm winda bûbûn",
          "Derhêner nexwest ku li Tirkiyeyê were nîşandan",
          "Fîlm hîn nehatibû qedandin",
        ],
        "Fîlm hate qedexekirin",
        "Fîlm piştî Cannesê bi salan li Tirkiyeyê nayê nîşandan; nîşandana "
        "wê ya fermî pir dereng çêbû.",
        "Film, Cannes'dan sonra yıllarca Türkiye'de gösterilemedi; resmî "
        "gösterimi çok sonra gerçekleşti.",
        "Yol (1982) — arşîva çapemeniyê ya nîşandanê",
    ),
    (
        4,
        "Festîvala Berlînê xelata xwe ya sereke bi kîjan navî dide?",
        ["Hirça Zêrîn", "Şêrê Zêrîn", "Palmiya Zêrîn", "Globa Zêrîn"],
        "Hirça Zêrîn",
        "Her festîvalek sembola bajarê xwe hildibijêre; hirç sembola Berlînê "
        "ye.",
        "Her festival kendi şehrinin simgesini seçer; ayı Berlin'in "
        "simgesidir.",
        "Berlinale — agahiyên fermî yên xelatan",
    ),
]


def main() -> None:
    bank = json.loads(PATH.read_text(encoding="utf-8"))
    existing = {q["id"] for q in bank}
    added = 0
    for index, (difficulty, prompt, answers, correct, ku, tr, source) in enumerate(
        QUESTIONS, start=25
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
    print(f"{added} zor soru eklendi; banka {len(bank)} soru.")


if __name__ == "__main__":
    main()
