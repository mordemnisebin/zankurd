import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Material varsayılanı İngilizce «Back»; etiket dile bağlı olmalı.
///
/// `BackButton` tooltip parametresi bu SDK'da yok; `tester.pageBack()`
/// de «Back» arar. Testler [ZkBackButton] tipine dokunmalı.
///
/// 2026-09-29 Şahnê: B iskeletinin geri düğmesi — 44'lük M pahlı Perde
/// plaka ([SahneIconButton]). Plaka kendi zeminini taşıdığı için renkli
/// bir kahramanın üstünde de okunur; [color] geriye uyum için kalır ve
/// yok sayılır (ikon rengi belirteçten gelir).
///
/// Görsel 44, dokunma alanı 48: erişilebilirlik kılavuzu testi
/// (`androidTapTargetGuideline`) 48'in altını reddeder. 48'lik kutuyu
/// artık bileşenin kendisi verir ([SahneIconButton]); ekran okuyucu tek bir
/// 48'lik düğme görür.
class ZkBackButton extends StatelessWidget {
  const ZkBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  /// Dokunma kutusunun kenarı.
  static const double tapTarget = sahneTapTarget;

  @override
  Widget build(BuildContext context) {
    return SahneIconButton(
      icon: AppIcons.arrowLeft,
      semanticLabel: context.t(K.back),
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}

/// Varsayılan geri düğmesinin dokunma kutusunun sayfa kenarından boşluğu:
/// plakanın (44) görsel kenarı 16'ya oturur.
const double _backInset = SahneSpace.page - SahneIconButton.inset;

/// Geri tuşu [K.back] tooltip'i taşıyan AppBar.
///
/// 2026-09-29 Şahnê: B iskeletinin çubuğu — en az 64 yükseklik, solda
/// sayfa kenarından 16 içeride 44'lük geri plakası, 12 boşluk, Manşet 22
/// başlık ve isteğe bağlı Açıklama alt satırı ([subtitle]). Zemin sayfa
/// zeminidir (`bg`); çağıran bir renk verirse o korunur.
PreferredSizeWidget zkAppBar(
  BuildContext context, {
  Key? key,
  Widget? title,
  Widget? subtitle,
  List<Widget>? actions,
  Color? backgroundColor,
  double? elevation,
  double? scrolledUnderElevation,
  bool automaticallyImplyLeading = true,
  Widget? leading,
  IconThemeData? iconTheme,
  bool? centerTitle,
  SystemUiOverlayStyle? systemOverlayStyle,
}) {
  final t = SahneTokens.of(context);
  final showDefaultLeading = automaticallyImplyLeading && leading == null;
  final hasLeading = leading != null || showDefaultLeading;
  // Başlık metinse sözleri bölünmeden sarar ([SahneUnbrokenText]) ve çubuk
  // büyük yazıda başlığın gerçek yüksekliği kadar uzar (eskiden sabit 64'tü:
  // %200'de başlık ve alt satır kesiliyordu).
  final titleText = title is Text && title.data != null ? title : null;
  final actionCount = actions?.length ?? 0;
  // 2026-09-30 simülatör: `AppBar` başlığı `softWrap: false` + üç nokta ile
  // sarar; büyük yazıda "Dilbilgisi / Gr…" diye kesiliyordu. Başlık en çok
  // iki satıra sarar ve KESİLMEZ: iki satıra sığmıyorsa yazı ölçeği o kadar
  // küçülür ([_titleScaler]); ölçüm ve çizim aynı ölçeği kullanır.
  final titleRoom = _titleRoom(context, hasLeading, actionCount);
  final Widget? shownTitle = titleText == null
      ? title
      : Text(
          titleText.data!,
          style: SahneType.headline.copyWith(color: t.tx),
          maxLines: _titleMaxLines,
          softWrap: true,
          overflow: TextOverflow.clip,
          textScaler: _titleScaler(
            context,
            titleText.data!,
            titleRoom,
            MediaQuery.textScalerOf(context),
          ),
        );
  final toolbarHeight = _barHeight(
    context,
    title: titleText?.data,
    subtitle: subtitle is Text ? subtitle.data : null,
    subtitleMaxLines: subtitle is Text ? subtitle.maxLines : null,
    hasSubtitle: subtitle != null,
    hasLeading: hasLeading,
    actionCount: actionCount,
  );
  // 2026-09-30 bant: `AppBar` başlığı yazı ölçeğini 1,34'te kırpar; çubuk
  // yüksekliği ise gerçek ölçekle ölçülür ([_barHeight]). %200'de çubuk
  // çizilenden çok daha uzun kalır, altında boş blok oluşurdu. Başlık ve alt
  // satır gerçek ölçekle çizilir, ölçüm ve çizim aynı kalır.
  final scaler = MediaQuery.textScalerOf(context);
  final Widget? plainHeading = shownTitle == null
      ? null
      : Semantics(
          header: true,
          child: subtitle == null
              ? shownTitle
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shownTitle,
                    DefaultTextStyle.merge(
                      style: SahneType.caption.copyWith(color: t.tx2),
                      softWrap: true,
                      child: subtitle,
                    ),
                  ],
                ),
        );
  final Widget? heading = plainHeading == null
      ? null
      : Builder(
          builder: (inner) => MediaQuery(
            data: MediaQuery.of(inner).copyWith(textScaler: scaler),
            child: plainHeading,
          ),
        );
  return AppBar(
    key: key,
    toolbarHeight: toolbarHeight,
    title: heading,
    titleSpacing: hasLeading ? SahneSpace.x3 : SahneSpace.page,
    titleTextStyle: SahneType.headline.copyWith(color: t.tx),
    actions: actions == null
        ? null
        : [...actions, const SizedBox(width: SahneSpace.x2)],
    backgroundColor: backgroundColor ?? t.bg,
    surfaceTintColor: Colors.transparent,
    elevation: elevation ?? 0,
    scrolledUnderElevation: scrolledUnderElevation ?? 0,
    iconTheme: iconTheme ?? IconThemeData(color: t.tx),
    centerTitle: centerTitle ?? false,
    systemOverlayStyle: systemOverlayStyle,
    automaticallyImplyLeading: showDefaultLeading,
    // Çağıranın kendi öncülü (ör. 48'lik kapat düğmesi) olduğu gibi kalır;
    // yalnız varsayılan geri plakası sayfa kenarına hizalanır.
    // Plakanın görsel kenarı sayfa kenarına (16) oturur; 48'lik dokunma
    // kutusu 2 px dışarı taşar.
    leadingWidth: leading == null && showDefaultLeading
        ? _backInset + ZkBackButton.tapTarget
        : null,
    leading:
        leading ??
        (showDefaultLeading
            ? const Padding(
                padding: EdgeInsetsDirectional.only(start: _backInset),
                child: Center(child: ZkBackButton()),
              )
            : null),
  );
}

