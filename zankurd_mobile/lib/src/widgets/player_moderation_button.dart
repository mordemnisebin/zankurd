import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
    this.onBlocked,
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

  /// Engelleme başarılıysa çağıranın listeyi tazelemesi için.
  final VoidCallback? onBlocked;

  @override
  State<PlayerModerationButton> createState() => _PlayerModerationButtonState();
}

class _PlayerModerationButtonState extends State<PlayerModerationButton> {
  bool _busy = false;

  Future<void> _openSheet() async {
    final playerId = widget.playerId;
    if (playerId == null || _busy) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('player-report-action'),
              leading: const Icon(AppIcons.flag),
              title: Text(sheetContext.t(K.reportProfileTitle)),
              subtitle: Text(
                Tr.forKu(K.reportProfileBodyP, sheetContext.isKu, {
                  'p0': widget.playerName,
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
    if (action == null || !mounted) return;

    setState(() => _busy = true);
    final okText = context.t(
      action == 'report' ? K.reportProfileDone : K.chatBlocked,
    );
    final failText = context.t(K.chatModerationFailed);

    final ok = action == 'report'
        ? await widget.repository.reportPlayerProfile(
            playerId: playerId,
            reason: 'profile_avatar_or_name',
          )
        : await widget.repository.blockPlayer(playerId);

    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && action == 'block') widget.onBlocked?.call();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(ok ? okText : failText)));
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
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      iconSize: widget.compact ? 18 : 20,
      tooltip: context.t(K.reportProfileTitle),
      // Bayrak, liderlikteki bildir düğmesiyle aynı görsel dil; ekran
      // okuyucu için de amacı açık.
      icon: Icon(
        AppIcons.flag,
        color: AppTheme.textMutedColor(context),
        semanticLabel: context.t(K.reportProfileTitle),
      ),
    );
  }
}
