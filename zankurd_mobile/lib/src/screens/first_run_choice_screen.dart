import 'package:flutter/material.dart';

import '../data/first_run_store.dart';
import '../data/learner_lexicon.dart';
import '../data/learning_goal_store.dart';
import '../data/learning_lesson_aliases.dart';
import '../data/placement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/learning_goal.dart';
import '../models/lesson.dart';
import '../services/guest_save_prompt.dart';
import '../services/placement_scoring.dart';
import '../theme/app_icons.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/learning_goal_chooser.dart';
import '../widgets/lexicon_speak_button.dart';
import '../widgets/sahne/sahne.dart';
import 'learning_screen.dart' show LessonDetailScreen;
import 'level_placement_screen.dart';

/// Tanıtımdan hemen sonraki iki soru: amaç ve "Kurmancî biliyor musun?".
///
/// ## Neden ayrı ekran
/// Eskiden amaç ayarlardaydı, seviye sınavı öğrenme sekmesinde küçük bir
/// şeritti ve ilk açılışta kimse ikisini görmüyordu: yeni oyuncu tanıtımdan
/// sonra boş bir ana ekrana düşüyordu (2026-11-03, ilk 5 dakika). Bu ekran
/// aynı mevcut parçaları ([LearningGoalChooser], [LevelPlacementScreen])
/// tek akışa dizer; yeni içerik üretmez.
///
/// Giriş seçenekleri (Apple/Google/misafir) bu ekranın SONRASINDA, olduğu gibi
/// görünür; hesap şartı yoktur. "Atla" bütün soruları varsayılanla geçer
/// (amaçsız, baştan) ve yine ilk derse iner.
class FirstRunChoiceScreen extends StatefulWidget {
  const FirstRunChoiceScreen({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  State<FirstRunChoiceScreen> createState() => _FirstRunChoiceScreenState();
}

class _FirstRunChoiceScreenState extends State<FirstRunChoiceScreen> {
  int _step = 0;
  LearningGoal? _goal;
  bool _finishing = false;

  Future<void> _finish({required bool placement}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await FirstRunStore.saveChoice(
      FirstRunPlan(goal: _goal, wantsPlacement: placement),
    );
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final goalStep = _step == 0;
    return SahneEntryScaffold(
      surfaceKey: const ValueKey('first-run-surface'),
      centerWhenAnchored: true,
      skip: SahneButton.text(
        key: const ValueKey('first-run-skip'),
        label: context.t(K.skip),
        arrow: false,
        onPressed: _finishing ? null : () => _finish(placement: false),
      ),
      title: goalStep
          ? context.t(K.learningGoalTitle)
          : context.t(K.onbKnowTitle),
      body: goalStep ? context.t(K.learningGoalHint) : null,
      content: goalStep
          ? Center(
              child: LearningGoalChooser(
                isKu: isKu,
                selected: _goal,
                showHeading: false,
                onSelected: (goal) => setState(() => _goal = goal),
              ),
            )
          : SahneButton.secondary(
              key: const ValueKey('first-run-know-some'),
              label: context.t(K.onbKnowSome),
              icon: AppIcons.compass,
              expand: true,
              onPressed: _finishing ? null : () => _finish(placement: true),
            ),
      primary: goalStep
          ? SahneButton.primary(
              key: const ValueKey('first-run-goal-next'),
              label: context.t(K.onbContinue),
              expand: true,
              onPressed: () => setState(() => _step = 1),
            )
          : SahneButton.primary(
              key: const ValueKey('first-run-know-beginner'),
              label: context.t(K.onbKnowBeginner),
              expand: true,
              onPressed: _finishing ? null : () => _finish(placement: false),
            ),
      secondary: goalStep
          ? null
          : SahneButton.text(
              key: const ValueKey('first-run-back'),
              label: context.t(K.backStep),
              arrow: false,
              onPressed: () => setState(() => _step = 0),
            ),
    );
  }
}

/// İlk dersin ardından gösterilen kısa "ilk başarı" anı: ilk öğrenilen
/// kelime, sesiyle, tek dokunuşla devam.
class FirstSuccessScreen extends StatelessWidget {
  const FirstSuccessScreen({required this.entry, super.key});

  final LearnerLexiconEntry entry;

  @override
  Widget build(BuildContext context) {
    return SahneEntryScaffold(
      surfaceKey: const ValueKey('first-success-surface'),
      centerWhenAnchored: true,
      title: context.t(K.onbFirstWordTitle),
      body: context.t(K.congrats),
      content: SahneStageCard(
        key: const ValueKey('first-success-card'),
        // Sahne kartı HER ZAMAN gecedir: yazı renkleri kartın İÇİNDEKİ
        // bağlamdan okunur (dışarıdan okununca koyu zeminde koyu yazı çıkar).
        child: Builder(
          builder: (context) {
            final t = SahneTokens.of(context);
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.termKu,
                        key: const ValueKey('first-success-word'),
                        style: SahneType.title.copyWith(color: t.tx),
                      ),
                      // Anlam Türkçedir; sözlük ekranlarıyla aynı biçimde her iki
                      // arayüz dilinde gösterilir.
                      const SizedBox(height: SahneSpace.x1),
                      Text(
                        entry.meaningTr,
                        style: SahneType.body.copyWith(color: t.tx2),
                      ),
                    ],
                  ),
                ),
                LexiconSpeakButton(text: entry.termKu),
              ],
            );
          },
        ),
      ),
      primary: SahneButton.primary(
        key: const ValueKey('first-success-continue'),
        label: context.t(K.onbContinue),
        expand: true,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// Akışın yürütücüsü: seviye sınavı -> uygun ilk ders -> ilk başarı -> hesap
/// önerisi. Hata ya da eksik veri hiçbir yerde kullanıcıyı kilitlemez; akış
/// sessizce kısalır ve kullanıcı normal ana ekranda kalır.
class FirstRunFlow {
  const FirstRunFlow._();

  /// Yol üstündeki ilk konu (öğrenme ekranının ilk sekmesi).
  static const firstCategory = 'everyday';

  /// Kabuk açıldığında bir kez çağrılır; bekleyen plan yoksa hiçbir şey yapmaz.
  static Future<void> run(
    BuildContext context,
    ZanKurdRepository repository,
  ) async {
    try {
      final plan = await FirstRunStore.consumeLaunch();
      if (plan == null || !context.mounted) return;
      // Mevcut ilerlemesi olan kullanıcı (yeniden kurulum + eşitleme) akışı
      // görmez.
      final completed = await repository.loadCompletedLessonIds();
      if (completed.isNotEmpty || !context.mounted) return;
      final goal = plan.goal;
      if (goal != null) {
        final store = await LearningGoalStore.load();
        await store.save(goal);
      }
      if (plan.wantsPlacement) {
        if (!context.mounted) return;
        await Navigator.of(
          context,
        ).push(AppRoute.to<void>(LevelPlacementScreen(repository: repository)));
      }
      if (!context.mounted) return;
      await openFirstLesson(context, repository);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'first_run_flow');
    }
  }

  /// Seviyeye uygun ilk dersi açar. Hiç ders bitirilmemişse ders sonrası
  /// "ilk başarı" anı ve (misafire) hesap önerisi de gelir. "Kelimelerim"
  /// boş durumundaki düğme de bunu kullanır.
  static Future<void> openFirstLesson(
    BuildContext context,
    ZanKurdRepository repository,
  ) async {
    try {
      final lessons = await repository.loadLessonsByCategory(firstCategory);
      if (lessons.isEmpty || !context.mounted) return;
      final level = (await PlacementStore.load()).level;
      final start = PlacementScoring.recommendedStartIndex(
        level,
        lessons.length,
      );
      final Lesson lesson = lessons[start];
      final before = await repository.loadCompletedLessonIds();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        AppRoute(
          page: LessonDetailScreen(lesson: lesson, repository: repository),
        ),
      );
      if (!context.mounted || before.isNotEmpty) return;
      final after = await repository.loadCompletedLessonIds();
      if (!after.contains(lesson.id) || !context.mounted) return;
      final entries = LearningLessonAliases.lexiconEntriesFor(
        lesson.slug,
        fallbackKey: lesson.id,
      );
      if (entries.isNotEmpty) {
        await Navigator.of(
          context,
        ).push(AppRoute.to<void>(FirstSuccessScreen(entry: entries.first)));
        if (!context.mounted) return;
      }
      await GuestSavePrompt.presentAfterFirstSuccess(context);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'first_run_first_lesson');
    }
  }
}
