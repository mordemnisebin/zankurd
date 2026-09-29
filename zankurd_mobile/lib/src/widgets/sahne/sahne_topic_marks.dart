import 'package:flutter/material.dart';

import '../../theme/sahne.dart';

/// Konunun görsel dili: yedi ana konunun her birinin bir silüeti (ana sayfa
/// karosu, [SahneCategoryGlyphPainter]) ve bir kilim motifi (alt konu bandı,
/// [SahneKilimBandPainter]) vardır.
///
/// 2026-09-30 kimlik: karo eskiden yalnız ton + çizgi ikondu; yedi karo
/// yan yana ortak bir dil söylemiyordu. Kullanıcı iki yön seçti: ana sayfada
/// K3 (tek dolu nesne, iki renk), alt konu bandında K1 (dokuma motif).
/// Koordinatlar ve ızgaralar `kimlik/konu/gen.py` taslağından birebir
/// taşındı. Eşleme `CategoryVisuals.mark`ta tek yerde durur; işareti
/// olmayan konu (Siyaset, Paradigma, Teknolojî) çizimi yerine eski ikon +
/// ton hâline düşer.
///
/// Renkler yalnız [SahneCategoryTone]dan gelir: silüet `detail` dolgu, iç
/// ayrıntı `ground` çizgi; motif `deep` alan üstünde `detail` ve `ground`.
/// Karo ve bant kimlik taşır: tema değişse de aynı kalır.
enum SahneTopicMark { ziman, cand, dirok, edebiyat, cografya, muzik, sinema }

