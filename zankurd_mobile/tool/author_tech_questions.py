# -*- coding: utf-8 -*-
"""Teknolojî kategorisini oynanabilir hâle getirir.

Kategori 12 soruda kalmıştı; `categories_tab.dart` 20'nin altındaki
kategorileri "yakında" diye kilitliyor, yani Teknolojî listede görünüyor
ama açılmıyordu — ölü ağırlık. Ürünün amacı yalnız Kürtçe değil, genel
dünya bilgisi de olduğu için kategori kapatılmak yerine dolduruldu.

Sorular iki işi birden yapıyor: teknoloji kavramını öğretiyor ve o kavramın
Kurmancî karşılığını veriyor — uygulamanın öğrenme amacına uygun tek taşla
iki kuş.
"""

import json
import sys

BANK = 'assets/data/offline_questions.json'


def mc(qid, difficulty, prompt, correct, distractors, ku, tr):
    # Doğru cevabın konumu soru numarasına göre döner. Sabit konum
    # (hep A şıkkı) oyuncunun konuyu değil deseni öğrenmesine yol açar;
    # `question_bank_test` bunu banka genelinde denetler.
    #
    # Dikkat: `QuizQuestion.displayAnswers` şıkları id'den türeyen sabit bir
    # kaydırmayla döndürür, yani *depolanan* konum ekranda görünen konum
    # değildir. Bu yüzden ekleme sonrası dağılımı `tool/rebalance_answer_
    # positions.py` düzeltir; buradaki dönüş yalnız ilk yaklaşımdır.
    answers = list(distractors)
    answers.insert(int(qid.split('_')[-1]) % 4, correct)
    return {
        'id': qid,
        'category': 'Teknolojî',
        'prompt': prompt,
        'answers': answers,
        'correctAnswer': correct,
        'explanation': tr,
        'explanationKu': ku,
        'explanationTr': tr,
        'type': 'multipleChoice',
        'difficulty': difficulty,
    }


def tf(qid, difficulty, prompt, correct, ku, tr):
    return {
        'id': qid,
        'category': 'Teknolojî',
        'prompt': prompt,
        'answers': ['Rast', 'Şaş'],
        'correctAnswer': correct,
        'explanation': tr,
        'explanationKu': ku,
        'explanationTr': tr,
        'type': 'trueFalse',
        'difficulty': difficulty,
    }


