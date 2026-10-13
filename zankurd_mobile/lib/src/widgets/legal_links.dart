import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/sahne.dart';
import '../utils/external_link.dart';

/// Gizlilik politikası ve kullanım koşulları bağlantıları. Mağaza şartıdır;
/// hem Ayarlar (Hakkında) hem de Paywall'da gösterilir. URL'ler
/// [AppConfig.privacyPolicyUrl] / [AppConfig.termsOfServiceUrl]'den okunur.
class LegalLinksRow extends StatelessWidget {
  const LegalLinksRow({super.key, this.alignment = MainAxisAlignment.start});

  final MainAxisAlignment alignment;

  WrapAlignment get _wrapAlignment => switch (alignment) {
    MainAxisAlignment.center => WrapAlignment.center,
    MainAxisAlignment.end => WrapAlignment.end,
    _ => WrapAlignment.start,
  };

  /// KVKK/gizlilik/şartlar bağlantısını açar.
  ///
  /// Açma mantığı burada DEĞİL, [openExternalLink] içindedir: aynı kusurun
  /// ikinci örneği görsel künye ekranında çıkınca (2026-08-17) düzeltme
  /// ortak bir kapıya taşındı. Kusurun ne olduğu ve niçin sessiz kaldığı o
  /// dosyanın başında yazılıdır.
  static Future<void> _open(BuildContext context, String url) =>
      openExternalLink(context, url, reason: 'legal link open');

  @override
  Widget build(BuildContext context) {
    // 2026-09-29 Şahnê: kalın açıklama, ikincil metin, altı çizili (metin
    // bağlantısı; Agir değil — mağaza şartı olan bir bilgi, eylem değil).
    final t = SahneTokens.of(context);
    final style = SahneType.captionStrong.copyWith(
      color: t.tx2,
      decoration: TextDecoration.underline,
      decorationColor: t.tx2,
    );
    Widget link(String label, String url) => InkWell(
      onTap: () => _open(context, url),
      customBorder: SahneShape.m,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
          child: Center(widthFactor: 1, child: Text(label, style: style)),
        ),
      ),
    );

    return Wrap(
      alignment: _wrapAlignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: SahneSpace.x2,
      children: [
        link(context.t(K.privacyPolicy), AppConfig.privacyPolicyUrl),
        ExcludeSemantics(
          child: Text('·', style: SahneType.caption.copyWith(color: t.tx3)),
        ),
        link(context.t(K.termsOfUse), AppConfig.termsOfServiceUrl),
      ],
    );
  }
}
