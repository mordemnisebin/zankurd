import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/zankurd_repository.dart';
import '../config/feature_flags.dart';
import '../models/referral_result.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/friend.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sahne/sahne.dart';
import 'room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Arkadaş listesi, oyuncu arama ve istek yönetimi ekranı.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();

  late Future<List<Friend>> _friendsFuture;
  late Future<List<FriendRequest>> _requestsFuture;
  List<PlayerSearchResult> _searchResults = const [];
  bool _searching = false;
  bool _roomLoading = false;
  final Set<String> _sentRequests = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadFriends() {
    _friendsFuture = widget.repository.loadFriends();
    _requestsFuture = widget.repository.loadPendingFriendRequests();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      _showMessage(context.t(K.minTwoChars));
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await widget.repository.searchPlayers(query);
      if (!mounted) return;
      setState(() => _searchResults = results);
      if (results.isEmpty) {
        _showMessage(context.t(K.playerNotFound));
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'friends_load');
      if (mounted) {
        setState(() => _searching = false);
        _showMessage(context.t(K.searchFailed));
      }
      return;
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(PlayerSearchResult player) async {
    final success = await widget.repository.addFriend(
      player.id,
      player.displayName,
    );
    if (!mounted) return;
    if (success) {
      setState(() => _sentRequests.add(player.id));
      widget.repository
          .logAnalyticsEvent('friend_request_sent', null)
          .catchError((error, stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'log_friend_request_sent',
            );
            return false;
          });
      _showMessage(context.t(K.requestSent));
    } else {
      _showMessage(context.t(K.requestFailed));
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    final success = await widget.repository.acceptFriendRequest(requestId);
    if (!mounted) return;
    if (success) {
      _showMessage(context.t(K.requestAccepted));
      setState(_loadFriends);
    } else {
      _showMessage(context.t(K.acceptFailed));
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final success = await widget.repository.rejectFriendRequest(requestId);
    if (!mounted) return;
    if (success) {
      _showMessage(context.t(K.requestRejected));
      setState(_loadFriends);
    } else {
      _showMessage(context.t(K.rejectFailed));
    }
  }

  /// Arkadaşla oynamak için özel oda açar; oda kodu arkadaşla paylaşılır.
  Future<void> _playWithFriend(Friend friend) async {
    if (_roomLoading) return;
    setState(() => _roomLoading = true);
    try {
      final room = await widget.repository.createOnlineRoom();
      if (!mounted) return;
      _showMessage(context.t(K.shareRoomCodeWith, {'name': friend.friendName}));
      await Navigator.of(context).push(
        AppRoute.to(
          RoomScreen(repository: widget.repository, initialRoom: room),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'friends_action');
      if (mounted) {
        _showMessage(context.t(K.roomCreateFailed));
      }
    } finally {
      if (mounted) setState(() => _roomLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    // 2026-09-29 Şahnê: B iskeleti. Sayfa adı ve alt satırı çubukta; eski
    // kimlik başlığı ve altındaki kilim ayracı kalktı. Bölümler tek bölüm
    // başlığıyla ([SahneSectionHeader]) ayrılır; arkadaşlar ve istekler
    // liste grubunda ([SahneListGroup]) durur. Ekranda Agir dolgulu bir
    // düğme yok: buradaki eylemlerin hiçbiri tek birincil değil (bir
    // listede birden çok "Kabul" / "Odaya çağır" olabilir), hepsi ikincil.
    return SahnePushedPage(
      title: context.t(K.myFriends),
      backLabel: context.t(K.back),
      // Tek parça kolon (tembel liste değil): istek ve arkadaş satırları
      // büyük yazıda ilk ekranın altına düşse de kurulur; ekran okuyucu ve
      // "sonraki öğe" gezinmesi hepsini görür. Liste kısa (istekler +
      // arkadaşlar), tembel kurmanın kazancı yok.
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (kReferralRewardsEnabled) _buildInviteSection(ku),
                _buildSearchSection(ku),
                _buildRequestsSection(ku),
                SahneSectionHeader(title: context.t(K.friendsScreen)),
                _buildFriendsSection(ku),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInviteSection(bool ku) {
    final t = SahneTokens.of(context);
    // Davet ödülü bir Zêr (ödül) konusudur: jeton glifi ton karoda; iki
    // eylem de ikincil (Kulis) — ekranın birincili değiller.
    return SahneSurfaceCard(
      key: const ValueKey('friends-invite-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Builder(
            builder: (context) {
              final tile = DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.goldTint,
                  shape: SahneShape.m,
                ),
                child: const SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: SahneGlyph(SahneGlyphKind.coin, size: 24),
                  ),
                ),
              );
              final texts = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(K.inviteFriends),
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                  Text(
                    context.t(K.inviteSubtitle),
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              );
              // Büyük yazıda jeton karosu metnin üstüne çıkar: başlık dar
              // sütunda hece hece bölünmesin.
              if (MediaQuery.textScalerOf(context).scale(16) >= 24) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tile,
                    const SizedBox(height: SahneSpace.x3),
                    texts,
                  ],
                );
              }
              return Row(
                children: [
                  tile,
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(child: texts),
                ],
              );
            },
          ),
          const SizedBox(height: SahneSpace.x4),
          FutureBuilder<String?>(
            future: widget.repository.getPlayerTag(),
            builder: (context, snapshot) {
              final tag = snapshot.data;
              final share = tag != null && tag.isNotEmpty
                  ? SahneButton.secondary(
                      key: const ValueKey('friends-share-code-button'),
                      label: tag,
                      icon: AppIcons.shareNodes,
                      expand: true,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        final text = context.t(K.inviteShareText, {'tag': tag});
                        SharePlus.instance.share(ShareParams(text: text));
                      },
                    )
                  : null;
              final enter = SahneButton.secondary(
                key: const ValueKey('friends-enter-code-button'),
                label: context.t(K.enterReferralCode),
                icon: AppIcons.userPlus,
                expand: true,
                onPressed: () => _showReferralDialog(ku),
              );
              return LayoutBuilder(
                builder: (context, constraints) {
                  // Büyük yazıda iki düğme yan yana sığmıyorsa alt alta
                  // iner; etiket harf harf bölünmez.
                  final stack =
                      MediaQuery.textScalerOf(context).scale(16) >= 24 ||
                      constraints.maxWidth < 300;
                  if (share == null) return enter;
                  if (stack) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        share,
                        const SizedBox(height: SahneSpace.x2),
                        enter,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: share),
                      const SizedBox(width: SahneSpace.x2),
                      Expanded(child: enter),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showReferralDialog(bool ku) {
    final controller = TextEditingController();
    bool submitting = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              // 2026-09-25: zemin ve yarıçap `AppTheme._dialogTheme`ten
              // geliyor. Buradaki `AppRadius.card` (14) temanın `md` (16)
              // değerinden farklıydı; uygulamada 14/16/20 karışık yarıçaplı
              // üç ayrı diyalog dili oluşmuştu.
              title: Text(
                context.t(K.enterReferralCode),
                style: SahneType.headline.copyWith(
                  color: SahneTokens.of(dialogContext).tx,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(K.inviteSubtitle),
                    style: SahneType.caption.copyWith(
                      color: SahneTokens.of(dialogContext).tx2,
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x3),
                  TextField(
                    key: const ValueKey('referral-code-input'),
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    // Girdi görünüşü temadan (Kulis, M pah, odakta Halka 2).
                    decoration: InputDecoration(
                      hintText: context.t(K.referralCodeHint),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.t(K.cancel)),
                ),
                // Diyaloğun tek birincil eylemi: Agir, koyu metin. Eski
                // düğme turuncu üstüne beyaz yazıyordu (2,35:1).
                SahneButton.primary(
                  key: const ValueKey('referral-code-submit'),
                  label: context.t(K.referralApplyAction),
                  arrow: false,
                  onPressed: submitting
                      ? null
                      : () async {
                          final code = controller.text.trim();
                          if (code.isEmpty) return;
                          setDialogState(() => submitting = true);
                          final result = await widget.repository
                              .redeemReferralCode(code);
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop();
                          if (!mounted) return;
                          if (result.isSuccess) {
                            HapticFeedback.mediumImpact();
                            _showMessage(context.t(K.referralCodeApplied));
                          } else {
                            final msg = switch (result.status) {
                              ReferralStatus.ownCode => context.t(
                                K.cannotUseOwnCode,
                              ),
                              ReferralStatus.alreadyRedeemed => context.t(
                                K.referralAlreadyUsed,
                              ),
                              ReferralStatus.notFound => context.t(
                                K.invalidReferralCode,
                              ),
                              ReferralStatus.notVerified => context.t(
                                K.referralGuestBlocked,
                              ),
                              _ => context.t(K.searchFailed),
                            };
                            _showMessage(msg);
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchSection(bool ku) {
    final t = SahneTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.findFriend)),
        // Tema girdisi (Kulis, M pah) + ikincil "Ara". Büyük yazıda düğme
        // girdinin altına iner; girdi daralıp ipucunu kaybetmez.
        KeyedSubtree(
          key: const ValueKey('friends-search-panel'),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final field = TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: context.t(K.searchByNameOrTag),
                  prefixIcon: Icon(AppIcons.magnifyingGlass, color: t.tx2),
                ),
              );
              final button = SahneButton.secondary(
                label: context.t(K.searchAction),
                icon: _searching ? AppIcons.hourglass : null,
                onPressed: _searching ? null : _search,
              );
              final stack =
                  MediaQuery.textScalerOf(context).scale(16) >= 24 ||
                  constraints.maxWidth < 280;
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: SahneSpace.x2),
                    button,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: SahneSpace.x2),
                  button,
                ],
              );
            },
          ),
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: SahneSpace.x3),
          SahneListGroup(
            dividerIndent: _PersonRow.dividerIndent,
            children: [
              for (final player in _searchResults)
                _PersonRow(
                  avatar: PlayerAvatar(
                    radius: 18,
                    colorHex: player.avatarColor,
                    displayName: player.displayName,
                  ),
                  title: player.displayName,
                  // Kod, iki aynı adı ayıran tek şey: adlar benzersiz değil
                  // ve olmayacak. Kodu olmayan eski profillerde satır hiç
                  // yazılmaz — uydurulmuş bir kod göstermektense yok saymak
                  // dürüst (2026-07-28).
                  subtitle: player.formattedTag,
                  subtitleStrong: player.formattedTag != null,
                  trailing: _sentRequests.contains(player.id)
                      ? _SentMark(label: context.t(K.requestSent))
                      : SahneButton.secondary(
                          label: context.t(K.addAction),
                          onPressed: () => _sendRequest(player),
                        ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRequestsSection(bool ku) {
    return FutureBuilder<List<FriendRequest>>(
      future: _requestsFuture,
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: SahneSpace.sectionTop),
            child: AppErrorState(
              title: context.t(K.requestsLoadFail),
              message: context.t(K.requestsLoadFailDot),
              retryLabel: context.t(K.retry),
              primaryAction: false,
              onRetry: () => setState(() {
                _requestsFuture = widget.repository.loadPendingFriendRequests();
              }),
            ),
          );
        }
        if (snap.data?.isEmpty ?? true) {
          return const SizedBox.shrink();
        }
        final requests = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SahneSectionHeader(title: context.t(K.pendingRequests)),
            SahneListGroup(
              dividerIndent: _PersonRow.dividerIndent,
              children: [
                for (final req in requests)
                  _FriendRequestRow(
                    request: req,
                    onAccept: () => _acceptRequest(req.id),
                    onReject: () => _rejectRequest(req.id),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildFriendsSection(bool ku) {
    return FutureBuilder<List<Friend>>(
      future: _friendsFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(SahneSpace.x6),
            child: Center(
              child: CircularProgressIndicator(
                color: SahneTokens.of(context).raceTx,
              ),
            ),
          );
        }
        if (snap.hasError) {
          return AppErrorState(
            title: context.t(K.loadFailedShort),
            message: context.t(K.friendsLoadFail),
            retryLabel: context.t(K.retryShort),
            primaryAction: false,
            onRetry: () => setState(_loadFriends),
          );
        }
        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return AppEmptyState(
            icon: AppIcons.peopleGroup,
            title: context.t(K.noFriends),
            message: context.t(K.noFriendsHint),
          );
        }
        return SahneListGroup(
          dividerIndent: _PersonRow.dividerIndent,
          children: [
            for (final friend in friends)
              _FriendRow(
                friend: friend,
                onPlay: () => _playWithFriend(friend),
                busy: _roomLoading,
              ),
          ],
        );
      },
    );
  }
}

/// Kişi satırı — [SahneListRow]'un ölçüleriyle, öncülü oyuncu avatarı.
///
/// `SahneListRow` öncül olarak yalnız ikon karosu, küçük resim ya da baş
/// harf alır; oyuncunun YÜKLEDİĞİ fotoğrafı ve seçtiği rengi taşıyan
/// [PlayerAvatar] için yuvası yok. Satır aynı ölçüleri kullanır: en az 64,
/// 12/8/16/8 iç boşluk, 36'lık elmas, 12 aralık, başlık Gövde 700, alt
/// satır Açıklama. Büyük yazıda sağdaki eylem metnin altına iner (başlık
/// dar sütunda harf harf bölünmez).
class _PersonRow extends StatelessWidget {
  const _PersonRow({
    super.key,
    required this.avatar,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.subtitleStrong = false,
    this.trailing,
    this.stackTrailing,
  });

  /// Grup ayırıcısının sol boşluğu: metnin hizası (12 + 36 + 12).
  static const double dividerIndent = SahneSpace.x3 + 36 + SahneSpace.x3;

  final Widget avatar;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final bool subtitleStrong;
  final Widget? trailing;

  /// `null`: yalnız büyük yazıda alta iner.
  final bool? stackTrailing;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          softWrap: true,
          style: SahneType.bodyStrong.copyWith(color: t.tx),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style:
                (subtitleStrong ? SahneType.captionStrong : SahneType.caption)
                    .copyWith(color: subtitleColor ?? t.tx2),
          ),
      ],
    );
    final stacked =
        stackTrailing ?? MediaQuery.textScalerOf(context).scale(16) >= 24;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x2,
          SahneSpace.x4,
          SahneSpace.x2,
        ),
        child: stacked && trailing != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      avatar,
                      const SizedBox(width: SahneSpace.x3),
                      Expanded(child: text),
                    ],
                  ),
                  const SizedBox(height: SahneSpace.x2),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: trailing,
                  ),
                ],
              )
            : Row(
                children: [
                  avatar,
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(child: text),
                  if (trailing != null) ...[
                    const SizedBox(width: SahneSpace.x2),
                    trailing!,
                  ],
                ],
              ),
      ),
    );
  }
}

