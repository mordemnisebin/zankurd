import 'package:flutter/widgets.dart';

import '../models/quiz_question.dart';

/// Bir tura servis edilecek soru kümesinin *kendi içindeki* tutarlılığını
/// koruyan saf politika.
///
/// Tek tek doğru olan sorular, yan yana geldiklerinde birbirini bozabilir.
/// 2026-07-25 canlı denetiminde görülen örnek:
///
///   1. soru: "'rênivîsa Hawarê' hangi açıklamayla anlaşılır?"
///      → doğru cevap: "Celadet Bedirxan'ın latin harfli alfabe sistemi"
///   2. soru: "Şu açıklama hangi terimdir: ...?"
///      → şıklardan biri: "rênivîsa Hawarê"
///
/// Birinci soru ikincinin cevabını, ikinci de birincinin terimini açık
/// ediyordu: aynı terim havuzundan ters çevrilerek üretilmiş sorular arka
/// arkaya düşünce tur bir bilgi ölçümü olmaktan çıkıyor.
///
/// Politika saf ve senkrondur; hem mock hem sunucu deposu aynı süzgeci
/// kullanır ki davranış ortamlar arasında ayrışmasın.
class QuestionSetPolicy {
  const QuestionSetPolicy._();

  /// Bir metni karşılaştırma için sadeleştirir: küçük harf, kenar boşlukları
  /// ve tırnak/noktalama kırpılmış. Kurmancî özel karakterleri (î, ê, û, ş,
  /// ç) *korunur* — ASCII'ye katlamak "şer" ile "ser" gibi farklı sözcükleri
  /// eşitler.
  static String normalize(String value) {
    final lowered = value.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final rune in lowered.runes) {
      final char = String.fromCharCode(rune);
      // Noktalama ve tırnak atılır; harf, rakam ve boşluk kalır.
      if (RegExp(r'[\p{L}\p{N}\s]', unicode: true).hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// [a] ve [b] birbirinin cevabını sızdırıyor mu?
  ///
  /// Sızıntı sayılan durumlar:
  /// - Birinin doğru cevabı, diğerinin soru metninde geçiyor.
  /// - Birinin doğru cevabı, diğerinin şıklarından biriyle aynı.
  ///
  /// Karşılaştırma iki yönlü yapılır; hangisinin önce geldiği önemsizdir.
  static bool leaksBetween(QuizQuestion a, QuizQuestion b) {
    if (a.id == b.id) return true;
    return _leaksInto(a, b) || _leaksInto(b, a);
  }

  static bool _leaksInto(QuizQuestion source, QuizQuestion target) {
    final answer = normalize(source.correctAnswer);
    // Çok kısa cevaplar ("5", "ez") tesadüfen her yerde geçer; eşiğin
    // altında kalanlar sızıntı sayılmaz, aksi halde geçerli sorular da
    // elenirdi.
    if (answer.length < 4) return false;

    final prompt = normalize(target.prompt);
    if (prompt.contains(answer)) return true;

    for (final option in target.answers) {
      if (normalize(option) == answer) return true;
    }
    return false;
  }

  /// [candidates] listesini sırasını koruyarak süzer: daha önce seçilmiş
  /// hiçbir soruyla sızıntı ilişkisi olmayan sorular tutulur.
  ///
  /// Süzgeç [limit] kadar soru bulamazsa listeyi zorla doldurmaz; eksik
  /// dönmek, kullanıcıya kendi kendini ele veren bir tur sunmaktan iyidir.
  /// Çağıran taraf isterse [fillFrom] ile havuzun kalanından tamamlayabilir.
  static List<QuizQuestion> withoutLeaks(
    List<QuizQuestion> candidates, {
    int? limit,
  }) {
    final kept = <QuizQuestion>[];
    for (final candidate in candidates) {
      if (limit != null && kept.length >= limit) break;
      final conflicts = kept.any((q) => leaksBetween(q, candidate));
      if (!conflicts) kept.add(candidate);
    }
    return kept;
  }

  /// Sorunun *okuma yükü*: metin ve şık uzunluğundan türetilen kaba bir
  /// karmaşıklık ölçüsü. Düşük = kısa ve doğrudan.
  ///
  /// Bankadaki `difficulty` etiketi konu zorluğunu anlatıyor ama okuma
  /// yükünü hiç yansıtmıyor: 2026-07-25 ölçümünde zorluk 1'in şık uzunluğu
  /// medyanı (50 karakter) tüm seviyelerin en yükseğiydi — yani tanım
  /// biçimli, altı satırlık sorular "Destpêk" (başlangıç) basamağına
  /// düşüyordu. Yeni öğrenen ilk temasında en ağır metinle karşılaşıyordu.
  static int readingLoad(QuizQuestion question) {
    final promptLength = question.prompt.characters.length;
    final longestOption = question.answers.fold<int>(
      0,
      (maximum, option) => option.characters.length > maximum
          ? option.characters.length
          : maximum,
    );
    // Şık uzunluğu iki kat ağırlıklı: dört uzun şıkkı karşılaştırmak, uzun
    // bir soru metnini okumaktan daha yorucudur.
    return promptLength + longestOption * 2;
  }

  /// [candidates] listesini okuma yüküne göre hafiften ağıra sıralar.
  ///
  /// Kararlılık için eşit yükte olanlar özgün sıralarını korur; böylece
  /// aynı havuz her seferinde aynı turu üretir (test edilebilirlik).
  static List<QuizQuestion> byReadingLoad(List<QuizQuestion> candidates) {
    final indexed = candidates.indexed.toList()
      ..sort((a, b) {
        final byLoad = readingLoad(a.$2).compareTo(readingLoad(b.$2));
        return byLoad != 0 ? byLoad : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  /// Açıklama sorunun kendisini tekrar ediyor mu?
  ///
  /// "«lêkera gerguhêz» şu anlama gelir: lêkerên ku hewcedariya wan bi
  /// artêla tewandî heye…" — soru zaten bu tanımı verip terimi soruyordu;
  /// açıklama hiçbir yeni bilgi eklemiyor (2026-07-25 canlı denetimi).
  ///
  /// Üretim akışında soru banka araçları bu bayrağı kalite raporunda
  /// kullanır; uygulama çalışırken içerik elemek için değil, denetim için.
  static bool explanationIsTautological(QuizQuestion question) {
    final explanation = normalize(
      question.explanationTr ?? question.explanationKu ?? question.explanation,
    );
    if (explanation.isEmpty) return false;
    final prompt = normalize(question.prompt);
    if (prompt.isEmpty) return false;

    // Sorunun tırnak içindeki tanım kısmı açıklamada birebir geçiyorsa,
    // açıklama soruyu yeniden yazmaktan ibarettir.
    final quoted = RegExp(r"'([^']{12,})'").allMatches(question.prompt);
    for (final match in quoted) {
      final fragment = normalize(match.group(1) ?? '');
      if (fragment.length >= 12 && explanation.contains(fragment)) return true;
    }

    // Ya da açıklamanın büyük bölümü doğrudan soru metninden kopyalanmışsa.
    final promptWords = prompt.split(' ').where((w) => w.length > 3).toSet();
    if (promptWords.length < 5) return false;
    final explanationWords = explanation
        .split(' ')
        .where((w) => w.length > 3)
        .toList();
    if (explanationWords.length < 5) return false;
    final shared = explanationWords.where(promptWords.contains).length;
    return shared / explanationWords.length >= 0.8;
  }
}
