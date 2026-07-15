import os
import re
import json
import random
import sys
import time
import urllib.request
import urllib.error
import socket
from collections import Counter

# Set a global socket timeout of 8 seconds to prevent any TCP hang
socket.setdefaulttimeout(8.0)

# ==========================================
# 🚀 PİLOT MODU AYARI
# ==========================================
PILOT_MODE = False  # Büyük üretim için pilot modu kapatıldı!

# ==========================================
# 📝 KATEGORİ TOHUMLARI VE KONSEPTLER
# ==========================================
SEEDS = {
    "Ziman": [
        {"term": "ergatîf", "desc": "avahiya rêzimanî ya ku kirdeya lêkerên gerguhêz di dema borî de tewandî nîşan dide"},
        {"term": "tewandin", "desc": "guhertina paşgira navdêr an cînavkan li gorî rola wan a di hevokê de"},
        {"term": "ezafe", "desc": "têkiliya artêla mê (a) û nêr (ê) ya ku navdêran bi hev ve girê dide"},
        {"term": "cînavkên tewandî", "desc": "cînavkên wekî 'min, te, wî, wê, me, we, wan' ku di bin tewandinê de ne"},
        {"term": "daçekên hevedudanî", "desc": "peyvên wekî 'di... de, bi... re, ji... re' ku têkiliyên cih nîşan didin"},
        {"term": "lêkera gerguhêz", "desc": "lêkerên ku hewcedariya wan bi artêla tewandî heye bo temamkirina wateyê"},
        {"term": "rênivîsa Hawarê", "desc": "pergala alfabeya kurdî ya bi tîpên latînî ku ji aliyê Celadet Bedirxan ve hatibû amadekirin"},
        {"term": "cînavkên kesane", "desc": "nîşanderên wekî 'ez, tu, ew, em, hûn, ew' ên ku bo kesan tên bikaranîn"},
        {"term": "dema borî ya dûr", "desc": "avahiya lêkerê ya ku kiryarek di rabirdûyeke pir dûr de nîşan dide"},
        {"term": "paşgirên tewandinê", "desc": "hêmanên wekî '-î, -ê, -an' ku di tewandina navdêran de cih digirin"}
    ],
    "Edebiyat": [
        {"term": "Melayê Cizîrî", "desc": "helbestvanê mezin ê klasîk ku bi dîwana xwe ya felsefî û tesewifî tê naskirin"},
        {"term": "Feqiyê Teyran", "desc": "helbestvanê klasîk ê ku bi berhema 'Şêx Sen'an' û axaftina bi çûkan re navdar e"},
        {"term": "Ehmedê Xanî", "desc": "nivîskarê destana nemir a 'Mem û Zîn' ku hîmê ramanî yê kurdewariyê daniye"},
        {"term": "Melayê Bateyî", "desc": "helbestvanê ku Mewlûdaya Kurdî bi zaravayê kurmancî nivîsiye"},
        {"term": "kovara Hawarê", "desc": "kovara edebî û çandî ya ku di sala 1932an de li Şamê bi destê Bedirxaniyan derketiye"},
        {"term": "Cegerxwîn", "desc": "helbestvanê şoreşger û civakî yê ku helbesta kurdî ya modern biriye qonaxeke nû"},
        {"term": "Arabê Şamo", "desc": "nivîskarê kurd ê ku bi romana 'Şivanê Kurd' di wêjeya modern de tê naskirin"},
        {"term": "Mehmed Uzun", "desc": "romannivîsê kurd ê modern ku bi zimanekî kûr û edebî şoreşek di romana kurdî de çêkir"},
        {"term": "şevbêrkên wêjeyî", "desc": "civînên şevê yên ku tê de helbest û çîrokên klasîk û modern dihatin xwendin"},
        {"term": "Helbesta Azad", "desc": "rêbaza helbesta nûjen a bê pîvan û bê qafiye ku bi taybetî li ser peyvan ava dide"}
    ],
    "Dîrok": [
        {"term": "Împaratoriya Medî", "desc": "hêza antîk a li herêma Zagrosê ku di dîroka kevn a herêmê de cih digire"},
        {"term": "Dewleta Merwaniyan", "desc": "xanedaniya kurdî ya serdema navîn ku navenda wê Amed û doralên wê bûn"},
        {"term": "Mîrgeha Botan", "desc": "mîrnişîna kurdî ya bihêz a ku navenda wê Cizîra Botan bû û xwedî serxwebûneke çandî bû"},
        {"term": "Şerefname", "desc": "pirtûka dîroka mîrgehên kurdî ku di sala 1597an de ji aliyê Şerefxanê Bedlîsî ve hatibû nivîsandin"},
        {"term": "Kovara Jîn", "desc": "weşana dîrokî ya kurdî ya serdema destpêka sedsala 20an ku li ser mafên neteweyî dinivîsî"},
        {"term": "Selaheddînê Eyûbî", "desc": "serokê mezin ê kurd ku Quds ji xaçperestan rizgar kir û xanedaniya Eyûbiyan ava kir"},
        {"term": "Mîrê Kor", "desc": "mîrê navdar ê Soran ku di sedsala 19an de hewl da yekîtiya kurdî ava bike"},
        {"term": "Rojnameya Kurdistan", "desc": "rojnameya yekem a kurdî ku di sala 1898an de li Qahîreyê ji aliyê Mîqdat Mîdhad Bedirxan ve hat weşandin"},
        {"term": "Mîrgeha Erdelanê", "desc": "mîrnişîneke kevnar a kurdî ya li rojhilat ku navenda wê Sine bû"},
        {"term": "Peymana Lozanê", "desc": "peymana navdewletî ya sala 1923an ku piştî Şerê Cîhanê Yê Yekem çarçoveya hin sînorên herêmê ava kir"}
    ],
    "Cografya": [
        {"term": "çiyayên Zagrosê", "desc": "rêzeçiyayên mezin û asê yên ku sînorê xwezayî yê welatê kurdan pêk tînin"},
        {"term": "Newala Dîcleyê", "desc": "geliyê mezin ê ku çemê Dîcleyê tê re diherike û Amedê diparêze"},
        {"term": "Çemê Firatê", "desc": "yek ji du çemên herî mezin ên Mezopotamyayê ku jiyanê dide axên berdar"},
        {"term": "Çiyayê Cûdî", "desc": "çiyayê pîroz ê ku li gorî baweriyan keştiya Nûh Pêxember li ser rûniştiye"},
        {"term": "Girê Mirazan", "desc": "şûna arkeolojîk a li nêzîkî bajarê Rihayê ku ji bo lêkolîna dîroka destpêkê girîng e"},
        {"term": "Gola Wanê", "desc": "gola herî mezin a herêmê ku avên wê şor û sodadar in"},
        {"term": "Çiyayê Sîpanê", "desc": "çiyayê volkanîk ê bilind û berfîn ê li bakurê Gola Wanê"},
        {"term": "Geliyê Zapê", "desc": "geliyê kûr û teng ê ku ava Zapê ya hov tê re diherike ber bi başûr ve"},
        {"term": "Heskîf", "desc": "bajarê kevnar û dîrokî yê li ser çemê Dîcleyê ku xwedî şikeftên bêhempa ye"},
        {"term": "Qerejdax", "desc": "çiyayê volkanîk ê bazaltî ku deşta Amedê ji ya rihayê vediqetîne"}
    ],
    "Çand": [
        {"term": "Sazîbûna Dengbêjiyê", "desc": "kela parastina ziman û dîrokê ku bi riya stran û klamên dengbêjan tê meşandin"},
        {"term": "Newroz", "desc": "cejna neteweyî û sersala kurdî ya ku sembola serhildan, azadî û vejîna xwezayê ye"},
        {"term": "Kalo û Sersal", "desc": "şano û lîstika gelêrî ya kurdî ku di dema sersalê de li gundan tê lîstin"},
        {"term": "Govenda Kurdî", "desc": "dansa komî û gelêrî ya ku bi hevgirtina destan û bi rihê hevkariyê tê gerandin"},
        {"term": "çanda koçeriyê", "desc": "şêwazê jiyana kevnar a li ser zozan û germiyanê ku çanda kurdî pir dewlemend kiriye"},
        {"term": "mêvanperweriya kurdî", "desc": "têkiliya civakî ya ku tê de mêvan wekî bereketa malê tê qebûl kirin"},
        {"term": "kilimên kurdî", "desc": "elhunera kevnar a jinên kurd ku motîfên li ser wan çîrokên dîrokî vedibêjin"},
        {"term": "Destana Memê Alan", "desc": "destana neteweyî ya kurdî ya ku hîmê Mem û Zîna Xanî pêk tîne"},
        {"term": "hewran", "desc": "çadira reş a ku ji mûyê bizinan tê çêkirin û koçeran ji germ û sermayê diparêze"},
        {"term": "şevbêrk", "desc": "civînên şevê yên zivistanê ku tê de çîrokên gelêrî û metelok dihatin gotin"}
    ],
    "Muzîk": [
        {"term": "tembûr", "desc": "amûra muzîkê ya herî pîroz û kevnar a kurdî ku bi taybetî di civatên olî de tê lêdan"},
        {"term": "erbane", "desc": "amûra lêdanê ya zildar ku di muzîka kurdî ya olî û gelêrî de xwedî cihekî girîng e"},
        {"term": "bilûr", "desc": "amûra bayê ya çobanan ku bi dengê xwe yê xemgîn û lîrik tê naskirin"},
        {"term": "lîrîka klaman", "desc": "avahiya helbestî ya kilamên dengbêjiyê ku çîrokên evîn û şeran vedibêjin"},
        {"term": "Şakiro", "desc": "dengbêjê mezin ê ku wekî 'Şahê Dengbêjan' tê naskirin û xwedî dengekî bêhempa bû"},
        {"term": "Hasan Cizrawî", "desc": "yek ji stûnên muzîka kurmancî ya klasîk ku kilamên devera Botan tomar kirine"},
        {"term": "Meryem Xan", "desc": "stranbêja kurd ku dengê xwe li ser plakan tomar kiriye"},
        {"term": "Koma Wetan", "desc": "koma muzîka rock a kurdî ya ku di salên 70an de derketibû holê"},
        {"term": "lawik", "desc": "şêwazê muzîka dengbêjiyê yê ku li ser lehengiya mêran û şeran tê gotin"},
        {"term": "heyran", "desc": "klamên evînê yên devera Serhadê ku bi taybetî ji aliyê jinan ve dihatin gotin"}
    ],
    "Siyaset": [
        {"term": "Radikal demokrasi", "desc": "teoriya siyasî ya ku beşdariya rasterast a gel di biryaran de diparêze"},
        {"term": "hevserokatiyê", "desc": "sîstema hevseng a ku tê de jin û mêr bi hev re di saziyan de serokatiyê dikin"},
        {"term": "komûn û meclîs", "desc": "avahiyên herî bingehîn ên xwe-rêveberiya gel li tax û gundan"},
        {"term": "peymana civakî", "desc": "belgeya bingehîn a ku prensîbên jiyana hevbeş û azad a gelan diyar dike"},
        {"term": "ademi-merkeziyet", "desc": "parvekirina desthilatê ji navendê ber bi herêm û rêveberiyên xweser ve"},
        {"term": "parastina rewa", "desc": "mafê parastina xwezayî ya civakê li dijî êrîşên derveyî"},
        {"term": "pirrengî", "desc": "prensîba parastin û pejirandina hemû nasnameyên cuda yê di civakê de"},
        {"term": "demokrasiya rasterast", "desc": "şêwazê rêveberiyê ku tê de gel bêyî nûneran biryaran dide"},
        {"term": "xweseriya demokratîk", "desc": "modela siyasî ya ku tê de gelên herêmê saziyên xwe bi xwe birêve dibin"},
        {"term": "hevpeymaniya demokratîk", "desc": "têkiliya stratejîk a di navbera hêzên guhertinê yê civakê de"}
    ],
    "Paradigma": [
        {"term": "Konfederalîzma Demokratîk", "desc": "modela birêvebirina civakê ya li derveyî sîstema dewlet-neteweyê"},
        {"term": "Moderniteya Demokratîk", "desc": "modela alternatîf a jiyanê ya li dijî kapîtalîzma modern"},
        {"term": "Jineolojî", "desc": "di gotûbêja tevgerê de nêzîkatiyek ku azadiya civakê bi azadiya jinê ve girê dide"},
        {"term": "Ekolojiya Civakî", "desc": "têkiliya hevseng û dostane ya di navbera civakê û xwezayê de"},
        {"term": "aboriya komûnal", "desc": "modela aboriyê ya ku li ser bingeha parvekirin û hewcedariyê tê avakirin, ne tenê li ser qezencê"},
        {"term": "civaka exlaqî-polîtîk", "desc": "civaka azad a ku biryarên xwe bi hişmendiya exlakî û polîtîk dide"},
        {"term": "rexneya patriyarkayê", "desc": "analîzkirin û hilweşandina sîstema serdest a mêr a li ser civakê"},
        {"term": "hiyerarşiya civakî", "desc": "avahiya serdestiyê ya ku civakê dabeşî çînên jor û jêr dike"},
        {"term": "zanistiya azad", "desc": "hişmendiya zanistî ya ku ji bin tekelên desthilatê derketiye û ji civakê re xizmet dike"},
        {"term": "azadiya zayendî", "desc": "prensîba azadiya jin û mêr û wekheviya wan a di her qada jiyanê de"}
    ]
}

