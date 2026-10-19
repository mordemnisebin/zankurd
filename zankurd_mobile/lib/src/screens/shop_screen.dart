import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/durable_write.dart';
import '../data/local_progress_scope.dart';
import '../data/sync_manager.dart';
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
import '../widgets/branded_loader.dart';
import '../widgets/player_avatar.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';
import 'spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../widgets/dialog_action_pair.dart';
import '../utils/number_format.dart';

/// `shop_items` tablosundaki `icon_name` sütununu [IconData]'ya çevirir.
/// Statik yedek listedeki (`ShopItem.catalog`) her ikon burada da
/// tanımlı olmalı — aksi halde canlı katalog jenerik çanta ikonuna düşer.
///
/// Map tabanlı arama kasıtlı: bir switch-expression'la yazıldığında web
/// derlemesinde (dart2js) yalnızca ilk birkaç dal doğru eşleşiyor, sonraki
/// dallar sessizce varsayılana düşüyordu (VM'de çalışan `flutter test` bunu
/// yakalamadı — bu yüzden canlıda fark edildi).
const Map<String, IconData> _shopIcons = {
  'auto_awesome_motion_outlined': AppIcons.wandMagicSparkles,
  'favorite_border_rounded': AppIcons.heart,
  'casino_outlined': AppIcons.ferrisWheel,
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

/// Kullanıcıya göre ayrılır: A'nın bekleyen çerçeve/rozet etkisi aynı
/// cihazdaki B'ye uygulanmasın.
String get _pendingEffectsKey =>
    LocalProgressScope.physical('shop_pending_purchase_effects');

bool _hasPurchaseEffect(String itemId) =>
    itemId == 'avatar_frame_gold' ||
    itemId == 'avatar_frame_neon' ||
    itemId == 'profile_badge_vip';

/// Sunucuya henüz ulaşmamış (kuyruğa alınmış) satın almaların kimlikleri. Kuyruk sonradan boşalınca etki mağaza
/// açılışında uygulanır; kayıt yoksa oyuncu parasını verip çerçevesini
/// hiç göremezdi.
Future<Set<String>> _readPendingEffects() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_pendingEffectsKey) ?? const []).toSet();
  } catch (_) {
    return <String>{};
  }
}

Future<void> _writePendingEffects(Set<String> ids) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pendingEffectsKey, ids.toList()..sort());
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: 'shop pending effects write');
  }
}

Future<void> _markEffectPending(String itemId) async {
  if (!_hasPurchaseEffect(itemId)) return;
  final ids = await _readPendingEffects();
  if (ids.add(itemId)) await _writePendingEffects(ids);
}

