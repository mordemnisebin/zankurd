// Tasarım kurulu tüm ekranlar 2026-10-20: mağaza kartı = ikon, ad, açıklama,
// fiyat düğmesi; VIP aynı çerçeve; yetmeyen ürün ortak pasif düğme.
// 2026-10-19 sadeleşme: "sakin yüzey" bekçisi yuvarlak köşeli yüzey
// kartını (`OutlinedBorder`) kabul eder; eskiden pahlı şekle cast ediyordu.
// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
// 2026-09-29 doğallık (G3): fiyat etiketi "120j" değil "120" (birimi jeton
// glifi söyler, K10); ürün adları cümle düzeninde ("Neon çerçeve"). Bu
// beklentiler yalnız eski yazımı sabitliyordu; davranış aynı.
import 'dart:async';

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
import 'package:zankurd_mobile/src/widgets/shop_showcase.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';
import 'package:zankurd_mobile/src/data/joker_stock_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';

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

  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
  }) async {
    if (coins < 50) {
      return const StreakFreezeChargeResult(
        outcome: StreakFreezeChargeOutcome.insufficient,
        idempotent: true,
      );
    }
    coins -= 50;
    spendReasons.add('streak_freeze');
    return const StreakFreezeChargeResult(
      outcome: StreakFreezeChargeOutcome.charged,
      idempotent: true,
    );
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

class _SlowChargeRepository extends _FailingEffectShopRepository {
  final gate = Completer<void>();

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    await gate.future;
    return super.spendCoins(amount, reason);
  }
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
  // 2026-10-28 tur 2 R6: "Çevir" alt perdede sabittir (çark ekranı iç
  // kaydırmalı ve dikey ortalı); aşağı kaydırmaya gerek yok.
  await tester.tap(find.text('Çevir'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  // 2026-09-29 Şahnê: çark sayfası B iskeletidir; geri düğmesi bileşenin
  // 44'lük plakası, sözü uygulamanın dilinden ('Geri').
  await tester.tap(find.byTooltip('Geri'));
  await tester.pumpAndSettle();
}

/// Üst çubuktaki bakiye çipi (2026-10-28 tur 3 T11: oyun merkezi ve profildeki
/// nötr kapsülle aynı; yalnız sayı, birim ekran okuyucuda).
Finder _balance(String amount) => find.descendant(
  of: find.byKey(const ValueKey('shop-coin-chip')),
  matching: find.text(amount),
);

void main() {
  // Neon/altın çerçeve satın alma `loadAvatarIdentity`/`updateAvatarIdentity`
  // üzerinden `SharedPreferences`e dokunur; mock'lanmazsa platform kanalı
  // hiç yanıt vermediği için widget testi sonsuza kadar asılı kalır.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StreakStore.resetInstance();
  });

  // Codex denetimi 2026-10-29 (hata #2): tahsilat beklenirken ekrandan
  // çıkılırsa `!mounted` erken dönüşü ürün etkisini atlıyor, jeton gidip
  // çerçeve gelmiyordu. Etki artık ekrandan bağımsız uygulanır.
  testWidgets('tahsilat beklenirken ekrandan çıkılsa da çerçeve uygulanır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _SlowChargeRepository()..failEffect = false;
    final visible = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      _shell(
        ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, show, _) =>
              show ? ShopScreen(repository: repository) : const Scaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Neon çerçeve'));
    await tester.tap(find.text('Neon çerçeve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın al'));
    await tester.pump();
    visible.value = false;
    await tester.pump();
    repository.gate.complete();
    await tester.pumpAndSettle();
    expect(repository.spendReasons, ['purchase_avatar_frame_neon']);
    expect(repository.identity.frameId, 'neon');
  });

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
    // 2026-10-27: joker paketi ve üç yeni çerçeve gerçekten teslim
    // ediliyor (JokerStockStore, AvatarFrame.kilim/newroz/sev).
    expect(debugShopItems.map((item) => item.id).toSet(), {
      'spin_wheel_extra',
      'avatar_frame_gold',
      'avatar_frame_neon',
      'profile_badge_vip',
      'joker_pack_3',
      'avatar_frame_kilim',
      'avatar_frame_newroz',
      'avatar_frame_sev',
    });
  });

  testWidgets('mağaza ürün rengini büyük yüzeylere taşımadan sakin kalır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    // 2026-10-29 son kurul: güçlendiricilere işlev satırı eklendi; VIP
    // kartı 844'te tembel listenin dışında kalıyordu.
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
              // 2026-10-29 vay 2B (B9): ürün önizlemesinin arkasındaki 88 px
              // ışık diski (ShopPreviewStage) bilerek degradelidir — ürün
              // rengi yalnız o küçük diskte; kartın yüzeyi yine sakin.
              final inStage = find
                  .ancestor(
                    of: find.byWidget(e.widget),
                    matching: find.byType(ShopPreviewStage),
                  )
                  .evaluate()
                  .isNotEmpty;
              final d = (e.widget as DecoratedBox).decoration;
              return !inStage &&
                  d is BoxDecoration &&
                  (d.gradient != null || (d.boxShadow?.isNotEmpty ?? false));
            }),
        isEmpty,
      );
    }

    expectCalmSurface(
      find.byKey(const ValueKey('shop-item-surface-profile_badge_vip')),
    );
    expectCalmSurface(
      find.byKey(const ValueKey('shop-item-surface-spin_wheel_extra')),
    );
    expect(
      find.byKey(const ValueKey('shop-item-accent-stripe-spin_wheel_extra')),
      findsNothing,
      reason: 'Ürün rengi tam genişlik dekor şeridine dönüşmemeli.',
    );
  });

  // (2026-10-28 tur 2 R7: alınabilir fiyat artık Zêr/altın dolgu.)
  // Kurul 2. tur 2026-10-20: alınabilir fiyat = turuncu çerçeveli açık düğme
  // (hero dahil); pasif düğme gri dolgu + kilit. İkisi bir bakışta ayrılır;
  // eskiden alınabilir olan da gri dolguydu ve pasif görünüyordu.
  testWidgets(
    'alınabilir fiyat turuncu çerçeveli, yetmeyen gri dolgulu ve kilitli',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      // 2026-10-29 son kurul: güçlendiricilere işlev satırı eklendi; VIP
      // kartı 844'te tembel listenin dışında kalıyordu.
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
      // 2026-10-28 tur 3 T16: fiyat düğmesi dolu altın değil, altın çerçeveli
      // TONLU çip (açık altın zemin + altın kenar + jeton + sayı); turuncu
      // yalnız ana akışın tek birincil eylemidir.
      final bg = filled.style!.backgroundColor!.resolve(<WidgetState>{})!;
      expect(bg, t.goldTint, reason: 'fiyat çipi tonlu altın zemin');
      expect(bg, isNot(t.act), reason: 'fiyat düğmesi turuncu olmamalı');
      expect(bg, isNot(t.zerBand), reason: 'dolu altın değil');
      expect(
        filled.style!.side!.resolve(<WidgetState>{})!.color,
        t.gold,
        reason: 'altın çerçeve',
      );
      expect(filled.style!.foregroundColor!.resolve(<WidgetState>{}), t.goldTx);

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
      // 2026-10-28 K11: ayrı "N jeton eksik" satırı KALKTI (hap de kartın
      // başka yerinde de); miktar yalnız ekran okuyucu etiketinde ve
      // pencerede yaşar. Hap aynı sabit boydadır ve tutarı gösterir.
      expect(
        find.descendant(of: short, matching: find.text('720')),
        findsOneWidget,
      );
      expect(find.textContaining('jeton eksik'), findsNothing);
      expect(
        find.byKey(const ValueKey('shop-short-note-profile_badge_vip')),
        findsNothing,
      );
      expect(
        tester.getSize(short).height,
        tester.getSize(affordable).height,
        reason: 'hap ile düğme aynı yükseklikte',
      );
    },
  );

  testWidgets('VIP kartı yatay ve kompakt (eskiden ~490 mp)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    // 2026-10-29 son kurul: güçlendiricilere işlev satırı eklendi; VIP
    // kartı 844'te tembel listenin dışında kalıyordu.
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(ShopScreen(repository: _ShopRepository(coins: 1000))),
    );
    await tester.pumpAndSettle();
    final hero = tester.getSize(
      find.byKey(const ValueKey('shop-item-surface-profile_badge_vip')),
    );
    // Tur 6: Kurmancî olmayan Türkçe açıklama dar sütunda 3 satıra iner;
    // kart yine kompakt (eskiden ~490 mp). 2026-10-29 vay 2B (B9): önizleme
    // 52 → 88 px ışık diski + gölge (Astra: "önizlemeler çok küçük"); tavan
    // 230 → 250, ~490'dan hâlâ çok uzak.
    expect(hero.height, lessThanOrEqualTo(250));
  });

  // 2026-10-28 K11 (eski Tur 6 "hepsi aynı tam genişlik satır" kararı geçersiz):
  // Güçlendiriciler tam genişlik satırlar, çerçeve ve rozet iki sütunlu
  // ızgara karolarıdır; gruplar alt alta, başlıklarıyla.
  testWidgets('güçlendiriciler tam genişlik satır, çerçeveler 2 sütun ızgara', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(ShopScreen(repository: _ShopRepository(coins: 300))),
    );
    await tester.pumpAndSettle();
    Rect r(String id) =>
        tester.getRect(find.byKey(ValueKey('shop-item-surface-$id')));
    final wheel = r('spin_wheel_extra');
    final joker = r('joker_pack_3');
    // Ucuzdan pahalıya: dondurma 50, joker 90, ekstra çevirme 120.
    expect(joker.width, wheel.width);
    expect(wheel.top, greaterThan(joker.bottom - 1));
    final boosters = find.byKey(const ValueKey('shop-group-boosters'));
    final looks = find.byKey(const ValueKey('shop-group-looks'));
    expect(boosters, findsOneWidget);
    expect(looks, findsOneWidget);
    expect(tester.getRect(looks).top, greaterThan(wheel.bottom - 1));
    final neon = r('avatar_frame_neon');
    final gold = r('avatar_frame_kilim'); // (kilim, neon) aynı satır
    expect(neon.width, lessThan(wheel.width * 0.6), reason: 'yarım genişlik');
    expect(neon.top, gold.top, reason: 'ikisi aynı satırda');
    expect(neon.left, isNot(gold.left));
    expect(neon.top, greaterThan(tester.getRect(looks).bottom - 1));
  });

  // 2026-10-28 tur 3 T11: bakiye çipi oyun merkezi ve profildekiyle aynı nötr
  // kapsül (altın jeton glifi); koyu kahve dolgulu ayrı bir çip değil.
  testWidgets('T11: bakiye çipi nötr stat çipi (dolgu rengi yok)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(ShopScreen(repository: _ShopRepository(coins: 500))),
    );
    await tester.pumpAndSettle();
    final chip = tester.widget<SahneStatChip>(
      find.descendant(
        of: find.byKey(const ValueKey('shop-coin-chip')),
        matching: find.byType(SahneStatChip),
      ),
    );
    expect(chip.tint, isNull);
    expect(chip.foreground, isNull);
  });

  testWidgets('mağaza bakiyeyi ve ürünleri listeler', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(_balance('500'), findsOneWidget);
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
    expect(_balance('0'), findsOneWidget);
    await _spinAndReturn(tester, repository, 'shop-spin-wheel-entry');

    expect(_balance('30'), findsOneWidget);
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
    expect(_balance('30'), findsOneWidget);
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
    // R6 (2026-10-28 tur 2): "Çevir" alt perdede sabit; kaydırma gerekmez.
    await tester.tap(find.text('Çevir'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    // 2026-09-29 Şahnê: çark sayfası B iskeletidir; geri düğmesi bileşenin
    // 44'lük plakası, sözü uygulamanın dilinden ('Geri').
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();

    expect(_balance('30'), findsOneWidget);
  });

  testWidgets(
    'kart açıklamayı göstermez, ürüne dokununca onay penceresi açıklamayı gösterir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ShopRepository(coins: 500);
      await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
      await tester.pumpAndSettle();

      const description = 'Bugün çarkı tekrar çevirmek için ekstra hak verir.';
      // AZ SÖZ 2026-10-20: kart yalnız ikon, ad ve fiyat/eylem taşır;
      // açıklama yalnız onay penceresinde okunur.
      expect(find.text(description), findsNothing);
      await tester.ensureVisible(find.text('Ekstra çevirme'));
      await tester.tap(find.text('Ekstra çevirme'));
      await tester.pumpAndSettle();
      expect(find.text(description), findsOneWidget);
      expect(find.text('Satın al'), findsOneWidget);
    },
  );

  // 2026-10-28 K11: eski Tur 10b düzeni ("metin tam genişlik, eylem altta")
  // geçersiz; satır = ikon + ad + SAĞDA sabit boyutlu fiyat düğmesi.
  testWidgets('mağaza satırı: ad solda, sabit boy fiyat düğmesi sağda', (
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
    final buy = find.byKey(const ValueKey('shop-buy-spin_wheel_extra'));
    final cardRect = tester.getRect(card);
    expect(
      tester.getSize(title).height,
      lessThan(52),
      reason: 'en çok iki satır',
    );
    expect(
      tester.getRect(title).right,
      lessThanOrEqualTo(tester.getRect(buy).left),
    );
    expect(tester.getRect(buy).right, greaterThan(cardRect.right - 20));
    expect(tester.getSize(buy).height, inInclusiveRange(44, 56));
    // Kilitli fiyat hapı aynı sabit genişlikte (ürünler arası hizalı).
    final joker = find.byKey(const ValueKey('shop-short-joker_pack_3'));
    if (joker.evaluate().isNotEmpty) {
      expect(tester.getSize(joker).width, tester.getSize(buy).width);
    }
    final locked = find.byKey(const ValueKey('shop-short-profile_badge_vip'));
    expect(tester.getSize(locked).height, tester.getSize(buy).height);
  });

  testWidgets('satın alma eylemleri düz ve gölgesizdir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    final buy = find.byKey(const ValueKey('shop-buy-spin_wheel_extra'));
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.descendant(of: buy, matching: find.byType(FilledButton)),
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

    final buy = find.byKey(const ValueKey('shop-buy-spin_wheel_extra'));
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    await tester.tap(buy);
    await tester.pumpAndSettle();
    // Confirm dialog: tap "Satın al"
    await tester.tap(find.text('Satın al'));
    await tester.pumpAndSettle();

    expect(repository.spendReasons, ['purchase_spin_wheel_extra']);
    // 500 - 120 (yeni ekstra çevirme fiyatı) = 380
    expect(repository.coins, 380);
    expect(_balance('380'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alınmış ürün "Alındı" görünür ve tekrar alınamaz', (
    tester,
  ) async {
    // 2026-10-27: dokuz ürünle çerçeveler listenin altında; hepsi görünsün.
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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

    expect(
      find.byKey(const ValueKey('shop-buy-spin_wheel_extra')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('spendCoins başarısız dönerse hata mesajı gösterilir', (
    tester,
  ) async {
    final repository = _FailingSpendRepository();
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    final buy = find.byKey(const ValueKey('shop-buy-spin_wheel_extra'));
    await tester.ensureVisible(buy);
    await tester.pumpAndSettle();
    await tester.tap(buy);
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
      'joker_pack_3': 90,
      'avatar_frame_kilim': 300,
      'avatar_frame_newroz': 400,
      'avatar_frame_sev': 500,
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
    expect(_balance('500'), findsOneWidget);
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
  // ── 2026-10-27 mağaza genişlemesi ────────────────────────────────────────
  //
  // Bekçi: yeni çerçeveler alınınca gerçekten kuşanılır; joker paketi üç
  // hakkı stoğa yazar (tekrar alınabilir); seri dondurma kartı eldeki
  // miktarı söyler ve alınca StreakStore'a bir dondurma ekler.
  for (final (title, frameId) in const [
    ('Kilim çerçeve', 'kilim'),
    ('Newroz çerçeve', 'newroz'),
    ('Gece çerçeve', 'sev'),
  ]) {
    testWidgets('$title alınınca kuşanılır ($frameId)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _ShopRepository(coins: 1000);
      await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(title));
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satın al'));
      await tester.pumpAndSettle();

      expect((await repository.loadAvatarIdentity()).frameId, frameId);
    });
  }

  testWidgets('joker paketi üç hakkı stoğa yazar ve yeniden alınabilir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 1000);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Joker paketi (3)'));
      await tester.tap(find.text('Joker paketi (3)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satın al'));
      await tester.pumpAndSettle();
      // Kutlama penceresini kapat.
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
    }

    expect(await JokerStockStore.count(), 6);
    expect(
      repository.spendReasons.where((r) => r == 'purchase_joker_pack_3'),
      hasLength(2),
    );
  });

  testWidgets('seri dondurma kartı eldekini söyler; alınınca stoğa eklenir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 1000);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Elinde: 0/2'), findsOneWidget);
    await tester.ensureVisible(find.text('Seri dondurma'));
    await tester.tap(find.text('Seri dondurma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın al'));
    await tester.pumpAndSettle();

    expect((await StreakStore.load()).freezeCount, 1);
  });

  // Codex denetimi 2026-10-29 (hata #2): tahsilat beklenirken ekrandan
  // çıkılırsa `!mounted` dondurma hakkını atlıyor, jeton gidiyordu; yanıtı
  // kaybolan denemenin tekrarı da yeni anahtar üretip ikinci kez çekiyordu.
  testWidgets('dondurma: ekrandan çıkılsa da hak teslim edilir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _SlowFreezeRepository();
    final visible = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      _shell(
        ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, show, _) =>
              show ? ShopScreen(repository: repository) : const Scaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Seri dondurma'));
    await tester.tap(find.text('Seri dondurma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Satın al'));
    await tester.pump();
    visible.value = false;
    await tester.pump();
    repository.gate.complete();
    await tester.pumpAndSettle();
    expect((await StreakStore.load()).freezeCount, 1);
  });

  testWidgets('dondurma: belirsiz hatadan sonra aynı idempotency anahtarı', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _SlowFreezeRepository()..failFirst = true;
    repository.gate.complete();
    final visible = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      _shell(
        ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, show, _) =>
              show ? ShopScreen(repository: repository) : const Scaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Seri dondurma'));
      await tester.tap(find.text('Seri dondurma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satın al'));
      await tester.pumpAndSettle();
      // Ekrandan çıkıp yeniden girilir (belirsiz hata ekranı kapanır).
      visible.value = false;
      await tester.pump();
      visible.value = true;
      await tester.pumpAndSettle();
    }
    expect(repository.keys.length, greaterThanOrEqualTo(2));
    expect(repository.keys.toSet(), hasLength(1));
  });
}

class _SlowFreezeRepository extends _ShopRepository {
  _SlowFreezeRepository() : super(coins: 1000);
  final gate = Completer<void>();
  final keys = <String>[];
  bool failFirst = false;

  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    await gate.future;
    if (failFirst && keys.length == 1) throw StateError('yanıt kayboldu');
    return super.spendStreakFreeze(idempotencyKey: idempotencyKey);
  }
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
