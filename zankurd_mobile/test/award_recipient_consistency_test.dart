import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Aynı ödülü aynı yıl iki farklı kişiye verdiren soru bankada duramaz.
///
/// ## Kusur
///
/// Banka iki soruda birden 2021 Nobel Edebiyat Ödülü'nü soruyordu:
///
/// * `ds_edebiyat_0214` — "hangi Tanzanyalı yazara verildi?" → Abdulrazak
///   Gurnah. **Doğru.**
/// * `ds_edebiyat_0223` — "hangi Nijeryalı yazar kazandı?" → Chimamanda
///   Ngozi Adichie. **Uydurma.** Adichie hiç Nobel almadı.
///
/// İkincisi yalnız yanlış değil, yaşayan gerçek bir yazara almadığı bir
/// ödülü yakıştırıyordu (2026-08-18'de çıkarıldı).
///
/// ## Niçin sessiz kaldı
///
/// Çapraz kontrol (`answer_key_consensus_test`) bu soruyu ONAYLADI ve
/// onaylaması da beklenirdi: modele "şu dört addan hangisi" diye sorulur,
/// "bu soru anlamlı mı" diye sorulmaz. Dört Nijeryalı yazar arasından
/// birini seçmesi istenen model, ÖNCÜLÜN kendisinin yalan olduğunu —
/// 2021'de Nobel'i hiçbir Nijeryalının almadığını — söyleyebileceği bir yer
/// yoktu. Çapraz kontrolün yapısal kör noktası budur: şıkkı doğrular,
/// önermeyi değil.
///
/// Bankayı bir bütün olarak okuyan hiçbir bekçi de yoktu; her soru tek
/// başına tutarlıydı. Yalan ancak iki soru yan yana konunca görünür oluyor.
///
/// ## Ölçülen sözleşme
///
/// Aynı (ödül, yıl) çifti için "kim aldı" diye soran iki soru aynı adı
/// vermeli. Kural bilerek dar tutuldu: yalnız ALICIYI soran sorular
/// karşılaştırılır. "Hangi ödülü aldı" ya da "hangi yıl aldı" soruları
/// dışarıda kalır, çünkü 1982 Altın Palmiye'yi *Yol* ile *Missing* PAYLAŞTI
/// — aynı çifte iki meşru ad düşebilir. Ödül–yıl–alıcı üçlüsünde ise
/// paylaşım istisnası yoktur.
void main() {
  /// Alıcısı tek olan ödüller. Paylaşımlı verilebilen ödüller (Altın
  /// Palmiye, Nobel Barış) bilerek dışarıda.
  final award = RegExp(
    r'Nobel (Edebiyat|Fizik|Kimya|Tıp) Ödülü|Nobel Edebiyat|Nobel Fizik',
    caseSensitive: false,
  );
  final year = RegExp(r'\b(1[89]\d{2}|20[0-2]\d)\b');

  /// Soru alıcıyı mı soruyor? "hangi ... yazar/şair/bilim insanı", "kim".
  final asksRecipient = RegExp(
    r'\bkim\b|hangi\s+\S*\s*(yazar|şair|bilim\s?insan|fizikçi|kimyager|romancı)',
    caseSensitive: false,
  );

  test('aynı ödül ve yıl için iki farklı alıcı adı verilmiyor', () {
    final recipients = <String, Set<String>>{};
    final sources = <String, List<String>>{};

    for (final file in Directory('assets/data').listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final decoded = jsonDecode(file.readAsStringSync());
      final items = decoded is List
          ? decoded
          : (decoded is Map ? decoded['questions'] : null);
      if (items is! List) continue;

      for (final item in items) {
        if (item is! Map) continue;
        final prompt = item['promptTr'];
        if (prompt is! String || !asksRecipient.hasMatch(prompt)) continue;

        final haystack = '$prompt ${item['explanation'] ?? ''}';
        final awardMatch = award.firstMatch(haystack);
        final yearMatch = year.firstMatch(prompt);
        if (awardMatch == null || yearMatch == null) continue;

        final answer = item['correctAnswerTr'] ?? item['correctAnswer'];
        if (answer is! String || answer.trim().isEmpty) continue;

        final key =
            '${awardMatch.group(0)!.toLowerCase().replaceAll('ödülü', '').trim()}'
            '|${yearMatch.group(1)}';
        (recipients[key] ??= <String>{}).add(answer.trim());
        (sources[key] ??= <String>[]).add('${item['id']}');
      }
    }

    // Kuralın canlı olduğunu da ölç: çıkarım sessizce bozulursa hiçbir çift
    // toplanmaz ve bekçi hiçbir şeyi ölçmeden yeşil kalırdı.
    expect(
      recipients.length,
      greaterThanOrEqualTo(10),
      reason:
          'Ödül–yıl çifti çıkarımı hiçbir şey bulamadı; bekçi ölü. Soru '
          'metinleri değiştiyse desenler de güncellenmeli.',
    );

    final conflicts = recipients.entries
        .where((e) => e.value.length > 1)
        .map((e) => '${e.key}: ${e.value.join(" / ")} (${sources[e.key]!.join(", ")})')
        .toList();

    expect(
      conflicts,
      isEmpty,
      reason:
          'Aynı ödül aynı yıl iki farklı kişiye verilmiş görünüyor; en az '
          'biri uydurma: $conflicts',
    );
  });
}