/// `shop_items` tablosundaki `theme_color` (ör. "FF3B81") sütununu
/// [Color]'a çevirir.
/// Uzunluk denetimi `try/catch`ten ÖNCE gelir ve şart.
///
/// `int.parse('FF' + clean, radix: 16)` eksik bir hex için hata ATMAZ,
/// sessizce yanlış bir sayı üretir: boş dize `0xFF` yani
/// `Color(0x000000FF)` verir — alfası sıfır, tamamen saydam. Üç haneli
/// `FFF` de `0x000FFFFF` verir, yine saydam. Yani `catch` bloğu bu
/// durumların hiçbirinde çalışmıyordu ve uzak katalogdaki kısa ya da boş
/// bir `theme_color`, vitrinde görünmez bir karo tonu üretiyordu.
///
/// Mevcut test bunu göremiyordu: yalnız `isNotNull` denetliyordu ve saydam
/// bir renk de null değildir (2026-08-12 denetimi).
Color shopColorForHex(String? hex) {
  if (hex == null) return AppTheme.accent;
  final cleanHex = hex.replaceAll('#', '').trim();
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(cleanHex)) return AppTheme.accent;
  try {
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

  // 2026-07-22 canlı UX denetimi: giriş ürünleri
  // 2026-07-23 M24: themeColor dağılımı playPink/playCyan/playPurple
  // (marka dışı) ağırlıklıydı — turuncu/altın/koyu-yeşil marka kimliğinden
  // uzaklaşıyordu. Yalnız themeColor alanları yeniden dağıtıldı; cost,
  // id, başlık ve ikonlara dokunulmadı. playPurple/playCyan'de kalan 3
  // ürün (emoji_ster, name_color_purple, frame_simple) bilinçli bırakıldı
  // çünkü açıklama metinleri o rengi ismen anıyor ("mor", "cyan").
  // ── Fiyat çıpası (2026-08-10) ────────────────────────────────────────
  //
  // Fiyatlar ÖLÇÜLEN gelire göre belirlendi, sezgiye göre değil.
  //
  // Çevrimdışı oynayan bir oyuncunun TEK jeton kaynağı günlük çarktır.
  // Solo tur sıfır jeton verir ve bu bir eksiklik değil: `claim_quiz_reward`
  // RPC'si `p_room_id is null` olduğunda `verification_required` dönüyor —
  // sunucu doğrulayamadığı bir turu ödüllendirmiyor. Oda/1v1 turları ödül
  // veriyor ama rakip ve bağlantı istiyor.
  //
  // Çark: [10, 25, 50, 15, 75, 20, 100, 30] → günde ortalama 40,6 jeton.
  //
  // Eski fiyatlarla ilk satın alma 4,9 gün, katalogun tamamı 24,6 gün
  // sürüyordu; yeni oyuncu mağazaya girip hiçbir şey alamıyor ve yakın bir
  // hedef de göremiyordu (2026-08-10 simülatör gezisi).
  //
  // İki kısıt var:
  //
  //   1. `spin_wheel_extra` çarkın kendisini veriyor. Fiyatı çarkın AZAMİ
  //      ödülünün (100) altına inerse döngü kâr eder ve sınırsız jeton
  //      pompasına döner. 120 seçildi: her satın alma her sonuçta net
  //      zarardır, yani kolaylık olarak kalır, arbitraj olmaz.
  //   2. Jeton satan bir IAP YOK. Fiyatların gelire etkisi sıfır; yalnız
  //      kozmetik döngünün temposunu belirliyorlar. Bu yüzden indirim bir
  //      gelir kaybı değil, erişilebilirlik kazancıdır.
  //
  // Yeni tempo: ilk satın alma 3,0 gün; katalog 17,7 gün.
  //
  // 2026-09-29 doğallık: ürün adları cümle düzeninde ("Altın çerçeve",
  // "Altın Çerçeve" değil). Her sözcüğü büyük harfle başlatmak Türkçe ve
  // Kurmancîde doğal değil; İngilizce arayüz kalıbıydı. DİKKAT: uzak
  // `shop_items` tablosunun `title_ku/title_tr` sütunları hâlâ eski
  // yazımı taşıyor (`supabase/2026-07-23_shop_items_sync.sql`); canlı
  // katalog okunduğunda o adlar görünür — veri göçü ayrıca gerekir.
  static const List<ShopItem> catalog = [
    ShopItem(
      id: 'spin_wheel_extra',
      titleKu: 'Zivirîna zêde',
      titleTr: 'Ekstra çevirme',
      descKu: 'Ji bo çerxa rojane mafekî zivirînê yê nû dide.',
      descTr: 'Bugün çarkı tekrar çevirmek için ekstra hak verir.',
      cost: 120,
      icon: AppIcons.ferrisWheel,
      themeColor: AppTheme.correct,
    ),
    ShopItem(
      id: 'avatar_frame_gold',
      titleKu: 'Çarçoveya zêrîn',
      titleTr: 'Altın çerçeve',
      descKu: 'Ji bo avatarê te çarçoveyeke zêrîn a taybet.',
      descTr: 'Avatarın için özel altın çerçeve.',
      cost: 480,
      icon: AppIcons.star,
      themeColor: AppTheme.gold,
    ),
    ShopItem(
      id: 'avatar_frame_neon',
      titleKu: 'Çarçoveya neon',
      titleTr: 'Neon çerçeve',
      descKu: 'Avatarê te bi rengên neon ên geş dibiriqe.',
      descTr: 'Avatarın neon renklerle parıldasın.',
      cost: 350,
      icon: AppIcons.wandMagicSparkles,
      themeColor: AppTheme.accent,
    ),
    ShopItem(
      id: 'profile_badge_vip',
      titleKu: 'Rozeta VIP',
      titleTr: 'VIP rozeti',
      descKu: 'Profîla te de rozeteke taybet a VIP xuya dibe.',
      descTr: 'Profilinde özel VIP rozeti görünsün.',
      cost: 720,
      icon: AppIcons.gem,
      themeColor: AppTheme.gold,
    ),
  ];
}

