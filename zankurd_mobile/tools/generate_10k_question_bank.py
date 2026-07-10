import re
import random
import csv
import shutil
from collections import defaultdict, Counter
from pathlib import Path

# Fix random seed for reproducibility
random.seed(42)

# File Paths
OFFLINE_FILE = Path("c:/Users/AMARGİ/Desktop/pirs kurmanci/zankurd_mobile/lib/src/data/offline_question_bank.dart")
SQL_FILE = Path("c:/Users/AMARGİ/Desktop/pirs kurmanci/zankurd_mobile/supabase/rich_question_bank_v2.sql")
CSV_V2_FILE = Path("c:/Users/AMARGİ/Desktop/pirs kurmanci/zankurd_mobile/supabase/rich_question_bank_v2_questions.csv")
CSV_READY_FILE = Path("c:/Users/AMARGİ/Desktop/pirs kurmanci/zankurd_mobile/supabase/questions_import_ready.csv")

BACKUP_DIR = Path("C:/Users/AMARGİ/.gemini/antigravity-ide/brain/d30086da-5581-4930-963c-31bbb230a684/scratch/backup")

# Restore original pre-10k offline question bank for a clean run
shutil.copy2(BACKUP_DIR / "offline_question_bank_pre10k.dart.bak", OFFLINE_FILE)
print("Original pre-10k offline_question_bank.dart restored.")

# Helper functions for string parsing
def parse_dart_string(s):
    if (s.startswith("'") and s.endswith("'")) or (s.startswith('"') and s.endswith('"')):
        quote = s[0]
        content = s[1:-1]
        if quote == "'":
            content = content.replace("\\'", "'").replace("\\\\", "\\")
        else:
            content = content.replace('\\"', '"').replace("\\\\", "\\")
        return content
    return s

def to_dart_string(s):
    escaped = s.replace('\\', '\\\\').replace("'", "\\'")
    escaped = escaped.replace('\n', '\\n')
    return f"'{escaped}'"

# 2. Parse existing 1155 questions
content = OFFLINE_FILE.read_text(encoding="utf-8")

existing_questions = []
pos = 0
while True:
    idx = content.find("QuizQuestion(", pos)
    if idx == -1:
        break
    
    start = idx + len("QuizQuestion(")
    depth = 1
    i = start
    while i < len(content) and depth > 0:
        if content[i] == '(':
            depth += 1
        elif content[i] == ')':
            depth -= 1
        i += 1
    
    block = content[idx:i]
    pos = i
    
    id_match = re.search(r"id:\s*'([^']*)'", block)
    category_match = re.search(r"category:\s*'([^']*)'", block)
    
    str_literal_re = r"'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\""
    
    prompt_match = re.search(r"prompt:\s*(" + str_literal_re + ")", block, re.DOTALL)
    correct_match = re.search(r"correctAnswer:\s*(" + str_literal_re + ")", block)
    explanation_match = re.search(r"explanation:\s*(" + str_literal_re + ")", block, re.DOTALL)
    
    answers_match = re.search(r"answers:\s*\[([\s\S]*?)\]", block)
    type_match = re.search(r"type:\s*QuestionType\.(\w+)", block)
    diff_match = re.search(r"difficulty:\s*(\d+)", block)
    image_match = re.search(r"imageUrl:\s*'([^']*)'", block)
    
    if id_match and category_match:
        qid = id_match.group(1)
        category = category_match.group(1)
        
        prompt = parse_dart_string(prompt_match.group(1)) if prompt_match else ""
        correct = parse_dart_string(correct_match.group(1)) if correct_match else ""
        explanation = parse_dart_string(explanation_match.group(1)) if explanation_match else ""
        
        answers = []
        if answers_match:
            ans_str = answers_match.group(1)
            ans_tokens = re.findall(str_literal_re, ans_str)
            answers = [parse_dart_string(t) for t in ans_tokens]
            
        qtype = type_match.group(1) if type_match else "multipleChoice"
        difficulty = int(diff_match.group(1)) if diff_match else 1
        image_url = image_match.group(1) if image_match else None
        
        existing_questions.append({
            "id": qid,
            "category": category,
            "prompt": prompt,
            "answers": answers,
            "correctAnswer": correct,
            "explanation": explanation,
            "difficulty": difficulty,
            "type": qtype,
            "imageUrl": image_url
        })

print(f"Parsed {len(existing_questions)} existing questions.")

# 3. Define comprehensive seed pools (50-100 items per category)
vocab_seed = [
    ("av", "su"), ("roj", "gün/güneş"), ("mal", "ev"), ("pirtûk", "kitap"), ("zanîn", "bilmek"),
    ("hatin", "gelmek"), ("çiya", "dağ"), ("dil", "kalp/dil"), ("heval", "arkadaş"), ("bajar", "şehir"),
    ("nan", "ekmek"), ("rê", "yol"), ("spas", "teşekkür"), ("xweş", "güzel/iyi"), ("sar", "soğuk"),
    ("biçûk", "küçük"), ("kevin", "eski"), ("îro", "bugün"), ("duh", "dün"), ("nav", "ad/isim"),
    ("zarok", "çocuk"), ("xwendekar", "öğrenci"), ("rast", "doğru"), ("pir", "çok"), ("destpêk", "başlangıç"),
    ("dar", "ağaç"), ("kurd", "Kürt"), ("ziman", "dil"), ("dibistan", "okul"), ("mamoste", "öğretmen"),
    ("şev", "gece"), ("derya", "deniz"), ("stêrk", "yıldız"), ("heyv", "ay"), ("ba", "rüzgar"),
    ("baran", "yağmur"), ("berf", "kar"), ("agir", "ateş"), ("ax", "toprak"), ("hewa", "hava"),
    ("gul", "gül"), ("hesp", "at"), ("şêr", "aslan"), ("kûçik", "köpek"), ("pisîk", "kedi"),
    ("çem", "nehir"), ("newal", "vadi"), ("deşt", "ova"), ("zinar", "kaya"), ("kanî", "çeşme/pınar"),
    ("nanpêj", "fırıncı"), ("kar", "iş"), ("huner", "sanat"), ("rû", "yüz"), ("dest", "el"),
    ("pê", "ayak"), ("ser", "baş/kafa"), ("guh", "kulak"), ("çav", "göz"), ("poz", "burun"),
    ("dev", "ağız"), ("diran", "diş"), ("por", "saç"), ("xanî", "bina/ev"), ("derî", "kapı"),
    ("pencere", "pencere"), ("mase", "masa"), ("kursî", "sandalye"), ("nivîn", "yatak"), ("teşt", "leğen"),
    ("nanxane", "yemekhane"), ("xwendegeh", "okul/akademi"), ("pênûs", "kalem"), ("kaxiz", "kağıt"),
    ("wêne", "resim/fotoğraf"), ("deng", "ses"), ("reng", "renk"), ("pîr", "yaşlı/ihtiyar"), ("ciwan", "genç"),
    ("jin", "kadın"), ("mêr", "erkek"), ("malbat", "aile"), ("bira", "erkek kardeş"), ("xwîşk", "kız kardeş"),
    ("dê", "anne"), ("bav", "baba"), ("kal", "dede"), ("dapîr", "anneanne/babaanne"), ("gund", "köy"),
    ("welat", "ülke/vatan"), ("cîhan", "dünya"), ("hezkirin", "sevmek"), ("xwendin", "okumak"),
    ("nivîsandin", "yazmak"), ("çûn", "gitmek"), ("rûniştin", "oturmak"), ("rabûn", "kalkmak"),
    ("axaftin", "konuşmak"), ("dîtin", "görmek"), ("bihîstin", "işitmek")
]

