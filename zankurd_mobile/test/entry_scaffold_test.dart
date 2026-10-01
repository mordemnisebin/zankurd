/// Giriş akışının dört ekranı (karşılama, giriş, kayıt, ad sorma) tek
/// iskeleti paylaşır (A9, 2026-10-01).
///
/// ## Kusur
///
/// Dört ekran dört ayrı dille yazılmıştı: karşılamada üstte 88–148 px'lik
/// logo/dil/atla yığını ve altta iki çubuk çifti; girişte dil seçici sağ
/// üstte, başlık kahraman kartın İÇİNDE ortalı, "Giriş yap" kartın ortasında
/// kayan bir düğme; kayıtta adım göstergesi kartın içinde renkli bir "1/3"
/// metni ve "Geri" birincilin yanında ikinci bir dolgulu düğme; ad ekranında
/// ekranın üstüne yapışmış tam genişlikte bir gece bandı ve "Şimdilik geç"
/// birincil düğmenin ALTINDA. Aynı kullanıcı aynı dakikada dört farklı
/// yerde "atla" arıyor, birincil düğmeyi dört farklı yükseklikte buluyordu.
///
/// ## Niçin sessiz kaldı
///
/// Her ekranın kendi bekçileri vardı ve hepsi geçiyordu: kendi içinde
/// tutarlı dört ekran. "Birincil düğme ekranlar arasında aynı yerde mi",
/// "atla hep sağ üstte mi", "başlık hep aynı hizada mı" gibi ekranlar
/// ARASI sorular hiçbir testin konusu değildi; yeni bir ekran eklendiğinde
/// ya da biri elden geçtiğinde sözleşmeyi kimse görmüyordu.
///
/// Bu dosya o ekranlar arası sözleşmeyi ölçer. Doğrulama, ağ ve analitik
/// kuralları (yaş kutusu, ad politikası, kayıt adımları) kendi
/// dosyalarında durur ve değişmedi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

const _size = Size(390, 844);

/// Ekran adı → (açıcı, başlık metni, birincil düğme metni).
class _Entry {
  const _Entry(this.name, this.title, this.primary, this.build);

  final String name;
  final String title;
  final String primary;
  final Widget Function() build;
}

final _entries = <_Entry>[
  _Entry(
    'karşılama',
    'Öğren',
    'Sonraki',
    () => OnboardingScreen(onComplete: () {}),
  ),
  _Entry('giriş', "ZanKurd'a hoş geldin", 'Giriş yap', SignInScreen.new),
  _Entry('kayıt', 'Hesabını oluştur', 'İleri', SignUpScreen.new),
  _Entry(
    'ad sorma',
    'Oyundaki adın ne olsun?',
    'Oyuna başla',
    () => ProfileNameGateScreen(
      repository: MockZanKurdRepository(),
      onCompleted: () {},
    ),
  ),
];

Future<void> _open(WidgetTester tester, _Entry e) async {
  await tester.binding.setSurfaceSize(_size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(child: e.build(), authProvider: GateAuthProvider()),
  );
  await tester.pumpAndSettle();
}

Rect _primaryRect(WidgetTester tester) {
  final dock = find.byKey(const ValueKey('entry-dock'));
  expect(dock, findsOneWidget, reason: 'alt perde sabit olmalı');
  return tester.getRect(
    find.descendant(of: dock, matching: find.byType(SahneButton)).first,
  );
}

