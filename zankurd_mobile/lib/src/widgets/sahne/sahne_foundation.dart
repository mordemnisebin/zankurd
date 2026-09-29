import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../providers/reduced_motion_provider.dart';
import '../../theme/sahne.dart';

/// Şahnê rolü: bir öğenin hangi renk ailesini taşıdığı.
///
/// Renk yalnız rol taşır (bkz. [SahneTokens]): öğrenme Zimrût, yarış Boyax,
/// ödül Zêr; nötr Kulis tonudur. İkon karosu, seçili çip, rozet ve kilim
/// şeridi rengini buradan alır — bileşen renk parametresi almaz.
enum SahneRole { learn, race, gold, neutral }

/// Rolün belirteçlerdeki karşılıkları.
extension SahneRoleTokens on SahneTokens {
  /// Rolün düz zeminde okunan metin/ikon rengi (`--rtx`).
  Color roleText(SahneRole role) => switch (role) {
    SahneRole.learn => learnTx,
    SahneRole.race => raceTx,
    SahneRole.gold => goldTx,
    SahneRole.neutral => tx,
  };

  /// Rolün ton zemini (`--rtint`).
  Color roleTint(SahneRole role) => switch (role) {
    SahneRole.learn => learnTint,
    SahneRole.race => raceTint,
    SahneRole.gold => goldTint,
    SahneRole.neutral => s2,
  };

  /// Sahne kartının köşe radyali: rol renginin %20'si (`--stage-learn`).
  Color roleGlow(SahneRole role) => switch (role) {
    SahneRole.learn => learn.withValues(alpha: 0.2),
    SahneRole.race => race.withValues(alpha: 0.2),
    SahneRole.gold => gold.withValues(alpha: 0.2),
    SahneRole.neutral => tx3.withValues(alpha: 0.12),
  };
}

/// Eski bir aksan renginin Şahnê rolü.
///
/// Ortak bileşenlerin eski API'leri renk parametresi alıyordu (`accent`,
/// `color`: `AppTheme.playGreen`, `AppTheme.gold` …). Şahnê'de renk yalnız
/// rol taşır; bu yüzden gelen renk olduğu gibi boyanmaz, tonuna göre bir
/// role çevrilir ve rolün belirteçleri kullanılır. Ekranlar Şahnê'ye
/// taşınınca rol doğrudan verilir.
///
/// * yeşil / camgöbeği → öğrenme (Zimrût)
/// * lal / pembe / kırmızı → yarış (Boyax)
/// * turuncu / altın / amber → ödül (Zêr); Agir bir rol değildir
/// * mavi, mor ve doygunluğu düşük (gri, lacivert yüzey) → nötr
SahneRole sahneRoleFor(Color color) {
  final hsl = HSLColor.fromColor(color);
  if (color.a == 0 || hsl.saturation < 0.25 || hsl.lightness < 0.12) {
    return SahneRole.neutral;
  }
  final h = hsl.hue;
  if (h >= 70 && h < 190) return SahneRole.learn;
  if (h >= 15 && h < 70) return SahneRole.gold;
  if (h >= 300 || h < 15) return SahneRole.race;
  return SahneRole.neutral;
}

/// Metnin iki uçtan (gecenin açık metni, gündüzün koyu metni) hangisiyle
/// renkli bir dolguda AA okunduğunu seçer. Kullanıcının seçtiği avatar
/// rengi gibi belirteç olmayan dolgular için; belirteç dolgularının kendi
/// `on…` rengi vardır (Agir → `onAct`, Zêr → `onGold`).
Color sahneOnFill(Color fill) {
  double contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
  }

  final light = SahneTokens.night.tx;
  final dark = SahneTokens.day.tx;
  return contrast(light, fill) >= contrast(dark, fill) ? light : dark;
}

/// Etkin dil Kurmancî mi? Büyük harf ([SahneType.upperFor]) için.
///
/// Bileşenler dil sağlayıcısı olmadan da çizilebilsin (galeri, çıplak
/// test) diye sağlayıcı yoksa Türkçe varsayılır; uygulamada sağlayıcı
/// her zaman vardır.
bool sahneIsKu(BuildContext context) {
  try {
    return Provider.of<LanguageProvider>(context).isKu;
  } on ProviderNotFoundException {
    return false;
  }
}

/// Geri ve kapat düğmelerinin varsayılan sözü: uygulamanın dilinden
/// ([K.back], [K.close]). Material yereli Kurmancî bilmediği için
/// "Back"/"Close" okuyordu (bkz. `ZkBackButton`). Dil sağlayıcısı yoksa
/// (galeri, çıplak test) Material yereline düşer.
String sahneBackLabel(BuildContext context) =>
    _appLabel(context, K.back) ??
    MaterialLocalizations.of(context).backButtonTooltip;

String sahneCloseLabel(BuildContext context) =>
    _appLabel(context, K.close) ??
    MaterialLocalizations.of(context).closeButtonTooltip;

String? _appLabel(BuildContext context, String key) {
  try {
    final isKu = Provider.of<LanguageProvider>(context).isKu;
    return Tr.forKu(key, isKu);
  } on ProviderNotFoundException {
    return null;
  }
}

/// Üst etiket ve rozet metnini yerele duyarlı büyütür.
String sahneUpper(BuildContext context, String text) =>
    SahneType.upperFor(text, isKu: sahneIsKu(context));

