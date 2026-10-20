/// Boşluk doldurma ve kelime sıralama soru metnini parçalarına ayırır.
///
/// Bankadaki ~300 soru tek satıra sıkıştırılmış bir kalıpla yazılı:
///
///   Yönerge: "ana cümle" ("çeviri")
///   Yönerge: "Ev ___ e. (cihê jiyanê)" ("Bu evdir.")
///
/// Ekranda hepsi tek büyük başlık olarak çiziliyordu: yönerge, cümle, ipucu
/// ve çeviri aynı ağırlıkta okunuyordu; oyuncu hangisinin "doldurulacak
/// cümle" olduğunu ayıklamak zorundaydı. Bu dosya veriyi DEĞİŞTİRMEZ,
/// yalnız çizim için böler; kalıba uymayan metin için `null` döner ve
/// çağıran eski düzene düşer.
library;

/// [parseQuestionPrompt]ın çıktısı.
class QuestionPromptParts {
  const QuestionPromptParts({
    required this.instruction,
    required this.main,
    this.hint,
    this.translation,
  });

  /// "Hevokê temam bike" gibi küçük üst satır.
  final String instruction;

  /// Ana cümle (boşluk `___` olarak içinde durur).
  final String main;

  /// Tırnak içindeki cümlenin sonundaki parantezli ipucu.
  final String? hint;

  /// Dıştaki `("...")` çeviri.
  final String? translation;

  @override
  bool operator ==(Object other) =>
      other is QuestionPromptParts &&
      other.instruction == instruction &&
      other.main == main &&
      other.hint == hint &&
      other.translation == translation;

  @override
  int get hashCode => Object.hash(instruction, main, hint, translation);

  @override
  String toString() =>
      'QuestionPromptParts($instruction | $main | $hint | $translation)';
}

// Yönerge tırnaksız bir ön ek; ana cümle ilk tırnaktan başlar. Çeviri
// kendi içinde tırnak taşıyabilir (`("Geceleyin "iyi geceler" deriz.")`),
// bu yüzden çeviri varyantı önce denenir ve sondan bağlanır.
final RegExp _withTranslation = RegExp(
  r'^([^"]+?):\s*"(.+?)"\s*\("(.+)"\)\s*$',
  dotAll: true,
);
final RegExp _mainOnly = RegExp(r'^([^"]+?):\s*"(.+)"\s*$', dotAll: true);
final RegExp _trailingParen = RegExp(
  r'^(.*?\S)\s*\(([^()]+)\)\s*$',
  dotAll: true,
);

/// [prompt] kalıba uyuyorsa parçalarını, uymuyorsa `null` döndürür.
QuestionPromptParts? parseQuestionPrompt(String prompt) {
  final text = prompt.trim();
  final withTr = _withTranslation.firstMatch(text);
  final match = withTr ?? _mainOnly.firstMatch(text);
  if (match == null) return null;
  final instruction = match.group(1)!.trim();
  var main = match.group(2)!.trim();
  final translation = withTr?.group(3)?.trim();
  if (instruction.isEmpty || main.isEmpty) return null;

  String? hint;
  final paren = _trailingParen.firstMatch(main);
  if (paren != null) {
    final inner = paren.group(2)!.trim();
    final rest = paren.group(1)!.trim();
    if (inner.isNotEmpty && rest.isNotEmpty) {
      hint = inner;
      main = rest;
    }
  }
  return QuestionPromptParts(
    instruction: instruction,
    main: main,
    hint: hint,
    translation: (translation == null || translation.isEmpty)
        ? null
        : translation,
  );
}

String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Kelime sıralamada tırnak içi cümle Kurmancî cevabın kendisi değilse
/// kaynak (Türkçe) cümledir: oyuncu ondan Kurmancîye çevirir.
bool isTurkishSourceSentence(String main, List<String> answerWords) =>
    _fold(main) != _fold(answerWords.join(' '));
