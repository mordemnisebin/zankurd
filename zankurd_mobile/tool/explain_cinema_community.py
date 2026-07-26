#!/usr/bin/env python3
"""Topluluk katkısı Sînema sorularının açıklamalarını yazar.

Bu dokuz soruda açıklama boştu. Açıklamalar artık tur sonunda toplu olarak
gösterildiği için boş açıklama, o sorunun öğrenme payını tümüyle silmek
demek. Uydurmamak için her biri kaynaktan doğrulandı (2026-07-26):

* Kobanê (2022) — yön. Özlem Yaşar, müzik Mehmûd Berazî, Komîna Fîlma
  Rojava yapımı, 2014-15 Kobanê kuşatmasını anlatır, çekimler Kobanê ve
  Tabqa'da; oyuncuların büyük bölümü direnişe katılmış gerçek savaşçılar.
* 14 Tîrmeh (2017) — yön. Haşim Aydemir, müzik Mehmûd Berazî; 14 Temmuz
  1982'de Amed cezaevindeki ölüm orucunu anlatır.
* Ji bo Azadîyê (2019) — yön. Ersin Çelik, müzik Mehmûd Berazî; Sur'daki
  103 günlük direnişi anlatır, çekimler Kobanê'de (bazı sahneler
  Qamişlo'da) yapıldı.

`comm_sin_0003` **değiştirildi**: "Memoyê Amedî" rolünü Fırat Mordem'in
oynadığı bilgisi hiçbir künyede doğrulanamadı — ne TMDB, ne festival
dosyaları, ne Kürtçe kaynaklar. Doğrulanamayan bir soruyu açıklamayla
sağlamlaştırmak kusuru gizler; soru, aynı filme dair doğrulanmış bir
bilgiyle değiştirildi.
"""
import json
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "assets/data/community_questions.json"

EXPLANATIONS = {
    "comm_sin_0001": (
        "Muzîka fîlmê Kobanê (2022) ya Komîna Fîlma Rojava ji hêla Mehmûd "
        "Berazî ve hatiye çêkirin; ew muzîka çend fîlmên din ên heman "
        "derdorê jî nivîsandiye.",
        "Rojava Film Komünü yapımı Kobanê (2022) filminin müziğini Mehmûd "
        "Berazî yaptı; aynı çevrenin başka birkaç filminin müziği de ona "
        "aittir.",
    ),
    "comm_sin_0002": (
        "Fîlm di sala 2022'yan de derket û dorpêça Kobanê ya 2014-2015'an "
        "vedibêje; senaryo li ser bingeha hevpeyvînên bi bi sedan şahid û "
        "şervanan hatiye nivîsandin.",
        "Film 2022'de gösterime girdi ve 2014-2015 Kobanê kuşatmasını "
        "anlatır; senaryo yüzlerce tanık ve savaşçıyla yapılan "
        "görüşmelere dayanır.",
    ),
    "comm_sin_0003": (
        "Fîlm li Kobanê û Tabqayê hate kişandin; beşek mezin ji lîstikvanan "
        "ne pîşeyî bûn, ew bi xwe beşdarî berxwedanê bûbûn.",
        "Film Kobanê ve Tabqa'da çekildi; oyuncuların büyük bölümü "
        "profesyonel değil, direnişe bizzat katılmış kişilerdi.",
    ),
    "comm_sin_0004": (
        "Muzîka fîlmê 14 Tîrmeh jî ji hêla Mehmûd Berazî ve hatiye çêkirin.",
        "14 Tîrmeh filminin müziği de Mehmûd Berazî'ye aittir.",
    ),
    "comm_sin_0005": (
        "Fîlmê derhêner Haşim Aydemir di sala 2017'an de derket; ew grewa "
        "birçîbûnê ya 14'ê Tîrmeha 1982'yan a li girtîgeha Amedê vedibêje.",
        "Yönetmen Haşim Aydemir'in filmi 2017'de gösterime girdi; 14 Temmuz "
        "1982'de Amed cezaevinde başlayan ölüm orucunu anlatır.",
    ),
    "comm_sin_0006": (
        "Fîlm di sala 2019'an de derket û berxwedana 103 rojan a li Sûrê "
        "vedibêje.",
        "Film 2019'da gösterime girdi ve Sur'daki 103 günlük direnişi "
        "anlatır.",
    ),
    "comm_sin_0007": (
        "Fîlm bûyerên li Sûra Amedê vedibêje, lê ji ber şert û mercan li "
        "Kobanê hate kişandin; hin dîmen li Qamişloyê hatin girtin.",
        "Film Amed'in Sur ilçesindeki olayları anlatır ama koşullar "
        "nedeniyle Kobanê'de çekildi; bazı sahneler Qamişlo'da alındı.",
    ),
    "comm_sin_0008": (
        "Derhêner Ersin Çelik e; senaryo li ser bingeha rojnivîskên "
        "şervanan û şahidiya kesên ku sax man hatiye nivîsandin.",
        "Yönetmen Ersin Çelik'tir; senaryo savaşanların günlüklerine ve "
        "hayatta kalanların tanıklığına dayanır.",
    ),
    "comm_sin_0009": (
        "Muzîka fîlm a Mehmûd Berazî ye; stranê 'Rûbarê Min' bi dengê "
        "Mizgîn Tahir di fîlm de derbas dibe.",
        "Filmin müziği Mehmûd Berazî'ye aittir; 'Rûbarê Min' parçası "
        "Mizgîn Tahir'in sesinden filmde yer alır.",
    ),
}

# Doğrulanamayan soru, aynı filme dair doğrulanmış bir bilgiyle değişir.
REPLACEMENT = {
    "comm_sin_0003": {
        "prompt": "Di fîlmê Kobanê de lîstikvan bi piranî kî ne?",
        "promptTr": "Kobanê filminde oyuncular çoğunlukla kimlerdir?",
        "answers": [
            "Kesên ku bi xwe beşdarî berxwedanê bûne",
            "Lîstikvanên şanoya Şamê",
            "Xwendekarên dibistana fîlman a Duhokê",
            "Lîstikvanên navdar ên Hollywoodê",
        ],
        "answersTr": [
            "Direnişe bizzat katılmış kişiler",
            "Şam tiyatrosunun oyuncuları",
            "Duhok film okulunun öğrencileri",
            "Hollywood'un ünlü oyuncuları",
        ],
        "correctAnswer": "Kesên ku bi xwe beşdarî berxwedanê bûne",
        "correctAnswerTr": "Direnişe bizzat katılmış kişiler",
    }
}


def main() -> None:
    bank = json.loads(PATH.read_text(encoding="utf-8"))
    touched = 0

    for question in bank:
        qid = question.get("id")
        if qid not in EXPLANATIONS:
            continue
        question.update(REPLACEMENT.get(qid, {}))
        ku, tr = EXPLANATIONS[qid]
        question["explanation"] = tr
        question["explanationKu"] = ku
        question["explanationTr"] = tr
        touched += 1

    PATH.write_text(
        json.dumps(bank, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    print(f"{touched} soruya açıklama yazıldı.")


if __name__ == "__main__":
    main()
