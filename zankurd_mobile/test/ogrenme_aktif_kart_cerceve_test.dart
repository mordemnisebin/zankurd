// 2026-10-20 TASARIM KURULU (tur 9b): öğrenme ekranında etkin ders kartı.
//
// ## Kusur
//
// "Sıradaki ders · Alfabe" kartı ile altındaki kilitli satırlar aynı beyaz
// yüzey kartı olarak duruyordu; görsel ağırlık farkı azdı (ChatGPT, Grok,
// Gemini, Codex) ve kilit ikonları metin kadar iri/koyuydu.
//
// ## Niçin sessiz kalırdı
//
// Etkin kartın çerçevesini ölçen test yoktu (seviye ekranında vardı:
// `aktif_seviye_karti_cerceve_test.dart`); öğrenme ekranı kendi kartını
// çiziyordu ve ikisi ayrı kaydı. Sözleşme: etkin ders kartı 2 px Agir
// çerçeve; kilitli satırın metni DÜŞÜK okunurlukla soluklaştırılmaz (kilit
// ikonu ikincil ve 16 px).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('etkin ders kartı 2 px Agir çerçeve, kilit ikonu ikincil 16', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('tr'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: LearningScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final t = SahneTokens.of(
      tester.element(find.byKey(const ValueKey('learning-next-step'))),
    );

    final frame = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('learning-active-frame')),
    );
    final shape = (frame.decoration as ShapeDecoration).shape;
    final side = (shape as OutlinedBorder).side;
    expect(side.width, 2);
    // 2026-10-22 tasarım kurulu (ChatGPT, Gemini 3.1 Pro, Claude Opus):
    // ağırlık farkını artık DOLU Zimrût yüzey taşır; çerçeve yüzeyle aynı
    // renktedir (Agir yalnız "Başla" düğmesinde kalır).
    expect(side.color, t.learnFill);

    final lock = tester.widgetList<Icon>(find.byIcon(AppIcons.lock)).first;
    expect(lock.size, 16);
    // D aşaması: kilit öğrenme alanının Zimrût'una doğru kayık (soluk değil).
    expect(lock.color, Color.lerp(t.tx2, t.learnTx, 0.4));
  });
}
