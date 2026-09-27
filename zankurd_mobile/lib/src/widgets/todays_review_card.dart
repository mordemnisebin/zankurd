import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../data/mistake_store.dart';
import '../data/zankurd_repository.dart';
import '../models/quiz_question.dart';
import '../screens/quiz_screen.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// "Bugünkü Tekrarlar" kartı — SM-2 aralıklı tekrar sisteminin ürün yüzü.
///
/// Yalnızca [MistakeStore.readyIds] içindeki (tekrar zamanı gelmiş) soruları
/// sayar. Hazır tekrar varsa dokunulabilir bir kart, yoksa sakin bir
/// "tamamlandı" durumu gösterir. Karta dokununca yalnız hazır sorularla,
/// öğrenme deneyiminde (sayaç/skor/joker yok) bir tekrar quizi açılır.
class TodaysReviewCard extends StatefulWidget {
  const TodaysReviewCard({
    required this.repository,
    required this.isKu,
    this.onStartReview,
    this.refreshSignal,
    super.key,
  });

  final ZanKurdRepository repository;
  final bool isKu;

  /// Test/özelleştirme için: verilirse quiz açmak yerine bu çağrılır.
  final void Function(List<QuizQuestion> questions)? onStartReview;

  /// Sekme yeniden seçildiğinde hazır sayısını tazelemek için.
  final Listenable? refreshSignal;

  @override
  State<TodaysReviewCard> createState() => _TodaysReviewCardState();
}

class _TodaysReviewCardState extends State<TodaysReviewCard> {
  int _readyCount = 0;
  bool _loading = true;

  static const _accent = AppTheme.playGreen;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.refreshSignal?.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_refresh);
    super.dispose();
  }

  /// Gerçekten AÇILABİLECEK tekrar soruları.
  ///
  /// Sayı ile eylem eskiden iki ayrı kaynaktan besleniyordu: rozet
  /// `store.readyCount` (bütün hazır kimlikler), başlatma ise
  /// `repository.questions` ile kesişim. Çevrimiçi maçlarda yanlış
  /// yapılan sorular veritabanı UUID'siyle kaydediliyor
  /// (`get_room_questions` satırın `id`sini döndürür); paketli bankanın
  /// kimlikleri ise `offline_0005` biçiminde. `_trackMistake` çevrimiçi
  /// yolda da çalıştığı için bu UUID'ler yanlış defterine giriyor ama
  /// hiçbir zaman çözümlenemiyordu.
  ///
  /// Sonuç: kart sıfırdan büyük bir rozet gösteriyor, dokunuş ise
  /// `questions.isEmpty` dalına düşüp SESSİZCE hiçbir şey yapmıyordu —
  /// Öğren sekmesinin başlık kartı, çevrimiçi 1v1 oynayan her kullanıcıda
  /// kalıcı olarak tepkisiz kalıyordu (2026-08-06 denetimi).
  ///
  /// Artık ikisi de aynı listeden besleniyor: sayı neyi vaat ediyorsa
  /// dokunuş onu açar.
  List<QuizQuestion> _launchable(Set<String> readyIds) => widget
      .repository
      .questions
      .where((q) => readyIds.contains(q.id))
      .toList();

  Future<void> _refresh() async {
    try {
      final store = await MistakeStore.load();
      final launchable = _launchable(store.readyIds).length;
      if (mounted) {
        setState(() {
          _readyCount = launchable;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'todays_review_card');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startReview() async {
    final store = await MistakeStore.load();
    final questions = _launchable(store.readyIds);
    if (questions.isEmpty) return;

    final onStart = widget.onStartReview;
    if (onStart != null) {
      onStart(questions);
      return;
    }

    if (!mounted) return;
    final ku = widget.isKu;
    final room = widget.repository.createRoom().copyWith(
      name: Tr.forKu(K.todaysReviews, ku),
      questionCount: questions.length,
    );
    await Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: room,
          questions: questions,
          practice: true,
          enableTimer: false,
          experience: QuizExperience.learning,
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final ku = widget.isKu;
    return _readyCount > 0
        ? _buildReady(context, ku)
        : _buildEmpty(context, ku);
  }

  Widget _buildReady(BuildContext context, bool ku) {
    final semanticLabel = [
      Tr.forKu(K.todaysReviews, ku),
      Tr.forKu(K.todaysReviewsCount, ku, {'count': '$_readyCount'}),
      Tr.forKu(K.strengthenMemory, ku),
    ].join('. ');
    return Semantics(
      key: const ValueKey('todays-review-card'),
      container: true,
      button: true,
      enabled: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: _startReview,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _startReview,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            key: const ValueKey('todays-review-status-row'),
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: AppSpacing.xs,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.iconTileBg(context, _accent),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                    child: Icon(
                      AppIcons.arrowsRotate,
                      color: AppColors.readableAccent(context, _accent),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Tr.forKu(K.todaysReviews, ku),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.readableAccent(context, _accent),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          Tr.forKu(K.todaysReviewsCount, ku, {
                            'count': '$_readyCount',
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    // a11y-tap-target: noninteractive — 52px InkWell içindeki sayı rozeti.
                    constraints: const BoxConstraints(minWidth: 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.iconTileBg(context, _accent),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '$_readyCount',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.readableAccent(context, _accent),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    AppIcons.chevronRight,
                    size: 16,
                    color: AppTheme.textMutedColor(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool ku) {
    final title = Tr.forKu(K.reviewsDone, ku);
    final detail = Tr.forKu(K.noReviewsToday, ku);
    return Semantics(
      key: const ValueKey('todays-review-empty'),
      label: '$title. $detail',
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey('todays-review-status-row'),
        padding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: AppSpacing.xs,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.iconTileBg(context, _accent),
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Icon(
                  AppIcons.circleCheck,
                  color: AppColors.readableAccent(context, _accent),
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
