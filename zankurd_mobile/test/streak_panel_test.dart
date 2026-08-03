import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/streak_panel.dart';

/// Streak yüzeyinin kullanıcıya verdiği sözleşmeler.
///
/// Panelin işi seriyi göstermek değil, oyuncunun onu KORUYABİLMESİ için
/// gereken bilgiyi vermek: hangi günler oynandı, bugün ne durumda, dondurma
/// niçin kullanılabilir ya da kullanılamaz.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

const _days = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

const _week = [
  StreakDayState.completed,
  StreakDayState.completed,
  StreakDayState.missed,
  StreakDayState.frozen,
  StreakDayState.completed,
  StreakDayState.today,
  StreakDayState.upcoming,
];

StreakPanel _panel({
  int current = 5,
  List<StreakDayState> days = _week,
  StreakFreezeState freezeState = StreakFreezeState.notNeeded,
  String? freezeLabel,
  String? freezeActionLabel,
  int? nextMilestone,
  int? freezeCost,
  VoidCallback? onFreeze,
}) => StreakPanel(
  current: current,
  days: days,
  freezeState: freezeState,
  freezeLabel: freezeLabel ?? 'F-${freezeState.name}',
  dayLabels: _days,
  freezeActionLabel: freezeActionLabel,
  nextMilestone: nextMilestone,
  freezeCost: freezeCost,
  onFreeze: onFreeze,
);

void main() {
  testWidgets('her gün durumu ayrı ikon taşır', (tester) async {
    // Renk tek kanal olamaz: "kaçırdım" ile "henüz gelmedi" arasındaki fark
    // yalnız tonla anlatılırsa renk körü oyuncu için kaybolur.
    final icons = <IconData>{};
    for (final state in StreakDayState.values) {
      await tester.pumpWidget(_wrap(_panel(days: [state])));
      icons.add(
        tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon!).last,
      );
    }
    expect(
      icons,
      hasLength(StreakDayState.values.length),
      reason: 'iki gün durumu aynı ikonu paylaşırsa renk tek kanal olur',
    );
  });

  testWidgets('her freeze durumu kendi etiketini gösterir', (tester) async {
    // Sekiz durumun altısı "sönük düğme" olarak çiziliyordu; oyuncu niçin
    // kullanamadığını ayırt edemiyordu.
    for (final state in StreakFreezeState.values) {
      await tester.pumpWidget(_wrap(_panel(freezeState: state)));
      expect(
        find.text('F-${state.name}'),
        findsOneWidget,
        reason: '${state.name} kendi etiketini göstermeli',
      );
    }
  });

  testWidgets('belirsiz işlem "uygulandı" demez', (tester) async {
    // Sunucudan cevap gelmeden başarı gösterilemez.
    await tester.pumpWidget(
      _wrap(_panel(freezeState: StreakFreezeState.uncertain)),
    );
    expect(find.text('F-applied'), findsNothing);
    expect(find.text('F-uncertain'), findsOneWidget);
  });

  testWidgets('uygulanırken koruma düğmesi sunulmaz', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        _panel(
          freezeState: StreakFreezeState.applying,
          freezeActionLabel: 'Koru',
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
        _panel(
          freezeState: StreakFreezeState.insufficientCoins,
          freezeActionLabel: 'Koru',
          onFreeze: () {},
        ),
      ),
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('F-insufficientCoins'), findsOneWidget);
  });

  testWidgets('etiket verilmezse koruma düğmesi çizilmez', (tester) async {
    // Bileşen kendi metnini uydurmaz; çağıran vermezse eylem sunulmaz.
    await tester.pumpWidget(
      _wrap(_panel(freezeState: StreakFreezeState.available, onFreeze: () {})),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('milestone ilerlemesi sayıyla da yazılır', (tester) async {
    await tester.pumpWidget(_wrap(_panel(current: 5, nextMilestone: 7)));
    expect(find.text('5/7'), findsOneWidget);
  });

  testWidgets('milestone geçilmişse ilerleme çubuğu gösterilmez', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_panel(current: 9, nextMilestone: 7)));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('dark temada ve 200% yazıda taşmaz', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: _panel(
                current: 12,
                freezeState: StreakFreezeState.available,
                freezeLabel: 'Amade ye ji bo parastinê',
                freezeActionLabel: 'Rêzê biparêze',
                nextMilestone: 30,
                freezeCost: 50,
                onFreeze: () {},
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
