import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/contest.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../utils/test_environment.dart';
import 'sahne/sahne.dart';
import 'skeleton_loader.dart';

/// "Bugünün sıralaması": ilk üç, kendi satırın, dünün birincisi ve bir
/// sonraki yarışmaya geri sayım.
///
/// ## Kusur
///
/// Günün turu bitince oyuncu yalnız kendi skorunu görüyordu; kimin nasıl
/// yaptığını, kaçıncı olduğunu ve yeni turun ne zaman açıldığını bilmiyordu.
/// "Yarışma" adı taşıyan ekranda yarışma hissi yoktu.
///
/// ## Kural
///
/// * Veri `getDailyEventBoard` (sunucu RPC) ile gelir; sıralama yalnız
///   GÖSTERİMDİR (ödül bağlı değil).
/// * Sonuç sunucuya YAZILDIKTAN sonra okunur: [ready] verilirse beklenir
///   (tur sonu ekranı kendi sonucunu yazar).
/// * Okunamazsa (çevrimdışı, hata) dürüst bir satır çıkar; geri sayım yine
///   görünür çünkü sunucuya gerek duymaz.
/// * Engellediğim oyuncular sunucuda süzülür; istemci ayrıca bir şey yapmaz.
/// * Geri sayım dakikada bir tazelenir; sınır İstanbul gece yarısıdır
///   ([nextContestResetAt]).
class DailyEventBoardCard extends StatefulWidget {
  const DailyEventBoardCard({
    super.key,
    required this.repository,
    this.ready,
    this.clock,
    this.teaser = false,
  });

  final ZanKurdRepository repository;

  /// Oynamadan ÖNCEKİ hâl: bugünün skorları ve sıralar gösterilmez (turu
  /// bozmaz), yalnız kaç kişinin bitirdiği, dünün birincisi ve geri sayım.
  /// 2026-10-25 ekran turu: tur başlamadan sayfanın %60'ı boştu.
  final bool teaser;

  /// Panonun okunmasından ÖNCE tamamlanması gereken iş (sonucu yazmak).
  final Future<void>? ready;

  /// Testler için saat; verilmezse `DateTime.now()`.
  final DateTime Function()? clock;

  @override
  State<DailyEventBoardCard> createState() => _DailyEventBoardCardState();
}

class _DailyEventBoardCardState extends State<DailyEventBoardCard> {
  late Future<DailyEventBoard?> _board;
  Timer? _tick;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _board = _load();
    _scheduleTick();
  }

  Future<DailyEventBoard?> _load() async {
    try {
      final ready = widget.ready;
      if (ready != null) await ready;
    } catch (error, stack) {
      // Yazma başarısızlığı panoyu engellemez: eski sonuçlar yine okunur.
      ErrorReporter.record(error, stack, reason: 'daily board ready');
    }
    try {
      return await widget.repository.loadDailyEventBoard();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'daily board load');
      return null;
    }
  }

  /// Bir sonraki dakika başında yeniden çizer. Tek atımlık zamanlayıcı
  /// zinciri: testlerde sonsuz periyodik zamanlayıcı bırakılmaz.
  void _scheduleTick() {
    if (isFlutterTestEnvironment) return;
    final now = _now();
    final untilNextMinute = Duration(seconds: 60 - now.second);
    _tick = Timer(untilNextMinute, () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    if (widget.teaser) return _buildTeaser(context, isKu);
    return Column(
      key: const ValueKey('daily-event-board'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.contestBoardTitle)),
        FutureBuilder<DailyEventBoard?>(
          future: _board,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonLine(
                key: ValueKey('daily-event-board-loading'),
                height: 120,
                borderRadius: 16,
              );
            }
            final board = snapshot.data;
            final hasRows =
                board != null && (board.top.isNotEmpty || board.me != null);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasRows)
                  _Rows(board: board, isKu: isKu)
                else
                  _Unavailable(isKu: isKu),
                if (board?.yesterdayWinner case final winner?) ...[
                  const SizedBox(height: SahneSpace.x3),
                  _InfoLine(
                    key: const ValueKey('daily-event-yesterday'),
                    icon: AppIcons.trophy,
                    text: Tr.forKu(K.contestYesterdayWinner, isKu, {
                      'name': winner.name,
                      'score': '${winner.correct}/${winner.total}',
                    }),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: SahneSpace.x3),
        _Countdown(now: _now(), isKu: isKu),
      ],
    );
  }
}

