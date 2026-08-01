import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/room_message.dart';
import '../services/chat_moderation_policy.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import 'player_avatar.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Oda sohbet paneli. [RoomScreen] altında daraltılabilir alt panel olarak
/// gösterilir. Supabase Realtime üzerinden canlı mesajlaşmayı destekler.
class RoomChat extends StatefulWidget {
  const RoomChat({
    required this.repository,
    required this.roomId,
    required this.visible,
    this.onToggle,
    super.key,
  });

  final ZanKurdRepository repository;
  final String roomId;
  final bool visible;
  final VoidCallback? onToggle;

  /// Kendi mesajına moderasyon menüsü açılmaz.
  String? get currentUserId => repository.currentUserId;

  @override
  State<RoomChat> createState() => _RoomChatState();
}

class _RoomChatState extends State<RoomChat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<RoomMessage>>? _subscription;
  List<RoomMessage> _messages = [];
  bool _sending = false;
  bool _subscribed = false;

  /// Engellenen göndericiler ve bildirilen mesajlar — bu cihazda hemen
  /// gizlenir. Sunucu tarafında `blocked_users` politikası zaten süzüyor;
  /// bu, kararın anında görünmesi için.
  final Set<String> _blockedSenderIds = <String>{};
  final Set<String> _hiddenMessageIds = <String>{};

  /// Ekranda gösterilecek mesajlar.
  List<RoomMessage> get _visibleMessages => _messages
      .where(
        (m) =>
            !_blockedSenderIds.contains(m.senderId) &&
            !_hiddenMessageIds.contains(m.id),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    if (widget.visible) _startListening();
  }

  @override
  void didUpdateWidget(RoomChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !_subscribed) {
      _startListening();
    } else if (!widget.visible && _subscribed) {
      _stopListening();
    }
  }

  @override
  void dispose() {
    _stopListening();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startListening() {
    if (_subscribed) return;
    _subscribed = true;
    _subscription = widget.repository
        .subscribeRoomMessages(widget.roomId)
        .listen(
          (msgs) {
            if (!mounted) return;
            setState(() => _messages = msgs);
            _scrollToBottom();
          },
          onError: (Object error, StackTrace stack) {
            ErrorReporter.record(
              error,
              stack,
              reason: 'room chat realtime stream failed',
            );
          },
        );
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _subscribed = false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Süzgeç kararını kullanıcıya okunur bir cümleyle söyler.
  ///
  /// Sessizce yutmak en kötüsü: kullanıcı mesajın gittiğini sanır ve
  /// karşı taraf hiç görmez.
  String _rejectionMessage(ChatModerationVerdict verdict) {
    return switch (verdict) {
      ChatModerationVerdict.blockedWord => context.t(K.chatBlockedWord),
      ChatModerationVerdict.containsLink => context.t(K.chatNoLinks),
      ChatModerationVerdict.tooLong => context.t(K.chatTooLong),
      ChatModerationVerdict.spam => context.t(K.chatSpam),
      ChatModerationVerdict.empty => '',
      ChatModerationVerdict.allowed => '',
    };
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    // İstemci tarafı süzgeç: kullanıcıya ANINDA niçin gönderilemediğini
    // söyler. Tek başına yeterli değildir — aynı kural `room_messages`
    // üzerinde bir BEFORE INSERT tetikleyicisiyle de kurulu
    // (supabase/2026-07-31_chat_moderation.sql), çünkü değiştirilmiş bir
    // istemci doğrudan REST üzerinden yazabilir.
    final verdict = ChatModerationPolicy.review(text);
    if (verdict != ChatModerationVerdict.allowed) {
      final message = _rejectionMessage(verdict);
      if (message.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }

    setState(() => _sending = true);
    final sendFailed = context.t(K.chatSendFailed);
    try {
      await widget.repository.sendRoomMessage(
        roomId: widget.roomId,
        text: text,
      );
      _messageController.clear();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room chat send failed');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(sendFailed)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Mesaja uzun basınca açılan moderasyon menüsü.
  ///
  /// Apple 1.2 içerik bildirme ve kullanıcı engelleme yollarının
  /// uygulamada bulunmasını şart koşar. Kendi mesajın için menü açılmaz.
  Future<void> _showModerationSheet(RoomMessage message) async {
    if (message.senderId == widget.currentUserId) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('chat-report-action'),
              leading: const Icon(AppIcons.triangleExclamation),
              title: Text(sheetContext.t(K.chatReport)),
              subtitle: Text(sheetContext.t(K.chatReportSub)),
              onTap: () => Navigator.of(sheetContext).pop('report'),
            ),
            ListTile(
              key: const ValueKey('chat-block-action'),
              leading: const Icon(AppIcons.circleXmark),
              title: Text(sheetContext.t(K.chatBlock)),
              subtitle: Text(sheetContext.t(K.chatBlockSub)),
              onTap: () => Navigator.of(sheetContext).pop('block'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final okText = context.t(
      action == 'report' ? K.chatReported : K.chatBlocked,
    );
    final failText = context.t(K.chatModerationFailed);
    final ok = action == 'report'
        ? await widget.repository.reportRoomMessage(
            messageId: message.id,
            reason: 'user_report',
          )
        : await widget.repository.blockPlayer(message.senderId);

    if (!mounted) return;
    if (ok) {
      // Bildiren/engelleyen için mesaj hemen gizlenir; sunucu kararını
      // beklemek kullanıcıyı rahatsız edici içerikle baş başa bırakırdı.
      setState(() {
        if (action == 'block') {
          _blockedSenderIds.add(message.senderId);
        } else {
          _hiddenMessageIds.add(message.id);
        }
      });
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(ok ? okText : failText)));
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    if (!widget.visible) return const SizedBox.shrink();
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.card),
          topRight: Radius.circular(AppRadius.card),
        ),
        border: Border(
          top: BorderSide(
            color: AppTheme.borderColor(context).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Sohbet başlığı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHiColor(context),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card),
                topRight: Radius.circular(AppRadius.card),
              ),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.comment,
                        size: 18,
                        color: AppTheme.textSubColor(context),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        context.t(K.chat),
                        style: TextStyle(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Semantics(
                  container: true,
                  button: true,
                  label: context.t(K.chat),
                  enabled: widget.onToggle != null,
                  onTap: widget.onToggle,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onToggle,
                      child: Center(
                        child: Icon(
                          AppIcons.chevronDown,
                          size: 22,
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Mesaj listesi
          Expanded(
            child: _visibleMessages.isEmpty
                ? Center(
                    child: Text(
                      context.t(K.chatEmpty),
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                    itemCount: _visibleMessages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = _visibleMessages[idx];
                      final isMine = msg.senderId == widget.currentUserId;
                      // Uzun basış: bildir / engelle. Apple 1.2 ikisinin de
                      // uygulamada bulunmasını şart koşuyor. Kendi mesajın
                      // için menü açılmaz.
                      return Semantics(
                        container: true,
                        button: !isMine,
                        enabled: !isMine,
                        label: '${msg.senderName}: ${msg.text}',
                        onLongPress: isMine
                            ? null
                            : () => _showModerationSheet(msg),
                        child: ExcludeSemantics(
                          child: GestureDetector(
                            key: ValueKey('chat-message-${msg.id}'),
                            onLongPress: isMine
                                ? null
                                : () => _showModerationSheet(msg),
                            child: _MessageBubble(
                              message: msg,
                              isMine: isMine,
                              ku: ku,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Giriş alanı
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xxs,
              AppSpacing.sm,
              AppSpacing.sm + 4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceHiColor(context),
              border: Border(
                top: BorderSide(
                  color: AppTheme.borderColor(context).withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: context.t(K.chatHint),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: AppTheme.borderColor(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: AppTheme.borderColor(
                            context,
                          ).withValues(alpha: 0.4),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryGradientStart,
                        ),
                      ),
                    ),
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryGradientStart,
                          ),
                        )
                      : const Icon(
                          AppIcons.paperPlane,
                          color: AppTheme.primaryGradientStart,
                        ),
                  tooltip: context.t(K.sendAction),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.ku,
  });

  final RoomMessage message;
  final bool isMine;
  final bool ku;

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            PlayerAvatar(
              radius: 14,
              colorHex: message.senderAvatarColor,
              displayName: message.senderName,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.68,
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: isMine
                    ? AppTheme.primaryGradientStart.withValues(alpha: 0.12)
                    : AppTheme.surfaceHiColor(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMine ? 14 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 14),
                ),
                border: Border.all(
                  color: isMine
                      ? AppTheme.primaryGradientStart.withValues(alpha: 0.22)
                      : AppTheme.borderColor(context).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSubColor(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: AppTheme.textMutedColor(context),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 6),
            PlayerAvatar(
              radius: 14,
              colorHex: message.senderAvatarColor,
              displayName: message.senderName,
            ),
          ],
        ],
      ),
    );
  }
}
