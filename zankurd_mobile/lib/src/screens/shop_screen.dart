import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/zankurd_repository.dart';
import '../data/supabase_zankurd_repository.dart';
import '../l10n/lang.dart';
import '../providers/sound_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';

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

  static const List<ShopItem> _items = [
    ShopItem(
      id: 'joker_bundle',
      titleKu: 'Paketa Jokeran',
      titleTr: 'Joker Paketi',
      descKu: 'Hemû jokaran ji bo pêşbirka bê nû dike.',
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
      titleKu: 'Zivirîna Zêde ya Çerxê',
      titleTr: 'Ekstra Çark Çevirme',
      descKu: 'Ji bo çerxa rojane mafekî zivirînê yê nû dide.',
      descTr: 'Bugün çarkı tekrar çevirebilmek için ekstra bir hak tanımlar.',
      cost: 200,
      icon: Icons.casino_outlined,
      themeColor: Color(0xFF2B5C8F),
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
  ];

  static IconData _getIconData(String? name) => switch (name) {
    'auto_awesome_motion_outlined' => Icons.auto_awesome_motion_outlined,
    'favorite_border_rounded' => Icons.favorite_border_rounded,
    'casino_outlined' => Icons.casino_outlined,
    'palette_outlined' => Icons.palette_outlined,
    _ => Icons.shopping_bag_outlined,
  };

  static Color _getColor(String? hex) {
    if (hex == null) return AppTheme.accent;
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return AppTheme.accent;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await widget.repository.loadCoinBalance();
      List<ShopItem> dynamicItems = _items;

      if (widget.repository is SupabaseZanKurdRepository) {
        try {
          final client =
              (widget.repository as SupabaseZanKurdRepository).client;
          final rows = await client.from('shop_items').select().order('cost');
          if (rows.isNotEmpty) {
            dynamicItems = rows.map((row) {
              return ShopItem(
                id: row['id'] as String,
                titleKu: row['title_ku'] as String? ?? '',
                titleTr: row['title_tr'] as String? ?? '',
                descKu: row['desc_ku'] as String? ?? '',
                descTr: row['desc_tr'] as String? ?? '',
                cost: (row['cost'] as num?)?.toInt() ?? 100,
                icon: _getIconData(row['icon_name'] as String?),
                themeColor: _getColor(row['theme_color'] as String?),
              );
            }).toList();
          }
        } catch (_) {
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
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
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
        HapticFeedback.lightImpact();
        // Ses çalınamazsa satın alma başarı mesajı engellenmesin
        // (çark ekranındaki desenle aynı).
        try {
          context.read<SoundProvider>().playCorrect();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ku
                  ? 'Te ${ku ? item.titleKu : item.titleTr} bi serkeftî kirî!'
                  : '${ku ? item.titleKu : item.titleTr} başarıyla satın alındı!',
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ku ? 'Çewtiyek çêbû.' : 'Bir hata oluştu.')),
      );
    } finally {
      _loadBalance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

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
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Balance Panel
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppPanel(
                  gradient: AppTheme.goldGradient,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ku ? 'Bakiyeya Te' : 'Mevcut Bakiyen',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ku ? '$_coinBalance coin' : '$_coinBalance coin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.monetization_on,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Items List
              Expanded(
                child: _loading && _coinBalance == 0
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryGradientStart,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _dynamicItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _dynamicItems[index];
                          final title = ku ? item.titleKu : item.titleTr;
                          final desc = ku ? item.descKu : item.descTr;
                          final isPurchased = _purchasedItemIds.contains(
                            item.id,
                          );
                          final canAfford = _coinBalance >= item.cost;

                          // Her ürün kendi renk kimliğini taşır: hafif
                          // zemin tonu + renkli kenarlık/parıltı.
                          final tint = item.themeColor;
                          final surface = AppTheme.surfaceHiColor(context);
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.alphaBlend(
                                    tint.withValues(alpha: 0.14),
                                    surface,
                                  ),
                                  Color.alphaBlend(
                                    tint.withValues(alpha: 0.04),
                                    surface,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: tint.withValues(
                                  alpha: isPurchased ? 0.18 : 0.30,
                                ),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: tint.withValues(alpha: 0.10),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            item.themeColor.withValues(
                                              alpha: 0.28,
                                            ),
                                            item.themeColor.withValues(
                                              alpha: 0.1,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                        border: Border.all(
                                          color: item.themeColor.withValues(
                                            alpha: 0.4,
                                          ),
                                        ),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        color: item.themeColor,
                                        size: 26,
                                      ),
                                    ),
                                    if (isPurchased)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.correct,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color:
                                                    AppTheme.textPrimaryColor(
                                                      context,
                                                    ),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          if (isPurchased) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.correct
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      AppRadius.xs,
                                                    ),
                                              ),
                                              child: Text(
                                                ku ? 'Yê te' : 'Sende',
                                                style: const TextStyle(
                                                  color: AppTheme.correct,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        desc,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.textMutedColor(
                                            context,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 76,
                                    minHeight: 46,
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPurchased
                                          ? AppTheme.correct.withValues(
                                              alpha: 0.18,
                                            )
                                          : (canAfford
                                                ? AppTheme.primaryGradientStart
                                                : AppTheme.surfaceHiColor(
                                                    context,
                                                  )),
                                      foregroundColor: isPurchased
                                          ? AppTheme.correct
                                          : (canAfford
                                                ? Colors.white
                                                : AppTheme.textMutedColor(
                                                    context,
                                                  )),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.sm,
                                        ),
                                      ),
                                    ),
                                    onPressed: (_loading || isPurchased)
                                        ? null
                                        : () => _purchase(item),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPurchased) ...[
                                          const Icon(Icons.check, size: 14),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              ku ? 'Kirî' : 'Alındı',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          if (canAfford)
                                            const Icon(
                                              Icons.shopping_cart_outlined,
                                              size: 14,
                                            ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${item.cost}c',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
