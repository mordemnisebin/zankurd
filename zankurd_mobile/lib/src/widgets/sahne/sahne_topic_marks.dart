import 'package:flutter/material.dart';

import '../../theme/sahne.dart';

/// Konunun görsel dili: her konunun (yedi ana konu + Siyaset, Paradigma,
/// Teknolojî, Cîhan) bir silüeti (ana sayfa
/// karosu, [SahneCategoryGlyphPainter]) ve bir kilim motifi (alt konu bandı,
/// [SahneKilimBandPainter]) vardır.
///
/// 2026-09-30 kimlik: karo eskiden yalnız ton + çizgi ikondu; yedi karo
/// yan yana ortak bir dil söylemiyordu. Kullanıcı iki yön seçti: ana sayfada
/// K3 (tek dolu nesne, iki renk), alt konu bandında K1 (dokuma motif).
/// Koordinatlar ve ızgaralar `kimlik/konu/gen.py` taslağından birebir
/// taşındı. Eşleme `CategoryVisuals.mark`ta tek yerde durur; işareti
/// olmayan (bilinmeyen) kategori eski ikon + ton hâline düşer.
///
/// Sonradan gelen dört işaret aynı dilde çizildi (2026-09-30): tek dolu
/// gövde, tek kalınlıkta zemin renginde iç çizgi, 64 birimlik kutuda
/// pahlı köşe. Parti, bayrak ya da ideolojik simge yok — uygulama her
/// görüşten Kürde hitap eder. Siyaset: katlı köşeli kâğıt sandığın ağzına
/// düşer (sivil eylem); Paradigma: dallanan ağaçlı ampul (fikir);
/// Teknolojî: yonga (cihaz/devre); Cîhan: enlem-boylam çizgili küre.
///
/// Renkler yalnız [SahneCategoryTone]dan gelir: silüet `detail` dolgu, iç
/// ayrıntı `ground` çizgi; motif `deep` alan üstünde `detail` ve `ground`.
/// Karo ve bant kimlik taşır: tema değişse de aynı kalır.
enum SahneTopicMark {
  ziman,
  cand,
  dirok,
  edebiyat,
  cografya,
  muzik,
  sinema,
  siyaset,
  paradigma,
  teknoloji,
  cihan,
}

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
  // Sandık: katlı köşeli kâğıt sandığın ağzına düşer. Parti, bayrak ya da
  // simge yok; her görüşten seçmen için aynı sivil eylem.
  SahneTopicMark.siyaset: _Glyph(
    fill: [
      _svgPath('M8 34H56V58L54 60H10L8 58Z'),
      _svgPath('M19 3H40L45 8V29H19Z'),
    ],
    line: [_svgPath('M17 43H47M25 17L30 22L38 11')],
  ),
  // Ampul içinde dallanan bir ağaç: düşünce ve dallanan fikir.
  SahneTopicMark.paradigma: _Glyph(
    fill: [
      _svgPath('M32 3Q51 3 51 22Q51 32 43 39V46H21V39Q13 32 13 22Q13 3 32 3Z'),
      _svgPath('M22 50H42V54Q42 59 37 59H27Q22 59 22 54Z'),
    ],
    line: [_svgPath('M32 40V19M32 33L23 24M32 28L41 19')],
  ),
  // Yonga: gövde, her kenarda üç bacak, içinde çekirdek ve 1. bacak çentiği.
  SahneTopicMark.teknoloji: _Glyph(
    fill: [
      _svgPath('M17 12H47L52 17V47L47 52H17L12 47V17Z'),
      for (final p in const [21.0, 30.0, 39.0]) ...[
        Path()..addRect(_r(p, 3, 4, 10)), // üst
        Path()..addRect(_r(p, 51, 4, 10)), // alt
        Path()..addRect(_r(3, p, 10, 4)), // sol
        Path()..addRect(_r(51, p, 10, 4)), // sağ
      ],
    ],
    line: [_svgPath('M24 24H40V40H24Z')],
  ),
  // Küre: bir boylam halkası ile ekvator ve iki enlem yayı.
  SahneTopicMark.cihan: _Glyph(
    fill: [
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(32, 32), radius: 28)),
    ],
    line: [
      _svgPath(
        'M32 4Q46 4 46 32Q46 60 32 60Q18 60 18 32Q18 4 32 4'
        'M2 32H62M6 17Q32 24 58 17M6 47Q32 40 58 47',
      ),
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

/// Konunun KÜÇÜK işareti: [SahneCategoryGlyphPainter]ın yuvarlak köşeli
/// küçük karosu (soru künyesi, satır başı). Ana sayfa karosundaki silüetin
/// aynısıdır — künyede genel bir Material ikonu durunca (Siyaset için
/// "terazi") aynı konu iki ayrı çizimle anlatılıyordu (2026-10-01 tasarım
/// denetimi).
///
/// Kare [size] kenarlıdır; silüet karonun %72'si olduğundan 28'de ~20 px
/// çizilir ve iç çizgi en az 1,5 px kalır. Ekran okuyucudan gizlenir: konu
/// adı yanındaki metinde zaten yazar.
class SahneTopicMarkBadge extends StatelessWidget {
  const SahneTopicMarkBadge({
    super.key,
    required this.mark,
    required this.tone,
    this.size = 28,
  });

  final SahneTopicMark mark;
  final SahneCategoryTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.25),
          child: CustomPaint(
            painter: SahneCategoryGlyphPainter(mark: mark, tone: tone),
          ),
        ),
      ),
    );
  }
}

