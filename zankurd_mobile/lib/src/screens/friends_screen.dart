import 'dart:async';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../utils/profile_tab_request.dart';

import '../data/zankurd_repository.dart';
import '../config/feature_flags.dart';
import '../models/referral_result.dart';
import '../utils/player_identity.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/add_friend_outcome.dart';
import '../models/friend.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/player_avatar.dart';
import '../widgets/player_moderation_button.dart';
import '../widgets/sahne/sahne.dart';
import 'async_duel/async_duel_challenge_sheet.dart';
import 'room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../widgets/dialog_action_pair.dart';
import '../services/social_push_prompt.dart';

/// Arkadaş listesi, oyuncu arama ve istek yönetimi ekranı.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    required this.repository,
    this.asyncDuelEnabled = kAsyncDuelEnabled,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Sırayla düello bayrağı; kapalıyken satırın birincil eylemi canlı oda
  /// daveti olarak kalır. Varsayılanı [kAsyncDuelEnabled].
  final bool asyncDuelEnabled;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with WidgetsBindingObserver {
  /// Ekran açıkken hafif yenileme aralığı: gelen istek ve kabuller ekrana
  /// yeniden girmeden görünsün (2026-10-21 iki simülatör turu).
  static const _pollInterval = Duration(seconds: 20);
  Timer? _pollTimer;
  bool _reloading = false;

  final TextEditingController _searchController = TextEditingController();

  late Future<List<Friend>> _friendsFuture;
  late Future<List<FriendRequest>> _requestsFuture;

  /// Davet kodu, ekran açılırken BİR kez istenir.
  ///
  /// `FutureBuilder(future: repository.getPlayerTag())` doğrudan `build`
  /// içinde yazılıydı: ekranın her `setState`i (arama kutusuna her harf,
  /// istek gönderme, oda açma) Supabase'e yeni bir `profiles` sorgusu
  /// atıyor ve davet düğmesi bekleme anına geri dönüp titriyordu. Davet
  /// kodu oturum boyunca değişmez; sonuç doğruydu, yalnız her yeniden
  /// çizimde ağ gidiş-dönüşü ödeniyordu.
  late final Future<String?> _playerTagFuture;

  /// Sunucuda meydan okuma RPC'leri var mı; arkadaş satırının birincil
  /// eyleminin ne olacağını belirler. Satırlar sonuç gelene dek çizilmez
  /// (önce "Odaya çağır", sonra "Meydan oku"ya dönen düğme zıplatırdı);
  /// hata `false` sayılır ve sonuç depoda önbelleğe alınır.
  late final Future<bool> _challengeFuture;
  List<PlayerSearchResult> _searchResults = const [];
  int _searchEpoch = 0;
  bool _searching = false;
  bool _roomLoading = false;

  /// Bu ekranda şimdi gönderdiğim istekler (sunucu yanıtı gelene dek
  /// iyimser). Asıl kaynak [_sentServer]; sunucu listesi gelince bununla
  /// değiştirilir.
  final Set<String> _sentRequests = {};

  /// Sunucudan okunan sosyal durum: arama sonuçlarının satırı ("Ekle" /
  /// "Gönderildi" / "Kabul" / "Arkadaşın") bunlardan seçilir.
  ///
  /// Eskiden "gönderildi" yalnız ekranın belleğindeydi ve arkadaş/gelen istek
  /// durumuna hiç bakılmıyordu: zaten arkadaş olunan ya da bize istek
  /// göndermiş biri için "Ekle" görünüyor, dokunuş sunucuda sessizce
  /// reddedilip genel "İstek gönderilemedi" çıkıyordu.
  Set<String> _friendIds = const {};
  Map<String, FriendRequest> _incomingByUser = const {};

  /// Gönderdiğim bekleyen istekler. `null` → sunucuda arkadaş yönetimi
  /// RPC'leri yok (ya da henüz yüklenmedi): "geri çek" ve "arkadaşlıktan
  /// çıkar" eylemleri sessizce gizlenir.
  List<SentFriendRequest>? _sentServer;
  int _socialEpoch = 0;

  bool get _managementSupported => _sentServer != null;

  bool _isSent(String userId) =>
      _sentRequests.contains(userId) ||
      (_sentServer?.any((request) => request.toUserId == userId) ?? false);

  @override
  void initState() {
    super.initState();
    _playerTagFuture = widget.repository.getPlayerTag();
    _challengeFuture = widget.asyncDuelEnabled
        ? asyncDuelChallengeAvailable(widget.repository)
        : Future<bool>.value(false);
    _loadFriends();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => unawaited(_reload()));
  }

  /// Arka planda yoklama durur (pil, veri, Supabase kotası); dönüşte bir
  /// kez tazelenir ve döngü yeniden kurulur (bkz. leaderboard_screen).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_reload());
        _startPolling();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _pollTimer?.cancel();
        _pollTimer = null;
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Listeleri sunucudan yeniden okur. Uçuştaki istek varken ikincisi
  /// başlamaz; hata sessizce yutulur (bölüm eski veriyi gösterir).
  Future<void> _reload() async {
    if (_reloading || !mounted) return;
    _reloading = true;
    try {
      final friends = widget.repository.loadFriends();
      final requests = widget.repository.loadPendingFriendRequests();
      final friendList = await friends;
      final requestList = await requests;
      if (!mounted) return;
      // SynchronousFuture: FutureBuilder tamamlanmış veriyi aynı karede
      // çizer; her turda bir kare dönen göstergesi titremez.
      setState(() {
        _friendsFuture = SynchronousFuture(friendList);
        _requestsFuture = SynchronousFuture(requestList);
      });
      await _refreshSocialState();
    } catch (_) {
      // Eski veri ekranda kalır; bir sonraki turda yeniden denenir.
    } finally {
      _reloading = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _loadFriends() {
    _friendsFuture = widget.repository.loadFriends();
    _requestsFuture = widget.repository.loadPendingFriendRequests();
    unawaited(_refreshSocialState());
  }

  /// Arkadaş / gelen istek / gönderilen istek kümelerini sunucudan yeniler.
  /// Yükleme hataları ilgili bölümün kendi hata durumunda görünür; burada
  /// yutulur ve satırlar "Ekle"ye düşer.
  Future<void> _refreshSocialState() async {
    final epoch = ++_socialEpoch;
    try {
      final friends = await _friendsFuture;
      final requests = await _requestsFuture;
      final sent = await widget.repository.loadSentFriendRequests();
      if (!mounted || epoch != _socialEpoch) return;
      setState(() {
        _friendIds = {for (final friend in friends) friend.friendId};
        _incomingByUser = {
          for (final request in requests) request.fromUserId: request,
        };
        _sentServer = sent;
        if (sent != null) {
          _sentRequests
            ..clear()
            ..addAll(sent.map((request) => request.toUserId));
        }
      });
    } catch (_) {
      // Bölümler kendi hatasını gösterir (FutureBuilder).
    }
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
    final epoch = ++_searchEpoch;
    setState(() => _searching = true);
    try {
      final results = await widget.repository.searchPlayers(query);
      if (!mounted || epoch != _searchEpoch) return;
      setState(() => _searchResults = results);
      if (results.isEmpty) {
        _showMessage(context.t(K.playerNotFound));
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'friends_load');
      if (mounted && epoch == _searchEpoch) {
        setState(() => _searching = false);
        _showMessage(context.t(K.searchFailed));
      }
      return;
    } finally {
      if (mounted && epoch == _searchEpoch) {
        setState(() => _searching = false);
      }
    }
  }

  /// Süren istek/yanıt işlemleri (kişi/istek kimliği başına). Çift dokunuş
  /// ikinci bir RPC göndermesin; o sırada düğme pasif.
  final Set<String> _busyIds = <String>{};

  Future<void> _sendRequest(PlayerSearchResult player) async {
    if (!_busyIds.add(player.id)) return;
    setState(() {});
    AddFriendOutcome outcome;
    try {
      outcome = await widget.repository.addFriend(
        player.id,
        player.displayName,
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'friend_request_send');
      outcome = AddFriendOutcome.failed;
    } finally {
      _busyIds.remove(player.id);
    }
    if (!mounted) return;
    // Meşgul durumu kalktı: düğme her sonuçta yeniden çizilsin. Erken dönen
    // dallar (zaten arkadaş, engelli, hız sınırı) setState çağırmıyordu ve
    // düğme başka bir çizime kadar "yükleniyor" kalıyordu (2026-10-24 dış
    // inceleme, iki model uyuştu).
    setState(() {});
    // Sunucunun cevabı ayrıştırılır; her sonuç kendi cümlesini alır (bkz.
    // test/friend_request_outcome_test.dart). Karşılıklı istek sunucuda
    // otomatik kabul edilirse "istek gönderildi" demek yanlış olurdu.
    if (outcome == AddFriendOutcome.alreadyFriends) {
      _showMessage(context.t(K.friendAlreadyFriends));
      return;
    }
    if (outcome == AddFriendOutcome.alreadyPending) {
      setState(() => _sentRequests.add(player.id));
      _showMessage(context.t(K.friendRequestAlreadyPending));
      return;
    }
    if (outcome == AddFriendOutcome.blocked) {
      _showMessage(context.t(K.friendRequestBlocked));
      return;
    }
    if (outcome == AddFriendOutcome.rateLimited) {
      _showMessage(context.t(K.friendRequestRateLimited));
      return;
    }
    if (outcome.isSuccess) {
      setState(() => _sentRequests.add(player.id));
      if (outcome == AddFriendOutcome.autoAccepted) {
        // Arkadaşlık kuruldu: liste ve istekler tazelenir.
        setState(_loadFriends);
      }
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
      _showMessage(
        context.t(
          outcome == AddFriendOutcome.autoAccepted
              ? K.requestAccepted
              : K.requestSent,
        ),
      );
      await SocialPushPrompt.maybeAsk(context);
    } else {
      _showMessage(context.t(K.requestFailed));
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    if (!_busyIds.add(requestId)) return;
    setState(() {});
    bool success;
    try {
      success = await widget.repository.acceptFriendRequest(requestId);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'friend_request_accept');
      success = false;
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(requestId));
      }
    }
    if (!mounted) return;
    if (success) {
      _showMessage(context.t(K.requestAccepted));
      setState(_loadFriends);
      await SocialPushPrompt.maybeAsk(context);
    } else {
      _showMessage(context.t(K.acceptFailed));
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    if (!_busyIds.add(requestId)) return;
    setState(() {});
    bool success;
    try {
      success = await widget.repository.rejectFriendRequest(requestId);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'friend_request_reject');
      success = false;
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(requestId));
      }
    }
    if (!mounted) return;
    if (success) {
      _showMessage(context.t(K.requestRejected));
      setState(_loadFriends);
    } else {
      _showMessage(context.t(K.rejectFailed));
    }
  }

  Future<void> _cancelRequest(SentFriendRequest request) async {
    final success = await widget.repository.cancelFriendRequest(
      request.toUserId,
    );
    if (!mounted) return;
    if (success) {
      _showMessage(context.t(K.requestCancelled));
      setState(() {
        _sentRequests.remove(request.toUserId);
        _loadFriends();
      });
    } else {
      _showMessage(context.t(K.requestCancelFailed));
    }
  }

  Future<void> _confirmRemoveFriend(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          dialogContext.t(K.removeFriendTitle, {
            'name': context.playerDisplayName(
              friend.friendName,
              tag: friend.friendTag,
            ),
          }),
        ),
        content: Text(dialogContext.t(K.removeFriendBody)),
        actions: [
          DialogActionPair(
            cancel: TextButton(
              key: const ValueKey('friend-remove-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.t(K.cancel)),
            ),
            confirm: SahneButton.primary(
              key: const ValueKey('friend-remove-confirm'),
              label: dialogContext.t(K.removeFriendConfirm),
              arrow: false,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await widget.repository.removeFriend(friend.friendId);
    if (!mounted) return;
    if (success) {
      _showMessage(context.t(K.friendRemoved));
      setState(_loadFriends);
    } else {
      _showMessage(context.t(K.friendRemoveFailed));
    }
  }

  /// Arkadaş ya da istek gönderen için bildir/engelle alt sayfası (Apple
  /// 1.2: araç içeriğin karşılaşıldığı yerde). Engel/bildirim sonrası
  /// listeler yeniden okunur.
  void _openModeration(String playerId, String playerName) {
    void refresh() {
      if (mounted) setState(_loadFriends);
    }

    unawaited(
      showPlayerModerationSheet(
        context: context,
        repository: widget.repository,
        playerId: playerId,
        playerName: playerName,
        onBlocked: refresh,
        onReported: refresh,
      ),
    );
  }

  /// Arkadaşla oynamak için özel oda açar; oda kodu arkadaşla paylaşılır.
  Future<void> _playWithFriend(Friend friend) async {
    if (_roomLoading) return;
    setState(() => _roomLoading = true);
    try {
      final room = await widget.repository.createOnlineRoom();
      if (!mounted) return;
      await SocialPushPrompt.maybeAsk(context);
      if (!mounted) return;
      _showMessage(
        context.t(K.shareRoomCodeWith, {
          'name': context.playerDisplayName(
            friend.friendName,
            tag: friend.friendTag,
          ),
        }),
      );
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
      role: SahneRole.social,
      title: context.t(K.myFriends),
      backLabel: context.t(K.back),
      onRefresh: _reload,
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
                _buildSearchSection(ku),
                if (kReferralRewardsEnabled) ...[
                  const SizedBox(height: SahneSpace.x4),
                  _buildInviteSection(ku),
                ],
                _buildRequestsSection(ku),
                _buildSentSection(),
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
    // 2026-10-20 renk ve canlılık (B): sosyal mod Nîl; davet kartı dolu Nîl
    // kahraman (beyaz yazı, cam jeton karosu, beyaz tonal Paylaş düğmesi).
    return SahneHeroSurface(
      key: const ValueKey('friends-invite-panel'),
      role: SahneRole.social,
      kilim: false,
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Builder(
              builder: (context) {
                const tile = DecoratedBox(
                  decoration: ShapeDecoration(
                    color: SahneVivid.glass,
                    shape: SahneShape.m,
                  ),
                  child: SizedBox.square(
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
                      context.t(K.inviteCardTitle),
                      style: SahneType.bodyStrong.copyWith(
                        color: SahneVivid.onFill,
                      ),
                    ),
                    Text(
                      context.t(K.inviteSubtitle),
                      style: SahneType.caption.copyWith(
                        color: SahneVivid.onFillSoft,
                      ),
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
              future: _playerTagFuture,
              builder: (context, snapshot) {
                final rawTag = snapshot.data;
                // Kod her yerde "ZK-4F7K" biçiminde görünür ve paylaşılır:
                // profil rozeti panoya böyle kopyalıyor, arama ve davet
                // kodu girişi de bu biçimi bekliyor (`search_profiles`
                // "ZK-4F7K" ve "4F7K"yı aynı kodla eşler). 2026-09-30 canlı:
                // bu düğme çıplak "7RHC" yazıyordu, profil "ZK-7RHC".
                final tag = rawTag != null && rawTag.isNotEmpty
                    ? (rawTag.toUpperCase().startsWith('ZK-')
                          ? rawTag
                          : 'ZK-$rawTag')
                    : null;
                final share = tag != null
                    ? SahneButton.tonal(
                        tint: SahneVivid.onFill,
                        foreground: t.nilOnWhite,
                        key: const ValueKey('friends-share-code-button'),
                        // "Paylaş · ZK-4F7K": düğme kodun kendisi gibi
                        // okunuyordu, ne yaptığı söylenmiyordu (kurul
                        // 2026-10-20). Mevcut `K.share` sözü; "Kodumu paylaş"
                        // yeni söz olurdu (NEEDS_JURY).
                        label: '${context.t(K.share)} · $tag',
                        icon: AppIcons.shareNodes,
                        expand: true,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          // Davet metni mağaza bağlantılarını da taşır: alıcı
                          // kodu görüp uygulamayı nereden bulacağını bilsin.
                          final text =
                              '${context.t(K.inviteShareText, {'tag': tag})}'
                              '\n${context.t(K.inviteStoreLinks, {'ios': AppConfig.appStoreUrl, 'play': AppConfig.playStoreUrl})}';
                          SharePlus.instance.share(ShareParams(text: text));
                        },
                      )
                    : null;
                final enter = SahneButton.tonal(
                  // D aşaması (2 model): cam dolgu kart zeminine karışıyordu;
                  // belirgin yarı saydam beyaz dolgu + ince beyaz kenar.
                  tint: SahneVivid.glassButton,
                  edge: SahneVivid.glassButtonEdge,
                  foreground: SahneVivid.onFill,
                  key: const ValueKey('friends-enter-code-button'),
                  label: context.t(K.enterReferralCode),
                  icon: AppIcons.coins,
                  expand: true,
                  onPressed: () => _showReferralDialog(ku),
                );
                // Misafir kendi kodunu paylaşabilir ama başkasının kodunu
                // KULLANAMAZ: sunucu "yalnız doğrulanmış hesaplar" diye
                // reddediyordu (2026-10-21 iki simülatör turu). Ölü düğme
                // yerine misafirde hiç çizilmez; hesabı kaydetme yolu
                // Profil'dedir.
                // Misafirin kodu yok: ödül yalnız doğrulanmış hesaba yazılır,
                // kod göstermek ölü bir vaat olurdu. Yerine hesabı kaydetme
                // yolu (Profil sekmesindeki "Hesabını kaydet") gösterilir.
                if (_isGuestSession(context)) {
                  return Column(
                    key: const ValueKey('friends-invite-guest'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.t(K.inviteGuestSave),
                        style: SahneType.bodyStrong.copyWith(
                          color: SahneVivid.onFill,
                        ),
                      ),
                      const SizedBox(height: SahneSpace.x3),
                      SahneButton.tonal(
                        tint: SahneVivid.onFill,
                        foreground: t.nilOnWhite,
                        key: const ValueKey('friends-invite-save-account'),
                        label: context.t(K.saveAccount),
                        icon: AppIcons.userPlus,
                        expand: true,
                        onPressed: () {
                          Navigator.of(context).popUntil((r) => r.isFirst);
                          ProfileTabRequest.request();
                        },
                      ),
                    ],
                  );
                }
                if (share == null) return enter;
                // İki düğme HER ZAMAN alt alta: yan yana yarım genişlikte
                // "Koda vexwendinê" iki satıra kırılıyordu (2026-09-30
                // canlı); etiketi kısaltmak yerine düğmeye tam genişlik
                // verilir.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInviteCodeRow(tag!),
                    const SizedBox(height: SahneSpace.x3),
                    share,
                    const SizedBox(height: SahneSpace.x2),
                    enter,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Kullanıcının KENDİ davet kodu: büyük, okunur ve tek dokunuşla kopyalanır.
  ///
  /// Kusur: kod yalnız "Paylaş · ZK-4F7K" düğmesinin etiketinde yaşıyordu;
  /// kullanıcılar kodlarını bulamadıklarını söyledi (2026-10-24). Panoya
  /// kopyalama profil rozetindeki gibi `K.playerTagCopied` ile bildirilir.
  Widget _buildInviteCodeRow(String tag) {
    return DecoratedBox(
      key: const ValueKey('friends-invite-code-row'),
      decoration: const ShapeDecoration(
        color: SahneVivid.glass,
        shape: SahneShape.m,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          start: SahneSpace.x4,
          top: SahneSpace.x1,
          bottom: SahneSpace.x1,
          end: SahneSpace.x1,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t(K.inviteYourCode),
                    style: SahneType.caption.copyWith(
                      color: SahneVivid.onFillSoft,
                    ),
                  ),
                  Text(
                    tag,
                    key: const ValueKey('friends-invite-code-text'),
                    style: SahneType.headline.copyWith(
                      color: SahneVivid.onFill,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('friends-copy-code-button'),
              tooltip: context.t(K.inviteCopyCode),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              color: SahneVivid.onFill,
              icon: const Icon(AppIcons.copy),
              onPressed: () async {
                HapticFeedback.selectionClick();
                await Clipboard.setData(ClipboardData(text: tag));
                if (!mounted) return;
                _showMessage(context.t(K.playerTagCopied));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Oturum misafir mi? Sağlayıcı yoksa (yalın testler) `false`.
  bool _isGuestSession(BuildContext context) {
    try {
      return context.read<AuthProvider>().isGuest;
    } on ProviderNotFoundException {
      return false;
    }
  }

  Future<void> _showReferralDialog(bool ku) async {
    // Kod alanının denetleyicisini diyalogun kendi State'i yönetir (bkz.
    // [_ReferralDialog]). Eskiden burada yaratılıp HİÇ atılmıyordu; atılsaydı
    // da kapanış animasyonunda çöküş riski vardı.
    final result = await showDialog<ReferralResult>(
      context: context,
      builder: (_) => _ReferralDialog(repository: widget.repository),
    );
    if (result == null || !mounted) return;
    if (result.isSuccess) {
      HapticFeedback.mediumImpact();
      _showMessage(context.t(K.referralCodeApplied));
    } else {
      final msg = switch (result.status) {
        ReferralStatus.ownCode => context.t(K.cannotUseOwnCode),
        ReferralStatus.alreadyRedeemed => context.t(K.referralAlreadyUsed),
        ReferralStatus.notFound => context.t(K.invalidReferralCode),
        ReferralStatus.notVerified => context.t(K.referralGuestBlocked),
        ReferralStatus.notActive => context.t(K.referralNeedsPlay),
        _ => context.t(K.searchFailed),
      };
      _showMessage(msg);
    }
  }

  Widget _buildSearchSection(bool ku) {
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
              final field = SahneField.search(
                controller: _searchController,
                hintText: context.t(K.searchByNameOrTag),
                onSubmitted: (_) => _search(),
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
                  avatar: PlayerAvatar.fromIdentity(
                    radius: 18,
                    identity: player.profile?.avatar,
                    fallbackColorHex: player.avatarColor,
                    displayName: player.displayName,
                  ),
                  title: context.playerDisplayName(
                    player.displayName,
                    tag: player.playerTag,
                  ),
                  // Kod, iki aynı adı ayıran tek şey: adlar benzersiz değil
                  // ve olmayacak. Kodu olmayan eski profillerde satır hiç
                  // yazılmaz — uydurulmuş bir kod göstermektense yok saymak
                  // dürüst (2026-07-28).
                  subtitle:
                      PlayerIdentity.isPlaceholderDisplayName(
                        player.displayName,
                      )
                      ? null
                      : player.formattedTag,
                  subtitleStrong: player.formattedTag != null,
                  trailing: _searchTrailing(player),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Arama sonucu satırının sağ tarafı: durum sunucudan gelen kümelerden
  /// seçilir (arkadaş > bana gelen istek > gönderdiğim istek > "Ekle").
  Widget _searchTrailing(PlayerSearchResult player) {
    if (_friendIds.contains(player.id)) {
      return SahneBadge(
        key: ValueKey('search-friend-${player.id}'),
        label: context.t(K.friendAlreadyMark),
      );
    }
    final incoming = _incomingByUser[player.id];
    if (incoming != null) {
      return SahneButton.primary(
        key: ValueKey('search-accept-${player.id}'),
        label: context.t(K.acceptAction),
        icon: AppIcons.check,
        arrow: false,
        onPressed: () => _acceptRequest(incoming.id),
      );
    }
    if (_isSent(player.id)) {
      return _SentMark(label: context.t(K.requestSent));
    }
    return SahneButton.secondary(
      key: ValueKey('search-add-${player.id}'),
      label: context.t(K.addAction),
      onPressed: () => _sendRequest(player),
    );
  }

  /// Gönderdiğim, yanıtlanmamış istekler; her satırda "geri çek". Sunucuda
  /// RPC yoksa ([_sentServer] `null`) ya da liste boşsa hiç görünmez.
  Widget _buildSentSection() {
    final sent = _sentServer;
    if (sent == null || sent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.sentRequestsTitle)),
        SahneListGroup(
          key: const ValueKey('friends-sent-requests'),
          dividerIndent: _PersonRow.dividerIndent,
          children: [
            for (final request in sent)
              _PersonRow(
                key: ValueKey('sent-request-${request.toUserId}'),
                avatar: PlayerAvatar.fromIdentity(
                  radius: 18,
                  identity: request.toProfile?.avatar,
                  displayName: request.toUserName,
                ),
                title: context.playerDisplayName(
                  request.toUserName,
                  tag: request.toProfile?.playerTag,
                ),
                subtitle: context.t(K.requestAwaiting),
                trailing: SahneButton.secondary(
                  key: ValueKey('sent-cancel-${request.toUserId}'),
                  label: context.t(K.cancelRequestAction),
                  onPressed: () => unawaited(_cancelRequest(request)),
                ),
                // Etiket dar telefonda (390) adın yanına sığmaz: eylem
                // adın altına iner (_FriendRequestRow ile aynı kural).
                stackTrailing: true,
              ),
          ],
        ),
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
                    busy: _busyIds.contains(req.id),
                    onAccept: () => _acceptRequest(req.id),
                    onReject: () => _rejectRequest(req.id),
                    onModerate: () => _openModeration(
                      req.fromUserId,
                      context.playerDisplayName(
                        req.fromUserName,
                        tag: req.fromProfile?.playerTag,
                      ),
                    ),
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
        return FutureBuilder<bool>(
          future: _challengeFuture,
          builder: (ctx, challengeSnap) {
            if (challengeSnap.connectionState != ConnectionState.done) {
              return Padding(
                padding: const EdgeInsets.all(SahneSpace.x6),
                child: Center(
                  child: CircularProgressIndicator(
                    color: SahneTokens.of(context).raceTx,
                  ),
                ),
              );
            }
            final canChallenge = challengeSnap.data ?? false;
            return SahneListGroup(
              dividerIndent: _PersonRow.dividerIndent,
              children: [
                for (final friend in friends)
                  _FriendRow(
                    friend: friend,
                    onPlay: () => _playWithFriend(friend),
                    onChallenge: canChallenge
                        ? () => unawaited(
                            startFriendChallenge(
                              context,
                              widget.repository,
                              friend.friendId,
                            ),
                          )
                        : null,
                    busy: _roomLoading,
                    onRemove: _managementSupported
                        ? () => unawaited(_confirmRemoveFriend(friend))
                        : null,
                    onModerate: () => _openModeration(
                      friend.friendId,
                      context.playerDisplayName(
                        friend.friendName,
                        tag: friend.friendTag,
                      ),
                    ),
                  ),
              ],
            );
          },
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
/// Arkadaş satırındaki meydan okuma düğmesi: simge + kısa metin, 44 yükseklik.
///
/// 9. kurul (Opus + ChatGPT, kare 13/46/65): tek başına kılıç simgesinin anlamı
/// belli değildi. Metin ("Meydan oku") simgeyle birlikte durur; satırdaki
/// ikincil eylemdir (turuncu birincil değil): çerçeveli, şeffaf.
class _ChallengePill extends StatelessWidget {
  const _ChallengePill({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final enabled = onPressed != null;
    final fg = enabled ? t.tx : t.tx3;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: SahneIconButton.visualSize,
          maxWidth: 176,
        ),
        child: SahneTappable(
          shape: SahneShape.withSide(SahneShape.m, t.edge, width: 1),
          color: t.s1,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x3,
              vertical: SahneSpace.x2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.swords, size: 20, color: fg),
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SahneType.captionStrong.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    this.onChallenge,
    this.onRemove,
    this.onModerate,
  });

  final Friend friend;

  /// Bildir/engelle alt sayfası (Apple 1.2); `null` → menüde görünmez.
  final VoidCallback? onModerate;

  /// Arkadaşlıktan çıkar; `null` → sunucuda `remove_friend` yok, eylem
  /// görünmez.
  final VoidCallback? onRemove;

  /// Canlı oda daveti. [onChallenge] varken sakin ikincil eylemdir; yokken
  /// satırın tek (yazılı) eylemi.
  final VoidCallback onPlay;

  /// Sırayla meydan okuma; `null` → sunucu/bayrak desteklemiyor.
  final VoidCallback? onChallenge;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final online = friend.isOnline;
    return _PersonRow(
      key: ValueKey('friend-row-${friend.friendName}'),
      // Çevrimiçi durumu yalnız renkle verilmez: avatarın köşesindeki küçük
      // nokta dolu (çevrimiçi) ya da boş (çevrimdışı) ve alt satırda söz.
      // 2026-09-29 doğallık: nokta elmastı; elmas yalnız soru ilerlemesi ve
      // ders sayacı anlamını taşır (K5). Durum noktası yuvarlaktır.
      avatar: SizedBox.square(
        dimension: 40,
        child: Stack(
          children: [
            PlayerAvatar.fromIdentity(
              radius: 18,
              identity: friend.friendAvatar,
              fallbackColorHex: friend.friendAvatarColor,
              displayName: friend.friendName,
            ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: online ? t.okTx : t.s1,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: online ? t.s1 : t.tx3,
                      width: SahneRing.r2,
                    ),
                  ),
                ),
                child: const SizedBox.square(dimension: 12),
              ),
            ),
          ],
        ),
      ),
      title: context.playerDisplayName(
        friend.friendName,
        tag: friend.friendTag,
      ),
      subtitle: online ? context.t(K.online) : context.t(K.offline),
      subtitleColor: online ? t.okTx : t.tx2,
      subtitleStrong: online,
      // Uzun etiket (KU "Vexwîne pêşbirkê") ad sütununu daraltıp adı ve
      // "Ne li serhêl"i sarıyordu: eylemler adın altına iner (tur 10a).
      stackTrailing:
          onChallenge != null && context.t(K.challengeFriendAction).length > 12
          ? true
          : null,
      // 2026-10-14: ürünün günlük aktif oyuncusu 3-25; iki arkadaşın aynı
      // anda çevrimiçi olması neredeyse hiç yok. Canlı oda daveti oyuncuyu
      // boş bir lobide bekletiyordu. Birincil eylem sırayla meydan okumadır
      // (arkadaş sonra oynar, bildirim alır).
      //
      // 7. kurul (Opus 6. tur + ChatGPT 7. tur): her arkadaşın altındaki iki
      // büyük çerçeveli düğme listeyi düğme yığınına çeviriyordu. Satır içi,
      // sağda: meydan oku simge düğmesi (44) + "⋯" menüsü ("Odaya çağır",
      // "Arkadaşlıktan çıkar"). Meydan okuma yoksa (RPC'ler sunucuda yok ya
      // da bayrak kapalı) yazılı "Odaya çağır" düğmesi kalır. Oda kurulurken
      // eylemler pasifleşir (eskiden ikinci dokunuş sessizce yutuluyordu).
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onChallenge != null)
            _ChallengePill(
              key: ValueKey('friend-action-${friend.friendName}'),
              label: context.t(K.challengeFriendAction),
              semanticLabel: context.t(K.challengeFriendActionA11y, {
                'name': context.playerDisplayName(
                  friend.friendName,
                  tag: friend.friendTag,
                ),
              }),
              onPressed: busy ? null : onChallenge,
            )
          else
            SahneButton.secondary(
              key: ValueKey('friend-action-${friend.friendName}'),
              label: context.t(K.inviteToRoom),
              icon: busy ? AppIcons.hourglass : null,
              onPressed: busy ? null : onPlay,
            ),
          if (onChallenge != null ||
              onRemove != null ||
              onModerate != null) ...[
            const SizedBox(width: SahneSpace.x1),
            SahneIconButton(
              key: ValueKey('friend-more-${friend.friendName}'),
              icon: AppIcons.ellipsis,
              quiet: true,
              semanticLabel: context.t(K.moreOptions),
              onPressed: () => _openMenu(context),
            ),
          ],
        ],
      ),
    );
  }

  void _openMenu(BuildContext context) {
    unawaited(
      showSahneSheet<void>(
        context: context,
        title: context.playerDisplayName(
          friend.friendName,
          tag: friend.friendTag,
        ),
        builder: (sheetContext) => SahneListGroup(
          children: [
            if (onChallenge != null)
              SahneListRow.icon(
                key: ValueKey('friend-room-${friend.friendName}'),
                icon: AppIcons.doorOpen,
                title: context.t(K.inviteToRoom),
                onTap: busy
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        onPlay();
                      },
              ),
            if (onRemove != null)
              SahneListRow.icon(
                key: ValueKey('friend-remove-${friend.friendName}'),
                icon: AppIcons.xmark,
                title: context.t(K.removeFriendAction),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onRemove!();
                },
              ),
            if (onModerate != null)
              SahneListRow.icon(
                key: ValueKey('friend-moderate-${friend.friendName}'),
                icon: AppIcons.flag,
                title: context.t(K.reportProfileTitle),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onModerate!();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestRow extends StatelessWidget {
  const _FriendRequestRow({
    required this.request,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    this.onModerate,
  });

  final FriendRequest request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  /// Bildir/engelle alt sayfası (Apple 1.2): istek gönderenin avatarı ve
  /// adı da kullanıcı içeriğidir.
  final VoidCallback? onModerate;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    void reject() {
      if (!busy) onReject();
    }

    final actions = <Widget>[
      if (onModerate != null) ...[
        SahneIconButton(
          key: ValueKey('friend-request-more-${request.id}'),
          icon: AppIcons.ellipsis,
          quiet: true,
          semanticLabel: context.t(K.reportProfileTitle),
          onPressed: onModerate,
        ),
        const SizedBox(width: SahneSpace.x1),
      ],
      // Reddet: Kulis karo + ✗, 48'lik dokunma kutusu (görsel 44). Şaş
      // (yanlış) tonu bir cevap durumudur, bir eylemin rengi değil.
      Tooltip(
        message: context.t(K.rejectAction),
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: context.t(K.rejectAction),
          onTap: reject,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: reject,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: SahneTappable(
                  // Kurul 5. tur 2026-10-20 (Grok): gri ✗ gri karoda
                  // görünmüyordu; birincil renk + görünür kenar.
                  shape: SahneShape.withSide(
                    SahneShape.m,
                    t.secondaryEdge,
                    width: 1.5,
                  ),
                  color: t.s2,
                  onTap: reject,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Icon(AppIcons.xmark, size: 20, color: t.tx),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: SahneSpace.x2),
      // Kurul 2026-10-20 (Opus): Kabul bekleyen isteğin ASIL eylemidir,
      // reddet ikon düğmesi yanında sessiz kalır; bu yüzden birincil
      // (turuncu). Eskiden ikincildi (bir listede birden çok istek olur
      // gerekçesiyle) ve "Reddet"le aynı gri yüzeydeydi.
      SahneButton.primary(
        label: context.t(K.acceptAction),
        icon: AppIcons.check,
        arrow: false,
        onPressed: busy ? null : onAccept,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final stackActions = constraints.maxWidth < 380 || textScale > 1.3;
        return _PersonRow(
          avatar: PlayerAvatar.fromIdentity(
            radius: 18,
            identity: request.fromProfile?.avatar,
            displayName: request.fromUserName,
          ),
          title: context.playerDisplayName(
            request.fromUserName,
            tag: request.fromProfile?.playerTag,
          ),
          // Büyük metinde "⋯" + Reddet + Kabul dar ekrana sığmayabilir:
          // alt satıra sarılır, taşmaz.
          trailing: stackActions
              ? Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: SahneSpace.x2,
                  children: actions,
                )
              : Row(mainAxisSize: MainAxisSize.min, children: actions),
          stackTrailing: stackActions,
        );
      },
    );
  }
}

/// Davet kodu girme diyaloğu. Denetleyiciyi kendi State'i yaratır ve atar;
/// kodu sunucuda kullanır ve sonucu `Navigator.pop` ile çağırana verir
/// (mesaj/haptik çağıranın işi).
class _ReferralDialog extends StatefulWidget {
  const _ReferralDialog({required this.repository});

  final ZanKurdRepository repository;

  @override
  State<_ReferralDialog> createState() => _ReferralDialogState();
}

class _ReferralDialogState extends State<_ReferralDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final navigator = Navigator.of(context);
      final result = await widget.repository.redeemReferralCode(code);
      if (!mounted) return;
      navigator.pop(result);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // 2026-09-25: zemin ve yarıçap `AppTheme._dialogTheme`ten
      // geliyor. Buradaki `AppRadius.card` (14) temanın `md` (16)
      // değerinden farklıydı; uygulamada 14/16/20 karışık yarıçaplı
      // üç ayrı diyalog dili oluşmuştu.
      title: Text(
        context.t(K.enterReferralCode),
        style: SahneType.headline.copyWith(color: SahneTokens.of(context).tx),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t(K.enterReferralCodeHint),
            style: SahneType.caption.copyWith(
              color: SahneTokens.of(context).tx2,
            ),
          ),
          const SizedBox(height: SahneSpace.x3),
          SahneField(
            key: const ValueKey('referral-code-input'),
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            hintText: context.t(K.referralCodeHint),
            semanticLabel: context.t(K.referralCodeHint),
          ),
        ],
      ),
      actions: [
        DialogActionPair(
          cancel: TextButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: Text(context.t(K.cancel)),
          ),
          // Diyaloğun tek birincil eylemi: Agir, koyu metin. Eski
          // düğme turuncu üstüne beyaz yazıyordu (2,35:1).
          confirm: SahneButton.primary(
            key: const ValueKey('referral-code-submit'),
            label: context.t(K.referralApplyAction),
            arrow: false,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ],
    );
  }
}
