// 2026-09-30 simülatör: geri düğmeli sayfa başlıkları (`zkAppBar`) büyük
// yazıda (iPhone 17e, %235) tek satırda "…" ile kesiliyordu ("Dilbilgisi /
// Gr…", "Kurmancî hî…"). `AppBar` başlığı `softWrap: false` + üç nokta ile
// sarar; başlığın kendisi hiçbir yerde kesilmiyordu diye taşma da yoktu,
// kusur yalnız gözle görülüyordu. Bekçi: %235'te uzun başlık en çok iki
// satıra sarar, KESİLMEZ (didExceedMaxLines false), çubuk başlığın ve alt
// satırın altında taşmaz, başlık geri plakasından en az 8 px uzakta durur.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';

import 'support/realistic_device.dart';

void main() {
  setUpAll(loadAppFonts);

  const titles = [
    'Dilbilgisi / Grammer',
    'Kurmancî hîn bibe',
    'Çavkaniyên wêneyan',
  ];

  for (final title in titles) {
    for (final width in [320.0, 390.0]) {
      testWidgets('"$title" x2.35 yazıda kesilmez (${width.round()} px)', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);
        late PreferredSizeWidget bar;
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('ku'),
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2.35)),
                child: child!,
              ),
              home: Builder(
                builder: (context) {
                  bar = zkAppBar(
                    context,
                    title: Text(title),
                    subtitle: const Text('Dil', maxLines: 2),
                  );
                  return Scaffold(appBar: bar, body: const SizedBox());
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(title),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: 'kesiliyor');
        expect(
          paragraph.size.height,
          lessThanOrEqualTo(bar.preferredSize.height),
          reason: 'başlık çubuktan uzun',
        );

        final titleRect = tester.getRect(find.text(title));
        final subtitleRect = tester.getRect(find.text('Dil'));
        final back = tester.getRect(find.byType(ZkBackButton));
        expect(
          titleRect.left - back.right,
          greaterThanOrEqualTo(8),
          reason: 'başlık geri plakasına yapışık',
        );
        expect(
          subtitleRect.bottom,
          lessThanOrEqualTo(bar.preferredSize.height),
          reason: 'alt satır çubuğun dışına taşıyor',
        );
        expect(titleRect.right, lessThanOrEqualTo(width));
      });
    }
  }
}
