// 2026-10-28 kurul K2: BÜTÜN normal sayfalar aynı nötr üst çubuğu taşır.
//
// Kusur: öğrenme yeşil, yarış bordo, mağaza sarı, konu akışı konu renginde
// DOLU üst bant taşıyordu; her sayfa farklı bir uygulama gibi duruyordu ve
// kırmızı/sarı büyük yüzeyler hata/uyarı gibi okunuyordu. 2026-10-20 "dolu
// bant" kararı (renk ve canlılık, B) bilerek geri alındı: renk yok edilmedi,
// amaçlı kullanılıyor — mod/konu rengi yalnız çubuğun altındaki 3 px'lik
// çizgide ([ZkAccentLine]) ve ikon rozetlerinde.
//
// Niçin sessiz kalırdı: `zkAppBar(backgroundColor: …)` hâlâ derlenirdi;
// parametreler bu yüzden SİLİNDİ (derleme zorlar). Bu bekçi çalışma
// zamanında iki sözleşmeyi sabitler: AppBar zemini sayfa zemini (`bg`), ve
// [SahnePushedPage] dolu bant (`sahne-pushed-band`) çizmez; rol rengi 3 px
// çizgidir. Tam ekran oyun sahneleri (soru, sonuç) kapsam dışıdır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';

Widget _wrap(Widget child, {required bool dark}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider(initialLang: 'tr')),
    ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ChangeNotifierProvider<ReducedMotionProvider>(
      create: (_) => ReducedMotionProvider(initialUserReduce: false),
    ),
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: child,
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final screens = <(String, Widget Function())>[
    ('öğrenme', () => LearningScreen(repository: MockZanKurdRepository())),
    ('mağaza', () => ShopScreen(repository: MockZanKurdRepository())),
    (
      'seviye (konu bandı)',
      () => LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman'),
    ),
    ('arkadaşlar', () => FriendsScreen(repository: MockZanKurdRepository())),
    ('turnuva', () => TournamentScreen(repository: MockZanKurdRepository())),
    ('yarışma', () => ContestScreen(repository: MockZanKurdRepository())),
  ];

  for (final dark in [false, true]) {
    for (final (name, build) in screens) {
      testWidgets('$name: üst çubuk nötr, dolu mod rengi yok '
          '(${dark ? "gece" : "gündüz"})', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_wrap(build(), dark: dark));
        await tester.pump(const Duration(seconds: 1));
        final t = SahneTokens.of(tester.element(find.byType(Scaffold).first));

        // Dolu bant anahtarları artık yok.
        expect(find.byKey(const ValueKey('sahne-pushed-band')), findsNothing);
        for (final bar in tester.widgetList<AppBar>(find.byType(AppBar))) {
          expect(bar.backgroundColor, t.bg, reason: '$name AppBar zemini');
        }
        // Rol/konu rengi varsa yalnız 3 px'lik çizgi.
        for (final line in tester.widgetList<SizedBox>(
          find.byKey(ZkAccentLine.valueKey),
        )) {
          expect(line.height, 3, reason: '$name çizgisi 3 px');
        }
        // Başlık normal metin renginde (beyaz-bant başlığı değil).
        final back = find.byType(ZkBackButton);
        if (back.evaluate().isNotEmpty) {
          expect(tester.getSize(back.first).height, greaterThanOrEqualTo(48));
        }
      });
    }
  }

  testWidgets('SahnePushedPage rolü yalnız 3 px çizgiyi boyar', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SahnePushedPage(title: 'Deneme', role: SahneRole.race),
        dark: false,
      ),
    );
    await tester.pump();
    final t = SahneTokens.of(tester.element(find.byType(Scaffold).first));
    expect(find.byKey(const ValueKey('sahne-pushed-band')), findsNothing);
    final line = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(ZkAccentLine.valueKey),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(line.color, t.roleFill(SahneRole.race));
    final title = tester.widget<Text>(find.text('Deneme'));
    expect(title.style?.color, t.tx);
  });
}