/// Test-only erişim: mağaza kataloğunun statik yedek listesi.
///
/// Yalnız etkisi gerçekten uygulanmış yayın ürünlerini döndürür.
@visibleForTesting
List<ShopItem> get debugShopItems => ShopItem.catalog
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
  ShopItem? _retryPurchaseEffectItem;
  final Set<String> _purchasedItemIds = {};
  List<ShopItem> _dynamicItems = const [];

  /// Çerçeve ürünlerinin önizlemesi için oyuncunun kendi avatarı ve adı.
  /// Yüklenemezse `null` kalır ve karo ürün ikonuna düşer; mağaza bu
  /// yüzden hata durumuna geçmez.
  AvatarIdentity? _avatar;
  String? _profileName;

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

  static bool _isFrameItem(String id) => id.startsWith('avatar_frame_');

  /// Ürün önizleme karosu. Çerçeve ürünlerinde karoda boş bir yıldız ya da
  /// sihirli değnek değil, oyuncunun KENDİ avatarı o çerçeveyle durur:
  /// satın alınan şeyin neye benzeyeceğini gösterir (2026-09-29 doğallık,
  /// GORSEL_KARARLAR K10). Avatar yüklenemediyse ürün ikonuna düşer.
  Widget _preview(ShopItem item, {required double size, bool dim = false}) {
    final avatar = _avatar;
    if (avatar == null || !_isFrameItem(item.id)) {
      return _PreviewTile(icon: item.icon, size: size, dim: dim);
    }
    final framed = applyShopPurchaseEffect(item.id, avatar);
    return _PreviewTile(
      icon: item.icon,
      size: size,
      dim: dim,
      child: PlayerAvatar(
        radius: (size * 0.34).roundToDouble(),
        photoUrl: framed.photoUrl,
        iconId: framed.iconId,
        colorHex: framed.colorHex,
        frameId: framed.frameId,
        displayName: _profileName,
      ),
    );
  }

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
      List<ShopItem> dynamicItems = ShopItem.catalog
          .where((item) => _supportedItemIds.contains(item.id))
          .toList(growable: false);

      if (widget.repository is SupabaseZanKurdRepository) {
        try {
          final client =
              (widget.repository as SupabaseZanKurdRepository).client;
          final rows = await client
              // Tablo adı `shop_items`.
              //
              // Burada bir zamanlar `shopShopItem.catalog` yazıyordu: bir
              // toplu isim değiştirmenin `shop_items` dizesini de yakalayıp
              // bozduğu bir kalıntı. PostgREST böyle bir tabloyu hiçbir
              // zaman bulamadı, sorgu her açılışta hata verdi ve ekran
              // sessizce statik yedek listeye düştü. Yani "uzaktan
              // güncellenebilir katalog" özelliği hiç çalışmadı ve bunu
              // yalnız hata günlüğü biliyordu (2026-08-12 denetimi).
              //
              // DİKKAT: bu düzeltme, uzak tablonun fiyatlarını yeniden
              // devreye sokar. `shop_items` üretimde 2026-07-13 tohumundaki
              // ESKİ fiyatları taşıyor; `2026-08-12_shop_price_anchor.sql`
              // uygulanmadan bu sürüm yayınlanırsa fiyat çıpası
              // (`ShopItem.catalog`) sessizce eskiye döner.
              .from('shop_items')
              .select()
              .order('cost');
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
      await _applyPendingEffects(purchasedIds);

      AvatarIdentity? avatar;
      String? profileName;
      if (dynamicItems.any((item) => _isFrameItem(item.id))) {
        try {
          avatar = await widget.repository.loadAvatarIdentity();
          profileName = await widget.repository.getProfileName();
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'shop frame preview avatar load failed',
          );
        }
      }

      if (mounted) {
        setState(() {
          _avatar = avatar;
          _profileName = profileName;
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

  /// Kuyruğa alınan ya da etkisi yarım kalan satın almaların etkisini,
  /// sunucu satın almayı onayladığında (hasPurchased) uygular. Yalnız
  /// işaretli ürünler uygulanır: oyuncunun sonradan seçtiği çerçeve her
  /// açılışta ezilmez.
  Future<void> _applyPendingEffects(Set<String> purchasedIds) async {
    final pending = await _readPendingEffects();
    if (pending.isEmpty) return;
    var changed = false;
    for (final itemId in pending.toList()) {
      if (!purchasedIds.contains(itemId)) continue;
      if (await _applyPurchaseEffect(itemId)) {
        pending.remove(itemId);
        changed = true;
      }
    }
    if (changed) await _writePendingEffects(pending);
  }

  Future<void> _openSpinWheel() async {
    await Navigator.of(context).push(
      AppRoute<void>(page: SpinWheelScreen(repository: widget.repository)),
    );
    if (!mounted) return;
    await _refreshCoinBalance();
  }

  Future<void> _refreshCoinBalance() async {
    try {
      final balance = await widget.repository.loadCoinBalance();
      if (!mounted) return;
      setState(() => _coinBalance = balance);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'shop balance refresh failed');
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
        final t = SahneTokens.of(ctx);
        final short = _coinBalance < item.cost;
        return AlertDialog(
          // Dar telefonda büyük yazıyla eksik-bakiye notu pencereyi 32 px
          // taşırıyordu; kaydırılabilir pencerede düğmeler hep görünür.
          scrollable: true,
          title: Row(
            children: [
              _preview(item, size: 44),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Text(
                  title,
                  style: SahneType.headline.copyWith(color: t.tx),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(desc, style: SahneType.body.copyWith(color: t.tx2)),
              const SizedBox(height: SahneSpace.x4),
              DecoratedBox(
                decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
                child: Padding(
                  padding: const EdgeInsets.all(SahneSpace.x3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SahneGlyph(SahneGlyphKind.coin),
                      const SizedBox(width: SahneSpace.x2),
                      Flexible(
                        child: Text(
                          // Para birimi adı defterden gelir: Kurmancî
                          // ekranda "zêr", Türkçede "coin". Sabit yazıldığında
                          // aynı ekranda iki ad birden görünüyordu — başlık
                          // "Zêrên xwe bi aqilmendî bixercîne" derken sayaç
                          // "0 coin" diyordu (2026-08-01, canlı Kurmancî
                          // mağaza ekranı).
                          '${item.cost} ${ctx.t(K.coinWord).toLowerCase()}',
                          style: SahneType.bodyStrong.copyWith(
                            color: t.tx,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Yetersiz bakiye bir durumdur: Şaş metni + ikon + söz; yalnız
              // renkle verilmez. Eksik miktar yazılır; bakiye satırı hep
              // görünür.
              const SizedBox(height: SahneSpace.x3),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.wallet, size: 16, color: t.tx2),
                  const SizedBox(width: SahneSpace.x2),
                  Flexible(
                    child: Text(
                      context.t(K.yourBalance, {
                        'coins': groupThousands(_coinBalance),
                      }),
                      style: SahneType.caption.copyWith(color: t.tx2),
                    ),
                  ),
                ],
              ),
              if (short) ...[
                const SizedBox(height: SahneSpace.x2),
                SahneShortfallNote(
                  key: const ValueKey('shop-dialog-shortfall'),
                  missing: coinShortfall(
                    cost: item.cost,
                    balance: _coinBalance,
                  ),
                  alert: true,
                  center: true,
                ),
              ],
            ],
          ),
          actions: [
            DialogActionPair(
              cancel: SahneButton.text(
                label: context.t(K.cancelShort),
                arrow: false,
                onPressed: () => Navigator.of(ctx).pop(false),
              ),
              // Diyaloğun tek birincil eylemi. Bakiye yetmiyorsa "Satın al"
              // pasif bırakılmaz, YERİNE gerçek bir sonraki adım gelir:
              // günlük çark (jeton kazanılan, kodda var olan yol).
              confirm: short
                  ? SahneButton.primary(
                      key: const ValueKey('shop-dialog-earn-coins'),
                      label: context.t(K.earnCoins),
                      arrow: false,
                      onPressed: () async {
                        Navigator.of(ctx).pop(false);
                        await _openSpinWheel();
                      },
                    )
                  : SahneButton.primary(
                      label: context.t(K.buyAction),
                      arrow: false,
                      onPressed: () => Navigator.of(ctx).pop(true),
                    ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.insufficientBalance))));
      return;
    }

    setState(() => _loading = true);
    setState(() {
      _purchaseErrorMessage = null;
      _retryPurchaseItem = item;
      _retryPurchaseEffectItem = null;
      _purchaseOffline = false;
    });

    final purchaseKey =
        'purchase_${item.id}_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final result = await widget.repository.spendCoinsDurable(
        item.cost,
        'purchase_${item.id}',
        purchaseKey,
      );
      if (!result.success && result.retryable) {
        await SyncManager.maybeInstance?.queueCoinSpend(
          amount: item.cost,
          reason: 'purchase_${item.id}',
          idempotencyKey: purchaseKey,
        );
        await _markEffectPending(item.id);
        if (!mounted) return;
        setState(() {
          _purchaseErrorMessage = context.t(K.errorOccurred);
          _retryPurchaseItem = null;
        });
        return;
      }
      final success = result.success;

      if (!mounted) return;

      if (success) {
        _purchaseErrorMessage = null;
        final effectApplied = await _applyPurchaseEffect(item.id);
        if (!mounted) return;
        if (!effectApplied) {
          final title = context.isKu ? item.titleKu : item.titleTr;
          setState(() {
            _purchaseErrorMessage = context.t(K.purchasedItem, {'item': title});
            _retryPurchaseItem = null;
            _retryPurchaseEffectItem = item;
            _purchaseOffline = false;
          });
          return;
        }
        _retryPurchaseEffectItem = null;
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
    } on RetryableWriteException catch (error, stack) {
      ErrorReporter.record(error.cause, stack, reason: 'shop_purchase');
      await SyncManager.maybeInstance?.queueCoinSpend(
        amount: item.cost,
        reason: 'purchase_${item.id}',
        idempotencyKey: purchaseKey,
      );
      await _markEffectPending(item.id);
      if (!mounted) return;
      setState(() {
        _purchaseErrorMessage = context.t(K.errorOccurred);
        _retryPurchaseItem = null;
        _purchaseOffline = isLikelyOfflineError(error.cause);
      });
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

  Future<bool> _applyPurchaseEffect(String itemId) async {
    // Bu koruma `applyShopPurchaseEffect`in gerçekten bir şey yaptığı
    // ürünlerle senkron kalmalı — 'avatar_frame_neon' burada yoktu ve dal
    // hiç açılmıyordu, yani neon satın alan oyuncu için
    // `loadAvatarIdentity`/`updateAvatarIdentity` hiç çağrılmıyordu
    // (2026-08-14 denetimi).
    if (!_hasPurchaseEffect(itemId)) return true;
    try {
      final identity = await widget.repository.loadAvatarIdentity();
      await widget.repository.updateAvatarIdentity(
        applyShopPurchaseEffect(itemId, identity),
      );
      return true;
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'shop purchase effect failed: $itemId',
      );
      return false;
    }
  }

  Future<void> _retryPurchaseEffect(ShopItem item) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _purchaseErrorMessage = null;
      _purchaseOffline = false;
    });

    final applied = await _applyPurchaseEffect(item.id);
    if (!mounted) return;

    if (!applied) {
      final title = context.isKu ? item.titleKu : item.titleTr;
      setState(() {
        _loading = false;
        _purchaseErrorMessage = context.t(K.purchasedItem, {'item': title});
        _retryPurchaseEffectItem = item;
      });
      return;
    }

    setState(() {
      _loading = false;
      _purchaseErrorMessage = null;
      _retryPurchaseEffectItem = null;
      _retryPurchaseItem = null;
    });
    HapticFeedback.lightImpact();
    _showPurchaseCelebrationDialog(item);
  }

  void _showPurchaseCelebrationDialog(ShopItem item) {
    final ku = context.isKu;
    final title = ku ? item.titleKu : item.titleTr;
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final t = SahneTokens.of(dialogContext);
        // 2026-09-29 Şahnê: altın kenarlı + bulanık gölgeli kutlama kutusu
        // ve maskot kalktı. Yüzey kartı; ürün Zêr tonlu elmasın içinde
        // (ödül Zêr'in işidir), tek birincil eylem "Anladım".
        return Dialog(
          backgroundColor: t.s1,
          shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
          child: Padding(
            padding: const EdgeInsets.all(SahneSpace.x6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: t.goldTint,
                      shape: SahneShape.diamond(
                        88,
                        side: BorderSide(
                          color: t.gold,
                          width: SahneRing.r2,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 88,
                      child: Icon(item.icon, size: 36, color: t.goldTx),
                    ),
                  ),
                ),
                const SizedBox(height: SahneSpace.x4),
                Semantics(
                  header: true,
                  child: Text(
                    context.t(K.congrats),
                    textAlign: TextAlign.center,
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ),
                const SizedBox(height: SahneSpace.x2),
                Text(
                  context.t(K.purchasedItem, {'item': title}),
                  textAlign: TextAlign.center,
                  style: SahneType.body.copyWith(color: t.tx2),
                ),
                const SizedBox(height: SahneSpace.x6),
                SahneButton.primary(
                  label: context.t(K.gotIt),
                  arrow: false,
                  expand: true,
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final t = SahneTokens.of(context);
    final coinLabel =
        '${groupThousands(_coinBalance)} '
        '${context.t(K.coinWord).toLowerCase()}';
    // 2026-09-29 Şahnê: B iskeleti. Sayfa adı çubukta, bakiye çubuğun
    // sağında jeton glifli stat çipi. Eski kimlik kartı ("Mağaza /
    // Jetonlarını akıllıca harca") kalktı: sayfa adı iki kez yazılmıyor.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(
        context,
        title: Text(context.t(K.shop)),
        actions: [
          // Dalga 5: devasa bakiye kartı yerine kompakt jeton çipi.
          SahneStatChip(
            key: const ValueKey('shop-coin-chip'),
            leading: const SahneGlyph(SahneGlyphKind.coin),
            label: coinLabel,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading && _dynamicItems.isEmpty
            ? const BrandedLoaderCenter()
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
                      title: _retryPurchaseEffectItem == null
                          ? context.t(K.purchaseErrorTitle)
                          : context.t(K.saveFailed),
                      message: _purchaseErrorMessage!,
                      retryLabel: context.t(K.retryShort),
                      onRetry: _retryPurchaseEffectItem != null
                          ? () =>
                                _retryPurchaseEffect(_retryPurchaseEffectItem!)
                          : _retryPurchaseItem == null
                          ? _loadBalance
                          : () => _purchase(_retryPurchaseItem!),
                    )
            : _dynamicItems.isEmpty
            ? AppEmptyState(
                icon: AppIcons.bagShopping,
                title: context.t(K.shopEmpty),
                message: context.t(K.checkConnection),
                actionLabel: context.t(K.retryShort),
                onAction: _loadBalance,
              )
            : _buildItemsList(context, ku),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  Günlük çark kısayolu
  // ────────────────────────────────────────────
  //
  // Günlük çarka giden TEK kalıcı yol. Öncesinde çarka erişim yalnız
  // bakiye TAM 0 iken görünen "jeton kazan" şeridiyle ve yetersiz-bakiye
  // dialog'undaki düğmeyle sınırlıydı — bakiyesi 0'dan farklı bir oyuncu
  // çarkı bir daha hiç bulamıyordu (2026-08-14 denetimi). Satır bakiyeden
  // bağımsız her zaman görünür.
  //
  // 2026-09-29 Şahnê: çubuktaki zar ikonu ve bakiye 0 iken üstte duran
  // altın şerit tek bir liste satırında birleşti. Bakiye 0 iken satırın
  // alt yazısı "Bakiyen 0 — günlük çarkı çevir" olur ve satır aynı zamanda
  // eski `shop-earn-coin-cta` giriş noktasıdır; iki ayrı yüzey aynı yere
  // götürmüyor.
  Widget _buildWheelShortcut(BuildContext context) {
    final zero = !_loading && _coinBalance == 0;
    final row = SahneListRow.icon(
      key: const ValueKey('shop-spin-wheel-entry'),
      icon: AppIcons.ferrisWheel,
      role: SahneRole.gold,
      title: context.t(K.wheelTitle),
      subtitle: zero ? context.t(K.zeroBalanceHint) : null,
      chevron: true,
      onTap: _openSpinWheel,
    );
    return SahneListGroup(
      children: [
        zero
            ? KeyedSubtree(
                key: const ValueKey('shop-earn-coin-cta'),
                child: row,
              )
            : row,
      ],
    );
  }

  // ────────────────────────────────────────────
  //  Ürünler: öne çıkan ürün + yüzey kartı ızgarası
  // ────────────────────────────────────────────
  Widget _buildItemsList(BuildContext context, bool ku) {
    final heroItem = _dynamicItems.reduce((a, b) => b.cost > a.cost ? b : a);
    final restItems = _dynamicItems.where((i) => i.id != heroItem.id).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        SahneSpace.x2,
        SahneSpace.page,
        SahneSpace.x8,
      ),
      children: [
        _buildWheelShortcut(context),
        const SizedBox(height: SahneSpace.x6),
        // Kurul 2. tur 2026-10-20: VIP kartı yatay ve kompakt (ikon solda,
        // ad+açıklama ortada, fiyat sağda); ızgara kartlarının yarısı boy.
        _buildShopCard(heroItem, ku, hero: true),
        if (restItems.isNotEmpty) ...[
          const SizedBox(height: SahneSpace.cardGap),
          // Sütun sayısı genişlikten; hücre yüksekliği içerikten. Sabit bir
          // en-boy oranı büyük yazıda ve Kurmancî adlarda kartı taşırıyordu
          // (kart dar, ad iki-üç satıra iner). Hücre boyu artık en uzun ürün
          // adının ve düğme etiketinin o genişlikte, o yazı ölçeğinde
          // ölçülen yüksekliğinden hesaplanır: satırdaki kartlar eşit boy
          // kalır, hiçbiri taşmaz ya da kesilmez.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // 2026-09-30 simülatör: büyük yazıda (Ekstra Büyük 2.35x)
              // iki sütun kalıyordu; ~165 px'lik kartta "Zivirîna zêde"
              // gibi adlar kelime ortasından kırılıyordu. Yazı 1.5x'i
              // geçince tek sütun: ad ve düğme tam genişlikte okunur.
              final largeText =
                  MediaQuery.textScalerOf(context).scale(1) >= 1.5;
              final columns = largeText
                  ? 1
                  : (width >= 680 ? 3 : (width >= 300 ? 2 : 1));
              // Kurul 3. tur 2026-10-20: tek sayıda ürün ve iki sütunda son
              // kart satırda yalnız kalıyordu (Neon). Son ürün tam genişlik
              // yatay kart (VIP gibi) olur; ızgara çift sayıyla kalır.
              final spanLast = columns == 2 && restItems.length.isOdd;
              final gridItems = spanLast
                  ? restItems.sublist(0, restItems.length - 1)
                  : restItems;
              final grid = GridView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: SahneSpace.cardGap,
                  crossAxisSpacing: SahneSpace.cardGap,
                  mainAxisExtent: _gridCellExtent(
                    context,
                    gridItems,
                    ku,
                    (width - SahneSpace.cardGap * (columns - 1)) / columns,
                  ),
                ),
                children: [
                  for (final item in gridItems) _buildShopCard(item, ku),
                ],
              );
              if (!spanLast) return grid;
              return Column(
                children: [
                  if (gridItems.isNotEmpty) grid,
                  if (gridItems.isNotEmpty)
                    const SizedBox(height: SahneSpace.cardGap),
                  _buildShopCard(restItems.last, ku, wide: true),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  /// Izgara hücresinin yüksekliği: kartın dikey dolgusu + önizleme
  /// karosu + en uzun ad + düğme. Ad ve düğme etiketi o sütun genişliğinde
  /// ve etkin yazı ölçeğinde gerçekten ölçülür.
  /// Kart açıklamasının en çok satırı; ızgara boyu ve kart aynı sınırı kullanır.
  static const int _descMaxLines = 3;

  double _gridCellExtent(
    BuildContext context,
    List<ShopItem> items,
    bool ku,
    double cellWidth,
  ) {
    const pad = SahneSpace.x3;
    const tile = 56.0;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    // Metin, kartın `Material`inin verdiği varsayılan biçemle (temanın
    // `bodyMedium`i) birleştirilerek ölçülür: miras harf aralığı satır
    // kırılımını değiştirir. 1 px pay, kenarda duran bir sözün ölçümde
    // sığıp çizimde alt satıra inmesini önler.
    final inherited =
        Theme.of(context).textTheme.bodyMedium ??
        DefaultTextStyle.of(context).style;
    double measure(
      String text,
      TextStyle style,
      double maxWidth, {
      int? maxLines,
    }) {
      final painter = TextPainter(
        maxLines: maxLines,
        // Aile açıkça ölçülen biçemden gelir (Onest / Bricolage);
        // miras biçemin ailesi ölçümü sistem yazı tipine düşürmesin.
        text: TextSpan(
          text: text,
          style: inherited.merge(style).copyWith(fontFamily: style.fontFamily),
        ),
        textDirection: direction,
        textScaler: scaler,
      )..layout(maxWidth: (maxWidth - 1).clamp(1.0, double.infinity));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final inner = cellWidth - pad * 2;
    var title = 0.0;
    var desc = 0.0;
    var button = 52.0;
    var note = 0.0;
    for (final item in items) {
      final name = ku ? item.titleKu : item.titleTr;
      title = math.max(title, measure(name, SahneType.bodyStrong, inner));
      desc = math.max(
        desc,
        measure(
          ku ? item.descKu : item.descTr,
          SahneType.caption,
          inner,
          maxLines: _descMaxLines,
        ),
      );
      final label = _purchasedItemIds.contains(item.id)
          ? context.t(K.ownedLabel)
          : '${item.cost}';
      // Düğme: 12 + ikon (20) + 8 yan boşlukla etiket; dikeyde 12 + 12.
      final labelHeight = measure(
        label,
        SahneType.button,
        inner - SahneSpace.x3 * 2 - 20 - SahneSpace.x2,
      );
      button = math.max(button, labelHeight + SahneSpace.x3 * 2);
      // Jeton yetmeyen ürünün düğmesi pasiftir; eksik sözü düğmenin
      // altında ayrı satırdır, hücre onu da sığdırmalı.
      final missing = coinShortfall(cost: item.cost, balance: _coinBalance);
      if (missing > 0 && !_purchasedItemIds.contains(item.id)) {
        note = math.max(
          note,
          measure(
            context.t(K.coinsShort, {'coins': '$missing'}),
            SahneType.captionStrong,
            inner,
          ),
        );
      }
    }
    if (note > 0) note += SahneSpace.x1;
    // +2: basınca 2 px çöken düğmenin payı ve yuvarlama.
    return pad +
        tile +
        SahneSpace.x3 +
        title +
        SahneSpace.x1 +
        desc +
        SahneSpace.x3 +
        button +
        note +
        pad +
        2;
  }

  // ────────────────────────────────────────────
  //  Tek mağaza kartı (ızgara hücresi ve VIP aynı çerçeve)
  // ────────────────────────────────────────────
  //
  // Kurul 2026-10-20 (5 model): VIP kartı ızgaradan boyut ve hizayla
  // ayrışıyor, fiyatlar kartta süzülüyor, jeton yetmeyince neyin alınamadığı
  // belli değildi. Artık her kart: ikon karosu, ad, kısa açıklama, ve kartın
  // EYLEMİ olan fiyat düğmesi (jeton glifi + tutar). Jeton yetmiyorsa düğme
  // ortak pasif biçimde (disabledFill/Edge/Fg) çizilir ve altında eksik
  // miktar yazar; kartın kendisi dokunulabilir kalır (pencere jeton kazanma
  // yolunu sunar). Ürün kimliği yalnız önizleme karosunda yaşar.
  Widget _buildShopCard(
    ShopItem item,
    bool ku, {
    bool hero = false,
    bool wide = false,
  }) {
    final t = SahneTokens.of(context);
    final title = ku ? item.titleKu : item.titleTr;
    final desc = ku ? item.descKu : item.descTr;
    final isPurchased = _purchasedItemIds.contains(item.id);

    if (hero || wide) {
      final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
      final texts = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: SahneType.bodyStrong.copyWith(
              color: isPurchased ? t.tx2 : t.tx,
            ),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(desc, style: SahneType.caption.copyWith(color: t.tx2)),
        ],
      );
      final action = isPurchased
          ? _buildOwnedChip(expand: largeText)
          : _buildBuyButton(item, ku, expand: largeText);
      return SahneSurfaceCard(
        key: hero
            ? const ValueKey('shop-hero-surface')
            : ValueKey('shop-item-surface-${item.id}'),
        padding: const EdgeInsets.all(SahneSpace.x3),
        onTap: (_loading || isPurchased) ? null : () => _confirmPurchase(item),
        child: largeText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _preview(item, size: 56, dim: isPurchased),
                  ),
                  const SizedBox(height: SahneSpace.x3),
                  texts,
                  const SizedBox(height: SahneSpace.x3),
                  action,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _preview(item, size: 56, dim: isPurchased),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(child: texts),
                  const SizedBox(width: SahneSpace.x3),
                  action,
                ],
              ),
      );
    }

    return SahneSurfaceCard(
      key: ValueKey('shop-item-surface-${item.id}'),
      padding: const EdgeInsets.all(SahneSpace.x3),
      onTap: (_loading || isPurchased) ? null : () => _confirmPurchase(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _preview(item, size: 56, dim: isPurchased),
          ),
          const SizedBox(height: SahneSpace.x3),
          Text(
            title,
            style: SahneType.bodyStrong.copyWith(
              color: isPurchased ? t.tx2 : t.tx,
            ),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            desc,
            maxLines: _descMaxLines,
            overflow: TextOverflow.ellipsis,
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
          const Spacer(),
          const SizedBox(height: SahneSpace.x3),
          isPurchased ? _buildOwnedChip() : _buildBuyButton(item, ku),
        ],
      ),
    );
  }

  // ── "Sende": pasif ikincil düğme + ✓ (satın alınmış, tekrar alınamaz) ──
  Widget _buildOwnedChip({bool expand = true}) {
    return SahneButton.secondary(
      label: context.t(K.ownedLabel),
      icon: AppIcons.check,
      expand: expand,
      onPressed: null,
    );
  }

  // ── Satın al ──
  //
  // Öne çıkan ürünün düğmesi ekranın TEK birincil eylemidir (Agir); ızgara
  // kartlarınınki ikincil (Kulis). Fiyatın solunda Şahnê jeton glifi
  // durur — Lucide ikonu değil (ödül glifleri `SahneGlyph`).
  Widget _buildBuyButton(ShopItem item, bool ku, {bool expand = true}) {
    // Görünen etiket yalnız sayı; birimi soldaki jeton glifi söyler.
    // 2026-09-29 doğallık: "720j" kısaltması kalktı (K10) — glifin
    // yanında "j" ikinci kez aynı şeyi söylüyordu ve Kurmancîde "720z"
    // okunmuyordu. Ekran okuyucuya söylenen ad tam cümle (bkz.
    // `test/button_semantics_test.dart`): düğme yalnız "düğme" diye
    // okunursa neyi satın alacağı söylenmez.
    final label = '${item.cost}';
    final semanticLabel = context.t(K.buyItemForCoins, {
      'item': ku ? item.titleKu : item.titleTr,
      'coins': '${item.cost}',
    });
    // Jeton yetmiyorsa düğme ortak pasif biçimdedir (kurul 2026-10-20:
    // yetmeyen ürün gri-düz çip olunca kartın eylemi kayboluyordu). Fiyat
    // görünür kalır; eksik söz altında yazar (bakiye 0 iken eksik fiyatın
    // kendisidir, ikinci kez yazılmaz). Kartın kendisi dokunulabilir kalır:
    // pencere jeton kazanma yolunu sunar.
    final missing = coinShortfall(cost: item.cost, balance: _coinBalance);
    if (missing > 0) {
      final note =
          SahnePriceChip.noteShownFor(price: item.cost, missing: missing)
          ? context.t(K.coinsShort, {'coins': '$missing'})
          : null;
      return Column(
        crossAxisAlignment: expand
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SahneButton.secondary(
            key: ValueKey('shop-short-${item.id}'),
            label: label,
            // Kilit + jeton: pasif düğme "alınamaz"ı yalnız renkle değil
            // simgeyle de söyler (kurul 2. tur).
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.lock,
                  size: 16,
                  color: SahneTokens.of(context).tx2,
                ),
                const SizedBox(width: SahneSpace.x1),
                const SahneGlyph(SahneGlyphKind.coin, size: 20),
              ],
            ),
            expand: expand,
            semanticLabel:
                '$semanticLabel. ${context.t(K.coinsShort, {'coins': '$missing'})}',
            onPressed: null,
          ),
          if (note != null) ...[
            const SizedBox(height: SahneSpace.x1),
            Text(
              note,
              textAlign: TextAlign.center,
              style: SahneType.captionStrong.copyWith(
                color: SahneTokens.of(context).tx2,
              ),
            ),
          ],
        ],
      );
    }
    final onPressed = _loading ? null : () => _confirmPurchase(item);
    // Alınabilir fiyat: turuncu çerçeveli, açık zeminli düğme. Pasif düğme
    // gri DOLGU olduğundan ikisi bir bakışta ayrılır; eskiden alınabilir
    // olan da ikincil gri dolguydu ve pasif görünüyordu (kurul 2. tur).
    final t = SahneTokens.of(context);
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox(
        width: expand ? double.infinity : null,
        child: OutlinedButton(
          key: ValueKey('shop-buy-${item.id}'),
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            elevation: 0,
            backgroundColor: t.s1,
            foregroundColor: t.actTx,
            minimumSize: const Size(52, 52),
            textStyle: SahneType.button,
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x4,
              vertical: SahneSpace.x3,
            ),
            // `side` açık yazılır: temanın ikincil kenarı (ink %40) yoksa
            // şeklin turuncu kenarını ezer.
            side: BorderSide(color: t.actTx, width: 1.5),
            shape: SahneShape.m,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SahneGlyph(SahneGlyphKind.coin, size: 20),
              const SizedBox(width: SahneSpace.x2),
              Flexible(child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ürün önizleme karosu: Zêr tonu zemin, M pah, ortada Zêr metni ikon.
///
/// Mağazadaki her ürün jetonla alınan bir ödüldür; Şahnê'de ödülün rengi
/// Zêr'dir. Ürünün eski "tema rengi" (yeşil, altın, turuncu) karoya
/// boyanmaz — ızgara tek tonda sakin kalır. İlk turda karo Kulis (`s2`)
/// idi ve aynı karttaki ikincil satın alma düğmesiyle (o da Kulis) ayırt
/// edilemiyordu. Alınmış ürün nötr Kulis + üçüncül ikon.
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.icon,
    required this.size,
    this.dim = false,
    this.child,
  });

  final IconData icon;
  final double size;
  final bool dim;

  /// Verilirse ikon yerine karonun ortasında durur (çerçeve ürününde
  /// oyuncunun avatarı).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: dim ? t.s2 : t.goldTint,
          shape: SahneShape.m,
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: child != null
              ? Center(child: child)
              : Icon(icon, size: size * 0.45, color: dim ? t.tx3 : t.goldTx),
        ),
      ),
    );
  }
}
