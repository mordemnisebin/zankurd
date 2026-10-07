/// 2026-09-30 bilgi denetimi: Gemini (agy) üç soruya "bilgi yanlışı" dedi,
/// ana ajan kaynaktan doğruladı ve düzeltti.
///
/// * Dicle'nin kaynağı. Tanım "ji Amedê dest pê dike / Amed'den doğup"
///   diyordu; Dicle Elazığ'daki Hazar Gölü yöresinden, Toroslardan doğar,
///   Amed'den geçer. `offline_tf_cog_0033` doğru cevabı "Rast" olan bir
///   doğru/yanlış sorusuydu, yani oyuncuya yanlış bilgi "doğru" diye
///   öğretiliyordu. Aynı tanımı çeldirici ya da açıklama olarak taşıyan iki
///   kardeş soru da (`_0032`, `_0034`) aynı cümleyle düzeltildi.
/// * "Şivanê Kurmanca". Açıklama 1931 diyordu; 1931 Rusça baskıdır,
///   Kurmancî roman 1935'te çıktı ve "ilk Kurmancî roman" sayılan odur.
/// * "Dema Hespên Serxweş" (Sarhoş Atlar Zamanı). Şıklarda hem Vodka hem
///   Viskî vardı, doğru cevap Viskî'ydi; kaynaklar ise ikisini de söylüyor
///   (Wikipedia maddesi bile iki yerde farklı). Vodka diyen oyuncu haksız
///   yere "yanlış" duyuyordu. Soru kaynakların uzlaştığı düzeye çekildi
///   (alkollü içki, çeldiriciler alkolsüz). Sunucu kopyası
///   `supabase/2026-09-30_sinema_drunken_horses_fix.sql` ile güncellendi.
///
/// Niçin sessizdi: üçü de yapısal olarak kusursuz sorulardı; kalite kapısı
/// ve dil denetimleri bilgi doğruluğuna bakmaz.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _bank(String name) =>
    (jsonDecode(File('assets/data/$name').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

Map<String, dynamic> _byId(List<Map<String, dynamic>> bank, String id) =>
    bank.firstWhere((q) => q['id'] == id);

void main() {
  final offline = _bank('offline_questions.json');
  final expansion = _bank('expansion_2026_09_28_questions.json');

  test('hiçbir soru Dicle\'nin Amed\'den doğduğunu söylemez', () {
    for (final q in [...offline, ...expansion]) {
      final text = jsonEncode(q);
      expect(
        text.contains('ji Amedê dest pê dike'),
        isFalse,
        reason: '${q['id']}: Dicle Amed\'den doğmaz, oradan geçer',
      );
      expect(
        text.contains("Amed'den doğ"),
        isFalse,
        reason: '${q['id']}: Dicle Amed\'den doğmaz, oradan geçer',
      );
    }
  });

  test('"Şivanê Kurmanca" Kurmancî baskı yılıyla (1935) anılır', () {
    for (final q in [...offline, ...expansion]) {
      for (final entry in q.entries) {
        final v = entry.value;
        if (v is String && v.contains('Şivanê Kurmanca')) {
          expect(
            v.contains('1931'),
            isFalse,
            reason: '${q['id']}.${entry.key}: 1931 Rusça baskıdır',
          );
        }
      }
    }
  });

  test('Sarhoş Atlar Zamanı sorusunda tek alkollü şık var', () {
    final q = _byId(expansion, 'ex28_yilmaz_guney_018');
    const alcohol = ['Vodka', 'Viskî', 'Araq', 'Şerab', 'Vexwarina alkolî'];
    final answers = (q['answers'] as List).cast<String>();
    expect(answers.where(alcohol.contains), [q['correctAnswer']]);
  });
}