/// SVG yol dizgisini [Path]e çevirir. Taslaktaki silüetler yalnız mutlak
/// `M L H V Q T Z` kullanır; dizgiler gen.py'den olduğu gibi kopyalandığı
/// için biçim sapması olmaz.
Path _svgPath(String d) {
  final tokens = RegExp(
    r'[MLHVQTZ]|-?\d*\.?\d+',
  ).allMatches(d).map((m) => m[0]!).toList();
  final path = Path();
  var i = 0;
  double num() => double.parse(tokens[i++]);
  var x = 0.0, y = 0.0;
  // Son ikinci derece denetim noktası (T için yansıtılır).
  double? qx, qy;
  String? cmd;
  while (i < tokens.length) {
    if (RegExp(r'[A-Z]').hasMatch(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M':
        x = num();
        y = num();
        path.moveTo(x, y);
        cmd = 'L';
        qx = qy = null;
      case 'L':
        x = num();
        y = num();
        path.lineTo(x, y);
        qx = qy = null;
      case 'H':
        x = num();
        path.lineTo(x, y);
        qx = qy = null;
      case 'V':
        y = num();
        path.lineTo(x, y);
        qx = qy = null;
      case 'Q':
        final cx = num(), cy = num();
        x = num();
        y = num();
        path.quadraticBezierTo(cx, cy, x, y);
        qx = cx;
        qy = cy;
      case 'T':
        final cx = qx == null ? x : 2 * x - qx;
        final cy = qy == null ? y : 2 * y - qy;
        x = num();
        y = num();
        path.quadraticBezierTo(cx, cy, x, y);
        qx = cx;
        qy = cy;
      case 'Z':
        path.close();
        qx = qy = null;
      default:
        throw FormatException('Desteklenmeyen yol komutu: $cmd');
    }
  }
  return path;
}

/// K3 silüetinin 64x64 kutudaki parçaları.
class _Glyph {
  _Glyph({
    this.fill = const [],
    this.line = const [],
    this.holes = const [],
    this.strokeFill = const [],
    this.holeRects = const [],
    this.holeCircles = const [],
    this.rotateDegrees = 0,
  });

  /// Silüet renginde dolu yollar.
  final List<Path> fill;

  /// Zemin renginde tek kalınlıklı iç ayrıntı çizgileri.
  final List<Path> line;

  /// Zemin renginde dolu delikler (yol).
  final List<Path> holes;

  /// Silüet renginde, sabit kalınlıkta çizgi (çaydanlık kulpu).
  final List<Path> strokeFill;
  final List<Rect> holeRects;
  final List<(Offset, double)> holeCircles;

  /// Tembûr: kutu merkezinde (32, 32) döndürülür, 1 birim aşağı kayar.
  final double rotateDegrees;
}

Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(x, y, w, h);

final Map<SahneTopicMark, _Glyph> _glyphs = {
  SahneTopicMark.ziman: _Glyph(
    fill: [_svgPath('M12 6H52L58 12V40L52 46H30L16 58V46H12L6 40V12Z')],
    line: [
      _svgPath('M26 22V38M26 22H39M26 30H37M26 38H39M27 16.5L32.5 12L38 16.5'),
    ],
  ),
  SahneTopicMark.cand: _Glyph(
    fill: [
      _svgPath(
        'M12 34Q12 28 18 28H42Q48 28 48 34V46Q48 54 40 54H20Q12 54 12 46Z',
      ),
      _svgPath('M21 28V21Q21 15 30 15Q39 15 39 21V28Z'),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(30, 9.5), radius: 3.6)),
      _svgPath('M13 46L3 27L8.5 24.5L15 36Z'),
    ],
    strokeFill: [_svgPath('M48 33Q60 33 59 43Q58 50 47 50')],
    line: [_svgPath('M17 41H43')],
  ),
  SahneTopicMark.dirok: _Glyph(
    fill: [
      _svgPath('M16 58V10H23.5V18H28.5V10H35.5V18H40.5V10H48V58Z'),
      _svgPath('M3 58V34H16V58Z'),
      _svgPath('M48 58V34H61V58Z'),
    ],
    holes: [_svgPath('M27 58V47Q27 41 32 41Q37 41 37 47V58Z')],
    line: [_svgPath('M32 25V31M9.5 43V49M54.5 43V49')],
  ),
  SahneTopicMark.edebiyat: _Glyph(
    fill: [
      _svgPath('M3 12Q17 11 29.5 18V54Q17 47 3 48Z'),
      _svgPath('M61 12Q47 11 34.5 18V54Q47 47 61 48Z'),
      _svgPath('M29.5 54V61L32 58.5L34.5 61V54Z'),
    ],
    line: [
      _svgPath(
        'M9 22Q17 22 24 26M9 30Q17 30 24 34M9 38Q17 38 24 42'
        'M55 22Q47 22 40 26M55 30Q47 30 40 34M55 38Q47 38 40 42',
      ),
    ],
  ),
  SahneTopicMark.cografya: _Glyph(
    fill: [_svgPath('M1 58L18 34L26 43L38 13L52 40L58 33L63 58Z')],
    line: [
      _svgPath(
        'M32 26L35 30.5L38.5 25.5L41.5 30.5L45 27M6 53Q18 47 29 52T57 51',
      ),
    ],
  ),
  SahneTopicMark.muzik: _Glyph(
    rotateDegrees: 36,
    fill: [
      _svgPath('M32 62Q17 62 17 48Q17 40 26 36L38 36Q47 40 47 48Q47 62 32 62Z'),
      _svgPath('M29.7 8H34.3V38H29.7Z'),
      _svgPath('M26 2H38L39.5 4V9L37.5 11H26.5L24.5 9V4Z'),
    ],
    holeCircles: const [
      (Offset(32, 49), 4.4),
      (Offset(29, 6.5), 1.5),
      (Offset(35, 6.5), 1.5),
    ],
  ),
  SahneTopicMark.sinema: _Glyph(
    fill: [_svgPath('M6 14H52L58 20V50H12L6 44Z')],
    holeRects: [
      for (final y in const [17.5, 42.0])
        for (final x in const [11.0, 20.5, 30.0, 39.5, 49.0])
          _r(x, y, 4.6, 4.6),
      _r(11, 26, 19, 12.5),
      _r(34, 26, 19, 12.5),
    ],
  ),
};

