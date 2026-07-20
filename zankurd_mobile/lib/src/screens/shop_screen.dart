import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/zankurd_repository.dart';
import '../data/supabase_zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/avatar_identity.dart';
import '../providers/sound_provider.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import 'spin_wheel_screen.dart';

/// `shop_items` tablosundaki `icon_name` sütununu [IconData]'ya çevirir.
/// Statik yedek listedeki (`ShopItem._items`) her ikon burada da
/// tanımlı olmalı — aksi halde canlı katalog jenerik çanta ikonuna düşer.
///
/// Map tabanlı arama kasıtlı: bir switch-expression'la yazıldığında web
/// derlemesinde (dart2js) yalnızca ilk birkaç dal doğru eşleşiyor, sonraki
/// dallar sessizce varsayılana düşüyordu (VM'de çalışan `flutter test` bunu
/// yakalamadı — bu yüzden canlıda fark edildi).
const Map<String, IconData> _shopIcons = {
  'auto_awesome_motion_outlined': Icons.auto_awesome_motion_outlined,
  'favorite_border_rounded': Icons.favorite_border_rounded,
  'casino_outlined': Icons.casino_outlined,
  'palette_outlined': Icons.palette_outlined,
  'star_rounded': Icons.star_rounded,
  'auto_awesome_rounded': Icons.auto_awesome_rounded,
  'text_fields_rounded': Icons.text_fields_rounded,
  'text_format_rounded': Icons.text_format_rounded,
  'auto_fix_high_rounded': Icons.auto_fix_high_rounded,
  'diamond_rounded': Icons.diamond_rounded,
};

IconData shopIconForName(String? name) =>
    _shopIcons[name] ?? Icons.shopping_bag_outlined;

