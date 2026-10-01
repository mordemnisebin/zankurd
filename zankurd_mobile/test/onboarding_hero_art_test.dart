/// Onboarding hero SANATININ bekçisi: iki slaytın soru kartı maketi,
/// maketin bankadaki gerçek soruyla aynı kalması ve hero/başlık arası
/// boşluk.
///
/// 2026-09-29 doğallık: 1. ve 2. grup eski görünüşü (üç eğik kategori
/// çizimi, VS amblemi) sabitliyordu. Kahraman artık bankadaki gerçek bir
/// sorunun statik maketi (GORSEL_KARARLAR K1); yarış slaytında VS amblemi
/// (iki elmas avatar) yerine soru ilerlemesi durur — elmasın iki
/// anlamından biri (K5). Korunan kurallar aynı: hero "burada ne var"
/// sorusunu gerçek içerikle yanıtlar, dekoratiftir (ekran okuyucuya
/// ayrıca duyurulmaz), yarış slaytı öğrenme slaytından ayrışır. Yeni
/// bekçi: maketteki metin ve şıklar bankadaki soruyla birebir aynıdır.
///
/// 2026-09-29 Şahnê: iki slayt da sahne kartıdır (`SahneStageCard`): sayfa
/// 1 öğrenme (Zimrût), sayfa 2 yarış (Boyax sahne degradesi).
///
/// ## Kusur
///
/// Her iki tanıtım sayfasının hero'su aynı jenerik kalıptaydı: forest
/// gradyanı + kilim dokusu + BEYAZ DAİREDE TEK İKON (mezuniyet şapkası ya
/// da şimşek) + köşede Zana. Sahip ekranı "renksiz" buldu: ikon ne
/// kategoriyle ne de "burada ne var" sorusuyla ilgiliydi. 2026-09-27'deki
/// üç kategori çizimi yelpazesi bu kez "yapay zekâ yapmış gibi" okundu:
/// çizim kolajı neyin oynanacağını söylemiyordu. Uzun telefonlarda
/// (390×844) hero ile başlık arasında da ~100pt boş alan kalıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// `onboarding_hierarchy_test.dart` yalnız hero YÜKSEKLİĞİNİ (< 300pt)
/// ölçüyordu; hero'nun İÇİNDE ne olduğuna hiç bakmıyordu. Maket sabit veri
/// taşıdığı için banka değişse de ekran aynı kalır; bankayla karşılaştıran
/// bir test olmadan maket sessizce var olmayan bir soruyu gösterirdi. Hero
/// ile başlık arasındaki boşluk da hiçbir yerde PİKSEL olarak ölçülmüyordu.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// Tek başına `OnboardingScreen`i (yalnız dil sağlayıcısıyla) çizer —
/// `onboarding_hierarchy_test.dart` ile aynı hafif kurulum.
Future<void> _pumpOnboarding(WidgetTester tester, {String lang = 'tr'}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..setLang(lang),
      child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
    ),
  );
  await tester.pumpAndSettle();
}

/// Bankadaki bütün soruları kimliğe göre toplar.
Map<String, Map<String, dynamic>> _bankById() {
  final byId = <String, Map<String, dynamic>>{};
  for (final entity in Directory('assets/data').listSync()) {
    if (entity is! File || !entity.path.endsWith('_questions.json')) continue;
    final decoded = jsonDecode(entity.readAsStringSync());
    final list = decoded is List
        ? decoded
        : ((decoded as Map<String, dynamic>)['questions'] as List? ?? []);
    for (final raw in list) {
      final q = raw as Map<String, dynamic>;
      byId[q['id'] as String] = q;
    }
  }
  return byId;
}

/// Kahraman yuvası ([SahneEntryHero]) bir sahne kartı sarar; rol ve kilim
/// kartın kendi alanlarıdır.
SahneStageCard _card(WidgetTester tester, Finder hero) =>
    tester.widget<SahneStageCard>(
      find.descendant(of: hero, matching: find.byType(SahneStageCard)),
    );

/// Kahramanın içindeki tek görsel logodur (K1: kategori çizimi kolajı
/// kalktı). 2026-10-01'den beri logo kartın içinde durur (giriş, kayıt ve ad
/// ekranındaki kartlar gibi); bu yüzden "hiç `Image` yok" yerine "her `Image`
/// bir `AppLogo`nun içinde" denir.
void _expectOnlyLogoImages(WidgetTester tester, Finder hero) {
  final images = find.descendant(of: hero, matching: find.byType(Image));
  final inLogo = find.descendant(
    of: find.descendant(of: hero, matching: find.byType(AppLogo)),
    matching: find.byType(Image),
  );
  expect(
    images.evaluate().length,
    inLogo.evaluate().length,
    reason: 'kategori çizimi kolajı kalktı (K1); yalnız logo görseli kalır',
  );
}

