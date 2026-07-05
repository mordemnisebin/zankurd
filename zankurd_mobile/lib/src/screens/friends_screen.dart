import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/friend.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';

/// Arkadaş listesi ve arkadaş yönetimi ekranı
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late Future<List<Friend>> _friendsFuture;
  late Future<List<FriendRequest>> _requestsFuture;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  void _loadFriends() {
    _friendsFuture = widget.repository.loadFriends();
    _requestsFuture = widget.repository.loadPendingFriendRequests();
  }

  void _acceptFriendRequest(String requestId) async {
    final success = await widget.repository.acceptFriendRequest(requestId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.isKu ? 'Hevalbûn qebûl kir' : 'Arkadaş eklendi',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() => _loadFriends());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Hevalên Xwe' : 'Arkadaşlar')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bekleyen istekler
                FutureBuilder<List<FriendRequest>>(
                  future: _requestsFuture,
                  builder: (ctx, snap) {
                    if (snap.hasError || (snap.data?.isEmpty ?? true)) {
                      return const SizedBox.shrink();
                    }
                    final requests = snap.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ku ? 'Davetnameyên Ciwan' : 'Bekleyen İstekler',
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
                            onAccept: () => _acceptFriendRequest(req.id),
                            ku: ku,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
                // Arkadaş listesi
                Text(
                  ku ? 'Hevalên Xwe' : 'Arkadaşlar',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Friend>>(
                  future: _friendsFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return AppErrorState(
                        title: ku ? 'Barnekirî' : 'Yüklenemedi',
                        message: ku
                            ? 'Hevalên xwe yüklenê de'
                            : 'Arkadaşlar yüklenemedi',
                        retryLabel: ku ? 'Dûbare' : 'Tekrar',
                        onRetry: () => setState(() => _loadFriends()),
                      );
                    }
                    final friends = snap.data ?? [];
                    if (friends.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.people_outline,
                        title: ku ? 'Heval tune' : 'Arkadaş yok',
                        message: ku
                            ? 'Hûn dikarin hevalê xwe bibînin'
                            : 'Henüz arkadaş eklememediniz',
                      );
                    }
                    return Column(
                      children: friends
                          .map((friend) => _FriendCard(friend: friend, ku: ku))
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

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend, required this.ku});

  final Friend friend;
  final bool ku;

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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ku ? 'Pisporî pêş nayê' : 'Yakında mevcut olacak',
                    ),
                  ),
                );
              },
              child: Text(ku ? 'Bila' : 'Oyna'),
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
    required this.ku,
  });

  final FriendRequest request;
  final VoidCallback onAccept;
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
