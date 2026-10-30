import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/achievement_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/contest.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/arena_kit.dart';
import '../widgets/daily_event_board.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/skeleton_loader.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Günlük etkinlikte soru başına verilen süre.
///
/// Şerit ile `_startQuiz` aynı sayıyı iki ayrı yere yazınca biri
/// değiştiğinde ekran yalan söylerdi.
const int kDailyEventSecondsPerQuestion = 20;

/// Günlük 10 soruluk ilerleme etkinliği: tema ve quiz başlatma.
class ContestScreen extends StatefulWidget {
  const ContestScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> with RouteAware {
  late Future<Contest?> _contestFuture;
  bool _starting = false;

  /// Günün soruları turu bugün bitirildi mi (bkz.
  /// [AchievementStore.dailyQuizDoneOn]).
  ///
  /// 2026-09-30 canlı: tur bitip sayfaya dönülünce kart yine boş "Bugün"
  /// dairesi ve "Başla" gösteriyordu. Not: Öğren'deki "Günün dersi" kartı
  /// AYRI bir kavramdır (bugün doğru cevaplanan soru sayısı, her modda
  /// sayılır); bu bayrak yalnız bu sayfanın turunu anlatır.
  bool _doneToday = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _loadContest();
    _loadDoneToday();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && !identical(route, _route)) {
      if (_route != null) appPageRouteObserver.unsubscribe(this);
      _route = route;
      appPageRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appPageRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// Quiz ekranı sonuç ekranını `pushReplacement` ile açtığı için
  /// `await Navigator.push(QuizScreen)` sonuç yazılmadan tamamlanır
  /// (bkz. `app_shell.dart` `didPopNext`); gerçek dönüş buradadır.
  @override
  void didPopNext() => _loadDoneToday();

  Future<void> _loadDoneToday() async {
    try {
      final store = await AchievementStore.load();
      final done = store.dailyQuizDoneOn(DateTime.now());
      if (!mounted || done == _doneToday) return;
      setState(() => _doneToday = done);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'contest done flag');
    }
  }

  void _loadContest() {
    _contestFuture = widget.repository.loadTodayContest().timeout(
      const Duration(seconds: 8),
    );
  }

