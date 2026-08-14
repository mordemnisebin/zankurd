import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/zankurd_repository.dart';
import '../data/supabase_zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/avatar_identity.dart';
import '../providers/sound_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../utils/network_error.dart';
import '../widgets/app_state.dart';
import '../widgets/roj_mascot.dart';
import '../widgets/screen_identity_header.dart';
import 'spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// `shop_items` tablosundaki `icon_name` sütununu [IconData]'ya çevirir.
/// Statik yedek listedeki (`ShopItem._items`) her ikon burada da
/// tanımlı olmalı — aksi halde canlı katalog jenerik çanta ikonuna düşer.
///
/// Map tabanlı arama kasıtlı: bir switch-expression'la yazıldığında web
/// derlemesinde (dart2js) yalnızca ilk birkaç dal doğru eşleşiyor, sonraki
/// dallar sessizce varsayılana düşüyordu (VM'de çalışan `flutter test` bunu
/// yakalamadı — bu yüzden canlıda fark edildi).
const Map<String, IconData> _shopIcons = {
  'auto_awesome_motion_outlined': AppIcons.wandMagicSparkles,
  'favorite_border_rounded': AppIcons.heart,
  'casino_outlined': AppIcons.dice,
  'palette_outlined': AppIcons.palette,
  'star_rounded': AppIcons.star,
  'auto_awesome_rounded': AppIcons.wandMagicSparkles,
  'text_fields_rounded': AppIcons.font,
  'text_format_rounded': AppIcons.font,
  'auto_fix_high_rounded': AppIcons.wandMagicSparkles,
  'diamond_rounded': AppIcons.gem,
  'sun_regular': AppIcons.sun,
  'star_regular': AppIcons.star,
  'image_regular': AppIcons.image,
};

IconData shopIconForName(String? name) =>
    _shopIcons[name] ?? AppIcons.bagShopping;

AvatarIdentity applyShopPurchaseEffect(String itemId, AvatarIdentity identity) {
  if (itemId == 'avatar_frame_gold') {
    return identity.copyWith(frameId: 'gold');
  }
  // Neon çerçeve satın alındığında kutlama dialog'u çıkıyor ama profile
  // dönünce hiçbir şey görünmüyordu: bu dal hiç yoktu, yani `frameId`
  // asla 'neon' olarak yazılmıyordu — sahiplik `hasPurchased` ile
  // kaydediliyor ama AKTİF çerçeve hiç değişmiyordu (2026-08-14 denetimi).
  if (itemId == 'avatar_frame_neon') {
    return identity.copyWith(frameId: 'neon');
  }
  if (itemId == 'profile_badge_vip') {
    return identity.copyWith(showcaseTitle: 'VIP');
  }
  return identity;
}

/// `shop_items` tablosundaki `theme_color` (ör. "FF3B81") sütununu
/// [Color]'a çevirir.
Color shopColorForHex(String? hex) {
  if (hex == null) return AppTheme.accent;
  try {
    final cleanHex = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  } catch (_) {
    return AppTheme.accent;
  }
}

class ShopItem {
  final String id;
  final String titleKu;
  final String titleTr;
  final String descKu;
  final String descTr;
  final int cost;
  final IconData icon;
  final Color themeColor;

  const ShopItem({
    required this.id,
    required this.titleKu,
    required this.titleTr,
    required this.descKu,
    required this.descTr,
    required this.cost,
    required this.icon,
    required this.themeColor,
  });
}

/// Test-only erişim: mağaza kataloğunun statik yedek listesi.
///
/// Yalnız etkisi gerçekten uygulanmış yayın ürünlerini döndürür.
@visibleForTesting
List<ShopItem> get debugShopItems => _ShopScreenState._items
    .where((item) => _ShopScreenState._supportedItemIds.contains(item.id))
    .toList(growable: false);

