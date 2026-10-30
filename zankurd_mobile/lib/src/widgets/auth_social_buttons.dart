import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/brand_icons.dart';
import 'sahne/sahne.dart';

/// Apple yalnız yerel iOS'ta; web/Android OAuth anahtarına bağımlı yol açılmaz.
bool get supportsAppleAuth =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Giriş, kayıt ve misafir bağlamada aynı boy/önem ve marka görünümü.
class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({
    super.key,
    required this.onGoogle,
    required this.onApple,
    this.signUp = false,
    this.linking = false,
    this.showGoogle = true,
    this.showApple,
    this.appleKey = const ValueKey('auth-apple'),
    this.contentWidth,
  });
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final bool signUp;
  final bool linking;
  final bool showGoogle;
  final bool? showApple;
  final Key appleKey;

  /// Intrinsic ölçüm kullanan diyaloglar kendi içerik genişliğini verir.
  final double? contentWidth;

  @override
  Widget build(BuildContext context) {
    final apple = context.t(
      linking
          ? K.linkApple
          : signUp
          ? K.signUpApple
          : K.continueApple,
    );
    final google = context.t(
      linking
          ? K.linkGoogle
          : signUp
          ? K.signUpGoogle
          : K.continueGoogle,
    );
    final hasApple = showApple ?? supportsAppleAuth;
    Widget buttons(double width) {
      double labelHeight(String label) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: SahneType.button),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1, width - 64));
        final height = painter.height;
        painter.dispose();
        return height;
      }

      final height = math.max(
        52.0,
        math.max(
              hasApple ? labelHeight(apple) : 0.0,
              showGoogle ? labelHeight(google) : 0.0,
            ) +
            24,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasApple)
            AppleAuthButton(
              key: appleKey,
              label: apple,
              height: height,
              onPressed: onApple,
            ),
          if (hasApple && showGoogle) const SizedBox(height: SahneSpace.x2),
          if (showGoogle)
            GoogleAuthButton(
              key: const ValueKey('auth-google'),
              label: google,
              height: height,
              onPressed: onGoogle,
            ),
        ],
      );
    }

    if (contentWidth != null) return buttons(contentWidth!);
    return LayoutBuilder(
      builder: (context, constraints) => buttons(constraints.maxWidth),
    );
  }
}

/// Google'ın kendi marka kılavuzundaki "Sign in with Google" renkleri:
/// beyaz dolgu, #747775 kontur, #1F1F1F yazı. Bunlar Şahnê paletinin
/// değil, üçüncü tarafın zorunlu kimliğidir; bu yüzden belirteç değil,
/// burada adlandırılmış sabittir. Şekil uygulamanın M pahıdır, gölge yok.
const _googleSurface = Color(0xFFFFFFFF);
const _googleStroke = Color(0xFF747775);
const _googleInk = Color(0xFF1F1F1F);

class GoogleAuthButton extends StatelessWidget {
  const GoogleAuthButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final shape = SahneShape.withSide(SahneShape.m, _googleStroke, width: 1);
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        // Marka düğmesi Şahnê'nin pasif tonuna boyanamaz (kılavuz); yükleme
        // sürerken yalnız soluklaşır, dokunuş almaz.
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: _googleSurface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: onPressed,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      'assets/brand/google_g.svg',
                      width: 20,
                      height: 20,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(width: SahneSpace.x3),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: SahneType.button.copyWith(color: _googleInk),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppleAuthButton extends StatelessWidget {
  const AppleAuthButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Apple'ın kendi düğme kılavuzu iki varyant tanımlar: açık zeminde siyah,
    // koyu zeminde beyaz. Düğme ilk yazıldığında yalnız siyah varyant vardı
    // ve karanlık temada gövde kartın zeminine 1.24:1 ile oturuyordu —
    // yalnız beyaz yazı havada duruyordu (2026-08-16 ekran turu,
    // 75_sign_in_dark). Siyah/beyaz Apple'ın zorunlu kimliğidir, belirteç
    // değil; şekil uygulamanın M pahı, gölge yok.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? Colors.white : Colors.black;
    final onSurface = dark ? Colors.black : Colors.white;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: sahneMotionReduced(context)
              ? Duration.zero
              : SahneMotion.fade,
          decoration: ShapeDecoration(color: surface, shape: SahneShape.m),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: SahneShape.m,
              onTap: onPressed,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SahneSpace.x4,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BrandIcon(BrandIcons.apple, color: onSurface, size: 20),
                      const SizedBox(width: SahneSpace.x3),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: SahneType.button.copyWith(color: onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// E-posta giriş formunun üstündeki statik bölüm ayıracı (çizgi + metin).
/// Form her zaman açık gösterildiği için aç/kapa chevron'u yoktur.
class AuthEmailDivider extends StatelessWidget {
  const AuthEmailDivider({super.key, this.contentWidth});

  final double? contentWidth;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    Widget line() => Expanded(
      child: SizedBox(height: 1, child: ColoredBox(color: t.line)),
    );
    // Kurul 4. tur (74): metin `Flexible` (gevşek) iken sağ çizgi soldakinden
    // kısa kalıyor, ayıraç ortalanmıyordu (boş pay dağıtılmıyor). Metin artık
    // en çok genişliğin %75'ine kadar kendi boyunda durur, iki çizgi kalanı
    // EŞİT paylaşır.
    Widget divider(double width) => Row(
      children: [
        line(),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width * 0.75),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
            child: Text(
              context.t(K.orWithEmail),
              textAlign: TextAlign.center,
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          ),
        ),
        line(),
      ],
    );
    return ConstrainedBox(
      // a11y-tap-target: noninteractive — statik bölüm ayıracı.
      constraints: const BoxConstraints(minHeight: 44),
      child: contentWidth != null
          ? divider(contentWidth!)
          : LayoutBuilder(builder: (context, box) => divider(box.maxWidth)),
    );
  }
}
