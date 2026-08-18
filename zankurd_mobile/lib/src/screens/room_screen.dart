import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/room_chat.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/floating_reaction_overlay.dart';
import '../widgets/player_moderation_button.dart';
import '../widgets/styled_button.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Odadan çıkış RPC'sinin beklenebileceği en uzun süre.
///
/// `quiz_screen.dart`teki `_onlineResultRequestTimeout` ile aynı bütçe:
/// çevrimiçi çağrıların geri kalanı zaten bu sınırla korunuyor. Süre
/// dolduğunda çağrı hata vermiş sayılır ve mevcut — test edilmiş — hata
/// yoluna düşer: lobi geri gelir, snackbar çıkar, çıkış yeniden denenebilir.
const Duration _roomLeaveTimeout = Duration(seconds: 15);

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    required this.repository,
    required this.initialRoom,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom initialRoom;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  /// Sohbet paneli açık mı. Kapalı başlar: aa42044'ün kalabalık kaygısı
  /// haklıydı, ama çözümü sohbeti silmek değil katlamaktı.
  bool _chatOpen = false;

  late GameRoom room = widget.initialRoom;

  /// Kullanıcı anahtara *elle* dokunduysa dediği geçer; dokunmadıysa
  /// sunucudaki gerçek durum gösterilir.
  ///
  /// Eskiden burada düpedüz `bool ready = true` vardı ve anahtar herkeste
  /// açık başlıyordu. Ev sahibinde bu doğruydu: `createOnlineRoom` satırı
  /// `is_ready: true` ile ekliyor. Ama `join_room_by_code` katılan oyuncuyu
  /// `is_ready = false` ile ekliyor — yani odaya katılan kişi kendi
  /// ekranında "Hazırım: açık" görürken, oyuncu listesinde "Bekliyor"
  /// yazıyordu ve ev sahibi yarışı başlatamıyordu. Çıkış yolu (anahtarı
  /// kapatıp yeniden açmak) hiçbir yerde yazmıyordu.
  ///
  /// Kusur tek cihazda görünmüyordu: ev sahibi olarak açan kişi hiçbir
  /// zaman uyuşmazlığı yaşamıyor. 2026-08-01'de Android'den oda kurulup
  /// iOS'tan katılınca ortaya çıktı.
  bool? _readyOverride;

  /// Bu oturumda engellenen oyuncuların kimlikleri; satırları buradan
  /// süzülür.
  ///
  /// `PlayerModerationButton.onBlocked` tanımlıydı ama HİÇBİR çağrı
  /// yerinde bağlanmamıştı — engelleme sunucuda başarıyla işleniyor,
  /// düğme "Oyuncu engellendi" diyordu, ama aynı kişinin satırı odada
  /// durmaya devam ediyordu; kullanıcı ekranı kapatıp açana kadar
  /// (o zaman `room.players` yeniden çekiliyordu) engellediği kişiyi
  /// görmeye devam ediyordu (2026-08-14 denetimi). `room.players`ın
  /// kendisi değişmiyor bilerek: engelleme oyuncuyu odadan ATMAZ, yalnız
  /// istemcide GÖRÜNMEZ kılar — `room_chat.dart`taki `_blockedSenderIds`
  /// ile aynı yerel süzgeç deseni.
  final Set<String> _blockedPlayerIds = <String>{};

  bool get ready {
    final chosen = _readyOverride;
    if (chosen != null) return chosen;
    final me = room.players.where((p) => p.id == _currentUserId).firstOrNull;
    // Liste henüz gelmediyse rolün varsayılanı doğrudur: odayı kuran
    // `is_ready: true` ile eklenir, katılan `is_ready = false` ile. Burada
    // koşulsuz `true` demek, katılanın ekranında anahtarı bir an açık
    // gösterip sonra kapatıyordu — hazır olmadığı hâlde hazır sandıran bir
    // kırpışma.
    if (me == null) return _isHost;
    return me.state == Player.readyState;
  }

  /// Oda sahibi miyim? `hostId` boşsa oda yerel/sahte depodadır ve tek
  /// oyuncu ev sahibidir.
  bool get _isHost => room.hostId == null || room.hostId == _currentUserId;

  String? get _currentUserId => widget.repository.currentUserId;
  bool starting = false;
  bool quizOpened = false;
  bool _leaving = false;
  bool _terminalHandled = false;
  StreamSubscription? _playersSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _broadcastSub;
  final FloatingReactionController _reactionController =
      FloatingReactionController();
  int _subscriptionGeneration = 0;

  /// `_navigateToQuiz` soru yüklemesi kaç kez üst üste başarısız oldu.
  ///
  /// Eskiden bu sayaç yoktu: yükleme düşünce `_resumeLobbyMonitoring()`
  /// lobi izlemesini yeniden açıyordu, izleme de sunucuda oda hâlâ
  /// `active` gördüğü için `_navigateToQuiz`ı HEMEN yeniden çağırıyordu —
  /// sunucu tarafı sorun sürdükçe host'u 3 saniyede bir aynı hatayı
  /// tekrarlayan sessiz bir döngüye sokuyordu (2026-08-14 denetimi).
  /// Sınır aşılınca `_questionLoadExhausted` otomatik tetiklemeyi durdurur;
  /// kullanıcı görünür bir hata + "yeniden dene" düğmesiyle karşılaşır.
  static const _maxQuestionLoadAttempts = 3;
  int _questionLoadAttempts = 0;
  bool _questionLoadExhausted = false;

  /// Realtime yetersiz kalırsa devreye giren polling fallback.
  /// Yalnızca lobide en az 2 oyuncu görülünce durur; aksi halde devam eder.
  Timer? _pollTimer;
  Timer? _statusPollTimer;
  int _pollCount = 0;
  bool _pollThrottled = false;
  static const _pollInterval = Duration(seconds: 3);
  static const _maxPollsBeforePause = 20; // ~60s, yalnızca >=2 oyuncu varken

  @override
  void initState() {
    super.initState();
    _startSubscriptions();
    _startPolling();
    _startStatusPolling();
    // Burada `updateReady(room, ready)` YOK — ve olmamalı.
    //
    // Eskiden vardı ve `ready` sabit `true` olduğu için zararsızdı: odaya
    // giren herkes kendini hazır ilan ediyordu. `ready` sunucudaki gerçek
    // durumdan beslenmeye başlayınca aynı satır kendi kuyruğunu ısırdı:
    //
    //   1. `joinOnlineRoom` katılanın hazır olduğunu sunucuya bildirir,
    //   2. oda ekranı açılır ve `room.players` HÂLÂ katılış anındaki
    //      listedir — o listede katılan `is_ready = false`,
    //   3. `ready` getter'ı o listeden false okur,
    //   4. bu satır sunucuya false yazar ve 1. adımı siler.
    //
    // Ev sahibi katılanı sonsuza dek "Li bendê" görüyordu. Yazma yolu
    // artık tek: giriş varsayılanını sunucu koyar (`create_online_room`
    // ev sahibini hazır, `join_room_by_code` katılanı hazır DEĞİL ekler),
    // sonrasında yalnız kullanıcının anahtara dokunması yazar
    // (2026-08-01, 2026-08-13'te katılanın otomatik hazır sayılması
    // kaldırılınca güncellendi).
  }

  void _startSubscriptions() {
    if (_leaving ||
        _terminalHandled ||
        quizOpened ||
        _playersSub != null ||
        _statusSub != null) {
      return;
    }
    final generation = ++_subscriptionGeneration;
    _playersSub = widget.repository
        .subscribeRoomPlayers(room)
        .listen(
          (p) {
            if (!mounted || generation != _subscriptionGeneration) return;
            _applyPlayerList(p);
          },
          onError: (err, stack) {
            if (!mounted ||
                generation != _subscriptionGeneration ||
                _leaving ||
                _terminalHandled) {
              return;
            }
            _startPolling();
          },
        );
    _statusSub = widget.repository
        .subscribeRoomStatus(room)
        .listen(
          (status) {
            if (!mounted ||
                generation != _subscriptionGeneration ||
                _leaving ||
                _terminalHandled) {
              return;
            }
            if (status == RoomStatus.finished) {
              _handleLobbyFinished();
              return;
            }
            if (status == RoomStatus.active &&
                !quizOpened &&
                !_questionLoadExhausted) {
              _pausePolling();
              _pauseStatusPolling();
              _navigateToQuiz();
            }
            setState(() => room = room.copyWith(status: status));
          },
          onError: (err, stack) {
            if (!mounted ||
                generation != _subscriptionGeneration ||
                _leaving ||
                _terminalHandled) {
              return;
            }
            _startPolling();
          },
        );

    final roomId = room.id;
    if (roomId != null && _broadcastSub == null) {
      _broadcastSub = widget.repository.subscribeRoomBroadcast(roomId).listen((
        payload,
      ) {
        if (!mounted || generation != _subscriptionGeneration) return;
        if (payload['type'] == 'reaction') {
          final text = payload['text'] as String?;
          final senderId = payload['sender_id'] as String?;
          final senderName = payload['sender_name'] as String?;
          if (text != null && senderId != _currentUserId) {
            _reactionController.triggerReaction(text, senderName: senderName);
          }
        }
      });
    }
  }

  void _applyPlayerList(List<Player> players) {
    if (!mounted || _leaving || _terminalHandled || quizOpened) return;
    setState(() => room = room.copyWith(players: players));
    _syncPollingForLobby(players.length);
  }

  /// Lobide yedek yoklama AÇIK kalır; yalnız yarış başlayınca durur.
  ///
  /// Eskiden `playerCount >= 2` görülür görülmez yoklama kalıcı olarak
  /// duruyordu. Niyet yorumda yazıyordu: "Realtime yetersizse host, 2.
  /// oyuncuyu polling ile görür." Yani yedek yalnız KATILIMI görmek için
  /// tasarlanmıştı ve katılan görülünce kapanıyordu.
  ///
  /// Ama lobide değişen tek şey katılım değil — hazır durumu da değişiyor,
  /// üstelik tam olarak katılımdan SONRA: `join_room_by_code` oyuncuyu
  /// `is_ready = false` ile ekliyor, katılan kendi durumunu hemen ardından
  /// bildiriyor. Yoklama tam o arada kapandığı için ev sahibi ikinci
  /// oyuncuyu sonsuza dek "Li bendê" görüyordu. Ekranın vaadi
  /// ("Rewşa te ... rasterast ... tê nîşandan") yalnız realtime'a kalıyor,
  /// o da bu tabloda gelmiyordu (2026-08-01, Android ev sahibi + iOS
  /// katılan).
  ///
  /// Lobi kısa ömürlüdür ve 3 saniyelik yoklamanın pil maliyeti buradadır
  /// — yarış başlar başlamaz `quizOpened` ile duruyor.
  void _syncPollingForLobby(int playerCount) {
    if (quizOpened) {
      _pausePolling();
      return;
    }
    // `_pollThrottled` olmadan bu satır, aşağıdaki 60sn'lik pil kısıtını
    // ilk realtime olayında geri açardı: kısıt `_pollTimer`ı null yapıyor,
    // burası da null gördüğü an yeniden başlatıyor.
    if (_pollTimer == null && !_pollThrottled) {
      _startPolling();
    }
  }

  /// Realtime yetersizse host, 2. oyuncuyu polling ile görür.
  void _startPolling() {
    if (_leaving || _terminalHandled || quizOpened) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollPlayersOnce());
  }

  void _startStatusPolling() {
    if (_leaving || _terminalHandled || quizOpened) return;
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(
      _pollInterval,
      (_) => _pollRoomStatusOnce(),
    );
  }

  Future<void> _pollPlayersOnce() async {
    if (!mounted || quizOpened) return;
    try {
      final players = await widget.repository.loadRoomPlayers(room);
      if (!mounted || _leaving || _terminalHandled || quizOpened) return;
      _applyPlayerList(players);
      if (players.length < 2) {
        _pollCount = 0;
      } else {
        _pollCount++;
        if (_pollCount >= _maxPollsBeforePause) {
          _pollThrottled = true;
          _pausePolling();
          Future.delayed(const Duration(seconds: 15), () {
            if (!mounted) return;
            _pollThrottled = false;
            _pollCount = 0;
            if (!quizOpened) _startPolling();
          });
        }
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'loadRoomPlayers poll failed');
    }
  }

  Future<void> _pollRoomStatusOnce() async {
    if (!mounted || quizOpened) return;
    try {
      final status = await widget.repository.loadRoomStatus(room);
      if (!mounted || quizOpened || _leaving || _terminalHandled) return;
      if (status == RoomStatus.finished) {
        _handleLobbyFinished();
        return;
      }
      if (status == RoomStatus.active &&
          !quizOpened &&
          !_questionLoadExhausted) {
        _pausePolling();
        _pauseStatusPolling();
        await _navigateToQuiz();
        return;
      }
      if (status != room.status) {
        setState(() => room = room.copyWith(status: status));
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'loadRoomStatus poll failed');
    }
  }

  void _pausePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _pauseStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
  }

  @override
  void dispose() {
    _cancelSubscriptionsBestEffort('room_dispose_subscription_cancel_failed');
    _pausePolling();
    _pauseStatusPolling();
    super.dispose();
  }

  Future<void> _leaveRoom() async {
    if (_leaving || _terminalHandled) return;
    setState(() {
      _leaving = true;
    });

    _cancelSubscriptionsBestEffort('room_leave_subscription_cancel_failed');
    _pausePolling();
    _pauseStatusPolling();

    if (room.id != null) {
      try {
        await widget.repository
            .leaveOnlineRoom(room)
            .timeout(_roomLeaveTimeout);
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'room_leave_failed');
        if (!mounted) return;
        setState(() => _leaving = false);
        _resumeLobbyMonitoring();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.t(K.roomLeaveFailed))));
        return;
      }
    } else {
      // Yerel odada sunucu oturumu yoktur. Hazırlık durumunu sıfırlama
      // mevcut en iyi-niyetli davranıştır; başarısız olması yerel
      // ekrandan çıkışı engellememelidir.
      try {
        await widget.repository.updateReady(room, false);
      } catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'room_leave_update_ready_failed',
        );
      }
    }

    if (!mounted) return;
    _returnToPreviousRoute();
  }

  /// "Hazırım" anahtarına dokunuşu sunucuya yazar.
  ///
  /// Eskiden anahtar iyimser (optimistic) güncelleniyor ve `updateReady`
  /// çağrısı fire-and-forget bırakılıyordu: sunucu yazması RPC/ağ
  /// hatasıyla düşse bile `_readyOverride` asla geri alınmıyordu.
  /// Kullanıcı anahtarı "açık" görürken sunucudaki gerçek satır hâlâ eski
  /// değerdeydi — host'un `allPlayersReady` kontrolü sessizce takılıyordu
  /// (2026-08-14 denetimi). Şimdi hata durumunda önceki değere dönülür ve
  /// kullanıcı bir snackbar ile bilgilendirilir.
  Future<void> _toggleReady(bool v) async {
    final previousOverride = _readyOverride;
    setState(() => _readyOverride = v);
    try {
      await widget.repository.updateReady(room, v);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room_update_ready_failed');
      if (!mounted) return;
      setState(() => _readyOverride = previousOverride);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.t(K.readyUpdateFailed))));
    }
  }

  void _resumeLobbyMonitoring() {
    if (!mounted || quizOpened || _terminalHandled) return;
    _startSubscriptions();
    _startPolling();
    _startStatusPolling();
  }

  void _cancelSubscriptionsBestEffort(String failureReason) {
    final playersSub = _playersSub;
    final statusSub = _statusSub;
    final broadcastSub = _broadcastSub;
    _playersSub = null;
    _statusSub = null;
    _broadcastSub = null;
    // Bazı Stream uygulamaları `cancel()` Future'ını geç veya hiç
    // tamamlamaz. Nesil anahtarı eski olayları hemen geçersiz kılar;
    // fiziksel temizliği beklemek çıkış RPC'sini bloke etmez.
    _subscriptionGeneration++;
    if (playersSub != null) {
      unawaited(_cancelSubscription(playersSub, failureReason));
    }
    if (statusSub != null) {
      unawaited(_cancelSubscription(statusSub, failureReason));
    }
    if (broadcastSub != null) {
      unawaited(_cancelSubscription(broadcastSub, failureReason));
    }
  }

  Future<void> _sendReaction(String text) async {
    final roomId = room.id;
    final me = room.players.where((p) => p.id == _currentUserId).firstOrNull;
    final myName = me?.name ?? 'Tu';
    _reactionController.triggerReaction(text, senderName: myName);
    if (roomId == null) return;
    try {
      await widget.repository.sendRoomBroadcast(roomId, {
        'type': 'reaction',
        'text': text,
        'sender_name': myName,
        'sender_id': _currentUserId,
      });
    } catch (_) {}
  }

  Future<void> _cancelSubscription(
    StreamSubscription subscription,
    String failureReason,
  ) async {
    try {
      await subscription.cancel();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: failureReason);
    }
  }

  void _returnToPreviousRoute() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    // Widget bir test/yerleştirme kabında kök rota olarak açılmışsa
    // güvenli bir geri hedef yoktur; ekranı kilitli bırakma.
    setState(() => _leaving = false);
  }

  void _handleLobbyFinished() {
    // Quiz açıldıktan sonra maçın terminal durumu QuizScreen'in
    // sorumluluğudur. Geç gelen lobi olayı aktif maç rotasını kapatmamalı.
    if (!mounted || quizOpened || _leaving || _terminalHandled) return;
    _terminalHandled = true;
    _cancelSubscriptionsBestEffort('room_finished_subscription_cancel_failed');
    _pausePolling();
    _pauseStatusPolling();

    final message = context.t(K.roomClosedByHost);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!messenger.mounted) return;
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      });
      return;
    }

    // Normal uygulama akışında RoomScreen daima bir önceki rotanın
    // üstüne açılır. Yine de kök rota olarak yerleştirilirse kapandığını
    // açıkça göster; geçersiz bir geri işlemi yapma.
    setState(() => room = room.copyWith(status: RoomStatus.finished));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyRoomCode(BuildContext context, bool ku) async {
    await Clipboard.setData(ClipboardData(text: room.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t(K.roomCodeCopied, {'code': room.code}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final sorted = [...room.players]
      ..sort((a, b) => b.score.compareTo(a.score));
    // `room.players` (yukarıdaki `sorted`) kasten süzülmez: oda üyeliği,
    // `canStart`/`allPlayersReady` gibi oyun mantığı hâlâ GERÇEK listeye
    // bakmalı. Yalnız EKRANDA çizilen satırlar süzülür.
    final visiblePlayers = sorted
        .where((p) => p.id == null || !_blockedPlayerIds.contains(p.id))
        .toList();
    final isHost = _isHost;
    final allPlayersReady = room.players.every(
      (player) => player.state == Player.readyState,
    );
    // Yeterli oyuncu var ama biri hazır değil: düğme kapalı kalır ve
    // SEBEBİ yazılır. Tek satırlık uyarı şeridi eskiden yalnız "2 oyuncu
    // gerekli" diyordu; katılan hazır olmadan başlanamadığı hâlde ev
    // sahibi kapalı düğmeye bakıp niçinini bilemiyordu.
    final waitingForReady = room.players.length >= 2 && !allPlayersReady;
    final canStart =
        isHost &&
        ready &&
        !starting &&
        room.players.length >= 2 &&
        allPlayersReady;
    if (_leaving) {
      return Scaffold(
        body: Container(
          color: AppTheme.bgOf(context),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppTheme.playCyan),
                const SizedBox(height: 24),
                Text(
                  context.t(K.leavingRoom),
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      // Sunucu çıkışı onaylamadan sistem geri hareketi rotayı
      // kapatmamalı. İkinci geri/ikon dokunuşunu `_leaving` tekilleştirir.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _leaveRoom();
      },
      child: Scaffold(
        body: FloatingReactionOverlay(
          controller: _reactionController,
          child: Container(
            color: AppTheme.bgOf(context),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.md,
                        AppSpacing.page,
                        AppSpacing.lg,
                      ),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: SizedBox(
                              key: const ValueKey('room-content-width'),
                              width: double.infinity,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _leaving ? null : _leaveRoom,
                                        tooltip: context.t(K.leaveRoom),
                                        icon: Icon(
                                          AppIcons.arrowLeft,
                                          color: AppTheme.textSubColor(context),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Serbest metin oda sohbeti; raporlama,
                                      // engelleme ve moderasyon tamamlanana kadar
                                      // mağaza sürümünde erişilemez.
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),

                                  // Brand hero — deep green (not generic blue Material)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
                                    child: Stack(
                                      children: [
                                        AppPanel(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppTheme.playCyan,
                                              Color(0xFF168E8A),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                context.t(K.privateRoom),
                                                style: AppTypography.caption
                                                    .copyWith(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.75,
                                                          ),
                                                    ),
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.xs,
                                              ),
                                              Text(
                                                room.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.heading1
                                                    .copyWith(
                                                      color: Colors.white,
                                                      fontSize: 26,
                                                    ),
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.sm,
                                              ),
                                              Wrap(
                                                spacing: AppSpacing.xs,
                                                runSpacing: AppSpacing.xs,
                                                children: [
                                                  _Pill(
                                                    // Ham kategori kimliği
                                                    // gösteriliyordu: TR
                                                    // arayüzde oda "Ziman",
                                                    // kategori sekmesinde ise
                                                    // aynı kategori "Dil"
                                                    // görünüyordu (2026-07-22
                                                    // canlı UX denetimi).
                                                    label:
                                                        CategoryNames.localized(
                                                          room.category,
                                                          context.isKu,
                                                        ),
                                                    icon: AppIcons.tableCells,
                                                  ),
                                                  _Pill(
                                                    // 2026-08-14 görsel
                                                    // denetimi: "sn" sabit
                                                    // kodlanmıştı,
                                                    // Kurmancî ekranda da
                                                    // aynen basılıyordu —
                                                    // play_hub_screen.dart'ta
                                                    // düzeltilen aynı kusur,
                                                    // burada gözden kaçmış.
                                                    label:
                                                        '${room.secondsPerQuestion} ${context.t(K.secondsShortUnit)}',
                                                    icon: AppIcons.stopwatch,
                                                  ),
                                                  _Pill(
                                                    label:
                                                        '${room.questionCount} ${context.t(K.soru)}',
                                                    icon:
                                                        AppIcons.circleQuestion,
                                                  ),
                                                  if (room.entryFee > 0)
                                                    _Pill(
                                                      label:
                                                          '${room.entryFee} ${context.t(K.coinWord)}',
                                                      icon: AppIcons.coins,
                                                    ),
                                                  if (isHost)
                                                    _Pill(
                                                      label: context.t(K.host),
                                                      icon: AppIcons.star,
                                                    ),
                                                  // Guest tarafında da mêvandar bilgisi
                                                  // görünsün: host'ta 3 çip, guest'te 2
                                                  // çip kalıyordu (bilgi asimetrisi).
                                                  if (!isHost)
                                                    _Pill(
                                                      label: context.t(
                                                        K.hostNamed,
                                                        {
                                                          'name': _hostName(
                                                            room,
                                                          ),
                                                        },
                                                      ),
                                                      icon: AppIcons.star,
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(
                                                height: AppSpacing.md,
                                              ),
                                              // Large invite code for sharing
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  key: const ValueKey(
                                                    'room-code-copy',
                                                  ),
                                                  onTap: () => _copyRoomCode(
                                                    context,
                                                    ku,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.sm,
                                                      ),
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              AppSpacing.md,
                                                          vertical:
                                                              AppSpacing.md,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.96,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppRadius.sm,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.12,
                                                              ),
                                                          blurRadius: 12,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                context.t(
                                                                  K.roomCodeTapCopy,
                                                                ),
                                                                style: AppTypography
                                                                    .caption
                                                                    .copyWith(
                                                                      color: AppTheme
                                                                          .lightTextSub,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              FittedBox(
                                                                fit: BoxFit
                                                                    .scaleDown,
                                                                alignment: Alignment
                                                                    .centerLeft,
                                                                child: Text(
                                                                  room.code,
                                                                  key: const ValueKey(
                                                                    'room-code',
                                                                  ),
                                                                  maxLines: 1,
                                                                  softWrap:
                                                                      false,
                                                                  style: AppTypography.display.copyWith(
                                                                    color: AppTheme
                                                                        .playCyan,
                                                                    letterSpacing:
                                                                        3,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w900,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Container(
                                                          width: 40,
                                                          height: 40,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration: BoxDecoration(
                                                            color: AppTheme
                                                                .playCyan
                                                                .withValues(
                                                                  alpha: 0.12,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  AppRadius.sm,
                                                                ),
                                                          ),
                                                          child: const Icon(
                                                            AppIcons.copy,
                                                            color: AppTheme
                                                                .playCyan,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  AppPanel(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              AppIcons.peopleGroup,
                                              color: AppTheme.textSubColor(
                                                context,
                                              ),
                                              size: 20,
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.xs,
                                            ),
                                            // Esnek olmalı: başlık `heading2`
                                            // ve sayaçla aynı satırda duruyor.
                                            // Sabit `Text` + `Spacer` ikilisi
                                            // %200 sistem yazısında satırı 57
                                            // piksel taşırıyordu — `Spacer`
                                            // kalan yeri yeniden dağıtamaz,
                                            // çünkü esnemeyen başlık zaten
                                            // hepsini yemiş oluyor (2026-08-03).
                                            // `Expanded` + tek satır kısaltma
                                            // sayacı yine sağa yaslar.
                                            Expanded(
                                              child: Text(
                                                context.t(K.playersWord),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.heading2
                                                    .copyWith(
                                                      color:
                                                          AppTheme.textPrimaryColor(
                                                            context,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.xs,
                                            ),
                                            Text(
                                              // Aşağıdaki listeyle aynı sayıyı
                                              // gösterir: `visiblePlayers`
                                              // (engellenenler süzülmüş).
                                              '${visiblePlayers.length}',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textMutedColor(
                                                          context,
                                                        ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                        if (room.players.length < 2) ...[
                                          const SizedBox(height: AppSpacing.xs),
                                          Row(
                                            key: const ValueKey(
                                              'room-connection-state',
                                            ),
                                            children: [
                                              SizedBox(
                                                width: 10,
                                                height: 10,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                      color: AppTheme.playCyan
                                                          .withValues(
                                                            alpha: 0.85,
                                                          ),
                                                    ),
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  context.t(
                                                    K.playerListUpdating,
                                                  ),
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                        color:
                                                            AppTheme.textMutedColor(
                                                              context,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: AppSpacing.sm),
                                        if (visiblePlayers.isEmpty)
                                          Text(
                                            context.t(K.noPlayersYet),
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  color:
                                                      AppTheme.textMutedColor(
                                                        context,
                                                      ),
                                                ),
                                          )
                                        else
                                          for (
                                            var i = 0;
                                            i < visiblePlayers.length;
                                            i++
                                          )
                                            _PlayerTile(
                                              key: ValueKey(
                                                'room-player-tile-${i + 1}',
                                              ),
                                              rank: i + 1,
                                              player: visiblePlayers[i],
                                              isKu: ku,
                                              repository: widget.repository,
                                              isSelf:
                                                  visiblePlayers[i].id ==
                                                      null ||
                                                  visiblePlayers[i].id ==
                                                      widget
                                                          .repository
                                                          .currentUserId,
                                              isHost:
                                                  room.hostId != null &&
                                                  visiblePlayers[i].id ==
                                                      room.hostId,
                                              onBlocked: () {
                                                final id = visiblePlayers[i].id;
                                                if (id == null) return;
                                                setState(
                                                  () =>
                                                      _blockedPlayerIds.add(id),
                                                );
                                              },
                                            ),
                                        if (room.players.length < 2) ...[
                                          const SizedBox(height: AppSpacing.sm),
                                          // Tek inline şerit: davet ipucu (başlatma
                                          // uyarısı aşağıdaki hazır panelinde).
                                          Row(
                                            children: [
                                              const Icon(
                                                AppIcons.userPlus,
                                                color: AppTheme.gold,
                                                size: 18,
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  context.t(
                                                    K.inviteFriendByCode,
                                                  ),
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                        color:
                                                            AppTheme.textMutedColor(
                                                              context,
                                                            ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.cardGap),

                                  AppPanel(
                                    child: Column(
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: SwitchListTile(
                                            value: ready,
                                            activeThumbColor: AppTheme.playCyan,
                                            activeTrackColor: AppTheme.playCyan
                                                .withValues(alpha: 0.45),
                                            onChanged: _toggleReady,
                                            title: Text(
                                              context.t(K.imReady),
                                              style: AppTypography.bodyLarge
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textPrimaryColor(
                                                          context,
                                                        ),
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            subtitle: Text(
                                              context.t(K.readyStateNote),
                                              style: AppTypography.caption
                                                  .copyWith(
                                                    color:
                                                        AppTheme.textMutedColor(
                                                          context,
                                                        ),
                                                  ),
                                            ),
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        if (waitingForReady) ...[
                                          // Oyuncu sayısı yeter ama biri hazır
                                          // değil. Mesaj role göre değişir:
                                          // hazır olmayan kişiye ne yapacağı,
                                          // ötekine niçin beklediği söylenir.
                                          Container(
                                            key: const ValueKey(
                                              'room-ready-hint',
                                            ),
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.sm,
                                              vertical: AppSpacing.xs + 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.gold.withValues(
                                                alpha: 0.10,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.sm,
                                                  ),
                                              border: Border.all(
                                                color: AppTheme.gold.withValues(
                                                  alpha: 0.30,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  AppIcons.circleCheck,
                                                  color:
                                                      AppColors.readableAccent(
                                                        context,
                                                        AppTheme.gold,
                                                      ),
                                                  size: 18,
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.xs,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    context.t(
                                                      ready
                                                          ? K.waitingOpponentReady
                                                          : K.tapReadyToStart,
                                                    ),
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                          color:
                                                              AppColors.readableAccent(
                                                                context,
                                                                AppTheme.gold,
                                                              ),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                        ],
                                        if (room.players.length < 2) ...[
                                          // Tek inline uyarı şeridi: "2 oyuncu gerekli"
                                          // mesajı yalnızca burada görünür.
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.sm,
                                              vertical: AppSpacing.xs + 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.wrong.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.sm,
                                                  ),
                                              border: Border.all(
                                                color: AppTheme.wrong
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  AppIcons.userPlus,
                                                  color: AppTheme.wrong,
                                                  size: 18,
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.xs,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    context.t(K.needTwoPlayers),
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                          color: AppTheme.wrong,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                        ],
                                        if (_questionLoadExhausted) ...[
                                          // 3 otomatik denemeden sonra sessiz
                                          // döngü durur; kullanıcı burada
                                          // gerçek durumu görür ve elle karar
                                          // verir (2026-08-14 denetimi).
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.sm,
                                              vertical: AppSpacing.xs + 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.wrong.withValues(
                                                alpha: 0.08,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.sm,
                                                  ),
                                              border: Border.all(
                                                color: AppTheme.wrong
                                                    .withValues(alpha: 0.25),
                                              ),
                                            ),
                                            child: Text(
                                              context.t(
                                                K.questionsLoadExhausted,
                                              ),
                                              style: AppTypography.caption
                                                  .copyWith(
                                                    color: AppTheme.wrong,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          GeometricGradientButton(
                                            label: context.t(K.retry),
                                            icon: AppIcons.play,
                                            onPressed: _retryLoadingQuestions,
                                          ),
                                        ] else if (isHost) ...[
                                          GeometricGradientButton(
                                            label: starting
                                                ? (context.t(K.preparingShort))
                                                : (context.t(K.startRace)),
                                            icon: AppIcons.play,
                                            isLoading: starting,
                                            onPressed: canStart
                                                ? _startGameHost
                                                : null,
                                          ),
                                        ] else ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: AppSpacing.sm,
                                              horizontal: AppSpacing.md,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme
                                                  .primaryGradientStart
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.sm,
                                                  ),
                                              border: Border.all(
                                                color: AppTheme
                                                    .primaryGradientStart
                                                    .withValues(alpha: 0.28),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(
                                                          AppTheme
                                                              .primaryGradientStart,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: AppSpacing.sm,
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    context.t(K.waitingHost),
                                                    style: AppTypography.caption
                                                        .copyWith(
                                                          color: AppTheme
                                                              .primaryGradientStart,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  _buildQuickReactionChips(context),
                                  const SizedBox(height: AppSpacing.sm),

                                  // ── Oda sohbeti ───────────────────────
                                  //
                                  // 411 satırlık `RoomChat` yazılmış, testi
                                  // ve çevirileri hazırdı ama aa42044
                                  // ("kalabalık ekranları seyrelt") onu
                                  // RoomScreen'den çıkarmıştı ve commit
                                  // gövdesi sohbetin kaldırıldığını hiç
                                  // anmıyordu. Geriye canlı akışa bağlı,
                                  // hiçbir ekranın mount etmediği bir widget
                                  // kaldı (2026-07-31 denetimi).
                                  //
                                  // Arkadaşla oynamanın en sosyal anında —
                                  // kod paylaşıldı, karşı taraf girdi —
                                  // hiçbir iletişim kanalı yoktu. Sohbet
                                  // katlanabilir bir panel olarak geri
                                  // geldi; kalabalık kaygısı kapalı
                                  // başlayarak karşılanıyor.
                                  //
                                  // Moderasyon onunla BİRLİKTE geldi
                                  // (Apple 1.2): gönderimde küfür/bağlantı
                                  // süzgeci, mesaja uzun basınca bildir ve
                                  // engelle. Sunucu tarafı karşılığı
                                  // supabase/2026-07-31_chat_moderation.sql.
                                  if (room.id != null) ...[
                                    const SizedBox(height: AppSpacing.cardGap),
                                    // Kapalıyken dış satır, açıkken RoomChat'in
                                    // KENDİ başlığı görünür. `_ChatToggleRow`
                                    // koşulsuz basıldığında ikisi üst üste
                                    // biniyor ve odada alt alta iki "Sohbet"
                                    // başlığı çıkıyordu (2026-08-01, iOS
                                    // simülatöründe görüldü). Sohbeti geri
                                    // getirirken `RoomChat`in zaten katlanabilir
                                    // bir başlığı ve `onToggle` geri çağrısı
                                    // olduğu gözden kaçmıştı.
                                    if (!_chatOpen)
                                      _ChatToggleRow(
                                        open: _chatOpen,
                                        onToggle: () => setState(
                                          () => _chatOpen = !_chatOpen,
                                        ),
                                      ),
                                    if (_chatOpen)
                                      RoomChat(
                                        key: const ValueKey('room-chat'),
                                        repository: widget.repository,
                                        roomId: room.id!,
                                        visible: true,
                                        onToggle: () => setState(
                                          () => _chatOpen = !_chatOpen,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startGameHost() async {
    setState(() => starting = true);
    try {
      await widget.repository.startGame(room);
      _navigateToQuiz();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'startGame failed');
      if (!mounted) return;
      setState(() => starting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.gameStartFailed))));
    }
  }

  Future<void> _navigateToQuiz() async {
    if (quizOpened) return;
    _pausePolling();
    _pauseStatusPolling();
    setState(() {
      quizOpened = true;
      starting = true;
    });
    List<QuizQuestion> questions;
    try {
      questions = await widget.repository.loadRoomQuestions(room);
      if (questions.isEmpty &&
          room.id != null &&
          widget.repository.usesServerHiddenAnswers) {
        throw StateError('Online room questions are unavailable.');
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'loadRoomQuestions failed');
      if (room.id == null || !widget.repository.usesServerHiddenAnswers) {
        questions = widget.repository.playableQuestions;
      } else {
        _questionLoadAttempts++;
        final exhausted = _questionLoadAttempts >= _maxQuestionLoadAttempts;
        if (!mounted) return;
        setState(() {
          quizOpened = false;
          starting = false;
          _questionLoadExhausted = exhausted;
        });
        // İzleme her durumda devam eder — oyuncu listesi ve "host çıktı"
        // olayları hâlâ gerekli. Yeniden deneme döngüsünü yukarıdaki
        // `!_questionLoadExhausted` koşulu keser, bu çağrı değil.
        _resumeLobbyMonitoring();
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                context.t(
                  exhausted ? K.questionsLoadExhausted : K.gameStartFailed,
                ),
              ),
            ),
          );
        return;
      }
    }
    if (!mounted) return;
    _questionLoadAttempts = 0;
    _questionLoadExhausted = false;
    setState(() => starting = false);
    Navigator.of(context).push(
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: room,
          questions: questions.isEmpty
              ? widget.repository.playableQuestions
              : questions,
          is1v1: room.id != null && room.players.length == 2,
        ),
      ),
    );
  }

  /// Kullanıcının otomatik döngü durduktan sonra elle tekrar denemesi.
  /// Sayaç ve bayrak sıfırlanır ki yeni deneme de kendi 3 hakkını alsın.
  void _retryLoadingQuestions() {
    setState(() {
      _questionLoadAttempts = 0;
      _questionLoadExhausted = false;
    });
    _navigateToQuiz();
  }

  Widget _buildQuickReactionChips(BuildContext context) {
    final reactions = [
      (context.t(K.reactionBravo), '👏'),
      (context.t(K.reactionGoodLuck), '🍀'),
      (context.t(K.reactionFast), '⚡'),
      (context.t(K.reactionSmiley), '😊'),
      (context.t(K.reactionFire), '🔥'),
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.center,
      children: [
        for (final r in reactions)
          ActionChip(
            key: ValueKey('room-reaction-${r.$2}'),
            label: Text(
              r.$1,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            backgroundColor: AppTheme.surfaceColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.badge),
              side: BorderSide(
                color: AppTheme.borderOf(context).withValues(alpha: 0.5),
              ),
            ),
            onPressed: () => _sendReaction(r.$1),
          ),
      ],
    );
  }
}

/// Mêvandarın (ev sahibinin) görünen adı — guest lobi çipi için.
String _hostName(GameRoom room) {
  for (final player in room.players) {
    if (player.id != null && player.id == room.hostId) return player.name;
  }
  return room.players.isNotEmpty ? room.players.first.name : '—';
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: AppSpacing.xxs + 1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({
    super.key,
    required this.rank,
    required this.player,
    required this.isKu,
    required this.repository,
    required this.isSelf,
    this.isHost = false,
    this.onBlocked,
  });

  final int rank;
  final Player player;
  final bool isKu;
  final bool isHost;

  /// Bildir/engelle için; yeni bir backend yok, mevcut RPC'ler kullanılır.
  final ZanKurdRepository repository;

  /// Kendi satırında moderasyon düğmesi çizilmez.
  final bool isSelf;

  /// Engelleme başarılıysa çağıranın (oda ekranının) satırı süzmesi için.
  final VoidCallback? onBlocked;

  /// Yerel oyuncunun görünen adı.
  ///
  /// Depo katmanı yerel oyuncuyu sabit `'Tu'` adıyla üretir — bu bir i18n
  /// değeri değil, yer tutucu. Türkçe arayüzde oyuncu kendi satırında
  /// "Tu" yazdığını görüyor ve bunu bir kullanıcı adı sanıyordu; sonuç
  /// ekranı aynı adı zaten gösterim anında yerelleştiriyordu, oda ekranı
  /// unutulmuştu (2026-07-26).
  String _displayName(BuildContext context) =>
      player.name == 'Tu' && player.id == null ? context.t(K.you) : player.name;

  /// Depodan gelen durum metni Türkçe sabittir; KU modunda burada çevrilir.
  String _localizedState(String state) {
    if (!isKu) return state;
    return switch (state) {
      'Hazır' => 'Amade',
      'Bekliyor' => 'Li bendê',
      'Cevapladı' => 'Bersivand',
      _ => state,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isHost
              ? AppTheme.gold.withValues(alpha: 0.45)
              : AppTheme.playCyan.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.playCyan.withValues(alpha: 0.16),
            child: Text(
              '$rank',
              style: AppTypography.caption.copyWith(
                // Sıra rakamı kendi renginin %16'lık dairesinde
                // yazılıyordu: koyu temada 2.15:1 (2026-07-27).
                color: AppColors.onAccentTint(context, AppTheme.playCyan),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _displayName(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          Tr.forKu(K.host, isKu),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onAccentTint(
                              context,
                              AppTheme.gold,
                            ),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _localizedState(player.state),
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.score}',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${player.streak} ${isKu ? "zincîr" : "seri"}',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          // Yabancı bir oyuncunun avatarı ve adı bu satırda da
          // gösteriliyor; bildir/engelle bu ekranda hiç yoktu
          // (2026-08-06 denetimi).
          //
          // Satırın SONUNA konuyor, ad sütununun içine değil: 44 pt'lik
          // dokunma hedefi metin sütununu uzatırsa satır yükselir ve
          // lobinin birincil eylemi ("Yarışı Başlat") üç kişilik odada
          // 390x844 ekranda katlamanın altına iniyordu.
          PlayerModerationButton(
            repository: repository,
            playerId: player.id,
            playerName: player.name,
            isSelf: isSelf,
            compact: true,
            onBlocked: onBlocked,
          ),
        ],
      ),
    );
  }
}

/// Sohbet panelini açıp kapatan satır.
///
/// Sohbet kapalı başlar ve bu satır onun var olduğunu söyler. aa42044
/// odayı seyreltmek için sohbeti tamamen kaldırmıştı; kalabalık kaygısı
/// haklıydı ama çözüm silmek değil katlamaktı — kapalıyken tek satır yer
/// kaplıyor (2026-07-31).
class _ChatToggleRow extends StatelessWidget {
  const _ChatToggleRow({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('room-chat-toggle'),
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  AppIcons.comment,
                  color: AppTheme.playCyan,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.t(K.chat),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  open ? AppIcons.chevronUp : AppIcons.chevronDown,
                  color: AppTheme.textMutedColor(context),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
