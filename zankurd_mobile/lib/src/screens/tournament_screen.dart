import 'package:flutter/material.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/tournament.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({required this.repository, super.key});
  final ZanKurdRepository repository;
  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  late Future<TournamentBracket?> _bracketFuture;
  late Future<List<TournamentStandings>> _standingsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bracketFuture = widget.repository.loadTournamentBracket();
    _standingsFuture = widget.repository.loadTournamentStandings();
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Turnuva' : 'Turnuva')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<TournamentBracket?>(
                  future: _bracketFuture,
                  builder: (_, snap) => snap.hasData
                      ? _BracketView(snap.data!, ku)
                      : AppErrorState(
                          title: 'Yükleniyor',
                          message: 'Turnuva yükleniyor',
                          retryLabel: 'Tekrar',
                          onRetry: () => setState(_load),
                        ),
                ),
                const SizedBox(height: 24),
                Text(
                  ku ? 'Sıralaması' : 'Sıralama',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<TournamentStandings>>(
                  future: _standingsFuture,
                  builder: (_, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    return Column(
                      children: snap.data!
                          .map((s) => _StandingRow(s, ku))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BracketView extends StatelessWidget {
  final TournamentBracket bracket;
  final bool ku;
  const _BracketView(this.bracket, this.ku);

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Durum',
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 12,
                ),
              ),
              Text(
                bracket.status == 'active' ? 'Devam' : 'Bitti',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Skor',
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 12,
                ),
              ),
              Text(
                '${bracket.totalScore}',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  final TournamentStandings s;
  final bool ku;
  const _StandingRow(this.s, this.ku);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppPanel(
        child: Row(
          children: [
            Text('${s.rank}.'),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                s.playerName,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${s.totalScore}',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
