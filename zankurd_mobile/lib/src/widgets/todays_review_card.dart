import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../data/mistake_store.dart';
import '../data/zankurd_repository.dart';
import '../models/quiz_question.dart';
import '../screens/quiz_screen.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Bir tekrar oturumunun en çok soru sayısı.
const int kReviewSessionCap = 12;

/// "Bugünkü Tekrarlar" kartı — SM-2 aralıklı tekrar sisteminin ürün yüzü.
///
/// Yalnızca [MistakeStore.readyIds] içindeki (tekrar zamanı gelmiş) soruları
/// sayar. Hazır tekrar varsa dokunulabilir bir kart, yoksa sakin bir
/// "tamamlandı" durumu gösterir. Karta dokununca yalnız hazır sorularla,
/// öğrenme deneyiminde (sayaç/skor/joker yok) bir tekrar quizi açılır.
/// Tekrar oturumunun başlık kategorisi: sorular tek konudansa o konu,
/// değilse Karışık (`mixed`). createRoom() varsayılanı ("Ziman") başlıkta
/// yanlış konu gösteriyordu.
String reviewRoomCategory(List<QuizQuestion> questions) {
  final categories = {for (final q in questions) q.category};
  return categories.length == 1 ? categories.single : 'mixed';
}

class TodaysReviewCard extends StatefulWidget {
  const TodaysReviewCard({
    required this.repository,
    required this.isKu,
    this.onStartReview,
    this.refreshSignal,
    this.hideWhenEmpty = false,
    super.key,
  });

  final ZanKurdRepository repository;
  final bool isKu;

  /// Hazır tekrar yokken hiçbir şey çizme.
  ///
  /// Öğrenme ekranı hiç ders çözmemiş birine "Tekrarlar tamam" diyordu —
  /// yapılmamış bir işin bittiğini söyleyen bir satır. Orada kart yalnız
  /// gerçekten tekrar bekliyorsa görünür.
  final bool hideWhenEmpty;

  /// Test/özelleştirme için: verilirse quiz açmak yerine bu çağrılır.
  final void Function(List<QuizQuestion> questions)? onStartReview;

  /// Sekme yeniden seçildiğinde hazır sayısını tazelemek için.
  final Listenable? refreshSignal;

  @override
  State<TodaysReviewCard> createState() => _TodaysReviewCardState();
}

