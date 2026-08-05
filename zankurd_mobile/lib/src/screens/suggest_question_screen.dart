import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Kullanıcıların yeni soru önerebileceği ekran.
///
/// Önerilen sorular Supabase 'suggested_questions' tablosuna kaydedilir,
/// onaylandıktan sonra soru havuzuna eklenir.
class SuggestQuestionScreen extends StatefulWidget {
  const SuggestQuestionScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<SuggestQuestionScreen> createState() => _SuggestQuestionScreenState();
}

class _SuggestQuestionScreenState extends State<SuggestQuestionScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  bool _submitted = false;

  String? _selectedCategory;
  final _promptController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();
  final _explanationController = TextEditingController();
  String _correctOption = 'A';
  int _difficulty = 3;

  @override
  void dispose() {
    _promptController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.pleasePickCategory))));
      return;
    }

    setState(() => _submitting = true);
    try {
      final submitted = await widget.repository.submitSuggestedQuestion(
        category: _selectedCategory!,
        prompt: _promptController.text.trim(),
        optionA: _optionAController.text.trim(),
        optionB: _optionBController.text.trim(),
        optionC: _optionCController.text.trim(),
        optionD: _optionDController.text.trim(),
        correctOption: _correctOption,
        explanation: _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
        difficulty: _difficulty,
      );
      if (!submitted) {
        if (mounted) {
          setState(() => _submitting = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.t(K.genericError))));
        }
        return;
      }
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitted = true;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'suggested_question_submit');
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.genericError))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final categories = widget.repository.categories;

    if (_submitted) {
      return _buildSuccessView(context);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      // Başlık gövdedeki kimlik bloğunda zaten var ("ZanKurd'a soru öner");
      // AppBar'da tekrarı ekranın tepesinde iki başlık gösteriyordu.
      appBar: AppBar(),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xs,
                AppSpacing.page,
                AppSpacing.lg,
              ),
              children: [
                // Başlık
                Text(
                  context.t(K.suggestHeader),
                  style: AppTypography.heading1.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t(K.suggestIntro),
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Kategori seçimi
                _SectionHeader(
                  icon: AppIcons.tableCells,
                  color: AppTheme.playCyan,
                  title: context.t(K.categoryLabel),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppPanel(
                  padding: EdgeInsets.zero,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    hint: Text(context.t(K.categoryPick)),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(CategoryNames.localized(cat, ku)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return context.t(K.categoryRequired);
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // Soru metni
                _SectionHeader(
                  icon: AppIcons.circleQuestion,
                  color: AppTheme.brand,
                  title: context.t(K.questionKurmanci),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _promptController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: context.t(K.questionHint),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.t(K.questionEmpty);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // Cevaplar
                _SectionHeader(
                  icon: AppIcons.listCheck,
                  color: AppTheme.correct,
                  title: context.t(K.answersLabel),
                ),
                const SizedBox(height: AppSpacing.xs),
                _AnswerField(
                  controller: _optionAController,
                  label: 'A',
                  color: AppTheme.answerOptionColors[0],
                  isCorrect: _correctOption == 'A',
                  ku: ku,
                ),
                const SizedBox(height: AppSpacing.xs),
                _AnswerField(
                  controller: _optionBController,
                  label: 'B',
                  color: AppTheme.answerOptionColors[1],
                  isCorrect: _correctOption == 'B',
                  ku: ku,
                ),
                const SizedBox(height: AppSpacing.xs),
                _AnswerField(
                  controller: _optionCController,
                  label: 'C',
                  color: AppTheme.answerOptionColors[2],
                  isCorrect: _correctOption == 'C',
                  ku: ku,
                ),
                const SizedBox(height: AppSpacing.xs),
                _AnswerField(
                  controller: _optionDController,
                  label: 'D',
                  color: AppTheme.answerOptionColors[3],
                  isCorrect: _correctOption == 'D',
                  ku: ku,
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // Doğru cevap seçici
                _SectionHeader(
                  icon: AppIcons.circleCheck,
                  color: AppTheme.gold,
                  title: context.t(K.pickCorrectAnswer),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppPanel(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['A', 'B', 'C', 'D'].map((letter) {
                      final selected = _correctOption == letter;
                      // Seçili daire `answerOptionColors`tan renk alıyordu;
                      // o dizi quizde bilerek nötr griye çekilmiştir, çünkü
                      // orada renk cevabı ele verir. Burada durum tersi:
                      // yazar **doğru cevabı beyan ediyor**, sızıntı yok.
                      // Nötr gri seçili hâli pasif gösteriyordu; doğru renk
                      // "doğru" yeşilidir (2026-07-27).
                      const color = AppTheme.correct;
                      return GestureDetector(
                        onTap: () => setState(() => _correctOption = letter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 60,
                          height: 60,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? color.withValues(alpha: 0.18)
                                : Colors.transparent,
                            border: Border.all(
                              color: selected
                                  ? color
                                  : AppTheme.borderColor(context),
                              width: selected ? 2.5 : 1.5,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            letter,
                            style: AppTypography.heading2.copyWith(
                              // Seçili dairede harf, kendi renginin %18'lik
                              // zeminine yazılıyordu: 3.71:1 (2026-07-27).
                              color: selected
                                  ? AppColors.onAccentTint(
                                      context,
                                      color,
                                      tintAlpha: 0.18,
                                    )
                                  : AppTheme.textMutedColor(context),
                              fontSize: 22,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // Açıklama (isteğe bağlı)
                _SectionHeader(
                  icon: AppIcons.lightbulb,
                  color: AppTheme.violet,
                  title: context.t(K.explanationOptional),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _explanationController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: context.t(K.explanationHint),
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // Zorluk seviyesi
                _SectionHeader(
                  icon: AppIcons.gaugeHigh,
                  color: AppTheme.brand,
                  title: context.t(K.difficultyWithValue, {
                    'level': '$_difficulty',
                  }),
                ),
                const SizedBox(height: AppSpacing.xs),
                AppPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '1',
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.correct,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Semantics(
                          label: context.t(K.difficultyLabel),
                          value: '$_difficulty / 5',
                          slider: true,
                          child: Slider(
                            value: _difficulty.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            activeColor: AppTheme.brand,
                            label: '$_difficulty',
                            onChanged: (value) {
                              setState(() => _difficulty = value.round());
                            },
                          ),
                        ),
                      ),
                      Text(
                        '5',
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.wrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Gönder butonu
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(AppIcons.paperPlane),
                    label: Text(
                      context.t(K.submitQuestion),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.t(K.suggestTitle))),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.page),
              child: AppPanel(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.correctGradient,
                        boxShadow: AppTheme.elevatedShadow(AppTheme.correct),
                      ),
                      child: const Icon(
                        AppIcons.check,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      context.t(K.thanksForSuggestion),
                      textAlign: TextAlign.center,
                      style: AppTypography.heading1.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.t(K.suggestionReceived),
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textSubColor(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t(K.goBack)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bölüm başlığı yardımcı widget'ı.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.title,
  });

  final IconData icon;
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(
            icon,
            color: AppColors.onAccentTint(context, color),
            size: 18,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Tek bir cevap alanı (A/B/C/D).
class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.controller,
    required this.label,
    required this.color,
    required this.isCorrect,
    required this.ku,
  });

  final TextEditingController controller;
  final String label;
  final Color color;
  final bool isCorrect;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: '$label) ${context.t(K.answerLabel)}',
        prefixIcon: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCorrect
                ? AppTheme.correct.withValues(alpha: 0.18)
                : color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: isCorrect
                ? Border.all(
                    color: AppTheme.correct.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.bodyLarge.copyWith(
              // Harf, kendi renginin %14'lük karosunun içine yazılıyordu:
              // koyu temada 1.93:1 — B, C ve D harfleri neredeyse
              // görünmüyordu, yalnız seçili olan okunuyordu (2026-07-27).
              // Şık renkleri bilerek nötrdür; `onAccentTint` yalnız
              // açıklığı kaydırır, nötrlüğü bozmaz.
              color: AppColors.onAccentTint(
                context,
                isCorrect ? AppTheme.correct : color,
              ),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        suffixIcon: isCorrect
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Icon(
                  AppIcons.circleCheck,
                  color: AppColors.readableAccent(context, AppTheme.correct),
                  size: 22,
                ),
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '${context.t(K.answerLabel)} $label ${context.t(K.requiredSuffix)}';
        }
        return null;
      },
    );
  }
}
