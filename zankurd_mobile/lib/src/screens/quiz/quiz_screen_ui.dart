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
                  ],
                  _buildQuestionEyebrow(context),
                  const SizedBox(height: SahneSpace.x2),
                  _buildQuestionSwitcher(
                    context,
                    layoutSize: layoutSize,
                    bodyHeight: constraints.maxHeight,
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
                        _buildQuestionEyebrow(context),
                        const SizedBox(height: SahneSpace.x2),
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
      _MultiplayerWaitingOverlay(isKu: _isKu),
    if (_isMultiplayer && _mpPhase == _MultiplayerPhase.reveal)
      _RevealCountdown(seconds: _revealCountdown, isKu: _isKu),
  ];

  /// Üst satırın orta yuvası: süreli turda sayaç, süresiz turda turun adı.
  ///
  /// Tur adı sırası: oda kodu (çevrimiçi) → turun kendi adı → kategori
  /// (bkz. `quizRoundTitle`). Kategori adı doğrudan yazıldığında günün
  /// dersinde yalan oluyordu: o tur karışık kategorilidir (2026-07-27).
  ///
  /// Coach-mark hedefi (`_timerTargetKey`) her iki hâlde de bu yuvadadır:
  /// süreli turda "süre burada", süresiz turda "burada süre yok" der.
  /// Üst satır `AnimatedSwitcher`in dışında olduğu için anahtar her soruda
  /// güvenle takılır.
  Widget _buildStageCenter(BuildContext context) {
    if (_usesTimer) {
      return KeyedSubtree(
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
        ),
      );
    }
    return KeyedSubtree(
      key: _timerTargetKey,
      child: Semantics(header: true, child: Text(_roundTitle(context))),
    );
  }

  /// Üst satırın sağ yuvası: yarışmada skor çipi (Zêr yıldız + puan).
  ///
  /// Öğrenmede skor yok (rekabet baskısı gösterilmez); düelloda iki skor
  /// gövdedeki düello kartında yan yana durur.
  Widget? _buildScoreChip(BuildContext context) {
    if (_isLearningExperience || widget.is1v1) return null;
    // Tur başında "★ 0" bilgi vermez, yalnız baskı kurar; ilk puanda belirir.
    if (score <= 0) return null;
    return SahneStatChip(
      leading: const SahneGlyph(SahneGlyphKind.star),
      label: '$score',
      semanticLabel: '$score ${context.t(K.scoreWord)}',
    );
  }

  /// Üst satırın altı: 10'lu elmas dizisi (+ yarışmada seri rozeti).
  ///
  /// Durum ŞEKİLLE ayrışır: doğru dolu + ✓, yanlış boş + ✗, bekleyen yalnız
  /// çizgi; şimdiki soru altın halka. Eski kilim tahtasının yeşil/kırmızı
  /// ayrımı renk körlüğünde kayboluyordu; elmasların şekli kaybolmaz.
  /// Ekran okuyucu tek bir özet okur ("3/10 · 2 Doğru · 0 Yanlış").
  Widget _buildStageProgress(BuildContext context) {
    final total = widget.questions.length;
    final results = [for (final record in answerRecords) record.isCorrect];
    final right = results.where((r) => r).length;
    final wrong = results.length - right;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SahneDiamondRow(
          key: const ValueKey('quiz-progress-bar'),
          states: [
            for (var i = 0; i < total; i++)
              i < results.length
                  ? (results[i]
                        ? SahneDiamondState.correct
                        : SahneDiamondState.wrong)
                  : SahneDiamondState.pending,
          ],
          currentIndex: index < total ? index : null,
          semanticLabel:
              '${index + 1}/$total · $right ${context.t(K.correct)} · '
              '$wrong ${context.t(K.wrong)}',
        ),
        if (!_isLearningExperience) _buildComboRow(),
      ],
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

  /// Gövdenin üst etiketi: kategori ikonu + "DİL • SORU 3/10" ve sorunun
  /// araçları (sohbet, kaydet, bildir). Araçlar 44'lük Şahnê ikon
  /// düğmeleridir, 48'lik dokunma kutusunda.
  ///
  /// Etiket `AnimatedSwitcher`in DIŞINDA: soru geçişinde araç düğmeleri iki
  /// kez görünmesin (eski ve yeni panel geçiş boyunca birlikte yaşar).
  Widget _buildQuestionEyebrow(BuildContext context) {
    final t = SahneTokens.of(context);
    final category = CategoryNames.localized(question.category, context.isKu);
    final progress = context.t(K.placementProgress, {
      'index': '${index + 1}',
      'total': '${widget.questions.length}',
    });
    final favoriteActionLabel = favorite
        ? context.t(K.removeAction)
        : context.t(K.save);
    return Row(
      children: [
        CategoryKickerMark(
          key: const ValueKey('quiz-question-icon-badge'),
          category: question.category,
          fallbackColor: t.tx2,
        ),
        const SizedBox(width: SahneSpace.x2),
        Expanded(
          child: Text(
            '$category · $progress',
            style: SahneType.eyebrow.copyWith(color: t.tx),
          ),
        ),
        if (_isMultiplayer)
          SahneIconButton(
            key: const ValueKey('quiz-reaction-menu-button'),
            icon: AppIcons.faceSmile,
            semanticLabel: context.t(K.chat),
            onPressed: () => _showLiveReactionMenu(context),
          ),
        // Kaydedilmiş soru dolu (Zêr) hâlde durur: "Kaldır" sözü tek
        // başına durumu göstermiyordu.
        SahneIconButton(
          icon: AppIcons.bookmark,
          semanticLabel: favoriteActionLabel,
          selected: favorite,
          onPressed: _toggleFavorite,
        ),
        SahneIconButton(
          icon: AppIcons.triangleExclamation,
          semanticLabel: context.t(K.reportAction),
          onPressed: _reportQuestion,
        ),
      ],
    );
  }

  Widget _buildQuestionSwitcher(
    BuildContext context, {
    Size? layoutSize,
    double? bodyHeight,
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
    Widget rate(String key, int value) => Expanded(
      child: SahneButton.secondary(
        label: context.t(key),
        expand: true,
        onPressed: () => _submitPracticeRating(value),
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

    return Column(
      key: const ValueKey('quiz-wildcard-row'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CoinBalanceLine(
          balance: _coinBalance,
          // Hiç jetonu olmayan yeni oyuncuya kilitler "her şey paralı"
          // gibi görünmesin: jetonun nereden kazanılacağını söyle.
          hint: _coinBalance == 0 && index == 0
              ? context.t(K.finishQuizHint)
              : null,
          // Dar dikey alanda (küçük telefon, %150+ yazı) ipucu yalnız ekran
          // okuyucuya gider: iki satırlık bir cümle alt perdeyi büyütüp
          // soruya kalan yeri yarıya indiriyordu (320×568 @2.0).
          showHint:
              MediaQuery.textScalerOf(context).scale(1) < 1.5 &&
              MediaQuery.sizeOf(context).height >= 640,
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
    final canAfford = _coinBalance >= type.coinCost;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hint),
        behavior: SnackBarBehavior.floating,
        margin: _quizSnackBarMargin,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 148 = alt perdenin en yüksek hâli: jeton satırı (~20) + joker dizisi
  /// (52) + perdenin iç boşluğu ve alt güvenli alan (~76). Tost bu yüksekliğin
  /// üstünde açılır, jokerlerin ya da "Sonraki"nin üstünü örtmez (M-2).
  static const double _kActionBarClearance = 148.0;
  static const EdgeInsets _quizSnackBarMargin = EdgeInsets.fromLTRB(
    SahneSpace.page,
    0,
    SahneSpace.page,
    _kActionBarClearance,
  );

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

  Future<void> _trackWildcardMission() async {
    final store = await DailyMissionStore.load();
    final completed = await store.reportWildcardUsed();
    if (completed == null || !mounted) return;

    final xpStore = await XPStore.load();
    final missionXP = completed.xpReward;
    final leveledUp = await xpStore.addXP(missionXP);
    unawaited(
      XpAwardPublisher.publish(repository: widget.repository, delta: missionXP),
    );

    if (!mounted) return;
    MissionToast.show(context, completed);
    if (leveledUp) {
      final isKu = context.isKu;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Tr.forKu(K.tebriklerSeviyeAtladinYeni, isKu, {
              'p0': '${xpStore.currentLevel}',
            }),
          ),
          behavior: SnackBarBehavior.floating,
          margin: _quizSnackBarMargin,
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
    bool charged;
    try {
      final result = await widget.repository.spendCoinsDurable(
        type.coinCost,
        type.spendReason,
        'wildcard:${question.id}:${type.name}',
      );
      if (!result.success && result.retryable) {
        await SyncManager.maybeInstance?.queueCoinSpend(
          amount: type.coinCost,
          reason: type.spendReason,
          idempotencyKey: 'wildcard:${question.id}:${type.name}',
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
        idempotencyKey: 'wildcard:${question.id}:${type.name}',
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
    final cost = WildcardType.fiftyFifty.coinCost;
    if (!_supportsEliminationWildcards ||
        _wildcard.fiftyFiftyUsed ||
        _coinBalance < cost ||
        answered) {
      return;
    }
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(fiftyFiftyUsed: true);
      // Gizlenecek yanlışlar rastgele seçilir; hep ilk ikisi gizlenirse
      // dikkatli oyuncu örüntüyü ezberler.
      hiddenAnswers =
          (question.answers.where((a) => a != question.correctAnswer).toList()
                ..shuffle())
              .take(2)
              .toSet();
    });
    unawaited(_chargeWildcard(WildcardType.fiftyFifty));
  }

  void _useAudience() {
    final cost = WildcardType.audience.coinCost;
    if (!_supportsOptionWildcards ||
        _wildcard.audienceUsed ||
        _coinBalance < cost ||
        answered) {
      return;
    }
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(audienceUsed: true);
      _audiencePoll = _buildAudiencePoll();
    });
    unawaited(_chargeWildcard(WildcardType.audience));
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
    final cost = WildcardType.doubleAnswer.coinCost;
    if (!_supportsDoubleAnswer ||
        _wildcard.doubleAnswerActivated ||
        _coinBalance < cost ||
        answered ||
        _firstAttemptAnswer.isNotEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(doubleAnswerActivated: true);
    });
    unawaited(_chargeWildcard(WildcardType.doubleAnswer));
  }

  void _changeQuestion() {
    final cost = WildcardType.changeQuestion.coinCost;
    if (!_isSoloMode ||
        _wildcard.changeQuestionUsed ||
        _coinBalance < cost ||
        answered) {
      return;
    }

    final category = question.category;
    final difficulty = question.difficulty;
    final usedIds = _questions.map((q) => q.id).toSet();

    // Türkçe oynanıyorsa çevirisi olmayan soru aday olamaz: aksi hâlde
    // oyuncu 30 coin ödeyip okuyamadığı bir soru alır. Kurmancîde her
    // sorunun metni zaten anadilindedir, o yüzden koşul yalnız TR'de.
    bool usable(QuizQuestion q) => _isKu || q.hasTurkishTranslation;

    // Önce aynı kategori + zorlukta aday ara
    var candidates = widget.repository.playableQuestions
        .where(
          (q) =>
              q.category == category &&
              q.difficulty == difficulty &&
              !usedIds.contains(q.id) &&
              usable(q),
        )
        .toList();

    // Yeterli yoksa aynı kategoride herhangi bir zorluk
    if (candidates.isEmpty) {
      candidates = widget.repository.playableQuestions
          .where(
            (q) =>
                q.category == category && !usedIds.contains(q.id) && usable(q),
          )
          .toList();
    }

    if (candidates.isEmpty) return; // değiştirilecek soru bulunamadı

    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    final replacement = candidates[Random().nextInt(candidates.length)];

    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(changeQuestionUsed: true);
      // `.localized()` ÇAĞRISI ŞART. initState turdaki bütün soruları bir
      // kez seçili dile yansıtıyor (quiz_screen.dart:301); yedek soru ise
      // havuzdan ham hâliyle geliyordu. `promptText` o zaman doğrudan
      // `prompt` alanını, yani Kurmancî metni döndürür — Türkçe oynayan
      // oyuncu 30 coin ödeyip Kurmancî bir soru ve Kurmancî şıklar
      // alıyordu (2026-07-31 denetimi).
      _questions[index] = replacement.localized(isKu: _isKu);
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
    unawaited(_chargeWildcard(WildcardType.changeQuestion));
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
      forceHeadline: headline,
      // Düello kartı ~120 pt yer tutar: uzun soru bir kademe erken küçülür.
      titleLineBudget: widget.is1v1
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
      suspense: _suspense,
      opponentSelectedAnswers: _opponentSelectedAnswers,
      isCompact: isCompact,
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
