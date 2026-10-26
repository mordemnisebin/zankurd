import '../l10n/strings.dart';
import 'learner_lexicon.dart';

/// Hawar (Latin) Kurmancî alfabesinin 31 harfi ve Türkçe konuşana ses
/// ipuçları (2026-10-27, "Alfabe ve sesler").
///
/// İpucu yalnız Türkçeden FARKLI okunan ya da Türkçede olmayan harflerde
/// vardır (e, ê, i, î, u, û, q, w, x); öteki harfler Türkçedeki gibi okunur
/// ve ipucu gürültü olurdu. Metinler jüri onaylıdır.
class AlphabetLetter {
  const AlphabetLetter(this.upper, this.letter, {this.hintKey});

  /// Büyük harf ("Ê"). Elle yazılır: `toUpperCase` yerel ayara göre
  /// değişebilir (Türkçe yerelde "i" → "İ" olurdu) ve süs amaçlı büyük
  /// harfe çevirme bekçisine takılır.
  final String upper;

  /// Küçük harf ("ê").
  final String letter;

  /// Ses ipucunun çeviri anahtarı; yoksa harf Türkçedeki gibi okunur.
  final String? hintKey;
}

const List<AlphabetLetter> kurmanciAlphabet = [
  AlphabetLetter('A', 'a'),
  AlphabetLetter('B', 'b'),
  AlphabetLetter('C', 'c'),
  AlphabetLetter('Ç', 'ç'),
  AlphabetLetter('D', 'd'),
  AlphabetLetter('E', 'e', hintKey: K.alphabetHintE),
  AlphabetLetter('Ê', 'ê', hintKey: K.alphabetHintEe),
  AlphabetLetter('F', 'f'),
  AlphabetLetter('G', 'g'),
  AlphabetLetter('H', 'h'),
  AlphabetLetter('I', 'i', hintKey: K.alphabetHintI),
  AlphabetLetter('Î', 'î', hintKey: K.alphabetHintIi),
  AlphabetLetter('J', 'j'),
  AlphabetLetter('K', 'k'),
  AlphabetLetter('L', 'l'),
  AlphabetLetter('M', 'm'),
  AlphabetLetter('N', 'n'),
  AlphabetLetter('O', 'o'),
  AlphabetLetter('P', 'p'),
  AlphabetLetter('Q', 'q', hintKey: K.alphabetHintQ),
  AlphabetLetter('R', 'r'),
  AlphabetLetter('S', 's'),
  AlphabetLetter('Ş', 'ş'),
  AlphabetLetter('T', 't'),
  AlphabetLetter('U', 'u', hintKey: K.alphabetHintU),
  AlphabetLetter('Û', 'û', hintKey: K.alphabetHintUu),
  AlphabetLetter('V', 'v'),
  AlphabetLetter('W', 'w', hintKey: K.alphabetHintW),
  AlphabetLetter('X', 'x', hintKey: K.alphabetHintX),
  AlphabetLetter('Y', 'y'),
  AlphabetLetter('Z', 'z'),
];

/// [letter]i taşıyan, sesi olan örnek kelime.
///
/// Önce harfle BAŞLAYAN kelimeler aranır; yoksa (Kurmancîde kısa "i" ve
/// "u" sözcük başında hemen hiç yoktur) harfi İÇEREN kelimeye düşülür
/// ("min", "gul"). Sıra: alfabe dersinin kelimeleri önce, sonra kısa olan;
/// yalnız tek sözcüklü kayıtlar (ifade değil). Seçim belirleyicidir: aynı
/// harf her açılışta aynı örneği verir. Sesli kayıt yoksa `null`; ekran
/// harfi örneksiz gösterir (sessiz düğme çizilmez).
LearnerLexiconEntry? alphabetExampleFor(
  String letter,
  bool Function(String text) hasAudio,
) {
  List<LearnerLexiconEntry> pick(bool Function(String lower) matches) => [
    for (final entry in LearnerLexicon.entries)
      if (!entry.termKu.contains(' ') &&
          matches(entry.termKu.toLowerCase()) &&
          hasAudio(entry.termKu))
        entry,
  ];
  var candidates = pick((lower) => lower.startsWith(letter));
  if (candidates.isEmpty) candidates = pick((lower) => lower.contains(letter));
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) {
    // 1–2 harfli kayıtlar çoğu kez edat/ek ("Bi", "Ji", "Ya"): örnek olarak
    // zayıf, en sona.
    final short = (a.termKu.length < 3 ? 1 : 0).compareTo(
      b.termKu.length < 3 ? 1 : 0,
    );
    if (short != 0) return short;
    final lesson = (a.sourceId == 'alphabet_1' ? 0 : 1).compareTo(
      b.sourceId == 'alphabet_1' ? 0 : 1,
    );
    if (lesson != 0) return lesson;
    final length = a.termKu.length.compareTo(b.termKu.length);
    if (length != 0) return length;
    return a.id.compareTo(b.id);
  });
  return candidates.first;
}
