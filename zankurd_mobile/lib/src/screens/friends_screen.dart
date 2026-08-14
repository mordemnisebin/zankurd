import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/friend.dart';
import '../providers/child_safety_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/screen_identity_header.dart';
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sosyal bağ — camgöbeği kimlik (Xwendin/bağlantı ailesi).
                ScreenIdentityHeader(
                  title: context.t(K.myFriends),
                  subtitle: context.t(K.myFriendsSub),
                  accent: AppTheme.cyan,
                  icon: AppIcons.peopleGroup,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSearchSection(ku),
                const SizedBox(height: 24),
                _buildRequestsSection(ku),
                ScreenSectionLabel(
                  label: context.t(K.myFriends),
                  accent: AppTheme.cyan,
                ),
                const SizedBox(height: 12),
                _buildFriendsSection(ku),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool ku) {
    // `ChildSafetyProvider` eskiden hiçbir ekrandan okunmuyordu — çocuk
    // modu açılsa da kapansa da davranış aynı kalıyordu, ayarlardaki
    // anahtar süs düğmesiydi (2026-08-14 denetimi). Bu ekran onun ilk
    // gerçek kapısı: çocuk modu açıkken oyuncu arama kutusu hiç
    // gösterilmez.
    if (!context.watch<ChildSafetyProvider>().allowFriendSearch) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenSectionLabel(
            label: context.t(K.findFriend),
            accent: AppTheme.cyan,
          ),
          const SizedBox(height: 12),
          AppPanel(
            key: const ValueKey('friends-search-blocked'),
            color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
            child: Row(
              children: [
                const Icon(AppIcons.shield, color: AppTheme.cyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t(K.childSafetyFriendSearchBlocked),
                    style: TextStyle(color: AppTheme.textPrimaryColor(context)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenSectionLabel(
          label: context.t(K.findFriend),
          accent: AppTheme.cyan,
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('friends-search-panel'),
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: AppTheme.teaserCardDecoration(
            context,
            accent: AppTheme.cyan,
            radius: AppRadius.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: context.t(K.searchByNameOrTag),
                    prefixIcon: const Icon(AppIcons.magnifyingGlass),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _search,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.cyan,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: _searching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryGradientStart,
                        ),
                      )
                    : Text(context.t(K.searchAction)),
              ),
            ],
          ),
        ),
        if (_searchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._searchResults.map(
            (player) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppPanel(
                color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
                child: Row(
                  children: [
                    PlayerAvatar(
                      radius: 22,
                      colorHex: player.avatarColor,
                      displayName: player.displayName,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            player.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          // Kod, iki aynı adı ayıran tek şey: adlar
                          // benzersiz değil ve olmayacak. Kodu olmayan
                          // eski profillerde satır hiç yazılmaz —
                          // uydurulmuş bir kod göstermektense yok saymak
                          // dürüst (2026-07-28).
                          if (player.formattedTag != null)
                            Text(
                              player.formattedTag!,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.onAccentTint(
                                  context,
                                  AppTheme.cyan,
                                ),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            )
                          else
                            Text(
                              context.t(K.requestFromHere),
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.textMutedColor(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _sentRequests.contains(player.id)
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.correct.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.correct.withValues(alpha: 0.20),
                              ),
                            ),
                            child: Icon(
                              AppIcons.circleCheck,
                              color: AppTheme.correct.withValues(alpha: 0.9),
                            ),
                          )
                        : FilledButton.tonal(
                            onPressed: () => _sendRequest(player),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.cyan.withValues(
                                alpha: 0.14,
                              ),
                              foregroundColor: AppColors.onAccentTint(
                                context,
                                AppTheme.cyan,
                              ),
                            ),
                            child: Text(context.t(K.addAction)),
                          ),
                  ],
                ),
              ),
            ),
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
            padding: const EdgeInsets.all(16),
            child: AppErrorState(
              title: context.t(K.requestsLoadFail),
              message: context.t(K.requestsLoadFailDot),
              retryLabel: context.t(K.retry),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenSectionLabel(
              label: context.t(K.pendingRequests),
              accent: AppTheme.cyan,
            ),
            const SizedBox(height: 12),
            ...requests.map(
              (req) => _FriendRequestCard(
                request: req,
                onAccept: () => _acceptRequest(req.id),
                onReject: () => _rejectRequest(req.id),
                ku: ku,
              ),
            ),
            const SizedBox(height: 24),
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
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryGradientStart,
            ),
          );
        }
        if (snap.hasError) {
          return AppErrorState(
            title: context.t(K.loadFailedShort),
            message: context.t(K.friendsLoadFail),
            retryLabel: context.t(K.retryShort),
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
        return Column(
          children: friends
              .map(
                (friend) => _FriendCard(
                  friend: friend,
                  ku: ku,
                  onPlay: () => _playWithFriend(friend),
                  busy: _roomLoading,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.ku,
    required this.onPlay,
    required this.busy,
  });

  final Friend friend;
  final bool ku;
  final VoidCallback onPlay;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final online = friend.isOnline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppPanel(
        key: ValueKey('friend-row-${friend.friendName}'),
        color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
        child: Row(
          children: [
            // Avatar with online dot
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                children: [
                  PlayerAvatar(
                    radius: 28,
                    colorHex: friend.friendAvatarColor,
                    displayName: friend.friendName,
                  ),
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: online
                            ? AppTheme.onlineGreen
                            : AppTheme.offlineGrey,
                        border: Border.all(
                          color: AppTheme.surfaceColor(context),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.friendName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    online ? (context.t(K.online)) : (context.t(K.offline)),
                    style: TextStyle(
                      color: online
                          ? AppTheme.correct
                          : AppTheme.textMutedColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Düğme "Oyna" diyordu ama oyun başlatmıyor: bir oda kurup
            // kodunu arkadaşla paylaşmanı istiyor. Çevrimdışı bir arkadaşta
            // bile aynı sözü veriyordu. Ad, yapılan işi anlatır — yeni
            // kullanıcının şaşırmaması ilk ölçüt (2026-07-26).
            // Düğme büyük yazıda satırı taşırıyordu; genişliği sınırlanıp
            // etiketi kısalabilir hâle getirildi (2026-07-26).
            Flexible(
              child: FilledButton.tonal(
                key: ValueKey('friend-action-${friend.friendName}'),
                onPressed: busy ? null : onPlay,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.cyan.withValues(alpha: 0.14),
                  // Ham aksan, kendi tonlu zemininde boğuluyordu: koyu
                  // temada ölçümde 2.49:1 — etiket sönük çıkıyor ve düğme
                  // kapalıymış gibi okunuyordu (2026-07-27).
                  foregroundColor: AppColors.onAccentTint(
                    context,
                    AppTheme.cyan,
                  ),
                ),
                child: busy
                    // Oda kurulurken düğme sessizce ölüydü: ikinci dokunuş
                    // `_roomLoading` kontrolüne takılıp hiçbir iz bırakmıyordu.
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        context.t(K.inviteToRoom),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestCard extends StatelessWidget {
  const _FriendRequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.ku,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppPanel(
        color: AppTheme.surfaceOf(context).withValues(alpha: 0.96),
        child: Row(
          children: [
            PlayerAvatar(radius: 24, displayName: request.fromUserName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.fromUserName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.t(K.wantsToBeFriend),
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.wrong.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: IconButton(
                onPressed: onReject,
                tooltip: context.t(K.rejectAction),
                icon: const Icon(AppIcons.xmark, color: AppTheme.wrong),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.cyan,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: Text(context.t(K.acceptAction)),
            ),
          ],
        ),
      ),
    );
  }
}
