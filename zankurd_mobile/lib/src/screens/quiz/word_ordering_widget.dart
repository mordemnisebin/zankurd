import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final String? selectedAnswer;

  @override
  State<WordOrderingWidget> createState() => _WordOrderingWidgetState();
}

class _WordOrderingWidgetState extends State<WordOrderingWidget> {
  late List<String> _availableWords;
  final List<String> _selectedWords = [];

  @override
  void initState() {
    super.initState();
    _initWords();
  }

  void _initWords() {
    // Soru içerisindeki kelimelerden karıştırılmış bir havuz oluştur.
    final rawWords = widget.question.answers;
    _availableWords = List<String>.from(rawWords)..shuffle();
  }

  void _selectWord(int index) {
    if (widget.disabled) return;
    HapticFeedback.lightImpact();
    setState(() {
      final word = _availableWords.removeAt(index);
      _selectedWords.add(word);
    });
  }

  void _unselectWord(int index) {
    if (widget.disabled) return;
    HapticFeedback.lightImpact();
    setState(() {
      final word = _selectedWords.removeAt(index);
      _availableWords.add(word);
    });
  }

  void _submit() {
    if (_selectedWords.isEmpty || widget.disabled) return;
    final constructedAnswer = _selectedWords.join(' ');
    widget.onAnswerSubmitted(constructedAnswer);
  }

  @override
  Widget build(BuildContext context) {
    final isKu = LangContext(context).isKu;
    final surface = AppTheme.surfaceColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              width: 1.0,
            ),
          ),
          child: _selectedWords.isEmpty
              ? Center(
                  child: Text(
                    isKu
                        ? 'Peyvan hilbijêre ku hevokê çêbikî'
                        : 'Cümleyi oluşturmak için kelimeleri seç',
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: List.generate(_selectedWords.length, (index) {
                    final word = _selectedWords[index];
                    return ActionChip(
                      label: Text(
                        word,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      backgroundColor: AppTheme.brand.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                        side: BorderSide(
                          color: AppTheme.brand.withValues(alpha: 0.5),
                        ),
                      ),
                      onPressed: widget.disabled
                          ? () {}
                          : () => _unselectWord(index),
                    );
                  }),
                ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ============ KELİME HAVUZU (AVAILABLE WORDS) ============
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: List.generate(_availableWords.length, (index) {
            final word = _availableWords[index];
            return ActionChip(
              label: Text(
                word,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppTheme.surfaceHiColor(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.badge),
                side: BorderSide(
                  color: AppTheme.borderColor(context).withValues(alpha: 0.4),
                ),
              ),
              onPressed: widget.disabled ? () {} : () => _selectWord(index),
            );
          }),
        ),

        const SizedBox(height: AppSpacing.md),

        // ============ KONTROL ET / GÖNDER BUTONU ============
        if (!widget.disabled)
          BouncingButton(
            onPressed: _selectedWords.isNotEmpty ? _submit : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _selectedWords.isNotEmpty
                    ? AppTheme.primaryCtaColor(context)
                    : AppTheme.borderColor(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                isKu ? 'Kontrol bike' : 'Kontrol et',
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
    );
  }
}
