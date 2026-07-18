import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
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
      _showMessage(
        context.isKu ? 'Herî kêm 2 tîp binivîse' : 'En az 2 harf yazın',
      );
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await widget.repository.searchPlayers(query);
      if (!mounted) return;
      setState(() => _searchResults = results);
      if (results.isEmpty) {
        _showMessage(
          context.isKu ? 'Lîstikvan nehat dîtin' : 'Oyuncu bulunamadı',
        );
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'friends_load');
      if (mounted) {
        setState(() => _searching = false);
        _showMessage(
          context.isKu ? 'Lêgerîn bi ser neket.' : 'Arama başarısız oldu.',
        );
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
          .catchError((_) => false);
      _showMessage(context.isKu ? 'Daxwaz hat şandin' : 'İstek gönderildi');
    } else {
      _showMessage(
        context.isKu ? 'Daxwaz neçû, dîsa biceribîne' : 'İstek gönderilemedi',
      );
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    final success = await widget.repository.acceptFriendRequest(requestId);
    if (!mounted) return;
    if (success) {
      _showMessage(context.isKu ? 'Daxwaz hat qebûlkirin' : 'Arkadaş eklendi');
      setState(_loadFriends);
    } else {
      _showMessage(
        context.isKu ? 'Qebûlkirin bi ser neket.' : 'Kabul işlemi başarısız.',
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final success = await widget.repository.rejectFriendRequest(requestId);
    if (!mounted) return;
    if (success) {
      _showMessage(context.isKu ? 'Daxwaz hat redkirin' : 'İstek reddedildi');
      setState(_loadFriends);
    } else {
      _showMessage(
        context.isKu ? 'Redkirin bi ser neket.' : 'Red işlemi başarısız.',
      );
    }
  }

  /// Arkadaşla oynamak için özel oda açar; oda kodu arkadaşla paylaşılır.
  Future<void> _playWithFriend(Friend friend) async {
    if (_roomLoading) return;
    setState(() => _roomLoading = true);
    try {
      final room = await widget.repository.createOnlineRoom();
      if (!mounted) return;
      _showMessage(
        context.isKu
            ? 'Koda odeyê bi ${friend.friendName} re parve bike'
            : 'Oda kodunu ${friend.friendName} ile paylaş',
      );
      await Navigator.of(context).push(
        AppRoute.to(
          RoomScreen(repository: widget.repository, initialRoom: room),
        ),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'friends_action');
      if (mounted) {
        _showMessage(
          context.isKu ? 'Ode nehat avakirin' : 'Oda oluşturulamadı',
        );
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
      appBar: AppBar(title: Text(ku ? 'Hevalên Min' : 'Arkadaşlarım')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
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
                  title: ku ? 'Hevalên Min' : 'Arkadaşlarım',
                  subtitle: ku
                      ? 'Bigere, daxwaz bike û bi heval re bilîze'
                      : 'Ara, istek at ve arkadaşınla oyna',
                  accent: AppTheme.cyan,
                  icon: Icons.people_alt_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                // Çocuk modu: arkadaş arama ve yeni istek gönderme kapalı
                // (cihaz tarafı; mevcut arkadaşlar korunur).
                if (context.watch<ChildSafetyProvider>().allowFriendSearch) ...[
                  _buildSearchSection(ku),
                  const SizedBox(height: 24),
                ],
                _buildRequestsSection(ku),
                ScreenSectionLabel(
                  label: ku ? 'Hevalên Min' : 'Arkadaşlarım',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenSectionLabel(
          label: ku ? 'Heval Bibîne' : 'Arkadaş Bul',
          accent: AppTheme.cyan,
        ),
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('friends-search-panel'),
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppTheme.playCyan.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: AppTheme.playCyan.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: ku ? 'Navê lîstikvanî...' : 'Oyuncu adı...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _search,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandGreen,
                  foregroundColor: Colors.white,
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
                    : Text(ku ? 'Bigere' : 'Ara'),
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
                child: Row(
                  children: [
                    PlayerAvatar(radius: 22, colorHex: player.avatarColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        player.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _sentRequests.contains(player.id)
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.check_circle,
                              color: AppTheme.primaryGradientStart.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          )
                        : FilledButton.tonal(
                            onPressed: () => _sendRequest(player),
                            child: Text(ku ? 'Zêde bike' : 'Ekle'),
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
              title: ku ? 'Daxwaz nehatin barkirin' : 'İstekler yüklenemedi',
              message: ku
                  ? 'Daxwaz nehatin barkirin.'
                  : 'İstekler yüklenemedi.',
              retryLabel: ku ? 'Dîsa biceribîne' : 'Tekrar dene',
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
              label: ku ? 'Daxwazên Hevaltiyê' : 'Bekleyen İstekler',
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
            title: ku ? 'Barnebû' : 'Yüklenemedi',
            message: ku ? 'Heval nehatin barkirin' : 'Arkadaşlar yüklenemedi',
            retryLabel: ku ? 'Dîsa biceribîne' : 'Tekrar',
            onRetry: () => setState(_loadFriends),
          );
        }
        final friends = snap.data ?? [];
        if (friends.isEmpty) {
          return AppEmptyState(
            icon: Icons.people_outline,
            title: ku ? 'Heval tune' : 'Arkadaş yok',
            message: ku
                ? 'Li jorê lîstikvanan bigere û heval zêde bike'
                : 'Yukarıdan oyuncu arayıp arkadaş ekleyebilirsin',
          );
        }
        return Column(
          children: friends
              .map(
                (friend) => _FriendCard(
                  friend: friend,
                  ku: ku,
                  onPlay: () => _playWithFriend(friend),
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
  });

  final Friend friend;
  final bool ku;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final online = friend.isOnline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppPanel(
        key: ValueKey('friend-row-${friend.friendName}'),
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
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF9E9E9E),
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
                    online
                        ? (ku ? 'Çevrimiçi' : 'Çevrimiçi')
                        : (ku ? 'Offline' : 'Offline'),
                    style: TextStyle(
                      color: online
                          ? const Color(0xFF4CAF50)
                          : AppTheme.textMutedColor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              key: const ValueKey('friend-primary-action'),
              onPressed: onPlay,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.playPink.withValues(alpha: 0.14),
                foregroundColor: AppTheme.playPink,
              ),
              child: Text(ku ? 'Bilîze' : 'Oyna'),
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
        child: Row(
          children: [
            PlayerAvatar(radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                request.fromUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              onPressed: onReject,
              tooltip: ku ? 'Red bike' : 'Reddet',
              icon: const Icon(Icons.close_rounded, color: AppTheme.wrong),
            ),
            FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(ku ? 'Qebûl' : 'Kabul'),
            ),
          ],
        ),
      ),
    );
  }
}
