import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// "Jeton yetmiyor" kapıları: tek desen (A5, 2026-10-01 tasarım denetimi).
///
/// ## Kusur
///
/// Jetonla geçilen kapılar yetmeyen bakiyeyi üç ayrı, üçü de yetersiz
/// biçimde ele alıyordu:
///
/// * **Mağaza kartı** etkin görünen bir fiyat düğmesi gösteriyordu; dokununca
///   açılan onay penceresi pasif (gri) bir "Satın al" ve ayrıca ikincil bir
///   "Jeton kazan" sunuyordu. Yani birincil eylem ölüydü, gerçek sonraki adım
///   ikincil düğmeye saklanmıştı; eksik miktar hiçbir yerde yazmıyordu.
/// * **Oda kurma sayfası** katılım ücretine yetmediğinde "Jetonun yetmiyor"
///   yazıp "Odayı aç" düğmesini pasif bırakıyordu: ölü düğme, çıkış yok.
/// * **Ücretli odaya kodla katılma** bakiye yetmediğinde sunucudan
///   `Insufficient coins for room entry fee` alıyordu; istemci bunu tanımayıp
///   `unknown`a düşürüyor, oyuncu "Odaya katılamadın. Tekrar dene." görüyordu.
///   Tekrar denemek sonucu değiştirmez; mesaj yanlış yönlendiriyordu. Aynı
///   iki hata "Yeni oda" (ücretli odanın tekrarı) için de geçerliydi.
///
/// ## Niçin sessiz kaldı
///
/// Üçünün de mevcut testleri "yanlış bir şey olmadı" diye bakıyordu (coin
/// harcanmadı, sayfa açıldı) ve pasif düğmeyi DOĞRU davranış diye sabitliyordu
/// (`shop_screen_test`: `buyButton.onPressed, isNull`). Yani kusur bir test
/// tarafından savunuluyordu. Ölçülmeyen şey, oyuncunun o anda NE görüp NE
/// yapabildiğiydi: eksik miktar ve gerçek bir sonraki adım.
///
/// ## Kural
///
/// Jeton yetmiyorsa: (1) eksik miktar yazılır (`SahneShortfallNote` /
/// `SahnePriceChip`), (2) birincil eylem pasif bırakılmaz, YERİNE jeton
/// kazanma yolu (günlük çark) gelir, (3) sunucunun yetersiz-bakiye reddi
/// genel bir hataya çevrilmez.
class _Repo extends MockZanKurdRepository {
  _Repo(this.coins);
  int coins;

  @override
  Future<int> loadCoinBalance() async => coins;

  @override
  Future<bool> canSpinToday() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('coinShortfall eksik miktardır, hiçbir zaman eksi değil', () {
    expect(coinShortfall(cost: 120, balance: 50), 70);
    expect(coinShortfall(cost: 120, balance: 120), 0);
    expect(coinShortfall(cost: 120, balance: 500), 0);
    expect(coinShortfall(cost: 0, balance: 0), 0);
  });

  test('sunucunun yetersiz-bakiye reddi tanınır ve genel hataya düşmez', () {
    final reason = roomJoinFailureReasonForMessage(
      'Insufficient coins for room entry fee',
    );
    expect(reason, RoomJoinFailureReason.insufficientCoins);
    expect(
      joinRoomErrorKey(RoomJoinException(reason)),
      K.insufficientCoins,
      reason: '"Tekrar dene" diyen genel mesaj yanlış yönlendirir.',
    );
    expect(
      roomJoinFailureReasonForMessage('Not authenticated'),
      RoomJoinFailureReason.unknown,
    );
  });

  test('"N jeton eksik" iki dilde miktarı taşır', () {
    expect(Tr.of(K.coinsShort, AppLanguage.tr), contains('{coins}'));
    expect(Tr.of(K.coinsShort, AppLanguage.ku), contains('{coins}'));
  });

