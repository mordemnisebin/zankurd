import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'kilim_pattern_painter.dart';
import 'roj_mascot.dart';

/// Günün sözü: (Kurmancî atasözü, Türkçe karşılığı).
typedef _Saying = (String ku, String tr);

/// Zana'nın "Gotina Rojê" kartı — ana ekranın alt boşluğunu dolduran,
/// maskotlu ve gün bazlı dönen kültürel dokunuş. Aynı gün herkes aynı
/// sözü görür (gün-tohumlu seçim; ağ/durum bağımlılığı yok).
class ZanaDailyCard extends StatelessWidget {
  const ZanaDailyCard({
    required this.isKu,
    this.dayOverride,
    this.onStart,
    this.reviewReadyCount = 0,
    super.key = const ValueKey('zana-daily-card'),
  });

  final bool isKu;

  /// Test için sabit gün indeksi; null ise bugünden türetilir.
  final int? dayOverride;
  final VoidCallback? onStart;

  /// Tekrara hazır (SM-2) soru sayısı. >0 ise günlük hedef, öğrenme yerine
  /// aralıklı tekrarı önceliklendirir; CTA aynı [onStart] akışını tetikler
  /// (Fêr Bibe sekmesindeki "Bugünkü Tekrarlar" kartına yönlenir).
  final int reviewReadyCount;

  static const List<_Saying> _sayings = [
    ('Zanîn ronahî ye.', 'Bilgi ışıktır.'),
    ('Dilop bi dilop gol çêdibe.', 'Damla damla göl olur.'),
    ('Gotina rast şîrîn e.', 'Doğru söz tatlıdır.'),
    ('Yek gul biharê nayîne.', 'Bir çiçekle bahar gelmez.'),
    ('Ziman mifta dil e.', 'Dil, gönlün anahtarıdır.'),
    ('Aqil tacê zêrîn e.', 'Akıl altın taçtır.'),
    ('Hevaltî dewlemendiya dil e.', 'Dostluk gönlün zenginliğidir.'),
    ('Bêhna fireh mifta serkeftinê ye.', 'Sabır, başarının anahtarıdır.'),
    ('Her roj hînbûnek nû ye.', 'Her gün yeni bir öğrenmedir.'),
    ('Çirûskek dikare daristanê ronî bike.', 'Bir kıvılcım ormanı aydınlatır.'),
  ];

  _Saying get _todaysSaying {
    final day =
        dayOverride ??
        DateTime.now().toUtc().difference(DateTime.utc(2026)).inDays;
    return _sayings[day % _sayings.length];
  }

  @override
  Widget build(BuildContext context) {
    final saying = _todaysSaying;
    const tint = AppTheme.gold;
    final surface = AppTheme.surfaceHiColor(context);
    // Günlük hedef modunda hazır tekrar varsa, öğrenme yerine aralıklı
    // tekrarı önceliklendir.
    final hasReview = onStart != null && reviewReadyCount > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // Açık sıcak sarı yüzey (altın + sıcak turuncu blend).
              Color.alphaBlend(tint.withValues(alpha: 0.16), surface),
              Color.alphaBlend(
                AppTheme.brandGreenDeep.withValues(alpha: 0.08),
                surface,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: tint.withValues(alpha: 0.30), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: const KilimPatternPainter(
                    drawPattern: true,
                    color: AppTheme.gold,
                    opacity: 0.04,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                const RojMascot(size: 48, mood: RojMood.happy),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.format_quote_rounded,
                            color: AppTheme.gold,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              hasReview
                                  ? (isKu
                                        ? 'Dubarekirinên Îro'
                                        : 'Bugünkü Tekrarlar')
                                  : onStart != null
                                  ? (isKu ? 'Armanca Îro' : 'Bugünün hedefi')
                                  : (isKu ? 'Gotina Rojê' : 'Günün Sözü'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        hasReview
                            ? (isKu
                                  ? '$reviewReadyCount pirs li benda dubarekirinê'
                                  : '$reviewReadyCount soru tekrara hazır')
                            : onStart != null
                            ? (isKu
                                  ? 'Bi 3 bersivên rast zincîra xwe biparêze'
                                  : '3 doğru cevapla serini koru')
                            : saying.$1,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w800,
                          fontStyle: FontStyle.italic,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasReview
                            ? (isKu
                                  ? 'Zana dubarekirinên te amade kir.'
                                  : 'Zana tekrarlarını hazırladı.')
                            : onStart != null
                            ? (isKu
                                  ? 'Zana rêya îro ji te re amade kir.'
                                  : 'Zana bugünkü yolunu hazırladı.')
                            : saying.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                      if (onStart != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: onStart,
                          icon: Icon(
                            hasReview
                                ? Icons.refresh_rounded
                                : Icons.arrow_forward_rounded,
                          ),
                          label: Text(
                            hasReview
                                ? (isKu
                                      ? 'Dest bi dubarekirinê'
                                      : 'Tekrara başla')
                                : (isKu
                                      ? 'Dest bi hînbûnê bike'
                                      : 'Öğrenmeye başla'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
