import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/responsive_wrapper.dart';

void main() {
  testWidgets('wide web layout reaches the desktop breakpoint', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    double? availableWidth;
    await tester.pumpWidget(
      MaterialApp(
        home: ResponsiveWrapper(
          child: LayoutBuilder(
            builder: (context, constraints) {
              availableWidth = constraints.maxWidth;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(availableWidth, greaterThanOrEqualTo(768));
  });

  test('privacy, wildcard and subscription copy stays truthful', () {
    final strings = File('lib/src/l10n/strings.dart').readAsStringSync();
    final wildcard = File('lib/src/models/wildcard.dart').readAsStringSync();
    final paywall = File(
      'lib/src/screens/paywall_screen.dart',
    ).readAsStringSync();
    final privacy = File('web/privacy.html').readAsStringSync();

    expect(
      strings,
      isNot(contains('Adın yalnızca liderlik tablosunda görünür')),
    );
    expect(strings, isNot(contains('Navê te tenê di tabloya pêşderçûnê de')));
    expect(privacy, isNot(contains('yalnızca liderlik tablosunda')));
    expect(privacy, isNot(contains('tenê di tabloya pêşderçûnê de')));
    expect(wildcard, isNot(contains('Seyirciye Sor')));
    expect(strings, isNot(contains('Seyirci oy dağılımını görürsün')));
    expect(paywall, isNot(contains('2 ay bedava')));
    expect(paywall, isNot(contains('2 meh belaş')));
    expect(paywall, isNot(contains('premium.errorMessage')));
    expect(paywall, isNot(contains('premium.infoMessage')));
  });

  test('solid accents use adaptive foregrounds and tap targets stay large', () {
    // 2026-09-29 Şahnê: iki ortak bileşen listeden çıktı, korudukları şey
    // kalıyor. Görev bildirimi artık altın DOLGU değil (Kulis zemin +
    // birincil metin; `mission_toast_typography_test` metni ölçer). Boş/hata
    // panelinin eylemi `SahneButton`dır: Agir üstünde metin temadan `onAct`
    // gelir (koyu, 8:1); ham renkle düğme boyamaz.
    //
    // 2026-09-29 Şahnê (ekranlar): dolgu üstündeki metin artık ekranda
    // `AppColors.onSolid(...)` ile hesaplanmaz; her dolgunun kendi "üstü"
    // belirteci vardır. Agir dolgu yalnız `SahneButton.primary`dir (metin
    // temadan `onAct`, koyu); Zêr dolgu üstünde `t.onGold`. Kural aynı:
    // dolu yüzeyde metin sabit beyaz değil, dolguya göre okunur renk.
    final expectedHelpers = <String, String>{
      'lib/src/screens/quiz_result_screen.dart': 'color: t.onGold',
      'lib/src/screens/quiz/quiz_screen_ui.dart': 'SahneButton.primary(',
      'lib/src/screens/paywall_screen.dart': 'SahneButton.primary(',
      // Boş/hata panelinin eylem düğmesi bu listede yoktu ve sabit beyaz
      // metin kullanıyordu: `AppErrorState` onu `AppTheme.wrong` ile
      // çağırdığında kontrast 3,73:1 kalıyordu. Bu düğme uygulamadaki her
      // yükleme hatasının tek eylemi (2026-07-31 denetimi).
      'lib/src/widgets/app_state.dart': 'SahneButton.primary(',
    };
    final toast = File('lib/src/widgets/mission_toast.dart').readAsStringSync();
    expect(
      toast,
      isNot(contains('backgroundColor: AppTheme.gold')),
      reason: 'görev bildirimi altın dolguyla içeriğin üstüne binmemeli',
    );
    for (final entry in expectedHelpers.entries) {
      expect(
        File(entry.key).readAsStringSync(),
        contains(entry.value),
        reason: '${entry.key} adaptive foreground kullanmıyor',
      );
    }

    // `offline_banner.dart` bu listede 2026-09-25'e kadar vardı: şerit
    // `AppTheme.wrong` ile DOLDURULUYORDU ve bu yüzden beyaz metin
    // (`onSolid`) kontrast için zorunluydu.
    //
    // Artık şerit doygun kırmızı dolgu değil, seyrek bir yüzey + ince
    // kenarlık kullanıyor; metin tema'nın birincil rengini alıyor. Bu
    // yüzden kural değişti: dolgu artık kesinlikle yapılmamalı, metin
    // okunabilir bir renkten gelmeli. Kuralın koruduğu şey (kontrast)
    // aynı kalıyor, yalnız yasaklanan biçim değişti.
    final offlineBanner = File(
      'lib/src/widgets/offline_banner.dart',
    ).readAsStringSync();
    expect(
      offlineBanner,
      isNot(contains('color: AppTheme.wrong,')),
      reason:
          'Çevrimdışı şeridi doygun kırmızıyla doldurma: zayıf ağda her '
          'ekranda görünen bir durum çığlık atmamalı (2026-09-25).',
    );
    // 2026-09-29 Şahnê: birincil metin belirteçten gelir (`t.tx`).
    expect(
      offlineBanner,
      contains('color: t.tx'),
      reason: 'Şerit metni tema birincil rengini kullanmalı.',
    );

    expect(
      File('lib/src/widgets/sahne/sahne_field.dart').readAsStringSync(),
      contains('minWidth: 48'),
    );
    expect(
      File('lib/src/widgets/legal_links.dart').readAsStringSync(),
      contains('minHeight: 48'),
    );
    expect(offlineBanner, contains('minHeight: 48'));
  });
}