culture_seed = [
    ("Newroz", "baharın gelişi ve yenilenme", "21 Adar"),
    ("govend", "toplu halk oyunu", "düğün ve kutlama"),
    ("dengbêj", "sözlü anlatım ve ezgili hikaye", "sözlü kültür"),
    ("kilim motifleri", "kültürel sembol ve renk hafızası", "el sanatı"),
    ("misafirperverlik", "toplumsal dayanışma", "gündelik kültür"),
    ("yerel kıyafetler", "kimlik ve bölgesel çeşitlilik", "gelenek"),
    ("ağıt", "duygu ve toplumsal hafıza", "sözlü gelenek"),
    ("masal anlatımı", "kuşaktan kuşağa aktarılan anlatı", "sözlü kültür"),
    ("bayramlaşma", "toplumsal bağları güçlendirme", "ziyaret"),
    ("halk mutfağı", "yerel yaşam ve paylaşım", "sofra kültürü"),
    ("hewran", "geleneksel kıl çadır yapımı", "göçebe yaşamı"),
    ("sînan", "geleneksel taş işçiliği", "mimari miras"),
    ("şahmaran", "doğu kültüründe mitolojik figür", "masal ve efsane"),
    ("heftegiyan", "geleneksel yedi tahıllı çorba", "yemek kültürü"),
    ("tûtik", "geleneksel kaval benzeri çalgı", "halk müziği"),
    ("nanê sêlê", "sac üzerinde pişirilen ekmek", "mutfak kültürü"),
    ("govendên herêmî", "yöresel halk dansları", "dans sanatı"),
    ("zembîlfiroş", "meşhur Kürt halk hikayesi", "sözlü edebiyat"),
    ("memê alan", "destansı Kürt halk anlatısı", "klasik destan"),
    ("kıl çadır", "göçebe Kürt aşiretlerinin barınağı", "yayla yaşamı"),
    ("helase", "geleneksel hasat ve bereket şenliği", "kültürel ritüel"),
    ("sersal", "Kürt halk takviminde yılbaşı kutlaması", "yeni yıl"),
    ("reşmal", "siyah keçi kılından yapılan çadır", "göçer kültürü"),
    ("kelaş", "el yapımı geleneksel Kürt ayakkabısı", "zanaat"),
    ("qutik", "geleneksel Kürt yeleği veya giysisi", "giyim kuşam"),
    ("şal û şapik", "geleneksel erkek giyim takımı", "yöresel giysi"),
    ("fistan", "geleneksel kadın giysisi", "yöresel kıyafet"),
    ("şax", "şırnak yöresine ait geleneksel dans", "halk oyunu"),
    ("lûr", "Kürt halk müziğinde ağıt benzeri ezgi", "müzik ritüeli"),
    ("serzêr", "düğünlerde geline takılan altınlar", "evlilik geleneği"),
    ("pêncşem", "geleneksel ziyaret ve anma günü", "inanç ritüeli"),
    ("sêpê", "üç ayaklı geleneksel halk dansı", "govend türü"),
    ("çilkez", "geleneksel Kürt saç örgüsü modeli", "saç tasarımı"),
    ("şîlan", "yabani gül ve bitkisel çay geleneği", "doğa kültürü"),
    ("destmal", "halay başının elinde salladığı mendil", "govend aksesuarı"),
    ("shivaniyeti", "geleneksel çobanlık ve doğa bilgisi", "yayla kültürü"),
    ("bêrîvan", "koyun sağan kadınların kültürel rolü", "yayla yaşamı"),
    ("koçerî", "göçer yaşam tarzı ve dans ritmi", "yaşam biçimi"),
    ("kew", "kınalı keklik ve doğa sevgisi sembolü", "kültürel motif"),
    ("tûrik", "yiyecek taşımak için dokunan torba", "el dokuması"),
    ("cîranî", "komşuluk ve toplumsal yardımlaşma", "social ethic"),
    ("beranberdan", "koç katımı ve hayvancılık şenliği", "mevsimlik ritüel"),
    ("bilûr", "kaval benzeri geleneksel üflemeli çalgı", "çoban çalgısı"),
    ("şabaş", "müzisyenlere bahşiş atma geleneği", "eğlence kültürü"),
    ("nanê tenûrê", "tandırda pişirilen geleneksel ekmek", "yemek mirası"),
    ("dew û av", "ayran ve su ikram etme kültürü", "misafirperverlik"),
    ("şevbêrk", "kış gecelerinde yapılan sohbet toplantıları", "sözlü paylaşım"),
    ("qazîn", "geleneksel kadın oyunları veya dansları", "halk dansı"),
    ("xana zêrîn", "masallardaki altın saray motifi", "halk efsanesi"),
    ("serpêhatî", "yaşanmış ilginç olayların anlatımı", "sözlü gelenek")
]

