import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../data/level_progress_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/quiz_level.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state.dart';
import '../widgets/kilim_progress_bar.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'quiz_screen.dart';
import '../config/category_visuals.dart';
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
    final gradient = CategoryVisuals.gradient(widget.category);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        // 2026-07-22 canlı UX denetimi: geri butonu görünürlük düzeltmesi
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: BackButton(
              color: Colors.white,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ),
      ),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          top: false,
          child: ListView(
            // Üstte status bar payı bırakılmaz; hero en üste kadar uzanır.
            padding: EdgeInsets.zero,
            children: [
              _CategoryHero(
                category: widget.category,
                subCategory: widget.subCategory,
                gradient: gradient,
                isKu: ku,
                completedLevels: _playedLevels.length,
                totalLevels: levels.length,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: switch (_loadState) {
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
              ),
            ],
          ),
        ),
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
                '${level.number}. ${context.isKu ? "Ast" : "Seviye"}',
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

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({
    required this.completedLevels,
    required this.totalLevels,
    required this.category,
    this.subCategory,
    required this.gradient,
    required this.isKu,
  });

  final String category;
  final String? subCategory;
  final LinearGradient gradient;
  final bool isKu;

  /// Bu alt kategoride tamamlanan / toplam seviye sayısı.
  final int completedLevels;
  final int totalLevels;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final color1 = Colors.white.withValues(alpha: 0.08);
    final color2 = Colors.white.withValues(alpha: 0.03);

    String title = CategoryNames.localized(category, isKu);
    String subtitle = Tr.forKu(K.kolaydanZoraDogruIlerle, isKu);

    if (subCategory != null) {
      // Ham `[]` erişimi DEĞİL: kategori adı takma ad olarak gelirse harita
      // null döner ve alt kategori başlığı sessizce kaybolurdu.
      final list = SubcategoryConfig.forCategory(category);
      final sub = list.firstWhere(
        (element) => element.id == subCategory,
        orElse: () => const SubcategoryInfo(
          id: '',
          nameKu: '',
          nameTr: '',
          descriptionKu: '',
          descriptionTr: '',
        ),
      );
      if (sub.id.isNotEmpty) {
        title = isKu
            ? '${CategoryNames.localized(category, isKu)} · ${sub.nameKu}'
            : '${CategoryNames.localized(category, isKu)} · ${sub.nameTr}';
        subtitle = isKu ? sub.descriptionKu : sub.descriptionTr;
      }
    }

    return Hero(
      tag: 'category_hero_${category}_$subCategory',
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          // 200pt'lik hero'nun üst ~%60'ı tamamen boştu: içerik `Spacer`
          // ile en alta itiliyordu ve telefonun üçte biri hiçbir şey
          // söylemiyordu (2026-07-25 canlı denetimi). Yükseklik başlığın
          // gerçekten ihtiyaç duyduğu ölçüye çekildi; kalan yer ilerleme
          // bilgisiyle dolduruldu.
          height: 168 + topInset,
          decoration: BoxDecoration(
            gradient: gradient,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Kategori görseli — en alt katman.
              //
              // `assets/question_images/cat_*.webp` sekiz görsel pakete
              // giriyor ama `CategoryVisuals.imagePath()` hiçbir yerden
              // çağrılmıyordu: ~600K ölü yük (2026-07-25 görsel denetimi).
              //
              // Görseller kategori *listesine* konmadı: 2026-07-24 kararı
              // poster kartları bilinçli olarak kaldırmıştı, çünkü sekiz
              // görsel yan yana gözü yoruyor. Burada aynı sorun yok —
              // ekranda tek kategori var. Görsel, gradyanın altında düşük
              // opaklıkta bir doku olarak durur; başlığın beyaz metni
              // üstteki gradyan perdesiyle okunur kalır.
              Opacity(
                opacity: 0.28,
                child: Image.asset(
                  CategoryVisuals.imagePath(category),
                  fit: BoxFit.cover,
                  // Görsel bulunamazsa hero yine çizilir; gradyan tek
                  // başına yeterli bir zemindir.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
              // Görselin üstüne gradyan perdesi: metin kontrastı görselin
              // parlaklığından bağımsız kalsın.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gradient.colors.first.withValues(alpha: 0.55),
                      gradient.colors.last.withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
              // Soft Glow 1
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [color1, color1.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              // Soft Glow 2
              Positioned(
                left: -50,
                bottom: -50,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [color2, color2.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              // Dekoratif daire
              Positioned(
                right: 20,
                bottom: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      title,
                      style: AppTypography.heading1.copyWith(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    if (totalLevels > 0) ...[
                      const SizedBox(height: 10),
                      _HeroProgress(
                        completed: completedLevels,
                        total: totalLevels,
                        isKu: isKu,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero içindeki ince ilerleme şeridi: "2/5 seviye tamam".
///
/// Başlık şeridinin boş kalan alanı süs yerine gerçek bir durum bilgisiyle
/// doldurulur; kullanıcı bu alt kategoride nerede olduğunu haritaya
/// bakmadan görür.
class _HeroProgress extends StatelessWidget {
  const _HeroProgress({
    required this.completed,
    required this.total,
    required this.isKu,
  });

  final int completed;
  final int total;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Semantics(
      label: isKu
          ? '$completed ji $total astan temam bûn'
          : '$total seviyeden $completed tanesi tamamlandı',
      child: ExcludeSemantics(
        child: Row(
          children: [
            // Kilim çubuğu yalnız 15'ten fazla soruluk quizlerde çiziliyordu
            // ve hiçbir seviyede o kadar soru yok — uygulamanın kültürel
            // görsel imzası pratikte hiç görünmüyordu (2026-07-25 görsel
            // denetimi). Burası kullanıcının ilerlemeye gerçekten baktığı
            // yer; motif buraya taşındı.
            Expanded(
              child: KilimProgressBar(
                value: ratio,
                height: 8,
                color: Colors.white,
                // Yeşil hero üzerinde iz, tema yüzeyiyle (açık) çizilirse
                // dolgudan ayırt edilemez ve %0 ilerleme "dolu" görünür.
                trackColor: Colors.white.withValues(alpha: 0.22),
                borderColor: Colors.white.withValues(alpha: 0.30),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              Tr.forKu(K.pPSeviye, isKu, {'p0': '$completed', 'p1': '$total'}),
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kademe rengi: her seviyenin yol üzerindeki kimliği.
/// Seviye numarasından zorluk merdiveninin rengi: kolaydan zora doğru
/// yeşil → camgöbeği → altın → turuncu → mor. Kesikli patika da aynı
/// diziyi kullanır, böylece renk bir ilerleme ölçeği olarak okunur.
///
/// 2. kademe lacivert (0xFF2B5C8F) idi: marka paletinde yer almayan bu
/// ton, yeşille altın arasında merdivenin dışından gelmiş gibi duruyor ve
/// dizinin ölçek olduğunu gizliyordu (2026-07-25 canlı denetimi).
Color _levelColor(int n) => switch (n) {
  1 => AppTheme.correct,
  2 => AppTheme.playCyan,
  3 => AppTheme.gold,
  4 => AppTheme.primaryGradientStart,
  _ => AppTheme.violet,
};

/// Seviyeleri düz liste yerine serpantin bir öğrenme yolunda gösterir:
/// düğümler sağa-sola salınır, aralarını kademe-renkli kesikli patika bağlar.
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

  /// Bir seviye açık mı? İlk basamak daima açıktır; sonrakiler ancak bir
  /// önceki oynandıysa açılır.
  ///
  /// Kilit yokken 5. seviye ("Mamoste", zorluk 4-5) ilk günden erişilebilir
  /// oluyordu: yol bir merdiven gibi çizilmiş ama merdiven işlevi görmüyor,
  /// yeni kullanıcı doğrudan en zora girip başarısız oluyordu (2026-07-25
  /// canlı denetimi). Kilit, haritanın vaat ettiği ilerlemeyi gerçek kılar.
  bool _isUnlocked(int number) {
    if (number <= 1) return true;
    return playedLevels.contains(number - 1);
  }

  /// Yoldaki "sıradaki" düğüm: oynanmamış ilk seviye.
  int? get _nextNumber {
    for (final level in levels) {
      if (!playedLevels.contains(level.number)) return level.number;
    }
    return null;
  }

  static const _rowHeight = 150.0;
  static const _nodeSize = 76.0;
  static const _xFractions = [0.26, 0.74, 0.30, 0.70, 0.34];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = [
          for (var i = 0; i < levels.length; i++)
            Offset(
              width * _xFractions[i % _xFractions.length],
              i * _rowHeight + _nodeSize / 2,
            ),
        ];
        return SizedBox(
          height: levels.length * _rowHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _PathPainter(
                      centers: centers,
                      colors: [
                        for (final level in levels) _levelColor(level.number),
                      ],
                    ),
                  ),
                ),
              ),
              for (var i = 0; i < levels.length; i++)
                Positioned(
                  left: (centers[i].dx - 90).clamp(0.0, width - 180),
                  top: i * _rowHeight,
                  width: 180,
                  child: _LevelNode(
                    level: levels[i],
                    disabled: disabled,
                    isKu: isKu,
                    played: playedLevels.contains(levels[i].number),
                    isNext: levels[i].number == _nextNumber,
                    locked: !_isUnlocked(levels[i].number),
                    onTap: () => onOpen(levels[i]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Yol üzerindeki tek seviye düğümü: gradyan daire + başlık/yıldız etiketi.
class _LevelNode extends StatefulWidget {
  const _LevelNode({
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

  /// Bu seviye daha önce oynandı (altın halka + tik rozeti).
  final bool played;

  /// Yolda sıradaki seviye (güçlü parıltı — "buradan devam et").
  final bool isNext;

  /// Bir önceki seviye henüz oynanmadı: düğüm soluk çizilir ve dokunma
  /// quiz açmak yerine neden kilitli olduğunu anlatır.
  final bool locked;
  final VoidCallback onTap;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode> {
  bool _pressed = false;

  /// Kilitli düğüme dokunulduğunda nedenini söyler. Sessizce hiçbir şey
  /// yapmayan bir düğüm, kullanıcıya "bozuk" hissi verir.
  void _explainLock(BuildContext context) {
    final previous = widget.level.number - 1;
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
    final color = _levelColor(widget.level.number);
    final isFinal = widget.level.number >= 5;

    final blocked = widget.disabled || widget.locked;
    final name = LevelNames.localized(widget.level.title, context.isKu);

    return Semantics(
      button: true,
      enabled: !blocked,
      label: widget.locked
          ? (context.t(K.pKilitliOncekiSeviyeyi, {'p0': name}))
          : name,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Saydamlığın altına opak bir daire konur.
          //
          // Kilitli düğüm %45 saydam çiziliyordu ve altındaki kesikli yol
          // dairenin içinden geçip kilit ikonunun ortasından görünüyordu —
          // düğüm çizgiyle çizilmiş gibi duruyordu (2026-07-27). Saydamlık
          // kararı doğru (kilitli olan sönük okunmalı); eksik olan, sönmeyi
          // sayfa zemininin üstünde yapmaktı.
          if (widget.locked)
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.bgOf(context),
              ),
            ),
          GestureDetector(
            onTapDown: blocked ? null : (_) => setState(() => _pressed = true),
            onTapUp: blocked
                ? null
                : (_) {
                    setState(() => _pressed = false);
                    widget.onTap();
                  },
            onTapCancel: blocked
                ? null
                : () => setState(() => _pressed = false),
            // Kilitli düğüme dokunmak sessiz kalmaz: nedenini söyler.
            onTap: widget.locked ? () => _explainLock(context) : null,
            child: AnimatedScale(
              scale: _pressed ? 0.93 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    // Saydamlık YALNIZ düğüm dairesine uygulanır.
                    //
                    // Önce bütün alt ağacı sarıyordu ve altındaki
                    // etiket kartı da %45 saydam çiziliyordu: koyu
                    // temada "Temel · 10 soru" okunabilirlik eşiğinin
                    // altında kalıyordu (2026-07-30 ekran turu, 38/53).
                    // Kilitli olduğu zaten dairenin sönük rengi ve
                    // asma kilit ikonundan belli; oyuncunun hangi
                    // seviyede kaç soru olduğunu okuyamaması ise
                    // planlamasını engelliyordu.
                    opacity: widget.locked ? 0.45 : 1.0,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color,
                                Color.alphaBlend(
                                  Colors.black.withValues(alpha: 0.24),
                                  color,
                                ),
                              ],
                            ),
                            border: Border.all(
                              color: widget.played
                                  ? AppTheme.gold
                                  : Colors.white.withValues(
                                      alpha: widget.isNext ? 0.9 : 0.55,
                                    ),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(
                                  alpha: widget.isNext ? 0.32 : 0.20,
                                ),
                                blurRadius: widget.isNext ? 16 : 10,
                                offset: const Offset(0, 5),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: widget.locked
                              ? const Icon(
                                  AppIcons.lock,
                                  color: Colors.white,
                                  size: 30,
                                )
                              : isFinal
                              ? const Icon(
                                  AppIcons.trophy,
                                  color: Colors.white,
                                  size: 34,
                                )
                              : Text(
                                  '${widget.level.number}',
                                  style: AppTypography.heading1.copyWith(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        if (widget.played)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: AppTheme.goldGradient,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                AppIcons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: color.withValues(alpha: 0.30)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LevelNames.localized(
                            widget.level.title,
                            context.isKu,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _DifficultyStars(
                              filled: widget.level.difficultyMax.clamp(1, 5),
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.level.questionCount} ${widget.isKu ? "pirs" : "soru"}',
                              style: AppTypography.caption.copyWith(
                                color: AppTheme.textMutedColor(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Düğüm merkezlerini kademe-renkli, kesikli S-kavisleriyle bağlar.
class _PathPainter extends CustomPainter {
  _PathPainter({required this.centers, required this.colors});

  final List<Offset> centers;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < centers.length - 1; i++) {
      final a = centers[i];
      final b = centers[i + 1];
      final midY = (a.dy + b.dy) / 2;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          colors[i],
          colors[i + 1],
          0.5,
        )!.withValues(alpha: 0.55);
      _drawDashed(canvas, path, paint);
    }
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint) {
    const dash = 12.0;
    const gap = 9.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + dash).clamp(0.0, metric.length),
          ),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.centers != centers || oldDelegate.colors != colors;
}

/// Zorluğu metin yerine 5'li yıldız dizisiyle gösterir.
///
/// 2026-07-23 canlı UX denetimi M16: yıldızlar "ilerleme" ile
/// karıştırılabiliyordu (asıl ilerleme rozeti ayrı bir tik işaretiyle
/// gösteriliyor). Tooltip + Semantics ile "zorluk" anlamı netleştirildi.
class _DifficultyStars extends StatelessWidget {
  const _DifficultyStars({required this.filled, required this.color});

  final int filled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final label = Tr.forKu(K.zorlukUzerindenPYildiz, isKu, {'p0': '$filled'});
    return Tooltip(
      message: Tr.forKu(K.zorluk, isKu),
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          // Zorluk yıldızla gösteriliyordu. Yıldız, quiz uygulamalarında
          // neredeyse her yerde *kazanılmış başarıyı* anlatır; hiç
          // oynamamış oyuncu seviye kartında "2/5 dolu yıldız" görünce
          // bunu kendi skoru sanıyordu (2026-07-25 canlı denetimi).
          // Yükselen çubuklar zorluğu tek anlama gelecek biçimde anlatır.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    width: 3,
                    height: 4.0 + i * 2,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1.5),
                      color: i <= filled
                          ? color
                          : AppTheme.textMutedColor(
                              context,
                            ).withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
