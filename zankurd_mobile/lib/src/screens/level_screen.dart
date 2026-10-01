import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../data/level_progress_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_level.dart';
import '../widgets/app_state.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/category_band.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'quiz_screen.dart';
import '../config/subcategory_config.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class LevelScreen extends StatefulWidget {
  const LevelScreen({
    required this.repository,
    required this.category,
    this.subCategory,
    super.key,
  });

  final ZanKurdRepository repository;
  final String category;
  final String? subCategory;

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  bool _loading = false;
  Set<int> _playedLevels = const {};
  QuizLevel? _retryLevel;
  _LevelLoadState _loadState = _LevelLoadState.ready;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final store = await LevelProgressStore.load();
    if (!mounted) return;
    setState(() {
      _playedLevels = {
        for (var n = 1; n <= 5; n++)
          if (store.isPlayed(widget.category, widget.subCategory, n)) n,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final levels = widget.repository.levelsForCategory(widget.category);
    final heading = _LevelHeading.of(widget.category, widget.subCategory, ku);

    // 2026-09-30 izgara: başlık alt kategori ekranıyla AYNI bantlı bileşendir
    // ([CategoryBandScaffold]; kategori tonu + kilim deseni). Eskiden bu
    // ekran düz gündüz çubuğu ve başka bir geri düğmesi taşıyordu; konu
    // akışında bir adım ilerleyince başlık değişiyordu. İçerik: ilerleme
    // kartı → seviye yolu (sıradaki seviye sahne kartında, ekranın TEK
    // birincil eylemiyle).
    return CategoryBandScaffold(
      category: widget.category,
      title: heading.title,
      subtitle: heading.subtitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          SahneSpace.page,
          SahneSpace.x4,
          SahneSpace.page,
          SahneSpace.x6,
        ),
        children: [
          if (levels.isNotEmpty) ...[
            _LevelProgressCard(
              description: heading.description,
              completed: _playedLevels.length,
              total: levels.length,
              isKu: ku,
            ),
            const SizedBox(height: SahneSpace.x4),
          ],
          switch (_loadState) {
            _LevelLoadState.error => AppErrorState(
              title: context.t(K.loadFailedShort),
              message: context.t(K.buSeviyeninSorulariYuklenemedi),
              retryLabel: context.t(K.retryShort),
              onRetry: _retrySelectedLevel,
            ),
            _LevelLoadState.empty => AppEmptyState(
              icon: AppIcons.bookOpen,
              title: context.t(K.noQuestionsForCategory),
              message: context.t(K.buSeviyeninSorulariYuklenemedi),
              actionLabel: context.t(K.retryShort),
              onAction: _retrySelectedLevel,
            ),
            _LevelLoadState.ready => _LevelPath(
              levels: levels,
              disabled: _loading,
              isKu: ku,
              playedLevels: _playedLevels,
              onOpen: _openLevel,
            ),
          },
        ],
      ),
    );
  }

  Future<void> _openLevel(QuizLevel level) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _retryLevel = level;
      _loadState = _LevelLoadState.ready;
    });
    try {
      final questions = await widget.repository.loadLevelQuestions(
        category: level.category,
        difficultyMin: level.difficultyMin,
        difficultyMax: level.difficultyMax,
        subCategory: widget.subCategory,
        limit: level.questionCount,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        setState(() => _loadState = _LevelLoadState.empty);
        return;
      }
      final room = widget.repository
          .createRoom(category: level.category)
          .copyWith(
            // Kategori KİMLİĞİ değil, kullanıcının dilindeki ADI.
            //
            // Burada `level.category` doğrudan yazılıyordu: kimlikler
            // Kurmancî kökenli olduğu için Türkçe arayüzde soru ekranının
            // başlığı "Ziman 1. Seviye" çıkıyor, aynı ekranın kategori çipi
            // ise "Dil" diyordu. Aynı kategori iki adla, tek ekranda
            // (2026-08-16 simülatör taraması).
            name:
                '${CategoryNames.localized(level.category, context.isKu)} '
                '${level.number}. ${context.t(K.progressLevelLabel)}',
            questionCount: questions.length,
          );
      final result = await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            // Kategori seviyeleri bir öğrenme yolunun basamaklarıdır,
            // yarışma değil: süre baskısı olmadan her cevaptan sonra
            // açıklama gösterilir. Varsayılan `competition` bırakıldığında
            // "Ziman → Rêziman → Destpêk" gibi apaçık ders akışlarında
            // kullanıcı yanlışının nedenini hiç öğrenemiyordu
            // (2026-07-25 canlı denetimi). Ana ekranın "Günün Dersi"
            // akışı zaten bu ayarda.
            experience: QuizExperience.learning,
            enableTimer: false,
          ),
        ),
      );
      // Yoldaki düğümü yalnız quiz gerçekten bitince işaretle: sonuç ekranı
      // skor haritasıyla döner; yarıda bırakma null döner ve tik almamalı.
      if (result is Map) {
        final store = await LevelProgressStore.load();
        await store.markPlayed(
          widget.category,
          widget.subCategory,
          level.number,
        );
      }
      await _loadProgress();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'level questions load failed');
      if (!mounted) return;
      setState(() => _loadState = _LevelLoadState.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _retrySelectedLevel() {
    final level = _retryLevel;
    if (level != null) _openLevel(level);
  }
}

