/// Konu görsel dili bekçisi: ana sayfa karosunun K3 silüeti
/// ([SahneCategoryGlyphPainter]) ve alt konu bandının K1 kilim deseni
/// ([SahneKilimBandPainter]).
///
/// ## Kusur
///
/// 2026-09-30'a dek konu karosu yalnız ton + çizgi ikondu, alt konu bandı
/// ise yalnız bazı konularda (çizimi olanlarda) fotoğraf benzeri bir görsel
/// taşıyordu: yedi konu yan yana ortak bir dil söylemiyordu. Kullanıcı ana
/// sayfa için K3 silüetini, alt konu bandı için K1 kilim desenini seçti.
///
/// ## Niçin sessiz kalırdı
///
/// Silüet yolları gen.py taslağından SVG dizgisi olarak taşındı; bir
/// dizgideki yazım hatası ya da eksik komut hiçbir testte patlamaz, karo
/// yalnız yanlış görünür. Konu eşlemesi de tek yerde
/// (`CategoryVisuals.mark`) durmazsa bir konu ikonda, biri silüette kalır.
///
/// ## Neyi korur
///
/// * Her konu için iki ressam da çizer ve konunun kendi rengini boyar
///   (silüet `detail`, desen `deep`/`detail`); yol çözümlemesi çökmez.
/// * Renkler yalnız [SahneCategoryTone]dan gelir: ressam dosyasında ham
///   renk yok.
/// * Eşleme: görünür her konu (ve takma adları) kendi işaretini alır;
///   yalnız bilinmeyen kategori almaz, karo ikona düşer.
///
/// ## 2026-09-30: Siyaset, Paradigma, Teknolojî, Cîhan
///
/// Bu üç konu geri görünür olduğunda işaretsizdi: yedi silüetin yanında
/// tek başına eski ikon + eğik köşe kalıyordu ve ızgara iki dilde
/// konuşuyordu. Kusur sessizdi: hiçbir test "her görünür konunun silüeti
/// var" demiyordu, aksine bu dosya işaretsiz kalmalarını SABİTLİYORDU.
/// Dördüncüsü ('Cîhan', dünya sineması/coğrafyası/tarihi) aynı gün kategori
/// oldu ve kendi tonunu aldı. Bekçi artık `colorDefinedCategories`in
/// her üyesinin işaretli olduğunu ölçer: yeni bir konu eklenip işaret
/// unutulursa burada patlar.
/// * Kilim: desen sağ kenardan taşar (kırpılır), sol taraf düz zemin kalır
///   (başlık okunurluğu) ve görünen genişlik ayrılan yeri aşmaz.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../support/realistic_device.dart';
import 'sahne_harness.dart';

class _Raster {
  _Raster(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final ByteData bytes;

  int at(int x, int y) {
    final i = (y * width + x) * 4;
    return (bytes.getUint8(i) << 24) |
        (bytes.getUint8(i + 1) << 16) |
        (bytes.getUint8(i + 2) << 8) |
        bytes.getUint8(i + 3);
  }
}

int _rgba(Color c) =>
    ((c.r * 255).round() << 24) |
    ((c.g * 255).round() << 16) |
    ((c.b * 255).round() << 8) |
    (c.a * 255).round();

Future<_Raster> _paint(
  WidgetTester tester,
  CustomPainter painter,
  Size size,
) async {
  final raster = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = (await image.toByteData())!;
    return _Raster(image.width, image.height, data);
  });
  return raster!;
}

int _count(_Raster r, Color color, {int x0 = 0, int x1 = -1}) {
  final want = _rgba(color);
  var n = 0;
  for (var y = 0; y < r.height; y++) {
    for (var x = x0; x < (x1 < 0 ? r.width : x1); x++) {
      if (r.at(x, y) == want) n++;
    }
  }
  return n;
}

