import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/premium_service.dart';
import '../services/analytics_service.dart';
import '../widgets/branded_loader.dart';
import '../widgets/legal_links.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Yıllık fiyatın aya düşen karşılığı — Apple 3.1.2'nin "price per unit if
/// appropriate" maddesi.
///
/// Yıllık fiyat tek başına aylıkla kıyaslanamaz: kullanıcı "₺399,99/yıl"ı
/// görüp bunun "₺39,99/ay"a göre ucuz mu pahalı mı olduğunu ekranda hesap
/// yapmadan bilemez. Apple bu yüzden birim fiyatı ister.
///
/// Sayı, mağazanın kendi fiyat dizesinin BİÇİMİ korunarak yazılır: para
/// birimi simgesi nerede duruyorsa orada kalır (öne, arkaya ya da boşlukla),
/// ondalık ayırıcı mağazanın kullandığı ayırıcıdır. Kendi biçimimizi kurmak
/// (ör. `'₺${x.toStringAsFixed(2)}'`) Türkçe yerelde "₺33.33" gibi yanlış bir
/// metin üretirdi — hem ayırıcı hem simge yeri yanlış — ve `intl` bu projede
/// doğrudan bağımlılık değil.
///
/// Ekrandan ayrı bir işlev olmasının sebebi ölçülebilirlik: RevenueCat
/// `StoreProduct` nesnesi testte kurulamadığı için biçimlendirme widget
/// testinden görünmez; kural burada, saf bir işlevde ölçülür.
String? monthlyEquivalentPrice(String priceString, double annualPrice) {
  if (annualPrice <= 0) return null;
  final first = priceString.indexOf(RegExp(r'\d'));
  final last = priceString.lastIndexOf(RegExp(r'\d'));
  if (first < 0 || last < first) return null;

  final separator = priceString.substring(first, last + 1).contains(',')
      ? ','
      : '.';
  final monthly = (annualPrice / 12)
      .toStringAsFixed(2)
      .replaceFirst('.', separator);
  return priceString.replaceRange(first, last + 1, monthly);
}

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
  bool _paywallViewLogged = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    if (!_paywallViewLogged) {
      _paywallViewLogged = true;
      AnalyticsService.instance.logPaywallView();
    }
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
    final packageId = pkg.identifier;
    AnalyticsService.instance.logEvent('paywall_purchase_started', {
      'package_id': packageId,
    });
    final outcome = await premium.purchasePackage(pkg);
    AnalyticsService.instance.logPurchaseOutcome(
      packageId: packageId,
      outcome: outcome.name,
    );
    if (outcome == PurchaseOutcome.success) {
      AnalyticsService.instance.logPurchaseSuccess(packageId);
    }
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
    AnalyticsService.instance.logRestoreOutcome(outcome.name);
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
    final t = SahneTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      // Bu ekranın hiçbir çıkış yolu yoktu: AppBar'ı, kapat düğmesi ve
      // (AppRoute bir PageRouteBuilder olduğu için) kaydırarak-geri hareketi
      // yoktu; giren kullanıcı uygulamayı öldürmeden çıkamıyordu
      // (2026-07-25 canlı denetimi, iOS). Geri düğmesi uygulamanın geri
      // kalanıyla aynı yerde — AppBar'da — durur.
      //
      // Başlık 'Premium' değil, App Store Connect'teki abonelik adının
      // kendisidir. Apple 3.1.2, otomatik yenilenen aboneliğin ADININ satın
      // alma ekranında yazmasını ister ve 'Premium' bir özellik adıdır,
      // ürün adı değil: mağazadaki ürünler "ZanKurd Pro Monthly/Yearly",
      // grup "ZanKurd Pro". Bu başlıkla kart başlıkları ("Aylık"/"Yıllık")
      // birleşince ekranda tam ürün adı okunur.
      //
      // 2026-09-29 Şahnê: B iskeleti — ad ve alt başlık çubukta. Eski
      // kimlik kartı, kilim bant şeridi ve alttaki üçgen desen kalktı.
      appBar: zkAppBar(
        context,
        title: const Text(AppConfig.subscriptionDisplayName),
        subtitle: Text(context.t(K.paywallSubtitle)),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            0,
            SahneSpace.page,
            SahneSpace.x8,
          ),
          children: [
            // 2026-08-10: `_PaywallHero` kaldırıldı. Ekran aynı değer
            // önerisini ÜÇ kez söylüyordu — üstteki kimlik başlığı, hemen
            // altındaki altın hero ve ardından aynı iki maddeyi sayan fayda
            // listesi. Tekrarı silmek yalnız görsel bir sadeleştirme değil:
            // paketler bir ekran yukarı çıkıyor, yani satın alma kararının
            // verildiği yer ilk bakışta görünüyor.
            SahneSectionHeader(title: context.t(K.paywallFeatures)),
            _Benefits(isKu: ku),
            const SizedBox(height: SahneSpace.x6),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: SahneSpace.x6),
                child: BrandedLoaderCenter(),
              )
            else if (_offeringsLoadFailed)
              _OfferingsLoadError(onRetry: _loadOfferings)
            else if (_packages.isEmpty)
              _EmptyOfferings(isKu: ku, onRetry: _loadOfferings)
            else
              _PackageList(
                packages: _packages,
                onBuy: _buy,
                isKu: ku,
                isBusy: context.watch<PremiumService>().purchaseInProgress,
              ),
            // Geri yükleme ve hukuk bağlantıları yükleme bitince HER durumda
            // görünür; otomatik yenileme koşulları yalnız satın alınabilir
            // bir paket varken (olmayan bir aboneliğin koşulunu saymak
            // ekranın asıl sözünü bastırır — 2026-09-29, K10).
            //
            // 2026-10-01 (A10): geri yükleme eskiden paket yokken de
            // gizliydi. Paketler yüklenemeyen (ağ hatası) ya da henüz
            // aktif olmayan ekranda, başka cihazdan abone olmuş kullanıcı
            // aboneliğini geri getirecek TEK yolu görmüyordu; yeniden
            // satın almaya itiliyordu. Restore, ürün listesine bağlı
            // değildir.
            if (!_loading) ...[
              const SizedBox(height: SahneSpace.x6),
              _FooterActions(
                isKu: ku,
                onRestore: _restore,
                showRenewalTerms: _packages.isNotEmpty,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Premium'un iki faydası — liste grubu. Seri koruması ödül ailesidir
/// (Zêr), destek nötr.
class _Benefits extends StatelessWidget {
  const _Benefits({required this.isKu});
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return SahneListGroup(
      children: [
        SahneListRow.icon(
          icon: AppIcons.shield,
          role: SahneRole.gold,
          title: Tr.forKu(K.paywallPerkStreak, isKu),
          subtitle: Tr.forKu(K.paywallPerkStreakBody, isKu),
        ),
        SahneListRow.icon(
          icon: AppIcons.heart,
          title: Tr.forKu(K.paywallPerkSupport, isKu),
          subtitle: Tr.forKu(K.paywallPerkSupportBody, isKu),
        ),
      ],
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
      // annual < monthly < diğer: en iyi değer önce, featured yıllıkta.
      int weight(Package p) {
        if (p.packageType == PackageType.annual) return 1;
        if (p.packageType == PackageType.monthly) return 2;
        return 3;
      }

      return weight(a).compareTo(weight(b));
    });
    // Ekranda tek birincil eylem: öne çıkan (yıllık) paketin düğmesi. Yıllık
    // yoksa ilk paket birincil olur; ötekiler ikincil.
    final primaryIndex = ordered.indexWhere(
      (p) => p.packageType == PackageType.annual,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < ordered.length; i++) ...[
          if (i > 0) const SizedBox(height: SahneSpace.cardGap),
          _PackageRow(
            package: ordered[i],
            isKu: isKu,
            primary: i == (primaryIndex < 0 ? 0 : primaryIndex),
            isBusy: isBusy,
            onBuy: () => onBuy(ordered[i]),
          ),
        ],
      ],
    );
  }
}