/// Başlığın en çok kaç satıra sarabileceği.
const int _titleMaxLines = 2;

/// Başlığa ayrılan genişlik: ekran − öncül − iki yanda başlık boşluğu −
/// eylemler. `NavigationToolbar` başlık boşluğunu İKİ yana da koyar
/// (`middleSpacing * 2`) ve [zkAppBar] eylemlerin sonuna [SahneSpace.x2]'lik
/// bir pay ekler; ölçüm bunların hepsini sayar.
///
/// 2026-09-30 izgara: eskiden eylem payı (8) ve sağ boşluk 12 yerine 16
/// sayılıyordu; ölçüm gerçek alandan ~4 px geniş kalıyor, kilim yuvası olan
/// çubukta alt satır ölçülenden bir satır fazla sarıp bandın altında
/// kırpılıyordu (Kurmancî "Zanist û Raman" ekranı).
double _titleRoom(BuildContext context, bool hasLeading, int actionCount) {
  final width = MediaQuery.sizeOf(context).width;
  final lead = hasLeading ? _backInset + ZkBackButton.tapTarget : 0.0;
  final spacing = hasLeading ? SahneSpace.x3 : SahneSpace.page;
  final actions = actionCount == 0
      ? 0.0
      : actionCount * sahneTapTarget + SahneSpace.x2;
  return math.max(48.0, width - lead - spacing * 2 - actions);
}

/// Başlığın yazı ölçeği: en uzun söz satıra sığar ([sahneUnbrokenScaler]) ve
/// bütün başlık [_titleMaxLines] satıra sığar; sığmıyorsa ölçek %8'er
/// küçülür (en aşağı 1,0). Kesme yok, küçülme var.
TextScaler _titleScaler(
  BuildContext context,
  String text,
  double room,
  TextScaler scaler,
) {
  const style = SahneType.headline;
  final merged = DefaultTextStyle.of(context).style.merge(style);
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  var fit = sahneUnbrokenScaler(context, text, style, room, scaler);
  final size = style.fontSize!;
  for (var i = 0; i < 24; i++) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: merged.copyWith(fontFamily: merged.fontFamily ?? SahneType.text),
      ),
      textDirection: direction,
      textScaler: fit,
      maxLines: _titleMaxLines,
    )..layout(maxWidth: room);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    final current = fit.scale(size) / size;
    if (!exceeded || current <= 1.0) break;
    fit = TextScaler.linear(math.max(1.0, current * 0.92));
  }
  return fit;
}

/// B çubuğunun yüksekliği: en az 64; büyük yazıda başlığın (ve alt
/// satırın) ölçülen yüksekliği + 16. 2026-09-30 bant: alt satır `maxLines`
/// ile kısıtlıysa ölçüm de o kadar satırı sayar (eskiden sınırsız ölçülür,
/// çizilen iki satırın altında boş bir blok kalırdı). Başlık metin değilse tek satır sayılır.
double _barHeight(
  BuildContext context, {
  required String? title,
  required String? subtitle,
  int? subtitleMaxLines,
  required bool hasSubtitle,
  required bool hasLeading,
  required int actionCount,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  final room = _titleRoom(context, hasLeading, actionCount);
  double measure(
    String? text,
    TextStyle style, {
    int? maxLines,
    bool isTitle = false,
  }) {
    if (text == null) return scaler.scale(style.fontSize!) * style.height!;
    final merged = DefaultTextStyle.of(context).style.merge(style);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: merged.copyWith(fontFamily: merged.fontFamily ?? SahneType.text),
      ),
      textDirection: direction,
      textScaler: isTitle
          ? _titleScaler(context, text, room, scaler)
          : sahneUnbrokenScaler(context, text, style, room, scaler),
      maxLines: maxLines,
    )..layout(maxWidth: room);
    final h = painter.height;
    painter.dispose();
    return h;
  }

  var h = measure(
    title,
    SahneType.headline,
    maxLines: _titleMaxLines,
    isTitle: true,
  );
  if (hasSubtitle) {
    h += measure(subtitle, SahneType.caption, maxLines: subtitleMaxLines);
  }
  return math.max(64, h + SahneSpace.x4);
}
