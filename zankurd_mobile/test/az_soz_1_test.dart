// "AZ SÖZ" turu, birinci grup bekçisi.
//
// ## Kusur
//
// Kullanıcı geri bildirimi (2026-10-20): "uygulama çok metin odaklı". Dört
// modelli tarama (Opus, Codex, ChatGPT, Grok) ortak olarak şunları saptadı:
// başlığın altında aynı şeyi söyleyen alt satırlar. Ana sayfa "Günün dersi"
// kartının içinde öbür dildeki başlık, düello satırlarında "Sen şimdi oyna,
// rakibin sonra" gibi açıklamalar, hikâye kartlarında öbür dildeki ad,
// Ayarlar'da iki satırın alt yazısı, Mağaza kartlarında ürün açıklaması.
//
// ## Niçin sessiz kalırdı
//
// Bu satırlar yanlış değil, yalnızca fazladır; hiçbir test bozulmaz, bir
// sonraki "küçük açıklama" ekleyişinde sessizce geri gelirler. Bu dosya
// KALDIRILAN metinlerin ilgili ekranlarda artık bulunmadığını sabitler.
// (Ekran başlıkları, sekmeler ve konu kartlarındaki iki dil bilerek KALIR.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/home/home_duel_card.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/story_catalog.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
    StoryProgressStore.resetInstance();
  });

  test('kaldırılan açıklama anahtarları sözlükte yok', () {
    for (final key in [
      'settings.retakePlacement.sub',
      'settings.betaFeedback.sub',
      'duel.challenge.entry.sub',
    ]) {
      expect(
        () => Tr.forKu(key, false),
        throwsA(isA<AssertionError>()),
        reason: '$key sözlükten silinmeliydi',
      );
    }
  });

  test('profil boş durumu tek cümle', () {
    expect(Tr.forKu(K.noOnlineHistory, false), 'Henüz soru çözmedin.');
    expect(
      Tr.forKu(K.noOnlineHistory, true),
      'Te hêj tu pirs çareser nekiriye.',
    );
  });

  testWidgets('hikâye kartında öbür dildeki ad yok', (tester) async {
    for (final isKu in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            // 12 hikâye ekrana sığmaz (2026-10-27): kaydırılır.
            body: SingleChildScrollView(
              child: StoryCatalog(isKu: isKu, onOpen: (_, _) async {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final story in everydayStories) {
        final other = isKu ? story.titleTr : story.titleKu;
        final own = isKu ? story.titleKu : story.titleTr;
        if (other != own) expect(find.text(other), findsNothing);
        expect(find.text(own), findsOneWidget);
      }
    }
  });

  testWidgets('ana sayfa düello satırında açıklama alt satırı yok', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SingleChildScrollView(
            child: HomeDuelCard(
              repository: freshMockRepository(),
              asyncDuelEnabled: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sırayla düello'), findsOneWidget);
    expect(find.text('Sen şimdi oyna, rakibin sonra'), findsNothing);
    expect(find.byKey(const ValueKey('home-duel-meta')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home-duel-primary')));
    await tester.pumpAndSettle();
    expect(find.text('Sen şimdi oyna, rakibin sonra'), findsNothing);
    expect(find.text('Bağlantı gönder, arkadaşın sonra oynasın'), findsNothing);
  });
}