/// K1 motif ızgaraları (9x9). `#` = [SahneCategoryTone.detail], `o` = konu
/// zemini ([SahneCategoryTone.ground]), `.` = [SahneCategoryTone.deep]
/// alanı. Her konunun ayrı bir dokuma biçimi: sarmal (Ziman), yıldız
/// (Çand), basamak (Dîrok), zikzak (Wêje), dişli dağ (Erdnîgarî), dama
/// (Muzîk), sekizgen halka (Sînema), ikili kemer dizisi (Siyaset), dallanan
/// Y (Paradigma), devre izi (Teknolojî), enlem-boylam kafesi (Cîhan).
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
  SahneTopicMark.siyaset: [
    '#########',
    '##.###.##',
    '#...#...#',
    '#...#...#',
    '#...#...#',
    '#...#...#',
    '#########',
    '.........',
    '#########',
  ],
  SahneTopicMark.paradigma: [
    '#.......#',
    '.#.....#.',
    '..#...#..',
    '...#.#...',
    '....#....',
    '#...#...#',
    '.#..#..#.',
    '..#.#.#..',
    '...###...',
  ],
  SahneTopicMark.teknoloji: [
    '###......',
    '#o####...',
    '###..#...',
    '.....#.##',
    '##...#.#o',
    '#o####.##',
    '##....#..',
    '......#..',
    'o#####...',
  ],
  SahneTopicMark.cihan: [
    '..#####..',
    '.#.#.#.#.',
    '#..#.#..#',
    '#..#.#..#',
    '#########',
    '#..#.#..#',
    '#..#.#..#',
    '.#.#.#.#.',
    '..#####..',
  ],
};

/// K1: alt konu bandının sağ kenarından taşan kilim deseni. Bant zemini
/// konunun tonudur ([SahneCategoryTone.ground]); 9x9 motif `deep` alan
/// üstünde `detail` ve `ground` hücreleriyle örülür.
///
/// 2026-09-30 bant: desen bandın TAM yüksekliğindedir (üst kenardan alt
/// kenara; ekran durum çubuğu payını bu ressamın DIŞINDA düz tonla boyar,
/// desen saat ve pil simgelerinin arkasına girmez): hücre boyu bant yüksekliğinin 1/9'u,
/// tam sayı piksele yuvarlanır (kenarlar keskin kalsın). Bandı çizen ekran
/// yüksekliği 9'un katına yükseltir, böylece yuvarlama payı kalmaz ve desen
/// iki kenara da tam değer. Eskiden desen bandın ortasında küçük bir blok
/// olarak duruyor, altında büyük bir boşluk kalıyordu.
///
/// Yatayda merkez sağ kenardan [centerInset] hücre içeridedir (taslak: 402
/// px bant, 18 px hücre, 78 px), yani desenin dış kenarı bandın dışına taşar
/// ve kırpılır. Görünen genişlik [reservedWidth]'i aşmaz: çubuk o kadar yer
/// bırakır ve metin desenin üstüne binmez. Hücre büyüdüğünde (büyük yazıda
/// bant uzar) desen sola değil sağa doğru daha çok kırpılır, yani daha az
/// sütun görünür.
class SahneKilimBandPainter extends CustomPainter {
  const SahneKilimBandPainter({
    required this.mark,
    required this.tone,
    required this.reservedWidth,
  });

  final SahneTopicMark mark;
  final SahneCategoryTone tone;

  /// Desenin görünen genişliğinin üst sınırı (px); çubuk bu kadar yer bırakır.
  final double reservedWidth;

  /// Merkezin sağ kenara uzaklığı (hücre); taslakta 78 / 18.
  static const double centerInset = 78 / 18;

  static const int _cells = 9;

  /// Desenin bandın içinde kalan hücre sayısı (kırpma öncesi).
  static const double visibleCells = centerInset + _cells / 2;

  /// Bandı 9'un katına yükseltir: hücre tam sayı piksel olur ve desen iki
  /// kenara tam değer.
  static double snapHeight(double height) =>
      (height / _cells).ceilToDouble() * _cells;

  /// [height] yüksekliğindeki bant için hücre boyu: yüksekliğin 1/9'u, tam
  /// sayı piksele yuvarlanmış (en az 1).
  static double cellFor(double height) {
    final c = (height / _cells).roundToDouble();
    return c < 1 ? 1 : c;
  }

  /// Desenin bant koordinatlarındaki kırpılmamış dikdörtgeni: yükseklik
  /// 9 hücre, üstü bandın üstü ([height] 9'un katıysa alt kenarı bandın alt
  /// kenarı). Sol kenarı hiçbir zaman `genişlik - reservedWidth`in soluna
  /// geçmez.
  static Rect patternRect(Size size, double reservedWidth) {
    final c = cellFor(size.height);
    final left = (size.width - visibleCells * c) > (size.width - reservedWidth)
        ? (size.width - visibleCells * c)
        : (size.width - reservedWidth);
    return Rect.fromLTWH(
      left.roundToDouble(),
      ((size.height - _cells * c) / 2).roundToDouble(),
      _cells * c,
      _cells * c,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = tone.ground);
    final grid = sahneKilimGrids[mark]!;
    final n = grid.length;
    final c = cellFor(size.height);
    final rect = patternRect(size, reservedWidth);
    final x0 = rect.left;
    final y0 = rect.top;
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
      old.reservedWidth != reservedWidth;
}
