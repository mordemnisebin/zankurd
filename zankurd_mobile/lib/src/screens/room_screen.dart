import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/player.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../widgets/player_avatar.dart';
import '../widgets/room_chat.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/join_deep_link.dart';
import '../utils/player_identity.dart';
import '../widgets/floating_reaction_overlay.dart';
import '../widgets/player_moderation_button.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/styled_button.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Aynı kimlikli oyuncuyu TEK satıra indirir.
///
/// 2026-09-30 canlı: lobinin ilk 1-2 saniyesinde oyuncu iki satır
/// görünüyordu (ikisi de "Mêvandar"), sonra teke iniyordu. `room_players`
/// tablosunun (room_id, player_id) birincil anahtarı sunucuda çift satırı
/// engeller; çift, istemcide oluşuyordu: ilk yükleme ile realtime
/// `stream()` tohumu/INSERT olayı aynı satırı iki kez getirebiliyor. Ekran
/// listeyi olduğu gibi çizdiği ve `players.length < 2` kapısını da buna
/// bakarak açtığı için çift satır hem yanlış görünüyor hem de tek başına
/// ev sahibine "2 oyuncu var, başlat" dedirtebilirdi.
///
/// İlk görülme sırası korunur; aynı kimlik tekrar gelirse veri SON
/// gelenden alınır (daha taze hazır durumu). Kimliksiz (yerel/eski) satırlara
/// dokunulmaz: onlar adla ayrışır ve aynı adlı iki yerel oyuncu meşrudur.
List<Player> dedupeRoomPlayers(List<Player> players) {
  final indexById = <String, int>{};
  final result = <Player>[];
  for (final player in players) {
    final id = player.id?.trim();
    if (id == null || id.isEmpty) {
      result.add(player);
      continue;
    }
    final existing = indexById[id];
    if (existing == null) {
      indexById[id] = result.length;
      result.add(player);
    } else {
      result[existing] = player;
    }
  }
  return result;
}

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

  late GameRoom room = widget.initialRoom.copyWith(
    players: dedupeRoomPlayers(widget.initialRoom.players),
  );

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

  /// Realtime birincil kaynak; yoklama sessizliği yakalayan nöbetçidir.
  ///
  /// 2026-09-25 düzeltmesi. Buradaki asıl hata "polling'i kapatmak" değil,
  /// **uçuşta kalan yanıtın** yeniyi ezmesiydi: `loadRoomPlayers` 3 saniye
  /// önce başlar, o arada realtime yeni listeyi verir, sonra yoklamanın
  /// ESKİ yanıtı düşer ve oyuncu görünmez. `room_lobby_test` bunu iki
  /// senaryoda kilitler: "realtime oyuncu listesi bayat kalınca yoklama
  /// kurtarır" ve "durumu yalnızca durum yoklaması görürse quiz açılır".
  ///
  /// Bu yüzden iki kanal da AYNI tek yazma noktasına uyar
  /// (`_applyPlayerList` / `_applyRoomStatus`); ikisi de generation
  /// koruması taşır ve yoklama, uçuşu sırasında bir realtime event'i
  /// düşmüşse yanıtını **ÇÖPE ATAR** (aşağıdaki `_realtimeEventSeq`).
  /// Yani iki yazıcı değil, bir yazıcı ve gecikmeli bir doğrulayıcı var.
  ///
  /// Yoklamayı tamamen kapatmak da doğru değildi: gerçek arıza bağlantının
  /// KOPMASI değil, bağlı kalıp OLAY GÖNDERMEMESİdir (2026-08-01'de host'un
  /// katılanı "Li bendê" görmemesi bu yüzdendi).
  Timer? _pollTimer;
  Timer? _statusPollTimer;
  int _pollCount = 0;
  bool _pollThrottled = false;

  /// Realtime'dan gelen her event artar. Yoklama isteği uçarken bu sayaç
  /// değişmişse dönen anlık görüntü bayattır ve uygulanmaz.
  int _realtimeEventSeq = 0;

  /// "Lîsteya lîstikvanan tê nûvekirin…" göstergesinin bağlı olduğu TEK durum.
  ///
  /// Kusur (2026-09-30 canlı): gösterge `room.players.length < 2` kapısına
  /// bağlıydı. Bu bir yenileme durumu değil, bir BEKLEME koşulu: ev sahibi
  /// odada tek kaldığı sürece — canlı sunucuda 11+ saniye — dönen daire hiç
  /// kapanmıyordu. Oysa liste çoktan gelmişti; gösterge veriyi değil, ikinci
  /// oyuncunun yokluğunu işaret ediyordu ve "takılı" görünüyordu.
  ///
  /// Bayrak yalnız İLK oyuncu listesi yüklemesi sürerken açık:
  ///
  ///   * `initialRoom.players` doluysa hiç açılmaz — ilk veri zaten elimizde,
  ///   * listeyse boşsa açılır ve `_applyPlayerList` ilk listeyi uyguladığı
  ///     anda iner (ilk veri geldi → gösterge biter),
  ///   * ilk deneme hata ile biterse de iner (yenileme bitti → gösterge bitsin),
  ///   * periyodik arka plan yoklaması (`_pollPlayersOnce`) bayrağı asla
  ///     AÇMAZ, yalnız kapatır — arka plan tazelemesi gösterge yakmaz.
  bool _playersRefreshing = false;

  static const _pollInterval = Duration(seconds: 3);
  static const _maxPollsBeforePause = 20; // ~60s, yalnızca >=2 oyuncu varken

  @override
  void initState() {
    super.initState();
    // Gösterge yalnız "ilk liste henüz elimize ulaşmadı" durumunda açık
    // başlar. Odayla birlikte gelen liste ilk veridir; o varsa dönen daire
    // hiç çizilmez.
    _playersRefreshing = widget.initialRoom.players.isEmpty;
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
            _markRealtimeHealthy();
            _applyPlayerList(p);
          },
          onError: (err, stack) {
            if (!mounted ||
                generation != _subscriptionGeneration ||
                _leaving ||
                _terminalHandled) {
              return;
            }
            // Bağlantı koptu: sıradaki yoklama turu zaten sunucuyu
            // okuyacak, ek bir işlem gerekmiyor.
            _startPolling();
            _startStatusPolling();
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
            _markRealtimeHealthy();
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
            // Bağlantı koptu: sıradaki yoklama turu zaten sunucuyu
            // okuyacak, ek bir işlem gerekmiyor.
            _startPolling();
            _startStatusPolling();
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
            _reactionController.triggerReaction(
              text,
              senderName: senderName == null
                  ? null
                  : PlayerIdentity.resolveName(senderName, isKu: context.isKu),
            );
          }
        }
      });
    }
  }

  /// Realtime suskunlaştıysa yoklama devralır; taze ise bu tur atlanır.
  void _markRealtimeHealthy() {
    _realtimeEventSeq++;
  }

  void _applyPlayerList(List<Player> players) {
    if (!mounted || _leaving || _terminalHandled || quizOpened) return;
    final unique = dedupeRoomPlayers(players);
    setState(() {
      room = room.copyWith(players: unique);
      // Liste elde: yenileme (ilk yükleme) bitti, gösterge iner. Sonraki
      // uygulamalar — realtime ya da periyodik arka plan yoklaması — bayrağı
      // yeniden kaldırmaz.
      _playersRefreshing = false;
    });
    _syncPollingForLobby(unique.length);
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
    // Uçuş başlarken realtime'in olay sayacı. Dönüşte değişmişse bir
    // event bu isteğin uçuşu sırasında düştü demektir: anlık görüntü
    // bayattır, çöpe atılır.
    final seqAtDispatch = _realtimeEventSeq;
    try {
      final players = await widget.repository.loadRoomPlayers(room);
      if (!mounted || _leaving || _terminalHandled || quizOpened) return;
      if (seqAtDispatch != _realtimeEventSeq) return;
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
      // İlk deneme burada BİTTİ (başarısız da olsa): gösterge sonsuza dek
      // dönmesin. Bayrak yalnız ilk yükleme sürerken açık olduğu için bu
      // kapanış sonraki turlarda kendini tekrar etmez.
      if (mounted && _playersRefreshing) {
        setState(() => _playersRefreshing = false);
      }
    }
  }

  Future<void> _pollRoomStatusOnce() async {
    if (!mounted || quizOpened) return;
    final seqAtDispatch = _realtimeEventSeq;
    try {
      final status = await widget.repository.loadRoomStatus(room);
      if (!mounted || quizOpened || _leaving || _terminalHandled) return;
      // Durum, geri dönen anlık görüntüden taze olmalı: uçuş sırasında bir
      // realtime durumu düştüyse bu yanıttaki "active" bilgisi eski bir
      // turdan kalma olabilir ve quiz'i erken açabilirdi. Sessizce
      // yoksayıp bir sonraki tura bırakıyoruz (3 saniye).
      if (seqAtDispatch != _realtimeEventSeq) return;
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
    _reactionController.dispose();
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
    // Yeniden abonelikte olay sayacı korunur: uçuşta olan yoklama
    // istekleri yine geçersiz sayılır.
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
    final myName = PlayerIdentity.resolveName(
      me?.name ?? 'Tu',
      isKu: context.isKu,
    );
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

  /// Odayı paylaşım sayfasıyla (WhatsApp, Telegram, SMS…) paylaşır.
  ///
  /// Oda kodu `ZK-` + on karakterdir; bir arkadaşa bunu sesli okumak ya da
  /// elle yazdırmak odayı fiilen kilitliyordu. Kod kopyalama tek yoldu ve
  /// kopyalanan kodun nereye yapıştırılacağını oyuncu kendisi bulmalıydı.
  /// Paylaşılan metin `zankurd.com/join/<kod>` bağlantısını taşır: web
  /// sürümü bu yolu açınca odaya doğrudan katılır (`JoinDeepLink`), yani
  /// uygulaması olmayan arkadaş da tarayıcıdan gelebilir. Kod metinde
  /// ayrıca durur ki uygulamadan elle girmek isteyen de katılabilsin.
  Future<void> _shareRoomInvite(Rect? origin) async {
    final text = context.t(K.roomInviteShareText, {
      'link': JoinDeepLink.shareUrl(room.code),
      'code': room.code,
    });
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room invite share failed');
      // Paylaşım sayfası açılamadıysa davet boşa gitmesin: metin panoya.
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(K.roomCodeCopied, {'code': room.code})),
        ),
      );
    }
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
    final t = SahneTokens.of(context);
    if (_leaving) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: t.raceTx,
                ),
              ),
              const SizedBox(height: SahneSpace.x6),
              Text(
                context.t(K.leavingRoom),
                style: SahneType.headline.copyWith(color: t.tx),
              ),
            ],
          ),
        ),
      );
    }

    // 2026-09-29 Şahnê: B iskeleti. Üstte 64'lük çubuk (44'lük pahlı
    // "odadan ayrıl" + başlık); kahraman yarış rolünde sahne kartı (oda
    // adı, ayar çipleri, oda kodu kutusu, ikincil davet); oyuncular liste
    // grubunda; "Hazırım" anahtarı yüzey kartında; ekranın TEK birincil
    // eylemi ("Yarışı Başlat") alt perdede sabit. Eski koyu yeşil degrade
    // kart, büyük kilim deseni, beyaz kod kutusu ve bulanık gölge kalktı.
    //
    // Çubuğun başlığı oda adını ya da "Özel Oda"yı TEKRAR ETMEZ: ikisi
    // kahramanda. Tepki balonları da çubuğun sağ yarısında uçar
    // (`FloatingReactionPlacement.roomHeader`); oda kimliği çubuğun altında
    // kaldığı için balon onu örtmez (bekçi: `room_lobby_test`).
    Widget width(Widget child) => Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: child,
      ),
    );
    Widget padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
      child: child,
    );

    final Widget action;
    if (_questionLoadExhausted) {
      // 3 otomatik denemeden sonra sessiz döngü durur; kullanıcı gerçek
      // durumu görür ve elle karar verir (2026-08-14 denetimi).
      action = GeometricGradientButton(
        label: context.t(K.retry),
        icon: AppIcons.play,
        onPressed: _retryLoadingQuestions,
      );
    } else if (isHost) {
      action = GeometricGradientButton(
        label: starting
            ? (context.t(K.preparingShort))
            : (context.t(K.startRace)),
        icon: AppIcons.play,
        isLoading: starting,
        onPressed: canStart ? _startGameHost : null,
      );
    } else {
      // Konuk başlatamaz: alt perdede düğme yerine ev sahibini beklediğini
      // söyleyen sakin bir satır durur.
      action = DecoratedBox(
        decoration: ShapeDecoration(
          color: t.s1,
          shape: SahneShape.withSide(SahneShape.m, t.edge, width: 1),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x4,
              vertical: SahneSpace.x2,
            ),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.raceTx,
                  ),
                ),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    context.t(K.waitingHost),
                    style: SahneType.captionStrong.copyWith(color: t.tx2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final notices = <Widget>[
      if (waitingForReady)
        // Oyuncu sayısı yeter ama biri hazır değil. Mesaj role göre
        // değişir: hazır olmayan kişiye ne yapacağı, ötekine niçin
        // beklediği söylenir.
        _RoomNotice(
          key: const ValueKey('room-ready-hint'),
          icon: AppIcons.circleCheck,
          text: context.t(ready ? K.waitingOpponentReady : K.tapReadyToStart),
        ),
      if (room.players.length < 2)
        // Tek uyarı şeridi: "2 oyuncu gerekli" yalnız burada görünür.
        // Bir hata değil, bir koşul: Zêr (dikkat) tonu, Şaş değil.
        _RoomNotice(icon: AppIcons.userPlus, text: context.t(K.needTwoPlayers)),
      if (_questionLoadExhausted)
        _RoomNotice(
          icon: AppIcons.triangleExclamation,
          text: context.t(K.questionsLoadExhausted),
          error: true,
        ),
    ];

    return PopScope(
      // Sunucu çıkışı onaylamadan sistem geri hareketi rotayı
      // kapatmamalı. İkinci geri/ikon dokunuşunu `_leaving` tekilleştirir.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _leaveRoom();
      },
      child: Scaffold(
        backgroundColor: t.bg,
        // Alt perde: ekranın tek birincil eylemi. `bottomNavigationBar`
        // yuvasında durur ki SnackBar'lar (ör. "Sorular yüklenemedi")
        // düğmenin ÜSTÜNDE açılsın, onu örtmesin.
        bottomNavigationBar: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.bg,
              border: Border(top: BorderSide(color: t.line)),
            ),
            child: width(
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x3,
                  SahneSpace.page,
                  SahneSpace.x3,
                ),
                child: action,
              ),
            ),
          ),
        ),
        body: FloatingReactionOverlay(
          controller: _reactionController,
          placement: FloatingReactionPlacement.roomHeader,
          child: SafeArea(
            child: Column(
              children: [
                _RoomBar(
                  title: context.t(K.roomLobbyTitle),
                  leaveLabel: context.t(K.leaveRoom),
                  onLeave: _leaving ? null : _leaveRoom,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(
                      top: SahneSpace.x2,
                      bottom: SahneSpace.x6,
                    ),
                    children: [
                      width(
                        SizedBox(
                          key: const ValueKey('room-content-width'),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              padded(
                                _RoomHero(
                                  room: room,
                                  isHost: isHost,
                                  onCopy: () => _copyRoomCode(context, ku),
                                  onShare: _shareRoomInvite,
                                ),
                              ),
                              padded(
                                SahneSectionHeader(
                                  title: context.t(K.playersWord),
                                ),
                              ),
                              if (_playersRefreshing)
                                padded(
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: SahneSpace.x2,
                                    ),
                                    child: Row(
                                      key: const ValueKey(
                                        'room-connection-state',
                                      ),
                                      children: [
                                        SizedBox.square(
                                          dimension: 12,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: t.raceTx,
                                          ),
                                        ),
                                        const SizedBox(width: SahneSpace.x2),
                                        Expanded(
                                          child: Text(
                                            context.t(K.playerListUpdating),
                                            style: SahneType.caption.copyWith(
                                              color: t.tx2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              padded(
                                visiblePlayers.isEmpty
                                    ? SahneSurfaceCard(
                                        child: Text(
                                          context.t(K.noPlayersYet),
                                          style: SahneType.body.copyWith(
                                            color: t.tx2,
                                          ),
                                        ),
                                      )
                                    : SahneListGroup(
                                        dividerIndent: _RoomPlayerRow.indent,
                                        children: [
                                          for (
                                            var i = 0;
                                            i < visiblePlayers.length;
                                            i++
                                          )
                                            _RoomPlayerRow(
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
                                          if (visiblePlayers.length < 2)
                                            _WaitingPlayerTile(isKu: ku),
                                        ],
                                      ),
                              ),
                              if (room.players.length < 2)
                                // Tek satırlık davet ipucu (başlatma uyarısı
                                // aşağıdaki hazır kartında).
                                padded(
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: SahneSpace.x3,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          AppIcons.userPlus,
                                          color: t.goldTx,
                                          size: 16,
                                        ),
                                        const SizedBox(width: SahneSpace.x2),
                                        Expanded(
                                          child: Text(
                                            context.t(K.inviteFriendByCode),
                                            style: SahneType.caption.copyWith(
                                              color: t.tx2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(height: SahneSpace.cardGap),
                              padded(
                                SahneSurfaceCard(
                                  padding: const EdgeInsets.fromLTRB(
                                    SahneSpace.x4,
                                    SahneSpace.x1,
                                    SahneSpace.x2,
                                    SahneSpace.x1,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SwitchListTile(
                                        value: ready,
                                        onChanged: _toggleReady,
                                        title: Text(
                                          context.t(K.imReady),
                                          style: SahneType.bodyStrong.copyWith(
                                            color: t.tx,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      for (final notice in notices) ...[
                                        notice,
                                        const SizedBox(height: SahneSpace.x3),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: SahneSpace.x4),
                              _buildQuickReactionChips(context),

                              // ── Oda sohbeti ───────────────────────
                              //
                              // Sohbet 2026-07-31'de moderasyonuyla (Apple
                              // 1.2: gönderimde süzgeç, uzun basınca
                              // bildir/engelle; sunucu karşılığı
                              // supabase/2026-07-31_chat_moderation.sql)
                              // katlanabilir bir panel olarak geri geldi;
                              // kalabalık kaygısı kapalı başlayarak
                              // karşılanıyor.
                              if (room.id != null) ...[
                                const SizedBox(height: SahneSpace.cardGap),
                                // Kapalıyken dış satır, açıkken RoomChat'in
                                // KENDİ başlığı görünür — ikisi asla aynı
                                // anda değil (2026-08-01, iOS simülatörü:
                                // alt alta iki "Sohbet" başlığı).
                                if (!_chatOpen)
                                  _ChatToggleRow(
                                    open: _chatOpen,
                                    onToggle: () =>
                                        setState(() => _chatOpen = !_chatOpen),
                                  ),
                                if (_chatOpen)
                                  padded(
                                    RoomChat(
                                      key: const ValueKey('room-chat'),
                                      repository: widget.repository,
                                      roomId: room.id!,
                                      visible: true,
                                      onToggle: () => setState(
                                        () => _chatOpen = !_chatOpen,
                                      ),
                                    ),
                                  ),
                              ],
                            ],
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

    // 2026-09-29 Şahnê: seçim rayı (kenara taşan, sağda solma). Çip
    // görselde 44; dokunma kutusu 48 (Android kılavuzu). Anahtardaki emoji
    // yalnız kimliktir, ekrana yazılmaz.
    return SahneRail(
      children: [
        for (final r in reactions)
          _ReactionChip(
            key: ValueKey('room-reaction-${r.$2}'),
            label: r.$1,
            onTap: () => _sendReaction(r.$1),
          ),
      ],
    );
  }
}

/// Mêvandarın (ev sahibinin) görünen adı — guest lobi çipi için.
///
/// Yer tutucu ad ("ZanKurd Oyuncusu") dile göre [PlayerIdentity] ile çözülür.
String _hostName(GameRoom room, {required bool isKu}) {
  for (final player in room.players) {
    if (player.id != null && player.id == room.hostId) {
      return PlayerIdentity.resolveName(player.name, isKu: isKu);
    }
  }
  return room.players.isNotEmpty
      ? PlayerIdentity.resolveName(room.players.first.name, isKu: isKu)
      : '—';
}

/// Oda çubuğu — B iskeletinin çubuğu (en az 64; 44'lük pahlı geri
/// plakası + 12 + Manşet 22 başlık).
///
/// `SahnePushedPage` kullanılmıyor: odanın çıkışı sunucu onayı bekleyen bir
/// eylemdir (`_leaveRoom`) ve bekçiler (`room_lobby_test`,
/// `room_exit_test`) onu bir `IconButton` + "Odadan ayrıl" ipucu olarak
/// arar; sayfanın kendi geri düğmesi bir `IconButton` değildir. Görünüş
/// aynıdır: Perde plaka, M pah, gündüzde 1 px kenar; dokunma alanı 48.
class _RoomBar extends StatelessWidget {
  const _RoomBar({
    required this.title,
    required this.leaveLabel,
    required this.onLeave,
  });

  final String title;
  final String leaveLabel;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SahneSpace.page - SahneIconButton.inset,
          SahneSpace.x2,
          SahneSpace.page,
          SahneSpace.x2,
        ),
        child: Row(
          children: [
            SahneIconButton(
              icon: AppIcons.arrowLeft,
              semanticLabel: leaveLabel,
              onPressed: onLeave,
            ),
            const SizedBox(width: SahneSpace.x3 - SahneIconButton.inset),
            Expanded(
              child: Semantics(
                header: true,
                child: SahneUnbrokenText(
                  title,
                  style: SahneType.headline.copyWith(color: t.tx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oda kahramanı — yarış rolünde sahne kartı.
///
/// "Özel Oda" etiketi, oda adı (Başlık 28), ayar çipleri (kategori, süre,
/// soru sayısı, giriş ücreti, ev sahibi), oda kodu kutusu (dokun, kopyala;
/// 44'lük kopyala karosu) ve ikincil "Arkadaşlarını davet et". Kart iki
/// temada da gecedir.
class _RoomHero extends StatelessWidget {
  const _RoomHero({
    required this.room,
    required this.isHost,
    required this.onCopy,
    required this.onShare,
  });

  final GameRoom room;
  final bool isHost;
  final VoidCallback onCopy;
  final Future<void> Function(Rect? origin) onShare;

  @override
  Widget build(BuildContext context) {
    return SahneStageCard(
      role: SahneRole.race,
      child: Builder(
        builder: (context) {
          // Sahne kartının içi gece belirteçleridir.
          final t = SahneTokens.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Etiket büyük harfe ÇEVRİLMEZ: "Özel Oda" oda kimliğinin
              // parçası olarak okunur (rozet değil, tür adı).
              // 2026-09-29 doğallık (K10): etiketteki yıldız kalktı. Kartta
              // iki yıldız vardı (bu etiket ve "Ev sahibi" çipi); yıldız
              // yalnız ev sahibini işaretler, tür adı süs taşımaz.
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.goldTint,
                  shape: SahneShape.s,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SahneSpace.x2,
                    vertical: 2,
                  ),
                  child: Text(
                    context.t(K.privateRoom),
                    style: SahneType.captionStrong.copyWith(color: t.goldTx),
                  ),
                ),
              ),
              const SizedBox(height: SahneSpace.x2),
              Semantics(
                header: true,
                child: Text(
                  room.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.title.copyWith(color: t.tx),
                ),
              ),
              const SizedBox(height: SahneSpace.x3),
              Wrap(
                spacing: SahneSpace.x2,
                runSpacing: SahneSpace.x2,
                children: [
                  _Pill(
                    label: CategoryNames.localized(room.category, context.isKu),
                    icon: AppIcons.tableCells,
                  ),
                  _Pill(
                    label:
                        '${room.secondsPerQuestion} ${context.t(K.secondsShortUnit)}',
                    icon: AppIcons.stopwatch,
                  ),
                  _Pill(
                    label: '${room.questionCount} ${context.t(K.soru)}',
                    icon: AppIcons.circleQuestion,
                  ),
                  if (room.entryFee > 0)
                    _Pill(
                      label: '${room.entryFee} ${context.t(K.coinWord)}',
                      icon: AppIcons.coins,
                    ),
                  _Pill(
                    label: isHost
                        ? context.t(K.host)
                        : context.t(K.hostNamed, {
                            'name': _hostName(room, isKu: context.isKu),
                          }),
                    icon: AppIcons.star,
                  ),
                ],
              ),
              const SizedBox(height: SahneSpace.x4),
              // Büyük davet kodu: kopyalanabilir tek yüzey.
              Material(
                color: t.bg,
                shape: SahneShape.withSide(
                  SahneShape.m,
                  SahneStageColors.raceSoft.withValues(alpha: 0.4),
                  width: SahneRing.r1,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const ValueKey('room-code-copy'),
                  onTap: onCopy,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SahneSpace.x4,
                      SahneSpace.x3,
                      SahneSpace.x3,
                      SahneSpace.x3,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t(K.roomCodeTapCopy),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: SahneType.caption.copyWith(color: t.tx2),
                              ),
                              const SizedBox(height: SahneSpace.x1),
                              // Kod hiçbir genişlikte kısaltılmaz: 13
                              // karakter 320 px'te de tam okunur.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  room.code,
                                  key: const ValueKey('room-code'),
                                  maxLines: 1,
                                  softWrap: false,
                                  style: SahneType.title.copyWith(
                                    color: t.gold,
                                    letterSpacing: 3,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: SahneSpace.x3),
                        ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              color: t.s2,
                              shape: SahneShape.m,
                            ),
                            child: SizedBox.square(
                              dimension: 44,
                              child: Icon(
                                AppIcons.copy,
                                color: t.goldTx,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: SahneSpace.x3),
              _RoomInviteButton(
                label: context.t(K.roomInviteAction),
                onShare: onShare,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Oda lobisindeki davet düğmesi — sahne kartının ikincil eylemi.
///
/// Paylaşım sayfası iPad'de bir çıkış noktası ister; düğmenin kendi
/// konumu [onShare]'e verilir. Telefonlarda yok sayılır.
class _RoomInviteButton extends StatelessWidget {
  const _RoomInviteButton({required this.label, required this.onShare});

  final String label;
  final Future<void> Function(Rect? origin) onShare;

  @override
  Widget build(BuildContext context) {
    return SahneButton.secondary(
      key: const ValueKey('room-invite-share'),
      label: label,
      icon: AppIcons.shareNodes,
      expand: true,
      onPressed: () {
        HapticFeedback.selectionClick();
        final box = context.findRenderObject() as RenderBox?;
        final origin = box == null || !box.hasSize
            ? null
            : box.localToGlobal(Offset.zero) & box.size;
        onShare(origin);
      },
    );
  }
}

/// Ayar çipi: sahne kartında Perde tonu, S pah, yumuşak lal ikon.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.s1, shape: SahneShape.m),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: SahneSpace.x2,
            end: SahneSpace.x3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: SahneStageColors.raceSoft, size: 16),
              const SizedBox(width: SahneSpace.x2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.captionStrong.copyWith(color: t.tx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hazır kartındaki bilgi şeridi: ton zemin + ikon + kalın açıklama.
///
/// Koşul (2 oyuncu gerekli, rakip hazır değil) Zêr tonudur — dikkat, hata
/// değil; gerçek hata (sorular yüklenemedi) Şaş tonu + uyarı ikonu.
class _RoomNotice extends StatelessWidget {
  const _RoomNotice({
    super.key,
    required this.icon,
    required this.text,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final (bg, fg) = error ? (t.errTint, t.errTx) : (t.goldTint, t.goldTx);
    return DecoratedBox(
      decoration: ShapeDecoration(color: bg, shape: SahneShape.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x3,
          vertical: SahneSpace.x2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: fg, size: 16),
            ),
            const SizedBox(width: SahneSpace.x2),
            Expanded(
              child: Text(
                text,
                style: SahneType.captionStrong.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oyuncu satırı — [SahneListRow.rank]'ın ölçüleriyle, öncülü oyuncunun
/// kendi avatarı ([PlayerAvatar]: yüklediği fotoğraf ya da seçtiği renk).
///
/// Sıra no + 36'lık elmas, ad (Gövde 700) + ev sahibi rozeti, durum
/// ("✓ Hazır" Rast; bekleyen kum saati + söz), sağda puan ve seri; en
/// sonda bildir/engelle. Hazır durumu hiçbir zaman yalnız renkle
/// verilmez. Büyük yazıda puan adın altına iner.
class _RoomPlayerRow extends StatelessWidget {
  const _RoomPlayerRow({
    super.key,
    required this.rank,
    required this.player,
    required this.isKu,
    required this.repository,
    required this.isSelf,
    this.isHost = false,
    this.onBlocked,
  });

  /// Ayırıcının sol boşluğu: avatarın hizası (12 + 24 + 12).
  static const double indent = SahneSpace.x3 + 24 + SahneSpace.x3;

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
  /// "Tu" yazdığını görüyor ve bunu bir kullanıcı adı sanıyordu
  /// (2026-07-26).
  String _displayName(BuildContext context) =>
      player.name == 'Tu' && player.id == null
      ? context.t(K.you)
      : PlayerIdentity.resolveName(player.name, isKu: isKu);

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
    final t = SahneTokens.of(context);
    final isReady = player.state == Player.readyState;
    final stacked = MediaQuery.textScalerOf(context).scale(16) >= 24;

    final nameText = Text(
      _displayName(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: SahneType.bodyStrong.copyWith(color: t.tx),
    );

    // İkinci satır: durum ("✓ Hazır" / kum saati + söz) ve ev sahibi
    // rozeti. `Wrap`: dar satırda ya da büyük yazıda rozet alt satıra iner;
    // ad sütununu ezmez, harf harf bölünmez (eski satır 7 px taşıyordu,
    // 2026-08-19).
    final state = Wrap(
      spacing: SahneSpace.x2,
      runSpacing: SahneSpace.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReady ? AppIcons.check : AppIcons.hourglass,
              size: 14,
              color: isReady ? t.okTx : t.tx2,
            ),
            const SizedBox(width: SahneSpace.x1),
            Flexible(
              child: Text(
                _localizedState(player.state),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (isReady ? SahneType.captionStrong : SahneType.caption)
                    .copyWith(color: isReady ? t.okTx : t.tx2),
              ),
            ),
          ],
        ),
        if (isHost)
          SahneBadge(label: Tr.forKu(K.host, isKu), tone: SahneBadgeTone.gold),
      ],
    );

    final score = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${player.score}',
          style: SahneType.bodyStrong.copyWith(
            color: t.tx,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          '${player.streak} ${context.t(K.streakLabel).toLowerCase()}',
          style: SahneType.caption.copyWith(color: t.tx2),
        ),
      ],
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x2,
          SahneSpace.x1,
          SahneSpace.x2,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$rank',
                  maxLines: 1,
                  style: SahneType.bodyStrong.copyWith(
                    color: isHost ? t.goldTx : t.tx2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            PlayerAvatar(
              radius: 18,
              photoUrl: player.avatarUrl,
              iconId: player.avatarIcon,
              colorHex: player.avatarColor,
              frameId: player.avatarFrame,
              displayName: _displayName(context),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  nameText,
                  const SizedBox(height: 2),
                  state,
                  if (stacked) ...[
                    const SizedBox(height: SahneSpace.x1),
                    score,
                  ],
                ],
              ),
            ),
            if (!stacked) ...[const SizedBox(width: SahneSpace.x2), score],
            // Yabancı bir oyuncunun avatarı ve adı bu satırda da
            // gösteriliyor; bildir/engelle burada (2026-08-06 denetimi).
            // Satırın SONUNDA: 48 dp'lik hedef metin sütununu uzatırsa
            // birincil eylem katlamanın altına iniyordu.
            PlayerModerationButton(
              repository: repository,
              playerId: player.id,
              playerName: _displayName(context),
              isSelf: isSelf,
              compact: true,
              onBlocked: onBlocked,
            ),
            if (isSelf || player.id == null)
              const SizedBox(width: SahneSpace.x3),
          ],
        ),
      ),
    );
  }
}

/// Henüz katılmamış 2. oyuncu için boş yuva satırı.
class _WaitingPlayerTile extends StatelessWidget {
  const _WaitingPlayerTile({required this.isKu});

  /// Bekçinin tutunacağı çapa.
  ///
  /// Metinle aramak işe yaramıyor: "Henüz yok" (`K.statPending`) oda
  /// ekranında başka yerde de geçiyor. Anahtar, iddiayı bu yuvanın İÇİNE
  /// hapseder.
  static const anchorKey = ValueKey('room-waiting-slot');

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ConstrainedBox(
      key: anchorKey,
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x2,
          SahneSpace.x4,
          SahneSpace.x2,
        ),
        child: Row(
          children: [
            const SizedBox(width: 24 + SahneSpace.x3),
            // Boş elmas yuva: yalnız çizgi, içi zemin.
            DecoratedBox(
              decoration: ShapeDecoration(
                shape: SahneShape.diamond(
                  36,
                  side: BorderSide(
                    color: t.tx3,
                    width: SahneRing.r1,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
              ),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(AppIcons.userPlus, size: 16, color: t.goldTx),
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Text(
                context.t(K.waitingOpponent),
                style: SahneType.bodyStrong.copyWith(color: t.tx2),
              ),
            ),
            const SizedBox(width: SahneSpace.x2),
            // Alt satırdaki ikinci "Henüz yok" kaldırıldı: yuva aynı iki
            // kelimeyi iki kez basıyordu; kum saatli rozet daha çok şey
            // söylüyor.
            Flexible(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.goldTint,
                  shape: SahneShape.s,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SahneSpace.x2,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(AppIcons.hourglass, size: 14, color: t.goldTx),
                      const SizedBox(width: SahneSpace.x1),
                      Flexible(
                        child: Text(
                          context.t(K.statPending),
                          style: SahneType.captionStrong.copyWith(
                            color: t.goldTx,
                          ),
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
    );
  }
}

/// Hızlı tepki çipi: [SahneRailChip] (görsel 44, dokunma 48).
class _ReactionChip extends StatelessWidget {
  const _ReactionChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SahneRailChip(
    label: label,
    selected: false,
    role: SahneRole.race,
    onTap: onTap,
  );
}

/// Sohbet panelini açıp kapatan satır.
///
/// Sohbet kapalı başlar ve bu satır onun var olduğunu söyler. aa42044
/// odayı seyreltmek için sohbeti tamamen kaldırmıştı; kalabalık kaygısı
/// haklıydı ama çözüm silmek değil katlamaktı (2026-07-31).
///
/// 2026-09-29 Şahnê: liste grubunda tek standart satır (yarış tonu ikon
/// karosu + söz + aç/kapa oku).
class _ChatToggleRow extends StatelessWidget {
  const _ChatToggleRow({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
      child: SahneListGroup(
        children: [
          SahneListRow.icon(
            key: const ValueKey('room-chat-toggle'),
            icon: AppIcons.comment,
            role: SahneRole.race,
            title: context.t(K.chat),
            trailing: Icon(
              open ? AppIcons.chevronUp : AppIcons.chevronDown,
              color: t.tx3,
              size: 20,
            ),
            onTap: onToggle,
          ),
        ],
      ),
    );
  }
}
