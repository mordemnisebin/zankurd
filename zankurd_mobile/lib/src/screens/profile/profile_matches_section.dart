import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/streak_store.dart';
import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/match_history.dart';
import '../../theme/app_icons.dart';
import '../../utils/error_reporter.dart';
import '../../utils/percent_format.dart';
import '../../utils/player_identity.dart';
import '../../widgets/sahne/sahne.dart';

/// Satırın sağındaki kısa tarih: "24.10". Yıl yok (yalnız son 10 maç);
/// dil/ay adı yok, bu yüzden Kurmancî ile Türkçe aynı görünür.
String profileMatchDateLabel(DateTime at) {
  final local = at.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month';
}

/// Satırın alt metni: "Kazandın · 5–4" / "Kaybettin · hükmen".
///
/// Hükmen sonuçta skor yazılmaz (kaybeden turunu bitirmemiş olabilir) ve
/// mevcut hükmen metinleri kullanılır ([K.asyncDuelWonForfeit]).
String profileMatchSubtitle(BuildContext context, RecentMatch match) {
  if (match.forfeit && match.result != RecentMatchResult.draw) {
    return match.result == RecentMatchResult.win
        ? context.t(K.asyncDuelWonForfeit)
        : context.t(K.asyncDuelLostForfeit);
  }
  final label = switch (match.result) {
    RecentMatchResult.win => context.t(K.matchResultWin),
    RecentMatchResult.loss => context.t(K.matchResultLoss),
    RecentMatchResult.draw => context.t(K.matchResultDraw),
  };
  final mine = match.myScore;
  final theirs = match.opponentScore;
  if (mine == null || theirs == null) return label;
  return '$label · $mine–$theirs';
}

IconData _kindIcon(RecentMatchKind kind) => switch (kind) {
  RecentMatchKind.async => AppIcons.clock,
  RecentMatchKind.room1v1 => AppIcons.swords,
  RecentMatchKind.room => AppIcons.peopleGroup,
};

String _kindLabel(BuildContext context, RecentMatchKind kind) => switch (kind) {
  RecentMatchKind.async => context.t(K.asyncDuel),
  RecentMatchKind.room1v1 => context.t(K.duel1v1Short),
  RecentMatchKind.room => context.t(K.roomWord),
};

/// Profildeki "Son maçlar": son 10 bitmiş maç (sırayla düello + canlı oda).
///
/// Durumlar: yükleniyor (hiçbir şey çizilmez, zıplama yok) · liste · boş
/// (oynamaya çağıran tek cümle + isteğe bağlı eylem) · yüklenemedi (tek
/// cümle + tekrar dene). [remote] false ise (çevrimdışı/yerel misafir) sunucu
/// hiç sorulmaz ve boş durum gösterilir: orada çevrimiçi maç olamaz.
class ProfileMatchHistorySection extends StatefulWidget {
  const ProfileMatchHistorySection({
    required this.repository,
    this.refreshSignal,
    this.remote = true,
    this.onStartPlay,
    this.limit = 10,
    super.key,
  });

  final ZanKurdRepository repository;
  final Listenable? refreshSignal;
  final bool remote;

  /// Boş durumdaki eylem ("Bugün başla"); null ise eylem çizilmez.
  final VoidCallback? onStartPlay;
  final int limit;

  @override
  State<ProfileMatchHistorySection> createState() =>
      _ProfileMatchHistorySectionState();
}