void main() {
  // Ölçüler GERÇEK yazı tipiyle alınır: ölçü fontu (Ahem) her harfi kareye
  // çevirir, ikincil satır sarar ve düğme konumları gerçekte olmayan yerde
  // ayrışırdı.
  setUpAll(loadAppFonts);

  testWidgets('birincil düğme dört ekranda ekranın AYNI yerinde durur', (
    tester,
  ) async {
    final rects = <String, Rect>{};
    for (final e in _entries) {
      await _open(tester, e);
      expect(find.text(e.primary), findsOneWidget, reason: e.name);
      rects[e.name] = _primaryRect(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    final first = rects.values.first;
    for (final entry in rects.entries) {
      expect(entry.value.top, closeTo(first.top, 0.5), reason: entry.key);
      expect(entry.value.left, closeTo(first.left, 0.5), reason: entry.key);
      expect(entry.value.width, closeTo(first.width, 0.5), reason: entry.key);
    }
  });

  testWidgets('karşılamanın 2. sayfasında "Geri" varken de düğme zıplamaz', (
    tester,
  ) async {
    await _open(tester, _entries.first);
    final page0 = _primaryRect(tester);
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-back')), findsOneWidget);
    expect(_primaryRect(tester).top, closeTo(page0.top, 0.5));
  });

  testWidgets('başlık dört ekranda aynı hizada ve aynı yazı ölçeğindedir', (
    tester,
  ) async {
    for (final e in _entries) {
      await _open(tester, e);
      final text = tester.widget<Text>(find.text(e.title));
      expect(text.style?.fontSize, SahneType.title.fontSize, reason: e.name);
      expect(text.style?.fontWeight, SahneType.title.fontWeight);
      expect(
        tester.getTopLeft(find.text(e.title)).dx,
        SahneSpace.page,
        reason: '${e.name}: başlık sayfa kenarına sola yaslı',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('kahraman yuvası dört ekranda kilim şeritli sahne kartıdır', (
    tester,
  ) async {
    for (final e in _entries) {
      await _open(tester, e);
      final card = find.byType(SahneStageCard).first;
      expect(tester.widget<SahneStageCard>(card).kilim, isTrue, reason: e.name);
      final rect = tester.getRect(card);
      expect(rect.left, SahneSpace.page, reason: e.name);
      expect(rect.right, _size.width - SahneSpace.page, reason: e.name);
      // Üst çubuğun (en az 56) hemen altında; ilerleme çubuğu olan
      // ekranlarda onun da altında.
      expect(rect.top, greaterThanOrEqualTo(SahneEntryScaffold.barHeight));
      expect(rect.top, lessThan(110), reason: e.name);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('atla her yerde SAĞ ÜSTTEDİR (karşılama, ad sorma)', (
    tester,
  ) async {
    for (final (entry, label) in [
      (_entries[0], 'Atla'),
      (_entries[3], 'Şimdilik geç'),
    ]) {
      await _open(tester, entry);
      final rect = tester.getRect(find.text(label));
      expect(rect.top, lessThan(SahneEntryScaffold.barHeight), reason: label);
      expect(
        rect.right,
        greaterThan(_size.width / 2),
        reason: '$label sağ yarıda',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    // Ad ekranında artık birincil düğmenin ALTINDA ikinci bir "geç" yok.
    await _open(tester, _entries[3]);
    expect(find.text('Şimdilik geç'), findsOneWidget);
  });

  testWidgets(
    'geri her yerde alt perdede, birincilin ALTINDAKİ metin düğmesi',
    (tester) async {
      // Karşılama 2. sayfa.
      await _open(tester, _entries.first);
      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      var primary = _primaryRect(tester);
      var back = tester.getRect(find.byKey(const ValueKey('onboarding-back')));
      expect(back.top, greaterThanOrEqualTo(primary.bottom));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('entry-dock')),
          matching: find.byKey(const ValueKey('onboarding-back')),
        ),
        findsOneWidget,
      );
      // Karşılama geri tuşu bir önceki sayfaya döner.
      await tester.tap(find.byKey(const ValueKey('onboarding-back')));
      await tester.pumpAndSettle();
      expect(find.text('Öğren'), findsOneWidget);

      // Kayıt 2. adım: "Geri" dolgulu ikinci düğme değil, metin düğmesi.
      await tester.pumpWidget(const SizedBox.shrink());
      await _open(tester, _entries[2]);
      expect(find.byKey(const ValueKey('signup-back-button')), findsNothing);
      await tester.enterText(
        find.byType(EditableText).at(0),
        'rojda@example.com',
      );
      await tester.enterText(find.byType(EditableText).at(1), 'sifre123');
      await tester.enterText(find.byType(EditableText).at(2), 'sifre123');
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      final signupBack = find.byKey(const ValueKey('signup-back-button'));
      expect(signupBack, findsOneWidget);
      primary = _primaryRect(tester);
      back = tester.getRect(signupBack);
      expect(back.top, greaterThanOrEqualTo(primary.bottom));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('entry-dock')),
          matching: find.byType(SahneButton),
        ),
        findsNWidgets(2),
        reason: 'perdede yalnız birincil + ikincil metin düğmesi',
      );
      await tester.tap(signupBack);
      await tester.pumpAndSettle();
      expect(find.text('Hesabını oluştur'), findsOneWidget);
      expect(find.byKey(const ValueKey('signup-back-button')), findsNothing);
    },
  );

  testWidgets('ilerleme çubuğu yalnız adımlı akışlarda ve hep aynı bileşen', (
    tester,
  ) async {
    final counts = <String, int>{};
    for (final e in _entries) {
      await _open(tester, e);
      counts[e.name] = find.byType(SahneProgressBar).evaluate().length;
      if (counts[e.name] == 1) {
        final top = tester.getTopLeft(find.byType(SahneProgressBar)).dy;
        expect(
          top,
          lessThan(SahneEntryScaffold.barHeight + 24),
          reason: '${e.name}: çubuk üst çubuğun hemen altında',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(counts, {'karşılama': 1, 'giriş': 0, 'kayıt': 1, 'ad sorma': 0});
  });

  testWidgets('klavye açıkken alt perde sabit kalmaz, düğme formla kayar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: MockZanKurdRepository(),
          onCompleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('entry-dock')),
      findsNothing,
      reason:
          'Sabit perde klavyeyle birlikte alanı bitiriyordu (568 − 300 − 56 − '
          '140 < 0); birincil düğme formun altına, kaydırılan sütuna iner.',
    );
    final scroll = find.byType(SingleChildScrollView);
    expect(
      find.descendant(of: scroll, matching: find.text('Oyuna başla')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 px ve %200 yazıda dört ekran taşmaz', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final e in _entries) {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(child: e.build(), authProvider: GateAuthProvider()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: e.name);
      expect(find.text(e.primary), findsOneWidget, reason: e.name);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