  Future<void> _startQuiz(Contest contest) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      // Etkinlik, tema/kategori etiketinden bağımsız günlük havuzdan beslenir;
      // "Günün dersi"nden ayrı tohumla, onun setini dışlayarak seçilir.
      var questions = await widget.repository.loadDailyEventQuestions(
        limit: contest.questionCount,
      );
      if (questions.isEmpty) {
        questions = widget.repository.playableQuestions
            .take(contest.questionCount)
            .toList();
      }
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.noQuestionsFound))));
        return;
      }

      final room = widget.repository
          .createRoom(category: 'Tevlihev')
          .copyWith(
            name: context.t(K.dailyEvent),
            questionCount: questions.length,
            // Günlük etkinlik tempolu bir mod; 20sn (2026-07-21 kullanıcı kararı).
            secondsPerQuestion: kDailyEventSecondsPerQuestion,
          );

      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            dailyQuiz: true,
          ),
        ),
      );
      if (!mounted) return;
      setState(_loadContest);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'contest quiz start failed');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.contestStartFailed))));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2026-09-29 Şahnê: B iskeleti. Ekranın adı ("Günün Etkinliği") ve alt
    // satırı artık çubukta; içerikte kimlik başlığı tekrar edilmez. Eski
    // alt kenardaki üçgen kilim deseni kalktı (desen yalnız sahne kartının
    // üst şeridi). Sayfa adı oyun merkezindeki girişle aynı kalır.
    // 2026-10-28 tur 3 T3: "Başla" ekranın dibine sabit (tek turuncu); hero
    // üstte kalır, orta alan dağ sahnesi + günün önizlemesiyle dolar.
    return FutureBuilder<Contest?>(
      future: _contestFuture,
      builder: (ctx, snapshot) {
        final contest = snapshot.data;
        final loaded =
            snapshot.connectionState != ConnectionState.waiting ||
            snapshot.hasData;
        final Widget content;
        if (!loaded) {
          // Yükleniyor: yüklenmiş içerikle AYNI sarmalayıcıda ve aynı ölçüde
          // iskelet; kart geldiğinde sayfa zıplamaz.
          content = _alignedContent(const _ContestSkeleton());
        } else if (snapshot.hasError) {
          content = SliverFillRemaining(
            child: AppErrorState(
              title: context.t(K.loadFailedShort),
              message: context.t(K.contestLoadFailed),
              retryLabel: context.t(K.retryTiny),
              onRetry: () => setState(_loadContest),
            ),
          );
        } else if (contest == null) {
          // Dürüst boş durum: dağ sahnesi + tek satır dostça mesaj + geri
          // yolu (2026-07-19 canlı denetim P1; tur 3 T3: boş ekran sahnesiz
          // kalmasın). Başlık bugünün etkinliğini anar.
          content = SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SahneSpace.page,
                SahneSpace.x4,
                SahneSpace.page,
                0,
              ),
              child: Column(
                children: [
                  SahneEntryScene(height: _heroSceneHeight(context)),
                  const SizedBox(height: SahneSpace.x4),
                  Expanded(
                    child: AppEmptyState(
                      icon: AppIcons.champagneGlasses,
                      title: context.t(K.dailyEventCardTitle),
                      message: context.t(K.contestNoneToday),
                      actionLabel: context.t(K.goHome),
                      actionIcon: AppIcons.house,
                      onAction: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          content = _alignedContent(
            _ContestContent(
              contest: contest,
              doneToday: _doneToday,
              // Tur bugün bitmişse "Bugünün sıralaması" açılır. Bitmemişse
              // yalnız önizleme (katılımcı sayısı, dünün birincisi, geri
              // sayım); oynamadan başkalarının skorunu görmek turu bozar
              // (bkz. `daily_event_security_ui_test`).
              board: _doneToday
                  ? DailyEventBoardCard(
                      key: const ValueKey('contest-board'),
                      repository: widget.repository,
                    )
                  : DailyEventBoardCard(
                      key: const ValueKey('contest-teaser'),
                      repository: widget.repository,
                      teaser: true,
                    ),
            ),
          );
        }
        return SahnePushedPage(
          role: SahneRole.race,
          title: context.t(K.dailyEvent),
          backLabel: context.t(K.back),
          slivers: [content],
          bottom: loaded && !snapshot.hasError && contest != null
              ? SahneButton.primary(
                  buttonKey: const ValueKey('contest-start'),
                  label: _starting
                      ? context.t(K.preparing)
                      : context.t(_doneToday ? K.playAgain : K.startEvent),
                  icon: AppIcons.play,
                  arrow: false,
                  expand: true,
                  loading: _starting,
                  onPressed: _starting ? null : () => _startQuiz(contest),
                )
              : null,
        );
      },
    );
  }

  /// İçeriği (ya da onun iskeletini) sayfanın üstünden başlatır.
  /// Yükleniyor ve yüklendi aynı yerleşimi paylaşır; yoksa kart gelince
  /// sayfa zıplar.
  Widget _alignedContent(Widget child) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
      // 2026-10-28 görsel kurul: kartı kalan alanın üst beşte birine itmek
      // telefonda başlığın altında ~200pt boşluk bırakıyordu; öteki lobiler
      // (turnuva, düello) içeriği üstten başlatır. Boşluk artık sabit;
      // iskelet ile yüklenen kart yine aynı yerde durur.
      sliver: SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SahneSpace.x4),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// Günün soruları kartı yüklenirken gösterilen iskelet: kahraman kart,
/// "Kısa bilgi" başlığı ve iki çip — gerçek düzenin yerleri ve boyları.
class _ContestSkeleton extends StatelessWidget {
  const _ContestSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('contest-skeleton'),
      label: context.t(K.preparingShort),
      liveRegion: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonLine(
            height: _heroSceneHeight(context) + _kHeroTextHeight,
            borderRadius: 16,
          ),
          const SizedBox(height: SahneSpace.sectionTop),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: SkeletonLine(width: 120, height: 20),
          ),
          const SizedBox(height: SahneSpace.x2),
          const Wrap(
            spacing: SahneSpace.x2,
            runSpacing: SahneSpace.x2,
            children: [
              SkeletonLine(width: 112, height: 44),
              SkeletonLine(width: 112, height: 44),
            ],
          ),
          // "Sıralamaya ilk sonuç girer" açıklaması (dar telefonda üç satır) —
          // yüklenince sayfa zıplamasın.
          const SizedBox(height: SahneSpace.x3),
          const SkeletonLine(height: 20),
          const SizedBox(height: SahneSpace.x1),
          const SkeletonLine(height: 20),
          const SizedBox(height: SahneSpace.x1),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: SkeletonLine(width: 220, height: 20),
          ),
          // Önizleme satırı (geri sayım) ve alt boşluğu.
          const SizedBox(height: SahneSpace.x3),
          const SkeletonLine(width: 220, height: 20),
          const SizedBox(height: SahneSpace.x4),
        ],
      ),
    );
  }
}

