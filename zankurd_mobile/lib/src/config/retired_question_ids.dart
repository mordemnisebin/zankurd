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
};

/// Soru emekliye ayrılmış bir genel kültür sorusu mu?
bool isQuestionRetired(String questionId) =>
    retiredQuestionIds.contains(questionId);
