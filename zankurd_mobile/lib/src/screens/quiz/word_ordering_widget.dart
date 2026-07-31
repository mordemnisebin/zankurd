import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/strings.dart';
import '../../l10n/lang.dart';
import '../../models/quiz_question.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bouncing_button.dart';

/// Etkileşimli Cümle Kurma (Word Ordering / Rêzkirina Hevokan) bileşeni.
/// Kullanıcının kelime parçalarını seçerek doğru cümle dizilimini oluşturmasını sağlar.
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
    final surface = AppTheme.surfaceColor(context);
    final answered = widget.disabled;

    // Cevap verildikten sonra kullanıcının gönderdiği cümle gösterilir;
    // yeniden düzenlemeye çalışmasın diye havuz ve buton kaldırılır.
    final submitted = answered ? widget.selectedAnswer : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ============ SEÇİLEN KELİMELERİN CÜMLE ALANI ============
        Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppTheme.borderColor(context).withValues(alpha: 0.5),
            ),
          ),
          child: submitted != null
              ? Text(
                  submitted,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                )
              : _selectedWords.isEmpty
              ? Center(
                  child: Text(
                    Tr.forKu(K.cumleyiOlusturmakIcinKelimeleri, isKu),
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                )
              : Semantics(
                  label: Tr.forKu(K.kurdugunCumle, isKu),
                  value: _selectedWords.map((t) => t.word).join(' '),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
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
          const SizedBox(height: AppSpacing.md),

          // ============ KELİME HAVUZU (AVAILABLE WORDS) ============
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
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

          const SizedBox(height: AppSpacing.md),

          // ============ KONTROL ET / GÖNDER BUTONU ============
          BouncingButton(
            onPressed: _selectedWords.isNotEmpty ? _submit : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _selectedWords.isNotEmpty
                    ? AppTheme.primaryCtaColor(context)
                    : AppColors.disabledSurface(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                Tr.forKu(K.kontrolEt, isKu),
                style: AppTypography.bodyLarge.copyWith(
                  color: _selectedWords.isNotEmpty
                      ? Colors.white
                      : AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    // Açık temada `surfaceHi` (#FBF8F3) kart yüzeyiyle (#FFFFFF) neredeyse
    // aynıydı: dokunulabilir kelimeler arka plandan ayırt edilemiyordu.
    // Havuz chip'i artık marka renginin düşük yoğunluklu bir tonunu ve tam
    // opak bir kenarlık kullanır.
    final background = selected
        ? AppTheme.brand.withValues(alpha: 0.22)
        : AppTheme.surfaceHiColor(context);
    final border = selected
        ? AppTheme.brand.withValues(alpha: 0.65)
        : AppTheme.borderColor(context);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      hint: semanticHint,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.badge),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.badge),
          // `alignment` VERİLMEZ: Container'a hizalama verildiğinde gevşek
          // kısıt altında mevcut genişliğin tamamına yayılır ve her kelime
          // tek başına bir satır kaplar (Wrap işlevsiz kalır).
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.badge),
              border: Border.all(color: border, width: selected ? 1.5 : 1.0),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                word,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
