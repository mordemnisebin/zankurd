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
import '../widgets/sahne/sahne.dart';
import '../widgets/styled_button.dart';
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
      onTimeout: () => null,
    );
  }

  Future<void> _startQuiz(Contest contest) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      // Günlük etkinlik, tema/kategori etiketinden bağımsız olarak ortak
      // günlük havuzdan beslenir. Repository bu havuzu UTC gün seed'i ile
      // seçtiği için aynı gün tüm oyuncular aynı soruları görür.
      var questions = await widget.repository.loadDailyQuestions(
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
    final t = SahneTokens.of(context);
    return SahnePushedPage(
      title: context.t(K.dailyEvent),
      backLabel: context.t(K.back),
      slivers: [
        FutureBuilder<Contest?>(
          future: _contestFuture,
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: t.raceTx),
                ),
              );
            }
            if (snapshot.hasError) {
              return SliverFillRemaining(
                child: AppErrorState(
                  title: context.t(K.loadFailedShort),
                  message: context.t(K.contestLoadFailed),
                  retryLabel: context.t(K.retryTiny),
                  onRetry: () => setState(_loadContest),
                ),
              );
            }
            final contest = snapshot.data;
            if (contest == null) {
              // Dürüst boş durum: net "yakında" mesajı + geri yolu.
              // Kullanıcı ölü ekranda kalmaz (2026-07-19 canlı denetim P1
              // bulgusu). Ekranın adı (Çalakiya Rojê) çubukta durur; boş
              // durumun başlığı onu tekrar etmez, bugünün etkinliğinin
              // kendisini ("Günün 10 Sorusu") anar.
              return SliverFillRemaining(
                child: AppEmptyState(
                  icon: AppIcons.champagneGlasses,
                  title: context.t(K.dailyEventCardTitle),
                  message: context.t(K.contestNoneToday),
                  actionLabel: context.t(K.goHome),
                  actionIcon: AppIcons.house,
                  onAction: () => Navigator.of(context).pop(),
                ),
              );
            }
            // 2026-09-30 canlı: kart ve iki çip ekranın üst yarısında
            // kalıyor, alt yarı bomboştu. İçerik artık kalan alanın
            // üst üçte birinde durur (optik denge); uzun içerik ya da büyük
            // yazıda alan yetmezse sayfa yine kayar.
            //
            // `SliverFillRemaining(hasScrollBody: false)` kullanılamaz:
            // içerik bir `LayoutBuilder` taşıyor (geniş ekran düzeni) ve
            // o iç boyut hesabını desteklemiyor.
            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: SahneSpace.page),
              sliver: SliverLayoutBuilder(
                builder: (context, sliver) => SliverToBoxAdapter(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: sliver.remainingPaintExtent,
                    ),
                    child: Align(
                      alignment: const Alignment(0, -0.6),
                      child: SizedBox(
                        width: double.infinity,
                        child: _ContestContent(
                          contest: contest,
                          doneToday: _doneToday,
                          starting: _starting,
                          onStart: () => _startQuiz(contest),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ContestContent extends StatelessWidget {
  const _ContestContent({
    required this.contest,
    required this.starting,
    required this.onStart,
    this.doneToday = false,
  });

  final Contest contest;
  final bool doneToday;
  final bool starting;
  final VoidCallback onStart;

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
      subtitle: context.t(K.dailyEventCardBody),
      accent: SahneTokens.of(context).race,
      icon: AppIcons.champagneGlasses,
      tokens: [
        // Bitirilmiş günde rozet "Bugün" değil "Tamamlandı" der ve düğme
        // "Tekrar oyna"dır; tur yine oynanabilir (davranış değişmez).
        ArenaStatusChip(
          status: doneToday ? ArenaStatus.completed : ArenaStatus.live,
          label: context.t(
            doneToday ? K.streakDayStateCompleted : K.contestToday,
          ),
          onSolid: true,
          role: SahneRole.race,
        ),
      ],
      action: GeometricGradientButton(
        label: starting
            ? (context.t(K.preparing))
            : (context.t(doneToday ? K.playAgain : K.startEvent)),
        icon: AppIcons.play,
        isLoading: starting,
        onPressed: starting ? null : onStart,
      ),
    );

    final quickInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SahneSectionHeader(title: context.t(K.contestQuickInfo)),
        _ContestQuickStrip(contest: contest, ku: ku),
      ],
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
                  ],
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [hero, quickInfo],
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
        Tr.forKu(K.questionCount, ku, {'count': '${contest.questionCount}'}),
      ),
      (
        AppIcons.clock,
        '$kDailyEventSecondsPerQuestion ${Tr.forKu(K.contestSeconds, ku)}',
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