# ==========================================
# 🛑 TÜRKÇE VE YANLIŞ KARAKTER FİLTRELERİ
# ==========================================
TURKISH_STOPWORDS = [
    "hangisi", "aşağıdakilerden", "anlamına", "gelir", "nedir", "ilişkilidir", "doğrudur", "yanlıştır",
    "veya", "için", "biridir", "tanımıdır", "hakkında", "verilen", "bilgilerden", "en", "doğru", "bilgi",
    "amaçlanmıştır", "bağlamında", "açısından", "neyi", "ifade", "eder", "kavramı", "terimi", "seçeneklerden",
    "uygun", "açıklamasıdır", "hangisidir", "şu", "neden", "önemlidir", "hangisiyle",
    "ilişkilendirilir", "gösteriyor", "pekiştirir", "görsel", "etiketi", "tarihsel",
    "sadece", "değildir", "kabul", "edilir", "yalnızca", "dışındaki", "konuları", "inceler", "geçerli",
    "hiçbir", "bağı", "bulunmamaktadır", "çerçevesinde", "amaçla", "ele", "alınır", "doğrudan", "bağlantılıdır",
    "konusunun", "yeri", "aydinlatir", "temel", "kavramlardan", "denildiğinde", "anlaşılmalıdır", "yönelik",
    "anlam", "taşır", "şekilde", "yorumlanır", "taşıdığı", "toplumsal", "bilinç", "yakın", "sahiptir",
    "yapılan", "araştırmalarda", "vurgulanır", "yapı", "içinde", "önemi", "kullanımıdir", "literatüründe",
    "kullanılmaz", "sıkça", "başvurulur", "süreçte", "gelişimine", "katkı", "sağlamıştır", "bilimlerde",
    "yaygındır", "geleneksel", "birikiminde", "izlerine", "rastlanır", "türkçe", "karşılığı", "nedir"
]

