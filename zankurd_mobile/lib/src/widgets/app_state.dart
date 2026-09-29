import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import 'roj_mascot.dart';
import 'sahne/sahne.dart';

/// Boş durum: 32'lik bağlamsal çizgi ikon + başlık + açıklama + isteğe
/// bağlı TEK eylem.
///
/// 2026-09-29 doğallık (K3): eskiden logo işareti plakası + köşesinde durum
/// karosu vardı. Her boş listede aynı logonun belirmesi şablon izi
/// bırakıyordu ve plakadaki logo kenarı kırıntılıydı. Artık yalnız
/// bağlamı söyleyen ikon ([icon], üçüncül metin rengi); boş, hata ve
/// çevrimdışı yine şekille (ikonla) ve başlıkla ayrışır.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key = const ValueKey('app-empty-state'),
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.primaryAction = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  /// Eylem ekranın tek birincil eylemi mi (Agir)? `false`: ikincil (Kulis),
  /// ekranda başka bir birincil eylem varken.
  final bool primaryAction;

  @override
  Widget build(BuildContext context) {
    return _AppStateScaffold(
      icon: icon,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      actionIcon: actionIcon,
      primaryAction: primaryAction,
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key = const ValueKey('app-error-state'),
    this.icon = AppIcons.triangleExclamation,
    this.showMascot = false,
    this.mascotMood = RojMood.sad,
    this.primaryAction = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  /// Geriye uyum; yok sayılır. Durumlarda maskot ya da logo plakası yok
  /// (2026-09-29 doğallık, K3): yalnız bağlamsal ikon.
  final bool showMascot;
  final RojMood mascotMood;

  /// Bkz. [AppEmptyState.primaryAction].
  final bool primaryAction;

  @override
  Widget build(BuildContext context) {
    return _AppStateScaffold(
      icon: icon,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
      actionIcon: AppIcons.arrowsRotate,
      primaryAction: primaryAction,
    );
  }
}

class AppOfflineState extends StatelessWidget {
  const AppOfflineState({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key = const ValueKey('app-offline-state'),
    this.showMascot = false,
    this.mascotMood = RojMood.thinking,
    this.primaryAction = true,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  /// Geriye uyum; yok sayılır. Durumlarda maskot ya da logo plakası yok
  /// (2026-09-29 doğallık, K3): yalnız bağlamsal ikon.
  final bool showMascot;
  final RojMood mascotMood;

  /// Bkz. [AppEmptyState.primaryAction].
  final bool primaryAction;

  @override
  Widget build(BuildContext context) {
    return _AppStateScaffold(
      icon: AppIcons.cloud,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
      actionIcon: AppIcons.arrowsRotate,
      primaryAction: primaryAction,
    );
  }
}

class _AppStateScaffold extends StatelessWidget {
  const _AppStateScaffold({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryAction,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final bool primaryAction;

  /// Durum ikonunun kenarı.
  static const double iconSize = 32;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Yükseklik sınırsızsa (kaydırılan bir listenin içindeyiz)
        // `maxHeight - 48` sonsuz olur ve düzen çöker: arkadaş listesi boş
        // olan her yeni kullanıcı bu ekranı kırmızı görüyordu (2026-07-26).
        // Bir çağrı yeri bunu kendi içinde çözmüştü; kural burada olmalı,
        // yoksa her yeni kullanım aynı tuzağa düşer.
        if (!constraints.hasBoundedHeight) {
          return Padding(
            padding: const EdgeInsets.all(SahneSpace.x6),
            child: Center(child: _panel(context)),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(SahneSpace.x6),
          child: ConstrainedBox(
            // Üstteki sabit bölüm uzadığında kalan yükseklik 48'in altına
            // inebilir (öğrenme ekranında boş ders listesi + hikâye
            // kataloğu): negatif alt sınır düzeni çökertir. Sıfıra kelepçele;
            // panel doğal boyunda çizilir, kaydırma geri kalanı taşır.
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(
                0.0,
                double.infinity,
              ),
            ),
            // Tam ortalama, üstteki sekmelerle panel arasında ~250pt boş
            // bırakıyordu; ekran yarım yüklenmiş gibi duruyordu. Panel
            // üst üçte bire çekildi: içerikle bağı kopmuyor (2026-07-27).
            child: Align(
              alignment: const Alignment(0, -0.45),
              child: _panel(context),
            ),
          ),
        );
      },
    );
  }

  /// Boş/hata bloğunun gövdesi.
  ///
  /// İki dal da bunu kullanır: sınırlı yükseklikte kaydırılabilir bir
  /// kapsayıcının, sınırsızda düz bir dolgunun içinde. Gövdeyi tek yerde
  /// tutmak, iki dalın zamanla ayrışmasını engeller.
  Widget _panel(BuildContext context) {
    final t = SahneTokens.of(context);
    final actionLabel = this.actionLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bağlamsal çizgi ikon (dekoratif; başlık okunur). Hata da aynı
        // üçüncül renktedir: durum ikonun şekli ve başlıkla söylenir, kırmızı
        // bir alarm plakasıyla değil.
        ExcludeSemantics(
          child: Icon(icon, size: iconSize, color: t.tx3),
        ),
        const SizedBox(height: SahneSpace.x4),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: SahneType.headline.copyWith(color: t.tx),
          ),
        ),
        const SizedBox(height: SahneSpace.x2),
        Text(
          message,
          textAlign: TextAlign.center,
          style: SahneType.body.copyWith(color: t.tx2),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: SahneSpace.x6),
          // Agir üstünde metin her zaman koyu (`onAct`): Şahnê düğmesi bunu
          // temadan alır. Eski düğme hata rengine beyaz yazıyordu (3,73:1).
          primaryAction
              ? SahneButton.primary(
                  label: actionLabel,
                  onPressed: onAction,
                  icon: actionIcon,
                  arrow: false,
                )
              : SahneButton.secondary(
                  label: actionLabel,
                  onPressed: onAction,
                  icon: actionIcon,
                ),
        ],
      ],
    );
  }
}
