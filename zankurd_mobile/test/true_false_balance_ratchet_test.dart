/// Doğru/yanlış sorularında cevap dengesi için iki yönlü mandal.
///
/// ## Kusur
///
/// Oyuncu konuyu değil cevap eğilimini öğrenebilir: bir kategoride doğru
/// cevap çoğunlukla "Şaş" ya da çoğunlukla "Rast" ise «hep Şaş de» kuralı
/// bilgiden çok puan getirir. 2026-10-25 incelemesi ham JSON'da Şaş payını
/// ~%64 buldu (Ziman %77, Cografya %71); o sayım emekli/elenmiş kayıtları da
/// içeriyordu. Uygulamanın gerçekten yüklediği oynanabilir havuzda
/// (`MockZanKurdRepository.playableQuestions`) 2026-10-25 durumu: 306 soru,
/// 154 Şaş (%50,3), 152 Rast. `bosluk_balance_test.dart` yalnız üç
/// kategoride "Rast <= %60" bakıyordu; Şaş yönü hiç izlenmiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Eğim hata üretmez. Yeni bir parti yalnız Şaş önermelerle gelirse (ör.
/// `bosluk_2026_10_02`: 45/45 Şaş) ya da Rast sorular emekliye ayrılırsa
/// denge sessizce bozulur.
///
/// ## Neyi korur
///
/// * Her kategori (en az [_minSample] oynanabilir D/Y sorusu varsa) ve genel
///   havuz için Şaş payı aşağıdaki BUGÜNKÜ orandan yükselemez (mandal).
/// * Aynı kategorilerde ve genelde Rast payı %60'ı geçemez.
///
/// Amaç her kategoriyi kademeli olarak %40–60 bandına indirmek. Oran
/// düştükçe tavanı yeni değere çek; asla yükseltme. Yeni Rast önermeler
/// Kurmancî metin kuralıyla, iki modelin (Gemini 3.8 Flash + Grok 4.7)
/// onayıyla eklenir. Denetim oran temellidir; veri azaldığında (soru
/// emekliye ayrılınca) yalnız oran bozulursa kırılır, küçük kategoriler
/// örnek eşiğinin altında kalınca atlanır.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

const _minSample = 20;
const _maxRastShare = 0.60;

/// Kategori → (Şaş, toplam) — 2026-10-25 oynanabilir havuz. Tavan oranı
/// `Şaş / toplam`dır; sayılar yalnız oranı kesin (tam sayıyla) yazmak için.
const Map<String, (int, int)> _sasCeiling = {
  'Cografya': (27, 48), // %56,3
  'Dîrok': (24, 43), // %55,8
  'Çand': (22, 40), // %55,0
  'Siyaset': (16, 30), // %53,3
  'Teknolojî': (20, 42), // %47,6
  'Edebiyat': (17, 38), // %44,7
  'Muzîk': (15, 37), // %40,5
  // Örnek eşiğinin altında (2026-10-25): Ziman 4/11, Paradigma 6/10,
  // Cîhan 2/4, Sînema 1/3. Eşiği geçince buraya o günkü oranla girer.
  'Ziman': (4, 11),
  'Paradigma': (6, 10),
  'Cîhan': (2, 4),
  'Sînema': (1, 3),
};
const (int, int) _overallSasCeiling = (154, 306); // %50,3

String _pct(int a, int b) => '$a/$b (%${(a / b * 100).toStringAsFixed(1)})';

void main() {
  late List<QuizQuestion> tf;

  setUp(() {
    expect(QuestionBankLoader.instance.allQuestions.length, greaterThan(1000));
    tf = MockZanKurdRepository().playableQuestions
        .where((q) => q.type == QuestionType.trueFalse)
        .toList();
  });

  test('D/Y cevapları yalnız Rast ya da Şaş', () {
    expect(tf.length, greaterThanOrEqualTo(_minSample));
    final other = [
      for (final q in tf)
        if (q.correctAnswer != 'Rast' && q.correctAnswer != 'Şaş')
          '${q.id}: ${q.correctAnswer}',
    ];
    expect(other, isEmpty, reason: 'Sayım dışı kalan D/Y cevabı: $other');
  });

  test('genel havuz: Şaş payı mandalın altında, Rast <= %60', () {
    final sas = tf.where((q) => q.correctAnswer == 'Şaş').length;
    final rast = tf.where((q) => q.correctAnswer == 'Rast').length;
    final (cs, ct) = _overallSasCeiling;
    expect(
      sas * ct,
      lessThanOrEqualTo(cs * tf.length),
      reason:
          'Genel Şaş payı ${_pct(sas, tf.length)} tavanı ${_pct(cs, ct)} '
          'aştı; Şaş eğimi büyüyor.',
    );
    expect(
      rast / tf.length,
      lessThanOrEqualTo(_maxRastShare),
      reason: 'Genel Rast payı ${_pct(rast, tf.length)} > %60',
    );
  });

  test('her kategori: Şaş payı mandalın altında, Rast <= %60', () {
    final byCategory = <String, List<QuizQuestion>>{};
    for (final q in tf) {
      byCategory.putIfAbsent(q.category, () => []).add(q);
    }
    final failures = <String>[];
    byCategory.forEach((category, list) {
      if (list.length < _minSample) return;
      final sas = list.where((q) => q.correctAnswer == 'Şaş').length;
      final rast = list.where((q) => q.correctAnswer == 'Rast').length;
      final ceiling = _sasCeiling[category];
      if (ceiling == null) {
        failures.add(
          '$category: ${list.length} D/Y sorusu var ama mandalda yok; '
          'bugünkü oranı (${_pct(sas, list.length)}) `_sasCeiling`e ekle',
        );
        return;
      }
      final (cs, ct) = ceiling;
      if (sas * ct > cs * list.length) {
        failures.add(
          '$category: Şaş ${_pct(sas, list.length)} > tavan ${_pct(cs, ct)}',
        );
      }
      if (rast / list.length > _maxRastShare) {
        failures.add('$category: Rast ${_pct(rast, list.length)} > %60');
      }
    });
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