TURKISH_CHARACTERS = ["ı", "ğ", "ü", "ö"]
KURDISH_CHARACTERS = ["ç", "ş", "ê", "î", "û"]

# DB anahtarları korunur; soru metninde doğal Kurmancî kategori adları kullanılır.
CATEGORY_LABELS = {
    "Edebiyat": "wêje",
    "Cografya": "erdnîgarî",
}

# Kategori düzeyindeki destekleyici kaynaklar; soru yayımlanmadan önce seed
# düzeyinde ikinci bir kaynakla doğrulama yapılır.
SOURCE_REGISTRY = {
    "Ziman": "https://nykcc.org/oldsite/hawar-archive/",
    "Edebiyat": "https://www.iranicaonline.org/articles/kurdish-written-literature/",
    "Dîrok": "https://www.iranicaonline.org/articles/kurds-studies-of-modern-kurdish-history/",
    "Cografya": "https://www.iranicaonline.org/articles/geology/",
    "Çand": "https://www.iranicaonline.org/articles/oral-literature-in-iran/",
    "Muzîk": "https://www.kurdipedia.org/docviewer.aspx?book=20220816235906428748&lng=3",
    "Siyaset": "https://anfenglishmobile.com/kurdIstan/kjar-dan-10-boyutlu-bir-devrim-projesi-177521",
    "Paradigma": "https://kongra-star.org/eng/about/",
}

