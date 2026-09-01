import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/widget_test_helpers.dart';

class _CapturingRepository extends MockZanKurdRepository {
  int? capturedSeconds;
  int? capturedQuestionCount;
  int? capturedEntryFee;
  String? capturedCategory;

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
    int questionCount = 10,
    int entryFee = 0,
  }) async {
    capturedCategory = category;
    capturedSeconds = secondsPerQuestion;
    capturedQuestionCount = questionCount;
    capturedEntryFee = entryFee;
    return super.createOnlineRoom(
      category: category,
      secondsPerQuestion: secondsPerQuestion,
      questionCount: questionCount,
      entryFee: entryFee,
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

      await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
      await tester.pumpAndSettle();

      expect(find.text('Dil'), findsOneWidget);
      expect(find.text('Kültür'), findsOneWidget);
      expect(find.text('Tarih'), findsOneWidget);
      expect(find.text('Ziman'), findsNothing);
      expect(find.text('Çand'), findsNothing);
      expect(find.text('Dîrok'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('custom-room-cat-Dîrok')),
      );
      await tester.pump();

      final openButton = find.text('Odayı Aç');
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

      await tester.tap(find.text('Oda Kur'));
      await tester.pumpAndSettle();

      // Süre seçimi (20 sn varsayılan; 30 sn seçelim)
      expect(find.text('20 sn'), findsOneWidget);
      await tester.tap(find.text('30 sn'));
      await tester.pumpAndSettle();

      // Soru sayısı seçimi (5 soru seçelim)
      expect(find.text('5 soru'), findsOneWidget);
      await tester.tap(find.text('5 soru'));
      await tester.pumpAndSettle();

      // Sayfa `SingleChildScrollView`; kategori/soru/süre/bahis satırları
      // eklendikten sonra onay düğmesi görünür alanın altında kalıyor.
      // `ensureVisible` olmadan `tap` sessizce boşa düşüyordu — istisna
      // yok, çağrı da yok. Aradaki `pump` şart: bu depoda bir kez
      // kaydırma tamamlanmadan dokunulup eski konuma vurulmuştu.
      final openButton = find.text('Odayı Aç');
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

    await tester.tap(find.text('Oda Kur'));
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

    await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await tester.pumpAndSettle();

    for (final seconds in GameRoom.allowedDurations) {
      expect(find.text('$seconds çirke'), findsOneWidget);
      expect(find.text('$seconds sn'), findsNothing);
    }
  });
}
