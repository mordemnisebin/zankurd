import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/friend.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../theme/sahne.dart';
import 'dialog_action_pair.dart';

/// Yabancı bir oyuncunun avatarı/adı gösterilen yerlerde bildir/engelle.
///
/// ## Kusur
///
/// Uygulamada `blockPlayer`ın tek çağıranı `room_chat.dart` idi ve oraya
/// yalnız bir **long-press** ile ulaşılıyordu; `reportPlayerProfile`ın
/// tek çağıranı ise liderlik ekranıydı ve o liste `limit: 10` ile
/// çekiliyordu. Yani ikisi de vardı ama:
///
///   • Eşleştirme VS kartı rakibin YÜKLEDİĞİ fotoğrafı ve adını tam
///     ekran gösteriyor, üstünde hiçbir moderasyon aracı yok.
///   • Oda oyuncu listesi aynı içeriği gösteriyor, yine yok.
///   • Sıradan bir rakip ilk 10'a girmediği için liderlikten de
///     bildirilemiyor.
///   • Sohbete hiç mesaj yazmamış bir rakip long-press yoluyla da
///     engellenemiyor.
///
/// Avatar fotoğrafı uygulamanın en filtresiz UGC yüzeyi —
/// `2026-08-02_profile_report_moderation.sql` kovanın yalnız MIME türü ve
/// 2 MB sınırı denetlediğini açıkça yazıyor. Apple Guideline 1.2 ve Play
/// UGC politikası, bildir/engelle'nin içeriğin KARŞILAŞILDIĞI yerde
/// bulunmasını bekler (2026-08-06 denetimi).
///
/// ## Karar
///
/// Yeni bir backend yok: mevcut `reportPlayerProfile` ve `blockPlayer`
/// çağrıları, mevcut `K.chat*`/`K.reportProfile*` metinleri kullanılıyor.
/// Gizli bir hareket yerine GÖRÜNÜR bir düğme — liderlikteki bildir
/// düğmesinin aynı gerekçesi: keşfedilemeyen bir moderasyon aracı,
/// moderasyon aracı sayılmaz.
///
/// Kendi satırında hiç çizilmez: insan kendini bildiremez/engelleyemez.
class PlayerModerationButton extends StatefulWidget {
  const PlayerModerationButton({
    required this.repository,
    required this.playerId,
    required this.playerName,
    this.isSelf = false,
    this.compact = false,
    this.quiet = false,
    this.onBlocked,
    this.onReported,
    this.onKick,
    super.key,
  });

  final ZanKurdRepository repository;

  /// Bildirilecek/engellenecek oyuncunun kimliği.
  ///
  /// Bot rakiplerde ve kimliği bilinmeyen satırlarda `null` olur; o
  /// durumda düğme çizilmez, çünkü sunucuya gönderilecek bir kimlik yok.
  final String? playerId;

  final String playerName;

  /// Kendi satırı: düğme hiç gösterilmez.
  final bool isSelf;

  /// Dar yerleşimlerde (oda oyuncu satırı) küçük ikon.
  final bool compact;

  /// Sessiz görünüm: bayrak yerine üç nokta (kalabalık listede her satırda
  /// bayrak gürültü yapıyordu); aynı alt sayfayı açar.
  final bool quiet;

  /// Engelleme başarılıysa çağıranın listeyi tazelemesi için.
  final VoidCallback? onBlocked;

  /// Bildirme başarılıysa çağıranın listeyi tazelemesi için (sunucu bildireni
  /// de o oyuncudan korur; sıralama bildirilen avatarı göstermeye devam
  /// etmesin).
  final VoidCallback? onReported;

  /// Verilirse alt sayfada "Odadan çıkar" satırı çıkar (yalnız oda sahibi,
  /// yalnız lobide). Sonuç `true` ise oyuncu çıkarılmıştır.
  final Future<bool> Function()? onKick;

  @override
  State<PlayerModerationButton> createState() => _PlayerModerationButtonState();
}

class _PlayerModerationButtonState extends State<PlayerModerationButton> {
  bool _busy = false;