/// İstek gönderildi işareti: Rast tonu kare + ✓ (söz ekran okuyucuya).
class _SentMark extends StatelessWidget {
  const _SentMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: t.okTint, shape: SahneShape.m),
        child: SizedBox.square(
          dimension: 44,
          child: Icon(AppIcons.circleCheck, size: 20, color: t.okTx),
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.onPlay,
    required this.busy,
  });

  final Friend friend;
  final VoidCallback onPlay;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final online = friend.isOnline;
    return _PersonRow(
      key: ValueKey('friend-row-${friend.friendName}'),
      // Çevrimiçi durumu yalnız renkle verilmez: elmasın köşesindeki küçük
      // elmas dolu (çevrimiçi) ya da boş (çevrimdışı) ve alt satırda söz.
      avatar: SizedBox.square(
        dimension: 40,
        child: Stack(
          children: [
            PlayerAvatar(
              radius: 18,
              colorHex: friend.friendAvatarColor,
              displayName: friend.friendName,
            ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: online ? t.okTx : t.s1,
                  shape: SahneShape.diamond(
                    14,
                    side: BorderSide(
                      color: online ? t.s1 : t.tx3,
                      width: SahneRing.r2,
                    ),
                  ),
                ),
                child: const SizedBox.square(dimension: 14),
              ),
            ),
          ],
        ),
      ),
      title: friend.friendName,
      subtitle: online ? context.t(K.online) : context.t(K.offline),
      subtitleColor: online ? t.okTx : t.tx2,
      subtitleStrong: online,
      // Düğme "Oyna" diyordu ama oyun başlatmıyor: bir oda kurup kodunu
      // arkadaşla paylaşmanı istiyor. Ad, yapılan işi anlatır — yeni
      // kullanıcının şaşırmaması ilk ölçüt (2026-07-26). Oda kurulurken
      // düğme pasifleşir (eskiden ikinci dokunuş sessizce yutuluyordu).
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: SahneButton.secondary(
          key: ValueKey('friend-action-${friend.friendName}'),
          label: context.t(K.inviteToRoom),
          icon: busy ? AppIcons.hourglass : null,
          onPressed: busy ? null : onPlay,
        ),
      ),
    );
  }
}

