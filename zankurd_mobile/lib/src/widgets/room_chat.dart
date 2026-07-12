import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/room_message.dart';
import '../theme/app_theme.dart';
import 'player_avatar.dart';

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
    _subscription =
        widget.repository.subscribeRoomMessages(widget.roomId).listen((msgs) {
      if (!mounted) return;
      setState(() => _messages = msgs);
      _scrollToBottom();
    });
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repository.sendRoomMessage(
        roomId: widget.roomId,
        text: text,
      );
      _messageController.clear();
    } catch (_) {
      // swallow
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
            color: AppTheme.borderColor(context).withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
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
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: AppTheme.textSubColor(context),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  ku ? 'Sohbet' : 'Sohbet',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onToggle,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
          // Mesaj listesi
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      ku
                          ? 'Hîn mesaj tune. Yekem bibêje!'
                          : 'Henüz mesaj yok. İlk sen yaz!',
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
                    itemCount: _messages.length,
                    itemBuilder: (ctx, idx) {
                      final msg = _messages[idx];
                      final isMine =
                          msg.senderId == widget.repository.currentUserId;
                      return _MessageBubble(
                        message: msg,
                        isMine: isMine,
                        ku: ku,
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
                      hintText: ku ? 'Peyamek binivîse…' : 'Bir mesaj yaz…',
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
                          color: AppTheme.borderColor(context).withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
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
                      : Icon(
                          Icons.send_rounded,
                          color: AppTheme.primaryGradientStart,
                        ),
                  tooltip: ku ? 'Bişîne' : 'Gönder',
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
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