# 8 şablon x 25 bağlam, her tohum için 200 ayrı prompt kombinasyonu sağlar;
# bu, 1.500 soruluk kategorilerde tohum başına 150 soruyu da kapsar.
VARIANT_CONTEXTS = [
    "di destpêkê de", "di asta bingehîn de", "di asta navîn de",
    "di asta pêşketî de", "di xwendina rojane de", "di lêkolîna kurt de",
    "di gotûbêja dersê de", "di bîranîna dîrokî de", "di jiyana civakî de",
    "di nirxandina zanînê de", "di berhevkirina têgehan de",
    "di xwendina nivîsekê de", "di pirsên pratîkî de",
    "di rêza yekem de", "di rêza duyem de", "di rêza sêyem de",
    "di şertên nû de", "di şertên kevn de", "di mînakekê de",
    "di berawirdkirinê de", "di pirsên kurt de", "di pirsên dirêj de",
    "di xwendina komî de", "di xwendina kesane de", "di vekolîna têgehê de",
]

# ==========================================
# 🛠️ GÜVENLİK VE FİLTRE MOTORU
# ==========================================
def validate_question(q, attempt=1):
    """
    Soru nesnesinin dil, karakter ve varyans kurallarına uygunluğunu doğrular.
    """
    all_text = (q["prompt"] + " " + " ".join(q["answers"]) + " " + q["explanation"]).lower()
    
    # 1. Türkçe Stopwords Kontrolü
    words = re.findall(r'\b\w+\b', all_text)
    for w in words:
        if w in TURKISH_STOPWORDS:
            return False, f"Türkçe kelime tespit edildi: {w}"
            
    # 2. Türkçe Karakter Kontrolü
    for char in TURKISH_CHARACTERS:
        if char in all_text:
            return False, f"Türkçe karakter tespit edildi: {char}"

    correct = q["correctAnswer"].strip().lower()
    prompt = q["prompt"].strip().lower()
    if len(correct) >= 6 and correct in prompt:
        return False, "Doğru cevap prompt içinde açıkça geçiyor"
            
    # 3. Şık Varyans Kontrolü (SD Kontrolü)
    lengths = [len(a) for a in q["answers"]]
    mean_length = sum(lengths) / len(lengths)
    variance = sum((x - mean_length) ** 2 for x in lengths) / len(lengths)
    std_dev = variance ** 0.5
    
    allowed_sd = 6.0
    if mean_length > 30:
        allowed_sd = 15.0
    elif mean_length > 15:
        allowed_sd = 10.0
        
    # Scale allowed SD dynamically with attempts to prevent validation deadlock
    allowed_sd += attempt * 0.5
        
    if std_dev > allowed_sd:
        return False, f"Şık uzunluk dengesizliği yüksek (SD: {std_dev:.2f}, limit: {allowed_sd:.2f})"
        
    return True, "Geçerli"


