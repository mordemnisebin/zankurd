// Tasarım kurulu tüm ekranlar 2026-10-20: mağaza kartı = ikon, ad, açıklama,
// fiyat düğmesi; VIP aynı çerçeve; yetmeyen ürün ortak pasif düğme.
// 2026-10-19 sadeleşme: "sakin yüzey" bekçisi yuvarlak köşeli yüzey
// kartını (`OutlinedBorder`) kabul eder; eskiden pahlı şekle cast ediyordu.
// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
// 2026-09-29 doğallık (G3): fiyat etiketi "120j" değil "120" (birimi jeton
// glifi söyler, K10); ürün adları cümle düzeninde ("Neon çerçeve"). Bu
// beklentiler yalnız eski yazımı sabitliyordu; davranış aynı.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/durable_write.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';

/// Bakiye ve satın alma durumunu deterministik kontrol eden sahte depo.
class _ShopRepository extends MockZanKurdRepository {
  _ShopRepository({required this.coins, Set<String>? purchased})
    : purchased = purchased ?? <String>{};

  int coins;
  final Set<String> purchased;
  final List<String> spendReasons = [];
  int hasPurchasedCalls = 0;

  @override
  Future<int> loadCoinBalance() async => coins;

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    if (coins < amount) return false;
    coins -= amount;
    spendReasons.add(reason);
    return true;
  }

  @override
  Future<bool> hasPurchased(String itemId) async {
    hasPurchasedCalls++;
    return purchased.contains(itemId);
  }
}

class _FailingEffectShopRepository extends _ShopRepository {
  _FailingEffectShopRepository() : super(coins: 1000);

  bool failEffect = true;
  int effectWriteCalls = 0;
  AvatarIdentity identity = const AvatarIdentity(
    iconId: 'roj',
    colorHex: '#E94560',
  );

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    final success = await super.spendCoins(amount, reason);
    if (success && reason.startsWith('purchase_')) {
      purchased.add(reason.substring('purchase_'.length));
    }
    return success;
  }

  @override
  Future<AvatarIdentity> loadAvatarIdentity() async => identity;

  @override
  Future<void> updateAvatarIdentity(AvatarIdentity next) async {
    effectWriteCalls += 1;
    if (failEffect) throw StateError('avatar identity persist failed');
    identity = next;
  }
}

class _OfflineSpendShopRepository extends _ShopRepository {
  _OfflineSpendShopRepository() : super(coins: 1000);

  @override
  Future<DurableCoinSpend> spendCoinsDurable(
    int amount,
    String reason,
    String idempotencyKey,
  ) async => throw const RetryableWriteException('network down');
}

class _SpinWheelShopRepository extends _ShopRepository {
  _SpinWheelShopRepository() : super(coins: 0);

  @override
  Future<bool> canSpinToday() async => true;

  @override
  Future<int> awardSpinCoins() async {
    coins += 30;
    return 30;
  }
}

