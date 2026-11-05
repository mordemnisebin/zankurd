import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/room_message.dart';
import '../theme/app_icons.dart';
import '../providers/reduced_motion_provider.dart';
import '../utils/error_reporter.dart';
import '../utils/player_identity.dart';
import 'sahne/sahne.dart';

/// Lobide sohbet GÖRÜNÜRLÜĞÜ (k4 T3, Clash Royale / Among Us modeli).
///
/// Eksik olan neydi: sohbet kapalıyken [RoomChat] akışa abone değildi, yani
/// kapalı panel hiçbir şey duymuyordu. Biri yazsa lobideki oyuncu bunu
/// ancak paneli açıp bakınca fark ediyordu; panel açılınca da ekranın
/// dışında kalabiliyordu (2026-10-27 4 cihazlı E2E). Bu denetleyici lobi
/// açıkken mesaj akışını SESSİZCE dinler ve üç ipucu üretir; tam ekran
/// sohbeti asla kendiliğinden açmaz:
///  * göndericinin satırında [bubbleDuration] süren konuşma balonu,
///  * sohbet simgesinde okunmamış sayısı,
///  * oyuncu listesinin altında tek satırlık son mesaj şeridi.
class LobbyChatController extends ChangeNotifier {
  LobbyChatController({
    required this.repository,
    required this.roomId,
    this.isBlocked,
    this.onReaction,
  });

  final ZanKurdRepository repository;
  final String roomId;

  /// Engellenen gönderenin mesajı sayılmaz, balon ve şerit çizilmez.
  final bool Function(String senderId)? isBlocked;

  /// Başkasından gelen hazır emoji tepkisi (yüzen tepki için).
  final void Function(RoomMessage message)? onReaction;

  static const bubbleDuration = Duration(seconds: 4);
  static const _resubscribeDelay = Duration(seconds: 3);

  StreamSubscription<List<RoomMessage>>? _sub;
  Timer? _bubbleTimer;
  Timer? _retryTimer;
  final Set<String> _seen = <String>{};
  bool _baselineTaken = false;
  bool _disposed = false;
  bool _chatOpen = false;

  int _unread = 0;
  RoomMessage? _last;
  RoomMessage? _bubble;

  int get unreadCount => _unread;
  RoomMessage? get lastMessage => _last;

  /// Balonu gösterilen mesaj (yoksa `null`).
  RoomMessage? get bubble => _bubble;

  bool get chatOpen => _chatOpen;

  /// Sohbet paneli açılınca okunmamışlar sıfırlanır; açıkken gelenler
  /// okunmuş sayılır.
  set chatOpen(bool value) {
    if (_chatOpen == value) return;
    _chatOpen = value;
    if (value) _unread = 0;
    _notify();
  }

  /// Hazır tepki emojisi mi: bu mesajlar balon/şerit/rozet değil yüzen
  /// tepki olarak görünür.
  static bool isReactionText(String text) =>
      lobbyReactionEmojis.contains(text.trim());