history_seed = [
    ("birincil kaynak", "döneminden kalan doğrudan belge veya nesne"),
    ("sözlü tarih", "tanıklık ve anlatılarla geçmişi anlama yöntemi"),
    ("kronoloji", "olayları zaman sırasına koyma"),
    ("arkeoloji", "maddi kalıntılarla geçmişi araştırma"),
    ("Mezopotamya", "Dicle ve Fırat çevresindeki tarihsel bölge"),
    ("göç", "toplulukların yer değiştirmesi"),
    ("yerleşik yaşam", "kalıcı yerleşim düzeni"),
    ("ticaret yolu", "bölgeler arası alışveriş güzergahı"),
    ("kültürel etkileşim", "toplumların birbirini etkilemesi"),
    ("tarihsel yorum", "kanıtlardan anlam çıkarma"),
    ("Med İmparatorluğu", "antik çağda Zagros merkezli büyük güç"),
    ("Şerefname", "Şeref Han tarafından yazılan Kürt tarihi eseri"),
    ("Mervaniler", "Diyarbakır merkezli ortaçağ Kürt hanedanlığı"),
    ("Eyyubiler", "Selahaddin Eyyubi tarafından kurulan büyük devlet"),
    ("Bedirhan Bey", "19. yüzyılda özerklik mücadelesi veren Kürt emiri"),
    ("Celadet Bedirxan", "Kürt alfabesini geliştiren yayıncı ve aydın"),
    ("Hawar dergisi", "Latin alfabesiyle basılan ilk Kürtçe dergi"),
    ("Şeyh Said", "1925 yılında Kürt hakları için isyan eden lider"),
    ("Dersim 1937", "Dersim bölgesinde yaşanan askeri harekat ve kriz"),
    ("Mahabad Cumhuriyeti", "1946'da kurulan ilk kısa ömürlü Kürt devleti"),
    ("Qazi Muhammed", "Mahabad Kürt Cumhuriyeti'nin cumhurbaşkanı"),
    ("Halepçe katliamı", "1988'de Kürtlere karşı yapılan kimyasal saldırı"),
    ("Anfal operasyonu", "Irak rejimi tarafından Kürtlere yönelik soykırım"),
    ("Lozan Antlaşması", "Kürt coğrafyasını dört devlete bölen antlaşma"),
    ("Kasr-ı Şirin Antlaşması", "Osmanlı ve Safevi sınırını belirleyen antlaşma"),
    ("Kürt Teali Cemiyeti", "20. yüzyıl başında kurulan Kürt örgütü"),
    ("Bitlis Prensliği", "Osmanlı döneminde özerk kalmış Kürt hükümdarlığı"),
    ("Bohtan Emirliği", "Cizre merkezli önemli Kürt beyliği"),
    ("Baban Emirliği", "Süleymaniye merkezli güçlü Kürt prensliği"),
    ("Soran Emirliği", "Ravanduz merkezli askeri güç biriktiren beylik"),
    ("Hakkari Emirliği", "Van gölü güneyinde hüküm sürmüş Kürt beyliği"),
    ("Mîrê Kor", "Soran emirliğinin kör lakaplı güçlü lideri"),
    ("Ehmedê Xanî", "17. yüzyılda Kürt aydınlanma fikrini yazan şair"),
    ("Mela Mahmude Bayazidi", "Kürt örf adetlerini derleyen ilk araştırmacı"),
    ("Jiyan gazetesi", "Süleymaniye'de basılan erken dönem Kürtçe gazete"),
    ("Kürdistan gazetesi", "Kahire'de 1898'de basılan ilk Kürt gazetesi"),
    ("Mikdat Mithat Bedirxan", "Kürdistan gazetesini çıkaran ilk Kürt gazeteci"),
    ("Şeyh Mahmud Berzenci", "Irak'ta kendini Kürdistan kralı ilan eden lider"),
    ("Koçgiri İsyanı", "1921'de Sivas yöresinde gelişen Kürt hareketi"),
    ("Ağrı İsyanları", "1927-1930 yılları arasında Ağrı dağı çevresindeki direniş"),
    ("Hoybun Cemiyeti", "Ağrı isyanını organize eden Kürt milliyetçi örgütü"),
    ("İhsan Nuri Paşa", "Hoybun cemiyeti adına askeri liderlik yapan subay"),
    ("Leyla Qasim", "Irak rejimi tarafından idam edilen Kürt kadın aktivist"),
    ("Barzani Hareketi", "Güney Kürdistan'da uzun yıllar süren ulusal hareket"),
    ("Mustafa Barzani", "Kürt hareketinin efsanevi askeri ve siyasi lideri"),
    ("Şengal", "Êzidî Kürtlerin tarihsel yerleşim bölgesi ve kalesi"),
    ("Cizre", "Botan emirliğinin ve tarihsel kültürün beşiği olan şehir"),
    ("Hasankeyf", "Dicle nehri üzerinde yer alan binlerce yıllık tarihi kent"),
    ("Amida", "Diyarbakır'ın antik çağdaki tarihi ismi ve kalesi"),
    ("Kürdistan Eyaleti", "Osmanlı'da 1847'de kurulan kısa süreli idari eyalet")
]

geography_seed = [
    ("çiya", "dağ"), ("deşt", "ova"), ("av", "su"), ("çem", "akarsu"), ("gol", "göl"),
    ("daristan", "orman"), ("newal", "vadi"), ("hewa", "hava"), ("erd", "yer/toprak"), ("sînor", "sınır"),
    ("Fırat nehri", "Mezopotamya'ya hayat veren büyük nehir"),
    ("Dicle nehri", "Diyarbakır surlarının altından geçen nehir"),
    ("Cudi dağı", "Nuh'un gemisinin indiğine inanılan tarihi dağ"),
    ("Ağrı dağı", "Kürdistan coğrafyasının en yüksek zirvesi"),
    ("Süphan dağı", "Van gölü kuzeyinde yer alan sönmüş volkanik dağ"),
    ("Van gölü", "dünyanın en büyük sodalı gölü olan havza"),
    ("Urmiye gölü", "Doğu Kürdistan'da yer alan tuzlu göl havzası"),
    ("Munzur dağları", "Dersim coğrafyasının en engebeli sıradağları"),
    ("Yukarı Fırat bölümü", "Kürdistan coğrafyasının kuzeybatı yüksek kesimi"),
    ("Botan çayı", "Siirt yöresinden geçip Dicle'ye dökülen nehir"),
    ("Zap suyu", "Hakkari dağlarını yararak akan hırçın akarsu"),
    ("Hazar gölü", "Elazığ sınırlarında yer alan tektonik göl"),
    ("Şengal dağı", "Musul ovasının ortasında yükselen stratejik dağ"),
    ("Hewler ovası", "Güney Kürdistan'ın en verimli tarım ovası"),
    ("Zagros sıradağları", "Kürdistan coğrafyasını baştan başa bölen dağlar"),
    ("Kürdistan iklimi", "karasal ve dağlık alanlarda soğuk kışlar"),
    ("akdeniz iklimi", "Akdeniz'e yakın Kürt bölgelerinde görülen iklim"),
    ("meşe ormanları", "Kürdistan dağlarının tipik bitki örtüsü ve ağacı"),
    ("Zap vadisi", "dik kayalıklar arasından Zap suyunun aktığı derin vadi"),
    ("Yüksekova", "Hakkari'de yer alan yüksek rakımlı tektonik ova"),
    ("Muş ovası", "Fırat'ın kollarının suladığı büyük tarım ovası"),
    ("Bingöl dağları", "birçok nehrin kaynağını aldığı yüksek yaylaklar"),
    ("Halgurd dağı", "Irak Kürdistanı sınırlarında yer alan en yüksek zirve"),
    ("Dokan gölü", "Süleymaniye yakınlarında yer alan yapay baraj gölü"),
    ("Derbendihan gölü", "Diyala nehri üzerinde kurulmuş baraj gölü"),
    ("Dicle bölümü", "Diyarbakır ve Şırnak'ı kapsayan nehir havzası"),
    ("Aras nehri", "Kars ve Iğdır sınırlarından geçip Hazar'a dökülen su"),
    ("Tendürek dağı", "krater gölüne sahip aktif volkanik dağ"),
    ("Nemrut krateri", "dünyanın en büyük ikinci krater gölüne sahip dağ"),
    ("Habur çayı", "Türkiye ve Irak sınırını çizen Dicle kolu"),
    ("Karacadağ", "Diyarbakır ovasında yer alan yayvan bazaltik volkan"),
    ("Botan vadisi", "Botan çayının oluşturduğu derin kanyon vadi"),
    ("Siverek ovası", "Karacadağ lavlarının oluşturduğu taşlık plato"),
    ("Şehrizor ovası", "Süleymaniye güneyindeki tarihi verimli düzlük"),
    ("Kandil dağları", "Garzan çayı yakınlarındaki dağlık kütle"),
    ("Munzur vadisi", "Tunceli'de yer alan milli park statüsündeki vadi"),
    ("Dicle ovası", "Cizre ve Silopi düzlüklerini kapsayan verimli ova"),
    ("Serhat bölgesi", "Kars, Ardahan, Ağrı ve Iğdır'ı kapsayan yüksek bölge"),
    ("Behdînan bölgesi", "Zaho ve Duhok civarındaki dağlık coğrafi alan"),
    ("Garzan çayı", "Batman'dan geçip Dicle'ye dökülen önemli akarsu")
]

