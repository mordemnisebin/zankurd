part of '../quiz_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

// ─── Şahnê C iskeleti (2026-09-29) ─────────────────────────────────────────
//
// Soru ekranı artık `SahneStageScaffold` üstünde durur: üst satırda kapat |
// ortada sayaç (süreli) ya da turun adı (süresiz) | skor çipi; altında 10'lu
// elmas dizisi; gövdede üst etiket ("DİL • SORU 3/10") + soru (Başlık 28/32,
// dört satırı aşarsa Manşet 22/28) + şık çubukları; alt perdede cevaptan
// ÖNCE joker dizisi, cevaptan SONRA tek birincil "Sonraki". Eski AppBar,
// başlık kartı, kategori rozeti, hayalet ikon ve Zana yüzü kalktı: kategori
// kimliği sahne zemininde (%14 çizim) ve huzmenin ışığında yaşar.

// ─── 2026-10-19 sadeleşme ───────────────────────────────────────────────────
//
// Test edenler ekranı "çok kalabalık, gözü yoruyor" buldu. Soru ekranı artık
// TEK üst satır taşır: kapat (X) | ortada "Kategori · 1/5" | sağda kalan
// saniye + ⋯ menüsü (Kaydet, Bildir). 60 px'lik elmas sayaç, ışık huzmesi,
// 5'li elmas dizisi ve gövdedeki ayrı künye/araç satırı kalktı; yerine
// satırın hemen altında 4 px'lik ince ilerleme çubuğu geldi. Joker dizisi
// açıklama cümlesini bırakıp kapsül çiplere indi (bkz. `_buildWildcardRow`).