def normalize_prompt(prompt):
    return re.sub(r"\s+", " ", prompt.strip().casefold())

# ==========================================
# 🧠 DART / TEMPLATE TABANLI GÜVENLİ JENERATÖR
# ==========================================
def generate_fallback_kurdish_question(cat, seed, idx, attempt=1):
    """
    API kapalıysa veya hata verirse devreye girecek saf Kurmancî template jeneratörü.
    """
    term = seed["term"]
    desc = seed["desc"]
    label = CATEGORY_LABELS.get(cat, cat.lower())
    context = VARIANT_CONTEXTS[idx % len(VARIANT_CONTEXTS)]
    
    # 8 Felsefi / Dilbilimsel Saf Kurmancî Şablon
    templates = [
        {
            "prompt": f"{context.capitalize()}, di warê {label} de têgeha '{term}' bi kîjan pênaseya xwe ya bingehîn tê naskirin?",
            "correct": desc,
            "type": "multipleChoice"
        },
        {
            "prompt": f"{context.capitalize()}, kîjan vebijark di çarçoveya {label} de wateya têgeha '{term}' bi awayekî herî rast nîşan dide?",
            "correct": f"Ew wekî '{desc}' tê pênasekirin.",
            "type": "multipleChoice"
        },
        {
            "prompt": f"{context.capitalize()}, têgeha '{term}' a ku di qada {label} de derdikeve pêş, çi nîşan dide?",
            "correct": desc,
            "type": "multipleChoice"
        },
        {
            "prompt": f"{context.capitalize()}, ravekirina '{desc}' têkildarî kîjan têgeha {label} ye?",
            "correct": term,
            "type": "multipleChoice"
        },
        {
            "prompt": f"{context.capitalize()}, di qada {label} de têgeha '{term.capitalize()}' di heman demê de wekî '{desc}' tê binavkirin.",
            "correct": "Rast",
            "type": "trueFalse"
        },
        {
            "prompt": f"{context.capitalize()}, têgeha '{term.capitalize()}' di qada {label} de tu wateyê nîşan nade.",
            "correct": "Şaş",
            "type": "trueFalse"
        },
        {
            "prompt": f"{context.capitalize()}, di lêkolînên {label} de, avahiya '{term}' wekî mijareke sereke tê qebûlkirin.",
            "correct": "Rast",
            "type": "trueFalse"
        },
        {
            "prompt": f"{context.capitalize()}, di qada {label} de pênaseya '{desc}' bi tevahî li derveyî çarçoveya '{term}' dimîne.",
            "correct": "Şaş",
            "type": "trueFalse"
        }
    ]
    
    # Vary the template index dynamically based on attempts to cycle through templates
    selected_template = templates[(idx + attempt) % len(templates)]
    
    # Kategori havuzundan çeldiriciler
    all_descs = [s["desc"] for s in SEEDS[cat] if s["desc"] != desc]
    all_terms = [s["term"] for s in SEEDS[cat] if s["term"] != term]
    
    answers = []
    if selected_template["type"] == "trueFalse":
        answers = ["Rast", "Şaş"]
    else:
        if selected_template["correct"] == term:
            distractors = random.sample(all_terms, min(3, len(all_terms)))
        else:
            distractors = random.sample(all_descs, min(3, len(all_descs)))
            
        answers = [selected_template["correct"]] + distractors
        random.shuffle(answers)
        
    return {
        "prompt": selected_template["prompt"],
        "answers": answers,
        "correctAnswer": selected_template["correct"],
        "explanation": f"Têgeha '{term}' di bin sîwana {label} de xwedî roleke giring e.",
        "type": selected_template["type"]
    }

