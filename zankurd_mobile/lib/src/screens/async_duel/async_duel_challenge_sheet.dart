import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../models/friend.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/error_reporter.dart';
import '../../utils/player_identity.dart';
import '../../widgets/app_panel.dart';
import '../../widgets/sahne/sahne.dart';
import 'async_duel_play_screen.dart';

/// "Arkadaşına meydan oku" seçim sayfası.
///
/// İki yol: **Bağlantıyla meydan oku** (birincil; hesabı olmayan birine
/// WhatsApp'tan gidebilir) ve **Arkadaş seç** (kabul edilmiş arkadaşlar;
/// seçilene bildirim düşer). Arkadaşı yoksa boş durum nedenini söyler ve
/// bağlantı yolunu önerir — çıkmaz sokak yok.
///
/// Bir seçenek seçilince sayfa kapanır ve oyun ekranı
/// ([AsyncDuelPlayScreen], [AsyncDuelEntry.createChallenge]) üstüne açılır;
/// 7 sorudan sonra sonuç ekranında Paylaş çıkar.
///
/// Dönüş: oyun ekranı kapandığında tamamlanır (çağıran gelen kutusunu
/// tazeler).
Future<void> showAsyncDuelChallengeSheet(
  BuildContext context,
  ZanKurdRepository repository,
) async {
  final entry = await showModalBottomSheet<AsyncDuelEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ChallengeSheet(repository: repository),
  );
  if (entry == null || !context.mounted) return;
  await Navigator.of(context).push(
    AppRoute.to(AsyncDuelPlayScreen(repository: repository, entry: entry)),
  );
}

class _ChallengeSheet extends StatefulWidget {
  const _ChallengeSheet({required this.repository});

  final ZanKurdRepository repository;

  @override
  State<_ChallengeSheet> createState() => _ChallengeSheetState();
}

class _ChallengeSheetState extends State<_ChallengeSheet> {
  /// `false`: iki seçenek; `true`: arkadaş listesi.
  bool _pickingFriend = false;
  List<Friend>? _friends;
  bool _friendsFailed = false;

  Future<void> _openFriends() async {
    setState(() {
      _pickingFriend = true;
      _friendsFailed = false;
    });
    if (_friends != null) return;
    try {
      final friends = await widget.repository.loadFriends();
      if (!mounted) return;
      setState(() => _friends = friends);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'challenge sheet friends');
      if (!mounted) return;
      setState(() => _friendsFailed = true);
    }
  }

  void _choose(AsyncDuelEntry entry) => Navigator.of(context).pop(entry);

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        left: SahneSpace.page,
        right: SahneSpace.page,
        bottom: SahneSpace.page,
      ),
      child: AppPanel(
        child: Column(
          key: const ValueKey('challenge-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.t(K.challengeEntry),
                style: SahneType.headline.copyWith(color: t.tx),
              ),
            ),
            const SizedBox(height: SahneSpace.x4),
            if (!_pickingFriend) ...[
              SahneButton.primary(
                key: const ValueKey('challenge-sheet-link'),
                label: context.t(K.challengeViaLink),
                icon: AppIcons.shareNodes,
                arrow: false,
                expand: true,
                onPressed: () =>
                    _choose(const AsyncDuelEntry.createChallenge()),
              ),
              const SizedBox(height: SahneSpace.x2),
              Text(
                context.t(K.challengeViaLinkSub),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x4),
              SahneButton.secondary(
                key: const ValueKey('challenge-sheet-friend'),
                label: context.t(K.challengePickFriend),
                icon: AppIcons.peopleGroup,
                expand: true,
                onPressed: () => unawaited(_openFriends()),
              ),
            ] else
              _FriendPicker(
                friends: _friends,
                failed: _friendsFailed,
                onRetry: () => unawaited(_openFriends()),
                onPick: (friend) => _choose(
                  AsyncDuelEntry.createChallenge(friendId: friend.friendId),
                ),
                onLink: () => _choose(const AsyncDuelEntry.createChallenge()),
              ),
          ],
        ),
      ),
    );
  }
}

class _FriendPicker extends StatelessWidget {
  const _FriendPicker({
    required this.friends,
    required this.failed,
    required this.onRetry,
    required this.onPick,
    required this.onLink,
  });

  final List<Friend>? friends;
  final bool failed;
  final VoidCallback onRetry;
  final ValueChanged<Friend> onPick;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final list = friends;
    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.challengeFriendsFailed),
            key: const ValueKey('challenge-friends-failed'),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x3),
          SahneButton.secondary(
            label: context.t(K.retry),
            icon: AppIcons.arrowsRotate,
            expand: true,
            onPressed: onRetry,
          ),
        ],
      );
    }
    if (list == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: SahneSpace.x4),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (list.isEmpty) {
      return Column(
        key: const ValueKey('challenge-friends-empty'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t(K.challengeFriendsEmptyBody),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x4),
          SahneButton.primary(
            key: const ValueKey('challenge-friends-empty-link'),
            label: context.t(K.challengeViaLink),
            icon: AppIcons.shareNodes,
            arrow: false,
            expand: true,
            onPressed: onLink,
          ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: SingleChildScrollView(
        child: SahneListGroup(
          children: [
            for (final friend in list)
              SahneListRow.icon(
                key: ValueKey('challenge-friend-${friend.friendId}'),
                icon: AppIcons.peopleGroup,
                role: SahneRole.race,
                title: context.playerDisplayName(friend.friendName),
                chevron: true,
                onTap: () => onPick(friend),
              ),
          ],
        ),
      ),
    );
  }
}

/// Meydan okuma giriş noktalarının kapısı: sunucuda RPC'ler yoksa (göç
/// henüz uygulanmamış, `PGRST202`/`42883`) giriş noktaları HİÇ çizilmez;
/// uygulama göçten önce de sonra da yayınlanabilir.
///
/// Çağıran sonuç gelene dek giriş noktasını gizli tutar (çizilip sonra
/// kaybolursa ekran zıplar). Sonda depoda bir kez yapılıp önbelleğe alınır
/// (`supportsAsyncDuelChallenge`); hata `false` sayılır.
Future<bool> asyncDuelChallengeAvailable(ZanKurdRepository repository) async {
  try {
    return await repository.supportsAsyncDuelChallenge();
  } catch (_) {
    return false;
  }
}