void main() {
  final hero = find.byKey(const ValueKey('onboarding-hero-panel'));

  group('1) Maket bankadaki gerçek soruyu gösterir', () {
    test('iki maket sorusu bankada aynı metin ve şıklarla durur', () {
      final bank = _bankById();
      for (final sample in [
        OnboardingSampleQuestion.learn,
        OnboardingSampleQuestion.race,
      ]) {
        final q = bank[sample.id];
        expect(q, isNotNull, reason: '${sample.id} bankada yok');
        expect(q!['prompt'], sample.promptKu);
        expect(q['promptTr'], sample.promptTr);
        expect(q['answers'], sample.answers);
        // Şıklar iki dilde aynı olmalı: maket şıkları dile göre çevirmez.
        expect(q['answersTr'] ?? q['answers'], sample.answers);
      }
    });

    testWidgets('sayfa 1: soru ve dört şık, çizim yok, kilim açık', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpOnboarding(tester);

      const sample = OnboardingSampleQuestion.learn;
      expect(
        find.descendant(of: hero, matching: find.text(sample.promptTr)),
        findsOneWidget,
      );
      for (final answer in sample.answers) {
        expect(
          find.descendant(of: hero, matching: find.text(answer)),
          findsOneWidget,
        );
      }
      _expectOnlyLogoImages(tester, hero);
      expect(_card(tester, hero).kilim, isTrue);
    });

    testWidgets('Kurmancî arayüzde soru metni Kurmancîdir', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpOnboarding(tester, lang: 'ku');

      expect(
        find.descendant(
          of: hero,
          matching: find.text(OnboardingSampleQuestion.learn.promptKu),
        ),
        findsOneWidget,
      );
    });

    testWidgets('maket ekran okuyucuya ayrı düğüm eklemez', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();

      await _pumpOnboarding(tester);

      // Dekoratiftir: başlık ve gövde aynı bilgiyi metinle veriyor. Şıklar
      // dokunulabilir sanılmasın diye ekran okuyucuya hiç duyurulmaz.
      expect(
        find.bySemanticsLabel(OnboardingSampleQuestion.learn.promptTr),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text(OnboardingSampleQuestion.learn.promptTr),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );

      semantics.dispose();
    });
  });

  group('2) Sayfa 2: yarışma sahnesi (Boyax sahne kartı)', () {
    testWidgets('öğrenme slaytı Zimrût, yarış slaytı Boyax + soru ilerlemesi', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpOnboarding(tester);
      expect(_card(tester, hero).role, SahneRole.learn);
      expect(
        find.descendant(of: hero, matching: find.byType(SahneDiamondRow)),
        findsNothing,
      );

      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();

      expect(_card(tester, hero).role, SahneRole.race);
      expect(
        find.descendant(of: hero, matching: find.byType(SahneDiamondRow)),
        findsOneWidget,
        reason: 'yarış slaytı sorunun üstünde soru ilerlemesini gösterir',
      );
      expect(
        find.descendant(
          of: hero,
          matching: find.text(OnboardingSampleQuestion.race.promptTr),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hero, matching: find.byType(SahneVsEmblem)),
        findsNothing,
        reason: 'VS amblemi (iki elmas avatar) kalktı (K5)',
      );
      _expectOnlyLogoImages(tester, hero);
      expect(find.byType(RojMascot), findsNothing, reason: 'maskot yok');
    });
  });

  group('3) Hero ile başlık arasındaki boşluk', () {
    testWidgets(
      '390×844: hero altı ile başlık üstü arasında ≤ 64pt (eskiden ~100pt)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpOnboarding(tester);

        final heroBottom = tester.getBottomLeft(hero).dy;
        final titleTop = tester.getTopLeft(find.text('Öğren')).dy;

        expect(
          titleTop - heroBottom,
          lessThanOrEqualTo(64),
          reason:
              'kahraman ile metin tek grup olarak ortalanır; aralarında '
              'yalnız sabit boşluk kalır.',
        );
      },
    );
  });

  group('4) Küçük ekran ve büyük yazıda taşma yok', () {
    testWidgets('375×667 (iPhone SE, normal yazı): sayfa 1 ve 2 taşmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 667));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.takeException();

      await _pumpOnboarding(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('%200 yazı: sayfa 1 ve 2 taşmaz', (tester) async {
      const size = Size(390, 844);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.takeException();

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang('tr'),
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: OnboardingScreen(onComplete: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
