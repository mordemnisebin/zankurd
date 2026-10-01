/// Bankada duran ama oyuncuya gösterilmeyen genel kültür soruları.
///
/// ## Neden
///
/// ZanKurd'un ayırt edici değeri Kürt dili ve kültürü. 2026-09-27 içerik
/// denetiminde oyuncuya yüklenen 1617 soru (Paradigma ve Siyaset hariç
/// sekiz kategori) tek tek okunup dört sınıfa ayrıldı: KURDI, ZIMAN
/// (Kurmancî öğretimi), BOLGE (Mezopotamya/Ortadoğu bağlamı) ve GENEL
/// (Kürtlerle ve bölgeyle bağı olmayan dünya bilgisi). Her uygulamada
/// bulunan dünya bilgisi soruları ZanKurd'u sıradanlaştırıyordu; benzer
/// Kürtçe uygulamalarda oyuncunun övdüğü şey Kürt içeriğiydi.
///
/// ## Kural
///
/// Çıkan: Kürtlerle bağı olmayan DÜNYA BİLGİSİ — belirli bir yabancı eser,
/// kişi, kurum, festival, tarih ya da sayısal rekor ("Vertigo hangi yıl
/// çıktı", "Güneş sisteminin en büyük gezegeni", "Don Kişot").
///
/// Kalan: KAVRAM ve TERİM soruları — konusu evrensel olsa da oyuncuya o
/// alanın Kurmancî sözcük dağarcığını öğretir: sinema dili (yönetmen,
/// kurgu, plan sekans, foley), müzik terimleri (melodi, ritim, armoni),
/// coğrafya kavramları (erozyon, iklim, föhn, harita izdüşümü).
///
/// Teknolojî ayrıca bütünüyle gizlendi (217 sorunun 198'i genel; bkz.
/// `category_visibility.dart`). Ziman, Çand ve Dîrok'ta genel soru yok.
///
/// ## Geri almak
///
/// Sorular silinmedi; bankada duruyor. Bir id'yi buradan çıkarmak onu
/// yeniden oynanır yapar. İleride ayrı bir "Genel Kültür" kategorisi
/// açılırsa bu liste onun kaynağıdır.
///
/// ## Cîhan'a dönenler (2026-09-30)
///
/// Ürün sahibi o "ayrı kategori" kararını verdi: ürün ~%70 Kürt içeriği,
/// ~%30 açıkça adlandırılmış nötr genel bilgi olacak. İlk (dünya bilgisi)
/// dalgadan 47 kayıt — dünya sineması (37), dünya coğrafyası ve doğa
/// bilgisi (9: okyanuslar, atmosfer, Challenger Deep…) ve Don Kişot (1) —
/// emekliden çıkarıldı ve `Cîhan` (Türkçe «Dünya») kategorisine alındı.
/// Bu 47'yi kalan emeklilerden ayıran şey, ikinci ve sonraki dalgaların
/// KUSURLARINA (tanım takası, şablon izi, tartışmalı görüş) değil yalnız
/// «Kürt bağı yok» gerekçesine dayanmalarıdır; o gerekçe artık kusur değil,
/// kategorinin tanımıdır. Olgu ve dil denetimleri (en az iki bağımsız model
/// + Gemini 3.1 Pro Kurmancî okuması) temiz çıktı. Kayıtlar kendi
/// bankalarında duruyor; yalnız `category` alanı `Cîhan` oldu. Emekli kalan
/// dünya bilgisi soruları (örneğin `cinema_0009`) bu denetimlerden
/// geçmedikleri için hâlâ burada ve hâlâ oynanmaz; geçen bir aday aynı
/// yoldan dönebilir.
///
/// İkinci tur (aynı gün): 52 kayıt daha (42 sinema, 10 coğrafya/doğa)
/// aynı yoldan döndü; bu kez her birine Gemini 3.1 Pro bir Kurmancî dil/terim
/// düzeltmesi önerdi, Grok 4.7 ya da Gemini 3.8 Flash onayladı ve düzeltme
/// uygulandı (hangi şıkkın doğru olduğu değişmedi). Listeden çıkarıldılar ve
/// `category` alanı `Cîhan` oldu.
///
/// ## İkinci dalga (2026-09-27, tanım takası — üsttekinden bağımsız kusur)
///
/// `tool/author_replacement_questions.py` ve `tool/author_replacements_wave2.py`
/// (2026-07-26) `offline_tf_` kimlikli `Rast e an şaş e: Têgeha «X» tê vê
/// wateyê: (tanım)` kalıbında 232 oynanabilir soru yazdı: her terimden biri
/// kendi tanımıyla ("Rast"), biri BAŞKA bir terimin gerçek tanımıyla ("Şaş").
/// Denetimde 80 Rast / 152 Şaş çıktı — hep "Şaş" diyen bir strateji %66
/// kazanıyordu. 152 Şaş'ın 87'sinde yanlış tanım, sorulan terimden TÜRCE
/// FARKLI bir terime aitti: göl↔dağ, kişi↔çalgı, dergi↔kişi, iklim↔dağ,
/// hanedan↔antlaşma, atasözü↔inanç… Bu tür bir soru bilgi ölçmez,
/// TÜR ipucu ölçer: konuyu hiç bilmeyen biri "bir göl dağ gibi tarif
/// edilemez" diyerek doğru cevabı bulur. Aynı TÜRDEN çift olan Şaş sorular
/// (iki nehir, iki şair, iki hanedan, iki çalgı…) bankada KALDI; onlar
/// gerçek bilgi ister. Sınırda kalan çiftler (ör. bir isyan tanımının bir
/// katliam tanımıyla, ya da bir kitabın bir dergiyle değişmesi) de bilerek
/// KALDI — tür farkı orada tartışmalı, emekliye ayırmak için yeterince
/// açık değil.
///
/// Ziman'ın gerekçesi farklıdır: orada kalıbın hiç "Rast" örneği yoktu
/// (0/10), yani kalıbı tanıyan oyuncu her seferinde "Şaş" diyerek
/// kazanıyordu; on sorunun tamamı emekliye ayrıldı.
///
/// Bu ikinci dalga Ziman, Çand ve Dîrok'ta da id ekliyor; üstteki "genel
/// dünya bilgisi yok" cümlesi hâlâ doğrudur — bu ayrı, ikinci bir kusurdur.
///
/// Aynı geçişte, ayrı ayrı doğrulanıp eklenen üç kayıt daha:
/// `sf_cin_0053` (Kiarostami'nin "Close-up"u — Kürt bağı yok, İran
/// sinemasının genel bilgisi), `cinema_0036` (Kaplanoğlu'nun "Bal"ı — Kürt
/// bağı yok, Türk sinemasının genel bilgisi) ve `offline_7011` (çoktan
/// seçmelide B ve C şıkları aynı önermenin iki söylenişi; soru şıklarıyla
/// çözülemez).
///
/// Oranın bekçisi: `test/tf_definition_swap_test.dart`.
///
/// ## Üçüncü dalga (2026-09-29, şablon izi — üsttekilerden bağımsız kusur)
///
/// Oynanabilir kümenin kalıp denetimi, sözlükten ve tanım listesinden
/// otomatik üretilmiş soruların bir kısmının bilgi değil kalıp ölçtüğünü
/// gösterdi. Yeni içerik yazılmadı; yalnız şu beş sınıf emekliye ayrıldı:
///
/// * Sözlük doğru/yanlış (26, Ziman): kelime ile Türkçe anlam rastgele
///   eşleştirilmiş; bu ailenin %81'inde cevap "Şaş" — kalıbı tanıyan oyuncu
///   hep "Şaş" diyerek kazanıyordu. Aynı aileden `offline_5268` ("pisîk" =
///   "kedi", Rast, örnek cümleli) bilerek KALDI: eşleştirmesi doğru ve
///   `animals_1` dersinin etiketli sorusu; çıkarsa ders mini testi 3'ten
///   2'ye iniyordu.
/// * Boş önerme (1): `offline_0755` ("Av … têgehan e") yanlışlanamaz; soru
///   bir şey sormuyor.
/// * Tür sızıntılı sözlük çoktan seçmelisi (55): doğru şık bir kişi/yer/eser
///   iken çeldiriciler başka türden ya da yarım cümle parçası; doğru cevap
///   türünden bulunuyor. (Sınırda kalan `offline_0748`, `offline_ede_2008`,
///   `ex28_festival_belgefilm_020`, `edit_edebiyat_0028` bilerek KALDI.)
/// * Tanımı bozuk / iki doğru şık (2): `offline_6626`, `offline_0543`.
/// * Çeldiricisi başka sorulardan kopyalanmış "çima" soruları
///   (`offline_2305`, `offline_2276`) ve aynı olgunun ikinci kılıfı
///   (`offline_7483`; ilk kılıf `offline_7334` zaten üstteki sınıfta).
///
/// Ayrıca ilk dalganın kuralına aykırı kalmış üç Kürt bağsız sinema
/// sorusu: `cinema_0009` ("Kış Uykusu"), `cinema_0027` ("Susuz Yaz"),
/// `cinema_0051` ("Gegen die Wand"). Üçü de Türkiye ya da Almanya
/// sinemasının genel bilgisi; ne film, ne yönetmen, ne konu Kürtlerle
/// bağlı. Emsal: ikinci dalgada aynı gerekçeyle çıkan `cinema_0036`.
///
/// ## Dördüncü dalga (2026-09-30, tartışmalı siyasi görüş — üsttekilerden bağımsız kusur)
///
/// Ürün sahibi 2026-09-30'da Paradigma, Siyaset ve Teknolojî'yi yeniden açtı
/// (bkz. `category_visibility.dart`). 2026-09-27'de bu üç kategorinin
/// gizlenmesindeki asıl gerekçe, bazı soruların bilgi değil TEK BİR SİYASİ
/// HAREKETİN öğretisini "doğru cevap" diye sunmasıydı (Türkiye pazarında
/// hukuki/erişim riski ve tarafsızlık sorunu). Kategoriyi bütünüyle gizlemek
/// tarafsız soruları da götürüyordu; bu yüzden çözüm SORU bazında yapıldı:
/// kategoriler açıldı, öğretiyi doğru şık ya da "Rast" diye sunan sorular
/// tek tek emekliye ayrıldı.
///
/// Sınıflama: Paradigma (108) ve Siyaset (51) bankasındaki 159 soru,
/// Gemini 3.8 Flash ve Muse Spark'ın bağımsız sınıflamasıyla "tartışmalı"
/// bulundu; iki modelin ayrıştığı sorularda Gemini 3.1 Pro son sözü söyledi.
/// Sunucudaki karşılığı `supabase/2026-09-30_contested_questions_unapprove.sql`
/// (zaten uygulandı; sunucuda 502 soruyu onaydan çıkardı). Yerel banka
/// uygulama paketiyle gelir ve sunucu göçünden etkilenmez, bu yüzden aynı
/// ayıklama burada da uygulanır; çevrimdışı paket ile sunucu böylece aynı
/// tutumu gösterir.
///
/// Kalan: bu sınıflamada tartışmalı bulunmayan Paradigma/Siyaset soruları
/// ve Kürt siyasi TARİHİ (olaylar, kişiler, tarihler; Dîrok'ta). Kayıtlar
/// silinmedi, bankada duruyor; bir id'yi buradan çıkarmak onu yeniden
/// oynanır yapar.
///
/// ## Beşinci dalga (2026-09-30, ikinci geçiş — bağımsız model ailesi)
///
/// Dördüncü dalgadan sonra kalan Siyaset/Paradigma soruları bağımsız bir
/// model ailesine (ChatGPT) de okutuldu. İşaretlediği 17 yerel soru iki
/// türdendi: RİSK — siyasi yüklü bir terime normatif tek tanım ya da bir
/// akıma ideolojik etiket ("mafê statuyê" gibi güncel siyasal talepler
/// atıfsız, genel-geçer bilgi gibi sunuluyordu); YANLIŞ — tartışmalı bir
/// siyaset bilimi kavramına ("radikal demokrasi", "katılımcı bütçe",
/// "toplumsal adalet") tek bir "doğru tanım" dayatılıyordu. Bilgi
/// yarışmasında cevabı tartışılabilir soru kötü sorudur; ürün sahibinin
/// "tartışmalıları ayıkla" çizgisinin devamıdır. Sunucudaki karşılığı
/// `supabase/2026-09-30_siyaset_second_pass_unapprove.sql` (zaten uygulandı;
/// sunucuda 64 soruyu onaydan çıkardı, bu 17'si yerel paketteki payıdır).
/// Kayıtlar silinmedi, bankada duruyor.
///
/// ## Altıncı dalga (2026-09-30, son olgu doğrulaması — üsttekilerden bağımsız kusur)
///
/// Son olgu doğrulamasında Gemini, Muse Spark, Grok 4.7 ve Space Bunny'den
/// en az biri bir soruyu olgu ya da şık doğruluğu açısından işaretledi. Her
/// işaret ikinci bir turda hem Gemini 3.1 Pro'ya hem Grok 4.7'ye gösterildi;
/// İKİSİ de sorun olduğunu doğruladığında soru emekliye ayrıldı (45 soru).
/// Otomatik yeniden yazılmadı: bir modelin önerdiği düzeltmeyi makineyle
/// uygulamak yeni olgu ya da dil hatası sokma riski taşır. Kusurlar
/// çoğunlukla «doğru şık sanılan şıkkın kavramı tam karşılamaması» türünden.
/// Kayıtlar silinmedi; düzeltilip insan okumasından
/// geçince id buradan çıkarılabilir. 45'in 7'si daha önceki dalgalarda zaten
/// emekliydi (yinelenen id eklenmedi), 38'i bu dalgada girdi.
library;

