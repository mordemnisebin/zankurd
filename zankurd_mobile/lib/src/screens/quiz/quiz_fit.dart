import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/sahne.dart';

/// SORU SIĞDIRMA (2026-10-29, kullanıcı engelleyicisi): "Soru ekranında
/// sorular tam gözükmüyor, kaydırmak gerekiyor. Taşma, iç içe geçme, tam
/// görünmeme kesinlikle olmasın."
///
/// Kusur: soru kartı + dört şık sabit boyda çiziliyordu; bankadaki en uzun
/// soru 269, en uzun şık 121 karakter. İPhone SE'de (375×667) yüz karakterlik
/// bir soru + dört uzun şık kayan alanı 150–600 pt aşıyor, son şık ekranın
/// dışında kalıyordu. Eski bekçiler "kaydırılabilir" diyerek kusuru kabul
/// ediyordu (`soru_sigma_test` bunu tersine çevirir).
///
/// Çare: soru ve şık yazısı, içinde durdukları alana göre BİR KADEME küçülür.
/// Kademe çizimden ÖNCE, aynı karede, metnin gerçek genişlikte ölçülmesiyle
/// seçilir (bkz. [QuizFit.choose]); ikinci karede değişmez, yani soru
/// geldikten sonra yerinden OYNAMAZ. Yazı tabanı: soru ≥ 17, şık ≥ 15
/// çizilen punto. Renk, kabartma ve kimlik değişmez; yalnız boy ve boşluk.
///
/// Yazı ölçeği > [maxAccessibleScale] ise kademe uygulanmaz: erişilebilirlik
/// için kullanıcının büyük yazısı küçültülmez, alan kayar (son çare).
@immutable
class QuizFit {
  const QuizFit({
    this.level = 0,
    this.questionScale = 1,
    this.optionScale = 1,
    this.promptPad = 16,
    this.sectionGap = 16,
    this.optionGap = 12,
    this.optionMinHeight = 60,
    this.optionVPad = 8,
    this.promptLineHeight,
    this.optionLineHeight,
    this.outerPad = 16,
    this.fits = true,
  });

  /// 0 = tam boy. Üst sınır [maxLevel].
  final int level;

  /// Soru yazısına uygulanan ek ölçek (≤ 1).
  final double questionScale;

  /// Şık yazısına uygulanan ek ölçek (≤ 1).
  final double optionScale;

  /// Soru kartının iç boşluğu.
  final double promptPad;

  /// Soru kartı ile şıklar arası.
  final double sectionGap;

  /// Şıklar arası.
  final double optionGap;

  /// Şık çubuğunun en az boyu (dokunma hedefi ≥ 48).
  final double optionMinHeight;

  /// Şık içindeki dikey boşluk.
  final double optionVPad;

  /// Satır yüksekliği / punto oranı (null = tasarım sistemi değeri). Dar
  /// kademelerde 1,5'tan 1,18'e iner; metin kutusu sıkışır, harf boyu değil.
  final double? promptLineHeight;
  final double? optionLineHeight;

  /// Soru bloğunun kayan alanın üstüne ve altına bıraktığı boşluk (her biri).
  final double outerPad;

  /// `false`: hiçbir kademe alana sığmadı (alan kayar). Sessiz değil, açık
  /// sonuç: bekçi ve taramalar bunu sayar.
  final bool fits;

  QuizFit withFits(bool value) => QuizFit(
    level: level,
    questionScale: questionScale,
    optionScale: optionScale,
    promptPad: promptPad,
    sectionGap: sectionGap,
    optionGap: optionGap,
    optionMinHeight: optionMinHeight,
    optionVPad: optionVPad,
    promptLineHeight: promptLineHeight,
    optionLineHeight: optionLineHeight,
    outerPad: outerPad,
    fits: value,
  );

  static const QuizFit nominal = QuizFit();

  static const int maxLevel = 6;

  /// Kısa ekranda (yükseklik < 700) tam boy kademesinin şık dikey boşluğu.
  static const double shortOptionVPad = 4;

  /// Bu yazı ölçeğinin üstünde kademe uygulanmaz.
  static const double maxAccessibleScale = 1.35;

  /// Çizilen en küçük soru / şık puntosu.
  static const double minQuestionPt = 17;
  static const double minOptionPt = 15;

