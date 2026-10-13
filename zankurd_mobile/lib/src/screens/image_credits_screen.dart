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
  List<ImageCredit>? _credits;
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
      final parsed = decoded.entries
          .map(
            (entry) =>
                ImageCredit.fromJson(entry.value as Map<String, dynamic>),
          )
          .toList();
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
    final ku = context.isKu;
    // Sıra görünen başlığa göre; dil değişince başlık da değiştiği için
    // sıralama burada, yüklemede değil.
    final credits = _credits == null
        ? null
        : ([..._credits!]..sort(
            (a, b) =>
                _sortKey(a.heading(ku)).compareTo(_sortKey(b.heading(ku))),
          ));
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

/// Türkçe/Kurmancî alfabe sırası için kaba anahtar.
///
/// `String.compareTo` kod birimine bakar: "ğ" (U+011F) "s"den sonra
/// geldiği için "Ağrı Dağı" "Asurilerin"in ardına düşüyordu. Özel harfler
/// temel harfin hemen ardına yerleştirilir (ç→c~, ı→h~ …); tam bir
/// harmanlama değil, kısa bir liste için yeterli.
String _sortKey(String text) {
  const map = {
    'ç': 'c~',
    'ğ': 'g~',
    'ı': 'h~',
    'ö': 'o~',
    'ş': 's~',
    'ü': 'u~',
    'ê': 'e~',
    'î': 'i~',
    'û': 'u~~',
  };
  final out = StringBuffer();
  for (final ch in text.toLowerCase().split('')) {
    out.write(map[ch] ?? ch);
  }
  return out.toString();
}

/// Künye satırının verisi; başlık seçimi test edilebilsin diye açık.
@visibleForTesting
class ImageCredit {
  const ImageCredit({
    required this.title,
    required this.artist,
    required this.license,
    required this.source,
    this.captionKu = '',
    this.captionTr = '',
  });

  factory ImageCredit.fromJson(Map<String, dynamic> json) => ImageCredit(
    title: (json['title'] as String?) ?? '',
    artist: (json['artist'] as String?) ?? '',
    license: (json['license'] as String?) ?? '',
    source: (json['source'] as String?) ?? '',
    captionKu: (json['caption_ku'] as String?) ?? '',
    captionTr: (json['caption_tr'] as String?) ?? '',
  );

  final String title;
  final String artist;
  final String license;
  final String source;

  /// Görselin ne gösterdiği, oyuncunun dilinde.
  ///
  /// Başlık satırı Wikimedia dosya adıydı; temizlense de İngilizce kalıyordu
  /// ("Great Zab 02", "Tandoor") ve Kurmancî/Türkçe ekranda yabancı bir
  /// liste gibi duruyordu (2026-09-30 simülatör denetimi). Dosya adı
  /// silinmedi: eserin kendi adı olarak altta küçük satırda durur.
  final String captionKu;
  final String captionTr;

  /// Satırın başlığı: dildeki alt yazı, yoksa temizlenmiş dosya adı.
  String heading(bool ku) {
    final caption = ku ? captionKu : captionTr;
    return caption.isNotEmpty ? caption : displayTitle;
  }

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

  final ImageCredit credit;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final heading = credit.heading(context.isKu);
    final workTitle = credit.displayTitle;
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
          Text(heading, style: SahneType.bodyStrong.copyWith(color: t.tx)),
          if (workTitle != heading) ...[
            const SizedBox(height: SahneSpace.x1),
            Text(workTitle, style: SahneType.caption.copyWith(color: t.tx2)),
          ],
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
