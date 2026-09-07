import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Kayıt sihirbazı kademeli adım/başlık süsünü "hareketi azalt" varken
/// yine oynatıyordu.
///
/// 900 ms'lik `LoadAnimationSequence` içeriği süre×0.2–0.95 aralığında
/// gösteriyor: tercih açıkken ilk form ekranı splash/girişteki gibi
/// ayarı yok saymış olur. Ölçek süsüdür, durum taşımaz — bitmiş değerde
/// durmalı.
Widget _shell({required bool reducedMotion}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(
        create: (_) => ReducedMotionProvider(initialUserReduce: reducedMotion),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: const SignUpScreen()),
  );
}

double _stepScale(WidgetTester tester) {
  return tester
      .widget<ScaleTransition>(
        find.ancestor(
          of: find.text('1'),
          matching: find.byType(ScaleTransition),
        ),
      )
      .scale
      .value;
}

void main() {
  testWidgets('hareketi azalt açıkken adım göstergesi zıplamaz', (
    tester,
  ) async {
    await tester.pumpWidget(_shell(reducedMotion: true));
    await tester.pump();

    expect(_stepScale(tester), 1.0);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tercih kapalıyken kademeli giriş oynar', (tester) async {
    await tester.pumpWidget(_shell(reducedMotion: false));
    await tester.pump();

    expect(
      _stepScale(tester),
      lessThan(1.0),
      reason:
          'kademe süsünün ilk karede bitmiş olması tercihin yok sayıldığı '
          'anlamına gelmez; kapalıyken animasyon başlamalı',
    );
  });
}