enum _LevelLoadState { ready, empty, error }

/// Çubuğun adı ve alt satırı, ilerleme kartının açıklaması.
///
/// Alt kategoriyle açılınca ad alt kategorinin adıdır, alt satır kategori
/// adı ve açıklama alt kategorinin açıklamasıdır; yalnız kategoriyle
/// açılınca ad kategori adı, alt satır "Kolaydan zora doğru ilerle".
/// Kategori KİMLİĞİ hiçbir zaman gösterilmez (`CategoryNames.localized`).
class _LevelHeading {
  const _LevelHeading(this.title, this.subtitle, this.description);

  final String title;
  final String subtitle;
  final String? description;

  factory _LevelHeading.of(String category, String? subCategory, bool isKu) {
    final categoryName = CategoryNames.localized(category, isKu);
    if (subCategory != null) {
      final list = SubcategoryConfig.forCategory(category);
      for (final sub in list) {
        if (sub.id == subCategory) {
          return _LevelHeading(
            isKu ? sub.nameKu : sub.nameTr,
            categoryName,
            isKu ? sub.descriptionKu : sub.descriptionTr,
          );
        }
      }
    }
    return _LevelHeading(
      categoryName,
      Tr.forKu(K.kolaydanZoraDogruIlerle, isKu),
      null,
    );
  }
}

/// İlerleme kartı (yüzey kartı): varsa alt kategorinin açıklaması, altında
/// öğrenme tonlu ilerleme çubuğu ve "2/5 seviye". Ekran okuyucu tek bir
/// cümle duyar: "5 seviyeden 2 tanesi tamamlandı".
class _LevelProgressCard extends StatelessWidget {
  const _LevelProgressCard({
    required this.description,
    required this.completed,
    required this.total,
    required this.isKu,
  });

  final String? description;
  final int completed;
  final int total;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final ratio = total <= 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    final text = description?.trim();
    return SahneSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (text != null && text.isNotEmpty) ...[
            Text(text, style: SahneType.body.copyWith(color: t.tx2)),
            const SizedBox(height: SahneSpace.x3),
          ],
          SahneProgressBar(
            value: ratio,
            trailing: Tr.forKu(K.pPSeviye, isKu, {
              'p0': '$completed',
              'p1': '$total',
            }),
            semanticLabel: Tr.forKu(K.progressLevelsCompleted, isKu, {
              'completed': '$completed',
              'total': '$total',
            }),
          ),
        ],
      ),
    );
  }
}

/// Seviye yolu: seviyeler sırayla alt alta kart. Sıradaki seviye sahne
/// kartıdır (tek birincil düğme); ötekiler yüzey kartı.
///
/// 2026-09-29 doğallık (K5): solda her kartın yanında bir yol elması
/// (bitti / sıradaki / kilitli) ve onları bağlayan yol çizgisi vardı. Kartın
/// rozeti aynı durumu zaten söylüyordu (yıldız / numara / kilit); elmas
/// ikinci bir işaretti ve elmas yalnız soru ilerlemesi ile ders sayacında
/// kalır. Sıra, kartların sırasıyla okunur.
class _LevelPath extends StatelessWidget {
  const _LevelPath({
    required this.levels,
    required this.disabled,
    required this.isKu,
    required this.playedLevels,
    required this.onOpen,
  });