literature_seed = [
    ("çîrok", "hikaye"), ("helbest", "şiir"), ("roman", "uzun anlatı"), ("destan", "kahramanlık anlatısı"),
    ("karakter", "anlatı kişisi"), ("tema", "ana düşünce"), ("mecaz", "dolaylı/anlam aktarımlı anlatım"),
    ("kafiye", "ses uyumu"), ("anlatıcı", "hikayeyi aktaran ses"), ("diyalog", "karşılıklı konuşma"),
    ("Ehmedê Xanî", "Mem û Zîn eserinin ünlü yazarı ve düşünür"),
    ("Melayê Cizîrî", "Kürt tasavvuf şiirinin klasik divan şairi"),
    ("Feqiyê Teyran", "kuşların diliyle yazan meşhur Kürt şair"),
    ("Cegerxwîn", "modern Kürt şiirinin öncü toplumcu şairi"),
    ("Mem û Zîn", "Kürt klasik edebiyatının en büyük aşk destanı"),
    ("Nûbihara Biçukan", "Ehmedê Xanî tarafından yazılan ilk Kürtçe sözlük"),
    ("Melayê Bateyî", "Mevlid-i Şerif'i Kürtçe yazan klasik şair"),
    ("Masture Erdelan", "tarihte divan yazmış ilk Kürt kadın tarihçi ve şair"),
    ("Celadet Bedirxan", "Hawar dergisini çıkaran edebi ekolün kurucusu"),
    ("Mehmed Uzun", "modern Kürt romanının kurucusu ve öncü romancı"),
    ("Şêrko Bêkes", "Kürt şiirine serbest tarzı getiren büyük şair"),
    ("Abdulla Goran", "Sorani Kürtçe şiirinde modernleşmenin öncüsü"),
    ("Nalî", "Soranice klasik şiir okulunun en büyük divan şairi"),
    ("Hêmin Mukriyanî", "Doğu Kürdistan'ın meşhur modern şair ve yazarı"),
    ("Qanadê Kurdo", "Kürt dili ve edebiyatı üzerine çalışan akademisyen"),
    ("Arabê Şamo", "Şivanê Kurd adlı ilk Kürtçe romanın yazarı"),
    ("Şivanê Kurd", "1935 yılında basılan ilk modern Kürtçe roman"),
    ("Ronahî dergisi", "Şam'da Latin alfabesiyle çıkarılan edebi dergi"),
    ("Xanî Mektebi", "Ehmedê Xanî'nin başlattığı edebi ve düşünsel ekol"),
    ("Kamuran Bedirxan", "Kürtçe gramer kitapları yazan dilbilimci ve yazar"),
    ("Riya Taza gazetesi", "Erivan'da uzun yıllar basılan Kürtçe gazete"),
    ("Evdirehîm Rehmî Hekarî", "Kürt tiyatrosunun kurucu oyun yazarlarından"),
    ("Memê Alan destanı", "Ehmedê Xanî'nin Mem û Zîn'e ilham aldığı halk destanı"),
    ("Dewrêşê Evdî destanı", "Kürt sözlü edebiyatının en hüzünlü destanlarından biri"),
    ("Baba Tahirê Hemedanî", "Kürt edebiyatının en eski klasik rubai şairi"),
    ("Mestûre Kurdistanî", "Erdelan beyliğinde yaşamış ünlü kadın şair"),
    ("Ehmedê Xasî", "Zazaca ilk mevlidi yazan şair ve din alimi"),
    ("Osman Sabri", "modern Kürt hikayeciliğinin kurucu isimlerinden"),
    ("Hejar Mukriyanî", "Şerefname ve Mem û Zîn'i Soraniceye çeviren yazar"),
    ("Ferhad û Şîrîn", "Kürt sözlü geleneğinde de anlatılan klasik aşk hikayesi"),
    ("Xana Qubadî", "klasik Kürt edebiyatında önemli yeri olan şair"),
    ("Pertew Begê Hkarî", "Hakkari emirliğinde yetişmiş klasik divan şairi"),
    ("Haris Bitlisî", "klasik dönemde Kürtçe eserler yazmış şair"),
    ("Qedrîcan", "modern Kürt şiirinde ve nesrinde iz bırakmış yazar"),
    ("Hawar Ekolü", "Kürt aydınlanmasını ve Latin alfabesini yayan edebi akım"),
    ("Jîna Nû dergisi", "erken dönem Kürtçe edebi ve siyasi yayınlardan biri"),
    ("Elî Herîrî", "Kürt edebiyatının bilinen en eski klasik şairlerinden"),
    ("Dîwana Melayê Cizîrî", "mistik aşk ve felsefe içeren meşhur şiir divanı"),
    ("Yaşar Kemal", "Kürt kökenli, dünya çapında tanınan usta romancı")
]

music_seed = [
    ("dengbêj", "ezgili sözlü anlatım yapan sanatçı"),
    ("ritim", "müziğin temelini oluşturan düzenli vuruşlar"),
    ("melodî", "seslerin ardışık dizilmesiyle oluşan ezgi"),
    ("stran", "Kürtçe şarkı veya melodi"),
    ("def", "Kürt tasavvuf ve halk müziğinde kullanılan vurmalı çalgı"),
    ("erbane", "halk müziğinde yaygın olarak çalınan zilli tef"),
    ("tembûr", "Kürt halk müziğinde en kutsal sayılan telli saz"),
    ("nota", "müziği kağıda dökmek için kullanılan evrensel işaretler"),
    ("koro", "topluluk halinde şarkı söyleme biçimi"),
    ("solo", "tek bir sanatçının şarkı söylemesi veya çalması"),
    ("Şivan Perwer", "Kürt müziğini dünyaya tanıtan en meşhur ses sanatçısı"),
    ("Mihemed Arif Cizrawî", "klasik Bahdinan müziğinin efsanevi sesi"),
    ("Hasan Cizrawî", "erken dönem Kürt müziği kayıtlarını yapan dengbêj"),
    ("Meryem Xan", "Kürt müziğinde plak dolduran ilk Kürt kadın sanatçı"),
    ("Karapetê Xaço", "Kürt sözlü müziğini derleyen Ermeni asıllı dengbêj"),
    ("Şakiro", "Kürtlerin 'şahê dengbêjan' dediği güçlü ses"),
    ("Ciwan Haco", "Kürt müziğine rock ve caz esintileri getiren sanatçı"),
    ("Aynur Doğan", "modern dönemde Kürt halk müziğini icra eden sanatçı"),
    ("Kardeş Türküler", "Kürt müziğini çok kültürlü ortamda icra eden grup"),
    ("Aram Tigran", "Kürtçe şarkılarıyla tanınan Ermeni asıllı usta müzisyen"),
    ("Koma Amed", "90'larda Kürt müziğinde devrim yapan alternatif müzik grubu"),
    ("kaval", "çobanların da çaldığı üflemeli geleneksel enstrüman"),
    ("zurna", "yüksek sesli, açık havada çalınan nefesli çalgı"),
    ("dahol", "zurna ile birlikte çalınan ritim sazı"),
    ("kemençe", "Kürt coğrafyasında da çalınan yaylı çalgı"),
    ("şevbêrk müziği", "kış gecesi sohbetlerinde icra edilen sözlü müzik"),
    ("kilam", "dengbêjlerin söylediği destansı veya aşk temalı şarkı"),
    ("lawik", "daha çok aşk ve yiğitlik üzerine söylenen müzik türü"),
    ("heyran", "Serhat bölgesinde yaygın olan bir Kürt halk ezgisi türü"),
    ("govend müziği", "halaylarda çalınan hareketli ve ritmik halk şarkıları"),
    ("makam", "Türk ve Kürt müziğinde ezgisel yapıyı belirleyen sistem"),
    ("şabaş geleneği", "müzisyenlere para atarak taltif etme adeti"),
    ("hîran", "Kürt halk müziğinde bir başka ezgi tarzı"),
    ("zembîlfiroş stranı", "efsaneyi anlatan meşhur geleneksel kilam"),
    ("Eyşeqan", "Kürt kadın dengbêj geleneğinin en bilinen temsilcilerinden"),
    ("Mihemed Şêxo", "Kürt halkının ulusal duygularını seslendiren ozan"),
    ("Erdewan Zaxoyî", "Bahdinan bölgesinin sevilen devrimci müzisyeni"),
    ("Koma Wetan", "tarihteki ilk Kürtçe rock grubunun adı"),
    ("çeng", "antik Mezopotamya ve Kürt müziğinde kullanılan arp benzeri çalgı"),
    ("defbaz", "erbane veya defi ustalıkla çalan ritim sanatçısı"),
    ("stranbêj", "genel olarak şarkı okuyan, seslendiren kişi"),
    ("dengbêj evi", "Van ve Diyarbakır'da dengbêjlerin dinlendiği kültürel mekan"),
    ("dengbêjlik okulu", "usta-çırak ilişkisiyle yürüyen müzikal aktarım"),
    ("serhad ezgileri", "Kars, Ağrı ve Van yöresine özgü lirik müzik tarzı"),
    ("botan ezgileri", "Şırnak ve Cizre yöresinin ritmik ve makamsal müziği"),
    ("behedînî ezgileri", "Duhok ve Zaho yöresine has müzikal tarz"),
    ("zaza müziği", "Dersim ve Bingöl yöresinde icra edilen Kürtçe müzik"),
    ("dengbêj makamı", "kilamların okunduğu serbest ritimli vokal tarzı"),
    ("şakiro stranları", "Şakiro'nun seslendirdiği uzun soluklu destansı kilamlar"),
    ("Mihemed Taha Akreyî", "Bahdinan bölgesinin popüler klasik halk sanatçısı")
]

