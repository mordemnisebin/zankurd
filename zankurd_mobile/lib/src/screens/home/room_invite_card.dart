import 'package:zankurd_mobile/src/utils/number_format.dart';

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
import '../../widgets/dialog_action_pair.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/branded_loader.dart';
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
/// Yalnız görünür sekme/rota uygulama önündeyken 20 saniyede bir yenilenir;
/// FCM ulaşmasa da yeni davet görünür. Aynı anda tek sorgu çalışır.
class RoomInviteCard extends StatefulWidget {
  const RoomInviteCard({
    required this.repository,
    this.refreshToken = 0,
    this.targetInviteId,
    this.refreshSignal,
    this.topGap = true,
    this.isVisible = true,
    super.key,
  });

  final ZanKurdRepository repository;
  final int refreshToken;

  /// Bildirimden açılan görünüm yalnız bu daveti sunar.
  final String? targetInviteId;
  final Listenable? refreshSignal;

  /// Kartın üstünde Ana ekrandaki kart aralığı bırakılsın mı.
  final bool topGap;

  /// IndexedStack içinde gizli kalan sekme ağ yoklaması yapmaz.
  final bool isVisible;

  @override
  State<RoomInviteCard> createState() => _RoomInviteCardState();
}

class _RoomInviteCardState extends State<RoomInviteCard>
    with WidgetsBindingObserver {
  List<RoomInvite> _invites = const [];
  String? _targetMessage;
  bool _busy = false;
  int _epoch = 0;
  Timer? _pollTimer;
  bool _loading = false;
  bool _reloadPending = false;
  bool _routeCurrent = false;
  bool _appInForeground = true;
  String? _invitesOwner;

  bool get _canLoad =>
      mounted &&
      widget.isVisible &&
      _routeCurrent &&
      _appInForeground &&
      !(RemoteAvailability.read(context)?.socialLocked ?? false);

  @override
  void initState() {
    super.initState();
    _invitesOwner = widget.repository.currentUserId;
    widget.refreshSignal?.addListener(_reload);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _appInForeground =
        lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _syncPolling();
  }

  void _syncPolling() {
    if (!_canLoad) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }
    if (_pollTimer != null) return;
    _reload();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_loading) unawaited(_load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    _syncPolling();
  }

  @override
  void didUpdateWidget(covariant RoomInviteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_reload);
      widget.refreshSignal?.addListener(_reload);
    }
    if (!identical(oldWidget.repository, widget.repository) ||
        _invitesOwner != widget.repository.currentUserId ||
        oldWidget.targetInviteId != widget.targetInviteId) {
      _epoch++;
      _invitesOwner = widget.repository.currentUserId;
      _invites = const [];
      _targetMessage = null;
      _reload();
    }
    _syncPolling();
    if (oldWidget.refreshToken != widget.refreshToken) _reload();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_reload);
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!_canLoad) return;
    if (_loading) {
      _reloadPending = true;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!_canLoad) return;
    if (_loading) {
      _reloadPending = true;
      return;
    }
    _loading = true;
    final epoch = ++_epoch;
    final repository = widget.repository;
    final userId = repository.currentUserId;
    try {
      final target = widget.targetInviteId;
      final invites = await repository.loadMyRoomInvites(
        throwOnError: true,
        inviteId: target,
      );
      if (!mounted ||
          epoch != _epoch ||
          !identical(repository, widget.repository) ||
          userId != repository.currentUserId) {
        return;
      }
      setState(() {
        _invitesOwner = userId;
        _invites = target == null
            ? invites
            : invites.where((i) => i.id == target).toList();
        _targetMessage = _invites.isEmpty ? K.roomInviteExpired : null;
      });
    } catch (error, stack) {
      // Geçici ağ hatası "davet yok" değildir; son başarılı liste kalır.
      if (mounted &&
          epoch == _epoch &&
          widget.targetInviteId != null &&
          _invites.isEmpty &&
          userId == repository.currentUserId) {
        setState(() => _targetMessage = K.loadFailedShort);
      }
      ErrorReporter.record(error, stack, reason: 'room_invite_card_load');
    } finally {
      _loading = false;
      if (_reloadPending) {
        _reloadPending = false;
        _reload();
      }
    }
  }

  bool _sameAccount(ZanKurdRepository repository, String? userId) =>
      identical(repository, widget.repository) &&
      repository.currentUserId == userId;

  void _snack(String message, {VoidCallback? retry}) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          action: retry == null
              ? null
              : SnackBarAction(label: context.t(K.retry), onPressed: retry),
        ),
      );

  Future<void> _decline(RoomInvite invite) async {
    if (_busy) return;
    final repository = widget.repository;
    final userId = repository.currentUserId;
    setState(() => _busy = true);
    try {
      await repository.respondRoomInvite(invite.id, accept: false);
    } catch (error, stack) {
      if (!mounted || !_sameAccount(repository, userId)) return;
      if (error is! RoomInviteException ||
          error.reason != RoomInviteFailure.expired) {
        ErrorReporter.record(error, stack, reason: 'room invite decline');
        _snack(
          context.t(K.genericError),
          retry: () {
            if (mounted &&
                _sameAccount(repository, userId) &&
                _invites.any((i) => i.id == invite.id)) {
              unawaited(_decline(invite));
            }
          },
        );
        return;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted || !_sameAccount(repository, userId)) return;
    if (widget.targetInviteId != null &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
      return;
    }
    await _load();
  }

  Future<void> _accept(RoomInvite invite) async {
    final fee = invite.entryFee;
    if (_busy || !invite.hasConfirmedTerms) {
      return;
    }
    final repository = widget.repository;
    final userId = repository.currentUserId;
    setState(() => _busy = true);
    try {
      if (fee! > 0) {
        final feeText = _inviteFeeText(context, invite);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.t(K.roomInviteJoin)),
            content: Text('${ctx.t(K.entryFeeLabel)}: $feeText'),
            actions: [
              DialogActionPair(
                cancel: TextButton(
                  key: const ValueKey('room-invite-fee-cancel'),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.t(K.cancel)),
                ),
                confirm: FilledButton(
                  key: const ValueKey('room-invite-fee-confirm'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('${ctx.t(K.roomInviteJoin)} · $feeText'),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true ||
            !mounted ||
            !_sameAccount(repository, userId)) {
          return;
        }
      }
      final code = await repository.respondRoomInvite(invite.id, accept: true);
      if (!mounted || !_sameAccount(repository, userId)) return;
      if (code == null || code != invite.roomCode) {
        throw const RoomInviteException(RoomInviteFailure.expired);
      }
      final room = await repository.joinOnlineRoom(code);
      if (!mounted || !_sameAccount(repository, userId)) return;
      final route = AppRoute.to<void>(
        RoomScreen(repository: repository, initialRoom: room),
      );
      if (widget.targetInviteId != null) {
        if (ModalRoute.of(context)?.isCurrent != true) return;
        await Navigator.of(context).pushReplacement(route);
      } else {
        await Navigator.of(context).push(route);
      }
    } on RoomInviteException catch (error) {
      if (mounted && _sameAccount(repository, userId)) {
        _snack(
          context.t(
            error.reason == RoomInviteFailure.expired
                ? K.roomInviteExpired
                : K.genericError,
          ),
        );
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room invite accept');
      if (mounted && _sameAccount(repository, userId)) {
        _snack(context.t(joinRoomErrorKey(error)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _sameAccount(repository, userId)) await _load();
  }

  String _feeText(BuildContext context, int? fee) => switch (fee) {
    0 => context.t(K.freeEntry),
    final int n when n > 0 => '${groupThousands(n)} ${context.t(K.coinWord)}',
    _ => context.t(K.unknownPlayer),
  };

  String _inviteFeeText(BuildContext context, RoomInvite invite) =>
      _feeText(context, invite.entryFee);

  @override
  Widget build(BuildContext context) {
    // Boş kart da kilidin kalkışını dinlemeli: aksi halde çevrimdışı
    // açılışta kurulmayan polling bağlantı dönünce hiç başlayamaz.
    final socialLocked = RemoteAvailability.socialLockedWatch(context);
    if (_invitesOwner != widget.repository.currentUserId ||
        _invites.isEmpty ||
        socialLocked) {
      if (widget.targetInviteId == null) return const SizedBox.shrink();
      final message = socialLocked ? K.offline : _targetMessage;
      if (message == null) return const BrandedLoaderCenter();
      return Center(
        child: Column(
          children: [
            Text(context.t(message), textAlign: TextAlign.center),
            if (message == K.loadFailedShort)
              SahneButton.text(label: context.t(K.retry), onPressed: _reload),
          ],
        ),
      );
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
      'count': groupThousands(invite.playerCount),
      'max': groupThousands(invite.maxPlayers),
    });
    final count = invite.questionCount;
    final seconds = invite.secondsPerQuestion;
    final details = [
      if (count != null) '${groupThousands(count)} ${context.t(K.soru)}',
      if (seconds != null)
        context.t(K.perQuestionSeconds, {'n': groupThousands(seconds)}),
    ].join(' · ');
    final feeText = _inviteFeeText(context, invite);
    final termsKnown = invite.hasConfirmedTerms;
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
                  if (widget.targetInviteId == null) ...[
                    Text(
                      extra > 0
                          ? '${context.t(K.roomInviteSection)} · ${groupThousands(_invites.length)}'
                          : context.t(K.roomInviteSection),
                      style: SahneType.captionStrong.copyWith(
                        color: t.eyebrowTx,
                      ),
                    ),
                    const SizedBox(height: SahneSpace.x1),
                  ],
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
                  if (details.isNotEmpty)
                    Text(
                      details,
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                  Text(
                    '${context.t(K.entryFeeLabel)}: $feeText',
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  SahneButton.secondary(
                    key: ValueKey(
                      termsKnown ? 'room-invite-join' : 'room-invite-retry',
                    ),
                    icon: termsKnown
                        ? AppIcons.peopleGroup
                        : AppIcons.arrowsRotate,
                    label: termsKnown
                        ? '${context.t(K.roomInviteJoin)} · $feeText'
                        : context.t(K.retry),
                    expand: true,
                    loading: _busy,
                    onPressed: _busy
                        ? null
                        : termsKnown
                        ? () => unawaited(_accept(invite))
                        : _reload,
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