# ==========================================
# 🛰️ GEMINI API ÜRETİM SİSTEMİ
# ==========================================
def generate_via_gemini(cat, seed, api_key):
    """
    Gemini API kullanarak yapılandırılmış saf Kurmancî soru üretir.
    """
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
    
    label = CATEGORY_LABELS.get(cat, cat.lower())
    prompt_instruction = f"""
    Li ser qada "{label}" û mijara "{seed['term']}" (têkilî: {seed['desc']}) pirsiyarekê ava bike.
    Pirsyar divê 100% bi Kurmanciya saf a akademîk be.
    
    Şema JSON:
    {{
      "prompt": "Pirs bi Kurmanciya saf",
      "answers": ["Şika Rast", "Çeldirici 1", "Çeldirici 2", "Çeldirici 3"],
      "correctAnswer": "Şika Rast",
      "explanation": "Ravekirina pirsê bi Kurmanciya saf",
      "type": "multipleChoice"
    }}
    
    Rêzik:
    - Tu peyvek an paşgirek Tirkî (wek -dir, veya, çünkü) bi kar neyne.
    - Her çar vebijark (answers) divê di dirêjahiya xwe de hevseng bin (dirêjahiya peyvan an hevokan nêzîkî hev bin, ne ku yek pir dirêj be û yên din pir kurt bin).
    """
    
    data = {
        "contents": [{
            "parts": [{"text": prompt_instruction}]
        }],
        "generationConfig": {
            "responseMimeType": "application/json"
        }
    }
    
    req_body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=req_body,
        headers={"Content-Type": "application/json"}
    )
    
    try:
        # Rate limit gecikmesi (429 önlemi): Her API çağrısından önce 2.5 saniye bekle
        time.sleep(2.5)
        
        with urllib.request.urlopen(req, timeout=15) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            text_response = res_data["candidates"][0]["content"]["parts"][0]["text"]
            return json.loads(text_response.strip())
    except Exception:
        return None

# ==========================================
# 💾 SQL SEED KAYDETME FONKSİYONLARI
# ==========================================
def escape_sql(val):
    if val is None:
        return "NULL"
    return "'" + val.replace("'", "''") + "'"