class _FriendRequestRow extends StatelessWidget {
  const _FriendRequestRow({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reddet: Kulis karo + ✗, 48'lik dokunma kutusu (görsel 44). Şaş
        // (yanlış) tonu bir cevap durumudur, bir eylemin rengi değil.
        Tooltip(
          message: context.t(K.rejectAction),
          excludeFromSemantics: true,
          child: Semantics(
            button: true,
            label: context.t(K.rejectAction),
            onTap: onReject,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onReject,
              child: SizedBox.square(
                dimension: 48,
                child: Center(
                  child: SahneTappable(
                    shape: SahneShape.m,
                    color: t.s2,
                    onTap: onReject,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(AppIcons.xmark, size: 20, color: t.tx2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: SahneSpace.x2),
        // Kabul ikincil: bir listede birden çok istek olabilir; ekranın tek
        // birincil eylemi değil.
        SahneButton.secondary(
          label: context.t(K.acceptAction),
          icon: AppIcons.check,
          onPressed: onAccept,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackActions = constraints.maxWidth < 380 || textScale > 1.3;
        return _PersonRow(
          avatar: PlayerAvatar(radius: 18, displayName: request.fromUserName),
          title: request.fromUserName,
          subtitle: context.t(K.wantsToBeFriend),
          trailing: actions,
          stackTrailing: stackActions,
        );
      },
    );
  }
}