  group('mağaza', () {
    Future<void> pumpShop(WidgetTester tester, int coins) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(child: ShopScreen(repository: _Repo(coins))),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('yetmeyen ürün düğme değil, eksik miktarlı durum çipi taşır', (
      tester,
    ) async {
      await pumpShop(tester, 200);

      // 120 jetonluk ürüne 200 yeter: gerçek satın alma düğmesi.
      final affordable = find.byKey(
        const ValueKey('shop-item-surface-spin_wheel_extra'),
      );
      expect(
        find.descendant(of: affordable, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('shop-short-spin_wheel_extra')),
        findsNothing,
      );

      // 480 ve 350 jetonluk çerçeveler ve 720'lik rozet yetmiyor.
      for (final (id, cost) in [
        ('avatar_frame_gold', 480),
        ('avatar_frame_neon', 350),
        ('profile_badge_vip', 720),
      ]) {
        final chip = find.byKey(ValueKey('shop-short-$id'));
        expect(chip, findsOneWidget, reason: '$id yetmiyor ama çip yok');
        expect(find.text('${cost - 200} jeton eksik'), findsOneWidget);
        expect(
          find.descendant(
            of: find.ancestor(
              of: chip,
              matching: find.byType(SahneSurfaceCard),
            ),
            matching: find.byType(FilledButton),
          ),
          findsNothing,
          reason: '$id için etkin görünen bir satın alma düğmesi kalmış',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'yetmeyen ürünün penceresinde pasif "Satın al" yok, "Jeton kazan" birincil',
      (tester) async {
        await pumpShop(tester, 50);

        await tester.tap(
          find.byKey(const ValueKey('shop-item-surface-spin_wheel_extra')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Satın al'), findsNothing);
        expect(
          find.byKey(const ValueKey('shop-dialog-shortfall')),
          findsOneWidget,
        );
        final earn = find.byKey(const ValueKey('shop-dialog-earn-coins'));
        expect(earn, findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.descendant(of: earn, matching: find.byType(FilledButton)),
              )
              .onPressed,
          isNotNull,
          reason: 'Birincil eylem ölü olmamalı.',
        );

        await tester.tap(earn);
        await tester.pumpAndSettle();
        expect(find.byType(SpinWheelScreen), findsOneWidget);
      },
    );

    testWidgets('yeten ürünün penceresi bugünkü gibi "Satın al" sunar', (
      tester,
    ) async {
      await pumpShop(tester, 500);
      await tester.tap(
        find.byKey(const ValueKey('shop-item-surface-spin_wheel_extra')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Satın al'), findsOneWidget);
      expect(find.byKey(const ValueKey('shop-dialog-shortfall')), findsNothing);
    });

    testWidgets('en büyük yazıda durum çipi hücreden taşmaz', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          child: ShopScreen(repository: _Repo(0)),
          languageProvider: kurmanciLang(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('oda kurma', () {
    Future<void> openSheet(WidgetTester tester, int coins) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(child: PlayHubScreen(repository: _Repo(coins))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
      await tester.pumpAndSettle();
    }

    testWidgets('ücrete yetmeyince eksik miktar yazar, "Odayı aç" yerine '
        '"Jeton kazan" gelir', (tester) async {
      await openSheet(tester, 10);

      // Ücretsiz seçenek varsayılan: oda açılabilir.
      expect(find.byKey(const ValueKey('custom-room-open')), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-room-shortfall')), findsNothing);

      final fee = find.byKey(const ValueKey('custom-room-fee-25'));
      await tester.ensureVisible(fee);
      await tester.tap(fee);
      await tester.pumpAndSettle();

      expect(find.text('15 jeton eksik'), findsOneWidget);
      expect(find.byKey(const ValueKey('custom-room-open')), findsNothing);
      final earn = find.byKey(const ValueKey('custom-room-earn-coins'));
      expect(earn, findsOneWidget);
      await tester.ensureVisible(earn);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(of: earn, matching: find.byType(FilledButton)),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(earn);
      await tester.pumpAndSettle();
      expect(find.byType(SpinWheelScreen), findsOneWidget);
    });
  });

  group('ücretli odanın tekrarı', () {
    Widget result(_Repo repository) => QuizResultScreen(
      repository: repository,
      room: const GameRoom(
        id: 'room-1v1-online',
        name: '1vs1',
        code: 'ZK-WINNER01',
        category: 'Ziman',
        players: [
          Player(id: 'user', name: 'Ez', score: 320, state: Player.readyState),
          Player(
            id: 'opp',
            name: 'Rojda',
            score: 180,
            state: Player.readyState,
          ),
        ],
        status: RoomStatus.finished,
        questionCount: 5,
        entryFee: 25,
      ),
      score: 320,
      correctCount: 4,
      wrongCount: 1,
      totalQuestions: 5,
      bestStreak: 3,
      coinsAwarded: 0,
      opponents: const [
        Player(id: 'opp', name: 'Rojda', score: 180, state: Player.readyState),
      ],
      answerRecords: const [],
    );

    testWidgets(
      'bakiye yetmiyorsa onay sorulmaz, eksik miktar ve çark sunulur',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(testShell(child: result(_Repo(10))));
        await tester.pump(const Duration(milliseconds: 600));

        final action = find.byKey(const ValueKey('result-new-room-button'));
        await tester.scrollUntilVisible(
          action,
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(action);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('result-new-room-shortfall')),
          findsOneWidget,
        );
        expect(find.text('15 jeton eksik'), findsOneWidget);
        // "Ücret düşecek, devam?" onayı hiç sorulmaz.
        expect(
          find.text(Tr.of(K.continueAction, AppLanguage.tr)),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey('result-new-room-earn-coins')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SpinWheelScreen), findsOneWidget);
      },
    );
  });
}