  Future<void> _openSheet() async {
    final playerId = widget.playerId;
    if (playerId == null || _busy) return;
    setState(() => _busy = true);
    try {
      await showPlayerModerationSheet(
        context: context,
        repository: widget.repository,
        playerId: playerId,
        playerName: widget.playerName,
        onBlocked: widget.onBlocked,
        onReported: widget.onReported,
        onKick: widget.onKick,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSelf || widget.playerId == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: const ValueKey('player-moderation-button'),
      onPressed: _busy ? null : _openSheet,
      // Dokunma hedefi erişilebilirlik alt sınırının altına düşmemeli.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: EdgeInsets.zero,
      iconSize: widget.compact ? 18 : 20,
      tooltip: context.t(K.reportProfileTitle),
      // Bayrak, liderlikteki bildir düğmesiyle aynı görsel dil; ekran
      // okuyucu için de amacı açık.
      icon: Icon(
        widget.quiet ? AppIcons.ellipsisVertical : AppIcons.flag,
        color: SahneTokens.of(context).tx2,
        semanticLabel: context.t(K.reportProfileTitle),
      ),
    );
  }
}

/// Bildir/engelle alt sayfasını açar ve seçilen eylemi uygular.
///
/// Satırdaki görünür bayrak ([PlayerModerationButton]) ve kalabalık odada
/// satıra uzun basış aynı yolu kullanır: iki giriş, tek davranış.
Future<void> showPlayerModerationSheet({
  required BuildContext context,
  required ZanKurdRepository repository,
  required String playerId,
  required String playerName,
  VoidCallback? onBlocked,
  VoidCallback? onReported,
  Future<bool> Function()? onKick,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    // 2026-09-29 Şahnê: alt perde Perde (`s1`), üst köşeler L pah.
    backgroundColor: SahneTokens.of(context).s1,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(SahneShape.lValue),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 2026-10-23: sıralamada ya da aynı odada biriyle karşılaşan
          // oyuncunun arkadaş ekleyebilmesi gerekir; bu satır EN ÜSTTE.
          _AddFriendTile(repository: repository, playerId: playerId),
          if (onKick != null)
            ListTile(
              key: const ValueKey('player-kick-action'),
              leading: const Icon(AppIcons.doorOpen),
              title: Text(sheetContext.t(K.roomKick)),
              subtitle: Text(sheetContext.t(K.roomKickSub)),
              onTap: () => Navigator.of(sheetContext).pop('kick'),
            ),
          ListTile(
            key: const ValueKey('player-report-action'),
            leading: const Icon(AppIcons.flag),
            title: Text(sheetContext.t(K.reportProfileTitle)),
            subtitle: Text(
              Tr.forKu(K.reportProfileBodyP, sheetContext.isKu, {
                'p0': playerName,
              }),
            ),
            onTap: () => Navigator.of(sheetContext).pop('report'),
          ),
          ListTile(
            key: const ValueKey('player-block-action'),
            leading: const Icon(AppIcons.circleXmark),
            title: Text(sheetContext.t(K.chatBlock)),
            subtitle: Text(sheetContext.t(K.chatBlockSub)),
            onTap: () => Navigator.of(sheetContext).pop('block'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  if (action == 'friend') {
    final doneText = context.t(K.requestSent);
    final failText = context.t(K.requestFailed);
    bool ok;
    try {
      ok = await repository.addFriend(playerId, playerName);
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(ok ? doneText : failText)));
    return;
  }

  if (action == 'kick' && onKick != null) {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('kick-player-dialog'),
        title: Text(dialogContext.t(K.roomKick)),
        content: Text(
          Tr.forKu(K.roomKickConfirmP, dialogContext.isKu, {'p0': playerName}),
        ),
        actions: [
          DialogActionPair(
            cancel: TextButton(
              key: const ValueKey('kick-player-cancel'),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.t(K.cancel)),
            ),
            confirm: FilledButton(
              key: const ValueKey('kick-player-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.t(K.roomKick)),
            ),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final doneText = context.t(K.roomKickDone);
    final failText = context.t(K.roomKickFailed);
    final kicked = await onKick();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(kicked ? doneText : failText)));
    return;
  }

  // Alt sayfadaki satıra dokunmak tek başına karar değildir: bildir/engelle
  // geri alınması zor eylemlerdir (bildirim engeli de kurar). Sıralama
  // ekranındaki bildir akışıyla AYNI onay penceresi; Vazgeç hiçbir şey yapmaz.
  final confirmed = await confirmPlayerModeration(
    context: context,
    action: action,
    playerName: playerName,
  );
  if (!confirmed || !context.mounted) return;

  final okText = context.t(
    action == 'report' ? K.reportProfileDone : K.chatBlocked,
  );
  final failText = context.t(K.chatModerationFailed);

  final ok = action == 'report'
      ? await repository.reportPlayerProfile(
          playerId: playerId,
          reason: 'profile_avatar_or_name',
        )
      : await repository.blockPlayer(playerId);

  if (!context.mounted) return;
  if (ok && action == 'block') onBlocked?.call();
  if (ok && action == 'report') onReported?.call();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(ok ? okText : failText)));
}

enum _FriendState { unknown, friend, sent }

/// Alt sayfanın "Arkadaş ekle" satırı.
///
/// Sayfa hemen açılır; arkadaşlık durumu arkadan okunur (arkadaşlar ve
/// gönderilmiş istekler). Zaten arkadaşsa "Arkadaşın", istek gönderilmişse
/// "İstek gönderildi" yazan PASİF satıra döner. Okuma başarısız olursa satır
/// normal kalır: sunucu zaten çifte isteği reddeder, yalan söylemekten iyidir.
class _AddFriendTile extends StatefulWidget {
  const _AddFriendTile({required this.repository, required this.playerId});

