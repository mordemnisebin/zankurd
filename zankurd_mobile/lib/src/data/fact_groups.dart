import '../models/quiz_question.dart';

/// Aynı olguyu soran soruların GRUP haritası (kimlik → grup anahtarı).
///
/// ## Kusur
///
/// Havuz küçük olduğu için aynı olgu birden çok kimlikle bankada duruyor
/// ("Mem û Zîn'in yazarı" yedi kimlik). Kimlik tabanlı "görüldü" geçmişi
/// bunları farklı soru sayar; oyuncu aynı turda ya da arka arkaya aynı olguyu
/// iki kez görebilir. GPT-6 Pro alan 7 bulgusu; yinelenenler
/// `alan7_tekrarlar.tsv`de listelendi, sahibin kararıyla SİLİNMEDİ — ikinci ve
/// sonraki kimlikler FARKLI bir olguyu soracak biçimde yeniden yazıldı. Bu
/// harita aradaki emniyet ağıdır: yeniden yazılamayan ya da sonradan benzeşen
/// kimlikler de aynı turda birlikte sunulmaz.
///
/// ## Kural
///
/// Bir turun aday havuzunda aynı gruptan yalnız İLK soru tutulur (sıra
/// korunur). Tur başka türlü dolmuyorsa seçici zaten havuzun geri kalanından
/// tamamlar: "tek soruluk tur" aynı olguyu iki kez sormaktan kötüdür.
/// Bekçi: `test/fact_group_test.dart`.
const Map<String, String> factGroupOf = {
  'edit_edebiyat_0001': 'edit_edebiyat_0001',
  'hat_0011': 'edit_edebiyat_0001',
  'hat_0018': 'edit_edebiyat_0001',
  'hat_0025': 'edit_edebiyat_0001',
  'bilim_0025': 'edit_edebiyat_0001',
  'kolay_edebiyat_01': 'edit_edebiyat_0001',
  'kolay_dirok_04': 'edit_edebiyat_0001',
  'hat_0001': 'hat_0001',
  'hat_0009': 'hat_0001',
  'hat_0002': 'hat_0002',
  'hat_0012': 'hat_0002',
  'hat_0005': 'hat_0005',
  'hat_0010': 'hat_0005',
  'hat_0006': 'hat_0006',
  'hat_0015': 'hat_0006',
  'hat_0021': 'hat_0021',
  'hat_0028': 'hat_0021',
  'hat_0023': 'hat_0023',
  'hat_0032': 'hat_0023',
  'hat_0027': 'hat_0027',
  'ex28_dastangotin_007': 'hat_0027',
  'hat_0037': 'hat_0037',
  'hat_0045': 'hat_0037',
  'hat_0049': 'hat_0049',
  'hat_0056': 'hat_0049',
  'hat_0053': 'hat_0053',
  'altkonu_0014': 'hat_0053',
  'hat_0035': 'hat_0035',
  'ex28_yilmaz_guney_002': 'hat_0035',
  'hat_0036': 'hat_0036',
  'ex28_yilmaz_guney_003': 'hat_0036',
  'hat_0065': 'hat_0065',
  'hat_0074': 'hat_0065',
  'hat_0068': 'hat_0068',
  'hat_0076': 'hat_0068',
  'hat_0086': 'hat_0086',
  'hat_0096': 'hat_0086',
  'hat_0103': 'hat_0103',
  'hat_0114': 'hat_0103',
  'altkonu_0007': 'altkonu_0007',
  'ex28_nujen_015': 'altkonu_0007',
  'altkonu_0016': 'altkonu_0016',
  'ds_sinema_0086': 'altkonu_0016',
  'offline_2430': 'offline_2430',
  'hat_0110': 'offline_2430',
  'ds_dirok_0172': 'ds_dirok_0172',
  'kolay_dirok_11': 'ds_dirok_0172',
  'ds_dirok_0150': 'ds_dirok_0150',
  'kolay_dirok_17': 'ds_dirok_0150',
  'ds_dirok_0026': 'ds_dirok_0026',
  'ds_dirok_0031': 'ds_dirok_0026',
  'ds_dirok_0043': 'ds_dirok_0026',
  'ds_dirok_0125': 'ds_dirok_0125',
  'ds_dirok_0143': 'ds_dirok_0125',
  'ds_dirok_0127': 'ds_dirok_0127',
  'ds_dirok_0134': 'ds_dirok_0127',
  'ds_dirok_0141': 'ds_dirok_0141',
  'ds_dirok_0148': 'ds_dirok_0141',
  'ds_muzik_0109': 'ds_muzik_0109',
  'ds_muzik_0106': 'ds_muzik_0109',
  'ds_muzik_0110': 'ds_muzik_0110',
  'ds_muzik_0103': 'ds_muzik_0110',
  'ds_muzik_0204': 'ds_muzik_0204',
  'ds_muzik_0213': 'ds_muzik_0204',
  'ds_sinema_0102': 'ds_sinema_0102',
  'ds_sinema_0109': 'ds_sinema_0102',
  'ds_teknoloji_0236': 'ds_teknoloji_0236',
  'ds_teknoloji_0242': 'ds_teknoloji_0236',
  'ds_teknoloji_0060': 'ds_teknoloji_0060',
  'ds_teknoloji_0068': 'ds_teknoloji_0060',
  'ds_teknoloji_0066': 'ds_teknoloji_0066',
  'ds_teknoloji_0073': 'ds_teknoloji_0066',
  'ds_ziman_0084': 'ds_ziman_0084',
  'ds_ziman_1101': 'ds_ziman_0084',
  'ds_ziman_0113': 'ds_ziman_0113',
  'ds_ziman_0080': 'ds_ziman_0113',
  'ds_cografya_0082': 'ds_cografya_0082',
  'ds_cografya_0086': 'ds_cografya_0082',
  'ds_cand_0240': 'ds_cand_0240',
  'ds_cand_0016': 'ds_cand_0240',
  'ds_cand_0209': 'ds_cand_0209',
  'ds_cand_0233': 'ds_cand_0209',
  'ds_teknoloji_0110': 'ds_teknoloji_0110',
  'ds_teknoloji_0124': 'ds_teknoloji_0110',
};

class FactGroups {
  const FactGroups._();

  /// [id] bir olgu grubundaysa grup anahtarı, değilse null.
  static String? of(String id) => factGroupOf[id];

  /// Aynı olgu grubundan yalnız ilk soruyu tutar; sıra korunur.
  static List<QuizQuestion> keepFirstPerGroup(List<QuizQuestion> pool) {
    final seen = <String>{};
    return [
      for (final question in pool)
        if (of(question.id) case final group?)
          if (seen.add(group)) question else ...const <QuizQuestion>[]
        else
          question,
    ];
  }
}