/// K3: konu başına tek dolu silüet ([SahneCategoryTone.detail]), iç ayrıntı
/// zemin renginde ([SahneCategoryTone.ground]) tek kalınlıklı çizgi. Gölge,
/// gradyan ve üçüncü renk yok.
///
/// Silüet karonun kısa kenarının %72'sidir; taslakta (100 birimlik karo)
/// sol üst köşe (14, 12)dir. Çizgi kalınlığı karo boyutuyla orantılıdır
/// (%2,9; en az 1,5 px) — küçük karoda çizgi kaybolmaz, büyükte kalınlaşmaz.
class SahneCategoryGlyphPainter extends CustomPainter {
  const SahneCategoryGlyphPainter({required this.mark, required this.tone});

  final SahneTopicMark mark;
  final SahneCategoryTone tone;

  /// Silüet kutusunun karoya oranı, sol/üst ofseti ve çizgi kalınlığı.
  static const double extent = 0.72;
  static const double offsetX = 0.14;
  static const double offsetY = 0.12;
  static const double strokeRatio = 0.029;
  static const double minStroke = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = tone.ground);
    final g = _glyphs[mark]!;
    final side = size.shortestSide;
    final s = side * extent / 64;
    final strokeBox =
        (side * strokeRatio).clamp(minStroke, double.infinity) / s;
    final fg = Paint()..color = tone.detail;
    final bg = Paint()..color = tone.ground;
    final line = Paint()
      ..color = tone.ground
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeBox
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final handle = Paint()
      ..color = tone.detail
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.4
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(
      (size.width - side) / 2 + side * offsetX,
      (size.height - side) / 2 + side * offsetY,
    );
    canvas.scale(s);
    if (g.rotateDegrees != 0) {
      const c = Offset(32, 32);
      canvas
        ..translate(c.dx, c.dy)
        ..rotate(g.rotateDegrees * 3.141592653589793 / 180)
        ..translate(-c.dx, -c.dy)
        ..translate(0, 1);
    }
    for (final p in g.fill) {
      canvas.drawPath(p, fg);
    }
    for (final p in g.strokeFill) {
      canvas.drawPath(p, handle);
    }
    for (final p in g.holes) {
      canvas.drawPath(p, bg);
    }
    for (final r in g.holeRects) {
      canvas.drawRect(r, bg);
    }
    for (final (center, radius) in g.holeCircles) {
      canvas.drawCircle(center, radius, bg);
    }
    for (final p in g.line) {
      canvas.drawPath(p, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SahneCategoryGlyphPainter old) =>
      old.mark != mark || old.tone != tone;
}

/// K1 motif ızgaraları (9x9). `#` = [SahneCategoryTone.detail], `o` = konu
/// zemini ([SahneCategoryTone.ground]), `.` = [SahneCategoryTone.deep]
/// alanı. Yedi konunun yedi ayrı dokuma biçimi: sarmal (Ziman), yıldız
/// (Çand), basamak (Dîrok), zikzak (Wêje), dişli dağ (Erdnîgarî), dama
/// (Muzîk), sekizgen halka (Sînema).
const Map<SahneTopicMark, List<String>> sahneKilimGrids = {
  SahneTopicMark.ziman: [
    '#########',
    '........#',
    '#######.#',
    '#.....#.#',
    '#.##o.#.#',
    '#.#...#.#',
    '#.#####.#',
    '#.......#',
    '#########',
  ],
  SahneTopicMark.cand: [
    '#...#...#',
    '.#..#..#.',
    '..#####..',
    '..#ooo#..',
    '###o#o###',
    '..#ooo#..',
    '..#####..',
    '.#..#..#.',
    '#...#...#',
  ],
  SahneTopicMark.dirok: [
    '....o....',
    '.........',
    '....#....',
    '...###...',
    '..#####..',
    '.#######.',
    '#########',
    '.........',
    '#########',
  ],
  SahneTopicMark.edebiyat: [
    '#o.###.o#',
    '##o.#.o##',
    '.##o.o##.',
    'o.##o##.o',
    '#o.###.o#',
    '##o.#.o##',
    '.##o.o##.',
    'o.##o##.o',
    '#o.###.o#',
  ],
  SahneTopicMark.cografya: [
    '..#...#..',
    '.###.###.',
    '#########',
    '.........',
    '#...#...#',
    '##.###.##',
    '#########',
    '.........',
    '#########',
  ],
  SahneTopicMark.muzik: [
    '#.#.#.#.#',
    '.o.o.o.o.',
    '#.#.#.#.#',
    '.o.o.o.o.',
    '#.#.#.#.#',
    '.o.o.o.o.',
    '#.#.#.#.#',
    '.o.o.o.o.',
    '#.#.#.#.#',
  ],
  SahneTopicMark.sinema: [
    '..#####..',
    '.##...##.',
    '##.###.##',
    '#.##o##.#',
    '#.#o#o#.#',
    '#.##o##.#',
    '##.###.##',
    '.##...##.',
    '..#####..',
  ],
};

