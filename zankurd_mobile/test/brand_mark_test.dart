import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/brand_mark.dart';

/// Logo bekçisi (2026-09-30, L4 soru balonu).
///
/// ## Kusur
///
/// Eski logo (kırmızı Z, güneş, dağ, kitap) yapay zekâ üretimi bir resim
/// gibi duruyordu ve 24 px'te okunmuyordu. Yeni logo üç yerde yaşar ve üçü
/// birbirinden habersiz kayabilir: uygulama içindeki yol çizimi
/// ([BrandMarkPainter]), simgeleri üreten `tool/generate_app_icons.py` ve
/// tasarım klasöründeki `uret.py`. Kayma sessizdir: simge bir sürüm sonra
/// ekrandaki markadan başka bir Z ile çıkar.
///
/// ## Koruma
///
/// * Çizicinin çokgenleri betikteki sayılarla birebir aynıdır.
/// * Oyuk gerçekten delik (evenOdd): Z'nin ortası çizilmez, balonun içi
///   çizilir.
/// * iOS/web simgelerinde alfa kanalı yoktur (App Store alfalı simgeyi
///   reddeder) ve zemin gece lacivertidir; açılış görselleri ve uygulama
///   içi logo ise şeffaftır.
void main() {
  test('çizici çokgenleri simge betiğiyle aynı sayılardır', () {
    final script = File('tool/generate_app_icons.py').readAsStringSync();
    List<List<int>> block(String name) {
      final m = RegExp(
        '$name = \\[(.*?)\\]\\n',
        dotAll: true,
      ).firstMatch(script);
      expect(m, isNotNull, reason: '$name betikte bulunamadı');
      return RegExp(r'\((\d+), (\d+)\)')
          .allMatches(m!.group(1)!)
          .map((e) => [int.parse(e.group(1)!), int.parse(e.group(2)!)])
          .toList();
    }

    List<List<int>> asList(List<Offset> o) =>
        o.map((p) => [p.dx.toInt(), p.dy.toInt()]).toList();
    expect(asList(BrandMarkPainter.bubble), block('BUBBLE'));
    expect(asList(BrandMarkPainter.hole), block('Z_HOLE'));
  });

  test('Z oyuk: ortası çizilmez, balonun gövdesi çizilir', () {
    // 1024 karede: (430, 331) Z'nin üst çubuğunun içi (delik, çizilmez);
    // (200, 450) balon gövdesi (dolu); (140, 800) kuyruk (dolu); (120, 150)
    // pahlı sol üst köşenin dışı (boş).
    final path = BrandMarkPainter.pathFor(
      Size(BrandMarkPainter.box.width, BrandMarkPainter.box.height),
    );
    Offset local(double x, double y) =>
        Offset(x - BrandMarkPainter.box.left, y - BrandMarkPainter.box.top);
    expect(
      path.contains(local(430, 331)),
      isFalse,
      reason: 'Z üst çubuğu delik',
    );
    expect(
      path.contains(local(200, 450)),
      isTrue,
      reason: 'balon gövdesi dolu',
    );
    expect(path.contains(local(140, 800)), isTrue, reason: 'kuyruk dolu');
    expect(
      path.contains(local(120, 150)),
      isFalse,
      reason: 'pahlı köşe dışarıda',
    );
  });

  testWidgets('BrandMark oranı 800/740, ekran okuyucudan gizli', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: BrandMark(color: Colors.orange, height: 22)),
      ),
    );
    final size = tester.getSize(find.byType(BrandMark));
    expect(size.height, 22);
    expect(size.width, closeTo(22 * 800 / 740, 0.001));
    expect(
      find.descendant(
        of: find.byType(BrandMark),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    semantics.dispose();
  });

  group('üretilen dosyalar', () {
    Future<ui.Image> decode(String path) async {
      final Uint8List bytes = File(path).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      return (await codec.getNextFrame()).image;
    }

    Future<Uint8List> rgba(ui.Image image) async => (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();

    test('iOS ve web simgelerinde alfa yok, zemin gece laciverti', () async {
      const paths = [
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png',
        'web/icons/Icon-512.png',
        'web/favicon.png',
      ];
      for (final path in paths) {
        final image = await decode(path);
        final px = await rgba(image);
        // Köşe pikseli: zemin. Alfa 255, renk #0A0F2E.
        expect(px[3], 255, reason: '$path köşesi saydam (alfa yasak)');
        expect(
          [px[0], px[1], px[2]],
          [0x0A, 0x0F, 0x2E],
          reason: '$path zemini gece laciverti değil',
        );
        for (var i = 3; i < px.length; i += 4) {
          if (px[i] != 255) fail('$path alfa kanalı taşıyor');
        }
      }
    });

    test('açılış görselleri ve uygulama içi logo şeffaf', () async {
      const paths = [
        'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
        'android/app/src/main/res/drawable/splash_logo.png',
      ];
      for (final path in paths) {
        final image = await decode(path);
        final px = await rgba(image);
        expect(px[3], 0, reason: '$path köşesi saydam olmalı');
        // Ortada işaret var: balon gövdesi turuncu (#FF8A3D).
        final i = ((image.height ~/ 2) * image.width + image.width ~/ 6) * 4;
        expect(
          [px[i], px[i + 1], px[i + 2], px[i + 3]],
          [0xFF, 0x8A, 0x3D, 0xFF],
          reason: '$path işareti Agir turuncusu değil',
        );
      }
    });
  });
}
