import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/friend.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
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
    } catch (_) {
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
      _showMessage(
        context.isKu ? 'Daxwaz hat şandin' : 'İstek gönderildi',
      );
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
      _showMessage(
        context.isKu ? 'Daxwaz hat qebûlkirin' : 'Arkadaş eklendi',
      );
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
    } catch (_) {
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
                _buildSearchSection(ku),
                const SizedBox(height: 24),
                _buildRequestsSection(ku),
                Text(
                  ku ? 'Hevalên Min' : 'Arkadaşlarım',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
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
        Text(
          ku ? 'Heval Bibîne' : 'Arkadaş Bul',
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Row(
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
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _sentRequests.contains(player.id)
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: AppTheme.accent.withValues(alpha: 0.8),
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
              retryLabel: ku ? 'Dîsa Biceribîne' : 'Tekrar Dene',
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
            Text(
              ku ? 'Daxwazên Hevaltiyê' : 'Bekleyen İstekler',
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
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
            message: ku
                ? 'Heval nehatin barkirin'
                : 'Arkadaşlar yüklenemedi',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppPanel(
        child: Row(
          children: [
            PlayerAvatar(radius: 28, colorHex: friend.friendAvatarColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.friendName,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ku ? 'Heval' : 'Arkadaş',
                    style: TextStyle(
                      color: AppTheme.textMutedColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onPlay,
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
              child: Text(ku ? 'Qebûl' : 'Kabul'),
            ),
          ],
        ),
      ),
    );
  }
}