const Set<String> retiredQuestionIds = <String>{
  // Sînema (18)
  'cinema_0002',
  'cinema_0011',
  'cinema_0014',
  'cinema_0015',
  'cinema_0020',
  'cinema_0029',
  'cinema_0032',
  'cinema_0041',
  'cinema_0047',
  'cinema_0054',
  'edit_sinema_0017',
  'edit_sinema_0019',
  'edit_sinema_0030',
  'offline_sin_2002',
  'offline_sin_2016',
  'sf_cin_0005',
  'sf_cin_0010',
  'sf_cin_0012',
  // Cografya (4)
  'sf_nat_0003',
  'sf_nat_0006',
  'sf_nat_0007',
  'sf_nat_0018',

  // ---------------------------------------------------------------------
  // İkinci dalga (2026-09-27): tanım takası kalıbında farklı türden çift —
  // bkz. dosya başındaki "İkinci dalga" belgesi. Kimlikler kategoriye göre
  // gruplanmıştır; her grup içindeki sıra bankadaki sıradır.
  // ---------------------------------------------------------------------

  // Cografya (30) — tanım takası farklı türden (göl/dağ/vadi/nehir/ova/
  // iklim/bölge/şehir karışık eşleşmiş)
  'offline_tf_0015',
  'offline_tf_0019',
  'offline_tf_0027',
  'offline_tf_0055',
  'offline_tf_0061',
  'offline_tf_0141',
  'offline_tf_0143',
  'offline_tf_0145',
  'offline_tf_0151',
  'offline_tf_cog_0008',
  'offline_tf_cog_0010',
  'offline_tf_cog_0012',
  'offline_tf_cog_0014',
  'offline_tf_cog_0016',
  'offline_tf_cog_0018',
  'offline_tf_cog_0020',
  'offline_tf_cog_0022',
  'offline_tf_cog_0024',
  'offline_tf_cog_0026',
  'offline_tf_cog_0028',
  'offline_tf_cog_0030',
  'offline_tf_cog_0032',
  'offline_tf_cog_0042',
  'offline_tf_cog_0048',
  'offline_tf_cog_0054',
  'offline_tf_cog_0056',
  'offline_tf_cog_0062',
  'offline_tf_cog_0066',
  'offline_tf_cog_0068',
  'offline_tf_cog_0070',

  // Dîrok (16) — tanım takası farklı türden (kişi/hanedan/antlaşma/eser/
  // olay karışık eşleşmiş)
  'offline_tf_0007',
  'offline_tf_0037',
  'offline_tf_0049',
  'offline_tf_0051',
  'offline_tf_0053',
  'offline_tf_0059',
  'offline_tf_0065',
  'offline_tf_0069',
  'offline_tf_0147',
  'offline_tf_dir_0003',
  'offline_tf_dir_0009',
  'offline_tf_dir_0011',
  'offline_tf_dir_0013',
  'offline_tf_dir_0023',
  'offline_tf_dir_0027',
  'offline_tf_dir_0029',

  // Edebiyat (9) — tanım takası farklı türden (kişi/eser/soyut kavram
  // karışık eşleşmiş)
  'offline_tf_0025',
  'offline_tf_0039',
  'offline_tf_0111',
  'offline_tf_0159',
  'offline_tf_ede_0007',
  'offline_tf_ede_0009',
  'offline_tf_ede_0017',
  'offline_tf_ede_0027',
  'offline_tf_ede_0029',

  // Muzîk (12) — tanım takası farklı türden (kişi/çalgı/soyut kavram/tür
  // karışık eşleşmiş)
  'offline_tf_0023',
  'offline_tf_0033',
  'offline_tf_0045',
  'offline_tf_0091',
  'offline_tf_0117',
  'offline_tf_0153',
  'offline_tf_muz_0003',
  'offline_tf_muz_0007',
  'offline_tf_muz_0011',
  'offline_tf_muz_0017',
  'offline_tf_muz_0019',
  'offline_tf_muz_0027',

  // Ziman (10) — gerekçe ötekilerden farklı: Ziman'da bu kalıbın HİÇ
  // "Rast" örneği yoktu (0 Rast / 10 Şaş). Dilbilgisi terimleri öğrenen
  // için aynı türden sayılabilir, ama kalıp görüldüğü an cevap "Şaş"tı;
  // bu yüzden onu kalıbın on sorusunun tamamı emekliye ayrıldı.
  'offline_tf_0081',
  'offline_tf_0083',
  'offline_tf_0085',
  'offline_tf_0087',
  'offline_tf_0093',
  'offline_tf_0095',
  'offline_tf_0115',
  'offline_tf_0123',
  'offline_tf_0131',
  'offline_tf_0135',

  // Çand (20) — tanım takası farklı türden (nesne/gelenek/soyut değer/
  // sanat türü karışık eşleşmiş)
  'offline_tf_0005',
  'offline_tf_0021',
  'offline_tf_0031',
  'offline_tf_0057',
  'offline_tf_0067',
  'offline_tf_0101',
  'offline_tf_0107',
  'offline_tf_0149',
  'offline_tf_can_0003',
  'offline_tf_can_0005',
  'offline_tf_can_0007',
  'offline_tf_can_0011',
  'offline_tf_can_0013',
  'offline_tf_can_0015',
  'offline_tf_can_0017',
  'offline_tf_can_0019',
  'offline_tf_can_0021',
  'offline_tf_can_0025',
  'offline_tf_can_0027',
  'offline_tf_can_0029',

  // Ek (3) — ayrı ayrı doğrulanmış, tanım takası kalıbının dışında
  'sf_cin_0053', // Kiarostami "Close-up": Kürt bağı olmayan sinema
  'cinema_0036', // Kaplanoğlu "Bal": Kürt bağı olmayan sinema
  'offline_7011', // kopya şık: B ve C aynı önermenin iki söylenişi
  // ---------------------------------------------------------------------
  // Üçüncü dalga (2026-09-29): şablon izi denetimi — bkz. dosya başındaki
  // "Üçüncü dalga" belgesi. Sınıfa, sınıf içinde kategoriye göre.
  // ---------------------------------------------------------------------

  // Ziman (26) — sözlük D/Y rastgele eşleştirme (%81 Şaş; offline_5268 kaldı)
  'offline_0014',
  'offline_5035',
  'offline_5039',
  'offline_5099',
  'offline_5158',
  'offline_5168',
  'offline_5174',
  'offline_5204',
  'offline_5208',
  'offline_5307',
  'offline_5314',
  'offline_5364',
  'offline_5433',
  'offline_5475',
  'offline_5499',
  'offline_5591',
  'offline_5593',
  'offline_5631',
  'offline_5632',
  'offline_5675',
  'offline_5676',
  'offline_5722',
  'offline_5733',
  'offline_5834',
  'offline_5848',
  'offline_5941',

  // Cografya (1) — boş önerme
  'offline_0755',

  // Cografya (13) — tür sızıntılı / parça cümle çeldiricili sözlük çoktan seçmelisi
  'offline_8108',
  'offline_8220',
  'offline_8263',
  'offline_8356',
  'offline_8561',
  'offline_8585',
  'offline_8833',
  'offline_8916',
  'offline_8965',
  'offline_9008',
  'offline_9036',
  'offline_9096',
  'offline_curated_20776',

  // Dîrok (17) — tür sızıntılı / parça cümle çeldiricili sözlük çoktan seçmelisi
  'offline_0534',
  'offline_2458',
  'offline_2727',
  'offline_7015',
  'offline_7053',
  'offline_7242',
  'offline_7257',
  'offline_7334',
  'offline_7335',
  'offline_7394',
  'offline_7644',
  'offline_7668',
  'offline_curated_20551',
  'offline_curated_20576',
  'offline_curated_20650',
  'offline_curated_20676',
  'offline_curated_20726',

  // Edebiyat (6) — tür sızıntılı / parça cümle çeldiricili sözlük çoktan seçmelisi
  'offline_10104',
  'offline_2248',
  'offline_9749',
  'offline_9936',
  'offline_9942',
  'offline_curated_20351',

  // Muzîk (10) — tür sızıntılı / parça cümle çeldiricili sözlük çoktan seçmelisi
  'offline_10333',
  'offline_10344',
  'offline_10615',
  'offline_10827',
  'offline_11013',
  'offline_11107',
  'offline_11143',
  'offline_11154',
  'offline_11366',
  'offline_11420',

  // Çand (9) — tür sızıntılı / parça cümle çeldiricili sözlük çoktan seçmelisi
  'offline_6182',
  'offline_6530',
  'offline_6560',
  'offline_6581',
  'offline_6610',
  'offline_6722',
  'offline_6823',
  'offline_6971',
  'offline_curated_21126',

  // Dîrok (1) — tanımı bozuk / iki doğru şık
  'offline_0543',

  // Çand (1) — tanımı bozuk / iki doğru şık
  'offline_6626',

  // Dîrok (1) — çeldiricisi başka sorulardan ya da aynı olgunun ikinci kılıfı
  'offline_7483',

  // Çand (2) — çeldiricisi başka sorulardan ya da aynı olgunun ikinci kılıfı
  'offline_2305',
  'offline_2276',

  // Sînema (3) — Kürt bağı olmayan sinema
  'cinema_0009', // "Kış Uykusu" (Ceylan)
  'cinema_0027', // "Susuz Yaz" (Erksan)
  'cinema_0051', // "Gegen die Wand" (Akın)
  // Ziman (1) — görseli soruya değil, benzer sözcüğe uyuyor (2026-09-30
  // simülatör). "pir" Kurmancîde "çok"tur (doğru şık); görsel ise yaşlı,
  // gülümseyen bir adamı gösteriyor, yani "pîr" (yaşlı) anlamını. Oyuncu
  // görüntüye bakıp "yaşlı" düşünür; "çok" şıkkı görselle çelişir. Kayıt
  // bankada durur (`assets/data/offline_questions.json`); yeni görsel
  // gelince id buradan çıkarılabilir.
  'offline_0120',

  // ---------------------------------------------------------------------
  // Dördüncü dalga (2026-09-30): tartışmalı siyasi görüş — bkz. dosya
  // başındaki "Dördüncü dalga" belgesi. Kategoriye göre gruplu.
  // ---------------------------------------------------------------------

  // Paradigma (108) — tek bir siyasi hareketin öğretisini doğru cevap diye sunuyor
  'edit_paradigma_0001',
  'edit_paradigma_0002',
  'edit_paradigma_0003',
  'edit_paradigma_0004',
  'edit_paradigma_0005',
  'edit_paradigma_0006',
  'edit_paradigma_0007',
  'edit_paradigma_0008',
  'edit_paradigma_0010',
  'edit_paradigma_0011',
  'edit_paradigma_0012',
  'edit_paradigma_0013',
  'edit_paradigma_0015',
  'edit_paradigma_0017',
  'edit_paradigma_0018',
  'edit_paradigma_0019',
  'edit_paradigma_0020',
  'edit_paradigma_0021',
  'edit_paradigma_0022',
  'edit_paradigma_0023',
  'edit_paradigma_0024',
  'offline_11493',
  'offline_11511',
  'offline_11517',
  'offline_11538',
  'offline_11543',
  'offline_11556',
  'offline_11584',
  'offline_11588',
  'offline_11599',
  'offline_11605',
  'offline_11624',
  'offline_11649',
  'offline_11713',
  'offline_11728',
  'offline_11779',
  'offline_11782',
  'offline_11789',
  'offline_11792',
  'offline_11813',
  'offline_11820',
  'offline_11838',
  'offline_11846',
  'offline_11864',
  'offline_11870',
  'offline_11886',
  'offline_11893',
  'offline_11917',
  'offline_12036',
  'offline_12069',
  'offline_12073',
  'offline_12261',
  'offline_12291',
  'offline_12344',
  'offline_12366',
  'offline_12391',
  'offline_12401',
  'offline_2292',
  'offline_2329',
  'offline_2503',
  'offline_2594',
  'offline_2820',
  'offline_curated_21751',
  'offline_curated_21776',
  'offline_curated_21800',
  'offline_curated_21826',
  'offline_curated_21851',
  'offline_curated_21876',
  'offline_curated_21901',
  'offline_curated_21926',
  'offline_curated_21951',
  'offline_curated_21975',
  'offline_par_2003',
  'offline_par_2004',
  'offline_tf_0011',
  'offline_tf_0029',
  'offline_tf_0035',
  'offline_tf_0047',
  'offline_tf_0071',
  'offline_tf_0075',
  'offline_tf_0079',
  'offline_tf_0105',
  'offline_tf_0129',
  'offline_tf_0139',
  'offline_tf_par_0000',
  'offline_tf_par_0001',
  'offline_tf_par_0002',
  'offline_tf_par_0003',
  'offline_tf_par_0004',
  'offline_tf_par_0005',
  'offline_tf_par_0006',
  'offline_tf_par_0007',
  'offline_tf_par_0008',
  'offline_tf_par_0009',
  'offline_tf_par_0012',
  'offline_tf_par_0013',
  'offline_tf_par_0014',
  'offline_tf_par_0016',
  'offline_tf_par_0017',
  'offline_tf_par_0018',
  'offline_tf_par_0019',
  'offline_tf_par_0020',
  'offline_tf_par_0021',
  'offline_tf_par_0022',
  'offline_tf_par_0026',
  'offline_tf_par_0027',
  'offline_tf_par_0028',
  'offline_tf_par_0029',

  // Siyaset (51) — tek bir siyasi hareketin öğretisini doğru cevap diye sunuyor
  'comm_siy_0001',
  'comm_siy_0002',
  'edit_siyaset_0003',
  'edit_siyaset_0005',
  'edit_siyaset_0006',
  'edit_siyaset_0010',
  'edit_siyaset_0012',
  'edit_siyaset_0013',
  'edit_siyaset_0017',
  'offline_12758',
  'offline_12760',
  'offline_12771',
  'offline_12779',
  'offline_12891',
  'offline_12981',
  'offline_12989',
  'offline_13124',
  'offline_13394',
  'offline_13486',
  'offline_13600',
  'offline_13649',
  'offline_13790',
  'offline_2443',
  'offline_2502',
  'offline_2653',
  'offline_2710',
  'offline_2741',
  'offline_2823',
  'offline_curated_21526',
  'offline_curated_21551',
  'offline_curated_21575',
  'offline_curated_21626',
  'offline_curated_21701',
  'offline_curated_21726',
  'offline_tf_0097',
  'offline_tf_0099',
  'offline_tf_0109',
  'offline_tf_0121',
  'offline_tf_0125',
  'offline_tf_0127',
  'offline_tf_0137',
  'offline_tf_siy_0007',
  'offline_tf_siy_0008',
  'offline_tf_siy_0035',
  'offline_tf_siy_0036',
  'offline_tf_siy_0037',
  'offline_tf_siy_0038',
  'offline_tf_siy_0049',
  'offline_tf_siy_0050',
  'offline_tf_siy_0055',
  'offline_tf_siy_0056',

  // ---------------------------------------------------------------------
  // Beşinci dalga (2026-09-30): bağımsız model ailesinin ikinci geçişi —
  // bkz. dosya başındaki "Beşinci dalga" belgesi.
  // ---------------------------------------------------------------------

  // Siyaset (17) — tartışmalı kavrama tek "doğru tanım" (YANLIŞ)
  // ya da siyasi yüklü terime normatif tanım / ideolojik etiket (RİSK)
  'offline_12703',
  'offline_12742',
  'offline_12985',
  'offline_13129',
  'offline_13169',
  'offline_13382',
  'offline_2336',
  'offline_curated_21500',
  'offline_tf_0063',
  'offline_tf_0073',
  'offline_tf_siy_0003',
  'offline_tf_siy_0004',
  'offline_tf_siy_0005',
  'offline_tf_siy_0006',
  'offline_tf_siy_0012',
  'offline_tf_siy_0032',
  'offline_tf_siy_0034',

  // ---------------------------------------------------------------------
  // Altıncı dalga (2026-09-30): son olgu doğrulaması — bkz. dosya başındaki
  // "Altıncı dalga" belgesi. Kategoriye göre gruplu.
  // ---------------------------------------------------------------------

  // Cografya (2) — iki modelin onayladığı olgu/şık kusuru
  'edit_cografya_0031',
  'offline_8986',

  // Dîrok (7) — iki modelin onayladığı olgu/şık kusuru
  'edit_dirok_0006',
  'edit_dirok_0014',
  'edit_dirok_0021',
  'offline_2639',
  'offline_7360',
  'offline_7383',
  'offline_7480',

  // Edebiyat (8) — iki modelin onayladığı olgu/şık kusuru
  'ds_edebiyat_0249',
  'edit_edebiyat_0031',
  'offline_10002',
  'offline_9405',
  'offline_9529',
  'offline_9730',
  'offline_9953',
  'offline_curated_20401',

  // Muzîk (5) — iki modelin onayladığı olgu/şık kusuru
  'edit_muzik_0014',
  'offline_10427',
  'offline_10930',
  'offline_11383',
  'offline_2499',

  // Siyaset (2) — iki modelin onayladığı olgu/şık kusuru
  'offline_12745',
  'offline_12961',

  // Sînema (2) — iki modelin onayladığı olgu/şık kusuru
  'edit_sinema_0026',
  'sf_cin_0054',

  // Teknolojî (3) — iki modelin onayladığı olgu/şık kusuru
  'offline_tek_2008',
  'tech_invent_0038',
  'tech_invent_0049',

  // Çand (9) — iki modelin onayladığı olgu/şık kusuru
  'ds_cand_1201',
  'edit_cand_0039',
  'offline_2692',
  'offline_6067',
  'offline_6206',
  'offline_6260',
  'offline_6523',
  'offline_6882',
  'restore_2026_08_07_0003',
  // ---------------------------------------------------------------------
  // 2026-10-01: bilgi yanlışı — "Geliyê Botan … Cizîrê dorpêç dike" doğru
  // cevabı "Rast" olan bir D/Y'ydi; Botan Vadisi Siirt'tedir, Cizre'yi
  // çevrelemez. Açıklama yeniden yazılırken Gemini 3.1 Pro yakaladı.
  // ---------------------------------------------------------------------
  'offline_tf_cog_0003',
};

/// Soru emekliye ayrılmış bir genel kültür sorusu mu?
bool isQuestionRetired(String questionId) =>
    retiredQuestionIds.contains(questionId);
