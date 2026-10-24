import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../utils/external_link.dart';
import 'sahne/sahne.dart';

/// Giriş ve kayıt düğmelerinin altındaki kabul satırı:
/// "Devam ederek Kullanım Şartları ve Gizlilik Politikası'nı kabul edersin."
///
/// ## Kusur
/// Yaş onay kutusu karşılamadan kalkınca ("Sonraki"yi kilitliyor ve ilk
/// ekranda hata gösteriyordu) kullanıcının şartları ve gizliliği kabul
/// ettiği hiçbir yerde söylenmiyordu.
///
/// ## Kural
/// Satır bir düğme DEĞİL, küçük düz metindir; iki söz altı çizili bağlantıdır
/// ve [AppConfig.termsOfServiceUrl] / [AppConfig.privacyPolicyUrl] adreslerini
/// ortak [openExternalLink] kapısıyla açar. Cümle tek anahtardır
/// ([K.signInConsent]); bağlantı olacak sözler `[` `]` içinde yazılır —
/// Kurmancî ile Türkçenin söz dizimi farklı olduğundan cümleyi parçalara
/// bölmek yerine işaretli tek şablon çevrilir. Birinci işaret şartlar,
/// ikincisi gizlilik adresine gider.
class ConsentLine extends StatefulWidget {
  const ConsentLine({super.key});

  @override
  State<ConsentLine> createState() => _ConsentLineState();
}

class _ConsentLineState extends State<ConsentLine> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans(BuildContext context, TextStyle linkStyle) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    final urls = [AppConfig.termsOfServiceUrl, AppConfig.privacyPolicyUrl];
    final template = context.t(K.signInConsent);
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\[([^\]]+)\]');
    var cursor = 0;
    var linkIndex = 0;
    for (final match in pattern.allMatches(template)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: template.substring(cursor, match.start)));
      }
      final url = urls[linkIndex.clamp(0, urls.length - 1)];
      linkIndex++;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => openExternalLink(context, url, reason: 'consent link');
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: match.group(1),
          style: linkStyle,
          recognizer: recognizer,
        ),
      );
      cursor = match.end;
    }
    if (cursor < template.length) {
      spans.add(TextSpan(text: template.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final base = SahneType.caption.copyWith(color: t.tx2);
    final linkStyle = base.copyWith(
      color: t.tx,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: t.tx,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SahneSpace.x1),
      child: Text.rich(
        key: const ValueKey('consent-line'),
        TextSpan(style: base, children: _spans(context, linkStyle)),
        textAlign: TextAlign.center,
      ),
    );
  }
}
