import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../utils/external_link.dart';
import '../widgets/branded_loader.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';

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
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/image_credits.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final parsed =
          decoded.entries
              .map(
                (entry) =>
                    _Credit.fromJson(entry.value as Map<String, dynamic>),
              )
              .toList()
            ..sort((a, b) => a.title.compareTo(b.title));
      if (mounted) {
        setState(() {
          _credits = parsed;
          _loadError = null;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'image credits load failed');
      if (mounted) {
        setState(() {
          _credits = const [];
          _loadError = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final credits = _credits;
    final t = SahneTokens.of(context);
    // 2026-09-29 Şahnê: B iskeleti (başlık çubukta); künye tek bir liste
    // grubunda, her eser bir satır. Hata durumu Şaş metni + ikonla.
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.imageCredits))),
      body: SafeArea(
        top: false,
        child: credits == null
            ? const BrandedLoaderCenter()
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.page,
                  SahneSpace.x2,
                  SahneSpace.page,
                  SahneSpace.x8,
                ),
                children: [
                  Text(
                    context.t(K.imageCreditsIntro),
                    style: SahneType.body.copyWith(color: t.tx2),
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  if (_loadError != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            AppIcons.triangleExclamation,
                            size: 20,
                            color: t.errTx,
                          ),
                        ),
                        const SizedBox(width: SahneSpace.x2),
                        Expanded(
                          child: Text(
                            context.t(K.imageCreditsFailed),
                            style: SahneType.body.copyWith(color: t.errTx),
                          ),
                        ),
                      ],
                    )
                  else if (credits.isEmpty)
                    Text(
                      context.t(K.imageCreditsEmpty),
                      style: SahneType.body.copyWith(color: t.tx2),
                    )
                  else
                    SahneListGroup(
                      children: [
                        for (final credit in credits)
                          _CreditTile(credit: credit),
                      ],
                    ),
                ],
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
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        SahneSpace.x4,
        SahneSpace.x3,
        SahneSpace.x4,
        SahneSpace.x1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            credit.displayTitle,
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            '${credit.artist} · ${credit.license}',
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
          if (credit.source.isNotEmpty)
            // Doğrudan `launchUrl` DEĞİL: dönen değeri okumadan, hiçbir
            // `try` olmadan çağrılıyordu. Künye bir lisans metnidir; CC
            // görsellerin atfı çalışan bir kaynak bağlantısı ister ve ölü
            // bağlantı sessizce hiçbir şey yapıyordu (2026-08-17).
            SahneButton.text(
              label: context.t(K.imageCreditsSource),
              onPressed: () => openExternalLink(
                context,
                credit.source,
                reason: 'image credit source',
              ),
            )
          else
            const SizedBox(height: SahneSpace.x2),
        ],
      ),
    );
  }
}