/// "Hareketi azalt" açık mı? Açıkken yalnız renk ve şekil değişir.
///
/// İki kaynağı birlikte okur: işletim sisteminin erişilebilirlik ayarı
/// (`MediaQuery.disableAnimations`) ve uygulamanın kendi tercihi
/// ([ReducedMotionProvider]; sağlayıcı yoksa `false`).
bool sahneMotionReduced(BuildContext context) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
    ReducedMotionProvider.isReducedIn(context);

/// Basılınca 2 px çöken sarmalayıcı (düğme, joker).
///
/// Maketteki "basılı" hâli: ton bir basamak koyulaşır (Material katmanı
/// verir) ve öğe 2 px aşağı iner. Hareketi azalt açıkken çökme yoktur.
/// `Listener` kullanır: jest yarışmasına girmez, çocuğun dokunuşunu
/// çalmaz.
class SahnePressSink extends StatefulWidget {
  const SahnePressSink({super.key, required this.enabled, required this.child});

  /// Pasif öğe çökmez.
  final bool enabled;
  final Widget child;

  @override
  State<SahnePressSink> createState() => _SahnePressSinkState();
}

class _SahnePressSinkState extends State<SahnePressSink> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final sink = widget.enabled && _down && !sahneMotionReduced(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Transform.translate(
        offset: Offset(0, sink ? 2 : 0),
        child: widget.child,
      ),
    );
  }
}

/// Pahlı dokunulabilir yüzey: `Material(shape)` + `InkWell(customBorder)`.
///
/// Dalga pah köşeden taşmaz. Şekil her zaman [SahneShape]'ten gelir;
/// `BorderRadius.circular` yok.
class SahneTappable extends StatelessWidget {
  const SahneTappable({
    super.key,
    required this.shape,
    required this.color,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  final ShapeBorder shape;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null && onLongPress == null
          ? child
          : InkWell(
              customBorder: shape,
              onTap: onTap,
              onLongPress: onLongPress,
              child: child,
            ),
    );
  }
}

/// Dokunma kutusunun kenarı: Android erişilebilirlik kılavuzu
/// (`androidTapTargetGuideline`) 48'in altını reddeder.
///
/// Şahnê'nin görsel ölçüleri (44'lük ikon düğmesi, 44'lük metin düğmesi,
/// 36'lık stat çipi) değişmez; dokunulabilen her bileşen görselini bu
/// kenarda saydam bir kutunun ortasına koyar. 2026-09-29 birleştirmesine
/// kadar her ekran bu kutuyu kendisi yazıyordu (`BarIconAction`,
/// `_TextAction`, `_QuizToolButton` …); artık bileşenin işidir.
const double sahneTapTarget = 48;

/// Sarar ama bir SÖZÜ harf harf bölmez.
///
/// Dar bir sütunda (320 px) büyük yazı ölçeğinde (%200) "Arkadaşlar" gibi
/// tek bir söz satıra sığmayınca Flutter onu harflerinden böler
/// ("Arkadaşla / r"). Bu metin en uzun sözünü ölçer; o söz sığmıyorsa yazı
/// ölçeği yalnız o söz sığacak kadar küçülür. Sözler arasından sarmak her
/// zaman serbesttir; küçülme yalnız sığmayan en uzun söz içindir, metnin
/// geri kalanı kullanıcının seçtiği ölçüde kalır ve kesilmez.
class SahneUnbrokenText extends StatelessWidget {
  const SahneUnbrokenText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final effective = constraints.hasBoundedWidth
            ? sahneUnbrokenScaler(
                context,
                text,
                style,
                constraints.maxWidth,
                scaler,
              )
            : scaler;
        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          textScaler: effective,
        );
      },
    );
  }
}

/// [text]in en uzun sözü [maxWidth]e sığacak yazı ölçeği: sığıyorsa
/// [scaler] olduğu gibi döner.
TextScaler sahneUnbrokenScaler(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
  TextScaler scaler,
) {
  if (maxWidth <= 0 || text.isEmpty) return scaler;
  final merged = DefaultTextStyle.of(context).style.merge(style);
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  var widest = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final painter = TextPainter(
      // Aile açıkça yazılır: ölçüm, çizimle aynı yazı tipinden yapılmalı.
      text: TextSpan(
        text: word,
        style: merged.copyWith(fontFamily: merged.fontFamily ?? SahneType.text),
      ),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    widest = math.max(widest, painter.width);
    painter.dispose();
  }
  if (widest <= maxWidth) return scaler;
  final size = merged.fontSize ?? 14;
  final current = scaler.scale(size) / size;
  // Kenardan bir tık pay: ölçüm ile çizim arasındaki yuvarlama sözü yine
  // bölmesin.
  return TextScaler.linear(current * (maxWidth / widest) * 0.98);
}

/// Perde (`s1`) yüzeyinin içi mi?
///
/// Yüzey kartı ve liste grubu içeriğini bununla sarar. Kendi zemini Perde
/// olan bir öğe (seçili olmayan seçim rayı çipi) Perde kartın İÇİNDE
/// görünmez oluyordu (2026-09-29, hesap ve öneri ekranları); böyle bir öğe
/// kartın içindeyse bir basamak yükselir (Kulis, `s2`).
class SahneOnSurface extends InheritedWidget {
  const SahneOnSurface({super.key, required super.child});

  /// Öğe Perde yüzeyinin içinde mi?
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SahneOnSurface>() != null;

  @override
  bool updateShouldNotify(SahneOnSurface oldWidget) => false;
}