  bool get isNominal => level == 0;

  /// [level] kademesinin değerleri. [base] kullanıcının yazı ölçeği.
  static QuizFit forLevel(int level, TextScaler base, {bool short = false}) {
    if (level <= 0) {
      return short ? const QuizFit(optionVPad: shortOptionVPad) : nominal;
    }
    final t = level / maxLevel;
    double lerp(double a, double b) => a + (b - a) * t;
    // Taban: SahneType.headline (22) ve gövde (16) çizilen ≥ 17 / 15 kalsın.
    // Doğrusal olmayan ölçekleyicide (Android 14) punto başına ölçek farklıdır:
    // gerçek ölçek `base.scale(punto)` ile alınır.
    final qMin = (minQuestionPt / base.scale(22)).clamp(0.5, 1.0);
    final oMin = (minOptionPt / base.scale(16)).clamp(0.5, 1.0);
    return QuizFit(
      level: level,
      questionScale: lerp(1, qMin),
      optionScale: lerp(1, oMin),
      promptPad: level >= 6 ? 4 : (level >= 5 ? 8 : (level >= 3 ? 10 : 12)),
      sectionGap: level >= 6 ? 4 : (level >= 5 ? 6 : (level >= 3 ? 8 : 12)),
      optionGap: level >= 6 ? 2 : (level >= 5 ? 4 : (level >= 3 ? 6 : 8)),
      // Dokunma tabanı HER kademede 48 (Android 48 dp).
      optionMinHeight: level >= 2 ? 48 : 52,
      optionVPad: level >= 6 ? 0 : (level >= 3 ? 2 : 4),
      promptLineHeight: const [null, null, 1.2, 1.15, 1.1, 1.1, 1.04][level],
      optionLineHeight: const [null, null, 1.35, 1.28, 1.22, 1.18, 1.1][level],
      outerPad: level >= 6 ? 0 : (level >= 5 ? 4 : (level >= 4 ? 8 : 16)),
    );
  }

