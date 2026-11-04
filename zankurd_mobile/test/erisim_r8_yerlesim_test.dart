/// Erişilebilirlik ve yerleşim bekçisi (GPT-6 Pro ekran denetimi, tur 8).
///
/// ## Kusur
///
/// * Zorunlu güncelleme ekranı kaydırılamayan bir `Column`du: 320×568'de 2×
///   yazıyla içerik ekranı aşıyor, TEK çıkış olan mağaza düğmesi görünmez
///   kalıyordu (geri de kapalı).
/// * Donmuş gün hücresi (10 pt kalkan + tarih alt alta) 2× yazıda kare
///   hücreyi (320 pt'de ~36) aşıp taşıyordu.
/// * Sözlük balonu varsayılan yükseklik sınırıyla ve kaydırmasız açılıyordu;
///   320×568 + 2× yazıda madde ve düğme kesiliyordu.
/// * `SahneListRow` başlığı dışlarken `footer`ı da dışlıyordu: düello
///   listesindeki "Dürt" düğmesi ve başarım ilerlemesi ekran okuyucudan
///   kayboluyordu.
/// * `SahneButton(loading: true)` etiketi göstergeyle değiştiriyor, işlemin
///   adı ekran okuyucudan siliniyordu.
/// * Üst `Semantics`i `excludeSemantics` olan öğelerde (sözlük sözcüğü,
///   hikâye çipi, kilitli seviye satırı, Doza sloganı, bildirim kapatma)
///   `onTap` aktarılmadığından ekran okuyucu eylemi tetikleyemiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hepsi yalnız dar ekran + büyük yazı ya da ekran okuyucuyla görünür;
/// 390×844 ve 1× yazıdaki ekran turu ve widget testleri temizdi.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_lookup.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/streak_calendar.dart';
import 'package:zankurd_mobile/src/widgets/update_gate.dart';

Widget _app(Widget home, {String lang = 'tr', double scale = 1}) =>
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang(lang),
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

void _phone(WidgetTester tester, {double w = 320, double h = 568}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('zorunlu güncelleme: 320×568 + 2× yazıda mağaza düğmesine '
      'ulaşılır', (tester) async {
    _phone(tester);
    var opened = 0;
    await tester.pumpWidget(
      _app(
        UpdateRequiredScreen(onOpenStore: () => opened++),
        lang: 'ku',
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final button = find.byKey(const ValueKey('update-required-store'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    expect(opened, 1);
  });

  testWidgets('seri takvimi: donmuş gün 320 pt + 2× yazıda taşmaz', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SingleChildScrollView(
            child: StreakCalendar(
              today: DateTime(2026, 10, 24),
              markFor: (_) => StreakCalendarMark.frozen,
            ),
          ),
        ),
        lang: 'ku',
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sözlük balonu: 320×568 + 2× yazıda taşmaz ve kaydırılır', (
    tester,
  ) async {
    _phone(tester);
    final entry = LearnerLexicon.lookup('ev')!;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLexiconEntrySheet(context, entry),
              child: const Text('aç'),
            ),
          ),
        ),
        scale: 2,
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lexicon-entry-sheet')),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
  });

  testWidgets('satır: footer düğümü ekran okuyucuda kalır', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SahneListRow.icon(
            icon: Icons.person,
            title: 'Bawer',
            subtitle: 'altyazı',
            footer: SahneButton.text(label: 'Dürt', onPressed: () {}),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('Dürt')), findsWidgets);
    expect(
      tester.getSemantics(find.text('Dürt')),
      isSemantics(label: 'Dürt', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('düğme: yüklenirken etiket ekran okuyucuda korunur', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Center(
            child: SahneButton.primary(
              label: 'Gönder',
              loading: true,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('Gönder')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('sözlük sözcüğü: ekran okuyucu etkinleştirince balon açılır', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: LexiconText('Ev mezin e.', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
    final node = tester.getSemantics(
      find.byKey(const ValueKey('lexicon-word-ev')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}