  void start() {
    if (_sub != null || _disposed) return;
    _sub = repository
        .subscribeRoomMessages(roomId)
        .listen(
          _onMessages,
          onError: (Object error, StackTrace stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'lobby chat hud stream failed',
            );
            _retry();
          },
          onDone: _retry,
        );
  }

  void _retry() {
    _sub?.cancel();
    _sub = null;
    if (_disposed || _retryTimer != null) return;
    _retryTimer = Timer(_resubscribeDelay, () {
      _retryTimer = null;
      start();
    });
  }

  void _onMessages(List<RoomMessage> messages) {
    final me = repository.currentUserId;
    final fresh = <RoomMessage>[];
    for (final m in messages) {
      if (_seen.add(m.id) && _baselineTaken) fresh.add(m);
    }
    final firstSnapshot = !_baselineTaken;
    _baselineTaken = true;
    if (firstSnapshot) {
      // Odaya girmeden önceki geçmiş "yeni" sayılmaz; yalnız son mesaj
      // şeridi için hatırlanır.
      final visible = messages
          .where(
            (m) =>
                m.senderId != me &&
                !(isBlocked?.call(m.senderId) ?? false) &&
                !isReactionText(m.text),
          )
          .toList();
      if (visible.isNotEmpty) {
        visible.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _last = visible.last;
        _notify();
      }
      return;
    }
    var changed = false;
    for (final m in fresh) {
      if (m.senderId == me) continue;
      if (isBlocked?.call(m.senderId) ?? false) continue;
      if (isReactionText(m.text)) {
        onReaction?.call(m);
        continue;
      }
      _last = m;
      changed = true;
      if (!_chatOpen) _unread++;
      _showBubble(m);
    }
    if (changed) _notify();
  }

  void _showBubble(RoomMessage m) {
    _bubble = m;
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(bubbleDuration, () {
      _bubble = null;
      _notify();
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _bubbleTimer?.cancel();
    _retryTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

/// Tek dokunuşluk hızlı tepkiler (emoji). Sohbet mesajı olarak gönderilir.
const lobbyReactionEmojis = ['👏', '🍀', '⚡', '😊', '🔥'];

String _senderName(RoomMessage m, BuildContext context) =>
    PlayerIdentity.resolveNameWithTag(
      m.senderName,
      isKu: context.isKu,
      tag: m.senderProfile?.playerTag,
    );

/// Sohbet simgesinin üstüne okunmamış sayısı rozeti ekler.
class ChatUnreadBadge extends StatelessWidget {
  const ChatUnreadBadge({
    super.key,
    required this.controller,
    required this.child,
  });

  final LobbyChatController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final n = controller.unreadCount;
        if (n == 0) return child;
        final t = SahneTokens.of(context);
        return Semantics(
          label: '${context.t(K.chat)}: $n',
          container: true,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              child,
              PositionedDirectional(
                top: 0,
                end: 0,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('chat-unread-badge'),
                      constraints: const BoxConstraints(
                        // a11y-tap-target: noninteractive — rozet, IgnorePointer.
                        minWidth: 18,
                        // a11y-tap-target: noninteractive — rozet.
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: t.act,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        n > 9 ? '9+' : '$n',
                        textScaler: TextScaler.noScaling,
                        style: SahneType.caption.copyWith(
                          color: t.onAct,
                          fontSize: 11,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Oyuncu satırının üstüne, o oyuncunun mesajı için konuşma balonu bindirir.
class ChatBubbleAnchor extends StatelessWidget {
  const ChatBubbleAnchor({
    super.key,
    required this.controller,
    required this.playerId,
    required this.child,
  });

  final LobbyChatController controller;
  final String? playerId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (playerId == null) return child;
    return ListenableBuilder(
      listenable: controller,
      child: child,
      builder: (context, child) {
        final m = controller.bubble;
        final show = m != null && m.senderId == playerId;
        if (!show) return child!;
        final t = SahneTokens.of(context);
        final reduce = ReducedMotionProvider.isReducedIn(context);
        Widget bubble = Container(
          key: const ValueKey('chat-bubble'),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.6,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: SahneSpace.x3,
            vertical: SahneSpace.x1,
          ),
          decoration: ShapeDecoration(color: t.s3, shape: SahneShape.m),
          child: Text(
            m.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SahneType.caption.copyWith(color: t.tx),
          ),
        );
        if (!reduce) {
          bubble = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 160),
            builder: (_, v, c) => Opacity(opacity: v, child: c),
            child: bubble,
          );
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            PositionedDirectional(
              end: SahneSpace.x3,
              top: 0,
              child: Semantics(
                liveRegion: true,
                label: '${_senderName(m, context)}: ${m.text}',
                child: ExcludeSemantics(child: IgnorePointer(child: bubble)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Oyuncu listesinin altında "gönderen: metin" tek satırı; dokununca sohbet.
class LastMessageStrip extends StatelessWidget {
  const LastMessageStrip({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final LobbyChatController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final m = controller.lastMessage;
        if (m == null || controller.chatOpen) return const SizedBox.shrink();
        final t = SahneTokens.of(context);
        final line = '${_senderName(m, context)}: ${m.text}';
        return Padding(
          padding: const EdgeInsets.only(top: SahneSpace.x2),
          child: Semantics(
            button: true,
            container: true,
            label: '${context.t(K.chat)}: $line',
            onTap: onOpen,
            child: ExcludeSemantics(
              child: InkWell(
                key: const ValueKey('chat-last-strip'),
                onTap: onOpen,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Icon(AppIcons.comment, size: 18, color: t.tx2),
                      const SizedBox(width: SahneSpace.x2),
                      Expanded(
                        child: Text(
                          line,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.caption.copyWith(color: t.tx2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Klavyesiz hızlı tepki sırası: her emoji bir dokunuş, sohbet mesajı olarak
/// gider. Etiketler mevcut tepki metinleridir (yeni Kurmancî metni yok).
class QuickReactionBar extends StatelessWidget {
  const QuickReactionBar({super.key, required this.onReaction});

  final void Function(String emoji, String label) onReaction;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.t(K.reactionBravo),
      context.t(K.reactionGoodLuck),
      context.t(K.reactionFast),
      context.t(K.reactionSmiley),
      context.t(K.reactionFire),
    ];
    final t = SahneTokens.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1.6 (Pro denetimi 2026-11-05): beş düğme 56 px SABİTTİ (toplam 280);
        // ≈300 px'lik görünümde (bölünmüş ekran, yatay taşma) Row yatayda
        // taşıyordu. Artık her biri en çok 56, sığmazsa küçülür (dokunma
        // hedefi 48'in altına inmez: 5 × 48 = 240 sığar).
        for (var i = 0; i < lobbyReactionEmojis.length; i++)
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 56),
              child: Semantics(
                button: true,
                label: labels[i],
                excludeSemantics: true,
                onTap: () => onReaction(lobbyReactionEmojis[i], labels[i]),
                child: InkWell(
                  key: ValueKey('room-reaction-${lobbyReactionEmojis[i]}'),
                  customBorder: const StadiumBorder(),
                  onTap: () => onReaction(lobbyReactionEmojis[i], labels[i]),
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: t.s2,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      lobbyReactionEmojis[i],
                      textScaler: TextScaler.noScaling,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
