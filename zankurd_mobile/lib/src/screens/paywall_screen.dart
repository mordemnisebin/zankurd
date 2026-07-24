import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
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

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _loading = true);
    final premium = context.read<PremiumService>();
    final offerings = await premium.fetchOfferings();
    final pkgs = <Package>[];
    for (final o in offerings) {
      pkgs.addAll(o.availablePackages);
    }
    if (!mounted) return;
    setState(() {
      _packages = pkgs;
      _loading = false;
    });
  }

  Future<void> _buy(Package pkg) async {
    final premium = context.read<PremiumService>();
    await premium.purchasePackage(pkg);
    if (!mounted) return;
    if (premium.isPremium) {
      Navigator.of(context).pop();
    } else if (premium.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(premium.errorMessage!)));
    }
  }

  Future<void> _restore() async {
    final premium = context.read<PremiumService>();
    await premium.restorePurchases();
    if (!mounted) return;
    if (premium.isPremium) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              ScreenIdentityHeader(
                title: ku ? 'Premium' : 'Premium',
                subtitle: ku
                    ? 'Dersên kûrtî bê sînor, bi zanebûnê'
                    : 'Sınırsız bilgi, daha fazlası',
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
                        label: ku ? 'Taybetmendiyên' : 'Özellikler',
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
            isKu ? 'ZanKurd Premium' : 'ZanKurd Premium',
            style: AppTypography.heading1.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            isKu
                ? 'Pirsên dijwar, kekira taybet, statistîkên kûr.'
                : 'Zor sorular, özel rozetler, derin istatistikler.',
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
        icon: AppIcons.circleXmark,
        title: isKu ? 'Bê reklam' : 'Reklamsız',
        description: isKu
            ? 'Reklam tune, dûr bê qerebûn.'
            : 'Reklamsız, kesintisiz deneyim.',
        color: AppTheme.gold,
      ),
      _Benefit(
        icon: AppIcons.chartLine,
        title: isKu ? 'Statistîkên kûr' : 'Derin istatistikler',
        description: isKu
            ? 'Dîroka pirsan, performansa kategoriyan, divêk bisekin.'
            : 'Soru geçmişi, kategori performansı, kişisel trendler.',
        color: AppTheme.violet,
      ),
      _Benefit(
        icon: AppIcons.bolt,
        title: isKu ? 'Sînor jokers' : 'Sınırsız joker',
        description: isKu
            ? '50/50, temaşa, ducar bersiv, pirs nû — sînor tune.'
            : '50/50, seyirci, çift cevap, yeni soru — sınırsız.',
        color: AppTheme.violet,
      ),
      _Benefit(
        icon: AppIcons.gem,
        title: isKu ? 'Mode xurt' : 'Özel modlar',
        description: isKu
            ? 'Turnûva premium, kategori taybet, pirsên nû.'
            : 'Premium turnuvalar, özel kategoriler, yeni sorular.',
        color: AppTheme.brand,
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(benefit.icon, color: accentColor, size: 18),
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
        return isKu ? 'Mehane' : 'Aylık';
      case PackageType.annual:
        return isKu ? 'Salane' : 'Yıllık';
      case PackageType.weekly:
        return isKu ? 'Heftane' : 'Haftalık';
      default:
        return package.identifier;
    }
  }

  String _packageSubtitle() {
    if (package.packageType == PackageType.annual) {
      return isKu ? '2 mehane xerc mesrefa' : '2 ay bedava';
    }
    if (package.packageType == PackageType.monthly) {
      return isKu ? 'Her mehane bêpûçkirin' : 'İstediğin zaman iptal';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final price = package.storeProduct.price;
    final priceString = package.storeProduct.priceString;
    final accentColor = featured ? AppTheme.gold : null;
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
                          isKu ? 'YÊ' : 'POPÜLER',
                          style: const TextStyle(
                            fontSize: 9,
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
                      ? priceString
                      : (isKu ? 'Biha tê' : 'Fiyat geliyor'),
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
              backgroundColor: featured
                  ? AppTheme.gold
                  : AppTheme.primaryGradientStart,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              disabledBackgroundColor: AppColors.disabledSurface(context),
            ),
            onPressed: isBusy ? null : onBuy,
            child: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isKu ? 'Bikirin' : 'Satın al',
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
                  isKu
                      ? 'Pakêtên premium hê nehate vekirin'
                      : 'Premium paketler henüz aktif değil',
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
            isKu
                ? 'Kurteyê Premium dê di rojekê de xuya bibin. Ji kerema xwe piştre vegere.'
                : 'Premium paketler kısa süre içinde aktif olacak. Lütfen daha sonra tekrar bakın.',
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
            isKu ? 'Kirrinan vegerîn' : 'Satın alımları geri yükle',
            style: AppTypography.caption.copyWith(
              color: AppTheme.textSubColor(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          isKu
              ? 'Dema kirrinan pê hatin hate vegerandin; bêpûçkirin ji bo carekê dike.'
              : 'Ödemeler Google/Apple tarafından yönetilir; istediğiniz zaman iptal edebilirsiniz.',
          style: AppTypography.caption.copyWith(
            color: AppTheme.textMutedColor(context),
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