  final ZanKurdRepository repository;
  final String playerId;

  @override
  State<_AddFriendTile> createState() => _AddFriendTileState();
}

class _AddFriendTileState extends State<_AddFriendTile> {
  _FriendState _state = _FriendState.unknown;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    try {
      final friends = await widget.repository.loadFriends();
      if (friends.any((Friend f) => f.friendId == widget.playerId)) {
        _set(_FriendState.friend);
        return;
      }
      final sent = await widget.repository.loadSentFriendRequests();
      if (sent?.any((r) => r.toUserId == widget.playerId) ?? false) {
        _set(_FriendState.sent);
      }
    } catch (_) {
      // Okunamadı: satır normal kalır.
    }
  }

  void _set(_FriendState state) {
    if (mounted) setState(() => _state = state);
  }

  @override
  Widget build(BuildContext context) {
    final friend = _state == _FriendState.friend;
    final sent = _state == _FriendState.sent;
    return ListTile(
      key: const ValueKey('player-add-friend-action'),
      enabled: !friend && !sent,
      leading: const Icon(AppIcons.userPlus),
      title: Text(
        context.t(
          friend ? K.friendAlreadyMark : (sent ? K.requestSent : K.addFriend),
        ),
      ),
      onTap: friend || sent ? null : () => Navigator.of(context).pop('friend'),
    );
  }
}

/// Bildir/engelle onay penceresi. `true` yalnız açık onayda döner.
@visibleForTesting
Future<bool> confirmPlayerModeration({
  required BuildContext context,
  required String action,
  required String playerName,
}) async {
  final isReport = action == 'report';
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: ValueKey(isReport ? 'report-profile-dialog' : 'block-player-dialog'),
      title: Text(
        dialogContext.t(isReport ? K.reportProfileTitle : K.chatBlock),
      ),
      content: Text(
        isReport
            ? Tr.forKu(K.reportProfileBodyP, dialogContext.isKu, {
                'p0': playerName,
              })
            : dialogContext.t(K.chatBlockSub),
      ),
      actions: [
        DialogActionPair(
          cancel: TextButton(
            key: const ValueKey('player-moderation-cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.t(K.cancel)),
          ),
          confirm: FilledButton(
            key: const ValueKey('player-moderation-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              dialogContext.t(isReport ? K.reportAction : K.chatBlock),
            ),
          ),
        ),
      ],
    ),
  );
  return result == true;
}
