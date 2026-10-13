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

  test('yalnız bilinen gerekçelerin kategorilerinden kimlik alınır', () {
    // İlk denetimde (dünya bilgisi) Ziman, Çand ve Dîrok'ta soru çıkmadı;
    // bu üçü yalnız 2026-09-27'deki İKİNCİ denetimle (tanım takasında
    // farklı türden çift) listeye girdi — bkz. `retired_question_ids.dart`
    // dosya başındaki "İkinci dalga" bölümü. Beklenmeyen bir kategori
    // çıkarsa ya bir kimlik yanlış girilmiştir ya da değerli bir Kürt
    // içerikli soru sessizce kaybolmaktadır.
    // 2026-09-29 doğallık: üçüncü dalga (şablon izi, bkz. aynı dosyanın
    // "Üçüncü dalga" belgesi) yalnız bu yedi kategoriden id ekledi; küme
    // bilerek aynı kaldı.
    // 2026-09-30 dördüncü dalga (tartışmalı siyasi görüş, bkz. aynı dosyanın
    // "Dördüncü dalga" belgesi): ürün sahibi Paradigma ve Siyaset'i yeniden
    // açtı ve tek bir siyasi hareketin öğretisini doğru cevap diye sunan
    // 159 soru tek tek emekliye ayrıldı. Bu iki kategori listeye BİLEREK
    // girdi; kategoriler açık, yalnız o sorular kapalı.
    final byId = {
      for (final q in QuestionBankLoader.instance.allQuestions) q.id: q,
    };
    final categories = {
      for (final id in retiredQuestionIds) byId[id]?.category,
    };
    // 2026-09-30 altıncı dalga (son olgu doğrulaması, Gemini 3.1 Pro + Grok
    // 4.7 ikisi de onayladı): Teknolojî ilk kez listeye girdi (3 soru).
    // Aynı gün `Cîhan` kategorisine 99 sinema/coğrafya/edebiyat kaydı döndü
    // ve hiçbiri artık bu listede değil — `Cîhan` burada ÇIKMAMALI.
    expect(categories, {
      'Teknolojî',
      'Sînema',
      'Cografya',
      'Edebiyat',
      'Dîrok',
      'Muzîk',
      'Ziman',
      'Çand',
      'Paradigma',
      'Siyaset',
    });
  });
}