class ShopScreen extends StatefulWidget {
  const ShopScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _coinBalance = 0;
  bool _loading = false;
  bool _loadError = false;
  bool _loadOffline = false;
  String? _purchaseErrorMessage;
  bool _purchaseOffline = false;
  ShopItem? _retryPurchaseItem;
  final Set<String> _purchasedItemIds = {};
  List<ShopItem> _dynamicItems = const [];

  // Sunucuda ürün kaydı bulunması tek başına yayına hazır olduğu anlamına
  // gelmez. Coin düşürüp etkisi olmayan taslak ürünler burada görünmez.
  // Bir ürün bu kümede YOKSA vitrinde görünmez. 2026-07-31'e kadar katalog
  // 13 ürün tanımlıyordu ama küme yalnız 3'ünü geçiriyordu; kalan 10'u ölü
  // veriydi. Coin ekonomisinin harcama tarafı böylece neredeyse kapalıydı:
  // kazanç sürüyor (quiz + günlük çark) ama harcanacak yer üç kalemdi,
  // bakiye şişip anlamsızlaşıyordu.
  //
  // Karşılığı olmayan dokuz ürün katalogdan tamamen SİLİNDİ — kümeye
  // yanlışlıkla eklenirlerse coin alıp hiçbir şey yapmazlardı. Neon
  // çerçeve ise gerçekten uygulandı (AvatarFrame.neon), o yüzden kaldı.
  //
  // Silinenler ve niçin uygulanmadıkları:
  //   emoji_roj, emoji_ster, frame_simple, premium_colors — profil
  //     kozmetiği için taşıyıcı alan yok.
  //   joker_bundle, joker_pack_3, extra_lifeline — jokerler tur başına
  //     sıfırlanıyor; kalıcı stok kavramı yok.
  //   name_color_gold, name_color_purple — isim rengi ancak DİĞER
  //     oyunculara görünürse anlamlı; bu sunucu tarafı yayılım ister
  //     (profiles kolonu + liderlik sorgusunda taşınması). İstemcide
  //     yapılabilecek bir şey değil.
  //
  // Kural: bu kümeye bir kimlik eklemek, o ürünün gerçekten bir şey
  // yaptığı anlamına gelir.
  static const Set<String> _supportedItemIds = {
    'spin_wheel_extra',
    'avatar_frame_gold',
    'avatar_frame_neon',
    'profile_badge_vip',
  };
  static const Set<String> _repeatableItemIds = {'spin_wheel_extra'};

