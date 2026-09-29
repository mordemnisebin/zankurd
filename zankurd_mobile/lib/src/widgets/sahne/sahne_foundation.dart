import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/lang.dart';
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
