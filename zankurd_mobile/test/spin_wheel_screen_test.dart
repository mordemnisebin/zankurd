import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Çark durumunu deterministik kontrol eden sahte depo.
class _SpinRepository extends MockZanKurdRepository {
  _SpinRepository({required this.canSpin, this.reward = 50});

  bool canSpin;
  final int reward;
  int awardCalls = 0;

  @override
  Future<bool> canSpinToday() async => canSpin;

  @override
  Future<int> awardSpinCoins() async {
    awardCalls += 1;
    if (!canSpin) return 0;
    canSpin = false;
    return reward;
  }
}

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void main() {
  // Çevir butonu ve geri sayım, çark görselinin (320px) altında kalır;
  // varsayılan test viewport'unda ListView bu satırları hiç build etmez.
  Future<void> useTallPhoneViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('çark hakkı varken Çevir butonu aktiftir', (tester) async {
    await useTallPhoneViewport(tester);
    final repository = _SpinRepository(canSpin: true);
    await tester.pumpWidget(_shell(SpinWheelScreen(repository: repository)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Çevir!'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hak yokken buton pasiftir ve geri sayım görünür', (
    tester,
  ) async {
    await useTallPhoneViewport(tester);
    final repository = _SpinRepository(canSpin: false);
    await tester.pumpWidget(_shell(SpinWheelScreen(repository: repository)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Yarın tekrar gel!'), findsOneWidget);
    expect(find.textContaining('Yeni çevirme hakkı'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('çevirince ödül tam bir kez verilir ve hak kapanır', (
    tester,
  ) async {
    await useTallPhoneViewport(tester);
    final repository = _SpinRepository(canSpin: true, reward: 50);
    await tester.pumpWidget(_shell(SpinWheelScreen(repository: repository)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Çevir!'));
    await tester.pump();
    // Animasyon sürerken ikinci hızlı dokunuş çift ödül vermemeli.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    // Çark animasyonu (3.6s) + konfeti (2.5s) tamamlanana kadar ilerlet.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 3));

    expect(repository.awardCalls, 1);
    expect(find.textContaining('+50 coin kazandın'), findsOneWidget);
    expect(find.text('Yarın tekrar gel!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sunucu 0 dönerse "zaten çevirdin" uyarısı çıkar ve hak kapanır',
    (tester) async {
      // canSpinToday true derken sunucunun (UTC gün sınırı) reddettiği durum:
      // istemci çakılmamalı, kullanıcıya açık mesaj göstermeli.
      await useTallPhoneViewport(tester);
      await tester.pumpWidget(
        _shell(SpinWheelScreen(repository: _RefusingSpinRepository())),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Çevir!'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Bugün zaten çevirdin.'), findsOneWidget);
      expect(find.text('Yarın tekrar gel!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('durum kontrolü hata verirse ekran çakılmaz ve uyarı gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(SpinWheelScreen(repository: _ThrowingSpinRepository())),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Çark durumu kontrol edilemedi.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Buton açık görünürken sunucunun ödülü reddettiği senaryo.
class _RefusingSpinRepository extends MockZanKurdRepository {
  @override
  Future<bool> canSpinToday() async => true;

  @override
  Future<int> awardSpinCoins() async => 0;
}

/// Durum kontrolünün tamamen başarısız olduğu senaryo.
class _ThrowingSpinRepository extends MockZanKurdRepository {
  @override
  Future<bool> canSpinToday() async {
    throw StateError('network down');
  }
}
