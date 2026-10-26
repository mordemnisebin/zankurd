import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/my_suggestion.dart';
import '../theme/app_icons.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';

/// "Önerilerim": gönderilen soru önerileri ve durumları (2026-10-27).
///
/// Niçin: öneri gönderen kullanıcı sonucunu hiçbir yerde göremiyordu;
/// başarı mesajı da tutulmayan bir ödül vaat ediyordu. Durum her zaman
/// şekil + sözle verilir (yalnız renkle değil): bekleyen kum saati,
/// onaylanan ✓, kabul edilmeyen ✗; editör notu varsa altında yazar.
class MySuggestionsScreen extends StatefulWidget {
  const MySuggestionsScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<MySuggestionsScreen> createState() => _MySuggestionsScreenState();
}

class _MySuggestionsScreenState extends State<MySuggestionsScreen> {
  late Future<List<MySuggestion>?> _future = widget.repository
      .loadMySuggestions();

  void _reload() {
    final next = widget.repository.loadMySuggestions();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.mySuggestions))),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<MySuggestion>?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator(color: t.learnTx));
            }
            final items = snapshot.data;
            if (items == null) {
              return AppErrorState(
                key: const ValueKey('my-suggestions-error'),
                title: context.t(K.genericErrorTitle),
                message: context.t(K.genericErrorBody),
                retryLabel: context.t(K.retry),
                onRetry: _reload,
              );
            }
            if (items.isEmpty) {
              return AppEmptyState(
                key: const ValueKey('my-suggestions-empty'),
                icon: AppIcons.lightbulb,
                title: context.t(K.mySuggestions),
                message: context.t(K.mySuggestionsEmpty),
              );
            }
            return ListView.separated(
              key: const ValueKey('my-suggestions-list'),
              padding: const EdgeInsets.fromLTRB(
                SahneSpace.page,
                SahneSpace.x2,
                SahneSpace.page,
                SahneSpace.x8,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: SahneSpace.x3),
              itemBuilder: (context, i) => _SuggestionCard(item: items[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.item});

  final MySuggestion item;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final ku = context.isKu;
    final badge = switch (item.status) {
      MySuggestionStatus.pending => SahneStatusBadge.blank(
        label: context.t(K.suggestionPending),
      ),
      MySuggestionStatus.approved => SahneStatusBadge(
        correct: true,
        label: context.t(K.suggestionApproved),
      ),
      MySuggestionStatus.rejected => SahneStatusBadge(
        correct: false,
        label: context.t(K.suggestionRejected),
      ),
    };
    final d = item.createdAt;
    final date =
        '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
    final note = item.reviewNote;
    return SahneSurfaceCard(
      key: ValueKey('my-suggestion-${item.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              badge,
              Text(
                '${CategoryNames.localized(item.category, ku)} · $date',
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x3),
          Text(item.prompt, style: SahneType.bodyStrong.copyWith(color: t.tx)),
          if (note != null) ...[
            const SizedBox(height: SahneSpace.x3),
            Text(
              context.t(K.suggestionReviewNote),
              style: SahneType.captionStrong.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x1),
            Text(note, style: SahneType.body.copyWith(color: t.tx2)),
          ],
        ],
      ),
    );
  }
}