  // 2026-07-22 canlı UX denetimi: giriş ürünleri
  // 2026-07-23 M24: themeColor dağılımı playPink/playCyan/playPurple
  // (marka dışı) ağırlıklıydı — turuncu/altın/koyu-yeşil marka kimliğinden
  // uzaklaşıyordu. Yalnız themeColor alanları yeniden dağıtıldı; cost,
  // id, başlık ve ikonlara dokunulmadı. playPurple/playCyan'de kalan 3
  // ürün (emoji_ster, name_color_purple, frame_simple) bilinçli bırakıldı
  // çünkü açıklama metinleri o rengi ismen anıyor ("mor", "cyan").
  static const List<ShopItem> _items = [
    ShopItem(
      id: 'spin_wheel_extra',
      titleKu: 'Zivirîna Zêde',
      titleTr: 'Ekstra Çevirme',
      descKu: 'Ji bo çerxa rojane mafekî zivirînê yê nû dide.',
      descTr: 'Bugün çarkı tekrar çevirmek için ekstra hak verir.',
      cost: 200,
      icon: AppIcons.dice,
      themeColor: AppTheme.correct,
    ),
    ShopItem(
      id: 'avatar_frame_gold',
      titleKu: 'Çarçoveya Zêrîn',
      titleTr: 'Altın Çerçeve',
      descKu: 'Ji bo avatarê te çarçoveyeke zêrîn a taybet.',
      descTr: 'Avatarın için özel altın çerçeve.',
      cost: 750,
      icon: AppIcons.star,
      themeColor: AppTheme.gold,
    ),
    ShopItem(
      id: 'avatar_frame_neon',
      titleKu: 'Çarçoveya Neon',
      titleTr: 'Neon Çerçeve',
      descKu: 'Avatarê te bi rengên neon ên geş dibiriqe.',
      descTr: 'Avatarın neon renklerle parıldasın.',
      cost: 600,
      icon: AppIcons.wandMagicSparkles,
      themeColor: AppTheme.accent,
    ),
    ShopItem(
      id: 'profile_badge_vip',
      titleKu: 'Rozeta VIP',
      titleTr: 'VIP Rozeti',
      descKu: 'Profîla te de rozeteke taybet a VIP xuya dibe.',
      descTr: 'Profilinde özel VIP rozeti görünsün.',
      cost: 1000,
      icon: AppIcons.gem,
      themeColor: AppTheme.gold,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadError = false;
      _loadOffline = false;
      _dynamicItems = const [];
    });
    try {
      final balance = await widget.repository.loadCoinBalance();
      List<ShopItem> dynamicItems = _items
          .where((item) => _supportedItemIds.contains(item.id))
          .toList(growable: false);

      if (widget.repository is SupabaseZanKurdRepository) {
        try {
          final client =
              (widget.repository as SupabaseZanKurdRepository).client;
          final rows = await client.from('shop_items').select().order('cost');
          if (rows.isNotEmpty) {
            dynamicItems = rows
                .map((row) {
                  return ShopItem(
                    id: row['id'] as String,
                    titleKu: row['title_ku'] as String? ?? '',
                    titleTr: row['title_tr'] as String? ?? '',
                    descKu: row['desc_ku'] as String? ?? '',
                    descTr: row['desc_tr'] as String? ?? '',
                    cost: (row['cost'] as num?)?.toInt() ?? 100,
                    icon: shopIconForName(row['icon_name'] as String?),
                    themeColor: shopColorForHex(row['theme_color'] as String?),
                  );
                })
                .where((item) => _supportedItemIds.contains(item.id))
                .toList(growable: false);
          }
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'shop catalog load failed; using fallback',
          );
          // Fallback to static items if table is not configured or query fails
        }
      }

      final purchasedIds = <String>{};
      for (final item in dynamicItems) {
        if (_repeatableItemIds.contains(item.id)) continue;
        final purchased = await widget.repository.hasPurchased(item.id);
        if (purchased) {
          purchasedIds.add(item.id);
        }
      }