  /// Soru + şıkların bu kademede tahmini boyu ([width]: sütun genişliği).
  /// Çizimle AYNI biçimler ve AYNI genişlikler kullanılır; bekçi
  /// (`soru_sigma_test`) sapmayı yakalar.
  double estimate({
    required BuildContext context,
    required String prompt,
    required List<String> answers,
    required double width,
    required TextScaler base,
    required bool listenButton,
    required int titleLineBudget,
    double extraInPrompt = 0,
  }) {
    // Her yapılandırmada 36–72 TextPainter koşardı; girdilerle önbelleğe alınır.
    // Anahtar: metinler İÇERİKLE (hash değil), bütün kademe alanları ve
    // ölçekleyicinin birkaç punto için gerçek çıktısı (doğrusal olmayan
    // ölçekleyiciler dahil).
    final key = _FitKey([
      level,
      questionScale,
      optionScale,
      promptPad,
      sectionGap,
      optionGap,
      optionMinHeight,
      optionVPad,
      promptLineHeight,
      optionLineHeight,
      outerPad,
      width,
      listenButton,
      titleLineBudget,
      extraInPrompt,
      for (final pt in const [11.0, 14.0, 16.0, 22.0, 26.0]) base.scale(pt),
      DefaultTextStyle.of(context).style,
      prompt,
      ...answers,
    ]);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return hit;
    }
    final v = _estimate(
      context: context,
      prompt: prompt,
      answers: answers,
      width: width,
      base: base,
      listenButton: listenButton,
      titleLineBudget: titleLineBudget,
      extraInPrompt: extraInPrompt,
    );
    _cache[key] = v;
    if (_cache.length > 600) _cache.remove(_cache.keys.first);
    return v;
  }

  static final Map<_FitKey, double> _cache = {};

  double _estimate({
    required BuildContext context,
    required String prompt,
    required List<String> answers,
    required double width,
    required TextScaler base,
    required bool listenButton,
    required int titleLineBudget,
    double extraInPrompt = 0,
  }) {
    final qScaler = _Compose(base, questionScale);
    final oScaler = _Compose(base, optionScale);
    // Kart çerçevesi (1 pt) iç genişlikten ve boydan düşer.
    final promptWidth = width - 2 * promptPad - 2 - (listenButton ? 56 : 0);
    const headline = SahneType.headline;
    final title = SahneType.question.copyWith(letterSpacing: -0.24);
    final dts = DefaultTextStyle.of(context).style;
    double measure(TextStyle s, String text, double w, TextScaler sc) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: dts.merge(s).copyWith(fontFamily: s.fontFamily),
        ),
        textDirection: TextDirection.ltr,
        textScaler: sc,
      )..layout(maxWidth: w);
      final h = p.height;
      p.dispose();
      return h;
    }

    int lines(TextStyle s, String text, double w, TextScaler sc) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: dts.merge(s).copyWith(fontFamily: s.fontFamily),
        ),
        textDirection: TextDirection.ltr,
        textScaler: sc,
      )..layout(maxWidth: w);
      final n = p.computeLineMetrics().length;
      p.dispose();
      return n;
    }

    final useHeadline =
        lines(title, prompt, promptWidth, qScaler) > titleLineBudget;
    final promptH = measure(
      (useHeadline ? headline : title).copyWith(height: promptLineHeight),
      prompt,
      promptWidth,
      qScaler,
    );
    final card =
        2 * promptPad +
        2 +
        (listenButton && promptH < 48 ? 48 : promptH) +
        extraInPrompt;

    // Şık metni: sol boşluk 8 + harf 36 + 12 + sağ 12 = 68.
    final textWidth = width - 68;
    var options = 0.0;
    for (final a in answers) {
      final textH = measure(
        SahneType.bodyStrong.copyWith(height: optionLineHeight),
        a,
        textWidth,
        oScaler,
      );
      final tile = (2 * optionVPad + (textH < 36 ? 36 : textH)).clamp(
        optionMinHeight,
        double.infinity,
      );
      options += tile + optionGap;
    }
    return 2 * outerPad + card + sectionGap + options;
  }

  /// Kullanılabilir [available] yüksekliğe sığan EN BÜYÜK kademe.
  /// Hiçbiri sığmazsa son kademe (alan kayar).
  static QuizFit choose({
    required BuildContext context,
    required String prompt,
    required List<String> answers,
    required double width,
    required double available,
    required bool listenButton,
    required int titleLineBudget,
    bool short = false,
    double extraInPrompt = 0,
  }) {
    final base = MediaQuery.textScalerOf(context);
    final scale = base.scale(16) / 16;
    if (scale > maxAccessibleScale || !available.isFinite) return nominal;
    for (var k = 0; k <= maxLevel; k++) {
      final fit = forLevel(k, base, short: short);
      final h = fit.estimate(
        context: context,
        prompt: prompt,
        answers: answers,
        width: width,
        base: base,
        listenButton: listenButton,
        titleLineBudget: titleLineBudget,
        extraInPrompt: extraInPrompt,
      );
      if (h <= available) return fit;
    }
    return forLevel(maxLevel, base, short: short).withFits(false);
  }

  @override
  bool operator ==(Object other) =>
      other is QuizFit &&
      other.level == level &&
      other.questionScale == questionScale &&
      other.optionScale == optionScale;

  @override
  int get hashCode => Object.hash(level, questionScale, optionScale);
}

/// Kullanıcının yazı ölçeğine [factor] kadar ek çarpan.
class _Compose extends TextScaler {
  const _Compose(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => scale(14) / 14;
}

/// Bir soru kutusunun [QuizFit]ini alt ağaca taşır.
class QuizFitScope extends InheritedWidget {
  const QuizFitScope({super.key, required this.fit, required super.child});

  final QuizFit fit;

  static QuizFit of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<QuizFitScope>()?.fit ??
      QuizFit.nominal;

  /// Dışarıdan da kullanılsın: [base] ölçeğine [factor] ekler.
  static TextScaler scaled(TextScaler base, double factor) =>
      factor == 1 ? base : _Compose(base, factor);

  @override
  bool updateShouldNotify(QuizFitScope old) => old.fit != fit;
}

/// Tek satırlık ad/etiket: sığmazsa küçülür AMA okunur tabanın (11 pt)
/// altına inmez; taban da yetmezse en çok [maxLines] satıra sarar ve son çare
/// üç nokta. Eskiden `FittedBox` sınırsız küçültüyordu (okunmaz ölçü).
class QuizFitLine extends StatelessWidget {
  const QuizFitLine(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final AlignmentGeometry alignment;

  /// Çizilen en küçük punto.
  static const double _minPt = 11;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final fs = style.fontSize ?? 14;
        final base = DefaultTextStyle.of(context).style.merge(style);
        double widthAt(double size) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: base.copyWith(
                fontFamily: style.fontFamily,
                fontSize: size,
              ),
            ),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w;
        }

