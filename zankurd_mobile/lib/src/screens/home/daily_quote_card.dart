import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_config.dart';
import '../../data/daily_quote_store.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../providers/bilingual_labels_provider.dart';
import '../../theme/app_icons.dart';
import '../../widgets/sahne/sahne.dart';

/// Ana ekranın "Gotina rojê / Günün sözü" kartı.
///
/// Her gün tek bir söz: Kurmancî söz büyük (başlık ölçeği, tırnaklı),
/// Türkçe karşılığı küçük ikinci satır, kaynak soluk. Türkçe satır arayüz
/// Kurmancî olsa da gösterilir (öğretici); yalnız "iki dilli etiket" ayarı
/// kapalı VE arayüz Kurmancîyse gizlenir. Sağ üstte paylaş düğmesi.
///
/// Renk: Zêr (altın) tonlu zemin, ince Zêr kenar; ödül/ışık rengi "bugünün
/// armağanı" duygusunu verir, öğrenme (Zimrût) ve yarış (Boyax) kartlarıyla
/// karışmaz. Çizim saat kaynağından ([SahneClock]) okur: gün değişince bir
/// sonraki çizimde yeni söz gelir.
class DailyQuoteCard extends StatefulWidget {
  const DailyQuoteCard({
    required this.isKu,
    this.quotes,
    this.onShare,
    super.key,
  });

  final bool isKu;

  /// Verilirse derlem buradan (test); yoksa [DailyQuoteStore].
  final List<DailyQuote>? quotes;

  /// Verilirse paylaşım metni buraya gider (test); yoksa share_plus.
  final void Function(String text)? onShare;

  /// Sözün tırnak içindeki hâli. Türkçe ve Kurmancî yazımda açılış da
  /// kapanış da üstte durur (“…”); önceki Almanca alt açılış tırnağı kullanıcı
  /// geri bildiriminde "yanlış yerde" diye bildirildi (2026-10-23).
  static String quoted(String text) => '“$text”';

  /// Paylaşım metni. Sondaki bağlantılar mağazaya gider; zankurd.com web
  /// sürümüne götürüyordu (2026-10-25).
  static String shareText(DailyQuote q) => [
    '${quoted(q.ku)} — ${q.tr}',
    q.source,
    'ZanKurd',
    'App Store: ${AppConfig.appStoreUrl}',
    'Google Play: ${AppConfig.playStoreUrl}',
  ].join('\n');

  @override
  State<DailyQuoteCard> createState() => _DailyQuoteCardState();
}

class _DailyQuoteCardState extends State<DailyQuoteCard> {
  List<DailyQuote>? _quotes;

  @override
  void initState() {
    super.initState();
    _quotes = widget.quotes ?? DailyQuoteStore.cached;
    if (_quotes == null) {
      DailyQuoteStore.load().then((list) {
        if (mounted) setState(() => _quotes = list);
      });
    }
  }

  void _share(DailyQuote q) {
    HapticFeedback.selectionClick();
    final text = DailyQuoteCard.shareText(q);
    final cb = widget.onShare;
    if (cb != null) {
      cb(text);
    } else {
      SharePlus.instance.share(ShareParams(text: text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = widget.quotes ?? _quotes;
    final quote = quotes == null ? null : DailyQuoteStore.pick(quotes);
    if (quote == null) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final isKu = widget.isKu;
    final showTr = !isKu || BilingualLabelsProvider.isEnabledIn(context);
    final label = Tr.forKu(K.gotinaRoje, isKu);
    return Padding(
      key: const ValueKey('home-daily-quote'),
      padding: const EdgeInsets.only(top: SahneSpace.cardGap),
      child: Semantics(
        container: true,
        label: '$label. ${quote.ku}${showTr ? '. ${quote.tr}' : ''}',
        child: SahneSurfaceCard(
          color: t.goldTint,
          edgeColor: t.goldTx.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: SahneType.eyebrow.copyWith(color: t.goldTx),
                    ),
                  ),
                  SahneIconButton(
                    key: const ValueKey('home-daily-quote-share'),
                    icon: AppIcons.shareNodes,
                    semanticLabel: context.t(K.share),
                    quiet: true,
                    onPressed: () => _share(quote),
                  ),
                ],
              ),
              Text(
                DailyQuoteCard.quoted(quote.ku),
                key: const ValueKey('home-daily-quote-ku'),
                style: SahneType.headline.copyWith(color: t.tx),
              ),
              if (showTr) ...[
                const SizedBox(height: SahneSpace.x2),
                Text(
                  quote.tr,
                  key: const ValueKey('home-daily-quote-tr'),
                  style: SahneType.body.copyWith(color: t.tx2),
                ),
              ],
              if (quote.source.isNotEmpty) ...[
                const SizedBox(height: SahneSpace.x2),
                Text(
                  quote.source,
                  key: const ValueKey('home-daily-quote-source'),
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