      if (mounted) {
        setState(() {
          _coinBalance = balance;
          _dynamicItems = dynamicItems;
          _purchasedItemIds.clear();
          _purchasedItemIds.addAll(purchasedIds);
          _loading = false;
          _loadError = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'shop balance load failed');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
          _loadOffline = isLikelyOfflineError(error);
        });
      }
    }
  }

  // ── Purchase confirmation dialog ──
  Future<void> _confirmPurchase(ShopItem item) async {
    final ku = context.isKu;
    final title = ku ? item.titleKu : item.titleTr;
    final desc = ku ? item.descKu : item.descTr;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: AppTheme.borderColor(ctx)),
          ),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.themeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  item.icon,
                  color: AppColors.onAccentTint(context, item.themeColor),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(ctx),
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                desc,
                style: TextStyle(
                  color: AppTheme.textSubColor(ctx),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.surfaceHi.withValues(alpha: 0.5)
                      : AppTheme.lightSurfaceHi,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppTheme.borderColor(ctx).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(AppIcons.coins, color: AppTheme.gold, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      // Para birimi adı defterden gelir: Kurmancî
                      // ekranda "zêr", Türkçede "coin". Sabit yazıldığında
                      // aynı ekranda iki ad birden görünüyordu — başlık
                      // "Zêrên xwe bi aqilmendî bixercîne" derken sayaç
                      // "0 coin" diyordu (2026-08-01, canlı Kurmancî
                      // mağaza ekranı).
                      '${item.cost} ${ctx.t(K.coinWord).toLowerCase()}',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(ctx),
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.wallet,
                    size: 16,
                    color: AppTheme.textMutedColor(ctx),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    context.t(K.yourBalance, {'coins': '$_coinBalance'}),
                    style: AppTypography.caption.copyWith(
                      color: (_coinBalance < item.cost)
                          ? AppTheme.wrong
                          : AppTheme.textSubColor(ctx),
                    ),
                  ),
                ],
              ),
              // Yetersiz bakiye: coin kazanma yoluna yönlendiren ikincil
              // eylem. Daha önce actions listesindeydi; üç eylem tek satıra
              // sığmayınca OverflowBar bunları merdiven gibi üç ayrı hizaya
              // dağıtıyordu (2026-07-22 canlı UX denetimi). İçeriğe alınınca
              // actions'ta iki eylem kalıyor ve düzgün hizalanıyor.
              if (_coinBalance < item.cost) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop(false);
                      Navigator.of(context).push(
                        AppRoute<void>(
                          page: SpinWheelScreen(repository: widget.repository),
                        ),
                      );
                    },
                    icon: const Icon(AppIcons.dice, size: 18),
                    label: Text(context.t(K.earnCoins)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                context.t(K.cancelShort),
                style: TextStyle(color: AppTheme.textMutedColor(ctx)),
              ),
            ),
            FilledButton(
              // Bakiye yetersizse 'Bikire' gri disabled kalır; kullanıcı
              // 'Coin qezenc bike' ile çarka yönlendirilir.
              onPressed: (_coinBalance < item.cost)
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryCtaColor(ctx),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(context.t(K.buyAction)),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      _purchase(item);
    }
  }

  Future<void> _purchase(ShopItem item) async {
    if (_coinBalance < item.cost) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(K.insufficientBalance)),
          backgroundColor: AppTheme.wrong,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    setState(() {
      _purchaseErrorMessage = null;
      _retryPurchaseItem = item;
      _purchaseOffline = false;
    });

    try {
      final success = await widget.repository.spendCoins(
        item.cost,
        'purchase_${item.id}',
      );

      if (!mounted) return;

      if (success) {
        _purchaseErrorMessage = null;
        await _applyPurchaseEffect(item.id);
        if (!mounted) return;
        HapticFeedback.lightImpact();
        try {
          context.read<SoundProvider>().playCorrect();
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'shop success sound failed',
          );
        }
        _showPurchaseCelebrationDialog(item);
      } else {
        HapticFeedback.vibrate();
        setState(() => _purchaseErrorMessage = context.t(K.purchaseFailed));
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'shop_purchase');
      if (!mounted) return;
      setState(() {
        _purchaseErrorMessage = context.t(K.errorOccurred);
        _purchaseOffline = isLikelyOfflineError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _loadBalance();
      }
    }
  }

  Future<void> _applyPurchaseEffect(String itemId) async {
    // Bu koruma `applyShopPurchaseEffect`in gerçekten bir şey yaptığı
    // ürünlerle senkron kalmalı — 'avatar_frame_neon' burada yoktu ve dal
    // hiç açılmıyordu, yani neon satın alan oyuncu için
    // `loadAvatarIdentity`/`updateAvatarIdentity` hiç çağrılmıyordu
    // (2026-08-14 denetimi).
    if (itemId != 'avatar_frame_gold' &&
        itemId != 'avatar_frame_neon' &&
        itemId != 'profile_badge_vip') {
      return;
    }
    try {
      final identity = await widget.repository.loadAvatarIdentity();
      await widget.repository.updateAvatarIdentity(
        applyShopPurchaseEffect(itemId, identity),
      );
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'shop purchase effect failed: $itemId',
      );
    }
  }

  void _showPurchaseCelebrationDialog(ShopItem item) {
    final ku = context.isKu;
    final title = ku ? item.titleKu : item.titleTr;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(dialogContext),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.gold, width: 2),
            boxShadow: AppTheme.elevatedShadow(AppTheme.gold),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RojMascot(mood: RojMood.celebrate, size: 72),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  color: AppColors.onAccentTint(context, AppTheme.gold),
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.t(K.congrats),
                style: AppTypography.heading2.copyWith(
                  color: AppColors.onAccentTint(context, AppTheme.gold),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.t(K.purchasedItem, {'item': title}),
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppTheme.textPrimaryColor(dialogContext),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.gold,
                    foregroundColor: AppTheme.lightTextPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    context.t(K.gotIt),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryColor(context)),

        actions: [
          // Günlük çarka giden TEK kalıcı yol. Öncesinde çarka erişim
          // yalnız bakiye TAM 0 iken görünen `_buildEarnCoinCta` ve
          // yetersiz-bakiye dialog'undaki "coin kazan" düğmesiyle sınırlıydı
          // — bakiyesi 0'dan farklı bir oyuncu çarkı bir daha hiç
          // bulamıyordu. Bu düğme bakiyeden bağımsız her zaman görünür
          // (2026-08-14 denetimi).
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              key: const ValueKey('shop-spin-wheel-entry'),
              icon: Icon(
                AppIcons.dice,
                color: AppTheme.textPrimaryColor(context),
              ),
              tooltip: context.t(K.wheelTitle),
              onPressed: () {
                Navigator.of(context).push(
                  AppRoute<void>(
                    page: SpinWheelScreen(repository: widget.repository),
                  ),
                );
              },
            ),
          ),
          // Dalga 5: devasa bakiye kartı yerine kompakt coin chip'i.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                key: const ValueKey('shop-coin-chip'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.38),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      spreadRadius: -8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.coins,
                      color: AppColors.onAccentTint(context, AppTheme.gold),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_coinBalance ${context.t(K.coinWord).toLowerCase()}',
                      maxLines: 1,
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: Column(
            children: [
              // ── Items ──
              Expanded(
                child: _loading && _dynamicItems.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGradientStart,
                        ),
                      )
                    : _loadError
                    ? _loadOffline
                          ? AppOfflineState(
                              title: context.t(K.shopOfflineTitle),
                              message: context.t(K.shopOfflineBody),
                              retryLabel: context.t(K.retryShort),
                              onRetry: _loadBalance,
                            )
                          : AppErrorState(
                              title: context.t(K.loadFailedShort),
                              message: context.t(K.genericErrorBody),
                              retryLabel: context.t(K.retryShort),
                              onRetry: _loadBalance,
                            )
                    : _purchaseErrorMessage != null
                    ? _purchaseOffline
                          ? AppOfflineState(
                              title: context.t(K.shopOfflineTitle),
                              message: context.t(K.shopOfflineBody),
                              retryLabel: context.t(K.retryShort),
                              onRetry: _retryPurchaseItem == null
                                  ? _loadBalance
                                  : () => _purchase(_retryPurchaseItem!),
                            )
                          : AppErrorState(
                              title: context.t(K.purchaseErrorTitle),
                              message: _purchaseErrorMessage!,
                              retryLabel: context.t(K.retryShort),
                              onRetry: _retryPurchaseItem == null
                                  ? _loadBalance
                                  : () => _purchase(_retryPurchaseItem!),
                            )
                    : _dynamicItems.isEmpty
                    ? AppEmptyState(
                        icon: AppIcons.bagShopping,
                        title: context.t(K.shopEmpty),
                        message: context.t(K.shopSubtitle),
                        actionLabel: context.t(K.retryShort),
                        onAction: _loadBalance,
                      )
                    : _buildItemsList(context, ku, isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Bakiye 0 iken üstte görünen coin kazanma mini-CTA'sı
  // ────────────────────────────────────────────
  Widget _buildEarnCoinCta(BuildContext context, bool ku) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          key: const ValueKey('shop-earn-coin-cta'),
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            Navigator.of(context).push(
              AppRoute<void>(
                page: SpinWheelScreen(repository: widget.repository),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.gold.withValues(alpha: 0.16),
                  AppTheme.gold.withValues(alpha: 0.07),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(AppIcons.dice, color: AppTheme.gold, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t(K.zeroBalanceHint),
                    maxLines: 2,
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                ),
                Icon(
                  AppIcons.chevronRight,
                  color: AppTheme.textMutedColor(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Items list: mockup-11 style "en popüler" hero + grid
  // ────────────────────────────────────────────
  Widget _buildItemsList(BuildContext context, bool ku, bool isDark) {
    if (_dynamicItems.isEmpty) {
      return Center(
        child: Text(
          context.t(K.shopEmpty),
          style: TextStyle(color: AppTheme.textMutedColor(context)),
        ),
      );
    }

    final heroItem = _dynamicItems.reduce((a, b) => b.cost > a.cost ? b : a);
    final restItems = _dynamicItems.where((i) => i.id != heroItem.id).toList();

    // Adaptive breakpoint for mobile, tablet, and desktop
    final width = MediaQuery.of(context).size.width;
    final int crossAxisCount;
    final double childAspectRatio;
    if (width >= 1024) {
      crossAxisCount = 4;
      childAspectRatio = 0.95;
    } else if (width >= 720) {
      crossAxisCount = 3;
      childAspectRatio = 0.90;
    } else if (width >= 360) {
      // Eşik 420pt idi; iPhone'ların neredeyse tamamı (SE 375, standart
      // 390, Pro 402) bunun altında kalıp tek sütuna düşüyordu ve ekranda
      // aynı anda ancak iki ürün görünüyordu (2026-07-25 canlı denetimi).
      // 360pt, modern iPhone'ların tamamını iki sütuna alır; kart genişliği
      // en dar cihazda bile ~166pt kalır.
      crossAxisCount = 2;
      childAspectRatio = 0.90;
    } else {
      crossAxisCount = 1;
      childAspectRatio = 1.95;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ScreenIdentityHeader(
          title: context.t(K.shop),
          subtitle: context.t(K.shopSubtitle),
          accent: AppTheme.gold,
          icon: AppIcons.bagShopping,
          compact: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Maskotlu karşılama şeridi kaldırıldı: AppBar başlığı, kimlik
        // kartı ve bu satır üst üste aynı şeyi söylüyordu ("Mağaza" /
        // "Coinlerini harca" / "Kazandığın coinlerle al") ve ilk ürün
        // ancak ekranın yarısından sonra başlıyordu (2026-07-25 canlı
        // denetimi). Karşılama görevini kimlik kartının alt başlığı taşır.
        if (!_loading && _coinBalance == 0) _buildEarnCoinCta(context, ku),
        _buildHeroCard(heroItem, ku, isDark),
        if (restItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Dar (2 sütun) ve geniş (3 sütun) ekranda kart genişliği çok
              // farklı; tek sabit oran genişte gereksiz boşluk, darda taşma
              // yaratıyordu. Sütun sayısına göre ayrı oran kullanılır.
              // Açıklamalar 2 satıra sığmayıp "…paletl…" diye kesiliyordu
              // (2026-07-22 canlı UX denetimi); maxLines 3'e çıkarıldı ve
              // kartlar buna göre biraz uzatıldı.
              childAspectRatio: childAspectRatio,
            ),
            itemCount: restItems.length,
            itemBuilder: (context, index) =>
                _buildShopCard(restItems[index], ku, isDark),
          ),
        ],
      ],
    );
  }

  // ── Hero: öne çıkan ürün — grid kartıyla aynı dilin 2 kat büyük hücresi ──
  Widget _buildHeroCard(ShopItem item, bool ku, bool isDark) {
    final title = ku ? item.titleKu : item.titleTr;
    final desc = ku ? item.descKu : item.descTr;
    final isPurchased = _purchasedItemIds.contains(item.id);
    final canAfford = _coinBalance >= item.cost;
    final tint = item.themeColor;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: (_loading || isPurchased) ? null : () => _confirmPurchase(item),
        borderRadius: BorderRadius.circular(AppRadius.card),
        splashColor: tint.withValues(alpha: 0.15),
        highlightColor: tint.withValues(alpha: 0.07),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.surfaceColor(context),
                tint.withValues(alpha: isPurchased ? 0.05 : 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: tint.withValues(alpha: isPurchased ? 0.18 : 0.28),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: isPurchased ? 0.04 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -8,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Stack(
              children: [
                Positioned(
                  right: -16,
                  top: -16,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          context.t(K.mostWanted),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Grid kartındaki ikon bloğunun büyük hâli.
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isPurchased
                                  ? [
                                      tint.withValues(alpha: 0.10),
                                      tint.withValues(alpha: 0.04),
                                    ]
                                  : [
                                      tint.withValues(alpha: 0.24),
                                      tint.withValues(alpha: 0.10),
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            boxShadow: [
                              BoxShadow(
                                color: tint.withValues(alpha: 0.14),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                                spreadRadius: -10,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            item.icon,
                            // Ürün ikonu kendi renginin tonundan yapılmış
                            // karonun içinde duruyor; ham renk orada
                            // altında 2.0:1'e kadar iniyordu — VIP elması
                            // altın karoda eriyip gidiyordu (2026-07-27).
                            color: isPurchased
                                ? tint.withValues(alpha: 0.5)
                                : AppColors.onAccentTint(context, tint),
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.clip,
                                style: TextStyle(
                                  color: isPurchased
                                      ? AppTheme.textMutedColor(context)
                                      : AppTheme.textPrimaryColor(context),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                desc,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.textMutedColor(context),
                                  fontSize: 12.5,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: isPurchased
                          ? _buildOwnedChip(ku)
                          : _buildBuyButton(item, ku, canAfford),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Single shop card
  // ────────────────────────────────────────────
  Widget _buildShopCard(ShopItem item, bool ku, bool isDark) {
    final title = ku ? item.titleKu : item.titleTr;
    final isPurchased = _purchasedItemIds.contains(item.id);
    final canAfford = _coinBalance >= item.cost;
    final tint = item.themeColor;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: (_loading || isPurchased) ? null : () => _confirmPurchase(item),
        borderRadius: BorderRadius.circular(AppRadius.card),
        splashColor: tint.withValues(alpha: 0.15),
        highlightColor: tint.withValues(alpha: 0.07),
        child: ClipRRect(
          // Pirs hizası: kart kenarlığı/gölgesi yok — kimlik yalnız ikon
          // renginde ve alttaki tam-genişlik renkli çizgide.
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            // 2026-07-24 canlı denetim: dokuz ürün kartı dokuz ayrı pastel
            // zemin taşıyordu (krem, lavanta, nane, şeftali…) — ızgara
            // birbiriyle yarışan renk lekelerine dönüşüyordu. Zemin tek tip
            // yüzey oldu; ürün kimliği yalnız ikon karosunda yaşar.
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Stack(
              children: [
                // Card content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icon area — sabit yükseklik yerine esnek: dar/kısa
                      // tile'larda (ör. 390dp genişlikte 2 sütun) taşma
                      // yaratmadan kalan alanı doldurur.
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: tint.withValues(
                              alpha: isPurchased ? 0.08 : 0.16,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            item.icon,
                            // Ürün ikonu kendi renginin tonundan yapılmış
                            // karonun içinde duruyor; ham renk orada
                            // altında 2.0:1'e kadar iniyordu — VIP elması
                            // altın karoda eriyip gidiyordu (2026-07-27).
                            color: isPurchased
                                ? tint.withValues(alpha: 0.5)
                                : AppColors.onAccentTint(context, tint),
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Title — uzun adlar kesilmesin: 2 satır, ellipsis yok.
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: isPurchased
                              ? AppTheme.textMutedColor(context)
                              : AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Price + Action
                      SizedBox(
                        height: 38,
                        child: isPurchased
                            ? _buildOwnedChip(ku)
                            : _buildBuyButton(item, ku, canAfford),
                      ),
                    ],
                  ),
                ),
                // Owned overlay indicator
                if (isPurchased)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.correct,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x44000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        AppIcons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Pirs imzası: tam-genişlik, kenardan kenara renkli çizgi.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 4,
                    color: tint.withValues(alpha: isPurchased ? 0.25 : 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── "Owned" chip ──
  Widget _buildOwnedChip(bool ku) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.correct.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppTheme.correct.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(AppIcons.check, size: 14, color: AppTheme.correct),
          const SizedBox(width: 4),
          Text(
            context.t(K.ownedLabel),
            style: TextStyle(
              color: AppColors.onAccentTint(context, AppTheme.correct),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Buy button ──
  Widget _buildBuyButton(ShopItem item, bool ku, bool canAfford) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _loading ? null : () => _confirmPurchase(item),
        style: FilledButton.styleFrom(
          backgroundColor: canAfford
              ? AppTheme.primaryCtaColor(context)
              : AppTheme.surfaceHiColor(context),
          disabledBackgroundColor: AppTheme.surfaceHiColor(context),
          // Yetersiz bakiyede fiyat "muted" griyle yazılıyordu: açık
          // yüzeyde 3,7:1 kontrast — yani **fiyat okunmuyordu**. Hiç coini
          // olmayan yeni kullanıcı mağazadaki bütün fiyatları bu hâlde
          // görür; ekran baştan sona soluk ve okunmaz duruyordu
          // (2026-07-27, canlı gezinti). Düğme yine pasif görünür ama
          // fiyat okunur (5,6:1).
          foregroundColor: canAfford
              ? Colors.white
              : AppTheme.textSubColor(context),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          // Aile açıkça yazılmalı: `styleFrom(textStyle:)` temadan gelen
          // biçimi birleştirmez, **değiştirir**. Ailesiz bir biçim verince
          // düğmenin yazısı sistem yazı tipine düşüyordu — fiyat etiketleri
          // uygulamanın geri kalanından başka bir tiple çiziliyordu
          // (2026-07-26).
          textStyle: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        icon: Icon(
          AppIcons.cartShopping,
          size: 15,
          color: canAfford ? Colors.white : AppTheme.textSubColor(context),
        ),
        // Görünen etiket kısa ("10c"), ekran okuyucuya söylenen ad tam
        // cümle. `ExcludeSemantics` tek başına kullanıldığında düğmenin
        // *tek* ad kaynağını gizliyor ve düğme adsız kalıyordu — okuyucu
        // yalnız "düğme" diyor, neyi satın alacağını söylemiyordu
        // (2026-07-26 ölçümü; bkz. `test/button_semantics_test.dart`).
        // Düğme alt ağacındaki anlamları birleştirdiği için buradaki
        // `Semantics` etiketi adı sağlar, `ExcludeSemantics` da görünen
        // metnin ikinci kez okunmasını önler.
        label: Semantics(
          label: context.t(K.buyItemForCoins, {
            'item': ku ? item.titleKu : item.titleTr,
            'coins': '${item.cost}',
          }),
          child: ExcludeSemantics(
            child: Text('${item.cost}${context.t(K.coinAbbrev)}'),
          ),
        ),
      ),
    );
  }
}
