# -*- coding: utf-8 -*-
"""ZK122-ZK141 bozuk blok + ZK003/ZK020 yinelenen seçenek düzeltmesi.
Sadece ..._DUZELTILMIS.csv üzerinde çalışır, orijinal CSV'ye dokunmaz.
Her satırda: soru metni aciklamadan türetilir, dogru_cevap/dogru_secenek
doldurulur, yinelenen seçenekler anlamlı alternatiflerle değiştirilir.
"""
import csv, io

DST = "zankurd_soru_bankasi_cevapli_DUZELTILMIS.csv"

# id -> (soru, [A,B,C,D], dogru_harf)
FIX = {
    "ZK003": (  # sadece yinelenen seçenek: B Mardin -> Urfa
        "Amed adı Kürtçe kullanımda en çok hangi şehirle ilişkilendirilir?",
        ["Mardin", "Urfa", "Van", "Diyarbakır"], "D"),
    "ZK020": (  # yinelenen 1915: B -> 1930
        "Mahabad Cumhuriyeti hangi yılda kurulmuş kısa ömürlü Kürt siyasal deneyimidir?",
        ["1915", "1930", "1920", "1946"], "D"),
    "ZK122": (
        "Kürdistan coğrafyasının en yüksek dağı hangisidir?",
        ["Ağrı Dağı", "Elburz Dağı", "Cudi Dağı", "Alp Dağları"], "C"),
    "ZK123": (
        "Fırat nehri hangi üç ülkenin topraklarından geçer?",
        ["Türkiye, Irak, İran", "Türkiye, Suriye, Ürdün",
         "Irak, İran, Suriye", "Türkiye, Irak, Suriye"], "D"),
    "ZK124": (
        "Kurmancî hangi dil ailesine mensuptur?",
        ["Doğu Avrupa", "Kuzey Avrupa", "İskandinav", "Hint-Avrupa"], "D"),
    "ZK125": (
        "Soranî nedir?",
        ["Arapçanın bir lehçesi", "Türkçenin bir lehçesi",
         "Farsçanın bir lehçesi", "Kurmancî'nin bir lehçesi"], "D"),
    "ZK126": (
        "Şerefname adlı eserin yazarı kimdir?",
        ["Şeref Han Bitlisi", "Melayê Cizîrî", "Ehmedê Xanî", "Cegerxwîn"], "A"),
    "ZK127": (
        "Dengbêjlik geleneği hangi sanat alanıyla ilişkilidir?",
        ["Klasik edebiyat", "Modern roman", "Felsefi düşünce",
         "Halk şiiri ve müziği"], "D"),
    "ZK128": (
        "Demokratik konfederalizm fikri kime aittir?",
        ["Mustafa Barzani", "Celadet Ali Bedirxan", "Melayê Cizîrî",
         "Abdullah Öcalan"], "D"),
    "ZK129": (
        "Jineolojî hangi çalışma alanını ifade eder?",
        ["Fizik bilimi", "Kimya bilimi", "Biyoloji bilimi",
         "Kadın bilimi ve toplumsal cinsiyet"], "D"),
    "ZK130": (
        "Govend nedir?",
        ["Kişisel müzik", "Dramatik tiyatro", "Spor müsabakası",
         "Toplu halk dansı"], "D"),
    "ZK131": (
        "Kürt müziğinin en eski çalgılarından def hangi çalgı grubuna girer?",
        ["Davul ve perküsyon", "Keman ve piyano", "Flüt ve klarinet",
         "Arp ve ut"], "A"),
    "ZK132": (
        "Kürt meselesi hangi ülkelerde yaşanmaktadır?",
        ["Sadece Türkiye'de", "Sadece Irak'ta", "Sadece İran'da",
         "Türkiye, Irak, İran, Suriye"], "D"),
    "ZK133": (
        "DEM Parti hangi ülkede kurulmuştur?",
        ["Irak", "İran", "Suriye", "Türkiye"], "D"),
    "ZK134": (
        "İlk Kürtçe gazete 'Kurdistan' hangi yılda yayımlanmıştır?",
        ["1918", "1928", "1948", "1898"], "D"),
    "ZK135": (
        "Newroz efsanesinde Dehak'a (Zahhak) karşı ayaklanan demirci kimdir?",
        ["Xerxes", "Napoleon", "Hitler", "Kawa/Kave Demirci"], "D"),
    "ZK136": (
        "Kürtler nasıl bir topluluk olarak tanımlanır?",
        ["Etnik ve dilsel topluluk", "Sadece dilsel grup",
         "Sadece siyasi grup", "Sadece dinsel grup"], "A"),
    "ZK137": (
        "Kürt diasporası yeni nesillere öncelikle neyi aktarır?",
        ["Dil, kültür ve kimlik", "Sadece spor", "Sadece turizm",
         "Sadece ekonomi"], "A"),
    "ZK138": (
        "ZanKurd'da soruların altındaki açıklama (şirove) ne işe yarar?",
        ["Öğrenmeyi kolaylaştırmak için", "Sadece görsel için",
         "CSV'yi bozmak için", "Doğru cevabı saklamak için"], "A"),
    "ZK139": (
        "ZanKurd uygulamasının temel amacı nedir?",
        ["Kurmancî içerik ve eğitim", "Sadece sosyal medya",
         "Sadece oyunlaşma", "Sadece güzel tasarım"], "A"),
    "ZK140": (
        "Dolma nasıl bir yemektir?",
        ["İç harçlı sebze/yaprak", "Sadece çorba", "Sadece tatlı şerbet",
         "Sadece tatlı"], "A"),
    "ZK141": (
        "Kürt kültüründe yemeğin paylaşılması (beş kirin) neyi amaçlar?",
        ["Topluluk ve aile bağlarını güçlendirmek için",
         "Sadece sosyalleşmek için", "Sadece alışveriş için",
         "Sadece yemek için"], "A"),
}

SEC_COLS = ["secenek_a", "secenek_b", "secenek_c", "secenek_d"]
HARFLER = ["A", "B", "C", "D"]

with io.open(DST, "r", encoding="utf-8-sig", newline="") as f:
    reader = csv.DictReader(f)
    rows = list(reader)
    fieldnames = reader.fieldnames

duzeltilen = []
for r in rows:
    sid = r["id"]
    if sid not in FIX:
        continue
    soru, secenekler, harf = FIX[sid]
    r["soru"] = soru
    for col, val in zip(SEC_COLS, secenekler):
        r[col] = val
    r["dogru_cevap"] = secenekler[HARFLER.index(harf)]
    r["dogru_secenek"] = harf
    duzeltilen.append(sid)

with io.open(DST, "w", encoding="utf-8-sig", newline="") as f:
    w = csv.DictWriter(f, fieldnames=fieldnames)
    w.writeheader()
    w.writerows(rows)

print(f"Düzeltilen: {len(duzeltilen)} satır -> {', '.join(sorted(duzeltilen))}")