AvatarIdentity applyShopPurchaseEffect(String itemId, AvatarIdentity identity) {
  if (itemId == 'avatar_frame_gold') {
    return identity.copyWith(frameId: 'gold');
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

class ShopScreen extends StatefulWidget {
  const ShopScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _coinBalance = 0;
  bool _loading = true;
  final Set<String> _purchasedItemIds = {};
  List<ShopItem> _dynamicItems = _items;

  static const _supportedItemIds = {
    'spin_wheel_extra',
    'avatar_frame_gold',
    'profile_badge_vip',
  };

  static const List<ShopItem> _items = [
    ShopItem(
      id: 'joker_bundle',
      titleKu: 'Paketa Jokeran',
      titleTr: 'Joker Paketi',
      descKu: 'Hemû joker ji bo pêşbirka bê têne nûkirin.',
      descTr: 'Bir sonraki yarışma için tüm joker haklarını sıfırlar.',
      cost: 500,
      icon: Icons.auto_awesome_motion_outlined,
      themeColor: AppTheme.accent,
    ),
    ShopItem(
      id: 'extra_lifeline',
      titleKu: 'Cana Zêde',
      titleTr: 'Ekstra Can',
      descKu: 'Di dema quizê de canekî din dide te.',
      descTr: 'Yarışma esnasında elendiğinde kullanabileceğin 1 can verir.',
      cost: 100,
      icon: Icons.favorite_border_rounded,
      themeColor: AppTheme.accent,
    ),
    ShopItem(
      id: 'spin_wheel_extra',
      titleKu: 'Zivirîna Zêde',
      titleTr: 'Ekstra Çevirme',
      descKu: 'Ji bo çerxa rojane mafekî zivirînê yê nû dide.',
      descTr: 'Bugün çarkı tekrar çevirebilmek için ekstra bir hak tanımlar.',
      cost: 200,
      icon: Icons.casino_outlined,
      themeColor: AppTheme.correct,
    ),
    ShopItem(
      id: 'premium_colors',
      titleKu: 'Rengên Taybet',
      titleTr: 'Premium Renkler',
      descKu: 'Ji bo profilê rengên nû û taybet vedike.',
      descTr: 'Profil kartı ve avatarı için özel premium renk paletleri açar.',
      cost: 300,
      icon: Icons.palette_outlined,
      themeColor: AppTheme.gold,
    ),
    ShopItem(
      id: 'avatar_frame_gold',
      titleKu: 'Çarçoveya Zêrîn',
      titleTr: 'Altın Çerçeve',
      descKu: 'Ji bo avatarê te çarçoveyeke zêrîn a taybet.',
      descTr: 'Avatarın için özel altın çerçeve.',
      cost: 750,
      icon: Icons.star_rounded,
      themeColor: AppTheme.gold,
    ),
    ShopItem(
      id: 'avatar_frame_neon',
      titleKu: 'Çarçoveya Neon',
      titleTr: 'Neon Çerçeve',
      descKu: 'Avatarê te bi rengên neon ên geş dibiriqe.',
      descTr: 'Avatarın neon renklerle parıldasın.',
      cost: 600,
      icon: Icons.auto_awesome_rounded,
      themeColor: AppTheme.playCyan,
    ),
    ShopItem(
      id: 'name_color_gold',
      titleKu: 'Navê Zêrîn',
      titleTr: 'Altın İsim',
      descKu: 'Navê te di profîl û rêzbendiyê de bi rengê zêrîn xuya dibe.',
      descTr: 'İsmin profil ve liderlik tablosunda altın renginde görünsün.',
      cost: 500,
      icon: Icons.text_fields_rounded,
      themeColor: AppTheme.gold,
    ),
    ShopItem(
      id: 'name_color_purple',
      titleKu: 'Navê Mor',
      titleTr: 'Mor İsim',
      descKu: 'Navê te bi rengekî mor ê taybet were xuyakirin.',
      descTr: 'İsmin özel mor renkte görünsün.',
      cost: 400,
      icon: Icons.text_format_rounded,
      themeColor: AppTheme.playPurple,
    ),
    ShopItem(
      id: 'joker_pack_3',
      titleKu: 'Pakêta Jokeran (3)',
      titleTr: 'Joker Paketi (3)',
      descKu:
          'Ji bo pêşbirka bê 3 jokerên zêde: 50/50, temaşevan û bersiva ducar.',
      descTr:
          'Bir sonraki yarışma için 3 ekstra joker: 50/50, seyirci ve çift cevap.',
      cost: 350,
      icon: Icons.auto_fix_high_rounded,
      themeColor: AppTheme.playPink,
    ),
    ShopItem(
      id: 'profile_badge_vip',
      titleKu: 'Rozeta VIP',
      titleTr: 'VIP Rozeti',
      descKu: 'Profîla te de rozeteke taybet a VIP xuya dibe.',
      descTr: 'Profilinde özel VIP rozeti görünsün.',
      cost: 1000,
      icon: Icons.diamond_rounded,
      themeColor: AppTheme.playCyan,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await widget.repository.loadCoinBalance();
      List<ShopItem> dynamicItems = _items
          .where((item) => _supportedItemIds.contains(item.id))
          .toList();

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
                .toList();
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
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'shop balance load failed');
      if (mounted) {
        setState(() => _loading = false);
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
                child: Icon(item.icon, color: item.themeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(ctx),
                    fontWeight: FontWeight.w800,
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
                    const Icon(
                      Icons.monetization_on,
                      color: AppTheme.gold,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.cost} coin',
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
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: AppTheme.textMutedColor(ctx),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    ku
                        ? 'Bakiyeya te: $_coinBalance coin'
                        : 'Bakiyen: $_coinBalance coin',
                    style: TextStyle(
                      color: _coinBalance < item.cost
                          ? AppTheme.wrong
                          : AppTheme.textSubColor(ctx),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (_coinBalance < item.cost)
              // Yetersiz bakiye: coin kazanma yoluna yönlendiren ikincil buton.
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop(false);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SpinWheelScreen(repository: widget.repository),
                    ),
                  );
                },
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: Text(ku ? 'Coin qezenc bike' : 'Coin kazan'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                ku ? 'Betal' : 'İptal',
                style: TextStyle(color: AppTheme.textMutedColor(ctx)),
              ),
            ),
            FilledButton(
              // Bakiye yetersizse 'Bikire' gri disabled kalır; kullanıcı
              // 'Coin qezenc bike' ile çarka yönlendirilir.
              onPressed: _coinBalance < item.cost
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(ku ? 'Bikire' : 'Satın Al'),
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
    final ku = context.isKu;
    if (_coinBalance < item.cost) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ku ? 'Bakiyeya te kêm e!' : 'Bakiye yetersiz!'),
          backgroundColor: AppTheme.wrong,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final success = await widget.repository.spendCoins(
        item.cost,
        'purchase_${item.id}',
      );

      if (!mounted) return;

      if (success) {
        await _applyPurchaseEffect(item.id);
        if (!mounted) return;
        HapticFeedback.lightImpact();
        // Ses çalınamazsa satın alma başarı mesajı engellenmesin
        // (çark ekranındaki desenle aynı).
        try {
          context.read<SoundProvider>().playCorrect();
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'shop success sound failed',
          );
        }
        final title = ku ? item.titleKu : item.titleTr;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ku
                  ? 'Te $title bi serkeftî kirî!'
                  : '$title başarıyla satın alındı!',
            ),
            backgroundColor: AppTheme.correct,
          ),
        );
      } else {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ku ? 'Kirîn bi ser neket.' : 'Satın alma başarısız oldu.',
            ),
            backgroundColor: AppTheme.wrong,
          ),
        );
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'shop_purchase');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ku ? 'Çewtiyek çêbû.' : 'Bir hata oluştu.')),
      );
    } finally {
      _loadBalance();
    }
  }

  Future<void> _applyPurchaseEffect(String itemId) async {
    if (itemId != 'avatar_frame_gold' && itemId != 'profile_badge_vip') {
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
        title: Text(
          ku ? 'Dukan' : 'Mağaza',
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
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
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on,
                      color: AppTheme.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_coinBalance coin',
                      maxLines: 1,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
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
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
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
              MaterialPageRoute<void>(
                builder: (_) => SpinWheelScreen(repository: widget.repository),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.casino_outlined,
                  color: AppTheme.gold,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ku
                        ? 'Bakiyeya te 0 e — çerxa rojane bizivire û coin qezenc bike!'
                        : 'Bakiyen 0 — günlük çarkı çevir, coin kazan!',
                    maxLines: 2,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
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
          ku ? 'Hîn tiştek di dukanê de tune.' : 'Mağazada henüz ürün yok.',
          style: TextStyle(color: AppTheme.textMutedColor(context)),
        ),
      );
    }

    final heroItem = _dynamicItems.reduce((a, b) => b.cost > a.cost ? b : a);
    final restItems = _dynamicItems.where((i) => i.id != heroItem.id).toList();

    // Use 2 columns; on wide screens (>600dp) use 3.
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 600 ? 3 : 2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
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
              // Dar ekranda (390x844) ürün kartı içeriği taşıyordu; kartlara
              // dikey nefes payı verildi (0.72 -> 0.66).
              childAspectRatio: 0.66,
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
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: tint.withValues(alpha: isPurchased ? 0.18 : 0.28),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: isPurchased ? 0.04 : 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            color: isPurchased
                ? AppTheme.surfaceColor(context).withValues(alpha: 0.7)
                : AppTheme.surfaceColor(context),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
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
                      color: AppTheme.brandGreen,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      ku ? 'YA HERÎ TÊ XWASTIN' : 'EN POPÜLER',
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
                                  tint.withValues(alpha: 0.22),
                                  tint.withValues(alpha: 0.08),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        item.icon,
                        color: isPurchased ? tint.withValues(alpha: 0.5) : tint,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textMutedColor(context),
                              fontSize: 13,
                              height: 1.3,
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
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: tint.withValues(alpha: isPurchased ? 0.18 : 0.28),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(alpha: isPurchased ? 0.04 : 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            color: isPurchased
                ? AppTheme.surfaceColor(context).withValues(alpha: 0.7)
                : AppTheme.surfaceColor(context),
          ),
          child: Stack(
            children: [
              // Card content
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon area
                    Container(
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
                                  tint.withValues(alpha: 0.22),
                                  tint.withValues(alpha: 0.08),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        item.icon,
                        color: isPurchased ? tint.withValues(alpha: 0.5) : tint,
                        size: 32,
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
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Description
                    Expanded(
                      child: Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPurchased
                              ? AppTheme.textMutedColor(
                                  context,
                                ).withValues(alpha: 0.7)
                              : AppTheme.textMutedColor(context),
                          fontSize: 11,
                          height: 1.35,
                        ),
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
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
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
          const Icon(Icons.check_rounded, size: 14, color: AppTheme.correct),
          const SizedBox(width: 4),
          Text(
            ku ? 'Yê te' : 'Sende',
            style: const TextStyle(
              color: AppTheme.correct,
              fontSize: 12,
              fontWeight: FontWeight.w800,
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
              ? AppTheme.accent
              : AppTheme.surfaceHiColor(context),
          disabledBackgroundColor: AppTheme.surfaceHiColor(context),
          foregroundColor: canAfford
              ? Colors.white
              : AppTheme.textMutedColor(context),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          elevation: canAfford ? 2 : 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        icon: Icon(
          Icons.shopping_cart_outlined,
          size: 15,
          color: canAfford ? Colors.white : AppTheme.textMutedColor(context),
        ),
        label: Text('${item.cost}c'),
      ),
    );
  }
}
