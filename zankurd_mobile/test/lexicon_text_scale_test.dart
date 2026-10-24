import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_lookup.dart';

/// Sözlük sözcüğü büyük yazıda iki kez büyüyordu (2026-10-22).
///
/// ## Kusur
///
/// iPhone 17e simülatöründe en büyük yazı boyutunda soru metnindeki
/// dokunulabilir (noktalı alt çizgili) sözcükler, yanlarındaki düz
/// sözcüklerden belirgin büyük çiziliyordu; cümle karışık görünüyordu.
/// Sözcük bir `WidgetSpan` içindeki `Text`'tir: Flutter yer tutucu
/// çocukları zaten metnin ölçekleyicisiyle büyütür, içteki `Text` de
/// `MediaQuery` ölçeğini bir kez daha uygular.
///
/// ## Niçin sessiz kalabilirdi
///
/// Ekran turu ve testler 1.0 ölçekte koşar; orada iki kez 1.0 yine 1.0'dır.
///
/// ## Bekçi
///
/// 2× yazı ölçeğinde dokunulabilir sözcüğün yüksekliği düz sözcüğünkünü
/// (dokunma payı hariç) aşmaz.
void main() {
  testWidgets('büyük yazıda sözlük sözcüğü düz sözcükle aynı boyda', (
    tester,
  ) async {
    final word = LearnerLexicon.lookup('dûr') != null ? 'dûr' : null;
    expect(word, isNotNull, reason: 'sözlükte bilinen bir sözcük gerekli');
    const style = TextStyle(fontSize: 20, height: 1.2);
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LexiconText('$word', style: style),
                  const Text('dûr', key: ValueKey('plain'), style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final tappable = find.byKey(const ValueKey('lexicon-word-dur'));
    expect(tappable, findsOneWidget);
    final inner = find.descendant(of: tappable, matching: find.byType(Text));
    final wordHeight = tester.getRect(inner).height;
    final plainHeight = tester
        .getRect(find.byKey(const ValueKey('plain')))
        .height;
    expect(wordHeight, closeTo(plainHeight, 1.0));
  });
}
