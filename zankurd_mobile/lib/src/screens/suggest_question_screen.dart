import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../utils/error_reporter.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
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
    final t = SahneTokens.of(context);
    final categories = widget.repository.categories;

    if (_submitted) {
      return _buildSuccessView(context);
    }

    // 2026-09-29 Şahnê: B iskeleti — sayfa adı çubukta, gövdede tekrar
    // edilmez. Alanlar üç yüzey kartında toplanır (girdiler Perde kartının
    // içinde Kulis tonunda durur); renkli ikon karolu alan başlıkları
    // yerine girdi alanlarının etiket dili. Tek birincil eylem: Gönder.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.suggestTitle))),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SahneSpace.page,
              SahneSpace.x2,
              SahneSpace.page,
              SahneSpace.x8,
            ),
            children: [
              Text(
                context.t(K.suggestIntro),
                style: SahneType.body.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x4),
              SahneSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldLabel(context.t(K.categoryLabel)),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      isExpanded: true,
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
                    const SizedBox(height: SahneSpace.x4),
                    _FieldLabel(context.t(K.questionKurmanci)),
                    TextFormField(
                      controller: _promptController,
                      maxLines: 3,
                      style: SahneType.body.copyWith(color: t.tx),
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
                  ],
                ),
              ),

              SahneSectionHeader(title: context.t(K.answersLabel)),
              SahneSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, letter) in const [
                      'A',
                      'B',
                      'C',
                      'D',
                    ].indexed) ...[
                      if (i > 0) const SizedBox(height: SahneSpace.x2),
                      _AnswerField(
                        controller: [
                          _optionAController,
                          _optionBController,
                          _optionCController,
                          _optionDController,
                        ][i],
                        label: letter,
                        isCorrect: _correctOption == letter,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: SahneSpace.x4),
              _FieldLabel(context.t(K.pickCorrectAnswer)),
              // Yazar doğru cevabı BEYAN ediyor (quizdeki gibi cevabı
              // ele veren bir renk değil): seçim rayının sığan
              // çeşidi, seçili harf öğrenme tonunda ve ekran
              // okuyucuda "seçili". 48: dokunma kılavuzu. Ray kartın
              // DIŞINDA durur: seçili olmayan çip Perde (`s1`) tonundadır ve
              // Perde kartın içinde görünmez oluyordu.
              SizedBox(
                height: 48,
                child: SahneRail.fit(
                  children: [
                    for (final letter in const ['A', 'B', 'C', 'D'])
                      SahneRailChip(
                        label: letter,
                        selected: _correctOption == letter,
                        onTap: () => setState(() => _correctOption = letter),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: SahneSpace.cardGap),
              SahneSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FieldLabel(context.t(K.explanationOptional)),
                    TextFormField(
                      controller: _explanationController,
                      maxLines: 3,
                      style: SahneType.body.copyWith(color: t.tx),
                      decoration: InputDecoration(
                        hintText: context.t(K.explanationHint),
                      ),
                    ),
                    const SizedBox(height: SahneSpace.x4),
                    _FieldLabel(
                      context.t(K.difficultyWithValue, {
                        'level': '$_difficulty',
                      }),
                    ),
                    Row(
                      children: [
                        Text(
                          '1',
                          style: SahneType.captionStrong.copyWith(color: t.tx2),
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
                              label: '$_difficulty',
                              onChanged: (value) {
                                setState(() => _difficulty = value.round());
                              },
                            ),
                          ),
                        ),
                        Text(
                          '5',
                          style: SahneType.captionStrong.copyWith(color: t.tx2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SahneSpace.x6),

              // Gönder: ekranın tek birincil eylemi.
              SahneButton.primary(
                label: context.t(K.submitQuestion),
                icon: AppIcons.paperPlane,
                arrow: false,
                expand: true,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    final t = SahneTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.suggestTitle))),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SahneSpace.page),
            child: SahneSurfaceCard(
              padding: const EdgeInsets.all(SahneSpace.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Başarı bir durumdur: Rast tonlu elmas + ✓ + söz.
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: t.okTint,
                        shape: SahneShape.diamond(88),
                      ),
                      child: SizedBox.square(
                        dimension: 88,
                        child: Icon(AppIcons.check, size: 40, color: t.okTx),
                      ),
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x5),
                  Semantics(
                    header: true,
                    child: Text(
                      context.t(K.thanksForSuggestion),
                      textAlign: TextAlign.center,
                      style: SahneType.headline.copyWith(color: t.tx),
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  Text(
                    context.t(K.suggestionReceived),
                    textAlign: TextAlign.center,
                    style: SahneType.body.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x6),
                  SahneButton.primary(
                    label: context.t(K.goBack),
                    arrow: false,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Girdi alanının etiketi — [StyledInputField] ile aynı dil: kalın
/// açıklama, ikincil metin, altında 8.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x2),
      child: Text(
        text,
        style: SahneType.captionStrong.copyWith(
          color: SahneTokens.of(context).tx2,
        ),
      ),
    );
  }
}

/// Tek bir cevap alanı (A/B/C/D).
///
/// Şık harfi renksizdir (Ray karosu, birincil metin — quizdeki şık dili).
/// Yazarın doğru diye beyan ettiği şık Rast tonunu ve ✓ işaretini alır:
/// durum hiçbir zaman yalnız renkle verilmez.
class _AnswerField extends StatelessWidget {
  const _AnswerField({
    required this.controller,
    required this.label,
    required this.isCorrect,
  });

  final TextEditingController controller;
  final String label;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return TextFormField(
      controller: controller,
      style: SahneType.body.copyWith(color: t.tx),
      decoration: InputDecoration(
        hintText: '$label) ${context.t(K.answerLabel)}',
        prefixIcon: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: SahneSpace.x2,
            end: SahneSpace.x2,
          ),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: isCorrect ? t.okTint : t.s3,
              shape: SahneShape.m,
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Center(
                child: Text(
                  label,
                  style: SahneType.button.copyWith(
                    color: isCorrect ? t.okTx : t.tx,
                  ),
                ),
              ),
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 52),
        suffixIcon: isCorrect
            ? Icon(AppIcons.circleCheck, color: t.okTx, size: 22)
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