void main() {
  setUpAll(loadAppFonts);

  final tones = <SahneTopicMark, SahneCategoryTone>{
    SahneTopicMark.ziman: SahneCategoryTone.ziman,
    SahneTopicMark.cand: SahneCategoryTone.cand,
    SahneTopicMark.dirok: SahneCategoryTone.dirok,
    SahneTopicMark.edebiyat: SahneCategoryTone.edebiyat,
    SahneTopicMark.cografya: SahneCategoryTone.cografya,
    SahneTopicMark.muzik: SahneCategoryTone.muzik,
    SahneTopicMark.sinema: SahneCategoryTone.sinema,
    SahneTopicMark.siyaset: SahneCategoryTone.siyaset,
    SahneTopicMark.paradigma: SahneCategoryTone.paradigma,
    SahneTopicMark.teknoloji: SahneCategoryTone.teknoloji,
    // 2026-09-30: 'Cîhan' kategori oldu ve kendi tonunu (deniz petrolü) aldı;
    // sahne gecesi yedeğine düşmesi artık hata sayılır.
    SahneTopicMark.cihan: SahneCategoryTone.cihan,
  };

  group('eşleme (CategoryVisuals.mark)', () {
    test('her görünür konu kendi işaretini alır', () {
      expect(CategoryVisuals.markedCategories.toSet(), {
        'Ziman',
        'Çand',
        'Dîrok',
        'Edebiyat',
        'Cografya',
        'Muzîk',
        'Sînema',
        'Siyaset',
        'Paradigma',
        'Teknolojî',
        'Cîhan',
      });
      for (final category in CategoryVisuals.colorDefinedCategories) {
        expect(
          CategoryVisuals.mark(category),
          isNotNull,
          reason: '$category: görünür konu işaretsiz kalamaz',
        );
      }
      expect(
        CategoryVisuals.markedCategories.map(CategoryVisuals.mark).toSet(),
        SahneTopicMark.values.toSet(),
        reason: 'her işaret tam bir konuya bağlı olmalı',
      );
      for (final category in CategoryVisuals.markedCategories) {
        final mark = CategoryVisuals.mark(category)!;
        expect(tones[mark], CategoryVisuals.tone(category), reason: category);
      }
    });

    test('takma adlar kanonik konunun işaretini alır', () {
      expect(CategoryVisuals.mark('Dil'), SahneTopicMark.ziman);
      expect(CategoryVisuals.mark('Kültür'), SahneTopicMark.cand);
      expect(CategoryVisuals.mark('Tarih'), SahneTopicMark.dirok);
      expect(CategoryVisuals.mark('Wêje'), SahneTopicMark.edebiyat);
      expect(CategoryVisuals.mark('Erdnîgarî'), SahneTopicMark.cografya);
      expect(CategoryVisuals.mark('Müzik'), SahneTopicMark.muzik);
      expect(CategoryVisuals.mark('Sinema'), SahneTopicMark.sinema);
      expect(CategoryVisuals.mark('Paradîgma'), SahneTopicMark.paradigma);
      expect(CategoryVisuals.mark('Teknoloji'), SahneTopicMark.teknoloji);
    });

    test('bilinmeyen kategori işaret almaz (silüet uydurulmaz)', () {
      expect(CategoryVisuals.mark('Bilinmeyen'), isNull);
    });
  });

  group('K3 silüeti', () {
    for (final entry in tones.entries) {
      testWidgets('${entry.key.name}: zemin ve silüet konunun renginde', (
        tester,
      ) async {
        final tone = entry.value;
        final raster = await _paint(
          tester,
          SahneCategoryGlyphPainter(mark: entry.key, tone: tone),
          const Size(160, 160),
        );
        // Köşe düz zemin; silüet detail rengiyle dolar; iç ayrıntı zemin
        // renginde çizilir (silüetin içinde de zemin pikselleri vardır).
        expect(raster.at(2, 2), _rgba(tone.ground));
        final detail = _count(raster, tone.detail);
        expect(detail, greaterThan(160 * 160 * 0.08), reason: 'silüet dolu');
        expect(detail, lessThan(160 * 160 * 0.6), reason: 'silüet taşmamış');
        expect(_count(raster, tone.deep), 0, reason: 'deep silüette yok');
      });
    }

    testWidgets('silüet kutusu karonun %72\'si: kenar boşluğu düz kalır', (
      tester,
    ) async {
      const tone = SahneCategoryTone.dirok;
      final raster = await _paint(
        tester,
        const SahneCategoryGlyphPainter(mark: SahneTopicMark.dirok, tone: tone),
        const Size(100, 100),
      );
      for (var i = 0; i < 100; i++) {
        expect(raster.at(i, 0), _rgba(tone.ground), reason: 'üst satır $i');
        expect(raster.at(0, i), _rgba(tone.ground), reason: 'sol sütun $i');
      }
    });

    testWidgets('karo silüetli çizilir; işaretsiz karo ikona düşer', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const Row(
          children: [
            SahneJewelTile(
              name: 'Ziman',
              icon: AppIcons.language,
              mark: SahneTopicMark.ziman,
              tone: SahneCategoryTone.ziman,
              size: 96,
            ),
            SahneJewelTile(
              name: 'Bilinmeyen',
              icon: AppIcons.scaleBalanced,
              tone: SahneCategoryTone.fallback,
              size: 96,
            ),
          ],
        ),
        dark: true,
        textScale: 1,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SahneCategoryGlyphPainter,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(AppIcons.language), findsNothing);
      expect(find.byIcon(AppIcons.scaleBalanced), findsOneWidget);
    });
  });

  group('K1 kilim bandı', () {
    test('her konunun 9x9 ızgarası var ve yalnız #, o, . içerir', () {
      expect(sahneKilimGrids.keys.toSet(), SahneTopicMark.values.toSet());
      for (final entry in sahneKilimGrids.entries) {
        expect(entry.value, hasLength(9), reason: entry.key.name);
        for (final row in entry.value) {
          expect(row, matches(RegExp(r'^[#o.]{9}$')), reason: entry.key.name);
        }
        expect(
          entry.value.join().contains('#'),
          isTrue,
          reason: '${entry.key.name}: detail hücresi yok',
        );
      }
      expect(
        sahneKilimGrids.values.map((g) => g.join()).toSet(),
        hasLength(SahneTopicMark.values.length),
        reason: 'her konu ayrı bir dokuma motifi',
      );
    });

    for (final entry in tones.entries) {
      testWidgets('${entry.key.name}: desen sağdan taşar, sol düz kalır', (
        tester,
      ) async {
        final tone = entry.value;
        const size = Size(390, 216);
        const reserved = 132.0;
        final raster = await _paint(
          tester,
          SahneKilimBandPainter(
            mark: entry.key,
            tone: tone,
            reservedWidth: reserved,
          ),
          size,
        );
        // Sol yarı yalnız zemin: başlık desenin üstüne binmez.
        final left = (size.width - reserved - 8).floor();
        expect(
          _count(raster, tone.ground, x0: 0, x1: left),
          left * size.height.round(),
          reason: 'sol taraf düz zemin',
        );
        expect(_count(raster, tone.deep), greaterThan(0));
        expect(_count(raster, tone.detail), greaterThan(0));
        // Desen bandın dışına taşar: son sütunda desen pikseli var.
        var edge = 0;
        for (var y = 0; y < raster.height; y++) {
          final p = raster.at(raster.width - 1, y);
          if (p != _rgba(tone.ground)) edge++;
        }
        expect(edge, greaterThan(0), reason: 'sağ kenarda desen görünmeli');
        // 2026-09-30 bant: desen bandın tam yüksekliğindedir; üst ve alt
        // kenar satırında (durum çubuğunun arkası dahil) desen pikseli var.
        for (final y in [0, raster.height - 1]) {
          var ink = 0;
          for (var x = 0; x < raster.width; x++) {
            if (raster.at(x, y) != _rgba(tone.ground)) ink++;
          }
          expect(ink, greaterThan(0), reason: 'y=$y satırında desen yok');
        }
      });
    }

    // Bant her temada gece değerleriyle çizilir; çubuğun gece metinleri
    // (başlık `tx`, alt satır `tx2`) konunun zemininde okunmalı (>= 4,5).
    test('başlık ve alt satır her konunun zemininde >= 4,5:1', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final entry in tones.entries) {
        for (final text in [SahneTokens.night.tx, SahneTokens.night.tx2]) {
          expect(
            contrast(text, entry.value.ground),
            greaterThanOrEqualTo(4.5),
            reason: entry.key.name,
          );
        }
      }
    });

    test('görünen genişlik ayrılan yeri aşmaz', () {
      for (final reserved in [84.0, 132.0]) {
        for (final size in const [
          Size(320, 108),
          Size(390, 108),
          Size(390, 216),
          Size(320, 279),
        ]) {
          final visible = SahneKilimBandPainter.patternRect(
            size,
            reserved,
          ).intersect(Offset.zero & size);
          expect(visible.width, lessThanOrEqualTo(reserved + 0.001));
        }
      }
    });

    // 2026-09-30 bant: hücre bant yüksekliğinin 1/9'u, tam sayı piksel;
    // 9'un katı yükseklikte desen bandın üst ve alt kenarına tam değer.
    test('hücre tam sayı ve desen 9 katı yükseklikte kenardan kenara', () {
      for (final raw in [100.0, 108.0, 131.5, 216.0, 279.0]) {
        final h = SahneKilimBandPainter.snapHeight(raw);
        expect(h % 9, 0);
        expect(h, greaterThanOrEqualTo(raw));
        expect(h - raw, lessThan(9));
        final c = SahneKilimBandPainter.cellFor(h);
        expect(c, c.roundToDouble());
        final rect = SahneKilimBandPainter.patternRect(Size(390, h), 132);
        expect(rect.top, 0, reason: 'h=$h');
        expect(rect.bottom, h, reason: 'h=$h');
      }
    });
  });

  test('ressam dosyasında ham renk yok: her renk SahneCategoryTone\'dan', () {
    final source = File(
      'lib/src/widgets/sahne/sahne_topic_marks.dart',
    ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//'));
    final code = source.join('\n');
    expect(code, isNot(contains('Color(0x')));
    expect(code, isNot(contains('Colors.')));
    expect(code, isNot(contains('Color.fromARGB')));
  });
}
