import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../config/category_visuals.dart';
import 'category_kicker_mark.dart';
import 'quiz_stage_kit.dart';
import 'sahne/sahne.dart';

/// Bütün soru ekranlarının ORTAK üst satır ortası (kurul 2. tur, 2026-10-20).
///
/// Kusur: ders, yarışma, seviye belirleme ve eşzamansız düello üst satırı
/// ayrı ayrı kuruyordu — kategori/sıra kimisinde ortada, kimisinde gövdede
/// ayrı satırdı, düelloda hiç yoktu. Dokuz modelli panelin üçü aynı şeyi
/// söyledi: "aynı uygulamada dört soru ekranı gibi". Tek bileşen:
/// `[kategori işareti] Soru n/N · Kategori`; kapat solda, sayaç ve ⋯ menüsü
/// sağda, altında 4 px'lik ilerleme çubuğu [SahneStageScaffold] üzerinden
/// her modda aynıdır.
class QuizStageCenter extends StatelessWidget {
  const QuizStageCenter({
    super.key,
    required this.category,
    required this.index,
    required this.total,
    this.textKey = const ValueKey('quiz-stage-kicker'),
    this.keyed,
    this.onBand = false,
    this.title,
    this.modeLabel,
  });

  final String category;

  /// Mod çipi ("Yarış", "Ders", "Düello"…): üst çubukta TEK küçük çip
  /// (2026-10-28, jüri K6+). Dar ekranda ve büyük yazıda düşer; mod gövdede
  /// ayrıca anlatılmaz.
  final String? modeLabel;

  /// Konu adı yerine yazılacak başlık. Seviye testinde soru konusu
  /// ("Siyaset") değil testin adı okunur: konu etiketi testi genel kültür
  /// sınavı gibi gösteriyordu (tam uygulama incelemesi 2026-10-22, 4 model).
  final String? title;

  /// 0 tabanlı geçerli soru.
  final int index;
  final int total;

  /// Etiket metninin anahtarı (testler okur).
  final Key textKey;

  /// Dış sarmalayıcıya verilecek anahtar (coach-mark hedefi gibi).
  final Key? keyed;

  /// Konu renginde dolu bandın üstünde: beyaz yazı ve beyaz konu ikonu.
  final bool onBand;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final name = title ?? CategoryNames.localized(category, context.isKu);
    final progress = context.t(K.placementProgress, {
      'index': '${index + 1}',
      'total': '$total',
    });
    // SIRA: sayaç BAŞTA, kategori sonda. Tek satırda kısaltma sondan yer;
    // "Teknoloji · Sor…" biçiminde kesilen şey sayaç oluyordu (kaçıncı soruda
    // olduğunu göstermek kategori adından önemli). İki `Text`li `Row`
    // denendi: orta yuva `_RenderGameBar` içinde kuru yerleşim ölçülür ve
    // `FittedBox`/sınırsız genişlikte `Row` istisna fırlatıyordu; tek `Text`
    // hem güvenli hem testlerin okuduğu tek künyedir
    // (`quiz_stage_center_counter_test`).
    // Büyük yazıda (≥ 1.5) künye işareti düşer: 320 px @2.0'da işaret +
    // saniye + ⋯ yanında kategori adı "Siya…" diye kesiliyor ve "Soru 1/5"
    // hiç görünmüyordu. Ad ve sıra, işaretten önemli.
    //
    // Dar telefonda (≤ 340 dp) da düşer: kapat + skor + saniye + ⋯ yanında
    // 32 px'lik işaret, sayacın son harflerini yiyordu. Büyük yazıda künye
    // iki satıra inebilir: sayaç ilk satırda kalır, kısaltma yalnız ikinci
    // satırdaki kategori adına düşer.
    final largeText = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final compact = largeText || MediaQuery.sizeOf(context).width <= 340;
    final chip = modeLabel;
    final showChip = chip != null && chip.isNotEmpty && !compact;
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact) ...[
          if (onBand)
            Icon(
              CategoryVisuals.icon(category),
              key: const ValueKey('quiz-question-icon-badge'),
              size: 22,
              color: SahneVivid.onFill,
            )
          else
            CategoryKickerMark(
              key: const ValueKey('quiz-question-icon-badge'),
              category: category,
              fallbackColor: t.tx2,
              size: 24,
            ),
          const SizedBox(width: SahneSpace.x2),
        ],
        Flexible(
          child: Text(
            '$progress · $name',
            key: textKey,
            maxLines: largeText ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: SahneType.eyebrow.copyWith(
              color: onBand ? SahneVivid.onFill : t.tx,
            ),
          ),
        ),
      ],
    );
    return KeyedSubtree(
      key: keyed,
      child: Semantics(
        header: true,
        child: showChip
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuizModeChip(label: chip),
                  const SizedBox(height: SahneSpace.x1),
                  line,
                ],
              )
            : line,
      ),
    );
  }
}

/// Dock'suz soru ekranlarında (seviye sınavı, eşzamansız düello) şıkların
/// ekranın dibinden uzaklığı: ders/yarışmada şıklar alt perdenin
/// (≈76 + güvenli alan) 160 + 24 px üstünde biter; bu ekranlarda perde
/// olmadığı için aynı mesafe boşlukla verilir (kurul 2. tur, ekran 40/99:
/// "şıklar her modda dipten aynı uzaklıkta"). Kısa ekranda gövdenin %28'iyle
/// sınırlanır, yoksa içerik sıkışır.
double quizAnswerBottomReserve(BuildContext context, double viewport) {
  final safe = MediaQuery.paddingOf(context).bottom;
  return (76 + safe + 160 + SahneSpace.x6).clamp(0.0, viewport * 0.28);
}
