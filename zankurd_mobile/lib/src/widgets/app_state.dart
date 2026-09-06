import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'roj_mascot.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key = const ValueKey('app-empty-state'),
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

  @override
  Widget build(BuildContext context) {
    return _AppStateScaffold(
      icon: icon,
      iconColor: AppTheme.primaryGradientStart,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      actionIcon: actionIcon,
      // Boş durumlarda Zana düşünceli hâliyle eşlik eder.
      showMascot: true,
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
  });

  final IconData icon;
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _AppStateScaffold(
      icon: icon,
      iconColor: AppTheme.wrong,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
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
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _AppStateScaffold(
      icon: AppIcons.cloud,
      iconColor: AppTheme.secondaryAccent,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
      actionIcon: AppIcons.arrowsRotate,
    );
  }
}

class _AppStateScaffold extends StatelessWidget {
  const _AppStateScaffold({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.showMascot = false,
  });

  /// true ise ikon halkası yerine Zana maskotu (düşünceli) gösterilir;
  /// küçük ikon rozeti köşede kalır (mevcut testler ikonu bulmaya devam eder).
  final bool showMascot;

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final actionLabel = this.actionLabel;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Yükseklik sınırsızsa (kaydırılan bir listenin içindeyiz)
        // `maxHeight - 48` sonsuz olur ve düzen çöker: arkadaş listesi boş
        // olan her yeni kullanıcı bu ekranı kırmızı görüyordu (2026-07-26).
        // Bir çağrı yeri bunu kendi içinde çözmüştü; kural burada olmalı,
        // yoksa her yeni kullanım aynı tuzağa düşer.
        if (!constraints.hasBoundedHeight) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(child: _panel(context, actionLabel)),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
              child: _panel(context, actionLabel),
            ),
          ),
        );
      },
    );
  }

  /// Boş/hata panelinin gövdesi.
  ///
  /// İki dal da bunu kullanır: sınırlı yükseklikte kaydırılabilir bir
  /// kapsayıcının, sınırsızda düz bir dolgunun içinde. Gövdeyi tek yerde
  /// tutmak, iki dalın zamanla ayrışmasını engeller.
  Widget _panel(BuildContext context, String? actionLabel) {
    // Panel bir zamanlar düz beyaz bir kutuydu: krem zeminde beyaz kart,
    // gri metin, soluk çerçeveli düğme. Boş ekranlarda **ekranın tamamı**
    // bu kutudan ibaret olduğu için uygulama orada cansız görünüyordu
    // (2026-07-27, canlı gezinti). Panel artık ekranın vurgu rengini
    // taşıyor: yumuşak bir gradyan, ikonun arkasında renk halkası ve
    // dolgulu bir eylem düğmesi.
    final tint = iconColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              tint.withValues(alpha: 0.10),
              AppTheme.surfaceColor(context),
            ),
            Color.alphaBlend(
              tint.withValues(alpha: 0.02),
              AppTheme.surfaceColor(context),
            ),
          ],
        ),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: showMascot ? 104 : 84,
            height: showMascot ? 104 : 84,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (showMascot) ...[
                  const RojMascot(size: 100, mood: RojMood.thinking),
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceHiColor(context),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(icon, color: iconColor, size: 16),
                    ),
                  ),
                ] else ...[
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: iconColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Icon(icon, color: iconColor, size: 32),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textMutedColor(context),
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            // Boş ekranda tek eylem budur; çerçeveli düğme onu ikincil
            // gösteriyordu. Dolgulu düğme hem çağrıyı hem rengi taşır.
            FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: tint,
                // Sabit beyaz DEĞİL: yazı rengi zemine bağlıdır. Bu düğme
                // uygulamadaki her yükleme hatasının tek eylemidir
                // ("Tekrar dene") ve `AppErrorState` onu `AppTheme.wrong`
                // (#E5533D) ile çağırıyor — beyaz üzerinde ölçülen kontrast
                // 3,73:1, AA eşiği 4,5:1. 14px/w800 olduğu için "büyük
                // metin" istisnasına da girmiyordu (2026-07-31 denetimi).
                //
                // Proje tam bu kusur için `AppColors.onSolid`u yazmıştı;
                // bu dosya yalnızca bekçinin listesinde yoktu.
                foregroundColor: AppColors.onSolid(tint),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                textStyle: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              icon: Icon(actionIcon ?? AppIcons.arrowsRotate, size: 16),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}
