/// Emekliye ayrılan genel kültür sorularının bekçisi.
///
/// ## Kusur
///
/// Oyuncuya yüklenen bankanın bir bölümü Kürtlerle ve bölgeyle bağı
/// olmayan dünya bilgisiydi ("Vertigo hangi yıl çıktı", "Güneş sisteminin
/// en büyük gezegeni"). 2026-09-27 içerik denetimiyle bu kayıtlar
/// `retired_question_ids.dart` listesine alındı: bankada duruyorlar,
/// oyuncuya çıkmıyorlar.
///
/// Aynı gün, İKİNCİ ve bağımsız bir kusur daha bulundu: `offline_tf_`
/// tanım-takası kalıbındaki "Şaş" soruların bir kısmı sorulan terimden
/// FARKLI TÜRDEN bir tanım taşıyordu (göl↔dağ, kişi↔çalgı gibi) — bilgi
/// değil tür ipucu ölçüyordu. Bu yüzden liste artık Ziman, Çand, Dîrok ve
/// Muzîk'ten de kimlik taşıyor; ayrıntı `retired_question_ids.dart`'ın
/// "İkinci dalga" bölümünde.
///
/// ## Niçin sessiz kalırdı
///
/// Liste yalnız kimliklerden oluşuyor. Bir kimlik yazım hatasıyla girerse
/// ya da soru bankadan yeniden adlandırılırsa liste hiçbir şeyi
/// dışlamadan "çalışıyor" görünür; tersine, yanlışlıkla Kürt içerikli bir
/// kategoriden kimlik eklenirse değerli bir soru sessizce kaybolur. Bu
/// bekçi üçünü de yakalar.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/retired_question_ids.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

void main() {
  const policy = QuestionContentPolicy();

  test('her emekli kimlik yüklenen bankada gerçekten var', () {
    final ids = {
      for (final q in QuestionBankLoader.instance.allQuestions) q.id,
    };
    final missing = retiredQuestionIds.where((id) => !ids.contains(id));
    expect(missing, isEmpty, reason: 'Bankada olmayan kimlik: $missing');
  });

  test('emekli sorular oynanmaz, geri kalanı etkilenmez', () {
    final all = QuestionBankLoader.instance.allQuestions;
    for (final q in all.where((q) => retiredQuestionIds.contains(q.id))) {
      expect(policy.isPlayable(q), isFalse, reason: q.id);
    }
    expect(isQuestionRetired('bu-kimlik-yok'), isFalse);
  });

  test('yalnız iki bilinen gerekçenin kategorilerinden kimlik alınır', () {
    // İlk denetimde (dünya bilgisi) Ziman, Çand ve Dîrok'ta soru çıkmadı;
    // bu üçü yalnız 2026-09-27'deki İKİNCİ denetimle (tanım takasında
    // farklı türden çift) listeye girdi — bkz. `retired_question_ids.dart`
    // dosya başındaki "İkinci dalga" bölümü. Beklenmeyen bir kategori
    // çıkarsa ya bir kimlik yanlış girilmiştir ya da değerli bir Kürt
    // içerikli soru sessizce kaybolmaktadır.
    // 2026-09-29 doğallık: üçüncü dalga (şablon izi, bkz. aynı dosyanın
    // "Üçüncü dalga" belgesi) yalnız bu yedi kategoriden id ekledi; küme
    // bilerek aynı kaldı.
    final byId = {
      for (final q in QuestionBankLoader.instance.allQuestions) q.id: q,
    };
    final categories = {
      for (final id in retiredQuestionIds) byId[id]?.category,
    };
    expect(categories, {
      'Sînema',
      'Cografya',
      'Edebiyat',
      'Dîrok',
      'Muzîk',
      'Ziman',
      'Çand',
    });
  });
}
