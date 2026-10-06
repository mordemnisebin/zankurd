// Paylaşım görseli maketi: dört örnek kartı PNG'ye basar.
// Çalıştır: ZANKURD_SHARE_OUT_DIR=<klasör> flutter test tool/screenshots/share_card_preview_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/share_story_card.dart';

String _flutterSdkRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.path != dir.parent.path) {
    if (Directory(
      '${dir.path}/bin/cache/artifacts/material_fonts',
    ).existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return '';
}

Future<void> _loadFonts() async {
  const families = {
    'Onest': [
      'assets/fonts/Onest-Regular.ttf',
      'assets/fonts/Onest-Medium.ttf',
      'assets/fonts/Onest-SemiBold.ttf',
      'assets/fonts/Onest-Bold.ttf',
    ],
    'BricolageGrotesque': [
      'assets/fonts/BricolageGrotesque-Bold.ttf',
      'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
    ],
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }
  final materialIcons = File(
    '${_flutterSdkRoot()}/bin/cache/artifacts/material_fonts/'
    'MaterialIcons-Regular.otf',
  );
  if (materialIcons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(
          materialIcons.readAsBytes().then((b) => ByteData.view(b.buffer)),
        ))
        .load();
  }
  // Lucide artık paket değil uygulamanın kendi varlığıdır (`pubspec.yaml`,
  // aile `Lucide`, `fontPackage` yok); öneksiz adla yüklenmeli.
  final lucide = File('assets/fonts/Lucide.ttf');
  if (lucide.existsSync()) {
    await (FontLoader('Lucide')
          ..addFont(lucide.readAsBytes().then((b) => ByteData.view(b.buffer))))
        .load();
  } else {
    print('UYARI: assets/fonts/Lucide.ttf bulunamadı — ikonlar kare çizilecek');
  }
  // Google/Apple marka glifleri: uygulamanın kendi varlığı (öneksiz aile).
  final brands = File('assets/fonts/Font-Awesome-7-Brands-Regular-400.otf');
  if (brands.existsSync()) {
    await (FontLoader('FontAwesomeBrands')
          ..addFont(brands.readAsBytes().then((b) => ByteData.view(b.buffer))))
        .load();
  } else {
    print('UYARI: Brands yazı tipi bulunamadı — marka ikonları kare çizilecek');
  }
}

/// Ekranı çizer ve basar. [page] `true` ise çocuk tam sayfa (iskelet)

Future<void> _render(
  WidgetTester tester,
  String name,
  ShareStoryCard card,
) async {
  final key = GlobalKey();
  tester.view.physicalSize = Size(card.format.width, card.format.height);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Material(
        child: RepaintBoundary(key: key, child: card),
      ),
    ),
  );
  await tester.runAsync(() async {
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(Platform.environment['ZANKURD_SHARE_OUT_DIR']!)
      ..createSync(recursive: true);
    File(
      '${dir.path}/$name.png',
    ).writeAsBytesSync(Uint8List.view(data!.buffer));
  });
}

void main() {
  setUpAll(_loadFonts);
  testWidgets('maketler', (tester) async {
    addTearDown(tester.view.reset);
    await _render(
      tester,
      '1_tr_story',
      const ShareStoryCard(
        isKu: false,
        format: ShareCardFormat.story,
        scoreText: '9/10',
        category: 'Ziman',
        stars: 3,
      ),
    );
    await _render(
      tester,
      '2_tr_square',
      const ShareStoryCard(
        isKu: false,
        format: ShareCardFormat.square,
        scoreText: '7/10',
        category: 'Dîrok',
        stars: 2,
      ),
    );
    await _render(
      tester,
      '3_ku_story',
      const ShareStoryCard(
        isKu: true,
        format: ShareCardFormat.story,
        scoreText: '9/10',
        category: 'Muzîk',
        stars: 3,
      ),
    );
    await _render(
      tester,
      '4_duel_win',
      const ShareStoryCard(
        isKu: false,
        format: ShareCardFormat.story,
        scoreText: '240',
        scoreLabel: 'puan',
        category: 'Çand',
        stars: 3,
        duelWin: true,
      ),
    );
  });
}
