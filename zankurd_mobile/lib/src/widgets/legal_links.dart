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

  /// KVKK/gizlilik/şartlar bağlantısını açar.
  ///
  /// Eskiden `launchUrl`ın dönen `bool` sonucu (cihazda bu şemayı açacak
  /// bir uygulama yoksa `false` döner, İSTİSNA FIRLATMAZ) hiç okunmuyordu
  /// — yalnız `catch` vardı. Kullanıcı yasal bir bağlantıya dokunuyor,
  /// hiçbir şey açılmıyor, hiçbir geri bildirim de yok: dokunuşun işe
  /// yaradığından bile emin olamıyordu (2026-08-14 denetimi). Ayarlar
  /// ekranındaki `_openAbuseReport`/`_openBetaFeedback` ile aynı desen:
  /// `ok == false` ve `catch` ikisi de aynı görünür SnackBar'a çıkar.
  static Future<void> _open(BuildContext context, String url) async {
    final failed = context.t(K.linkOpenFailed);
    try {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok || !context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failed)));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'legal link open: $url');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failed)));
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
      onTap: () => _open(context, url),
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
