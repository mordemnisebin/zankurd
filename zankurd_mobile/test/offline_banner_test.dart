// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/widgets/offline_banner.dart';

/// Çevrimdışı şerit `AnimatedSize` ile 300 ms açılıp kapanıyordu ve
/// "hareketi azalt" tercihini hiç okumuyordu.
///
/// Boy değişimi süsüdür, bağlantı durumunu taşımaz: tercih açıkken süre
/// sıfır olmalı. Aksi hâlde ayar, kabukta her zaman görünen bu bantta
/// yok sayılmış olur — birincil CTA ve haftalık grafik aynı kapıdan
/// geçiyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('offline banner retry action is tappable', (tester) async {
    var tapped = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: MaterialApp(
          home: Scaffold(
            body: OfflineBanner(isOffline: true, onRetry: () => tapped++),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('offline banner hides itself when online', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: const MaterialApp(
          home: Scaffold(body: OfflineBanner(isOffline: false)),
        ),
      ),
    );

    expect(
      find.text('İnternet bağlantısı yok. Kontrol ediliyor…'),
      findsNothing,
    );
  });

  testWidgets('offline banner respects top safe area inset', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(padding: EdgeInsets.only(top: 47)),
            child: Scaffold(
              body: OfflineBanner(
                isOffline: true,
                label: 'Sunucuya ulaşılamadı',
              ),
            ),
          ),
        ),
      ),
    );

    final labelTop = tester.getTopLeft(find.text('Sunucuya ulaşılamadı')).dy;
    expect(labelTop, greaterThanOrEqualTo(47));
  });

  testWidgets('hareketi azalt açıkken şerit boyu animasyonsuz değişir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageProvider(initialLang: 'tr'),
          ),
          ChangeNotifierProvider(
            create: (_) => ReducedMotionProvider(initialUserReduce: true),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: OfflineBanner(isOffline: true)),
        ),
      ),
    );

    final size = tester.widget<AnimatedSize>(find.byType(AnimatedSize));
    expect(size.duration, Duration.zero);
  });

  testWidgets('tercih kapalıyken şerit boyu 300 ms animasyonla değişir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: const MaterialApp(
          home: Scaffold(body: OfflineBanner(isOffline: true)),
        ),
      ),
    );

    final size = tester.widget<AnimatedSize>(find.byType(AnimatedSize));
    expect(size.duration, const Duration(milliseconds: 300));
  });
}
