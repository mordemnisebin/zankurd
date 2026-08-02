import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import '../widgets/legal_links.dart';
import '../widgets/screen_identity_header.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Premium abonelik satın alma ekranı. RevenueCat üzerinden aylık
/// abonelikler sunar. Yapılandırma yoksa veya offerings boşsa
/// kullanıcı dostu bir "yakında" görünümü gösterir.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<Package> _packages = [];
  bool _loading = true;
  bool _offeringsLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _loading = true);
    final premium = context.read<PremiumService>();
    final pkgs = <Package>[];
    final result = await premium.fetchOfferings();
    if (result case OfferingsFetchSuccess(:final offerings)) {
      for (final offering in offerings) {
        pkgs.addAll(offering.availablePackages);
      }
    }
    if (!mounted) return;
    setState(() {
      _packages = pkgs;
      _offeringsLoadFailed = result is OfferingsFetchFailure;
      _loading = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _buy(Package pkg) async {
    final premium = context.read<PremiumService>();
    final outcome = await premium.purchasePackage(pkg);
    if (!mounted) return;
    switch (outcome) {
      case PurchaseOutcome.success:
        Navigator.of(context).pop();
      case PurchaseOutcome.cancelled:
      case PurchaseOutcome.inProgress:
        // Kullanıcı vazgeçti ya da akış zaten sürüyor: mesaj gösterme.
        break;
      case PurchaseOutcome.pending:
        _showMessage(context.t(K.paywallPaymentPending));
      case PurchaseOutcome.failed:
        _showMessage(context.t(K.paywallPurchaseFailed));
    }
  }

  Future<void> _restore() async {
    final premium = context.read<PremiumService>();
    final outcome = await premium.restorePurchases();
    if (!mounted) return;
    switch (outcome) {
      case RestoreOutcome.restored:
        Navigator.of(context).pop();
        return;
      case RestoreOutcome.nothingFound:
        _showMessage(context.t(K.paywallRestoreNothing));
      case RestoreOutcome.failed:
        _showMessage(context.t(K.paywallRestoreFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      backgroundColor: AppTheme.bgOf(context),
      // Bu ekranın hiçbir çıkış yolu yoktu: AppBar'ı, kapat düğmesi ve
      // (AppRoute bir PageRouteBuilder olduğu için) kaydırarak-geri hareketi
      // yoktu; giren kullanıcı uygulamayı öldürmeden çıkamıyordu
      // (2026-07-25 canlı denetimi, iOS). Geri düğmesi uygulamanın geri
      // kalanıyla aynı yerde — AppBar'da — durur.
      appBar: AppBar(
        backgroundColor: AppTheme.bgOf(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryColor(context)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              ScreenIdentityHeader(
                title: 'Premium',
                subtitle: context.t(K.paywallSubtitle),
                accent: AppTheme.gold,
                icon: AppIcons.gem,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.md,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PaywallHero(isKu: ku),
                      const SizedBox(height: AppSpacing.lg),
                      ScreenSectionLabel(
                        label: context.t(K.paywallFeatures),
                        accent: AppTheme.gold,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _Benefits(isKu: ku),
                      const SizedBox(height: AppSpacing.lg),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.gold,
                            ),
                          ),
                        )
                      else if (_offeringsLoadFailed)
                        _OfferingsLoadError(onRetry: _loadOfferings)
                      else if (_packages.isEmpty)
                        _EmptyOfferings(isKu: ku)
                      else
                        _PackageList(
                          packages: _packages,
                          onBuy: _buy,
                          isKu: ku,
                          isBusy: context
                              .watch<PremiumService>()
                              .purchaseInProgress,
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      _FooterActions(isKu: ku, onRestore: _restore),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaywallHero extends StatelessWidget {
  const _PaywallHero({required this.isKu});
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.gold, AppTheme.brandDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.gem, color: Colors.white, size: 36),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Tr.forKu(K.paywallHeroTitle, isKu),
            style: AppTypography.heading1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            Tr.forKu(K.paywallHeroSub, isKu),
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits({required this.isKu});
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final benefits = <_Benefit>[
      _Benefit(
        icon: AppIcons.shield,
        title: Tr.forKu(K.paywallPerkStreak, isKu),
        description: Tr.forKu(K.paywallPerkStreakBody, isKu),
        color: AppTheme.brand,
      ),
      _Benefit(
        icon: AppIcons.heart,
        title: Tr.forKu(K.paywallPerkSupport, isKu),
        description: Tr.forKu(K.paywallPerkSupportBody, isKu),
        color: AppTheme.gold,
      ),
    ];
    return Column(
      children: [
        for (final b in benefits)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _BenefitRow(benefit: b),
          ),
      ],
    );
  }
}

class _Benefit {
  _Benefit({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.benefit});
  final _Benefit benefit;

  @override
  Widget build(BuildContext context) {
    final accentColor = benefit.color;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Icon(
              benefit.icon,
              color: AppColors.onAccentTint(context, accentColor),
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  benefit.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  benefit.description,
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textSubColor(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageList extends StatelessWidget {
  const _PackageList({
    required this.packages,
    required this.onBuy,
    required this.isKu,
    required this.isBusy,
  });

  final List<Package> packages;
  final ValueChanged<Package> onBuy;
  final bool isKu;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    // İlk paketin yıllık/yıllık olduğunu kontrol et; öne çıkar.
    final ordered = [...packages];
    ordered.sort((a, b) {
      // monthly < annual < weekly gibi listeyi tipik sıraya koy
      int weight(Package p) {
        if (p.packageType == PackageType.monthly) return 1;
        if (p.packageType == PackageType.annual) return 2;
        return 3;
      }

      return weight(a).compareTo(weight(b));
    });
    return Column(
      children: [
        for (var i = 0; i < ordered.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.xs),
            child: _PackageRow(
              package: ordered[i],
              isKu: isKu,
              featured: ordered[i].packageType == PackageType.monthly,
              isBusy: isBusy,
              onBuy: () => onBuy(ordered[i]),
            ),
          ),
      ],
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.package,
    required this.isKu,
    required this.featured,
    required this.onBuy,
    required this.isBusy,
  });

  final Package package;
  final bool isKu;
  final bool featured;
  final bool isBusy;
  final VoidCallback onBuy;

  String _packageTitle() {
    switch (package.packageType) {
      case PackageType.monthly:
        return Tr.forKu(K.periodMonthly, isKu);
      case PackageType.annual:
        return Tr.forKu(K.periodAnnual, isKu);
      case PackageType.weekly:
        return Tr.forKu(K.periodWeekly, isKu);
      default:
        return package.identifier;
    }
  }

  String _packageSubtitle() {
    if (package.packageType == PackageType.monthly) {
      return Tr.forKu(K.cancelAnytime, isKu);
    }
    return '';
  }

  /// Fiyatın yanında gösterilen yenileme dönemi. Apple 3.1.2, fiyatın
  /// hangi dönem için olduğunun paywall'da açıkça yazmasını ister.
  String _pricePeriodSuffix() {
    return switch (package.packageType) {
      PackageType.monthly => Tr.forKu(K.perMonthSuffix, isKu),
      PackageType.annual => Tr.forKu(K.perYearSuffix, isKu),
      PackageType.weekly => Tr.forKu(K.perWeekSuffix, isKu),
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final price = package.storeProduct.price;
    final priceString = package.storeProduct.priceString;
    final accentColor = featured ? AppTheme.gold : null;
    final buttonBackground = featured
        ? AppTheme.gold
        : AppTheme.primaryGradientStart;
    final buttonForeground = AppColors.onSolid(buttonBackground);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color:
              accentColor?.withValues(alpha: 0.45) ??
              AppTheme.borderColor(context),
          width: featured ? 1.5 : 1,
        ),
        boxShadow: featured
            ? [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _packageTitle(),
                      style: AppTypography.heading2.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    if (featured) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          Tr.forKu(K.popularBadge, isKu),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppTheme.gold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_packageSubtitle().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _packageSubtitle(),
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textSubColor(context),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  price > 0
                      ? '$priceString${_pricePeriodSuffix()}'
                      : Tr.forKu(K.priceComing, isKu),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBackground,
              foregroundColor: buttonForeground,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              disabledBackgroundColor: AppColors.disabledSurface(context),
            ),
            onPressed: isBusy ? null : onBuy,
            child: isBusy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: buttonForeground,
                    ),
                  )
                : Text(
                    Tr.forKu(K.buyAction, isKu),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyOfferings extends StatelessWidget {
  const _EmptyOfferings({required this.isKu});
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.circleInfo, color: AppTheme.gold),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  Tr.forKu(K.paywallPackagesInactive, isKu),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Tr.forKu(K.paywallPackagesInactiveBody, isKu),
            style: AppTypography.caption.copyWith(
              color: AppTheme.textSubColor(context),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferingsLoadError extends StatelessWidget {
  const _OfferingsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.triangleExclamation, color: AppTheme.wrong),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.t(K.genericErrorTitle),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.t(K.genericErrorBody),
            style: AppTypography.caption.copyWith(
              color: AppTheme.textSubColor(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.arrowsRotate),
            label: Text(context.t(K.retry)),
          ),
        ],
      ),
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({required this.isKu, required this.onRestore});
  final bool isKu;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: onRestore,
          child: Text(
            Tr.forKu(K.restorePurchases, isKu),
            style: AppTypography.caption.copyWith(
              color: AppTheme.textSubColor(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Apple App Store Review 3.1.2 ve Google Play abonelik politikası,
        // otomatik yenileme koşullarının satın alma ekranının KENDİSİNDE
        // yazmasını ister: yenileme, ücretlendirme anı ve iptal yolu.
        Text(
          Tr.forKu(K.paywallRenewalTerms, isKu),
          style: AppTypography.caption.copyWith(
            color: AppTheme.textMutedColor(context),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Yasal bağlantılar — abonelikli uygulamalarda Apple zorunlu tutar.
        const Center(child: LegalLinksRow(alignment: MainAxisAlignment.center)),
      ],
    );
  }
}
