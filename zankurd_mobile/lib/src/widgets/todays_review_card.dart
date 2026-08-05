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
    final surface = AppTheme.surfaceHiColor(context);
    return ClipRRect(
      key: const ValueKey('todays-review-card'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _startReview,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accent.withValues(alpha: 0.18),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        AppIcons.arrowsRotate,
                        color: AppColors.onAccentTint(context, _accent),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 13,
                                decoration: AppTheme.sectionAccent(_accent),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  Tr.forKu(K.todaysReviews, ku),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: _accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            Tr.forKu(K.todaysReviewsCount, ku, {
                              'count': '$_readyCount',
                            }),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Tr.forKu(K.strengthenMemory, ku),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.textMutedColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      constraints: const BoxConstraints(minWidth: 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        '$_readyCount',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withValues(alpha: 0.12),
              ),
              child: Icon(
                AppIcons.circleCheck,
                color: _accent.withValues(alpha: 0.9),
                size: 17,
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
    );
  }
}