/// K1: alt konu bandının sağ kenarından taşan kilim deseni. Bant zemini
/// konunun tonudur ([SahneCategoryTone.ground]); 9x9 motif `deep` alan
/// üstünde `detail` ve `ground` hücreleriyle örülür.
///
/// Yerleşim taslağın (402x160 bant, 18 px hücre) oranlarını korur:
/// motifin merkezi sağ kenardan [centerInset] hücre içeridedir, dolayısıyla
/// desenin dış kenarı bandın dışına taşar ve kırpılır. Uygulamada bantta
/// başlık da durduğu için hücre biraz küçüktür ([heightCells]) ve desenin
/// görünen genişliği [reservedWidth]'i aşmaz: başlık çubuğu o kadar yer
/// bırakır, yani metin desenin üstüne binmez. [topInset] durum çubuğu
/// payıdır: desen onun altında kalır (saat ve pil düz zemin üstünde okunur).
class SahneKilimBandPainter extends CustomPainter {
  const SahneKilimBandPainter({
    required this.mark,
    required this.tone,
    required this.reservedWidth,
    this.topInset = 0,
  });

  final SahneTopicMark mark;
  final SahneCategoryTone tone;

  /// Desenin görünen genişliğinin üst sınırı (px); çubuk bu kadar yer bırakır.
  final double reservedWidth;
  final double topInset;

  /// Desenin yüksekliği, kullanılabilir bant yüksekliğinin 1/[heightCells]
  /// katı hücreyle dokunur (9 hücre + kenar boşluğu).
  static const double heightCells = 9.8;

  /// Merkezin sağ kenara uzaklığı (hücre); taslakta 78 / 18.
  static const double centerInset = 78 / 18;

  static const int _cells = 9;

  /// Desenin bandın içinde kalan hücre sayısı.
  static const double visibleCells = centerInset + _cells / 2;

  /// Verilen bant için hücre boyu.
  static double cellFor(Size size, double topInset, double reservedWidth) {
    final byHeight = (size.height - topInset) / heightCells;
    final byWidth = reservedWidth / visibleCells;
    return byHeight < byWidth ? byHeight : byWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = tone.ground);
    final grid = sahneKilimGrids[mark]!;
    final n = grid.length;
    final c = cellFor(size, topInset, reservedWidth);
    final x0 = size.width - centerInset * c - n / 2 * c;
    final y0 = topInset + (size.height - topInset - n * c) / 2;
    canvas.drawRect(
      Rect.fromLTWH(x0, y0, n * c, n * c),
      Paint()..color = tone.deep,
    );
    // Hücre kenarlarında yumuşatma dikişi kalmasın: her hücre sağa/aşağı
    // çeyrek piksel taşar (üstteki hücre altta kalanı örter).
    const seam = 0.25;
    for (final (char, color) in [('#', tone.detail), ('o', tone.ground)]) {
      final path = Path();
      for (var j = 0; j < n; j++) {
        var i = 0;
        while (i < n) {
          if (grid[j][i] != char) {
            i++;
            continue;
          }
          var k = i;
          while (k < n && grid[j][k] == char) {
            k++;
          }
          path.addRect(
            Rect.fromLTWH(x0 + i * c, y0 + j * c, (k - i) * c + seam, c + seam),
          );
          i = k;
        }
      }
      canvas.drawPath(path, Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SahneKilimBandPainter old) =>
      old.mark != mark ||
      old.tone != tone ||
      old.reservedWidth != reservedWidth ||
      old.topInset != topInset;
}