class _ProfileMatchHistorySectionState
    extends State<ProfileMatchHistorySection> {
  List<RecentMatch>? _matches;
  bool _failed = false;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_reload);
    // Çevrimdışı/yerel misafir: sunucuya sorulmaz, doğrudan boş durum.
    if (widget.remote) {
      unawaited(_fetch());
    } else {
      _matches = const [];
    }
  }

  @override
  void didUpdateWidget(covariant ProfileMatchHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reload);
      widget.refreshSignal?.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) unawaited(_fetch());
  }

  Future<void> _fetch() async {
    if (!widget.remote) return;
    final epoch = ++_epoch;
    try {
      final matches = await widget.repository.loadMyRecentMatches(
        limit: widget.limit,
      );
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _matches = matches;
        _failed = false;
      });
    } catch (error, stack) {
      // Elde eski liste varsa o kalır; yoksa "yüklenemedi" gösterilir. Boş
      // listeye düşülmez: "henüz maç yok" demek yanlış olurdu.
      ErrorReporter.record(error, stack, reason: 'profile recent matches');
      if (!mounted || epoch != _epoch) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final t = SahneTokens.of(context);
    final Widget body;
    if (matches == null && !_failed) {
      // İlk yükleme: başlık bile çizilmez; satırlar gelince bölüm açılır.
      return const SizedBox.shrink(key: ValueKey('profile-recent-matches'));
    } else if (matches == null) {
      body = SahneSurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x4,
          vertical: SahneSpace.x3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.t(K.asyncDuelLoadFailed),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ),
            SahneButton.text(
              buttonKey: const ValueKey('profile-recent-matches-retry'),
              label: context.t(K.retry),
              arrow: false,
              onPressed: _reload,
            ),
          ],
        ),
      );
    } else if (matches.isEmpty) {
      // Boş "Son maçlar" ayrı bir kart çizmez (2026-10-28 kurul K9): boş
      // Rekorlar kartı tek kompakt boş durumdur ve oyuna zaten götürür.
      return const SizedBox.shrink(key: ValueKey('profile-recent-matches'));
    } else {
      body = SahneListGroup(
        children: [for (final match in matches) _MatchRow(match: match)],
      );
    }
    return Column(
      key: const ValueKey('profile-recent-matches'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.recentMatchesTitle)),
        body,
      ],
    );
  }
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({required this.match});

  final RecentMatch match;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final raw = match.opponentName;
    final opponent = raw == null || raw.trim().isEmpty
        ? context.t(K.asyncDuelOpponent)
        : context.playerDisplayName(raw);
    final subtitle = profileMatchSubtitle(context, match);
    final kind = _kindLabel(context, match.kind);
    final date = profileMatchDateLabel(match.playedAt);
    return SahneListRow.icon(
      key: ValueKey('profile-match-${match.id}'),
      icon: _kindIcon(match.kind),
      role: SahneRole.race,
      title: opponent,
      subtitle: subtitle,
      // Mod adı yalnız ekran okuyucuya: ikon tek başına anlam taşımaz.
      semanticLabel: '$opponent. $subtitle. $kind. $date',
      trailing: Text(
        date,
        style: SahneType.caption.copyWith(
          color: t.tx2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Profildeki "Rekorlarım": en uzun günlük seri (yerel), canlı oda doğru
/// serisi, günlük yarış en çok doğru, düello galibiyeti ve kazanma oranı
/// (sunucu). Sıfır uydurulmaz.
///
/// ## Niçin "—" listesi değil
///
/// Yeni oyuncuda beş satırın hepsi "—" idi: boş bir tablo hem bilgi vermez
/// hem "eksik/bozuk" izlenimi bırakır (2026-10-24 simülatör turu). Artık:
/// hiçbiri bilinmiyorsa davetkâr boş durum ("İlk rekorunu kır" + oyna
/// düğmesi); bazısı biliniyorsa yalnız bilinenler + küçük ipucu.
class ProfileRecordsSection extends StatefulWidget {
  const ProfileRecordsSection({
    required this.repository,
    this.refreshSignal,
    this.remote = true,
    this.onStartPlay,
    super.key,
  });

  /// Boş durumdaki "oynamaya başla" düğmesi; yoksa düğme çizilmez.
  final VoidCallback? onStartPlay;

  final ZanKurdRepository repository;
  final Listenable? refreshSignal;
  final bool remote;

  @override
  State<ProfileRecordsSection> createState() => _ProfileRecordsSectionState();
}

class _ProfileRecordsSectionState extends State<ProfileRecordsSection> {
  int? _bestDayStreak;
  ServerRecords? _server;
  int _epoch = 0;

  /// Yerel + (varsa) sunucu okuması bitti mi. Bitmeden boş durum çizilirse
  /// sunucu sayıları gelince ekran "boş"tan "dolu"ya zıplıyordu.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_reload);
    unawaited(_fetch());
  }

  @override
  void didUpdateWidget(covariant ProfileRecordsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reload);
      widget.refreshSignal?.addListener(_reload);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) unawaited(_fetch());
  }

  Future<void> _fetch() async {
    final epoch = ++_epoch;
    // Yerel değer sunucuya bağlı değildir: çevrimdışıyken de görünür.
    try {
      final streak = await StreakStore.load();
      if (mounted && epoch == _epoch) {
        setState(() => _bestDayStreak = streak.best);
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile records streak');
    }
    if (widget.remote) {
      try {
        final server = await widget.repository.loadMyServerRecords();
        if (!mounted || epoch != _epoch) return;
        setState(() => _server = server);
      } catch (error, stack) {
        // Sunucu sayıları gelmediyse ilgili satırlar hiç çizilmez.
        ErrorReporter.record(error, stack, reason: 'profile records server');
      }
    }
    if (mounted && epoch == _epoch && !_settled) {
      setState(() => _settled = true);
    }
  }

  /// 0 ve null "henüz yok" demektir: "—".
  String _count(int? value) => value == null || value <= 0 ? '—' : '$value';

  @override
  Widget build(BuildContext context) {
    final server = _server;
    final winRate = server?.winRatePercent;
    final rows = <({String label, String value, IconData icon, String key})>[
      (
        label: context.t(K.recordBestDayStreak),
        value: _count(_bestDayStreak),
        icon: AppIcons.fire,
        key: 'day-streak',
      ),
      (
        label: context.t(K.recordBestQuizStreak),
        value: _count(server?.bestQuizStreak),
        icon: AppIcons.bolt,
        key: 'quiz-streak',
      ),
      (
        label: context.t(K.recordBestContest),
        value: _count(server?.bestContestCorrect),
        icon: AppIcons.bullseye,
        key: 'contest',
      ),
      (
        label: context.t(K.recordDuelWins),
        // Düello oynanmışsa 0 galibiyet gerçek bir sayıdır; hiç oynanmadıysa "—".
        value: server == null || server.duelTotal == 0
            ? '—'
            : '${server.duelWins}',
        icon: AppIcons.trophy,
        key: 'duel-wins',
      ),
      (
        label: context.t(K.recordWinRate),
        value: winRate == null ? '—' : context.percent(winRate),
        icon: AppIcons.chartLine,
        key: 'win-rate',
      ),
    ];
    final t = SahneTokens.of(context);
    if (!_settled) {
      return const SizedBox.shrink(key: ValueKey('profile-records'));
    }
    final known = [
      for (final row in rows)
        if (row.value != '—') row,
    ];
    if (known.isEmpty) {
      // Başlıksız tek kompakt boş durum (rekor + son maç birlikte, K9).
      return Column(
        key: const ValueKey('profile-records'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: SahneSpace.cardGap),
          SahneSurfaceCard(
            key: const ValueKey('profile-records-empty'),
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x4,
              vertical: SahneSpace.x3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: ExcludeSemantics(
                    child: Icon(AppIcons.trophy, size: 20, color: t.goldTx),
                  ),
                ),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(K.recordsEmptyTitle),
                        style: SahneType.bodyStrong.copyWith(color: t.tx),
                      ),
                      const SizedBox(height: SahneSpace.x1),
                      Text(
                        context.t(K.recordsEmptyBody),
                        style: SahneType.caption.copyWith(color: t.tx2),
                      ),
                      if (widget.onStartPlay != null)
                        SahneButton.text(
                          buttonKey: const ValueKey('profile-records-start'),
                          label: context.t(K.recordsEmptyAction),
                          onPressed: widget.onStartPlay,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      key: const ValueKey('profile-records'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.recordsTitle)),
        SahneListGroup(
          children: [
            for (final row in known)
              SahneListRow.icon(
                key: ValueKey('profile-record-${row.key}'),
                icon: row.icon,
                role: SahneRole.gold,
                title: row.label,
                semanticLabel: '${row.label}: ${row.value}',
                trailing: Text(
                  row.value,
                  style: SahneType.bodyStrong.copyWith(
                    color: t.tx,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
        if (known.length < rows.length)
          Padding(
            padding: const EdgeInsets.only(top: SahneSpace.x2),
            child: Text(
              context.t(K.recordsMoreHint),
              key: const ValueKey('profile-records-hint'),
              style: SahneType.caption.copyWith(color: t.tx3),
            ),
          ),
      ],
    );
  }
}
