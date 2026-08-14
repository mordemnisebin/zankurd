import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/contest.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/arena_kit.dart';
import '../widgets/screen_identity_header.dart';
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

class _ContestScreenState extends State<ContestScreen> {
  late Future<Contest?> _contestFuture;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadContest();
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      // AppBar başlıksız: ekranın adını `ScreenIdentityHeader` taşıyor.
      // Burada başlık da verilince "Günün Etkinliği" ilk 300 pikselde iki
      // kez yazıyordu (2026-07-30 ekran turu, 11/24/31/34). Kimlik başlığı
      // kullanan on ekranın sekizi AppBar başlığını zaten boş bırakıyor;
      // aykırı olan buydu. (`review_screen` iki *farklı* başlık gösterir —
      // "Cevaplar" ve "Özet" — orada tekrar yok.)
      appBar: AppBar(),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: FutureBuilder<Contest?>(
            future: _contestFuture,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGradientStart,
                  ),
                );
              }
              if (snapshot.hasError) {
                return AppErrorState(
                  title: context.t(K.loadFailedShort),
                  message: context.t(K.contestLoadFailed),
                  retryLabel: context.t(K.retryTiny),
                  onRetry: () => setState(_loadContest),
                );
              }
              final contest = snapshot.data;
              if (contest == null) {
                // Dürüst boş durum: isim eşleşmesi (Çalakiya Rojê) + net
                // "yakında" mesajı + geri yolu. Kullanıcı ölü ekranda
                // kalmaz (2026-07-19 canlı denetim P1 bulgusu).
                return AppEmptyState(
                  icon: AppIcons.champagneGlasses,
                  title: context.t(K.dailyContest),
                  message: context.t(K.contestNoneToday),
                  actionLabel: context.t(K.goHome),
                  actionIcon: AppIcons.house,
                  onAction: () => Navigator.of(context).pop(),
                );
              }
              return _ContestContent(
                contest: contest,
                starting: _starting,
                onStart: () => _startQuiz(contest),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContestContent extends StatelessWidget {
  const _ContestContent({
    required this.contest,
    required this.starting,
    required this.onStart,
  });

  final Contest contest;
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
    final hero = ArenaHero(
      title: context.t(K.dailyEventCardTitle),
      subtitle: context.t(K.dailyEventCardBody),
      // Turkuaz: turnuvanın altınından ayrı bir aile üyesi. Yarışma
      // bugüne ait, doğrudan ve hızlı; kupanın tören rengini taşımamalı.
      accent: _contestTone,
      icon: AppIcons.champagneGlasses,
      tokens: [
        ArenaStatusChip(
          status: ArenaStatus.live,
          label: context.t(K.contestToday),
          onSolid: true,
        ),
      ],
      action: GeometricGradientButton(
        label: starting ? (context.t(K.preparing)) : (context.t(K.startEvent)),
        icon: AppIcons.play,
        isLoading: starting,
        onPressed: starting ? null : onStart,
      ),
    );

    final quickInfo = _ContestPanel(
      title: context.t(K.contestQuickInfo),
      icon: AppIcons.bolt,
      child: _ContestQuickStrip(contest: contest, ku: ku),
    );

    // Kimlik başlığı KALIR. Turnuvada kaldırılmıştı çünkü hero aynı
    // başlığı taşıyordu; burada hero "Günün 10 Sorusu" der, kimlik bandı
    // ekranın adını ("Günün Etkinliği") — ikisi farklı, tekrar yok.
    // Ekranın adı oyun merkezindeki girişle eşleşmeli, yoksa kullanıcı
    // hangi ekrana geldiğini doğrulayamaz.
    final header = ScreenIdentityHeader(
      title: context.t(K.dailyEvent),
      subtitle: context.t(K.dailyEventSub),
      accent: _contestTone,
      icon: AppIcons.champagneGlasses,
      compact: true,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Geniş ekranda gerçek iki sütun: solda bugünün etkinliği ve
        // başlama eylemi, sağda kısa bilgi.
        if (constraints.maxWidth >= 720) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: hero),
                    const SizedBox(width: AppSpacing.cardGap),
                    Expanded(
                      flex: 5,
                      child: Column(
                        key: const ValueKey('contest-wide-column'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [quickInfo],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.lg,
          ),
          children: [
            header,
            const SizedBox(height: AppSpacing.md),
            hero,
            const SizedBox(height: AppSpacing.cardGap),
            quickInfo,
          ],
        );
      },
    );
  }
}

/// Yarışmanın ton rengi — turkuaz (#04697C).
///
/// Turnuva altın taşır (tören, uzun soluklu kupa). Yarışma bugüne ait,
/// doğrudan ve hızlı bir etkinlik; aynı rengi taşısaydı turnuvanın rengi
/// değiştirilmiş bir kopyası gibi okunurdu. Altın bu ekranda yalnız ödül
/// jetonlarında kalır — yani ekonomiyi anlatan yerde.
const Color _contestTone = Color(0xFF04697C);

/// Etkinliği tek bakışta anlatan kısa bilgi şeridi.
///
/// Yalnız GERÇEKLEŞEN değerler: kaç soru sorulacağı, soru başına kaç
/// saniye verileceği ve soruların karışık havuzdan geldiği. Temanın
/// zorluk aralığı ve kategorisi BİLEREK yok — sorular o temadan
/// seçilmiyor (bkz. `_ContestContent` notu).
class _ContestQuickStrip extends StatelessWidget {
  const _ContestQuickStrip({required this.contest, required this.ku});

  final Contest contest;
  final bool ku;

  @override
  Widget build(BuildContext context) {
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i == items.length - 1 ? 0 : AppSpacing.sm,
              ),
              child: _ContestStat(icon: items[i].$1, text: items[i].$2),
            ),
        ],
      ),
    );
  }
}

/// Sayı + etiketten oluşan küçük bilgi bloğu.
class _ContestStat extends StatelessWidget {
  const _ContestStat({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.textSubColor(context)),
          const SizedBox(width: 7),
          Text(
            text,
            maxLines: 1,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Başlıklı sakin panel — arena ailesinin nötr yüzeyi.
class _ContestPanel extends StatelessWidget {
  const _ContestPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppTheme.textSubColor(context)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textSubColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// Eski gövde — kaldırıldı.