paradigma_seed = [
    ("demokratik konfederalizm", "devlet dışı toplumsal yönetim modeli"),
    ("demokratik modernite", "kapitalist moderniteye alternatif yaşam sistemi"),
    ("jineolojî", "kadın eksenli toplum ve yaşam bilimi"),
    ("ekolojik toplum", "doğayı sömürmeyen, onunla uyumlu yaşayan toplum"),
    ("kadın özgürlüğü", "toplumsal özgürleşmenin en temel kriteri"),
    ("komün", "toplumun en küçük ve doğrudan katılımcı yönetim birimi"),
    ("meclis", "komünlerin üstünde yer alan koordinasyon ve karar organı"),
    ("demokratik ulus", "ortak vatanda çok kültürlü ve eşitlikçi birliktelik"),
    ("demokratik özerklik", "halkın kendi kendini yönetme ve örgütleme biçimi"),
    ("toplumsal sözleşme", "toplumun bir arada yaşama ilkelerini belirleyen belge"),
    ("kapitalist modernite", "endüstriyalizm, ulus-devlet ve kapitalizm üçlüsü"),
    ("endüstriyalizm", "kâr amaçlı doğayı tahrip eden sanayileşme modeli"),
    ("ulus devlet", "tek tipleştirici, sınırları kutsallaştıran devlet yapısı"),
    ("toplumsal ekoloji", "doğa tahribatının hiyerarşiyle ilişkisini kuran bilim"),
    ("eş başkanlık", "yönetim organlarında kadın-erkek eşit temsil sistemi"),
    ("öz savunma", "toplumun kendini koruma ve örgütleme hakkı"),
    ("ahlaki-politik toplum", "kendi kararlarını alan, etik değerlere sahip toplum"),
    ("tekelcilik", "economic and political centralization crisis"),
    ("hiyerarşi", "toplumda alt-üst ilişkisi kuran baskıcı örgütlenme"),
    ("ataerkillik", "erkeği egemen kılan, kadını ezen toplumsal yapı"),
    ("demokratik konfederal", "devletçi olmayan, tabana dayalı federasyon"),
    ("komünal ekonomi", "kâr yerine ihtiyacı ve paylaşımı esas alan ekonomi"),
    ("demokratik siyaset", "halkın doğrudan yönetime ve karar süreçlerine katılımı"),
    ("toplumsal cinsiyet", "toplumun kadın ve erkeğe biçtiği yapay roller"),
    ("pozitivizm", "sadece maddi olguları kabul eden, dogmatik bilim anlayışı"),
    ("demokratik modernite akademisi", "alternatif bilim ve yaşam arayışının okulu"),
    ("ahlakilik", "toplumun kendi kendini koruma ve yürütme refleksidir"),
    ("politikleşme", "toplumun kendi kaderi hakkında söz ve karar sahibi olması"),
    ("özgür eş yaşam", "baskı ve sahiplenmeye dayanmayan eşit ortak yaşam"),
    ("kadın akademileri", "kadın bilincini ve jineolojiyi geliştiren okullar"),
    ("kooperatifçilik", "komünal ekonominin temel dayanışma birimi"),
    ("ekolojik endüstri", "doğayla uyumlu, geri dönüşümlü üretim tarzı"),
    ("hiyerarşisiz toplum", "tahakküm ve sömürünün olmadığı eşitlikçi düzen"),
    ("sivil toplum", "devlet dışı, toplumsal örgütlenme alanları"),
    ("özgürlük ölçütü", "toplumun genel özgürlüğünün kadının özgürlüğüyle ölçülmesi"),
    ("doğrudan demokrasi", "halkın temsilciler olmadan doğrudan karar alması"),
    ("demokratik kanton", "yerel özerkliğe sahip idari ve toplumsal birim"),
    ("sosyal sözleşme", "kantonların ve komünlerin ortak kurucu metni"),
    ("demokratik komünalizm", "komün yaşamına ve dayanışmaya dayalı sistem"),
    ("antikapitalizm", "kapitalizmin kâr ve sömürü mantığına karşı duruş"),
    ("ekolojik bilinç", "insanın doğanın bir parçası olduğunu anlama durumu"),
    ("patriyarka eleştirisi", "erkek egemen sistemin yapısını deşifre etme"),
    ("demokratik uygarlık", "devletçi olmayan, halkların komünal gelişim çizgisi"),
    ("devletçi uygarlık", "sınıflı, hiyerarşik ve devlet odaklı tarih çizgisi"),
    ("ahlaki güç", "yasalara gerek kalmadan toplumun kendini yönetebilmesi"),
    ("yerel meclis", "mahalle ve köylerde halkın kararlar aldığı kurul"),
    ("demokratik ittifak", "farklı ezilen kesimlerin eşitlikçi birlikteliği"),
    ("komünal mülkiyet", "toprağın ve araçların topluma ait olması"),
    ("demokratik bilim", "tekelci olmayan, topluma hizmet eden bilim anlayışı"),
    ("cinsiyet özgürlükçü", "cinsel baskı ve ayrımcılığa karşı eşitlikçi ilke")
]

