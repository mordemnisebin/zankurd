import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'branded_loader.dart';

/// Yerel açılış ekranının (iOS `LaunchScreen.storyboard`, Android
/// `launch_background`) Flutter'daki birebir kopyası.
///
/// ## Kusur
///
/// Yerel açılış ekranı koyu zemin + ortada büyük turuncu logoydu; Flutter'ın
/// ilk karesi (`BootHost`) açık zemin + küçük logo + "ZanKurd" yazısı + yükleyici
/// çiziyordu, ardından `SplashScreen` bir üçüncü marka karesi daha çiziyordu
/// (ölçekleyen, solan, farklı boyutlu). Kullanıcı soğuk açılışta iki kez
/// zemin/logo sıçraması görüyordu (2026-11-03 simülatör kareleri).
///
/// ## Niçin sessiz kalırdı
///
/// Her kare tek başına "doğru" görünür; sıçrama yalnız ardışık karelerin
/// yan yana konmasıyla görülür ve hiçbir test yerel açılış ekranının
/// boyutunu ya da rengini Flutter tarafıyla karşılaştırmazdı.
///
/// ## Sözleşme
///
/// Zemin düz renktir ([lightBackground]/[darkBackground] = iOS
/// `LaunchBackground.colorset` ve Android `zk_splash_bg*`), logo
/// [logoWidth] x [logoHeight] ve tam ortadadır. Yükleyici yalnız
/// [spinnerDelay] sonra, logoyu oynatmadan, logonun altına solarak gelir.
/// `BootHost` ve `SplashScreen` aynı kareyi çizer; aralarında görsel
/// sıçrama olmaz.
class LaunchFrame extends StatefulWidget {
  const LaunchFrame({this.brightness, this.showSpinner = true, super.key});

  /// Verilmezse çevredeki tema parlaklığı kullanılır.
  final Brightness? brightness;
  final bool showSpinner;

  static const Color lightBackground = AppTheme.lightBg; // 0xFFF4F6FA
  static const Color darkBackground = AppTheme.bg; // 0xFF121214

  /// `LaunchImage@3x.png` 540x500 px = 180x166,67 pt.
  static const String logoAsset = 'assets/brand/launch_logo.png';
  static const double logoWidth = 180;
  static const double logoHeight = 500 / 3;

  static const Duration spinnerDelay = Duration(milliseconds: 600);
  static const double spinnerGap = 24;

  static Color backgroundFor(Brightness b) =>
      b == Brightness.dark ? darkBackground : lightBackground;

  @override
  State<LaunchFrame> createState() => _LaunchFrameState();
}

class _LaunchFrameState extends State<LaunchFrame> {
  Timer? _timer;
  bool _spinner = false;

  @override
  void initState() {
    super.initState();
    if (widget.showSpinner) {
      _timer = Timer(LaunchFrame.spinnerDelay, () {
        if (mounted) setState(() => _spinner = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = widget.brightness ?? Theme.of(context).brightness;
    return ColoredBox(
      key: const ValueKey('launch-frame-bg'),
      color: LaunchFrame.backgroundFor(brightness),
      child: Stack(
        children: [
          const Center(
            child: Image(
              key: ValueKey('launch-frame-logo'),
              image: AssetImage(LaunchFrame.logoAsset),
              width: LaunchFrame.logoWidth,
              height: LaunchFrame.logoHeight,
              excludeFromSemantics: true,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            ),
          ),
          // Yükleyici logodan bağımsız konumlanır: logo yerinden oynamaz.
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(
                  0,
                  LaunchFrame.logoHeight / 2 + LaunchFrame.spinnerGap + 12,
                ),
                child: AnimatedOpacity(
                  opacity: _spinner ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: const BrandedLoader(size: 24, strokeWidth: 2.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