/// Kahraman kartın yüklenmiş hâldeki yüksekliği (iskelet bununla aynı yeri
/// tutsun; `contest_skeleton_test` ölçüp kilitler).
const double _kHeroTextHeight = 128;

/// Hero'ya gömülü dağ sahnesinin yüksekliği (U2, 2026-10-28 tur 4): ekranın
/// %36'sı, 208–320 arası. Sabit 208 telefonda içerik ile sabit "Başla"
/// arasında ~200 px ölü boşluk bırakıyordu; sahne boşluğu doldurur, kısa
/// ekranda küçülür.
double _heroSceneHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * 0.36).clamp(208.0, 320.0);

class _ContestContent extends StatelessWidget {
  const _ContestContent({
    required this.contest,
    this.doneToday = false,
    this.board,
  });

  /// Bugünün sıralaması (yalnız tur bugün bitmişse).
  final Widget? board;

  final Contest contest;
  final bool doneToday;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    // İçerik BİLEREK jenerik: bu ekran bir yarışma DEĞİL, günlük ilerleme
    // etkinliği başlatır.
    //
    // `Contest` modeli tema adı, zorluk aralığı ve dört ödül basamağı
    // taşır — ama hiçbiri bu akışta gerçekleşmez: `_startQuiz` sorulari
    // ortak günlük havuzdan (`Tevlihev`) çeker, oda temanın kategorisini
    // almaz ve quiz `contestId: null` ile açılır. Yani hiçbir yarışma
    // kaydı oluşmaz, sıralama hesaplanmaz ve sıralama ödülü ödenmez.
    // Bu değerleri ekrana yazmak, ürünün veremeyeceği bir söz vermek
    // olurdu — `daily_event_security_ui_test.dart` tam da bunu koruyor
    // (doğrulanamayan contest akışı açılmaz).
    //
    // Bu turda görsel sistem değişti, iddia değil: aynı dürüst içerik
    // arena diliyle çizilir.
    //
    // 2026-09-29 Şahnê: kahraman yarış rolünde bir sahne kartıdır (Boyax
    // sahne degradesi + lal kilim şeridi); "Etkinliğe başla" ekranın TEK
    // birincil eylemidir. Eski turkuaz ton palet dışıydı — etkinlik bir
    // yarış biçimidir, rengi Boyax'tır.
    final hero = ArenaHero(
      title: context.t(K.dailyEventCardTitle),
      accent: SahneTokens.of(context).race,
      icon: AppIcons.champagneGlasses,
      sceneHeight: _heroSceneHeight(context),
      tokens: [
        // Bitirilmiş günde rozet "Bugün" değil "Tamamlandı" der ve düğme
        // "Tekrar oyna"dır; tur yine oynanabilir (davranış değişmez).
        ArenaStatusChip(
          status: doneToday ? ArenaStatus.completed : ArenaStatus.live,
          label: context.t(
            doneToday ? K.streakDayStateCompleted : K.contestPlayableToday,
          ),
          onSolid: true,
          // Y5: nötr pil (kırmızı yalnız yanlış geri bildirimi).
          role: SahneRole.neutral,
        ),
      ],
    );

