import 'package:flutter/material.dart';

import '../data/mistake_store.dart';
import '../data/zankurd_repository.dart';
import '../models/quiz_question.dart';
import '../screens/quiz_screen.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import 'kilim_pattern_painter.dart';

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

  Future<void> _refresh() async {
    try {
      final store = await MistakeStore.load();
      if (mounted) {
        setState(() {
          _readyCount = store.readyCount;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startReview() async {
    final store = await MistakeStore.load();
    final readyIds = store.readyIds;
    final questions = widget.repository.questions
        .where((q) => readyIds.contains(q.id))
        .toList();
    if (questions.isEmpty) return;

    final onStart = widget.onStartReview;
    if (onStart != null) {
      onStart(questions);
      return;
    }

    if (!mounted) return;
    final ku = widget.isKu;
    final room = widget.repository.createRoom().copyWith(
      name: ku ? 'Dubarekirinên Îro' : 'Bugünkü Tekrarlar',
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(_accent.withValues(alpha: 0.16), surface),
                  Color.alphaBlend(_accent.withValues(alpha: 0.05), surface),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: _accent.withValues(alpha: 0.30),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: const KilimPatternPainter(
                        drawPattern: true,
                        color: _accent,
                        opacity: 0.04,
                      ),
                    ),
                  ),
                ),
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
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: _accent,
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
                                  ku
                                      ? 'Dubarekirinên Îro'
                                      : 'Bugünkü Tekrarlar',
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
                            ku
                                ? '$_readyCount pirs ji bo dubarekirinê amade ne'
                                : '$_readyCount soru tekrara hazır',
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
                            ku ? 'Bîranîna xwe xurt bike' : 'Hafızanı pekiştir',
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
    final surface = AppTheme.surfaceHiColor(context);
    return Container(
      key: const ValueKey('todays-review-empty'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              color: _accent.withValues(alpha: 0.9),
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ku ? 'Dubarekirin temam' : 'Tekrarlar tamam',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ku
                      ? 'Îro pirsên te yên dubarekirinê tune'
                      : 'Bugün tekrar edilecek sorun yok',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