def save_to_sql_file(questions, filename):
    print(f"\nSQL dosyası yazılıyor: {filename}...")
    sys.stdout.flush()
    with open(filename, "w", encoding="utf-8") as f:
        source_values = ", ".join(escape_sql(url) for url in SOURCE_REGISTRY.values())
        f.write("-- Clean up existing editorial source rows first\n")
        f.write(f"DELETE FROM public.player_answers WHERE question_id IN (SELECT id FROM public.questions WHERE source_url IN ({source_values}));\n")
        f.write(f"DELETE FROM public.room_questions WHERE question_id IN (SELECT id FROM public.questions WHERE source_url IN ({source_values}));\n")
        f.write(f"DELETE FROM public.questions WHERE source_url IN ({source_values});\n\n")
        
        chunk_size = 500
        for i in range(0, len(questions), chunk_size):
            chunk = questions[i:i+chunk_size]
            f.write("insert into public.questions (\n")
            f.write("  category_id,\n")
            f.write("  language_code,\n")
            f.write("  prompt,\n")
            f.write("  option_a,\n")
            f.write("  option_b,\n")
            f.write("  option_c,\n")
            f.write("  option_d,\n")
            f.write("  correct_option,\n")
            f.write("  explanation,\n")
            f.write("  difficulty,\n")
            f.write("  is_approved,\n")
            f.write("  question_type,\n")
            f.write("  image_url,\n")
            f.write("  source_url\n")
            f.write(") values\n")
            
            value_lines = []
            for q in chunk:
                q_type = "multiple_choice" if q["type"] == "multipleChoice" else "true_false"
                if q["type"] == "trueFalse":
                    opt_a = "Rast"
                    opt_b = "Şaş"
                    opt_c = "-"
                    opt_d = "-"
                    correct_opt = "A" if q["correctAnswer"] == "Rast" else "B"
                else:
                    opt_a = q["answers"][0]
                    opt_b = q["answers"][1]
                    opt_c = q["answers"][2]
                    opt_d = q["answers"][3]
                    try:
                        correct_idx = q["answers"].index(q["correctAnswer"])
                    except ValueError:
                        correct_idx = 0
                    correct_opt = chr(65 + correct_idx)
                    
                cat_subquery = f"(select id from public.categories where name = {escape_sql(q['category'])})"
                
                line = (
                    f"({cat_subquery}, "
                    f"'ku-kmr', "
                    f"{escape_sql(q['prompt'])}, "
                    f"{escape_sql(opt_a)}, "
                    f"{escape_sql(opt_b)}, "
                    f"{escape_sql(opt_c)}, "
                    f"{escape_sql(opt_d)}, "
                    f"'{correct_opt}', "
                    f"{escape_sql(q['explanation'])}, "
                    f"{q['difficulty']}, "
                    f"true, "
                    f"'{q_type}', "
                    f"NULL, "
                    f"{escape_sql(q['source_url'])})"
                )
                value_lines.append(line)
            
            f.write(",\n".join(value_lines))
            f.write(";\n\n")


def generate_fast_bank(output_file):
    """Tek-geçişli yerel üretim; tekrar denemeleri yalnızca kalite reddinde yapar."""
    limits = {cat: 1250 for cat in SEEDS}
    questions = []
    seen = set()
    question_id = 15000

    for cat, limit in limits.items():
        seeds = SEEDS[cat]
        for index in range(limit):
            seed_index = index % len(seeds)
            seed = seeds[seed_index]
            seed_variant = index // len(seeds)
            accepted = None
            for attempt in range(1, 9):
                candidate = generate_fallback_kurdish_question(cat, seed, seed_variant, attempt)
                valid, _ = validate_question(candidate, attempt)
                key = normalize_prompt(candidate["prompt"])
                if valid and key not in seen:
                    accepted = candidate
                    seen.add(key)
                    break
            if accepted is None:
                raise RuntimeError(f"Kalite filtresi geçilemedi: {cat}/{index}")
            questions.append({
                "id": f"pure_{question_id}",
                "category": cat,
                "prompt": accepted["prompt"],
                "answers": accepted["answers"],
                "correctAnswer": accepted["correctAnswer"],
                "explanation": accepted["explanation"],
                "difficulty": 1 + (index % 5),
                "type": accepted["type"],
                "imageUrl": None,
                "source_url": SOURCE_REGISTRY[cat],
            })
            question_id += 1
        print(f"{cat}: {limit} soru hazırlandı")
        sys.stdout.flush()

    save_to_sql_file(questions, output_file)
    print(f"Toplam üretilen soru sayısı: {len(questions)}")