politics_seed = [
    ("radikal demokrasi", "tabandan doğrudan katılımı öncelikli kılan demokrasi"),
    ("eş başkanlık", "yönetimde eşit temsil sistemidir"),
    ("yerel meclisler", "yerel kararların alındığı halk meclisleri"),
    ("demokratik özerklik", "yerelde kendi kendini yönetme ve karar alma statüsü"),
    ("çoğulculuk", "farklı kimliklerin ve inançların eşit kabul edilmesi"),
    ("toplumsal uzlaşı", "barışçıl çözüm için toplumun ortak karara varması"),
    ("müzakere", "sorunları diyalog yoluyla çözme yöntemi"),
    ("demokratik anayasa", "tüm farklı kesimleri kapsayan özgürlükçü anayasa"),
    ("temsili demokrasi", "halkın sadece seçimlerle yönetime katıldığı sistem"),
    ("doğrudan katılım", "halkın siyasi kararlara bizzat dahil olması"),
    ("yerel yönetim", "belediyeler ve yerel kurulların oluşturduğu yönetim"),
    ("statü hakkı", "halkların kendi kimliğiyle tanınma ve yönetilme hakkı"),
    ("barış süreci", "çatışmalı ortamı diyalogla sonlandırma aşaması"),
    ("siyasi katılım", "vatandaşların karar alma süreçlerine müdahil olması"),
    ("azınlık hakları", "çoğunluğa karşı farklı olan grupların korunması"),
    ("anadilinde eğitim", "halkların kendi diliyle eğitim alma hakkı"),
    ("insan hakları", "her bireyin doğuştan sahip olduğu evrensel haklar"),
    ("kuvvetler ayrılığı", "yasama, yürütme ve yargının bağımsız olması"),
    ("sivil itaatsizlik", "adaletsiz yasalara karşı barışçıl protesto biçimi"),
    ("yerel özerklik şartı", "yerel yönetimlerin gücünü artıran uluslararası belge"),
    ("demokratik siyaset", "baskı ve tasfiye yerine diyalogu seçen siyaset tarzı"),
    ("cinsiyet kotası", "siyasette kadın katılımını güvenceye alan yasal oran"),
    ("parti eş başkanlığı", "partilerde kadının eşit söz sahibi olma sistemi"),
    ("yerel demokrasi", "kararların halka en yakın birimlerde alınması"),
    ("meşruiyet", "yönetimin halkın rızasına ve hukuka uygun olması"),
    ("toplumsal muhalefet", "resmi yönetime karşı halkın barışçıl tepki örgütlenmesi"),
    ("ademi merkeziyetçilik", "gücün tek merkezden yerel birimlere dağıtılması"),
    ("barışçıl çözüm", "çatışmaları silah yerine diyalogla çözme iradesi"),
    ("hakikat komisyonu", "geçmişteki acıları araştırıp toplumsal barışı kuran kurul"),
    ("demokratik ittifaklar", "farklı muhalif grupların ortak barış platformu"),
    ("meclis sistemi", "kararların tek lider yerine kurullarla alınması"),
    ("toplumsal adalet", "kaynakların ve hakların eşit paylaşılması ilkesi"),
    ("özyönetim hakkı", "toplumun dışarıdan baskı olmadan kendini yönetmesi"),
    ("statü talebi", "anayasal güvence ve kültürel hakların tanınması"),
    ("siyasi özerklik", "kendi yasalarını yapabilen yerel parlamento yetkisi"),
    ("idari özerklik", "yerel bütçe ve hizmetleri kendi yönetme hakkı"),
    ("anadili hakkı", "resmi ve kamusal alanlarda anadilinin kullanılması"),
    ("çoğulcu demokrasi", "sadece çoğunluğun değil azınlığın da dinlendiği yapı"),
    ("katılımcı bütçe", "bütçe harcamalarını halkın meclislerle belirlemesi"),
    ("siyasi ahlak", "siyasette dürüstlük ve toplumsal yararı önceleme ilkeleri"),
    ("demokratik haklar", "protesto, örgütlenme ve ifade özgürlüğü hakları"),
    ("barış hakkı", "toplumun savaşsız bir ortamda yaşama evrensel hakkı"),
    ("sivil katılım", "dernekler ve inisiyatiflerle yönetime müdahil olma"),
    ("yerel irade", "merkezden atanan kayyum yerine seçilmiş yerel yönetici gücü"),
    ("demokratik muhalefet", "mecliste ve sokakta hak arama kanalları"),
    ("anayasal güvence", "hakların kanunla koruma altına alınması"),
    ("demokratik uzlaşı", "ortak yararda partilerin bir araya gelmesi"),
    ("toplumsal barış", "farklı etnik ve inanç gruplarının huzurlu birlikteliği"),
    ("demokratik haklar beyannamesi", "temel hakları listeleyen kurucu belge"),
    ("adil yargılanma", "bağımsız ve tarafsız mahkemelerde savunma hakkı")
]

# 4. Group existing questions by category
questions_by_cat = defaultdict(list)
existing_prompts = set()
for q in existing_questions:
    questions_by_cat[q["category"]].append(q)
    existing_prompts.add(q["prompt"].strip().lower())

# Compile pools of all correct answers per category (including seeds)
category_pools = defaultdict(list)
for q in existing_questions:
    category_pools[q["category"]].append(q["correctAnswer"])

for w, tr in vocab_seed:
    category_pools["Ziman"].extend([w, tr])
for topic, meaning, context in culture_seed:
    category_pools["Çand"].extend([meaning, context])
for topic, desc in history_seed:
    category_pools["Dîrok"].append(desc)
for topic, desc in geography_seed:
    category_pools["Cografya"].append(desc)
for topic, desc in literature_seed:
    category_pools["Edebiyat"].append(desc)
for topic, desc in music_seed:
    category_pools["Muzîk"].append(desc)
for topic, desc in paradigma_seed:
    category_pools["Paradigma"].append(desc)
for topic, desc in politics_seed:
    category_pools["Siyaset"].append(desc)

for cat in category_pools:
    category_pools[cat] = list(set(category_pools[cat]))