QUESTIONS = [
    mc('offline_tek_0001', 1,
       'Amûra ku agahiyan li ser kaxizê çap dike bi Kurmancî çi ye?',
       'Çaper', ['Nîşander', 'Bilindgo', 'Kamera'],
       'Çaper agahiyan ji ekranê digihîne kaxizê.',
       'Yazıcı, bilgiyi ekrandan kâğıda aktarır.'),
    mc('offline_tek_0002', 1,
       'Peyva Kurmancî «bîrge» bi Tirkî çi tê gotin?',
       'bellek', ['ekran', 'kablo', 'düğme'],
       'Bîrge dane bi demkî an bi domdarî diparêze.',
       'Bellek, veriyi geçici ya da kalıcı olarak saklar.'),
    mc('offline_tek_0003', 2,
       'Di komputerê de kîjan beş hesaban dike û fermanan bi rê ve dibe?',
       'Pêvajoker', ['Bîrge', 'Ekran', 'Bilindgo'],
       'Pêvajoker mejiyê komputerê ye; ferman li wir tên hesibandin.',
       'İşlemci bilgisayarın beynidir; komutlar orada hesaplanır.'),
    mc('offline_tek_0004', 2,
       'Peyva Kurmancî «tor» di warê komputerê de bi Tirkî çi ye?',
       'ağ', ['dosya', 'klasör', 'pencere'],
       'Tor amûran bi hev ve girê dide û danûstandina daneyan pêk tîne.',
       'Ağ, cihazları birbirine bağlar ve veri alışverişini sağlar.'),
    mc('offline_tek_0005', 3,
       'Kîjan pergal navên malperan vediguherîne navnîşanên hejmarî?',
       'DNS', ['HTML', 'USB', 'PDF'],
       'DNS navê malperê tîne ser navnîşana IP ya server.',
       'DNS, site adını sunucunun IP adresine çevirir.'),
    mc('offline_tek_0006', 3,
       'Girêdana ku danûstandina di navbera geroker û serverê de şîfre dike kîjan e?',
       'HTTPS', ['FTP', 'SMTP', 'IRC'],
       'HTTPS naveroka di rê de diparêze; bêyî wê şîfre eşkere diçin.',
       'HTTPS yoldaki içeriği korur; onsuz parolalar açık gider.'),
    mc('offline_tek_0007', 4,
       'Di bernamesaziyê de «xelek» ji bo çi tê bikaranîn?',
       'Dubarekirina heman gavan', ['Parastina şîfreyan', 'Çapkirina kaxizê',
                                    'Girêdana torê'],
       'Xelek rê dide ku heman gav heta şertek pêk were dubare bibin.',
       'Döngü, aynı adımların bir koşul sağlanana dek tekrarlanmasını sağlar.'),
    mc('offline_tek_0008', 4,
       'Di bernamesaziyê de «guhêrbar» çi dike?',
       'Nirxekê bi navekî ve girê dide', ['Ekranê ronî dike',
                                          'Torê lez dike',
                                          'Bataryayê dagire'],
       'Guhêrbar nirxekê di bîrgeyê de bi navekî tomar dike.',
       'Değişken, bir değeri bellekte bir adla saklar.'),
    mc('offline_tek_0009', 5,
       'Çima girêdanên bêqablo ji yên bi qablo bêtir hewceyî şîfrekirinê ne?',
       'Ji ber ku sînyal li hewayê belav dibe û herkes dikare bigire',
       ['Ji ber ku hêdîtir in', 'Ji ber ku kêmtir enerjiyê dixwin',
        'Ji ber ku kurttir in'],
       'Sînyala bêqablo di hewayê de belav dibe; her amûra nêzîk dikare wê bibihîze.',
       'Kablosuz sinyal havada yayılır; yakındaki her cihaz onu dinleyebilir.'),
    mc('offline_tek_0010', 5,
       'Di daneparêziyê de «paşvegirtin» çi ye?',
       'Kopiyeke daneyan a li cihekî din', ['Şîfreya bikarhêner',
                                           'Leza torê', 'Rengê ekranê'],
       'Paşvegirtin daneyan li derveyî amûra sereke digire ku windabûn tazmîn bibe.',
       'Yedekleme, kaybı telafi etmek için veriyi ana cihaz dışında tutar.'),
    mc('offline_tek_0011', 2,
       'Peyva Kurmancî «pelgeh» bi Tirkî çi tê gotin?',
       'klasör', ['fare', 'ekran', 'kablo'],
       'Pelgeh dosyeyan bi hev re di nav xwe de kom dike.',
       'Klasör, dosyaları bir arada toplar.'),
    mc('offline_tek_0012', 3,
       'Kîjan amûr enerjiya elektrîkê ya amûrên guhêzbar hildigire?',
       'Batarya', ['Çaper', 'Mişk', 'Bilindgo'],
       'Batarya enerjiyê hildigire ku amûr bêyî pêwendiya elektrîkê bixebite.',
       'Batarya, cihazın prizsiz çalışması için enerjiyi depolar.'),
    mc('offline_tek_0013', 1,
       'Peyva Kurmancî «ekran» ji bo çi tê bikaranîn?',
       'Nîşandana wêne û nivîsan', ['Tomarkirina deng', 'Şîfrekirina daneyan',
                                    'Çapkirina kaxizê'],
       'Ekran encama hesaban wek wêne û nivîs nîşan dide.',
       'Ekran, hesabın sonucunu görüntü ve yazı olarak gösterir.'),
    mc('offline_tek_0014', 4,
       'Di torê de «server» çi kar dike?',
       'Xizmet û daneyan digihîne amûrên din',
       ['Tenê wêneyan çap dike', 'Tenê deng tomar dike',
        'Tenê bataryayê dagire'],
       'Server daxwazên amûrên din bersivandin û daneyan digihîne wan.',
       'Sunucu, diğer cihazların isteklerini karşılar ve onlara veri ulaştırır.'),
    mc('offline_tek_0015', 5,
       'Çima şîfreyeke dirêj ji ya kurt bihêztir e?',
       'Ji ber ku hejmara kombînasyonan bi dirêjiyê re bi lez zêde dibe',
       ['Ji ber ku bîranîna wê hêsantir e',
        'Ji ber ku kêmtir cih digire',
        'Ji ber ku torê lez dike'],
       'Her tîpa zêde hejmara îhtîmalan gelek qat mezin dike.',
       'Her ek karakter olasılık sayısını kat kat büyütür.'),

    tf('offline_tek_0016', 1,
       'Bîrgeya demkî (RAM) piştî girtina amûrê naveroka xwe winda dike.',
       'Rast',
       'RAG bêyî elektrîkê naveroka xwe naparêze; ji bo domdariyê dîsk tê bikaranîn.',
       'RAM elektrik kesilince içeriğini korumaz; kalıcılık için disk kullanılır.'),
    tf('offline_tek_0017', 2,
       'Girêdana HTTP naveroka di rê de şîfre dike.',
       'Şaş',
       'HTTP naveroka xwe eşkere dişîne; şîfrekirin bi HTTPS tê.',
       'HTTP içeriği açık gönderir; şifreleme HTTPS ile gelir.'),
    tf('offline_tek_0018', 3,
       'Pelrêça daneyan a li ser înternetê bêyî paşvegirtinê jî her tim ewle ye.',
       'Şaş',
       'Servera dûr jî dikare biteqe an bê hackkirin; paşvegirtin şertê ewlehiyê ye.',
       'Uzak sunucu da bozulabilir ya da ele geçirilebilir; yedekleme güvenliğin şartıdır.'),
    tf('offline_tek_0019', 2,
       'Peyva Kurmancî ya ku ji bo «mouse» tê bikaranîn «mişk» e.',
       'Rast',
       'Wek gelek zimanan, Kurmancî jî ji bo vê amûrê navê heywanê bi kar tîne.',
       'Birçok dil gibi Kurmancî de bu araç için hayvanın adını kullanır.'),
    tf('offline_tek_0020', 4,
       'Kodên çavkaniyê yên vekirî tenê ji aliyê şirketan ve tên nivîsandin.',
       'Şaş',
       'Kodê vekirî ji aliyê kes, komele û şirketan ve bi hev re tê pêşxistin.',
       'Açık kaynak kod; kişiler, topluluklar ve şirketler tarafından birlikte geliştirilir.'),
    tf('offline_tek_0021', 3,
       'Şîfreya heman ji bo hemû hesaban bikaranîn xetereyê zêde dike.',
       'Rast',
       'Heke yek xizmet bête hackkirin, hemû hesabên bi heman şîfreyê vedibin.',
       'Bir servis ele geçirilirse aynı parolayı kullanan tüm hesaplar açılır.'),
    tf('offline_tek_0022', 5,
       'Zêdekirina hejmara pêvajokeran her tim bernameyê ewqas qat lez dike.',
       'Şaş',
       'Beşên ku nikarin bi hev re bimeşin sînor datînin; ne her kar tê parvekirin.',
       'Paralelleşemeyen bölümler sınır koyar; her iş bölünebilir değildir.'),
    tf('offline_tek_0023', 1,
       'Klavye ji bo têketina nivîsê tê bikaranîn.',
       'Rast',
       'Klavye tîp û fermanan digihîne komputerê.',
       'Klavye, harfleri ve komutları bilgisayara iletir.'),
    tf('offline_tek_0024', 4,
       'Piştrastkirina du gavî tenê bi şîfreyê dixebite.',
       'Şaş',
       'Ew ji bilî şîfreyê hêmaneke duyem — kod an amûr — dixwaze.',
       'İki adımlı doğrulama, paroladan başka ikinci bir öge — kod ya da cihaz — ister.'),
    tf('offline_tek_0025', 2,
       'Peyva Kurmancî «malper» ji bo «web sitesi» tê bikaranîn.',
       'Rast',
       'Malper li ser înternetê rûpelên bi hev ve girêdayî digire nav xwe.',
       'Malper, internette birbirine bağlı sayfaları kapsar.'),
    tf('offline_tek_0026', 5,
       'Şîfrekirin daneyê bêyî mifteya rast dîsa xwendinbar dihêle.',
       'Şaş',
       'Armanca şîfrekirinê tam ev e: bêyî mifteyê nivîs ne xwendinbar be.',
       'Şifrelemenin amacı tam da budur: anahtar olmadan metin okunamaz olsun.'),
    tf('offline_tek_0027', 3,
       'Nûvekirinên nermalavê gelek caran valahiyên ewlehiyê digirin.',
       'Rast',
       'Nûvekirin çewtiyên naskirî yên ku dikarin bên bikaranîn sererast dike.',
       'Güncellemeler, sömürülebilir bilinen açıkları kapatır.'),
    tf('offline_tek_0028', 4,
       'Wêneyek bi çareseriya bilind her tim cihê kêmtir digire.',
       'Şaş',
       'Bêtir pîksel bêtir dane ye; bi giştî cih zêde dibe, ne kêm.',
       'Daha çok piksel daha çok veridir; yer genelde artar, azalmaz.'),
]


def main() -> int:
    rows = json.load(open(BANK, encoding='utf-8'))
    existing_ids = {row['id'] for row in rows}
    existing_prompts = {row['prompt'] for row in rows}

    clashes = [q['id'] for q in QUESTIONS if q['id'] in existing_ids]
    dupes = [q['id'] for q in QUESTIONS if q['prompt'] in existing_prompts]
    if clashes or dupes:
        print('çakışma: %s %s' % (clashes[:3], dupes[:3]))
        return 1

    rows.extend(QUESTIONS)
    with open(BANK, 'w', encoding='utf-8') as handle:
        json.dump(rows, handle, ensure_ascii=False, indent=2)
        handle.write('\n')

    total = sum(1 for r in rows if r['category'] == 'Teknolojî')
    print('eklenen: %d | Teknolojî toplam: %d' % (len(QUESTIONS), total))
    return 0


if __name__ == '__main__':
    sys.exit(main())
