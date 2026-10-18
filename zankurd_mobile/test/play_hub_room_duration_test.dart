// 2026-10-19 sadeleşme (ikinci tur): oda kurma çipleri Material ChoiceChip/FilterChip yerine `SahnePickChip` (seçili = dolu renk, değilse çerçeve; eşit sütunlu ızgara);
// bekçiler `.selected` alanını yeni bileşenden okur, davranış (çoklu seçim, Karışık, gönderilen değerler) aynı.
// 2026-10-19 son rötuş: çipler tek satır ("Bilim ve Düşünce" iki satıra sarıp satırı uzatıyordu); büyük yazıda iki satıra izin var ama aynı satırdaki çipler eşit boyda; alt çubuğun üstünde ayraç var.
// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

class _CapturingRepository extends MockZanKurdRepository {
  int? capturedSeconds;
  int? capturedQuestionCount;
  int? capturedEntryFee;
  int? capturedMaxPlayers;
  String? capturedCategory;

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
    int questionCount = 10,
    int entryFee = 0,
    int maxPlayers = 2,
  }) async {
    capturedCategory = category;
    capturedSeconds = secondsPerQuestion;
    capturedQuestionCount = questionCount;
    capturedEntryFee = entryFee;
    capturedMaxPlayers = maxPlayers;
    return super.createOnlineRoom(
      category: category,
      secondsPerQuestion: secondsPerQuestion,
      questionCount: questionCount,
      entryFee: entryFee,
      maxPlayers: maxPlayers,
    );
  }
}

