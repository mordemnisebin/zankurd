import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../utils/external_link.dart';
import '../widgets/app_panel.dart';

/// Soru fotoğraflarının künyesi.
///
/// Fotoğraflar Wikimedia Commons'tan, yalnız kamu malı / CC0 / CC BY
/// lisanslarıyla alındı (2026-07-26 kararı; CC BY-SA share-alike
/// yükümlülüğü doğurduğu için dışarıda bırakıldı).
///
/// **CC BY atıf ister ve bu ekran o yükümlülüğün karşılığıdır.** Fotoğrafı
/// atıfsız kullanmak lisans ihlalidir; ekranı kaldırmak ya da künyeyi
/// eksiltmek uygulamayı ihlale sokar. `assets/data/image_credits.json`
/// indirme aracı tarafından yazılır, elle düzenlenmez.
class ImageCreditsScreen extends StatefulWidget {
  const ImageCreditsScreen({super.key});

  @override
  State<ImageCreditsScreen> createState() => _ImageCreditsScreenState();
}

class _ImageCreditsScreenState extends State<ImageCreditsScreen> {
  List<_Credit>? _credits;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/data/image_credits.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final parsed =
        decoded.entries
            .map(
              (entry) => _Credit.fromJson(entry.value as Map<String, dynamic>),
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    if (mounted) setState(() => _credits = parsed);
  }

  @override
  Widget build(BuildContext context) {
    final credits = _credits;
    return Scaffold(
      appBar: AppBar(title: Text(context.t(K.imageCredits))),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: credits == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  children: [
                    Text(
                      context.t(K.imageCreditsIntro),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textMutedColor(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final credit in credits) ...[
                      _CreditTile(credit: credit),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _Credit {
  const _Credit({
    required this.title,
    required this.artist,
    required this.license,
    required this.source,
  });

  factory _Credit.fromJson(Map<String, dynamic> json) => _Credit(
    title: (json['title'] as String?) ?? '',
    artist: (json['artist'] as String?) ?? '',
    license: (json['license'] as String?) ?? '',
    source: (json['source'] as String?) ?? '',
  );

  final String title;
  final String artist;
  final String license;
  final String source;

  /// Okunabilir başlık.
  ///
  /// Künye Wikimedia dosya adını olduğu gibi yazıyordu:
  /// "17331 A group of Kurdish residents in Dahuk, Iraq celebreate the
  /// Kurdish New Year in 2006.jpg" — başında yükleme numarası, sonunda
  /// uzantı. Yasal olarak gereken şey eser, sanatçı, lisans ve bağlantı;
  /// dosya adının teknik kabuğu değil (2026-07-27). Bağlantı zaten
  /// dosyanın kendisine gider, yani hiçbir bilgi kaybolmuyor.
  String get displayTitle {
    var text = title.replaceFirst(
      RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false),
      '',
    );
    // Yükleme/çekim numaraları: "20190510 153415.Koysinjaq…" gibi zincirler
    // için tekrar tekrar kırpılır.
    while (RegExp(r'^\d{3,}[\s._-]+').hasMatch(text)) {
      text = text.replaceFirst(RegExp(r'^\d{3,}[\s._-]+'), '');
    }
    text = text.replaceAll('_', ' ');
    // Fotoğraf makinesi adlandırması boşluk kullanmaz, nokta kullanır.
    // Yalnız o durumda noktalar boşluğa çevrilir; "U.S. Army" gibi normal
    // başlıklar bozulmasın.
    if (!text.contains(' ') && text.contains('.')) {
      text = text.replaceAll('.', ' ');
    }
    text = text.trim();
    return text.isEmpty ? title : text;
  }
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.credit});

  final _Credit credit;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            credit.displayTitle,
            style: AppTypography.bodyLarge.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${credit.artist} · ${credit.license}',
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
            ),
          ),
          if (credit.source.isNotEmpty) ...[
            const SizedBox(height: 6),
            InkWell(
              // Doğrudan `launchUrl` DEĞİL: dönen değeri okumadan, hiçbir
              // `try` olmadan çağrılıyordu. Künye bir lisans metnidir; CC
              // görsellerin atfı çalışan bir kaynak bağlantısı ister ve ölü
              // bağlantı sessizce hiçbir şey yapıyordu (2026-08-17).
              onTap: () => openExternalLink(
                context,
                credit.source,
                reason: 'image credit source',
              ),
              child: Text(
                context.t(K.imageCreditsSource),
                style: AppTypography.caption.copyWith(
                  color: AppTheme.brand,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