extension _QuizScreenUI on _QuizScreenState {
  /// Dikey akış: kayan gövde (üst etiket, soru, şıklar, bildirimler). Alt
  /// perde (joker/Sonraki) sahnenin kendisinde sabittir; soru ne kadar uzun
  /// olursa olsun ekranda kalır ve kaydırma onu yerinden oynatmaz (2026-07-22
  /// canlı UX denetimi, P0-1).
  Widget _buildPortraitLayout(Size layoutSize) {
    // Yarışma modlarında (solo/1v1/oda) tur içinde açıklama gösterilmez.
    final showExpl = _isLearningExperience && _showExplanation;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = min(
          max(0.0, constraints.maxWidth - SahneSpace.page * 2),
          800.0,
        );
        // Kayan alan 800'lük içerik adasıdır (geniş ekranda ortalanır);
        // şıklar ve alt perdedeki eylem aynı sütunda durur.
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            height: constraints.maxHeight,
            child: SahneStageScroll(
              scrollKey: const ValueKey('quiz-portrait-scroll'),
              resetKey: index,
              padding: const EdgeInsets.only(
                top: SahneSpace.x4,
                bottom: SahneSpace.x6,
              ),
              child: Column(
                key: const ValueKey('quiz-answer-content'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.versusBannerText != null) ...[
                    _VersusBanner(text: widget.versusBannerText!),
                    const SizedBox(height: SahneSpace.x3),
                  ],
                  if (widget.is1v1) ...[
                    _buildDuelHeader(),
                    const SizedBox(height: SahneSpace.x4),
                  ] else if (_isCrowd) ...[
                    _buildCrowdHeader(),
                    const SizedBox(height: SahneSpace.x4),
                  ],
                  _buildQuestionSwitcher(
                    context,
                    layoutSize: layoutSize,
                    bodyHeight: constraints.maxHeight,
                    // TÜM modlarda (ders, yarışma, düello, oda, görselli)
                    // kısa soru için şıklar alta (baş parmak bölgesi) oturur,
                    // soru üstteki boş alanda ortalanır. Bildirim ve tost payı
                    // 160 + üst/alt dolgu düşülür; düello/oda/karşılaşma
                    // üstlüğü ve görsel de kayan gövdede yer tutar, onların
                    // payı ayrıca düşülür: içerik sığıyorsa gereksiz kaydırma
                    // doğmaz. Uzun soru/şık zaten kayar.
                    anchorHeight: _portraitAnchorHeight(
                      constraints.maxHeight,
                      layoutSize,
                    ),
                    showExplanation: showExpl,
                    // Coach-mark anahtarı yalnız ilk soruda: panel
                    // AnimatedSwitcher içinde, geçişte eski ve yeni panel
                    // birlikte yaşar (duplicate-GlobalKey).
                    answerAreaKey: index == 0 ? _answerAreaKey : null,
                    correctAnswerKey: _correctAnswerKey,
                    questionVisualReady: !_questionVisualReady
                        ? _handleQuestionVisualReady
                        : null,
                  ),
                  ..._buildRoundNotices(),
                  if (widget.is1v1 && screenHeight >= 800) ...[
                    const SizedBox(height: SahneSpace.cardGap),
                    _LiveScoreboard(players: livePlayers),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Dikey akışta soru+şık bloğunun en az boyu (şıkları alta oturtur).
  ///
  /// Kusur (kurul, 2026-10-20): yalnız yarışma sorusu şıkları alta
  /// oturtuyordu; ders, seviye belirleme, sırayla düello ve ders yanlış
  /// cevabı şıkları ekranın tepesine yığıp altı bomboş bırakıyordu — aynı
  /// uygulamada iki ayrı soru ekranı gibi. Tek kural artık hepsinde.
  double? _portraitAnchorHeight(double bodyHeight, Size layoutSize) {
    var reserve = SahneSpace.x4 + SahneSpace.x6 + quizAnchorNoticeReserve;
    // Karşılaşma bandı / düello ve oda başlığı gövdenin içinde yer tutar.
    if (widget.versusBannerText != null) reserve += 56;
    if (widget.is1v1 || _isCrowd) reserve += 120;
    if (question.hasImage) {
      final compact = layoutSize.height < 700;
      reserve +=
          questionImagePortraitHeight(
            layoutSize,
            isCompact: compact || bodyHeight < 720,
          ) +
          SahneSpace.x3;
    }
    final height = bodyHeight - reserve;
    return height > 0 ? height : null;
  }

  // ─── Compact landscape layout ──────────────────────────────────────────
  //
  // Yalnız gerçekten kısa ve yatay ekranlar için — seçim kuralı ve gerekçesi
  // `_useCompactLandscapeLayout` başında. Soru solda; ilerleme bilgisi ve
  // eylemler (joker/Sonraki) sağ sütunda, çünkü alt perde yatayda soruya
  // yer bırakmaz.

  Widget _buildCompactLandscapeLayout(Size layoutSize) {
    final showExpl = _isLearningExperience && _showExplanation;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scrollPadding = EdgeInsets.only(
      top: SahneSpace.x2,
      bottom: SahneSpace.x4 + bottomInset,
    );

    // İki sütun AYRI kayar: soru uzunsa ya da yazı büyükse sol sütun
    // kayarken eylemler (joker/Sonraki) sağda yerinde kalır. Tek bir kaydırma
    // alanında şık görünür alana getirilince sağ sütun da yukarı kayıyor ve
    // "Sonraki" ekranın dışına çıkıyordu (844×390 @2.0).
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: SizedBox(
            key: const ValueKey('quiz-landscape-content'),
            width: min(
              max(0.0, constraints.maxWidth - SahneSpace.page * 2),
              800.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SahneStageScroll(
                    resetKey: index,
                    padding: scrollPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.versusBannerText != null) ...[
                          _VersusBanner(text: widget.versusBannerText!),
                          const SizedBox(height: SahneSpace.x3),
                        ],
                        _buildQuestionSwitcher(
                          context,
                          layoutSize: layoutSize,
                          showExplanation: showExpl,
                          answerAreaKey: index == 0 ? _answerAreaKey : null,
                          correctAnswerKey: _correctAnswerKey,
                          questionVisualReady: !_questionVisualReady
                              ? _handleQuestionVisualReady
                              : null,
                        ),
                        ..._buildRoundNotices(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: SahneSpace.x4),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: SingleChildScrollView(
                      padding: scrollPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.is1v1) ...[
                            _buildDuelHeader(),
                            const SizedBox(height: SahneSpace.x3),
                          ] else if (_isCrowd) ...[
                            _buildCrowdHeader(),
                            const SizedBox(height: SahneSpace.x3),
                          ],
                          _buildDock(context),
                          if (widget.is1v1) ...[
                            const SizedBox(height: SahneSpace.x3),
                            _LiveScoreboard(players: livePlayers),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Şıkların altına düşen tur bildirimleri: süre doldu, rakip bekleniyor,
  /// sonraki soruya geri sayım. Hepsi gövdenin akışındadır; kaydırma
  /// emniyet supabı olarak kalır.
  List<Widget> _buildRoundNotices() => [
    if (selectedAnswer == 'TIMEOUT' && !_suspense)
      QuizTimeoutNotice(isKu: _isKu, correctAnswer: question.correctAnswer),
    if (_isMultiplayer && answered && _mpPhase == _MultiplayerPhase.waiting)
      _MultiplayerWaitingOverlay(
        isKu: _isKu,
        crowd: _isCrowd,
        progress: _currentCrowdProgress,
      ),
    if (_isMultiplayer && _mpPhase == _MultiplayerPhase.reveal)
      _RevealCountdown(seconds: _revealCountdown, isKu: _isKu),
  ];

  /// Üst satırın orta yuvası: kategori ikonu + "Kategori · 1/5" künyesi.
  ///
  /// Künye artık gövdede değil üst satırdadır (2026-10-19). Tur adı ("Günün
  /// dersi", oda kodu) buraya yazılmaz: günün dersi karışık kategorilidir ve
  /// künye SORUNUN kategorisini söyler (2026-07-27: kategori adı turun adı
  /// diye yazılınca günün dersinde yalan oluyordu; burada yalan değil, her
  /// soruda o sorunun kategorisi). Künye `AnimatedSwitcher`in DIŞINDA durur.
  ///
  /// Süresiz turda coach-mark hedefi (`_timerTargetKey`) bu yuvadadır
  /// ("burada süre yok" der); süreli turda hedef sayaçtır
  /// ([_buildStageTrailing]).
  Widget _buildStageCenter(BuildContext context) => QuizStageCenter(
    onBand: true,
    keyed: _usesTimer ? null : _timerTargetKey,
    category: question.category,
    index: index,
    total: widget.questions.length,
  );

  /// Üst satırın sağ yuvası: [sohbet] [skor] [kalan saniye] [⋯ menü].
  ///
  /// * Sohbet yalnız çok oyunculuda.
  /// * Skor (Zêr yıldız + puan) yalnız yarışmada ve ilk puandan sonra: tur
  ///   başında "★ 0" bilgi vermez, yalnız baskı kurar. Öğrenmede skor yok
  ///   (rekabet baskısı gösterilmez); düelloda iki skor gövdedeki düello
  ///   kartında yan yana durur.
  /// * Sayaç yalnız süreli turda; coach-mark hedefidir.
  /// * ⋯ menüsü Kaydet ve Bildir'i taşır (eskiden gövdedeki künye satırında
  ///   iki ayrı düğmeydi).
  ///
  /// Grup, dar ekranda ve büyük yazıda taşmaz: sığdırılarak küçülür.
  Widget _buildStageTrailing(BuildContext context) {
    final showScore =
        !(_isLearningExperience || widget.is1v1 || _isCrowd) && score > 0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerEnd,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isMultiplayer)
            SahneIconButton(
              key: const ValueKey('quiz-reaction-menu-button'),
              glass: true,
              icon: AppIcons.faceSmile,
              semanticLabel: context.t(K.chat),
              onPressed: () => _showLiveReactionMenu(context),
            ),
          if (showScore) ...[
            Semantics(
              label: '${groupThousands(score)} ${context.t(K.scoreWord)}',
              excludeSemantics: true,
              child: Row(
                key: const ValueKey('quiz-score-chip'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SahneGlyph(SahneGlyphKind.star, size: 16),
                  const SizedBox(width: SahneSpace.x1),
                  Text(
                    groupThousands(score),
                    style: SahneType.captionStrong.copyWith(
                      color: SahneVivid.onFill,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SahneSpace.x3),
          ],
          if (_usesTimer) ...[
            KeyedSubtree(
              key: _timerTargetKey,
              // Sabit 'quiz-circular-timer' anahtarı widget'ın kendisinde.
              child: QuizTimerWidget(
                key: const ValueKey('quiz-circular-timer'),
                animation: _timerController,
                // Gerçek kaynak room.secondsPerQuestion'dır; sabit 15 lobi
                // çipiyle (örn. 30 sn) çelişiyordu.
                maxSeconds: widget.room.secondsPerQuestion,
                isPaused: answered,
                light: _stageLight,
                onBand: true,
              ),
            ),
            const SizedBox(width: SahneSpace.x1),
          ],
          Builder(
            builder: (buttonContext) => SahneIconButton(
              key: const ValueKey('quiz-more-menu'),
              glass: true,
              icon: AppIcons.ellipsis,
              semanticLabel: context.t(K.moreOptions),
              onPressed: () => _openQuestionMenu(buttonContext),
            ),
          ),
        ],
      ),
    );
  }

  /// ⋯ menüsü: Kaydet (soru kayıtlıysa Kaldır) ve Bildir.
  ///
  /// Menü sahne (gece) temasında açılır: `buttonContext` sahnenin altındadır.
  Future<void> _openQuestionMenu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy + box.size.height,
        box.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
    final t = SahneTokens.of(buttonContext);
    final favoriteLabel = favorite
        ? buttonContext.t(K.removeAction)
        : buttonContext.t(K.save);
    final reportLabel = buttonContext.t(K.reportAction);
    final choice = await showMenu<String>(
      context: buttonContext,
      position: position,
      items: [
        PopupMenuItem<String>(
          key: const ValueKey('quiz-menu-favorite'),
          value: 'favorite',
          height: 48,
          child: Row(
            children: [
              Icon(
                AppIcons.bookmark,
                size: 20,
                color: favorite ? t.goldTx : t.tx,
              ),
              const SizedBox(width: SahneSpace.x3),
              Flexible(child: Text(favoriteLabel)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          key: const ValueKey('quiz-menu-report'),
          value: 'report',
          height: 48,
          child: Row(
            children: [
              Icon(AppIcons.triangleExclamation, size: 20, color: t.tx),
              const SizedBox(width: SahneSpace.x3),
              Flexible(child: Text(reportLabel)),
            ],
          ),
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'favorite':
        _toggleFavorite();
      case 'report':
        _reportQuestion();
    }
  }

  /// Üst satırın altı: 4 px'lik ince ilerleme çubuğu (+ yarışmada seri
  /// rozeti).
  ///
  /// Eskiden 10'lu elmas dizisiydi (doğru dolu + ✓, yanlış boş + ✗). Çubuk
  /// tamamlanan soru oranını gösterir; tek tek doğru/yanlış sonuç ekranında
  /// ve ekran okuyucu özetinde ("3/10 · 2 Doğru · 0 Yanlış") yaşar.
  Widget _buildStageProgress(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [if (!_isLearningExperience) _buildComboRow()],
    );
  }

  /// Konu bandının içindeki ilerleme çubuğu (2026-10-20 renk ve canlılık, B):
  /// bandın rengi konunun rengi olduğundan dolgu beyaz, iz cam; turuncu
  /// eylem rengi kırmızı/turuncu konularda kaybolurdu.
  Widget _buildBandProgress(BuildContext context) {
    final total = widget.questions.length;
    final results = [for (final record in answerRecords) record.isCorrect];
    final right = results.where((r) => r).length;
    final wrong = results.length - right;
    // Cevaplanmış soru tamamlanmış sayılır; sıradaki soru henüz değil.
    final done = (index + (answered ? 1 : 0)).clamp(0, total);
    return SahneProgressBar(
      key: const ValueKey('quiz-progress-bar'),
      value: total == 0 ? 0 : done / total,
      height: 4,
      tone: SahneProgressTone.action,
      fillColor: SahneVivid.onFill,
      trackColor: SahneVivid.glassTrack,
      semanticLabel:
          '${index + 1}/$total · $right ${context.t(K.correct)} · '
          '$wrong ${context.t(K.wrong)}',
    );
  }

  /// Seri rozeti + puan uçuşu satırı. Rozet yokken yükseklik kaplamaz.
  Widget _buildComboRow() {
    return Padding(
      key: _comboKey,
      padding: EdgeInsets.only(
        top: comboTierFor(streak) != null ? SahneSpace.x2 : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ComboBadge(streak: streak, isKu: _isKu),
          ),
          const SizedBox(width: SahneSpace.x2),
          ScoreFlyup(trigger: _flyupTrigger, points: _lastPointsEarned),
        ],
      ),
    );
  }

  /// Düello kartı: iki oyuncu, skorlar, halat çekme çubuğu.
  Widget _buildDuelHeader() {
    final myName = widget.room.id != null ? _myName : Tr.forKu(K.you, _isKu);
    final player = livePlayers.firstWhere(
      _isMe,
      orElse: () => Player(
        id: _myId,
        name: myName,
        score: score,
        state: '',
        streak: streak,
      ),
    );
    final opponent = livePlayers.firstWhere(
      (player) => !_isMe(player),
      orElse: () =>
          Player(name: Tr.forKu(K.opponentWord, _isKu), score: 0, state: ''),
    );
    return _DuelScoreHeader(
      player: player,
      opponent: opponent,
      progress: '${index + 1}/${widget.questions.length}',
    );
  }

  /// Kalabalık oda kartı: kendi puanın, sıran ve ilk üç.
  ///
  /// Sıra canlı hesaplanır (`crowdStandings`): sunucu yalnız sonuç yükünde
  /// verir, oyun sürerken `room_players` skorları her açıklamada güncellenir.
  Widget _buildCrowdHeader() {
    final standings = crowdStandings(livePlayers);
    final player = livePlayers.firstWhere(
      _isMe,
      orElse: () => Player(
        id: _myId,
        name: _myName,
        score: score,
        state: '',
        streak: streak,
      ),
    );
    final mine = standings.where((s) => _isMe(s.player)).firstOrNull;
    return _CrowdScoreHeader(
      player: player,
      rank: mine?.rank,
      total: standings.length,
      top: standings.take(3).toList(growable: false),
      progress: _currentCrowdProgress,
    );
  }

  Widget _buildQuestionSwitcher(
    BuildContext context, {
    Size? layoutSize,
    double? bodyHeight,
    double? anchorHeight,
    bool? showExplanation,
    GlobalKey? answerAreaKey,
    GlobalKey? correctAnswerKey,
    VoidCallback? questionVisualReady,
  }) {
    final reduceMotion = sahneMotionReduced(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      // Opaklık yalnız ikinci yarıda yükselir. AnimatedSwitcher giden
      // çocuğu aynı animasyonu ters yönde oynatarak çizdiğinden, düz
      // `opacity: animation` ile iki soru geçiş boyunca aynı anda yarı
      // saydam kalıyor ve metinler üst üste binip okunmuyordu
      // (2026-07-25 canlı denetimi).
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      // Geçişte panel yukarıdan hizalanır (ortalanırsa kısa soru
      // sıçrar).
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(
        key: ValueKey(index),
        child: _buildQuestionPanel(
          context,
          layoutSize: layoutSize,
          bodyHeight: bodyHeight,
          anchorHeight: anchorHeight,
          showExplanation: showExplanation,
          answerAreaKey: answerAreaKey,
          correctAnswerKey: correctAnswerKey,
          questionVisualReady: questionVisualReady,
        ),
      ),
    );
  }

  /// Alt perde (dikey) ya da sağ sütun (yatay): tur eylemleri.
  ///
  /// * Yarışmada cevaptan ÖNCE joker dizisi; cevaptan SONRA tek birincil
  ///   "Sonraki". Cevap beklenirken pasif bir "Sonraki" göstermek, ekranın
  ///   en büyük öğesini ölü bir blok yapıyordu; jokerler o anda gerçekten
  ///   kullanılabilir olan eylemdir.
  /// * Öğrenmede (joker yok) "Sonraki" hep yerindedir; cevaba kadar pasif.
  /// * Alıştırmada doğru cevaptan sonra "Sonraki"nin yerini zorluk puanı
  ///   alır (üç eşit ikincil düğme).
  ///
  /// Coach-mark "Sonraki" adımının hedefi (`_nextButtonKey`) bu bölgenin
  /// TAMAMIDIR: balon "cevaptan sonra buraya dokun" der; cevaptan önce
  /// orada jokerler durur, cevaptan sonra "Sonraki" aynı yere gelir.
  Widget _buildDock(BuildContext context) {
    final t = SahneTokens.of(context);
    final bool showRatingBar =
        widget.practice &&
        answered &&
        answerRecords.any(
          (record) => record.id == question.id && record.isCorrect,
        ) &&
        !completing;
    final showJokers =
        !_isLearningExperience && !_usesServerHiddenAnswers && !answered;

    // Geniş ekranda eylemler de 800'lük içerik adasında kalır: tam genişlikte
    // bir "Sonraki" şıklardan kopuk ayrı bir şerit gibi okunurdu.
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: KeyedSubtree(
          key: _nextButtonKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Çift Cevap ilk denemesi yanlışsa: açıklama olmadan ikinci cevap
              // beklenir; oyuncuya net ipucu verilir.
              if (!answered && _firstAttemptAnswer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                  child: Semantics(
                    liveRegion: true,
                    label: context.t(K.doubleAnswerHint),
                    excludeSemantics: true,
                    child: Text(
                      context.t(K.doubleAnswerHint),
                      textAlign: TextAlign.center,
                      style: SahneType.captionStrong.copyWith(color: t.goldTx),
                    ),
                  ),
                ),
              if (showJokers)
                _buildWildcardRow()
              else if (showRatingBar)
                _buildRatingBar(context)
              else
                _buildNextButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Tek birincil eylem: "Sonraki" / son soruda "Bitir".
  ///
  /// Çok oyunculuda geçiş otomatik olduğu için düğme pasif kalır ve ne
  /// beklendiğini söyler. Gerilim tutuşu (sonuç bekleniyor) sırasında da
  /// kilitli: hızlı dokunuş skor uygulanmadan soruyu ilerletmesin. Pasif
  /// hâl Şahnê'nin pasifidir (Perde + üçüncül metin), soluk turuncu değil.
  Widget _buildNextButton(BuildContext context) {
    final bool canPressNext = _isMultiplayer
        ? false
        : (answered && !completing && !_suspense);
    final waiting = _isMultiplayer || _suspense;
    return SahneButton.primary(
      key: const ValueKey('quiz-next-button'),
      label: _isMultiplayer && answered && _mpPhase != _MultiplayerPhase.reveal
          ? context.t(K.waitingOpponent)
          : isLastQuestion
          ? context.t(K.finishAction)
          // Yanlıştan sonra açıklama kartı açıkken eylem "Devam": oyuncu
          // önce okur, sonra devam eder (bkz. [_WrongAnswerInsight]).
          : _wrongAnswerInsightVisible
          ? context.t(K.continueAction)
          : context.t(K.next),
      // Beklerken kum saati; son soruda bayrak; yoksa ok (→).
      icon: waiting
          ? AppIcons.hourglassStart
          : isLastQuestion
          ? AppIcons.flag
          : null,
      arrow: !waiting && !isLastQuestion,
      expand: true,
      onPressed: canPressNext ? () => _next() : null,
    );
  }

  /// Alıştırma turunda doğru cevaptan sonra zorluk puanı: üç eşit ikincil
  /// düğme. Hiçbiri "birincil" değil — üçü de eşit seçimdir.
  Widget _buildRatingBar(BuildContext context) {
    final questionIndex = index;
    Widget rate(String key, int value) => Expanded(
      child: SahneButton.secondary(
        label: context.t(key),
        expand: true,
        onPressed: _ratingInFlight
            ? null
            : () => _submitPracticeRating(value, questionIndex),
      ),
    );
    return Row(
      children: [
        rate(K.difficultyHard, 3),
        const SizedBox(width: SahneSpace.x2),
        rate(K.difficultyMedium, 4),
        const SizedBox(width: SahneSpace.x2),
        rate(K.difficultyEasy, 5),
      ],
    );
  }

  // ─── Joker satırı ────────────────────────────────────────────────────────

  Widget _buildWildcardRow() {
    // Eleme jokerleri iki şıklı soruda cevabın kendisini satar; orada hiç
    // GÖSTERİLMEZLER. Pasif bir düğme bırakmak da olurdu ama oyuncuya
    // sebebini anlatmayan ölü bir düğme, olmayan düğmeden kötüdür.
    final jokers = [
      if (_supportsEliminationWildcards) WildcardType.fiftyFifty,
      if (_supportsOptionWildcards) WildcardType.audience,
      if (_supportsDoubleAnswer) WildcardType.doubleAnswer,
      if (_isSoloMode) WildcardType.changeQuestion,
    ];

    // Kurul 4. tur 2026-10-20 (Opus, önceki turlar dahil): hiç jokere
    // jetonu yetmeyen oyuncu her soruda dört kilitli çip görüyordu (ölü
    // ağırlık). Hiçbiri alınamıyorsa satır TEK sönük satıra iner (kilit +
    // jeton + bakiye + "Yetersiz bakiye"; yeni söz yok); dokununca mevcut
    // tost nedenini ve jeton kazanma yolunu söyler. En az biri alınabiliyorsa
    // satır olduğu gibi durur (yetmeyenler zaten sönük).
    final noneAffordable =
        jokers.isNotEmpty &&
        jokers.every(
          (type) => !_wildcard.isUsed(type) && !_canPayWildcard(type),
        );
    if (noneAffordable) {
      return KeyedSubtree(
        key: const ValueKey('quiz-wildcard-row'),
        child: KeyedSubtree(
          key: _wildcardKey,
          child: _CollapsedWildcardLine(
            balance: _coinBalance,
            onTap: _explainLockedWildcard,
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('quiz-wildcard-row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CoinBalanceLine(
          balance: _coinBalance,
          // Hiç jetonu olmayan yeni oyuncuya kilitler "her şey paralı"
          // gibi görünmesin: jetonun nereden kazanılacağını söyle (ekranda
          // yazılmaz; ekran okuyucuya gider ve kilitli jokere dokununca tost
          // olur).
          showHint: _freeWildcardAvailable,
          hint: _freeWildcardAvailable
              ? context.t(K.freeWildcardToday)
              : (_coinBalance == 0 && index == 0
                    ? context.t(K.finishQuizHint)
                    : null),
        ),
        const SizedBox(height: SahneSpace.x2),
        // Adlar ekranda yazmadığı için (ikon + fiyat) dört joker her
        // genişlikte ve %200 yazıda da tek satırda kalır; içerik gerekirse
        // sığdırılarak küçülür.
        KeyedSubtree(
          key: _wildcardKey,
          child: SahneJokerBar(
            jokers: [for (final type in jokers) _buildWildcardButton(type)],
          ),
        ),
      ],
    );
  }

  Widget _buildWildcardButton(WildcardType type) {
    final used = _wildcard.isUsed(type);
    // doubleAnswer "kullanıldı" = aktive edildi: görsel olarak vurgulanır
    final isActive = type == WildcardType.doubleAnswer && used;
    final canAfford = _canPayWildcard(type);
    final isEnabled = !used && canAfford && !answered;

    return WildcardButton(
      type: type,
      isKu: _isKu,
      isEnabled: isEnabled,
      isUsed: used,
      isAnswered: answered,
      isActive: isActive,
      cantAfford: !used && !canAfford && !answered,
      onTap: () => _onWildcardTap(type),
      onLockedTap: _explainLockedWildcard,
    );
  }

  /// Jetonu yetmeyen (kilitli) jokere dokunma: neden alınamadığını söyler.
  /// Joker soluk ve kilitli görünür ama dokunulabilir kalır; ölü bir düğme
  /// sebebini anlatmaz (2026-10-19 sadeleşme: bu cümle eskiden her soruda
  /// jeton satırında yazılıydı).
  void _explainLockedWildcard() {
    _showStageToast(
      '${context.t(K.wildcardNoCoins)} · '
      '${context.t(K.finishQuizHint)}',
      key: const ValueKey('quiz-wildcard-locked-note'),
    );
  }

  void _onWildcardTap(WildcardType type) {
    // Joker öğretimi tutorial turundan buraya taşındı: ilk kullanımda
    // tek seferlik contextual ipucu (her joker türü için ayrı).
    _maybeShowWildcardHint(type);
    switch (type) {
      case WildcardType.fiftyFifty:
        _useFiftyFifty();
      case WildcardType.audience:
        _useAudience();
      case WildcardType.doubleAnswer:
        _activateDoubleAnswer();
      case WildcardType.changeQuestion:
        _changeQuestion();
    }
  }

  Future<void> _maybeShowWildcardHint(WildcardType type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'zankurd.wildcard_hint.${type.name}';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    final hint = switch (type) {
      WildcardType.fiftyFifty => context.t(K.wildcardFiftyHint),
      WildcardType.audience => context.t(K.wildcardAudienceHint),
      WildcardType.doubleAnswer => context.t(K.wildcardDoubleHint),
      WildcardType.changeQuestion => context.t(K.wildcardChangeHint),
    };
    _showStageToast(hint);
  }

  // ─── Joker mekanikleri ───────────────────────────────────────────────────

  bool get _supportsOptionWildcards =>
      question.type != QuestionType.fillInBlank &&
      question.type != QuestionType.wordOrdering;

  /// Şık ELEYEN jokerler için ek koşul: en az dört şık.
  ///
  /// ## Kusur
  ///
  /// 50/50 iki yanlışı gizler. İki şıklı bir doğru/yanlış sorusunda tek bir
  /// yanlış vardır; `take(2)` onu gizler ve geriye YALNIZ doğru cevap kalır.
  /// Oyuncu 20 jeton ödeyip cevabın kendisini satın alıyordu.
  ///
  /// Çift cevap aynı kapıdan geçiyordu ve orada daha da kötüydü: iki şıklı
  /// bir soruda iki kez cevaplama hakkı kazanmayı GARANTİ eder — 50 jeton
  /// karşılığında kesin puan.
  ///
  /// Banka doğru/yanlış sorularıyla dolu; ikisi de kuramsal değil.
  ///
  /// Sessizdi çünkü kapı soru TÜRÜNE bakıyordu (`fillInBlank` ve
  /// `wordOrdering` dışarıda) ve doğru/yanlış da şıklı bir türdür. Eleme
  /// jokerlerini anlamlı kılan şey tür değil, ŞIK SAYISIdır (2026-08-12).
  ///
  /// Seyirci jokeri bu kapıdan geçmez: iki şıkta da dürüst bir dağılım
  /// gösterir, cevabı ele vermez.
  bool get _supportsEliminationWildcards =>
      _supportsOptionWildcards && question.answers.length >= 4;

  /// Çift cevap hakkı bu soruda anlamlı mı?
  ///
  /// Kısıt yalnız ŞIKLI sorular için geçerli. Serbest metinli türlerde
  /// (boşluk doldurma, sıralama) şık yoktur, dolayısıyla iki deneme hakkı
  /// hiçbir şeyi garanti etmez — oyuncu yine doğru sözcüğü yazmak zorunda.
  ///
  /// İlk taslak bu ayrımı yapmıyor ve `answers.length >= 4` diyordu; boşluk
  /// doldurma sorusunun şık listesi BOŞ olduğu için çift cevap orada da
  /// kapanmıştı. Kusuru iki mevcut test yakaladı.
  bool get _supportsDoubleAnswer =>
      !_supportsOptionWildcards || question.answers.length >= 4;

  /// Joker için ödeme yolu var mı: bedava günlük hak YA DA yeterli jeton.
  ///
  /// Yeni oyuncunun jetonu (8–19) en ucuz jokerin fiyatının (20) altındaydı;
  /// joker satırı her soruda kilitli kalıyor ve özellik hiç denenemiyordu.
  /// Günde bir kez, solo turda ilk kullanım bedavadır (bekçi:
  /// `free_wildcard_store_test`, `free_wildcard_quiz_test`).
  bool _canPayWildcard(WildcardType type) =>
      _freeWildcardAvailable || _coinBalance >= type.coinCost;

  /// Bedava hakkı bu kullanımda harcar; harcandıysa `true`.
  ///
  /// Bayrak HEMEN düşer (ikinci dokunuş aynı karede bedava saymasın), kalıcı
  /// yazım arkadan gider. Bedava kullanımda `_chargeWildcard` ÇAĞRILMAZ:
  /// sunucuya `spend_coins` gitmez, bakiye yerelde de düşmez. Sunucu jeton
  /// mantığı değişmedi.
  bool _takeFreeWildcard() {
    if (!_freeWildcardAvailable) return false;
    _freeWildcardAvailable = false;
    unawaited(FreeWildcardStore.consume());
    return true;
  }

  Future<void> _trackWildcardMission() async {
    final store = await DailyMissionStore.load();
    final completed = await store.reportWildcardUsed();
    if (completed == null || !mounted) return;

    // Görev XP'si BURADA verilmez: ödül ana ekranda "Ödülü al" ile alınırken
    // (`HomeScreen._claimMissionReward`) tek kez yazılır. Burada da yazmak
    // aynı görevi iki kez ödüllendiriyordu (bkz.
    // test/mission_xp_single_grant_test.dart).
    MissionToast.show(context, completed);
  }

  /// Jokerin ücretini sunucuya yazar ve gösterilen bakiyeyi gerçekle eşitler.
  ///
  /// Etki ÖNCE uygulanır, ücret sonra yazılır ve bu bilinçli: 50/50'nin
  /// şıkları gizlemesi için bir ağ gidiş-dönüşü beklemek, sayaç işlerken
  /// oyunu kilitlerdi ve çevrimdışı turda joker hiç çalışmazdı.
  ///
  /// Ama yerel düşüş bir VARSAYIMDIR ve doğrulanması gerekir. `spendCoins`
  /// sunucu reddettiğinde (fiyat ayrışması, yetersiz sunucu bakiyesi, oturum
  /// düşmesi) İSTİSNA FIRLATMAZ, yalnız `false` döner — ve bu dönüş hiç
  /// okunmuyordu, çağrı `catchError` ile ateşlenip unutuluyordu. Sonuç:
  /// ekranda jetonlar düşmüş görünüyor, sunucuda hiç düşmemiş oluyordu.
  /// Kullanıcı olmayan bir borcu görüyor ve bir sonraki tazelemeye kadar
  /// aslında alabileceği şeyleri alamıyordu (2026-08-17).
  ///
  /// Reddedilirse gösterilen bakiye sunucudan yeniden okunur — tahmin
  /// edilmez. Jokerin ETKİSİ geri alınmaz: şıklar zaten gizlenmiştir, onları
  /// geri getirmek verilmiş bir şeyi elden almak olurdu ve jokeri aynı soruda
  /// yeniden kullanılabilir kılmak bedava tekrar demektir.
  ///
  /// Taşıma hatasında bakiye OLDUĞU GİBİ bırakılır: `loadCoinBalance`
  /// çevrimdışı hatayı yukarı taşır ve son bilinen bakiye, uçak modunda
  /// "bakiyen bitti" göstermekten iyidir (bkz. o metodun 2026-08-14 notu).
  Future<void> _chargeWildcard(WildcardType type) async {
    // Anahtar turu da taşır: yalnız soru+tür olunca aynı soru başka bir
    // turda (tekrar kuyruğu, ertesi gün) yeniden çıktığında sunucu "zaten
    // ödendi" deyip jokeri bedava veriyordu (2026-10-25). Aynı turdaki
    // yeniden denemeler ve kuyruk aynı anahtarı kullanır.
    final idempotencyKey =
        'wildcard:$_analyticsRoundId:${question.id}:${type.name}';
    bool charged;
    try {
      final result = await widget.repository.spendCoinsDurable(
        type.coinCost,
        type.spendReason,
        idempotencyKey,
      );
      if (!result.success && result.retryable) {
        await SyncManager.maybeInstance?.queueCoinSpend(
          amount: type.coinCost,
          reason: type.spendReason,
          idempotencyKey: idempotencyKey,
        );
      }
      charged = result.success || result.retryable;
    } on RetryableWriteException catch (error, stack) {
      ErrorReporter.record(
        error.cause,
        stack,
        reason: 'spend_coins_${type.name}',
      );
      await SyncManager.maybeInstance?.queueCoinSpend(
        amount: type.coinCost,
        reason: type.spendReason,
        idempotencyKey: idempotencyKey,
      );
      charged = true;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'spend_coins_${type.name}');
      charged = false;
    }
    if (charged || !mounted) return;

    try {
      final balance = await widget.repository.loadCoinBalance();
      if (!mounted) return;
      setState(() => _coinBalance = balance);
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'wildcard balance resync ${type.name}',
      );
    }
  }

  void _useFiftyFifty() {
    if (!_supportsEliminationWildcards ||
        _wildcard.fiftyFiftyUsed ||
        !_canPayWildcard(WildcardType.fiftyFifty) ||
        answered) {
      return;
    }
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    final free = _takeFreeWildcard();
    setState(() {
      if (!free) _coinBalance -= WildcardType.fiftyFifty.coinCost;
      _wildcard = _wildcard.copyWith(fiftyFiftyUsed: true);
      // Gizlenecek yanlışlar rastgele seçilir; hep ilk ikisi gizlenirse
      // dikkatli oyuncu örüntüyü ezberler.
      hiddenAnswers =
          (question.answers.where((a) => a != question.correctAnswer).toList()
                ..shuffle())
              .take(2)
              .toSet();
    });
    if (!free) unawaited(_chargeWildcard(WildcardType.fiftyFifty));
  }

  void _useAudience() {
    if (!_supportsOptionWildcards ||
        _wildcard.audienceUsed ||
        !_canPayWildcard(WildcardType.audience) ||
        answered) {
      return;
    }
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    final free = _takeFreeWildcard();
    setState(() {
      if (!free) _coinBalance -= WildcardType.audience.coinCost;
      _wildcard = _wildcard.copyWith(audienceUsed: true);
      _audiencePoll = _buildAudiencePoll();
    });
    if (!free) unawaited(_chargeWildcard(WildcardType.audience));
  }

  Map<String, double> _buildAudiencePoll() {
    final seed = question.id.codeUnits.fold<int>(0, (s, u) => s + u);
    final rng = Random(seed);

    // 50/50 aktifse sadece görünür şıkları kullan
    final visible = question.answers
        .where((a) => !hiddenAnswers.contains(a))
        .toList();
    final wrongs = visible.where((a) => a != question.correctAnswer).toList();

    // Doğru cevap %50-70 oy alır
    final correctShare = 0.50 + rng.nextDouble() * 0.20;
    var remaining = 1.0 - correctShare;

    final poll = <String, double>{};
    for (var i = 0; i < wrongs.length; i++) {
      if (i == wrongs.length - 1) {
        poll[wrongs[i]] = remaining < 0 ? 0.0 : remaining;
      } else {
        final share = remaining * (0.15 + rng.nextDouble() * 0.45);
        poll[wrongs[i]] = share;
        remaining -= share;
      }
    }
    poll[question.correctAnswer] = correctShare;
    return poll;
  }

  void _activateDoubleAnswer() {
    if (!_supportsDoubleAnswer ||
        _wildcard.doubleAnswerActivated ||
        !_canPayWildcard(WildcardType.doubleAnswer) ||
        answered ||
        _firstAttemptAnswer.isNotEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    final free = _takeFreeWildcard();
    setState(() {
      if (!free) _coinBalance -= WildcardType.doubleAnswer.coinCost;
      _wildcard = _wildcard.copyWith(doubleAnswerActivated: true);
    });
    if (!free) unawaited(_chargeWildcard(WildcardType.doubleAnswer));
  }

  void _changeQuestion() {
    if (!_isSoloMode ||
        _wildcard.changeQuestionUsed ||
        !_canPayWildcard(WildcardType.changeQuestion) ||
        answered) {
      return;
    }

    final usedIds = _questions.map((q) => q.id).toSet();

    // Türkçe oynanıyorsa çevirisi olmayan soru aday olamaz: aksi hâlde
    // oyuncu 30 coin ödeyip okuyamadığı bir soru alır. Kurmancîde her
    // sorunun metni zaten anadilindedir, o yüzden koşul yalnız TR'de.
    bool usable(QuizQuestion q) => _isKu || q.hasTurkishTranslation;

    final candidates = wildcardReplacementCandidates(
      current: question,
      pool: widget.repository.playableQuestions,
      usedIds: usedIds,
      usable: usable,
    );

    if (candidates.isEmpty) return; // değiştirilecek soru bulunamadı

    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    final replacement = candidates[Random().nextInt(candidates.length)];

    final free = _takeFreeWildcard();
    setState(() {
      if (!free) _coinBalance -= WildcardType.changeQuestion.coinCost;
      _wildcard = _wildcard.copyWith(changeQuestionUsed: true);
      // `.localized()` ÇAĞRISI ŞART. initState turdaki bütün soruları bir
      // kez seçili dile yansıtıyor (quiz_screen.dart:301); yedek soru ise
      // havuzdan ham hâliyle geliyordu. `promptText` o zaman doğrudan
      // `prompt` alanını, yani Kurmancî metni döndürür — Türkçe oynayan
      // oyuncu 30 coin ödeyip Kurmancî bir soru ve Kurmancî şıklar
      // alıyordu (2026-07-31 denetimi).
      _questions[index] = replacement.localized(
        isKu: _isKu,
        learning: _isLearningExperience,
      );
      hiddenAnswers = const {};
      _audiencePoll = null;
      favorite = false;
      _favoriteTouched = false;
      // İlk deneme ATILAN soruya aitti; yeni soruya taşınamaz.
      //
      // Taşındığında Çift Cevap hakkı sessizce yanıyordu: oyuncu 50 jeton
      // ödeyip iki cevap hakkı alıyor, ilkini yanlış kullanıyor (bu aşamada
      // `answered` hâlâ yanlıştır, o yüzden soru değiştirme açıktır), 40
      // jetonla soruyu değiştiriyor ve yeni soruda İLK dokunuşu ikinci
      // deneme sayılıyordu — tek şansı kalıyordu. Ödediği iki hakkın biri,
      // artık görmediği bir soruda harcanmış oluyordu (2026-08-12 denetimi).
      //
      // `doubleAnswerActivated` bilerek korunuyor: hak duruyor, yalnız o
      // hakkın atılan soruda kullanılmış YARISI siliniyor.
      _firstAttemptAnswer = '';
    });
    _markQuestionSeen();
    _loadFavoriteState();
    _startTimer();
    if (!free) unawaited(_chargeWildcard(WildcardType.changeQuestion));
  }

  // ─── Soru paneli ─────────────────────────────────────────────────────────

  /// Soru: (görsel) + soru metni + şık çubukları + öğrenme notu.
  ///
  /// Başlık kartı YOK: Şahnê'de soru sahnenin kendisinde durur (maketteki
  /// `.sh-q`). Kategori kimliği sahne zemininde ve huzmenin ışığındadır;
  /// eski kategori rozeti, "Şıklı" etiketi ve kartın arkasındaki hayalet
  /// ikon kalktı.
  Widget _buildQuestionPanel(
    BuildContext context, {
    Size? layoutSize,
    double? bodyHeight,
    double? anchorHeight,
    bool? showExplanation,
    GlobalKey? answerAreaKey,
    GlobalKey? correctAnswerKey,
    VoidCallback? questionVisualReady,
  }) {
    final promptText = question.promptText;
    // Yerleşim dalıyla AYNI ölçü ve AYNI kural (`_useCompactLandscapeLayout`):
    // dal iki sütun seçerken panelin tipografisi/görseli başka bir ölçüden
    // karar verirse ikisi çelişir (1440×900 ve 768×1024 kusurları).
    final size = layoutSize ?? MediaQuery.sizeOf(context);
    final compactLandscape = _useCompactLandscapeLayout(
      size.width,
      size.height,
    );
    // Kısa ekran (iPhone SE, telefon-yatay): görsel bir basamak küçülür,
    // şıkların dikey iç boşluğu daralır. Yazı küçülmez.
    final isCompact = compactLandscape || size.height < 700;
    // Görselin boyu kayan GÖVDEYE göre seçilir: üst satır, elmas dizisi ve
    // alt perde düşüldükten sonra kalan alan 720'den kısaysa (her telefon)
    // görsel dar kademeye (%19, 64–132) iner. Aksi hâlde görselli dört şıklı
    // soruda D şıkkı alt perdenin arkasına düşüyordu (402×874, bkz.
    // `quiz_round_honesty_test` Kusur 3). Tablette görsel tam boyunda kalır.
    final imageCompact = isCompact || (bodyHeight ?? size.height) < 720;

    Widget textAndAnswers({required bool headline}) => _QuestionTextAndAnswers(
      promptText: promptText,
      lexiconEnabled: _lexiconTapAllowed,
      translationEnabled: _translationRevealAllowed,
      forceHeadline: headline,
      // Düello kartı ~120 pt yer tutar: uzun soru bir kademe erken küçülür.
      titleLineBudget: (widget.is1v1 || _isCrowd)
          ? QuizQuestionPrompt.maxTitleLines - 1
          : QuizQuestionPrompt.maxTitleLines,
      question: question,
      selectedAnswer: selectedAnswer,
      adjudicatedCorrect: _currentAnswerAdjudication,
      answered: answered,
      hiddenAnswers: hiddenAnswers,
      firstAttemptAnswer: _firstAttemptAnswer,
      audiencePoll: _audiencePoll,
      showExplanation: showExplanation ?? _showExplanation,
      wrongAnswerInsight: _wrongAnswerInsightVisible,
      suspense: _suspense,
      opponentSelectedAnswers: _opponentSelectedAnswers,
      isCompact: isCompact,
      minBodyHeight: anchorHeight,
      twoColumn: compactLandscape,
      answerAreaKey: answerAreaKey,
      correctAnswerKey: correctAnswerKey,
      explanationKey: _explanationKey,
      explanationActionKey: _explanationActionKey,
      onAnswer: _answer,
      onListen: _listenCurrentQuestion,
      canListen: _canListenCurrentQuestion,
      listeningListenable: _questionAudioService?.playingListenable,
    );

    if (compactLandscape && question.hasImage) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 164,
            child: _QuestionImage(
              url: question.imageUrl!,
              alt: question.imageAltFor(isKu: context.isKu),
              isCompact: isCompact,
              layoutSize: size,
              onReady: questionVisualReady,
            ),
          ),
          const SizedBox(width: SahneSpace.x3),
          Expanded(child: textAndAnswers(headline: true)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (question.hasImage) ...[
          _QuestionImage(
            key: _photoKeyFor(index),
            url: question.imageUrl!,
            alt: question.imageAltFor(isKu: context.isKu),
            isCompact: imageCompact,
            layoutSize: size,
            onReady: questionVisualReady,
          ),
          const SizedBox(height: SahneSpace.x3),
        ],
        textAndAnswers(headline: compactLandscape),
      ],
    );
  }

  /// Çevrimiçi sonucun teslim kapısı (yükleniyor / alınamadı). Sahnenin
  /// içinde kalır: tur bitti ama sonuç henüz yok. Tek birincil eylem
  /// "Tekrar dene"; "Ana sayfa" ikincil.
  Widget _buildOnlineResultGate(BuildContext context) {
    final loading = _onlineResultPhase == _OnlineResultPhase.loading;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !loading) {
          _leaveOnlineResultGate();
        }
      },
      child: SahneStageScaffold(
        closeLabel: context.t(K.close),
        center: Semantics(header: true, child: Text(context.t(K.resultTitle))),
        body: Builder(
          builder: (context) {
            final t = SahneTokens.of(context);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(SahneSpace.x6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: loading
                          ? CircularProgressIndicator(color: t.gold)
                          : Icon(
                              _onlineResultOwnerChanged
                                  ? AppIcons.shield
                                  : AppIcons.cloud,
                              size: 48,
                              color: t.goldTx,
                            ),
                    ),
                    const SizedBox(height: SahneSpace.x4),
                    Text(
                      context.t(
                        loading
                            ? K.resultRecoveryLoading
                            : _onlineResultOwnerChanged
                            ? K.resultRecoveryOwnerChanged
                            : K.resultRecoveryFailed,
                      ),
                      textAlign: TextAlign.center,
                      style: SahneType.body.copyWith(color: t.tx),
                    ),
                    if (!loading) ...[
                      const SizedBox(height: SahneSpace.x6),
                      SahneButton.primary(
                        label: context.t(K.retry),
                        icon: AppIcons.arrowsRotate,
                        arrow: false,
                        expand: true,
                        onPressed: _retryOnlineResultGate,
                      ),
                      const SizedBox(height: SahneSpace.x3),
                      SahneButton.secondary(
                        label: context.t(K.home),
                        icon: AppIcons.house,
                        expand: true,
                        onPressed: _leaveOnlineResultGate,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
