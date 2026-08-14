import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/streak_panel.dart';

/// Streak yüzeyinin kullanıcıya verdiği sözleşmeler.
///
/// Panelin işi seriyi göstermek değil, oyuncunun onu KORUYABİLMESİ için
/// gereken bilgiyi vermek: hangi günler oynandı, bugün ne durumda, dondurma
/// niçin kullanılabilir ya da kullanılamaz.
///
/// Gün işaretinin ekran okuyucu anonsu `context.t` üzerinden defterden
/// okur (2026-08-14 denetimi) — gerçek ekranlarda kök widget'ın sağladığı
/// `LanguageProvider` burada da olmalı, aksi hâlde `Provider.of` bulunamaz
/// hatası atar.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
      child: MaterialApp(
        theme: brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
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
  testWidgets(
    'gün durumu anonsu ham enum adını değil çevrilmiş etiketi okur '
    '(2026-08-14)',
    (tester) async {
      // `Semantics.label` eskiden '$label: ${state.name}' üretiyordu — yani
      // TalkBack/VoiceOver "Pt: completed" gibi ham İngilizce enum adını
      // okuyordu. Görsel ikon/renk dilden bağımsız kalabilir ama anons
      // kalamaz.
      await tester.pumpWidget(
        _wrap(_panel(days: const [StreakDayState.completed])),
      );
      final dayMarkFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && (widget.properties.label ?? '').contains('Pt'),
      );
      final semantics = tester.getSemantics(dayMarkFinder);
      expect(semantics.label, isNot(contains('completed')));
      expect(semantics.label, contains('Tamamlandı'));
    },
  );

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
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
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
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  // ── Gerçek ürüne bağlılık ────────────────────────────────────────────
  //
  // Panel bir süre yalnız dosyada durdu: testlerde çiziliyordu ama hiçbir
  // ekran onu kullanmıyordu. Bu bekçi, streak yüzeyinin gerçekten ana
  // sayfadan ulaşılabilir olduğunu ve eski "ikon + başlık + paragraf"
  // anatomisinin geri gelmediğini sabitler.
  test('ana sayfa streak yüzeyi paneli kullanır', () {
    final home = File('lib/src/screens/home_screen.dart').readAsStringSync();
    expect(home, contains('StreakPanel('));
    expect(home, contains('_loadStreakWeek'));
    // Haftalık ritim GERÇEK geçmişten gelmeli; uydurma dizi değil.
    expect(home, contains('getLast7DaysHistory'));
    // Eski bilgilendirme metni panelin yerini almamalı.
    expect(home, isNot(contains('K.pGundurAraliksizOynuyorsun')));
  });

  test('panel etiketleri l10n defterinden gelir', () {
    final home = File('lib/src/screens/home_screen.dart').readAsStringSync();
    for (final key in const [
      'K.streakFreezeAvailable',
      'K.streakFreezeNoCoins',
      'K.streakWeekdays',
      'K.streakDayUnit',
    ]) {
      expect(home, contains(key), reason: '$key kullanilmiyor');
    }
  });
}
