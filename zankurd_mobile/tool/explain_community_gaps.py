#!/usr/bin/env python3
"""Topluluk bankasındaki açıklamasız soruların açıklamalarını yazar.

Açıklamalar tur sonunda toplu gösterildiği için boş açıklama, o sorunun
öğrenme payını tümüyle siler. 24 soruda açıklama boştu.

Yazılan sekizi doğrulanabilir coğrafya, edebiyat ve müzik bilgisidir.
Kalan on altısı **bilerek boş bırakıldı**: çoğu tek tek kişilerin
yaşamına dair anma bilgisi ve bunları bağımsız olarak doğrulayamıyorum.
Doğrulanmamış bir açıklama yazmak, yanlış olabilecek bir cevabı
"öğretilmiş bilgi" hâline getirir — boş açıklamada panel hiç açılmaz,
sessiz ama dürüst.
"""
import json
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "assets/data/community_questions.json"

EXPLANATIONS = {
    "comm_cog_0001": (
        "Amed (Diyarbekir) li herêma bakur a Kurdistanê ye û bajarê herî "
        "mezin ê wê herêmê tê hesibandin.",
        "Amed (Diyarbakır) Kürdistan'ın kuzey bölgesindedir ve o bölgenin "
        "en büyük şehri sayılır.",
    ),
    "comm_cog_0003": (
        "Nisêbîn navçeyeke li ser sînorê Sûriyeyê ye û bi Mêrdînê ve "
        "girêdayî ye.",
        "Nisêbîn (Nusaybin) Suriye sınırında bir ilçedir ve Mardin'e "
        "bağlıdır.",
    ),
    "comm_cog_0004": (
        "Behra Wanê gola herî mezin a herêmê ye û navê xwe ji bajarê li "
        "kêleka xwe digire.",
        "Van Gölü bölgenin en büyük gölüdür ve adını kıyısındaki şehirden "
        "alır.",
    ),
    "comm_cog_0005": (
        "Seyîd Riza yek ji rêberên olî û civakî yên herêma Dêrsimê bû.",
        "Seyid Rıza, Dersim bölgesinin tanınmış dinî ve toplumsal "
        "önderlerindendi.",
    ),
    "comm_muz_0002": (
        "Mihemmed Şêxo yek ji pêşengên muzîka kurdî ye; bi stranên xwe yên "
        "bi saz tê nasîn.",
        "Mihemmed Şêxo Kürt müziğinin öncülerindendir; saz eşliğinde "
        "söylediği eserlerle tanınır.",
    ),
    "comm_muz_0003": (
        "Ev gotin ji Aram Tigran re tê hesibandin; ew hunermendekî bi eslê "
        "xwe ermenî bû û bi kurdî distira.",
        "Bu söz Aram Tigran'a atfedilir; Ermeni asıllı bir sanatçıydı ve "
        "Kürtçe söylerdi.",
    ),
    "comm_ede_0001": (
        "Baba Tahir bi dûbeytiyên xwe tê nasîn û li derdora Hemedanê jiyaye.",
        "Baba Tahir dûbeytî biçimiyle tanınır ve Hemedan çevresinde "
        "yaşamıştır.",
    ),
    "comm_ede_0004": (
        "Romana «Bîra Qederê» ji jiyana Celadet Alî Bedirxan îlham digire.",
        "«Bîra Qederê» romanı Celadet Alî Bedirxan'ın yaşamından esinlenir.",
    ),
    "comm_siy_0002": (
        "YPJ (Yekîneyên Parastina Jin) yekîneya jinan a li Rojava ye.",
        "YPJ (Yekîneyên Parastina Jin) Rojava'daki kadın birliğidir.",
    ),
}


def main() -> None:
    bank = json.loads(PATH.read_text(encoding="utf-8"))
    touched = 0
    for question in bank:
        pair = EXPLANATIONS.get(question.get("id"))
        if pair is None:
            continue
        ku, tr = pair
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
