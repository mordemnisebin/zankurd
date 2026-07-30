import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';

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

  static Future<void> _open(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'legal link open: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.caption.copyWith(
      color: AppTheme.textSubColor(context),
      decoration: TextDecoration.underline,
      fontWeight: FontWeight.w600,
    );
    Widget link(String label, String url) => InkWell(
      onTap: () => _open(url),
      borderRadius: BorderRadius.circular(6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(widthFactor: 1, child: Text(label, style: style)),
        ),
      ),
    );

    return Wrap(
      alignment: _wrapAlignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 2,
      children: [
        link(context.t(K.privacyPolicy), AppConfig.privacyPolicyUrl),
        Text(
          '·',
          style: AppTypography.caption.copyWith(
            color: AppTheme.textMutedColor(context),
          ),
        ),
        link(context.t(K.termsOfUse), AppConfig.termsOfServiceUrl),
      ],
    );
  }
}
