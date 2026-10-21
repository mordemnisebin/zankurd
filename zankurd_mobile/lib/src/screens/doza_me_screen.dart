import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../utils/error_reporter.dart';
import '../widgets/sahne/sahne.dart';

/// "Doza me / Davamız" — uygulamanın kimlik ve değerler sayfası.
///
/// Metinler jüriden geçmiş kimlik metnidir ve `strings.dart` içinde AYNEN
/// durur (`K.doza*`); burada yeniden yazılmaz, kısaltılmaz. Hiçbir parti,
/// örgüt, kişi adı ya da sembol yoktur: dil, hak ve özgür yaşam değerleri.
///
/// Düzen: Sahne açılan sayfa → giriş paragrafı → "Mafên me, daxwazên me"
/// başlığı altında sekiz madde (numaralı, ikonlu kartlar) → vurgulu kapanış
/// kartı → altta tek birincil eylem: kapanış metnini ve uygulama bağlantısını
/// paylaş.
class DozaMeScreen extends StatelessWidget {
  const DozaMeScreen({super.key, this.onShare});

  /// Paylaşım kancası (testler); verilmezse sistem paylaşım sayfası açılır.
  final Future<void> Function(String text)? onShare;

  /// Paylaşılan metnin sonundaki uygulama bağlantısı.
  static const appLink = 'https://zankurd.com';

  static const _items = <_Item>[
    _Item(K.dozaM1Head, K.dozaM1Body, AppIcons.bookOpenReader),
    _Item(K.dozaM2Head, K.dozaM2Body, AppIcons.language),
    _Item(K.dozaM3Head, K.dozaM3Body, AppIcons.idBadge),
    _Item(K.dozaM4Head, K.dozaM4Body, AppIcons.peopleGroup),
    _Item(K.dozaM5Head, K.dozaM5Body, AppIcons.venus),
    _Item(K.dozaM6Head, K.dozaM6Body, AppIcons.locationDot),
    _Item(K.dozaM7Head, K.dozaM7Body, AppIcons.music),
    _Item(K.dozaM8Head, K.dozaM8Body, AppIcons.mountain),
  ];

  Future<void> _share(BuildContext context) async {
    final text = '${context.t(K.dozaClosing)}\n$appLink';
    final hook = onShare;
    try {
      if (hook != null) {
        await hook(text);
      } else {
        await SharePlus.instance.share(ShareParams(text: text));
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'doza_me_share');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final rightsSecond = context.secondLabel(K.dozaRights);
    return SahnePushedPage(
      title: context.t(K.dozaTitle),
      subtitle: context.secondLabel(K.dozaTitle),
      backLabel: context.t(K.back),
      bottom: SahneButton.primary(
        key: const ValueKey('doza-share-button'),
        label: context.t(K.dozaShare),
        icon: AppIcons.shareNodes,
        expand: true,
        onPressed: () => _share(context),
      ),
      children: [
        const SizedBox(height: SahneSpace.x2),
        Text(
          context.t(K.dozaIntro),
          key: const ValueKey('doza-intro'),
          style: SahneType.body.copyWith(color: t.tx, height: 28 / 16),
        ),
        SahneSectionHeader(
          title: context.t(K.dozaRights),
          eyebrow: rightsSecond,
        ),
        for (var i = 0; i < _items.length; i++) ...[
          _ItemCard(index: i + 1, item: _items[i]),
          const SizedBox(height: SahneSpace.cardGap),
        ],
        const SizedBox(height: SahneSpace.x2),
        const _ClosingCard(),
        const SizedBox(height: SahneSpace.x4),
      ],
    );
  }
}

class _Item {
  const _Item(this.headKey, this.bodyKey, this.icon);
  final String headKey;
  final String bodyKey;
  final IconData icon;
}

/// Bir madde: solda ton karoda ikon ve numara, sağda kalın başlık + metin.
class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.index, required this.item});

  final int index;
  final _Item item;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final head = context.t(item.headKey);
    final body = context.t(item.bodyKey);
    final second = context.secondLabel(item.headKey);
    return SahneSurfaceCard(
      key: ValueKey('doza-item-$index'),
      semanticLabel: '$index. $head. $body',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: SahneSpace.x2),
              decoration: ShapeDecoration(
                color: t.learnTint,
                shape: SahneShape.m,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 22, color: t.learnTx),
                  const SizedBox(height: SahneSpace.x1),
                  Text(
                    '$index',
                    style: SahneType.captionStrong.copyWith(
                      color: t.learnTx,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: SahneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (second != null) SahneBilingualLabel(second),
                SahneUnbrokenText(
                  head,
                  style: SahneType.button.copyWith(color: t.tx),
                ),
                const SizedBox(height: SahneSpace.x1),
                Text(body, style: SahneType.body.copyWith(color: t.tx2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kapanış: dolu Zimrût kart; sloganlar kalın ve eğik.
class _ClosingCard extends StatelessWidget {
  const _ClosingCard();

  /// Kapanış metninin sloganlarla başlayan kuyruğu (iki dilde de aynı söz).
  static const _sloganStart = 'Berxwedan jiyan e.';

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final text = context.t(K.dozaClosing);
    final cut = text.indexOf(_sloganStart);
    final base = SahneType.headline.copyWith(color: SahneVivid.onFill);
    final emphasis = base.copyWith(
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
    );
    return SahneSurfaceCard(
      key: const ValueKey('doza-closing'),
      color: t.learnFill,
      edgeColor: t.learnFill,
      padding: const EdgeInsets.all(SahneSpace.x6),
      semanticLabel: text,
      child: ExcludeSemantics(
        child: Text.rich(
          cut <= 0
              ? TextSpan(text: text, style: base)
              : TextSpan(
                  children: [
                    TextSpan(text: text.substring(0, cut), style: base),
                    TextSpan(text: text.substring(cut), style: emphasis),
                  ],
                ),
        ),
      ),
    );
  }
}