  final List<QuizLevel> levels;
  final bool disabled;
  final bool isKu;
  final Set<int> playedLevels;
  final ValueChanged<QuizLevel> onOpen;

  bool _isUnlocked(int number) {
    if (number <= 1) return true;
    return playedLevels.contains(number - 1);
  }

  int? get _nextNumber {
    for (final level in levels) {
      if (!playedLevels.contains(level.number)) return level.number;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < levels.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == levels.length - 1 ? 0 : SahneSpace.cardGap,
            ),
            child: _LevelNode(
              key: ValueKey('level-node-${levels[i].number}'),
              level: levels[i],
              disabled: disabled,
              isKu: isKu,
              played: playedLevels.contains(levels[i].number),
              isNext: levels[i].number == next,
              locked: !_isUnlocked(levels[i].number),
              onTap: () => onOpen(levels[i]),
            ),
          ),
      ],
    );
  }
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    super.key,
    required this.level,
    required this.disabled,
    required this.isKu,
    required this.played,
    required this.isNext,
    required this.locked,
    required this.onTap,
  });

  final QuizLevel level;
  final bool disabled;
  final bool isKu;
  final bool played;
  final bool isNext;
  final bool locked;
  final VoidCallback onTap;

  void _explainLock(BuildContext context) {
    final previous = level.number - 1;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.t(K.oncePSeviyeyiTamamla, {'p0': '$previous.'}),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = disabled || locked;
    final name = LevelNames.localized(level.title, isKu);
    final label = locked
        ? context.t(K.pKilitliOncekiSeviyeyi, {'p0': name})
        : isNext
        ? context.t(K.homePathNext, {'name': name})
        : name;
    final VoidCallback? tap = disabled
        ? null
        : locked
        ? () => _explainLock(context)
        : onTap;

    if (isNext && !locked) {
      // Sıradaki seviye: sahne kartı (gece, öğrenme rolü) + TEK birincil
      // düğme. Kartın her yeri dokunulabilir; düğme aynı işi yapar.
      return Semantics(
        container: true,
        button: true,
        enabled: !blocked,
        onTap: blocked ? null : onTap,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tap,
          child: SahneStageCard(
            key: ValueKey('level-card-${level.number}'),
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LevelRowContent(
                    level: level,
                    name: name,
                    badge: _LevelBadge.next,
                    headline: true,
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  SahneButton.primary(
                    label: context.t(K.start),
                    onPressed: disabled ? null : onTap,
                    expand: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      button: true,
      enabled: !blocked,
      onTap: blocked ? null : onTap,
      label: label,
      excludeSemantics: true,
      child: SahneSurfaceCard(
        key: ValueKey('level-card-${level.number}'),
        onTap: tap,
        padding: const EdgeInsetsDirectional.fromSTEB(
          SahneSpace.x3,
          SahneSpace.x3,
          SahneSpace.x4,
          SahneSpace.x3,
        ),
        child: _LevelRowContent(
          level: level,
          name: name,
          badge: locked
              ? _LevelBadge.locked
              : played
              ? _LevelBadge.played
              : _LevelBadge.open,
          trailing: locked ? null : AppIcons.chevronRight,
        ),
      ),
    );
  }
}

/// Seviye rozeti (44'lük M karo) dört dil konuşur: kilitli (Kulis + kilit;
/// ikon ikincil metinde — üçüncül metin Kulis üstünde 4.49:1 kalıyor),
/// oynanmış (Zêr tonu + yıldız glifi — altın bu uygulamada yalnız
/// KAZANILMIŞ ödül demektir), sıradaki (Zimrût tonu + numara) ve nadiren
/// "açık ama sırada değil" (Kulis + numara; düz ilerlemede hemen hiç
/// oluşmaz).
enum _LevelBadge { locked, played, next, open }

class _LevelRowContent extends StatelessWidget {
  const _LevelRowContent({
    required this.level,
    required this.name,
    required this.badge,
    this.headline = false,
    this.trailing,
  });

  final QuizLevel level;
  final String name;
  final _LevelBadge badge;

  /// Sahne kartında ad Manşet 22; satırda Gövde 700.
  final bool headline;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final locked = badge == _LevelBadge.locked;
    final number = Text(
      '${level.number}',
      style: SahneType.headline.copyWith(
        color: badge == _LevelBadge.next ? t.learnTx : t.tx,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final (Color tile, Widget mark) = switch (badge) {
      _LevelBadge.locked => (t.s2, Icon(AppIcons.lock, color: t.tx2, size: 20)),
      _LevelBadge.played => (
        t.goldTint,
        const SahneGlyph(SahneGlyphKind.star, size: 24),
      ),
      _LevelBadge.next => (t.learnTint, number),
      _LevelBadge.open => (t.s2, number),
    };
    final badgeTile = DecoratedBox(
      decoration: ShapeDecoration(color: tile, shape: SahneShape.m),
      child: SizedBox.square(dimension: 44, child: Center(child: mark)),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: (headline ? SahneType.headline : SahneType.bodyStrong)
              .copyWith(color: locked ? t.tx2 : t.tx),
        ),
        const SizedBox(height: SahneSpace.x1),
        Row(
          children: [
            // 2026-09-29 doğallık (K5): kilitli seviye tek işaretle (kilit)
            // söylenir; sönük zorluk çubukları ikinci bir "kapalı" işareti
            // ve her satırda tekrar eden bir sinyal simgesiydi.
            if (!locked) ...[
              _DifficultyBars(
                filled: level.difficultyMax.clamp(1, 5),
                color: t.learnTx,
              ),
              const SizedBox(width: SahneSpace.x2),
            ],
            // Kilitli seviye NEDEN kilitli olduğunu söyler (2026-09-30
            // izgara): yalnız soru sayısı yazıyordu, kilit ikonuna dokunmak
            // dışında açılma koşulu görünmüyordu. Koşul tek satırdır
            // ("Önce 1. seviyeyi tamamla."); soru sayısı açılınca görünür.
            Flexible(
              child: Text(
                locked
                    ? context.t(K.oncePSeviyeyiTamamla, {
                        'p0': '${level.number - 1}.',
                      })
                    : '${level.questionCount} ${context.t(K.soru)}',
                key: locked
                    ? ValueKey('level-lock-hint-${level.number}')
                    : null,
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ),
          ],
        ),
      ],
    );
    // Büyük yazı ölçeğinde (≥ 1.5) rozet metnin üstüne çıkar: ad dar bir
    // sütunda harf harf bölünmesin ("Destpê / k").
    final large = MediaQuery.textScalerOf(context).scale(16) >= 24;
    return Row(
      children: [
        if (large)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badgeTile,
                const SizedBox(height: SahneSpace.x2),
                texts,
              ],
            ),
          )
        else ...[
          badgeTile,
          const SizedBox(width: SahneSpace.x3),
          Expanded(child: texts),
        ],
        if (trailing != null) ...[
          const SizedBox(width: SahneSpace.x2),
          Icon(trailing, size: 20, color: t.tx3),
        ],
      ],
    );
  }
}

/// Zorluğu yükselen 5 çubukla gösterir.
///
/// Zorluk eskiden yıldızla gösteriliyordu. Yıldız, quiz uygulamalarında
/// neredeyse her yerde *kazanılmış başarıyı* anlatır; hiç oynamamış oyuncu
/// seviye kartında "2/5 dolu yıldız" görünce bunu kendi skoru sanıyordu
/// (2026-07-25 canlı denetimi). Şahnê'de de yıldız glifi ödüldür (oynanmış
/// seviyenin rozeti); zorluk yıldız olmaz. Tooltip + Semantics "zorluk"
/// anlamını taşır (2026-07-23 M16).
class _DifficultyBars extends StatelessWidget {
  const _DifficultyBars({required this.filled, required this.color});

  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final isKu = context.isKu;
    final label = Tr.forKu(K.zorlukUzerindenPYildiz, isKu, {'p0': '$filled'});
    return Tooltip(
      message: Tr.forKu(K.zorluk, isKu),
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 2),
                  child: SizedBox(
                    width: 3,
                    height: 4.0 + i * 2,
                    child: ColoredBox(color: i <= filled ? color : t.s3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