Widget _shell(Widget child, {bool reducedMotion = false}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
      ChangeNotifierProvider<ReducedMotionProvider>(
        create: (_) => ReducedMotionProvider(initialUserReduce: reducedMotion),
      ),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

Future<void> _spinAndReturn(
  WidgetTester tester,
  _SpinWheelShopRepository repository,
  String entryKey,
) async {
  await tester.tap(find.byKey(ValueKey(entryKey)));
  await tester.pumpAndSettle();
  await tester.pump();
  expect(find.text('Günün çarkı'), findsOneWidget);
  expect(find.byType(SpinWheelScreen), findsOneWidget);
  await tester.drag(find.byType(Scrollable), const Offset(0, -500));
  await tester.pump();
  await tester.tap(find.text('Çevir'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  // 2026-09-29 Şahnê: çark sayfası B iskeletidir; geri düğmesi bileşenin
  // 44'lük plakası, sözü uygulamanın dilinden ('Geri').
  await tester.tap(find.byTooltip('Geri'));
  await tester.pumpAndSettle();
}

void main() {
  // Neon/altın çerçeve satın alma `loadAvatarIdentity`/`updateAvatarIdentity`
  // üzerinden `SharedPreferences`e dokunur; mock'lanmazsa platform kanalı
  // hiç yanıt vermediği için widget testi sonsuza kadar asılı kalır.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('mağaza kozmetik etkileri profil kimliğine uygulanır', () {
    const identity = AvatarIdentity(iconId: 'roj', colorHex: '#E94560');

    expect(
      applyShopPurchaseEffect('avatar_frame_gold', identity).frameId,
      'gold',
    );
    expect(
      applyShopPurchaseEffect('profile_badge_vip', identity).showcaseTitle,
      'VIP',
    );
    expect(applyShopPurchaseEffect('spin_wheel_extra', identity), identity);
  });

  // 2026-08-14 denetimi: 'avatar_frame_neon' bu iki yerin (etki
  // fonksiyonu + _applyPurchaseEffect koruması) İKİSİNDE de eksikti.
  // Satın alma coini düşürüp kutlama dialog'unu gösteriyordu ama
  // `frameId` hiç 'neon' olmuyordu — profile dönünce çerçeve yoktu.
  test('neon çerçeve satın alınca frameId "neon" olur', () {
    const identity = AvatarIdentity(iconId: 'roj', colorHex: '#E94560');

    expect(
      applyShopPurchaseEffect('avatar_frame_neon', identity).frameId,
      'neon',
    );
  });

  testWidgets(
    'neon çerçeve satın alınca depoya yazılan kimlikte frameId "neon" olur',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ShopRepository(coins: 1000);
      await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Neon çerçeve'));
      await tester.tap(find.text('Neon çerçeve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satın al'));
      await tester.pumpAndSettle();

      expect((await repository.loadAvatarIdentity()).frameId, 'neon');
    },
  );

  testWidgets(
    'kozmetik alındıktan sonra kuşanma kaydı bozulursa tekrar coin harcanmaz',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _FailingEffectShopRepository();
      await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Neon çerçeve'));
      await tester.tap(find.text('Neon çerçeve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satın al'));
      await tester.pumpAndSettle();

      expect(repository.spendReasons, ['purchase_avatar_frame_neon']);
      expect(repository.effectWriteCalls, 1);
      expect(find.text('Tebrikler!'), findsNothing);
      expect(find.text('Kaydedilemedi.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);

      repository.failEffect = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      expect(
        repository.spendReasons,
        ['purchase_avatar_frame_neon'],
        reason:
            'Kuşanma retry satın almayı ve coin harcamasını tekrarlamamalı.',
      );
      expect(repository.effectWriteCalls, 2);
      expect(repository.identity.frameId, 'neon');
      expect(find.text('Tebrikler!'), findsOneWidget);
    },
  );

  // Bekçi (2026-10-15): bağlantı koptuğunda satın alma kuyruğa alınıyor
  // (`queueCoinSpend`), ama çerçeve/VIP etkisi yalnız anlık yoldan uygulanıyordu;
  // kuyruk boşalınca oyuncu parasını verip çerçevesini hiç göremiyordu. Testler
  // hep anlık başarıyı denediği için sessizdi. Şimdi kuyruğa alınan ürün
  // işaretlenir ve sunucu satın almayı onaylayınca mağaza açılışında uygulanır;
  // işaretsiz ürün (oyuncunun sonradan seçtiği çerçeve) ezilmez.
  testWidgets(
    'kuyruktan sonra onaylanan satın almanın etkisi açılışta uygulanır',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'shop_pending_purchase_effects': ['avatar_frame_neon'],
      });
      final repository = _FailingEffectShopRepository()
        ..failEffect = false
        ..purchased.addAll({'avatar_frame_neon', 'avatar_frame_gold'});
      await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
      await tester.pumpAndSettle();

      expect(repository.identity.frameId, 'neon');
      expect(repository.effectWriteCalls, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('shop_pending_purchase_effects'), isEmpty);
    },
  );

  testWidgets('kuyruğa alınan çerçeve satın alması etkisi için işaretlenir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _OfflineSpendShopRepository();
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Neon çerçeve'));
    await tester.tap(find.text('Neon çerçeve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın al'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('shop_pending_purchase_effects'), [
      'avatar_frame_neon',
    ]);
  });

  testWidgets('işaretsiz satın alınmış ürün açılışta kimliği ezmez', (
    tester,
  ) async {
    final repository = _FailingEffectShopRepository()
      ..failEffect = false
      ..purchased.addAll({'avatar_frame_neon', 'avatar_frame_gold'});
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(repository.effectWriteCalls, 0);
  });

  // 2026-07-31: katalog 13 ürün tanımlıyordu ama yalnız 3'ü yayınlanıyordu;
  // kalan 10'u ölü veriydi ve `_supportedItemIds`e yanlışlıkla eklenirlerse
  // coin alıp hiçbir şey yapmazlardı. Dokuzu tamamen silindi, neon çerçeve
  // ise gerçekten uygulandı (AvatarFrame.neon + hasPurchased kancası).
  //
  // Bu bekçinin işi: katalogda YAYINLANMAYAN ürün kalmaması. Yani liste
  // artık hem "ne yayınlanıyor" hem "ne tanımlı" sorusunun tek cevabı.
  test('mağaza yalnız gerçekten çalışan ürünleri yayınlar', () {
    expect(debugShopItems.map((item) => item.id).toSet(), {
      'spin_wheel_extra',
      'avatar_frame_gold',
      'avatar_frame_neon',
      'profile_badge_vip',
    });
  });

  testWidgets('mağaza ürün rengini büyük yüzeylere taşımadan sakin kalır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 500);

    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    // 2026-09-29 Şahnê: öne çıkan ürün ve ızgara kartları aynı yüzey
    // kartıdır (`SahneSurfaceCard`: Perde dolgu, L pah, gündüzde 1 px
    // kenar, gölgesiz, degradesiz). Kural aynı: ürün rengi büyük yüzeye
    // taşınmaz, kartlar sakin kalır.
    void expectCalmSurface(Finder card) {
      expect(card, findsOneWidget);
      expect(tester.widget(card), isA<SahneSurfaceCard>());
      final material = tester.widget<Material>(
        find.descendant(of: card, matching: find.byType(Material)).first,
      );
      final t = SahneTokens.of(tester.element(card));
      expect(material.color, t.s1);
      expect(material.elevation, 0);
      final shape = material.shape! as OutlinedBorder;
      expect(shape.side.color, t.edge);
      expect(
        find
            .descendant(of: card, matching: find.byType(DecoratedBox))
            .evaluate()
            .where((e) {
              final d = (e.widget as DecoratedBox).decoration;
              return d is BoxDecoration &&
                  (d.gradient != null || (d.boxShadow?.isNotEmpty ?? false));
            }),
        isEmpty,
      );
    }

    expectCalmSurface(find.byKey(const ValueKey('shop-hero-surface')));
    expectCalmSurface(
      find.byKey(const ValueKey('shop-item-surface-spin_wheel_extra')),
    );
    expect(
      find.byKey(const ValueKey('shop-item-accent-stripe-spin_wheel_extra')),
      findsNothing,
      reason: 'Ürün rengi tam genişlik dekor şeridine dönüşmemeli.',
    );
  });

  // Kurul 2. tur 2026-10-20: alınabilir fiyat = turuncu çerçeveli açık düğme
  // (hero dahil); pasif düğme gri dolgu + kilit. İkisi bir bakışta ayrılır;
  // eskiden alınabilir olan da gri dolguydu ve pasif görünüyordu.
  testWidgets(
    'alınabilir fiyat turuncu çerçeveli, yetmeyen gri dolgulu ve kilitli',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ShopRepository(coins: 500);

      await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
      await tester.pumpAndSettle();

      final t = SahneTokens.of(tester.element(find.byType(ShopScreen)));
      final affordable = find.byKey(
        const ValueKey('shop-buy-spin_wheel_extra'),
      );
      expect(affordable, findsOneWidget);
      // Kurul 4. tur 2026-10-20: alınabilir fiyat DOLU turuncu birincil
      // düğme; kilitli fiyat kutusuz düz metin (gri kutu düğme gibi okunuyor,
      // alınabilen ürün ondan zayıf kalıyordu).
      final filled = tester.widget<FilledButton>(
        find.descendant(of: affordable, matching: find.byType(FilledButton)),
      );
      expect(filled.onPressed, isNotNull);
      expect(t.act.computeLuminance(), greaterThan(0.2));

      final short = find.byKey(const ValueKey('shop-short-profile_badge_vip'));
      expect(short, findsOneWidget);
      expect(
        find.descendant(of: short, matching: find.byIcon(AppIcons.lock)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: short, matching: find.byType(OutlinedButton)),
        findsNothing,
      );
      expect(
        find.descendant(of: short, matching: find.byType(FilledButton)),
        findsNothing,
        reason: 'kilitli fiyat kutu/düğme değil düz metin',
      );
      // Tur 9b: eksik söz sağ sütundan sol metin sütununa (açıklamanın altına)
      // taşındı; sağ sütunda yalnız kilitli fiyat kalır.
      expect(
        find.descendant(
          of: short,
          matching: find.textContaining('jeton eksik'),
        ),
        findsNothing,
      );
      final note = tester.widget<Text>(
        find.byKey(const ValueKey('shop-short-note-profile_badge_vip')),
      );
      expect(note.style?.color, t.goldTx, reason: 'eksik söz sıcak ton');
    },
  );

  testWidgets('VIP kartı yatay ve kompakt (eskiden ~490 mp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(ShopScreen(repository: _ShopRepository(coins: 1000))),
    );
    await tester.pumpAndSettle();
    final hero = tester.getSize(
      find.byKey(const ValueKey('shop-hero-surface')),
    );
    // Tur 6: Kurmancî olmayan Türkçe açıklama dar sütunda 3 satıra iner;
    // kart yine kompakt (eskiden ~490 mp).
    expect(hero.height, lessThanOrEqualTo(230));
  });

  // Tur 6: tüm ürünler aynı tam genişlik yatay satır (bkz.
  // tur6a_magaza_esit_kart_bekcisi_test).
  testWidgets('tüm ürün kartları tam genişlik ve alt alta dizilir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(ShopScreen(repository: _ShopRepository(coins: 300))),
    );
    await tester.pumpAndSettle();
    final first = tester.getRect(
      find.byKey(const ValueKey('shop-item-surface-spin_wheel_extra')),
    );
    final last = tester.getRect(
      find.byKey(const ValueKey('shop-item-surface-avatar_frame_neon')),
    );
    expect(last.width, first.width);
    expect(last.top, greaterThan(first.bottom - 1));
  });

  testWidgets('mağaza bakiyeyi ve ürünleri listeler', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('500 jeton'), findsOneWidget);
    expect(find.text('Ekstra çevirme'), findsOneWidget);
    expect(find.text('Altın çerçeve'), findsOneWidget);
    expect(find.text('VIP rozeti'), findsOneWidget);
    expect(find.text('Joker Paketi'), findsNothing);
    expect(find.text('Ekstra Can'), findsNothing);
    expect(find.text('Premium Renkler'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // 2026-09-29 doğallık (K10): "En çok alınan" rozeti satış verisi
  // olmadan her kurulumda en pahalı ürüne yapışıyordu — uydurma bir iddia.
  // Veri gelene dek hiçbir üründe görünmez.
  testWidgets('mağaza satış verisi olmadan "en çok alınan" demez', (
    tester,
  ) async {
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('En çok alınan'), findsNothing);
    expect(find.byType(SahneBadge), findsNothing);
  });

  // 2026-09-29 doğallık (K10): çerçeve ürününün karosunda boş bir yıldız
  // duruyordu; oyuncu neyi satın alacağını görmüyordu. Karo artık
  // oyuncunun kendi avatarını o çerçeveyle gösterir.
  testWidgets('çerçeve ürünü oyuncunun avatarını o çerçeveyle gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    for (final id in ['avatar_frame_gold', 'avatar_frame_neon']) {
      final card = find.byKey(ValueKey('shop-item-surface-$id'));
      expect(card, findsOneWidget);
      final avatar = find.descendant(
        of: card,
        matching: find.byType(PlayerAvatar),
      );
      expect(avatar, findsOneWidget, reason: '$id karosu avatar göstermeli');
      expect(
        tester.widget<PlayerAvatar>(avatar).frameId,
        applyShopPurchaseEffect(id, const AvatarIdentity()).frameId,
      );
    }
    // Çerçeve olmayan ürün ikonunda kalır.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('shop-item-surface-spin_wheel_extra')),
        matching: find.byType(PlayerAvatar),
      ),
      findsNothing,
    );
  });

  // 2026-08-14 denetimi: çarka giden TEK yol, bakiye TAM 0 iken görünen
  // `_buildEarnCoinCta`ydı. Bakiyesi 0'dan farklı bir oyuncu (ör. burada
  // 500 jeton) çarkı bir daha hiç bulamıyordu. AppBar'daki giriş düğmesi
  // bakiyeden bağımsız her zaman görünmeli ve çarka götürmeli.
  testWidgets('AppBar çarkı sonrası bakiye ve katalog state korunur', (
    tester,
  ) async {
    final repository = _SpinWheelShopRepository();
    await tester.pumpWidget(
      _shell(ShopScreen(repository: repository), reducedMotion: true),
    );
    await tester.pumpAndSettle();

    final initialCatalogReads = repository.hasPurchasedCalls;
    expect(find.text('0 jeton'), findsOneWidget);
    await _spinAndReturn(tester, repository, 'shop-spin-wheel-entry');

    expect(find.text('30 jeton'), findsOneWidget);
    expect(repository.hasPurchasedCalls, initialCatalogReads);
  });

  testWidgets('bakiye 0 jeton kazan CTA çarkı sonrası bakiyeyi yeniler', (
    tester,
  ) async {
    final repository = _SpinWheelShopRepository();
    await tester.pumpWidget(
      _shell(ShopScreen(repository: repository), reducedMotion: true),
    );
    await tester.pumpAndSettle();

    await _spinAndReturn(tester, repository, 'shop-earn-coin-cta');
    expect(find.text('30 jeton'), findsOneWidget);
  });

  testWidgets('yetersiz bakiye dialogundaki Coin kazan çarkı sonrası yeniler', (
    tester,
  ) async {
    final repository = _SpinWheelShopRepository();
    await tester.pumpWidget(
      _shell(ShopScreen(repository: repository), reducedMotion: true),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('120'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('120'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jeton kazan'));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.drag(find.byType(Scrollable), const Offset(0, -500));
    await tester.pump();
    await tester.tap(find.text('Çevir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    // 2026-09-29 Şahnê: çark sayfası B iskeletidir; geri düğmesi bileşenin
    // 44'lük plakası, sözü uygulamanın dilinden ('Geri').
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();

    expect(find.text('30 jeton'), findsOneWidget);
  });

  testWidgets(
    'kart açıklamayı gösterir, ürüne dokununca onay penceresi aynı ayrıntıyı açar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ShopRepository(coins: 500);
      await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
      await tester.pumpAndSettle();

      const description = 'Bugün çarkı tekrar çevirmek için ekstra hak verir.';
      // Kurul 2026-10-20: açıklama artık kartta yazar (kart: ikon, ad,
      // açıklama, fiyat düğmesi).
      expect(find.text(description), findsOneWidget);
      await tester.ensureVisible(find.text('Ekstra çevirme'));
      await tester.tap(find.text('Ekstra çevirme'));
      await tester.pumpAndSettle();
      expect(find.text(description), findsNWidgets(2));
      expect(find.text('Satın al'), findsOneWidget);
    },
  );

  // Tur 10b kusuru: metin sütunu fiyat/eylem sütunuyla genişliği paylaşıyordu;
  // ad 2, açıklama 3-4 satıra kırılıyordu. Sessiz kaldı çünkü hiçbir şey
  // taşmıyor, yalnız kart uzuyordu. Bekçi: metin kartın tam genişliğini alır
  // ve fiyat/eylem satırı metnin ALTINDA, sağa yaslı durur.
  testWidgets('mağaza kartı: metin tam genişlik, eylem altta sağa yaslı', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 300);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    final card = find.byKey(
      const ValueKey('shop-item-surface-spin_wheel_extra'),
    );
    final title = find.descendant(
      of: card,
      matching: find.text('Ekstra çevirme'),
    );
    final desc = find.descendant(
      of: card,
      matching: find.text('Bugün çarkı tekrar çevirmek için ekstra hak verir.'),
    );
    final buy = find.byKey(const ValueKey('shop-buy-spin_wheel_extra'));
    final cardRect = tester.getRect(card);
    // Ad tek satır; açıklama kart genişliğinin sağ kenarına kadar uzanır
    // (test yazı tipi geniştir, satır sayısı değil genişlik sabitlenir).
    expect(tester.getSize(title).height, lessThan(26));
    expect(tester.getRect(desc).right, greaterThan(cardRect.right - 60));
    // Eylem metnin altında ve sağa yaslı, ~40 yükseklik.
    expect(
      tester.getRect(buy).top,
      greaterThanOrEqualTo(tester.getRect(desc).bottom),
    );
    expect(tester.getRect(buy).right, greaterThan(cardRect.right - 20));
    expect(tester.getSize(buy).height, inInclusiveRange(38, 48));
    // Kilitli üründe eksik notu eylem satırında, kilitli fiyatın solunda.
    final note = find.byKey(
      const ValueKey('shop-short-note-profile_badge_vip'),
    );
    final locked = find.byKey(const ValueKey('shop-short-profile_badge_vip'));
    expect(
      tester.getRect(note).right,
      lessThanOrEqualTo(tester.getRect(locked).left),
    );
    expect(tester.getRect(locked).right, greaterThan(cardRect.right - 40));
  });

  testWidgets('satın alma eylemleri düz ve gölgesizdir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Satın al · 120'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Satın al · 120'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.style?.elevation?.resolve(<WidgetState>{}) ?? 0, 0);
  });

  testWidgets('bakiye yetersizse uyarı çıkar ve coin harcanmaz', (
    tester,
  ) async {
    final repository = _ShopRepository(coins: 50);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Ekstra çark 120 jeton — bakiye 50c ile alınamamalı.
    await tester.ensureVisible(find.text('120'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('120'));
    await tester.pumpAndSettle();
    // 2026-10-01 (A5): yetersiz bakiyede pencerede pasif bir 'Satın al'
    // DURMAZ; yerine gerçek sonraki adım ('Jeton kazan') ve eksik miktar
    // gelir. Ayrıntılı bekçi: `coin_shortfall_pattern_test.dart`.
    expect(find.text('Satın al'), findsNothing);
    expect(find.text('Jeton kazan'), findsOneWidget);
    expect(find.text('70 jeton eksik'), findsWidgets);
    expect(repository.spendReasons, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('satın alma coini düşürür ve doğru gerekçeyle harcar', (
    tester,
  ) async {
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Satın al · 120'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın al · 120'));
    await tester.pumpAndSettle();
    // Confirm dialog: tap "Satın al"
    await tester.tap(find.text('Satın al'));
    await tester.pumpAndSettle();

    expect(repository.spendReasons, ['purchase_spin_wheel_extra']);
    // 500 - 120 (yeni ekstra çevirme fiyatı) = 380
    expect(repository.coins, 380);
    expect(find.text('380 jeton'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alınmış ürün "Alındı" görünür ve tekrar alınamaz', (
    tester,
  ) async {
    final repository = _ShopRepository(
      coins: 1000,
      purchased: {'avatar_frame_gold'},
    );
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Sende'), findsOneWidget);

    // Purchased items cannot be re-purchased — no buy button shown
    expect(find.text('480'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekstra çevirme tüketilebilir olduğu için yeniden alınabilir', (
    tester,
  ) async {
    final repository = _ShopRepository(
      coins: 500,
      purchased: {'spin_wheel_extra'},
    );
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Satın al · 120'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spendCoins başarısız dönerse hata mesajı gösterilir', (
    tester,
  ) async {
    final repository = _FailingSpendRepository();
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Satın al · 120'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın al · 120'));
    await tester.pumpAndSettle();
    // Confirm dialog: tap "Satın al"
    await tester.tap(find.text('Satın al'));
    await tester.pumpAndSettle();

    expect(find.text('Satın alınamadı. Tekrar dene.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Yayın kataloğunda yalnız gerçek etkisi bulunan ürünler kalır. Fiyatlar
  // istemci ve sunucu arasında birebir korunmalıdır.
  test('mağaza paleti marka tonları çoğunlukta (M24)', () {
    final brandTones = <Color>{
      AppTheme.gold,
      AppTheme.accent,
      AppTheme.correct,
    };
    final brandCount = debugShopItems
        .where((item) => brandTones.contains(item.themeColor))
        .length;
    final offBrandCount = debugShopItems.length - brandCount;

    expect(
      brandCount,
      greaterThan(offBrandCount),
      reason:
          'Marka dışı tonlar (playPink/playCyan/playPurple) çoğunlukta '
          'kalmamalı — M24 denetiminin amacı buydu.',
    );
  });

  test('mağaza ürün fiyatları M24 paleti değişikliğinden etkilenmedi', () {
    // 2026-08-10: fiyatlar ölçülen gelire göre yeniden çıpalandı.
    // Çevrimdışı oyuncunun tek jeton kaynağı günlük çark (ortalama 40,6/gün);
    // eski fiyatlarla ilk satın alma 4,9 gün, katalog 24,6 gün sürüyordu.
    // Gerekçe ve kısıtlar `test/shop_economy_anchor_test.dart` içinde.
    const expectedCosts = {
      'spin_wheel_extra': 120,
      'avatar_frame_gold': 480,
      'avatar_frame_neon': 350,
      'profile_badge_vip': 720,
    };

    final actualCosts = {for (final item in debugShopItems) item.id: item.cost};
    expect(actualCosts, expectedCosts);
  });

  // 2026-07-23 M33 marka kimliği için başlığa bir Roj maskotu şeridi
  // eklemişti. 2026-07-25 canlı denetiminde bu şerit, AppBar başlığı ve
  // kimlik kartıyla birlikte üst üste üçüncü kez "mağaza / coinlerini
  // harca" diyordu ve ilk ürün ancak ekranın yarısından sonra başlıyordu.
  // Şerit kaldırıldı; karşılamayı kimlik kartının alt başlığı taşır.
  // Maskot onboarding, liderlik ve boş durumlarda görünmeye devam eder.
  testWidgets('mağaza başlığı tek karşılama gösterir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shop-mascot-header')), findsNothing);
    expect(find.text('Mağaza'), findsOneWidget);
  });

  testWidgets('bakiye 0 iken earn-coin CTA 390x844 ekranda taşmadan çizilir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _ShopRepository(coins: 0);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shop-earn-coin-cta')), findsOneWidget);
    // Overflow olsaydı framework exception fırlatırdı.
    expect(tester.takeException(), isNull);
  });

  testWidgets('mağaza yükleme hatası görünür ve bakiye yeniden yüklenir', (
    tester,
  ) async {
    final repository = _RetryableShopRepository();
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-state')), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.text('500 jeton'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ağ yoksa mağaza bağlamsal çevrimdışı durumu gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(ShopScreen(repository: _OfflineShopRepository())),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Mağaza çevrimdışı'), findsOneWidget);
    expect(
      find.text('Mağaza verileri için internet bağlantısı gerekiyor.'),
      findsOneWidget,
    );
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Bakiye yeterli görünürken sunucunun harcamayı reddettiği senaryo
/// (ör. eşzamanlı harcama sonrası sunucu bakiyesi düşmüş olabilir).
class _FailingSpendRepository extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 500;

  @override
  Future<bool> spendCoins(int amount, String reason) async => false;

  @override
  Future<bool> hasPurchased(String itemId) async => false;
}

class _RetryableShopRepository extends MockZanKurdRepository {
  bool fail = true;
  int loadCalls = 0;

  @override
  Future<int> loadCoinBalance() async {
    loadCalls += 1;
    if (fail) throw StateError('shop unavailable');
    return 500;
  }

  @override
  Future<bool> hasPurchased(String itemId) async => false;
}

class _OfflineShopRepository extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async {
    throw StateError('network unavailable');
  }
}
