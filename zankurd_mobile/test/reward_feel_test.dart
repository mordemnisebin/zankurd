/// Ödül ve rekabet anlarının HİSSEDİLMESİNİ koruyan bekçiler.
///
/// Uygulamanın ödül dili yazıyla anlatıyordu: skor birden beliriyor,
/// düelloda öndelik iki sayının farkını okumayı gerektiriyordu. İkisi de
/// doğru bilgi veriyordu ama hiçbir şey hissettirmiyordu (2026-08-19).
/// Buradaki testler o iki düzeltmenin sessizce geri alınmasını engeller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/rolling_count.dart';

void main() {
  group('halat çekme payı', () {
    test('berabere başlangıçta tam ortada durur', () {
      expect(duelTugShare(0, 0), 0.5);
    });

    test('öndelik oranla gösterilir', () {
      expect(duelTugShare(30, 10), closeTo(0.75, 0.001));
    });

    test('ezici sonuçta bile kaybedene şerit kalır', () {
      // Asıl korunan kural. Ham oran 1.0 olurdu ve çubuk TEK renge
      // dönerdi; tek renkli çubuk "rakip yok" diye okunur, yani rakibi
      // göstermek için eklenen öğe rakibi siler.
      expect(duelTugShare(120, 0), 1 - duelTugFloor);
      expect(duelTugShare(0, 120), duelTugFloor);
    });
  });

  group('sayarak çıkan skor', () {
    testWidgets('hedefe atlamaz, tırmanır', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: RollingCount(value: 400, style: TextStyle())),
        ),
      );

      // İlk kare sıfırdan başlar.
      expect(find.text('0'), findsOne);

      await tester.pump(const Duration(milliseconds: 200));
      final mid = tester.widget<Text>(find.byType(Text)).data!;
      expect(
        int.parse(mid),
        allOf(greaterThan(0), lessThan(400)),
        reason: 'sayım ortada bir yerde olmalı, uçlarda değil',
      );

      await tester.pumpAndSettle();
      expect(find.text('400'), findsOne);
    });

    testWidgets('hareket azaltma açıkken sayım yapılmaz', (tester) async {
      // Erişilebilirlik ayarı dekoratif animasyonu iptal eder. Sayım
      // gözü takip etmeye zorlayan bir hareket; vestibüler rahatsızlığı
      // olan kullanıcı için tam olarak kapatılması gereken türden.
      await tester.pumpWidget(
        ChangeNotifierProvider<ReducedMotionProvider>(
          create: (_) => ReducedMotionProvider(initialUserReduce: true),
          child: const MaterialApp(
            home: Scaffold(body: RollingCount(value: 400, style: TextStyle())),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('400'), findsOne);
    });

    test('süre farkla büyür ama tavanı vardır', () {
      // Sabit süre iki uçta da yanlış: 3 puan uzun uzun sayılırsa komik,
      // 4200 puan aynı sürede sayılırsa okunmayan bir bulanıklık.
      final small = RollingCount.durationFor(5);
      final medium = RollingCount.durationFor(400);
      final huge = RollingCount.durationFor(999999);

      expect(medium, greaterThan(small));
      expect(huge, lessThanOrEqualTo(const Duration(milliseconds: 1100)));
    });
  });
}