class _PackageRow extends StatelessWidget {
  const _PackageRow({
    required this.package,
    required this.isKu,
    required this.primary,
    required this.onBuy,
    required this.isBusy,
  });

  final Package package;
  final bool isKu;
  final bool primary;
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

  /// Her dönemde aynı söz: iptal koşulu yalnız aylık pakette yazıldığında
  /// yıllık paket "iptal edilemez" gibi okunuyordu. İptal her pakette
  /// aynıdır (yenilemeyi durdurur); karttaki söz bunu simetrik söyler.
  String _packageSubtitle() => Tr.forKu(K.cancelAnytime, isKu);

  String? _perMonthEquivalent() {
    if (package.packageType != PackageType.annual) return null;
    final monthly = monthlyEquivalentPrice(
      package.storeProduct.priceString,
      package.storeProduct.price,
    );
    if (monthly == null) return null;
    return '≈ $monthly${Tr.forKu(K.perMonthSuffix, isKu)}';
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
    final t = SahneTokens.of(context);
    final price = package.storeProduct.price;
    final priceString = package.storeProduct.priceString;
    final label = Tr.forKu(K.buyAction, isKu);
    // Fiyatı çözülemeyen paket (mağaza fiyat vermedi) satın alınamaz:
    // "Fiyat geliyor" yazan bir kartın "Satın al" düğmesi, kullanıcıyı
    // ne ödeyeceğini bilmeden onaya götürürdü (Apple 3.1.2: fiyat satın
    // alma anında görünür olmalı).
    final onPressed = (isBusy || price <= 0) ? null : onBuy;
    // Paket bir yüzey kartıdır. Rozet yok: "En çok alınan" gibi bir söz
    // için satış verisi yoktu (mağazadaki aynı rozet 2026-09-29'da bu
    // yüzden kalkmıştı); yıllık paketin gerçek farkı aşağıdaki "≈ aylık"
    // satırıdır ve mağazanın kendi fiyatından hesaplanır.
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _packageTitle(),
                style: SahneType.headline.copyWith(color: t.tx),
              ),
            ],
          ),
          Text(
            _packageSubtitle(),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x2),
          Text(
            price > 0
                ? '$priceString${_pricePeriodSuffix()}'
                : Tr.forKu(K.priceComing, isKu),
            style: SahneType.bodyStrong.copyWith(
              color: t.tx,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (_perMonthEquivalent() case final perMonth?)
            Text(perMonth, style: SahneType.caption.copyWith(color: t.tx2)),
          const SizedBox(height: SahneSpace.x4),
          primary
              ? SahneButton.primary(
                  label: label,
                  expand: true,
                  onPressed: onPressed,
                )
              : SahneButton.secondary(
                  label: label,
                  expand: true,
                  onPressed: onPressed,
                ),
        ],
      ),
    );
  }
}

