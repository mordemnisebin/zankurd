import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/strings.dart';
import '../../l10n/lang.dart';
import '../../models/quiz_question.dart';
import '../../widgets/sahne/sahne.dart';

/// Etkileşimli Cümle Kurma (Word Ordering / Rêzkirina Hevokan) bileşeni.
/// Kullanıcının kelime parçalarını seçerek doğru cümle dizilimini oluşturmasını sağlar.
///
/// Şahnê: cümle alanı Perde (`s1`) üstünde L pahlı yüzeydir; havuzdaki
/// kelimeler Kulis (`s2`), cümleye alınanlar Ray (`s3`) tonunda M pahlı
/// 48'lik karolardır — seçim renkle değil tonla ve yerle söylenir.
/// "Kontrol et" cevaptan önce ekranın tek birincil eylemidir (temanın
/// Agir `FilledButton`ı).
class WordOrderingWidget extends StatefulWidget {
  const WordOrderingWidget({
    super.key,
    required this.question,
    required this.onAnswerSubmitted,
    required this.disabled,
    this.selectedAnswer,
  });

  final QuizQuestion question;
  final ValueChanged<String> onAnswerSubmitted;
  final bool disabled;

  /// Cevap verildikten sonra ekranda kalan kullanıcı cümlesi. Soru
  /// yanıtlandığında (`disabled`) kelime havuzu gizlenir ve yalnızca bu
  /// cümle gösterilir.
  final String? selectedAnswer;

  @override
  State<WordOrderingWidget> createState() => _WordOrderingWidgetState();
}

class _WordOrderingWidgetState extends State<WordOrderingWidget> {
  /// Havuzdaki kelimeler. Kelimeler tekrar edebildiği için (ör. "nan ... nan")
  /// dizin değil, `_Token` kimliği ile taşınır.
  late List<_Token> _availableWords;
  final List<_Token> _selectedWords = [];

  /// Havuzun şimdiye dek ölçülen EN BÜYÜK yüksekliği.
  ///
  /// Havuz boşaldıkça `Wrap` küçülür ve altındaki "Kontrol et" düğmesi
  /// yukarı zıplardı: oyuncu son kelimeye dokunur dokunmaz hedef parmağının
  /// altından kayardı (2026-10-07 simülatör QA'sı). Havuz alanı ilk
  /// yüksekliğinde tutulur; yeni soruda sıfırlanır.
  double _poolMinHeight = 0;
  final GlobalKey _poolKey = GlobalKey();

  void _measurePool() {
    final box = _poolKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    if (box.size.height > _poolMinHeight + 0.5 && mounted) {
      setState(() => _poolMinHeight = box.size.height);
    }
  }

  @override
  void initState() {
    super.initState();
    _initWords();
  }

  @override
  void didUpdateWidget(covariant WordOrderingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Quiz bir sonraki soruya geçtiğinde Flutter aynı State nesnesini yeniden
    // kullanır. Bu sıfırlama olmadan önceki sorunun kelimeleri ekranda kalır.
    if (oldWidget.question.id != widget.question.id) {
      _selectedWords.clear();
      _poolMinHeight = 0;
      _initWords();
    }
  }

  void _initWords() {
    final rawWords = widget.question.answers;
    final tokens = <_Token>[
      for (final (index, word) in rawWords.indexed) _Token(index, word),
    ]..shuffle();

    // Karıştırma tesadüfen doğru sırayı verirse soru kendini ele verir;
    // en az bir kelime yer değiştirene kadar kaydır.
    if (tokens.length > 1 && _isOriginalOrder(tokens)) {
      tokens.insert(0, tokens.removeLast());
    }
    _availableWords = tokens;
  }

