import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';

/// "Hareketi azalt" tercihi gerçekten uygulanır.
///
/// ## Kusur
///
/// `ReducedMotionProvider` yazılmıştı, ayarlarda açılıp kapanabiliyordu ve
/// sınıf belgesi şunu vaat ediyordu: *"Etkin değer, kullanıcı tercihi VEYA
/// sistemin `disableAnimations` tercihiyle birlikte çalışır."*
///
/// İkisi de tutulmuyordu:
///
/// 1. `setSystemReduce`i çağıran TEK BİR SATIR yoktu, yani `_systemReduce`
///    hep false kalıyordu. iOS/Android erişilebilirlik ayarından hareketi
///    kapatan kullanıcı, uygulamada ayrıca aynı anahtarı bulup açmak
///    zorundaydı.
/// 2. Uygulamadaki dört sonsuz (`repeat()`) animasyonun hiçbiri provider'ı
///    okumuyordu; quiz efektleri ise `isFlutterTestEnvironment`e
///    dallanıyordu — yani animasyonlar yalnız TEST KOŞUCUSUNDA kapanıyor,
///    gerçek kullanıcının tercihi hiçbirini etkilemiyordu.
///
/// Aynı uygulamada iki farklı shimmer davranışı bile vardı: biri ayarı
/// sayıyor, öteki saymıyordu (2026-07-31 denetimi).
void main() {
  group('sağlayıcı davranışı', () {
    test('kullanıcı veya sistem tercihi yeterli', () {
      final provider = ReducedMotionProvider();
      expect(provider.reduceMotion, isFalse);

      provider.setSystemReduce(true);
      expect(
        provider.reduceMotion,
        isTrue,
        reason: 'Sistem tercihi tek başına yeterli olmalı.',
      );

      provider.setSystemReduce(false);
      expect(provider.reduceMotion, isFalse);
    });

    testWidgets('sağlayıcı yoksa güvenli varsayılan hareket açıktır', (
      tester,
    ) async {
      // Hareket azaltma bir iyileştirmedir; widget'lar onu okumak için
      // sağlayıcı zorunlu kılmamalı. Aksi hâlde aynı widget bir ekran
      // görüntüsü aracında ya da izole testte çöker — eşleşme ekranının
      // dört testi tam bu yüzden düşmüştü.
      late bool reduced;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              reduced = ReducedMotionProvider.isReducedIn(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(reduced, isFalse);
    });

    testWidgets('sağlayıcı varsa değeri okunur', (tester) async {
      late bool reduced;
      await tester.pumpWidget(
        ChangeNotifierProvider<ReducedMotionProvider>(
          create: (_) => ReducedMotionProvider(initialUserReduce: true),
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                reduced = ReducedMotionProvider.isReducedIn(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(reduced, isTrue);
    });
  });

  group('bağlantılar', () {
    test('sistem tercihi uygulama kökünde okunuyor', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(
        main,
        contains('MediaQuery.disableAnimationsOf(context)'),
        reason: 'Sistem tercihi okunmazsa provider ın yarısı ölü kalır.',
      );
      expect(main, contains('setSystemReduce'));
    });

    test('sonsuz animasyonlar tercihi dinliyor', () {
      // `repeat()` çağıran her yer.
      const owners = {
        'lib/src/screens/matchmaking_screen.dart': 'radar ve nabız',
        'lib/src/screens/categories_tab.dart': 'shimmer',
        'lib/src/screens/quiz/quiz_timer_widget.dart': 'sayaç nabzı',
      };
      owners.forEach((path, what) {
        expect(
          File(path).readAsStringSync(),
          contains('ReducedMotionProvider.isReducedIn'),
          reason: '$what ($path) tercihi dinlemiyor.',
        );
      });
    });

    test('quiz efektleri test bayrağına değil tercihe dallanıyor', () {
      final effects = File(
        'lib/src/screens/quiz/quiz_effects.dart',
      ).readAsStringSync();
      expect(effects, contains('ReducedMotionProvider.isReducedIn'));
      // Yanlış cevaptaki parlama, sarsıntı ve combo rozeti — üçü de
      // tetiklendiği yerde kapıdan geçmeli.
      expect(effects, contains('_motionOff(context)'));
    });
  });
}