/// Bilgi kartı: ikon + başlık + açıklama + yeniden deneme bağlantısı.
/// [error] durumunda ikon Şaş metninde (durum ikon ve sözle birlikte).
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
    this.error = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 20, color: error ? t.errTx : t.tx2),
              ),
              const SizedBox(width: SahneSpace.x2),
              Expanded(
                child: Text(
                  title,
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(body, style: SahneType.caption.copyWith(color: t.tx2)),
          const SizedBox(height: SahneSpace.x1),
          SahneButton.text(label: retryLabel, onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Offering çekildi ama içinde paket yok.
///
/// Bu bir hata DEĞİLDİR — fetch başarılı döner — ama kullanıcı açısından
/// sonucu aynıdır: satın alacak bir şey yoktur. Aradaki tek fark, bu
/// durumun dışarıdan (RevenueCat panelinde offering ↔ mağaza ürünü
/// eşlemesi tamamlandığında) kendiliğinden düzelmesidir. Bu yüzden ekran
/// dürüst kalır (sahte fiyat veya sahte paket uydurulmaz) fakat çıkışsız
/// bırakılmaz: hata durumuyla aynı yeniden deneme yolu sunulur.
class _EmptyOfferings extends StatelessWidget {
  const _EmptyOfferings({required this.isKu, required this.onRetry});
  final bool isKu;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      icon: AppIcons.circleInfo,
      title: Tr.forKu(K.paywallPackagesInactive, isKu),
      body: Tr.forKu(K.paywallPackagesInactiveBody, isKu),
      retryLabel: Tr.forKu(K.retry, isKu),
      onRetry: onRetry,
    );
  }
}

class _OfferingsLoadError extends StatelessWidget {
  const _OfferingsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _NoticeCard(
      icon: AppIcons.triangleExclamation,
      title: context.t(K.genericErrorTitle),
      body: context.t(K.genericErrorBody),
      retryLabel: context.t(K.retry),
      onRetry: onRetry,
      error: true,
    );
  }
}

class _FooterActions extends StatelessWidget {
  const _FooterActions({
    required this.isKu,
    required this.onRestore,
    required this.showRenewalTerms,
  });
  final bool isKu;
  final VoidCallback onRestore;

  /// Satın alınabilir paket varken true: yenileme koşulları yalnız o zaman
  /// yazılır.
  final bool showRenewalTerms;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SahneButton.text(
            label: Tr.forKu(K.restorePurchases, isKu),
            arrow: false,
            onPressed: onRestore,
          ),
        ),
        const SizedBox(height: SahneSpace.x2),
        if (showRenewalTerms) ...[
          // Apple App Store Review 3.1.2 ve Google Play abonelik politikası,
          // otomatik yenileme koşullarının satın alma ekranının KENDİSİNDE
          // yazmasını ister: yenileme, ücretlendirme anı ve iptal yolu.
          Text(
            Tr.forKu(K.paywallRenewalTerms, isKu),
            style: SahneType.caption.copyWith(color: t.tx3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SahneSpace.x2),
        ],
        // Yasal bağlantılar — abonelikli uygulamalarda Apple zorunlu tutar.
        const Center(child: LegalLinksRow(alignment: MainAxisAlignment.center)),
      ],
    );
  }
}