# 5. Generic templates generator helper (Expanded to 35 templates!)
def generate_question_from_template(cat, seed, template_idx):
    topic = seed[0]
    desc = seed[1]
    context = seed[2] if len(seed) > 2 else cat
    
    # 35 templates defined (No visual templates!)
    templates = [
        # Multiple Choice (22 templates)
        (f"{cat} bağlamında '{topic}' en çok hangi alanla veya tanımla ilişkilidir?", desc, "multipleChoice"),
        (f"Aşağıdakilerden hangisi '{topic}' kavramının en uygun açıklamasıdır?", desc, "multipleChoice"),
        (f"'{topic}' kavramı {cat.lower()} açısından neyi ifade eder?", desc, "multipleChoice"),
        (f"'{topic}' hakkında verilen bilgilerden hangisi en doğrudur?", f"'{desc}' ile doğrudan ilişkilidir.", "multipleChoice"),
        (f"Aşağıdakilerden hangisi '{topic}' kavramının temel niteliğidir?", desc, "multipleChoice"),
        (f"'{cat}' araştırmalarında '{topic}' neyi açıklar?", desc, "multipleChoice"),
        (f"Aşağıdaki seçeneklerden hangisi '{topic}' kavramını tanımlar?", desc, "multipleChoice"),
        (f"'{topic}' teriminin {cat.lower()} bağlamındaki karşılığı nedir?", desc, "multipleChoice"),
        (f"'{cat}' çerçevesinde '{topic}' ne amaçla ele alınır?", desc, "multipleChoice"),
        (f"Aşağıdakilerden hangisi '{topic}' ile doğrudan bağlantılıdır?", desc, "multipleChoice"),
        (f"'{cat}' alanında '{topic}' konusunun yeri nedir?", desc, "multipleChoice"),
        (f"Aşağıdakilerden hangisi '{topic}' teriminin doğru tanımıdır?", desc, "multipleChoice"),
        (f"'{cat}' çalışmalarında '{topic}' kavramı hangi konuyu aydınlatır?", desc, "multipleChoice"),
        (f"Aşağıdakilerden hangisi '{topic}' ile ilgili temel kavramlardan biridir?", desc, "multipleChoice"),
        (f"'{topic}' denildiğinde {cat.lower()} açısından ne anlaşılmalıdır?", desc, "multipleChoice"),
        (f"Kürdistan/Kürt çalışmaları çerçevesinde '{topic}' ne şekilde yorumlanır?", desc, "multipleChoice"),
        (f"Aşağıdakilerden hangisi '{topic}' kavramının taşıdığı temel anlamlardan biridir?", desc, "multipleChoice"),
        (f"'{topic}' kavramı, toplumsal bilinç ve {cat.lower()} açısından neyi ifade eder?", desc, "multipleChoice"),
        (f"Aşağıdaki terimlerden hangisi '{topic}' ile yakın bir anlama sahiptir?", desc, "multipleChoice"),
        (f"'{topic}' kavramı hakkında yapılan araştırmalarda hangisi vurgulanır?", desc, "multipleChoice"),
        (f"Toplumsal yapı içinde '{topic}' kavramının önemi nedir?", desc, "multipleChoice"),
        (f"Aşağıdakilerden hangisi '{topic}' kavramının modern bağlamda kullanımıdır?", desc, "multipleChoice"),
        
        # True/False (13 templates)
        (f"'{topic.capitalize()}' kavramı {cat} alanıyla doğrudan ilişkilidir.", "Rast", "trueFalse"),
        (f"{cat} bağlamında '{topic}' sadece teknik veya önemsiz bir detaydır.", "Şaş", "trueFalse"),
        (f"'{topic.capitalize()}' kavramı {cat} çalışmalarında önemli bir başlık olarak kabul edilir.", "Rast", "trueFalse"),
        (f"'{cat}' alanı yalnızca '{topic}' dışındaki konuları inceler.", "Şaş", "trueFalse"),
        (f"'{topic.capitalize()}', {cat.lower()} araştırmalarında geçerli bir kavramdır.", "Rast", "trueFalse"),
        (f"'{topic.capitalize()}' kavramının {cat.lower()} ile hiçbir bağı bulunmamaktadır.", "Şaş", "trueFalse"),
        (f"'{topic.capitalize()}' terimi {cat.lower()} kavramsal çerçevesinde yer alır.", "Rast", "trueFalse"),
        (f"'{cat}' bağlamında '{topic}' tamamen uydurma bir terimdir.", "Şaş", "trueFalse"),
        (f"'{topic.capitalize()}' terimi modern {cat.lower()} literatüründe kullanılmaz.", "Şaş", "trueFalse"),
        (f"Gelişmiş {cat.lower()} teorilerinde '{topic}' kavramına sıkça başvurulur.", "Rast", "trueFalse"),
        (f"'{topic.capitalize()}' kavramı tarihsel süreçte {cat.lower()} gelişimine katkı sağlamıştır.", "Rast", "trueFalse"),
        (f"'{topic.capitalize()}' teriminin {cat.lower()} alanı dışındaki bilimlerde kullanımı çok daha yaygındır.", "Şaş", "trueFalse"),
        (f"Geleneksel {cat.lower()} birikiminde '{topic}' kavramının izlerine rastlanır.", "Rast", "trueFalse")
    ]
    
    prompt, correct, qtype = templates[template_idx % len(templates)]
    difficulty = 1 + (template_idx % 5)
    
    return {
        "prompt": prompt,
        "correctAnswer": correct,
        "type": qtype,
        "difficulty": difficulty,
        "imageUrl": None,
        "explanation": f"'{topic}' kavramı hakkında {cat.lower()} bağlamında bilgi edindirme amaçlanmıştır."
    }

# Question Generator Engine
new_id_counter = 5000  
final_questions = []

def generate_distractors(correct, pool, count=3):
    candidates = [c for c in pool if c != correct and len(c.strip()) > 0]
    candidates.sort(key=lambda c: abs(len(c) - len(correct)))
    top_candidates = candidates[:15]
    if len(top_candidates) < count:
        top_candidates = candidates
    if len(top_candidates) < count:
        return ["ziman", "çand", "dîrok", "huner"][:count]
    return random.sample(top_candidates, count)

categories = ["Ziman", "Çand", "Dîrok", "Cografya", "Edebiyat", "Muzîk", "Paradigma", "Siyaset"]
target_count = 1250

for cat in categories:
    cat_existing = questions_by_cat[cat]
    final_questions.extend(cat_existing)
    
    needed = target_count - len(cat_existing)
    print(f"Category {cat}: present={len(cat_existing)}, needed={needed}")
    
    # Get seeds for this category
    if cat == "Ziman":
        seeds = vocab_seed
    elif cat == "Çand":
        seeds = culture_seed
    elif cat == "Dîrok":
        seeds = history_seed
    elif cat == "Cografya":
        seeds = geography_seed
    elif cat == "Edebiyat":
        seeds = literature_seed
    elif cat == "Muzîk":
        seeds = music_seed
    elif cat == "Paradigma":
        seeds = paradigma_seed
    else:  # Siyaset
        seeds = politics_seed
        
    candidate_questions = []
    
    if cat == "Ziman":
        for s_idx, (term, meaning) in enumerate(seeds):
            for t_idx in range(25): # 25 templates
                difficulty = 1 + (t_idx % 5)
                
                if t_idx % 2 == 0:
                    qtype = "multipleChoice"
                    if t_idx % 4 == 0:
                        prompt = f'Di Kurmancî de peyva "{term}" bi Tirkî çi ye?'
                        correct = meaning
                        explanation = f'"{term}" kelimesi "{meaning}" anlamına gelir.'
                    else:
                        prompt = f'"{meaning}" anlamına gelen Kurmancî kelime hangisidir?'
                        correct = term
                        explanation = f'"{meaning}" için doğru karşılık "{term}"tir.'
                else:
                    qtype = "trueFalse"
                    is_correct = (t_idx % 4 == 1)
                    if is_correct:
                        prompt = f'Peyva "{term}" "{meaning}" anlamına gelir.'
                        correct = "Rast"
                        explanation = f'"{term}" için doğru karşılık "{meaning}"tir.'
                    else:
                        other_meaning = seeds[(s_idx + 1) % len(seeds)][1]
                        prompt = f'Peyva "{term}" "{other_meaning}" anlamına gelir.'
                        correct = "Şaş"
                        explanation = f'"{term}" kelimesi "{meaning}" demektir.'
                    
                candidate_questions.append({
                    "prompt": prompt,
                    "correctAnswer": correct,
                    "type": qtype,
                    "difficulty": difficulty,
                    "imageUrl": None,
                    "explanation": explanation
                })
    else:
        # Other categories use generic templates (up to 40 variations now!)
        for s_idx, seed in enumerate(seeds):
            for t_idx in range(40): 
                candidate_questions.append(generate_question_from_template(cat, seed, t_idx))
                
    random.shuffle(candidate_questions)
    
    generated_in_cat = 0
    for cand in candidate_questions:
        if generated_in_cat >= needed:
            break
            
        norm_prompt = cand["prompt"].strip().lower()
        if norm_prompt in existing_prompts:
            continue
            
        # Build answers
        answers = []
        if cand["type"] == "trueFalse":
            answers = ["Rast", "Şaş"]
        else:
            distractors = generate_distractors(cand["correctAnswer"], category_pools[cat], count=3)
            answers = [cand["correctAnswer"]] + distractors
            random.shuffle(answers)
            
        new_q = {
            "id": f"offline_{new_id_counter}",
            "category": cat,
            "prompt": cand["prompt"],
            "answers": answers,
            "correctAnswer": cand["correctAnswer"],
            "explanation": cand["explanation"],
            "difficulty": cand["difficulty"],
            "type": cand["type"],
            "imageUrl": None
        }
        
        final_questions.append(new_q)
        existing_prompts.add(norm_prompt)
        new_id_counter += 1
        generated_in_cat += 1
        
    print(f"Generated {generated_in_cat} new questions in {cat}.")

