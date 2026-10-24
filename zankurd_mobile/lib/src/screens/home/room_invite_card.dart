import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/zankurd_repository.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/room_invite.dart';
import '../../providers/remote_availability.dart';
import '../../theme/app_icons.dart';
import '../../utils/app_route.dart';
import '../../utils/error_reporter.dart';
import '../../utils/player_identity.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/sahne/sahne.dart';
import '../play_hub_screen.dart' show joinRoomErrorKey;
import '../room_screen.dart';

/// Bir arkadaşın beni odasına davet ettiğini gösteren kart (Ana ekran ve
/// Yarış sekmesi).
///
/// Bekleyen davet yoksa (ya da sunucuda göç uygulanmamışsa) hiçbir şey
/// çizmez ve yer kaplamaz. Davet varsa en yenisi öne çıkar: davet edenin adı,
/// kategori, doluluk; "Katıl" daveti kabul edip MEVCUT oda katılma yoluna
/// (`joinOnlineRoom`) verir — dolu oda, engel, başka odada olma, katılım
/// ücreti kontrolleri tek yerde kalır. "Reddet" daveti kapatır. Birden çok
/// davet varsa en yenisi gösterilir, sayısı başlıkta yazılır; biri
/// işlenince sıradaki görünür.
///
/// Yükleme maliyeti: kart açılırken, [refreshToken]/[refreshSignal] değişince
/// ve kendi işlemlerinden sonra bir kez çekilir; yoklama döngüsü yoktur.
class RoomInviteCard extends StatefulWidget {
  const RoomInviteCard({
    required this.repository,
    this.refreshToken = 0,
    this.refreshSignal,
    this.topGap = true,
    super.key,
  });

  final ZanKurdRepository repository;
  final int refreshToken;
  final Listenable? refreshSignal;

  /// Kartın üstünde Ana ekrandaki kart aralığı bırakılsın mı.
  final bool topGap;

  @override
  State<RoomInviteCard> createState() => _RoomInviteCardState();
}

class _RoomInviteCardState extends State<RoomInviteCard> {
  List<RoomInvite> _invites = const [];
  bool _busy = false;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_reload);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant RoomInviteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reload);
      widget.refreshSignal?.addListener(_reload);
    }
    if (oldWidget.refreshToken != widget.refreshToken) unawaited(_load());
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) unawaited(_load());
  }

  Future<void> _load() async {
    if (RemoteAvailability.read(context)?.socialLocked ?? false) return;
    final epoch = ++_epoch;
    try {
      final invites = await widget.repository.loadMyRoomInvites();
      if (!mounted || epoch != _epoch) return;
      setState(() => _invites = invites);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room_invite_card_load');
      if (!mounted || epoch != _epoch) return;
      setState(() => _invites = const []);
    }
  }

  void _snack(String message) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));

  Future<void> _decline(RoomInvite invite) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.respondRoomInvite(invite.id, accept: false);
    } on RoomInviteException {
      // Zaten kapanmış: kart yine de kalkar.
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room invite decline');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  Future<void> _accept(RoomInvite invite) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final code = await widget.repository.respondRoomInvite(
        invite.id,
        accept: true,
      );
      if (code == null) {
        throw const RoomInviteException(RoomInviteFailure.expired);
      }
      final room = await widget.repository.joinOnlineRoom(code);
      if (!mounted) return;
      setState(() => _busy = false);
      await Navigator.of(context).push(
        AppRoute.to(
          RoomScreen(repository: widget.repository, initialRoom: room),
        ),
      );
    } on RoomInviteException catch (error) {
      if (mounted) {
        _snack(
          context.t(
            error.reason == RoomInviteFailure.expired
                ? K.roomInviteExpired
                : K.roomInviteFailed,
          ),
        );
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room invite accept');
      if (mounted) _snack(context.t(joinRoomErrorKey(error)));
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_invites.isEmpty || RemoteAvailability.socialLockedWatch(context)) {
      return const SizedBox.shrink();
    }
    final invite = _invites.first;
    final extra = _invites.length - 1;
    final name = context.playerDisplayName(
      invite.inviterName,
      tag: invite.inviterProfile?.playerTag,
    );
    final title = context.t(K.roomInviteCardTitle, {'name': name});
    final meta = context.t(K.roomInviteCardMeta, {
      'category': invite.categoryName,
      'count': '${invite.playerCount}',
      'max': '${invite.maxPlayers}',
    });
    return Padding(
      key: const ValueKey('room-invite-card'),
      padding: EdgeInsets.only(top: widget.topGap ? SahneSpace.cardGap : 0),
      child: Semantics(
        container: true,
        label: '$title. $meta',
        child: SahneSurfaceCard(
          child: Builder(
            builder: (context) {
              final t = SahneTokens.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    extra > 0
                        ? '${context.t(K.roomInviteSection)} · ${_invites.length}'
                        : context.t(K.roomInviteSection),
                    style: SahneType.captionStrong.copyWith(color: t.eyebrowTx),
                  ),
                  const SizedBox(height: SahneSpace.x1),
                  Row(
                    children: [
                      PlayerAvatar.fromIdentity(
                        key: const ValueKey('room-invite-avatar'),
                        radius: 18,
                        identity: invite.inviterProfile?.avatar,
                        displayName: invite.inviterName,
                      ),
                      const SizedBox(width: SahneSpace.x3),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: SahneType.headline.copyWith(color: t.tx),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SahneSpace.x1),
                  Text(
                    meta,
                    key: const ValueKey('room-invite-meta'),
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  SahneButton.secondary(
                    key: const ValueKey('room-invite-join'),
                    icon: AppIcons.peopleGroup,
                    label: context.t(K.roomInviteJoin),
                    expand: true,
                    loading: _busy,
                    onPressed: _busy ? null : () => unawaited(_accept(invite)),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SahneButton.text(
                      key: const ValueKey('room-invite-decline'),
                      label: context.t(K.roomInviteDecline),
                      arrow: false,
                      onPressed: _busy
                          ? null
                          : () => unawaited(_decline(invite)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