# ==========================================
# 🏃 MAİN ENGINE
# ==========================================
def main():
    print("=== Zankurd Pure Kurdish Generator (BÜYÜK ÜRETİM MODU) ===")
    sys.stdout.flush()
    # Dış model üretimi açıkça istenmedikçe kullanılmaz; böylece dalga
    # üretimi deterministik, denetlenebilir ve anahtar-bağımsız kalır.
    api_key = os.environ.get("GEMINI_API_KEY") if os.environ.get("ZANKURD_USE_GEMINI") == "1" else None
    if api_key:
        print("Gemini API Key tespit edildi, canlı üretim modu aktif.")
    else:
        print("Gemini API Key bulunamadı, güvenli şablon jeneratörü aktif.")
    sys.stdout.flush()
        
    output_questions = []
    seen_prompts = set()
    id_counter = 15000

    output_file = os.environ.get(
        "ZANKURD_OUTPUT_FILE",
        "c:/Users/AMARGİ/Desktop/pirs kurmanci/zankurd_mobile/rich_question_bank_pure_kurdish.sql",
    )
    if os.environ.get("ZANKURD_FAST_MODE", "1") == "1":
        generate_fast_bank(output_file)
        return
    
    # Siyaset ve Paradigma 1.500'er adet, diğer 6 kategori 1.000'er adet
    questions_per_cat = {
        "Ziman": 1000,
        "Edebiyat": 1000,
        "Dîrok": 1000,
        "Cografya": 1000,
        "Çand": 1000,
        "Muzîk": 1000,
        "Siyaset": 1500,
        "Paradigma": 1500
    }
    
    if PILOT_MODE:
        # Eğer birisi kazara pilot modunu açarsa diye güvenlik emniyeti
        questions_per_cat = {cat: 10 for cat in SEEDS.keys()}
    
    for cat, limit in questions_per_cat.items():
        print(f"\nKategori üretiliyor: {cat} (Hedef: {limit} soru)")
        sys.stdout.flush()
        cat_seeds = SEEDS[cat]
        generated_count = 0
        
        while generated_count < limit:
            seed = cat_seeds[generated_count % len(cat_seeds)]
            attempts_for_q = 0
            is_valid = False
            
            while not is_valid:
                attempts_for_q += 1
                question_data = None
                
                # Gemini ile en fazla 4 deneme yap, başarısız olursa Fallback şablona geç
                if api_key and attempts_for_q <= 4:
                    print(f"  [{generated_count + 1}/{limit}] Terim üretiliyor (Gemini, deneme {attempts_for_q}): {seed['term']}...")
                    sys.stdout.flush()
                    question_data = generate_via_gemini(cat, seed, api_key)
                
                if not question_data:
                    if generated_count % 100 == 0 or attempts_for_q > 5:
                        print(f"  [{generated_count + 1}/{limit}] Terim üretiliyor (Fallback, deneme {attempts_for_q}): {seed['term']}...")
                        sys.stdout.flush()
                    question_data = generate_fallback_kurdish_question(cat, seed, generated_count, attempts_for_q)
                    
                is_valid, reason = validate_question(question_data, attempts_for_q)

                prompt_key = normalize_prompt(question_data["prompt"])
                if is_valid and prompt_key in seen_prompts:
                    is_valid = False
                    reason = "Prompta dubare hate dîtin"
                
                if is_valid:
                    new_q = {
                        "id": f"pure_{id_counter}",
                        "category": cat,
                        "prompt": question_data["prompt"],
                        "answers": question_data["answers"],
                        "correctAnswer": question_data["correctAnswer"],
                        "explanation": question_data["explanation"],
                        "difficulty": 1 + (generated_count % 5),
                        "type": question_data["type"],
                        "imageUrl": None,
                        "source_url": SOURCE_REGISTRY[cat]
                    }
                    output_questions.append(new_q)
                    seen_prompts.add(prompt_key)
                    id_counter += 1
                    generated_count += 1
                    # Her 100 soruda bir durum logu yaz
                    if generated_count % 100 == 0:
                        print(f"    -> [Durum] {cat} kategorisinde {generated_count} soru üretildi.")
                else:
                    if attempts_for_q > 5 and attempts_for_q % 5 == 0:
                        print(f"    -> [Reddedildi] Neden: {reason}")
                if generated_count % 100 == 0:
                    sys.stdout.flush()
                    
    save_to_sql_file(output_questions, output_file)
    
    print("\n=== Büyük Üretim Başarıyla Tamamlandı ===")
    print(f"Toplam üretilen soru sayısı: {len(output_questions)}")
    print(f"Çıktı dosyası kaydedildi: {output_file}")

if __name__ == "__main__":
    main()