void main() {
  testWidgets(
    'Türkçe oda kurucusu kategori etiketlerini yerelleştirir ama ham kimliği gönderir',
    (tester) async {
      final repository = _CapturingRepository();
      await tester.pumpWidget(
        testShell(child: PlayHubScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('play-hub-create-room')),

        200,
      );

      await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
      await tester.pumpAndSettle();

      expect(find.text('Dil'), findsOneWidget);
      expect(find.text('Kültür'), findsOneWidget);
      expect(find.text('Tarih'), findsOneWidget);
      expect(find.text('Ziman'), findsNothing);
      expect(find.text('Çand'), findsNothing);
      expect(find.text('Dîrok'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('custom-room-cat-Dîrok')));
      await tester.pump();

      final openButton = find.text('Odayı aç');
      await tester.ensureVisible(openButton);
      await tester.pump();
      await tester.tap(openButton);
      await tester.pumpAndSettle();

      expect(repository.capturedCategory, 'Dîrok');
    },
  );

  testWidgets(
    'oda kurucusu kategori, soru sayısı, süre ve giriş ücretini seçebilir ve seçim odaya uygulanır',
    (tester) async {
      final repository = _CapturingRepository();
      await tester.pumpWidget(
        testShell(child: PlayHubScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Oda kur'), 200);

      await tester.tap(find.text('Oda kur'));
      await tester.pumpAndSettle();

      // Süre seçimi (20 sn varsayılan; 30 sn seçelim)
      expect(find.text('20 sn'), findsOneWidget);
      await tester.ensureVisible(find.text('30 sn'));
      await tester.pump();
      await tester.tap(find.text('30 sn'));
      await tester.pumpAndSettle();

      // Soru sayısı seçimi (5 soru seçelim)
      expect(find.text('5 soru'), findsOneWidget);
      await tester.ensureVisible(find.text('5 soru'));
      await tester.pump();
      await tester.tap(find.text('5 soru'));
      await tester.pumpAndSettle();

      // Sayfa `SingleChildScrollView`; kategori/soru/süre/bahis satırları
      // eklendikten sonra onay düğmesi görünür alanın altında kalıyor.
      // `ensureVisible` olmadan `tap` sessizce boşa düşüyordu — istisna
      // yok, çağrı da yok. Aradaki `pump` şart: bu depoda bir kez
      // kaydırma tamamlanmadan dokunulup eski konuma vurulmuştu.
      final openButton = find.text('Odayı aç');
      await tester.ensureVisible(openButton);
      await tester.pump();
      await tester.tap(openButton);
      await tester.pumpAndSettle();

      expect(repository.capturedSeconds, 30);
      expect(repository.capturedQuestionCount, 5);
      expect(repository.capturedEntryFee, 0);
    },
  );

  testWidgets('süre seçenekleri modelin izinli kümesiyle birebir aynı', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Oda kur'), 200);

    await tester.tap(find.text('Oda kur'));
    await tester.pumpAndSettle();

    for (final seconds in GameRoom.allowedDurations) {
      expect(
        find.text('$seconds sn'),
        findsOneWidget,
        reason: '$seconds sn seçeneği eksik',
      );
    }
  });

  testWidgets('Kurmancî arayüzde süre birimi "çirke" olur, "sn" değil', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: PlayHubScreen(repository: MockZanKurdRepository()),
        languageProvider: kurmanciLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-create-room')),

      200,
    );

    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();

    for (final seconds in GameRoom.allowedDurations) {
      expect(find.text('$seconds çirke'), findsOneWidget);
      expect(find.text('$seconds sn'), findsNothing);
    }
  });

  Future<void> openCreateSheet(
    WidgetTester tester,
    _CapturingRepository repository,
  ) async {
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-create-room')),
      200,
    );
    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();
  }

  testWidgets('oda kurma: konu çipi karo adını yazar, anlamsal ad tam kalır; '
      'kaydırma alanı altında solma var', (tester) async {
    final handle = tester.ensureSemantics();
    await openCreateSheet(tester, _CapturingRepository());
    final chip = find.byKey(const ValueKey('custom-room-cat-Paradigma'));
    if (chip.evaluate().isNotEmpty) {
      expect(
        find.descendant(of: chip, matching: find.text('Bilim')),
        findsOneWidget,
      );
      expect(tester.getSemantics(chip).label, 'Bilim ve Düşünce');
    }
    expect(
      find.byKey(const ValueKey('custom-room-bottom-fade')),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('oda kurma çipleri: aynı satırda eşit boy, normal yazıda 48 '
        '(yazı x$scale)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openCreateSheet(tester, _CapturingRepository());
      expect(
        find.byKey(const ValueKey('custom-room-footer-divider')),
        findsOneWidget,
      );
      final rows = <int, Set<double>>{};
      for (final e in find.byType(SahnePickChip).evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        rows.putIfAbsent(r.top.round(), () => {}).add(r.height);
        if (scale == 1.0) expect(r.height, 48, reason: 'tek satır, 48');
      }
      expect(rows, isNotEmpty);
      rows.forEach((top, heights) {
        expect(heights.length, 1, reason: 'satır $top: eşit boy olmalı');
      });
    });
  }

  testWidgets(
    'oyuncu sayısı çipleri izinli kümeyle aynı, varsayılan 8 seçili',
    (tester) async {
      await openCreateSheet(tester, _CapturingRepository());

      for (final capacity in GameRoom.allowedMaxPlayers) {
        expect(
          find.byKey(ValueKey('custom-room-capacity-$capacity')),
          findsOneWidget,
          reason: '$capacity kişilik seçenek eksik',
        );
      }
      final eight = tester.widget<SahnePickChip>(
        find.byKey(const ValueKey('custom-room-capacity-8')),
      );
      expect(eight.selected, isTrue);
      expect(find.text('Oyuncu sayısı'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('custom-room-capacity-hint')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'seçilen oyuncu sayısı createOnlineRoom\'a maxPlayers olarak gider',
    (tester) async {
      final repository = _CapturingRepository();
      await openCreateSheet(tester, repository);

      final chip = find.byKey(const ValueKey('custom-room-capacity-30'));
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final openButton = find.text('Odayı aç');
      await tester.ensureVisible(openButton);
      await tester.pump();
      await tester.tap(openButton);
      await tester.pumpAndSettle();

      expect(repository.capturedMaxPlayers, 30);
    },
  );

  testWidgets('2 kişi seçilince kalabalık ipucu kalkar ve kapasite 2 gider', (
    tester,
  ) async {
    final repository = _CapturingRepository();
    await openCreateSheet(tester, repository);

    final chip = find.byKey(const ValueKey('custom-room-capacity-2'));
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('custom-room-capacity-hint')),
      findsNothing,
    );

    final openButton = find.text('Odayı aç');
    await tester.ensureVisible(openButton);
    await tester.pump();
    await tester.tap(openButton);
    await tester.pumpAndSettle();

    expect(repository.capturedMaxPlayers, 2);
  });

  group('kategori seçimi: Karışık ve çoklu', () {
    Future<void> tapChip(WidgetTester tester, String key) async {
      final chip = find.byKey(ValueKey(key));
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    Future<void> open(WidgetTester tester) async {
      final openButton = find.text('Odayı aç');
      await tester.ensureVisible(openButton);
      await tester.pump();
      await tester.tap(openButton);
      await tester.pumpAndSettle();
    }

    testWidgets('varsayılan Karışık seçili ve Tevlihev gönderir', (
      tester,
    ) async {
      final repository = _CapturingRepository();
      await openCreateSheet(tester, repository);

      final mixed = tester.widget<SahnePickChip>(
        find.byKey(const ValueKey('custom-room-cat-mixed')),
      );
      expect(mixed.selected, isTrue);
      await open(tester);
      expect(repository.capturedCategory, 'Tevlihev');
    });

    testWidgets(
      'birden çok kategori seçilince Karışık kalkar, adlar birleşir',
      (tester) async {
        final repository = _CapturingRepository();
        await openCreateSheet(tester, repository);

        await tapChip(tester, 'custom-room-cat-Dîrok');
        await tapChip(tester, 'custom-room-cat-Ziman');
        final mixed = tester.widget<SahnePickChip>(
          find.byKey(const ValueKey('custom-room-cat-mixed')),
        );
        expect(mixed.selected, isFalse);
        await open(tester);
        expect(repository.capturedCategory, 'Dîrok, Ziman');
      },
    );

    testWidgets('Karışık seçilince tekil seçimler temizlenir', (tester) async {
      final repository = _CapturingRepository();
      await openCreateSheet(tester, repository);

      await tapChip(tester, 'custom-room-cat-Dîrok');
      await tapChip(tester, 'custom-room-cat-mixed');
      final dirok = tester.widget<SahnePickChip>(
        find.byKey(const ValueKey('custom-room-cat-Dîrok')),
      );
      expect(dirok.selected, isFalse);
      await open(tester);
      expect(repository.capturedCategory, 'Tevlihev');
    });

    testWidgets('son kategori kaldırılınca Karışık\'a döner (boş seçim yok)', (
      tester,
    ) async {
      final repository = _CapturingRepository();
      await openCreateSheet(tester, repository);

      await tapChip(tester, 'custom-room-cat-Dîrok');
      await tapChip(tester, 'custom-room-cat-Dîrok');
      final mixed = tester.widget<SahnePickChip>(
        find.byKey(const ValueKey('custom-room-cat-mixed')),
      );
      expect(mixed.selected, isTrue);
      await open(tester);
      expect(repository.capturedCategory, 'Tevlihev');
    });
  });
}
