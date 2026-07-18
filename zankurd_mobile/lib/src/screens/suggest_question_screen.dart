import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Ji kerema xwe kategoriyekê hilbijêre.',
              'Lütfen bir kategori seç.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.repository.submitSuggestedQuestion(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.s(
                'Şaşiyek çêbû. Ji kerema xwe dîsa biceribîne.',
                'Bir hata oluştu. Lütfen tekrar deneyin.',
              ),
            ),
          ),
        );
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
      appBar: AppBar(title: Text(ku ? 'Pirs Pêşniyar Bike' : 'Soru Öner')),
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
                  ku
                      ? 'ZanKurd pirsên te pêşniyar dike'
                      : 'ZanKurd\'a soru öner',
                  style: AppTypography.heading1.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ku
                      ? 'Ji bo dewlemendkirina pirsan, pirsa xwe ya nû ji me re bişîne.'
                      : 'Soru havuzunu zenginleştirmek için yeni sorunu bizimle paylaş.',
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Kategori seçimi
                _SectionHeader(
                  icon: Icons.category_outlined,
                  color: AppTheme.playCyan,
                  title: ku ? 'Kategorî' : 'Kategori',
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
                    hint: Text(
                      ku ? 'Kategoriyekê hilbijêre...' : 'Bir kategori seç...',
                    ),
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
                        return ku ? 'Kategorî pêwîst e' : 'Kategori zorunlu';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // Soru metni
                _SectionHeader(
                  icon: Icons.help_outline_rounded,
                  color: AppTheme.playPink,
                  title: ku ? 'Pirs (Kurmancî)' : 'Soru (Kurmancî)',
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _promptController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: ku ? 'Pirsa xwe binivîse...' : 'Soruyu yaz...',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return ku ? 'Pirs vala nabe' : 'Soru boş olamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // Cevaplar
                _SectionHeader(
                  icon: Icons.list_alt_rounded,
                  color: AppTheme.correct,
                  title: ku ? 'Bersiv' : 'Cevaplar',
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
                  icon: Icons.check_circle_outline,
                  color: AppTheme.gold,
                  title: ku ? 'Bersiva Rast Hilbijêre' : 'Doğru Cevabı Seç',
                ),
                const SizedBox(height: AppSpacing.xs),
                AppPanel(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['A', 'B', 'C', 'D'].map((letter) {
                      final selected = _correctOption == letter;
                      final idx = letter.codeUnitAt(0) - 65;
                      final color = AppTheme.answerOptionColors[idx];
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
                              color: selected
                                  ? color
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
                  icon: Icons.lightbulb_outline,
                  color: AppTheme.violet,
                  title: ku ? 'Şîrove (Vebijarkî)' : 'Açıklama (İsteğe bağlı)',
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _explanationController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: ku
                        ? 'Çima ev bersiv rast e?'
                        : 'Bu cevap neden doğru?',
                  ),
                ),
                const SizedBox(height: AppSpacing.cardGap),

                // Zorluk seviyesi
                _SectionHeader(
                  icon: Icons.speed_rounded,
                  color: AppTheme.brandGreen,
                  title: ku
                      ? 'Astê Zehmetiyê: $_difficulty'
                      : 'Zorluk Seviyesi: $_difficulty',
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
                          color: Colors.green,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: _difficulty.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: AppTheme.brandGreen,
                          label: '$_difficulty',
                          onChanged: (value) {
                            setState(() => _difficulty = value.round());
                          },
                        ),
                      ),
                      Text(
                        '5',
                        style: AppTypography.caption.copyWith(
                          color: Colors.red,
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
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      ku ? 'Pirsê Bişîne' : 'Soruyu Gönder',
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
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Pirs Pêşniyar Bike' : 'Soru Öner')),
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
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      ku
                          ? 'Spas ji bo pêşniyara te!'
                          : 'Öneriniz için teşekkürler!',
                      textAlign: TextAlign.center,
                      style: AppTypography.heading1.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      ku
                          ? 'Pêşniyara te hat hildan. Piştî pejirandinê, tu yê 50 zêr û xelata Rozeta Nivîskar qezenc bikî!'
                          : 'Soru öneriniz alındı! Onaylandıktan sonra 50 jeton ve özel Yazar Rozeti kazanacaksınız!',
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
                        child: Text(ku ? 'Vegere' : 'Geri Dön'),
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
          child: Icon(icon, color: color, size: 18),
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
        hintText: '$label) ${ku ? 'Bersiv' : 'Cevap'}',
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
              color: isCorrect ? AppTheme.correct : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        suffixIcon: isCorrect
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.correct,
                  size: 22,
                ),
              )
            : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '${ku ? 'Bersiv' : 'Cevap'} $label ${ku ? 'pêwîst e' : 'zorunlu'}';
        }
        return null;
      },
    );
  }
}