extension on _DailyEventBoardCardState {
  Widget _buildTeaser(BuildContext context, bool isKu) {
    return Column(
      key: const ValueKey('daily-event-teaser'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: SahneSpace.x3),
        FutureBuilder<DailyEventBoard?>(
          future: _board,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonLine(height: 48, borderRadius: 16);
            }
            final board = snapshot.data;
            if (board == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InfoLine(
                  key: const ValueKey('daily-event-participants'),
                  icon: AppIcons.user,
                  text: switch (board.participants) {
                    <= 0 => Tr.forKu(K.contestTeaserBeFirst, isKu),
                    1 => Tr.forKu(K.contestTeaserOne, isKu),
                    final n => Tr.forKu(K.contestTeaserParticipants, isKu, {
                      'count': '$n',
                    }),
                  },
                ),
                if (board.yesterdayWinner case final winner?) ...[
                  const SizedBox(height: SahneSpace.x3),
                  _InfoLine(
                    key: const ValueKey('daily-event-yesterday'),
                    icon: AppIcons.trophy,
                    text: Tr.forKu(K.contestYesterdayWinner, isKu, {
                      'name': winner.name,
                      'score': '${winner.correct}/${winner.total}',
                    }),
                  ),
                ],
                const SizedBox(height: SahneSpace.x3),
              ],
            );
          },
        ),
        _Countdown(now: _now(), isKu: isKu, ends: true),
      ],
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows({required this.board, required this.isKu});

  final DailyEventBoard board;
  final bool isKu;

  SahneListRow _row(DailyEventEntry e, bool isKu) {
    final score = '${e.correct}/${e.total}';
    final label = '${e.rank}. ${e.name}, $score, ${e.timeLabel}';
    if (e.isMe) {
      return SahneListRow.me(
        key: ValueKey('daily-event-row-${e.rank}'),
        rank: e.rank,
        title: e.name,
        subtitle: e.timeLabel,
        // "Sen" rozeti vurgunun sözlü kanalı: altın ton tek başına
        // renk körü oyuncuya yetmez (sıralama ekranıyla aynı kural).
        //
        // Rozet ve skor YAN YANA değil ÜST ÜSTE: yan yana dizilince 320 pt
        // genişlikte, %200 yazıda satır 65 pt taşıyordu.
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SahneRowValue(score),
            const SizedBox(height: SahneSpace.x1),
            SahneBadge(label: Tr.forKu(K.you, isKu), tone: SahneBadgeTone.gold),
          ],
        ),
        semanticLabel: label,
      );
    }
    return SahneListRow.rank(
      key: ValueKey('daily-event-row-${e.rank}'),
      rank: e.rank,
      title: e.name,
      icon: AppIcons.user,
      subtitle: e.timeLabel,
      trailing: SahneRowValue(score),
      semanticLabel: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = board.me;
    final meInTop = me != null && board.top.any((e) => e.rank == me.rank);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneListGroup(children: [for (final e in board.top) _row(e, isKu)]),
        // İlk üçte değilsem kendi satırım ayrıca, vurgulu durur.
        if (me != null && !meInTop) ...[
          const SizedBox(height: SahneSpace.x2),
          _row(me, isKu),
        ],
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return _InfoLine(
      key: const ValueKey('daily-event-board-unavailable'),
      icon: AppIcons.clock,
      text: Tr.forKu(K.contestBoardUnavailable, isKu),
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.now, required this.isKu, this.ends = false});

  /// Tur henüz oynanmadıysa "Bu tur X sonra biter" (oynanabilirlikle
  /// çelişmez); bittiyse "Yeni tur X sonra".
  final bool ends;
  final DateTime now;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final left = contestResetCountdown(now);
    return _InfoLine(
      key: const ValueKey('daily-event-countdown'),
      icon: AppIcons.clock,
      text: Tr.forKu(ends ? K.contestEndsIn : K.contestNextIn, isKu, {
        'h': '${left.hours}',
        'm': '${left.minutes}',
      }),
    );
  }
}

/// İkon + sarılan tek metin (dar ekranda ve %200 yazıda taşmaz).
class _InfoLine extends StatelessWidget {
  const _InfoLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: t.tx2),
        const SizedBox(width: SahneSpace.x2),
        Expanded(
          child: Text(text, style: SahneType.caption.copyWith(color: t.tx2)),
        ),
      ],
    );
  }
}
