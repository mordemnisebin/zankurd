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
library;

const Set<String> retiredQuestionIds = <String>{
  // Sînema (97)
  'cinema_0002',
  'cinema_0005',
  'cinema_0008',
  'cinema_0011',
  'cinema_0012',
  'cinema_0014',
  'cinema_0015',
  'cinema_0017',
  'cinema_0020',
  'cinema_0021',
  'cinema_0023',
  'cinema_0024',
  'cinema_0025',
  'cinema_0026',
  'cinema_0029',
  'cinema_0030',
  'cinema_0032',
  'cinema_0033',
  'cinema_0035',
  'cinema_0037',
  'cinema_0038',
  'cinema_0039',
  'cinema_0041',
  'cinema_0044',
  'cinema_0047',
  'cinema_0048',
  'cinema_0050',
  'cinema_0052',
  'cinema_0054',
  'ds26_cinema_0087',
  'ds26_cinema_0089',
  'ds26_cinema_0090',
  'ds26_cinema_0109',
  'ds26_cinema_0111',
  'ds26_cinema_0113',
  'edit_sinema_0011',
  'edit_sinema_0012',
  'edit_sinema_0013',
  'edit_sinema_0014',
  'edit_sinema_0015',
  'edit_sinema_0017',
  'edit_sinema_0019',
  'edit_sinema_0020',
  'edit_sinema_0021',
  'edit_sinema_0022',
  'edit_sinema_0023',
  'edit_sinema_0024',
  'edit_sinema_0027',
  'edit_sinema_0030',
  'offline_sin_2002',
  'offline_sin_2005',
  'offline_sin_2008',
  'offline_sin_2011',
  'offline_sin_2012',
  'offline_sin_2013',
  'offline_sin_2015',
  'offline_sin_2016',
  'sf_cin_0003',
  'sf_cin_0004',
  'sf_cin_0005',
  'sf_cin_0006',
  'sf_cin_0007',
  'sf_cin_0008',
  'sf_cin_0009',
  'sf_cin_0010',
  'sf_cin_0011',
  'sf_cin_0012',
  'sf_cin_0013',
  'sf_cin_0014',
  'sf_cin_0015',
  'sf_cin_0016',
  'sf_cin_0017',
  'sf_cin_0018',
  'sf_cin_0019',
  'sf_cin_0020',
  'sf_cin_0021',
  'sf_cin_0022',
  'sf_cin_0026',
  'sf_cin_0028',
  'sf_cin_0029',
  'sf_cin_0032',
  'sf_cin_0033',
  'sf_cin_0034',
  'sf_cin_0035',
  'sf_cin_0036',
  'sf_cin_0037',
  'sf_cin_0038',
  'sf_cin_0040',
  'sf_cin_0043',
  'sf_cin_0044',
  'sf_cin_0045',
  'sf_cin_0047',
  'sf_cin_0048',
  'sf_cin_0049',
  'sf_cin_0050',
  'sf_cin_0051',
  'sf_cin_0052',
  // Cografya (23)
  'sf_geo_0001',
  'sf_geo_0002',
  'sf_geo_0003',
  'sf_geo_0004',
  'sf_nat_0002',
  'sf_nat_0003',
  'sf_nat_0004',
  'sf_nat_0005',
  'sf_nat_0006',
  'sf_nat_0007',
  'sf_nat_0008',
  'sf_nat_0009',
  'sf_nat_0010',
  'sf_nat_0011',
  'sf_nat_0012',
  'sf_nat_0013',
  'sf_nat_0014',
  'sf_nat_0015',
  'sf_nat_0016',
  'sf_nat_0017',
  'sf_nat_0018',
  'sf_nat_0019',
  'sf_nat_0020',
  // Edebiyat (1)
  'offline_ede_2014',

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
};

/// Soru emekliye ayrılmış bir genel kültür sorusu mu?
bool isQuestionRetired(String questionId) =>
    retiredQuestionIds.contains(questionId);
