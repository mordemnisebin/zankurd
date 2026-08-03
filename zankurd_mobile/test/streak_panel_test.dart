import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/streak_panel.dart';

/// Streak yüzeyinin kullanıcıya verdiği sözleşmeler.
///
/// Panelin tek işi seriyi göstermek değil, oyuncunun onu KORUYABİLMESİ için
/// gereken bilgiyi vermek: hangi günler oynandı, bugün ne durumda, dondurma
/// niçin kullanılabilir ya da kullanılamaz.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

const _week = [
  StreakDayState.completed,
  StreakDayState.completed,
  StreakDayState.missed,
  StreakDayState.frozen,
  StreakDayState.completed,
  StreakDayState.today,
  StreakDayState.upcoming,
];

void main() {
  testWidgets('yedi günün her durumu ayrı ikon taşır', (tester) async {
    // Renk tek kanal olamaz: "kaçırdım" ile "henüz gelmedi" arasındaki fark
    // yalnız tonla anlatılırsa renk körü oyuncu için kaybolur.
    final icons = <IconData>{};
    for (final state in StreakDayState.values) {
      await tester.pumpWidget(
        _wrap(
          StreakPanel(
            current: 3,
            days: [state],
            freezeState: StreakFreezeState.notNeeded,
          ),
        ),
      );
      // İlk ikon gün işareti; jeton ve çip ikonları sonra gelir.
      final dayIcon = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon!)
          .toList();
      icons.add(dayIcon.last);
    }
    expect(
      icons,
      hasLength(StreakDayState.values.length),
      reason: 'iki gün durumu aynı ikonu paylaşırsa renk tek kanal olur',
    );
  });

  testWidgets('freeze durumları birbirinden ayrı etiket taşır', (tester) async {
    // Sekiz durumun altısı "sönük düğme" olarak çiziliyordu; oyuncu niçin
    // kullanamadığını ayırt edemiyordu.
    final labels = <String>{};
    for (final state in StreakFreezeState.values) {
      await tester.pumpWidget(
        _wrap(StreakPanel(current: 5, days: _week, freezeState: state)),
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((t) => t.isNotEmpty)
          .toList();
      labels.add(texts.join('|'));
    }
    expect(
      labels,
      hasLength(StreakFreezeState.values.length),
      reason: 'iki freeze durumu aynı görünüyorsa ayrım kaybolur',
    );
  });

  testWidgets('belirsiz işlem "uygulandı" demez', (tester) async {
    // Sunucudan cevap gelmeden başarı gösterilemez.
    await tester.pumpWidget(
      _wrap(
        const StreakPanel(
          current: 5,
          days: _week,
          freezeState: StreakFreezeState.uncertain,
          isKu: false,
        ),
      ),
    );
    expect(find.text('Korundu'), findsNothing);
    expect(find.text('Sonuç belirsiz'), findsOneWidget);
  });

  testWidgets('uygulanırken koruma düğmesi sunulmaz', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        StreakPanel(
          current: 5,
          days: _week,
          freezeState: StreakFreezeState.applying,
          onFreeze: () => taps++,
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(taps, 0);
  });

  testWidgets('coin yetersizken koruma düğmesi sunulmaz', (tester) async {
    await tester.pumpWidget(
      _wrap(
        StreakPanel(
          current: 5,
          days: _week,
          freezeState: StreakFreezeState.insufficientCoins,
          onFreeze: () {},
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('Coin yetersiz'), findsOneWidget);
  });

  testWidgets('milestone ilerlemesi sayıyla da yazılır', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const StreakPanel(
          current: 5,
          days: _week,
          freezeState: StreakFreezeState.notNeeded,
          nextMilestone: 7,
        ),
      ),
    );
    expect(find.text('5/7'), findsOneWidget);
  });

  testWidgets('milestone geçilmişse ilerleme çubuğu gösterilmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const StreakPanel(
          current: 9,
          days: _week,
          freezeState: StreakFreezeState.notNeeded,
          nextMilestone: 7,
        ),
      ),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('dark temada ve 200% yazıda taşmaz', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StreakPanel(
                current: 12,
                days: _week,
                freezeState: StreakFreezeState.available,
                nextMilestone: 30,
                freezeCost: 50,
                isKu: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