    final quickInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SahneSectionHeader(title: context.t(K.contestQuickInfo)),
        _ContestQuickStrip(contest: contest, ku: ku),
        // Tekrar oynanabilir mi / hangi sonuç sayılır: sunucu yalnız günün
        // İLK kaydını tutar (`submit_daily_event_result`: on conflict do
        // nothing).
        Padding(
          padding: const EdgeInsets.only(top: SahneSpace.x3),
          child: Text(
            Tr.forKu(K.contestFirstCounts, ku),
            key: const ValueKey('contest-first-counts'),
            style: SahneType.caption.copyWith(
              color: SahneTokens.of(context).tx2,
            ),
          ),
        ),
      ],
    );

    final boardSection = board == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: SahneSpace.x4),
            child: board,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Geniş ekranda gerçek iki sütun: solda bugünün etkinliği ve
        // başlama eylemi, sağda kısa bilgi.
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: hero),
              const SizedBox(width: SahneSpace.cardGap),
              Expanded(
                flex: 5,
                child: Column(
                  key: const ValueKey('contest-wide-column'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // Bölüm başlığının 24'lük üst boşluğu kahramanın üst
                  // kenarıyla hizalanmasın diye geri alınır.
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -SahneSpace.sectionTop),
                      child: quickInfo,
                    ),
                    ?boardSection,
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [hero, quickInfo, ?boardSection],
        );
      },
    );
  }
}

/// Etkinliği tek bakışta anlatan kısa bilgi çipleri.
///
/// Yalnız GERÇEKLEŞEN değerler: kaç soru sorulacağı ve soru başına kaç
/// saniye verileceği. Temanın zorluk aralığı ve kategorisi BİLEREK yok —
/// sorular o temadan seçilmiyor (bkz. `_ContestContent` notu).
///
/// 2026-09-29 Şahnê: stat çipi ([SahneStatChip]) — Kulis tonu, M pah,
/// solda 20'lik ikon, kalın açıklama. Çipler sarar; %200 yazıda da taşmaz.
class _ContestQuickStrip extends StatelessWidget {
  const _ContestQuickStrip({required this.contest, required this.ku});

  final Contest contest;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Sayı ve birimi AYNI metin düğümünde durur.
    //
    // Ayrı `Text`lere bölmek görsel olarak daha düzenliydi ama "10 soru"
    // ifadesini parçalıyordu; ekran okuyucu iki bağlamsız parça okuyor ve
    // ekranın ne vaat ettiği metin olarak aranamaz hâle geliyordu.
    final items = <(IconData, String)>[
      (
        AppIcons.question,
        Tr.forKu(K.questionCount, ku, {
          'count': groupThousands(contest.questionCount),
        }),
      ),
      (
        AppIcons.clock,
        '${groupThousands(kDailyEventSecondsPerQuestion)} ${Tr.forKu(K.contestSeconds, ku)}',
      ),
    ];

    return Wrap(
      spacing: SahneSpace.x2,
      runSpacing: SahneSpace.x2,
      children: [
        for (final item in items)
          SahneStatChip(
            leading: Icon(item.$1, size: 20, color: t.raceTx),
            label: item.$2,
          ),
      ],
    );
  }
}