  bool _isOriginalOrder(List<_Token> tokens) {
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].index != i) return false;
    }
    return true;
  }

  void _selectWord(_Token token) {
    if (widget.disabled) return;
    HapticFeedback.lightImpact();
    setState(() {
      _availableWords.remove(token);
      _selectedWords.add(token);
    });
  }

  void _unselectWord(_Token token) {
    if (widget.disabled) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedWords.remove(token);
      // Kelime havuzdaki özgün karışık konumuna geri döner; sona eklenirse
      // kullanıcı her geri alışta farklı bir düzenle karşılaşır.
      final insertAt = _availableWords.indexWhere(
        (t) => t.shuffleRank > token.shuffleRank,
      );
      if (insertAt == -1) {
        _availableWords.add(token);
      } else {
        _availableWords.insert(insertAt, token);
      }
    });
  }

  void _submit() {
    if (_selectedWords.isEmpty || widget.disabled) return;
    widget.onAnswerSubmitted(_selectedWords.map((t) => t.word).join(' '));
  }

  @override
  Widget build(BuildContext context) {
    final isKu = LangContext(context).isKu;
    final t = SahneTokens.of(context);
    final answered = widget.disabled;

    // Cevap verildikten sonra kullanıcının gönderdiği cümle gösterilir;
    // yeniden düzenlemeye çalışmasın diye havuz ve buton kaldırılır.
    final submitted = answered ? widget.selectedAnswer : null;
    if (!answered) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measurePool());
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ============ SEÇİLEN KELİMELERİN CÜMLE ALANI ============
        // 88: tek satır çip (50) + dolgu (32) = 82; eskiden 80'di ve ilk
        // kelime seçilince alan 2 dp uzayıp düğmeyi kaydırıyordu.
        Container(
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(SahneSpace.x4),
          decoration: ShapeDecoration(
            color: t.s1,
            shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
          ),
          child: submitted != null
              ? Text(
                  submitted,
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                )
              : _selectedWords.isEmpty
              ? Center(
                  child: Text(
                    Tr.forKu(K.cumleyiOlusturmakIcinKelimeleri, isKu),
                    textAlign: TextAlign.center,
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                )
              : Semantics(
                  label: Tr.forKu(K.kurdugunCumle, isKu),
                  value: _selectedWords.map((t) => t.word).join(' '),
                  child: Wrap(
                    spacing: SahneSpace.x2,
                    runSpacing: SahneSpace.x2,
                    children: [
                      for (final token in _selectedWords)
                        _WordChip(
                          word: token.word,
                          selected: true,
                          semanticHint: Tr.forKu(K.cumledenCikar, isKu),
                          onPressed: answered
                              ? null
                              : () => _unselectWord(token),
                        ),
                    ],
                  ),
                ),
        ),

        if (!answered) ...[
          const SizedBox(height: SahneSpace.x4),

          // ============ KELİME HAVUZU (AVAILABLE WORDS) ============
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: _poolMinHeight),
            child: Wrap(
              key: _poolKey,
              alignment: WrapAlignment.center,
              spacing: SahneSpace.x2,
              runSpacing: SahneSpace.x2,
              children: [
                for (final token in _availableWords)
                  _WordChip(
                    word: token.word,
                    selected: false,
                    semanticHint: Tr.forKu(K.cumleyeEkle, isKu),
                    onPressed: () => _selectWord(token),
                  ),
              ],
            ),
          ),

          const SizedBox(height: SahneSpace.x4),

          // ============ KONTROL ET / GÖNDER BUTONU ============
          SahnePressSink(
            enabled: _selectedWords.isNotEmpty,
            child: FilledButton(
              onPressed: _selectedWords.isNotEmpty ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(Tr.forKu(K.kontrolEt, isKu)),
            ),
          ),
        ],
      ],
    );
  }
}

/// Havuzdaki tek bir kelime. Aynı kelime cümlede birden çok kez geçebildiği
/// için kimlik dizinden değil bu nesneden gelir.
class _Token {
  _Token(this.index, this.word) : shuffleRank = _nextRank++;

  static int _nextRank = 0;

  /// Doğru cümledeki özgün sıra (yalnızca karıştırma kontrolü için).
  final int index;
  final String word;

  /// Havuzdaki karışık konumunu koruyan sıra numarası.
  final int shuffleRank;
}

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.selected,
    required this.semanticHint,
    required this.onPressed,
  });

  final String word;
  final bool selected;
  final String semanticHint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Havuz kelimesi Kulis (`s2`), cümledeki kelime Ray (`s3`): seçim tonla
    // ve yerle söylenir. Gündüzde 1 px kenar, gecede kenarsız (katman tonla
    // ayrılır). Eski turuncu yarı saydam seçim tonu palet dışıydı.
    final t = SahneTokens.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      hint: semanticHint,
      child: SahnePressSink(
        enabled: enabled,
        child: SahneTappable(
          shape: SahneShape.withSide(SahneShape.m, t.edge, width: 1),
          color: selected ? t.s3 : t.s2,
          onTap: onPressed,
          // `alignment` VERİLMEZ: gevşek kısıtta hizalama verilen kutu
          // satırın tamamına yayılır ve her kelime tek başına bir satır
          // kaplar (Wrap işlevsiz kalır).
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SahneSpace.x4,
                vertical: SahneSpace.x2,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  word,
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