        // Genişlik sıfır/negatif/çok dar ise hiçbir ölçü yapılmaz: okunur
        // tabanda (11 pt) sarılı metin; punto HER adımda pozitiftir.
        final tooNarrow = !c.maxWidth.isFinite ? false : c.maxWidth < 8;
        // `scaler.scale(size) >= _minPt` sağlayan EN KÜÇÜK punto (ölçekleyici
        // doğrusal olmasa da): aralık araması, sonra doğrulama.
        double floorSize() {
          var lo = 1.0;
          var hi = fs;
          if (scaler.scale(hi) < _minPt) return hi;
          for (var i = 0; i < 24; i++) {
            final mid = (lo + hi) / 2;
            if (scaler.scale(mid) >= _minPt) {
              hi = mid;
            } else {
              lo = mid;
            }
          }
          return hi;
        }

        var size = fs;
        var lines = 1;
        if (tooNarrow) {
          size = floorSize();
          lines = maxLines;
        } else if (c.maxWidth.isFinite && widthAt(fs) > c.maxWidth) {
          final floor = floorSize();
          // Orantı yetmez (harf genişliği punto ile tam doğrusal değil):
          // sığana kadar birkaç kez yeniden ölç; taban altına inme.
          size = (fs * ((c.maxWidth - 3) / widthAt(fs))).clamp(floor, fs);
          for (var i = 0; i < 6 && widthAt(size) > c.maxWidth - 1.5; i++) {
            final next = (size * ((c.maxWidth - 3) / widthAt(size))).clamp(
              floor,
              fs,
            );
            if (next >= size) break;
            size = next;
          }
          if (widthAt(size) > c.maxWidth - 0.5) {
            // Tabanda da tek satıra sığmadı: tabanda sar.
            size = floor;
            lines = maxLines;
          }
        }
        return Align(
          alignment: alignment,
          child: Text(
            text,
            maxLines: lines,
            softWrap: lines > 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(fontSize: size),
          ),
        );
      },
    );
  }
}

/// Oda skor şeridinin sütun sayısı (2026-10-29, Astra 2. inceleme): ölçerek
/// seçilir. Çip = iç boşluk 8 + avatar 20 + 4 + puan; puan
/// okunur tabanda (11 pt çizilen) en kötü 5 haneli ("99.999") ölçülür, yani
/// puan oyun içinde büyüyünce sütun sayısı DEĞİŞMEZ. Dört çip [innerWidth]'e
/// sığıyorsa 4, sığmıyorsa 2.
int quizCrowdColumns(TextScaler scaler, double innerWidth) {
  double widthOf(String text, double size) {
    final p = TextPainter(
      text: TextSpan(
        text: text,
        style: SahneType.captionStrong.copyWith(
          fontFamily: SahneType.text,
          fontSize: size,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  // Çizilen 11 pt'e denk punto (ölçek 1'in altına inmez); en kötü 5 haneli
  // puan ("99.999").
  final ratio = scaler.scale(12) / 12;
  final score = widthOf('99.999', (11 / ratio).clamp(1.0, 12.0));
  final need = 8 + 20 + 4 + score;
  return (innerWidth - 3 * 4) / 4 >= need ? 4 : 2;
}

/// Ölçüm önbelleği anahtarı: parçalar YAPISAL eşitlikle karşılaştırılır.
///
/// Önce `join` ile metne çevriliyordu; sürüm derlemesinde `TextStyle.toString()`
/// alanlarını yazmaz, yazı tipi ya da satır yüksekliği değişse de anahtar aynı
/// kalıp eski ölçümü döndürebilirdi (Astra incelemesi, 2026-10-29).
@immutable
class _FitKey {
  _FitKey(List<Object?> parts) : parts = List.unmodifiable(parts);

  final List<Object?> parts;

  @override
  bool operator ==(Object other) =>
      other is _FitKey && listEquals(other.parts, parts);

  @override
  int get hashCode => Object.hashAll(parts);
}