class _TodaysReviewCardState extends State<TodaysReviewCard> {
  int _readyCount = 0;
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    widget.refreshSignal?.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant TodaysReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSignal != widget.refreshSignal) {
      oldWidget.refreshSignal?.removeListener(_refresh);
      widget.refreshSignal?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_refresh);
    super.dispose();
  }

  /// Gerçekten AÇILABİLECEK tekrar soruları.
  ///
  /// Sayı ile eylem eskiden iki ayrı kaynaktan besleniyordu: rozet
  /// `store.readyCount` (bütün hazır kimlikler), başlatma ise
  /// `repository.questions` ile kesişim. Çevrimiçi maçlarda yanlış
  /// yapılan sorular veritabanı UUID'siyle kaydediliyor
  /// (`get_room_questions` satırın `id`sini döndürür); paketli bankanın
  /// kimlikleri ise `offline_0005` biçiminde. `_trackMistake` çevrimiçi
  /// yolda da çalıştığı için bu UUID'ler yanlış defterine giriyor ama
  /// hiçbir zaman çözümlenemiyordu.
  ///
  /// Sonuç: kart sıfırdan büyük bir rozet gösteriyor, dokunuş ise
  /// `questions.isEmpty` dalına düşüp SESSİZCE hiçbir şey yapmıyordu —
  /// Öğren sekmesinin başlık kartı, çevrimiçi 1v1 oynayan her kullanıcıda
  /// kalıcı olarak tepkisiz kalıyordu (2026-08-06 denetimi).
  ///
  /// Artık ikisi de aynı listeden besleniyor: sayı neyi vaat ediyorsa
  /// dokunuş onu açar.
  ///
  /// ## Kusur (2026-10-15)
  ///
  /// Kaynak `repository.questions` idi; ana ekran ise `playableQuestions`
  /// ile sayıyordu. Karantinadaki bir soru kartta sayılmasa da oturuma
  /// girebiliyordu; ayrıca hazır ne kadar soru varsa hepsi tek oturumda
  /// açılıyordu (birikmiş yüzlerce tekrar bir "bugünkü" oturum olmuyordu).
  ///
  /// Kural: yalnız `playableQuestions`, en çok gecikenden başlayıp
  /// [kReviewSessionCap] soru.
  List<QuizQuestion> _launchable(List<String> readyIdsByOverdue) {
    final byId = {for (final q in widget.repository.playableQuestions) q.id: q};
    return [
      for (final id in readyIdsByOverdue)
        if (byId[id] != null) byId[id]!,
    ].take(kReviewSessionCap).toList();
  }

  Future<void> _refresh() async {
    try {
      final store = await MistakeStore.load();
      final launchable = _launchable(store.readyIdsMostOverdueFirst).length;
      if (mounted) {
        setState(() {
          _readyCount = launchable;
          _loading = false;
        });
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'todays_review_card');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startReview() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final store = await MistakeStore.load();
      if (!mounted) return;
      final questions = _launchable(store.readyIdsMostOverdueFirst);
      if (questions.isEmpty) {
        await _refresh();
        return;
      }

      final onStart = widget.onStartReview;
      if (onStart != null) {
        onStart(questions);
        return;
      }

      final ku = widget.isKu;
      // createRoom() varsayılan kategoriyi ("Ziman") taşıyordu; tekrar
      // sorusu Siyaset'tenken başlıkta "Ziman · 1 pirs" yazıyordu
      // (simülatör gezisi 2026-10-21). Tek konuysa o, değilse Karışık.
      final room = widget.repository.createRoom().copyWith(
        name: Tr.forKu(K.todaysReviews, ku),
        questionCount: questions.length,
        category: reviewRoomCategory(questions),
      );
      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            practice: true,
            enableTimer: false,
            experience: QuizExperience.learning,
          ),
        ),
      );
      if (mounted) await _refresh();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'todays_review_start');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Tr.forKu(K.quizLoadFail, widget.isKu))),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_readyCount == 0 && widget.hideWhenEmpty) {
      return const SizedBox.shrink();
    }
    final ku = widget.isKu;
    return _readyCount > 0
        ? _buildReady(context, ku)
        : _buildEmpty(context, ku);
  }

  // 2026-09-29 Şahnê: öğrenme rolünün satırı — 36'lık M karo (Zimrût tonu
  // + Zimrût metni ikon), üst satır kalın açıklama Zimrût metni, alt satır
  // Gövde 700; chevron üçüncül.
  //
  // 2026-09-29 doğallık (K7): sağda sayıyı ikinci kez yazan Zimrût rozeti
  // vardı ("3 soru tekrara hazır" + "3"). Sayı yalnız cümlede kalır.
  Widget _tile(SahneTokens t, IconData icon) => DecoratedBox(
    decoration: ShapeDecoration(color: t.learnTint, shape: SahneShape.m),
    child: SizedBox.square(
      dimension: 36,
      child: Icon(icon, color: t.learnTx, size: 20),
    ),
  );

  Widget _buildReady(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    final semanticLabel = [
      Tr.forKu(K.todaysReviews, ku),
      Tr.forKu(K.todaysReviewsCount, ku, {'count': '$_readyCount'}),
      Tr.forKu(K.strengthenMemory, ku),
    ].join('. ');
    return Semantics(
      key: const ValueKey('todays-review-card'),
      container: true,
      button: true,
      enabled: !_starting,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: _starting ? null : _startReview,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: _starting ? null : _startReview,
          excludeFromSemantics: true,
          customBorder: SahneShape.m,
          child: Padding(
            key: const ValueKey('todays-review-status-row'),
            padding: const EdgeInsets.symmetric(vertical: SahneSpace.x2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  _tile(t, AppIcons.arrowsRotate),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Tr.forKu(K.todaysReviews, ku),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.captionStrong.copyWith(
                            color: t.learnTx,
                          ),
                        ),
                        Text(
                          Tr.forKu(K.todaysReviewsCount, ku, {
                            'count': '$_readyCount',
                          }),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.bodyStrong.copyWith(color: t.tx),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Icon(AppIcons.chevronRight, size: 20, color: t.tx3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool ku) {
    final t = SahneTokens.of(context);
    final title = Tr.forKu(K.reviewsDone, ku);
    final detail = Tr.forKu(K.noReviewsToday, ku);
    return Semantics(
      key: const ValueKey('todays-review-empty'),
      label: '$title. $detail',
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey('todays-review-status-row'),
        padding: const EdgeInsets.symmetric(vertical: SahneSpace.x2),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              _tile(t, AppIcons.circleCheck),
              const SizedBox(width: SahneSpace.x3),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