print(f"Total merged questions: {len(final_questions)}")

# Check category counts
final_category_counts = Counter(q["category"] for q in final_questions)
print("\nFinal Category distribution:")
for cat, count in final_category_counts.items():
    print(f"  {cat}: {count}")

# 6. Generate the new lib/src/data/offline_question_bank.dart
offline_content = """import '../models/quiz_question.dart';

const offlineQuestionBank = <QuizQuestion>[
"""

for q in final_questions:
    img_str = f",\n    imageUrl: '{q['imageUrl']}'" if q["imageUrl"] else ""
    ans_str = ", ".join(to_dart_string(a) for a in q["answers"])
    prompt_str = to_dart_string(q["prompt"])
    correct_str = to_dart_string(q["correctAnswer"])
    explanation_str = to_dart_string(q["explanation"])
    
    offline_content += f"""  QuizQuestion(
    id: '{q['id']}',
    category: '{q['category']}',
    prompt: {prompt_str},
    answers: [{ans_str}],
    correctAnswer: {correct_str},
    explanation: {explanation_str},
    difficulty: {q['difficulty']},
    type: QuestionType.{q['type']}{img_str}
  ),
"""

offline_content += "];\n"
OFFLINE_FILE.write_text(offline_content, encoding="utf-8")
print("offline_question_bank.dart updated.")

# 7. Generate supabase/rich_question_bank_v2.sql
sql_content = """alter table public.questions
  add column if not exists question_type text not null default 'multiple_choice';

alter table public.questions
  add column if not exists image_url text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'questions_question_type_check'
  ) then
    alter table public.questions
      add constraint questions_question_type_check
      check (question_type in ('multiple_choice', 'true_false', 'visual'));
  end if;
end;
$$;

insert into public.categories (name, slug, is_active)
values
  ('Ziman', 'ziman', true),
  ('Çand', 'cand', true),
  ('Dîrok', 'dirok', true),
  ('Edebiyat', 'edebiyat', true),
  ('Cografya', 'cografya', true),
  ('Muzîk', 'muzik', true),
  ('Siyaset', 'siyaset', true),
  ('Paradigma', 'paradigma', true)
on conflict (name) do update set is_active = excluded.is_active;

delete from public.questions
where source_url = 'zankurd_seed_rich_v2';

insert into public.questions (
  category_id,
  language_code,
  prompt,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option,
  explanation,
  difficulty,
  is_approved,
  question_type,
  image_url,
  source_url
)
values
"""

type_map = {
    "multipleChoice": "multiple_choice",
    "trueFalse": "true_false",
    "visual": "visual"
}

sql_values = []
for q in final_questions:
    cat_escaped = q["category"].replace("'", "''")
    prompt_escaped = q["prompt"].replace("'", "''")
    
    options = ["-"] * 4
    for idx, ans in enumerate(q["answers"]):
        if idx < 4:
            options[idx] = ans
            
    correct_idx = q["answers"].index(q["correctAnswer"]) if q["correctAnswer"] in q["answers"] else 0
    correct_letter = chr(65 + correct_idx)
    
    option_a = options[0].replace("'", "''")
    option_b = options[1].replace("'", "''")
    option_c = options[2].replace("'", "''")
    option_d = options[3].replace("'", "''")
    
    explanation_escaped = q["explanation"].replace("'", "''")
    sql_type = type_map.get(q["type"], "multiple_choice")
    image_url_str = f"'{q['imageUrl']}'" if q["imageUrl"] else "null"
    
    sql_values.append(
        f"((select id from public.categories where name = '{cat_escaped}'), 'ku-kmr', "
        f"'{prompt_escaped}', '{option_a}', '{option_b}', '{option_c}', '{option_d}', "
        f"'{correct_letter}', '{explanation_escaped}', {q['difficulty']}, true, '{sql_type}', "
        f"{image_url_str}, 'zankurd_seed_rich_v2')"
    )

sql_content += ",\n".join(sql_values) + ";\n"
SQL_FILE.write_text(sql_content, encoding="utf-8")
print("rich_question_bank_v2.sql updated.")

# 8. Write CSV files
csv_headers = [
    "id", "category", "language_code", "prompt", "option_a", "option_b", "option_c", "option_d",
    "correct_option", "explanation", "difficulty", "is_approved", "question_type", "image_url", "source_url"
]

with CSV_V2_FILE.open("w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(csv_headers)
    for q in final_questions:
        options = ["-"] * 4
        for idx, ans in enumerate(q["answers"]):
            if idx < 4:
                options[idx] = ans
        correct_idx = q["answers"].index(q["correctAnswer"]) if q["correctAnswer"] in q["answers"] else 0
        correct_letter = chr(65 + correct_idx)
        
        writer.writerow([
            q["id"], q["category"], "ku-kmr", q["prompt"], options[0], options[1], options[2], options[3],
            correct_letter, q["explanation"], q["difficulty"], "true", type_map.get(q["type"], "multiple_choice"),
            q["imageUrl"] or "", "zankurd_seed_rich_v2"
        ])

print("rich_question_bank_v2_questions.csv updated.")

with CSV_READY_FILE.open("w", encoding="utf-8", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(csv_headers)
    for q in final_questions:
        options = ["-"] * 4
        for idx, ans in enumerate(q["answers"]):
            if idx < 4:
                options[idx] = ans
        correct_idx = q["answers"].index(q["correctAnswer"]) if q["correctAnswer"] in q["answers"] else 0
        correct_letter = chr(65 + correct_idx)
        
        writer.writerow([
            q["id"], q["category"], "ku-kmr", q["prompt"], options[0], options[1], options[2], options[3],
            correct_letter, q["explanation"], q["difficulty"], "true", type_map.get(q["type"], "multiple_choice"),
            q["imageUrl"] or "", "zankurd_seed_rich_v2"
        ])

print("questions_import_ready.csv updated.")
