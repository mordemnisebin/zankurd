part of '../quiz_screen.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _QuizScreenUI on _QuizScreenState {
  Widget _buildPortraitLayout() {
    // Yarışma modlarında (solo/1v1/oda) tur içinde açıklama gösterilmez.
    final showExpl = _isLearningExperience && _showExplanation;

    final screenHeight = MediaQuery.sizeOf(context).height;

    // Düzen üç bölgeye ayrılır: sabit üst (skor/ilerleme), kaydırılabilir
    // orta (soru + şıklar) ve sabit alt aksiyon barı. Böylece "Sonraki"
    // butonu ile joker satırı soru ne kadar uzun olursa olsun her zaman
    // ekranda kalır — geri sayım işlerken kullanıcı scroll etmek zorunda
    // kalmaz (2026-07-22 canlı UX denetimi, P0-1).
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = min(constraints.maxWidth - 24, 800.0);
        final layoutSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Padding(
          // M-7: raw literal → adlandırılmış sabit. 6px, AppSpacing.xxs(4) ile
          // xs(8) arasında; quiz-özel değer olduğu için ayrı sabite alındı.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            6.0,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: Column(
                children: [
                  if (!_isLearningExperience) ...[
                    _buildScoreHeader(),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  _buildProgressBar(context),
                  if (!_isLearningExperience) _buildComboRow(),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    // Kısa sorular uzun telefonlarda ekranın ortasına
                    // itilmez. Üstten başlayan akış ilerleme çubuğu → soru
                    // ilişkisini korur; uzun içerik yine kaydırılabilir.
                    child: LayoutBuilder(
                      builder: (context, scrollConstraints) {
                        // Kartın altına başka bir şey düşüyorsa (süre doldu
                        // uyarısı, rakip bekleme perdesi, geri sayım, canlı
                        // skor tablosu) kart alanı doldurmaz — yoksa o
                        // öğeler ekranın dışına taşar ve her soruda
                        // kaydırma gerekirdi.
                        // Kartın ALTINA düşen öğelerin yer payı.
                        //
                        // Önce bu bir aç/kapa anahtarıydı: altta bir şey
                        // varsa kart hiç dolmuyordu ve boşluk geri geliyordu
                        // — süre dolduğunda ekranın alt üçte biri yine
                        // bomboş kalıyordu (2026-08-16 simülatör taraması).
                        // Oysa doğrusu doldurmayı kapatmak değil, o öğelere
                        // pay ayırmak. Pay eksik kalırsa kart kaydırılır;
                        // fazla kalırsa küçük bir boşluk olur — ikisi de
                        // ekranın üçte birini boş bırakmaktan iyidir.
                        var reservedBelowCard = 0.0;
                        if (selectedAnswer == 'TIMEOUT' && !_suspense) {
                          reservedBelowCard += 56;
                        }
                        if (_isMultiplayer &&
                            answered &&
                            _mpPhase == _MultiplayerPhase.waiting) {
                          reservedBelowCard += 72;
                        }
                        if (_isMultiplayer &&
                            _mpPhase == _MultiplayerPhase.reveal) {
                          reservedBelowCard += 72;
                        }
                        if (widget.is1v1 && screenHeight >= 800) {
                          reservedBelowCard += 104;
                        }
                        // Karta gerçekten kalan yükseklik. Doldurma
                        // yapılmasa bile sıkışıklık kararı buna bakar.
                        final availableCardHeight =
                            scrollConstraints.hasBoundedHeight
                            ? max(
                                0.0,
                                scrollConstraints.maxHeight - AppSpacing.md,
                              )
                            : null;
                        final fillHeight = availableCardHeight == null
                            ? null
                            : (availableCardHeight - reservedBelowCard > 0
                                  ? availableCardHeight - reservedBelowCard
                                  : null);
                        return SingleChildScrollView(
                          key: const ValueKey('quiz-portrait-scroll'),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: scrollConstraints.maxHeight.clamp(
                                0.0,
                                double.infinity,
                              ),
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.md,
                                ),
                                child: Column(
                                  key: const ValueKey('quiz-answer-content'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Coach-mark GlobalKey'leri yalnız ilk soruda: panel
                                    // AnimatedSwitcher içinde olduğundan geçiş sırasında
                                    // eski ve yeni panel aynı anda yaşar; anahtar her
                                    // soruda geçilirse duplicate-GlobalKey hatası oluşur.
                                    // Eğitim turu zaten sadece ilk soruda gösterilir.
                                    _buildQuestionSwitcher(
                                      context,
                                      layoutSize: layoutSize,
                                      showExplanation: showExpl,
                                      timerKey: index == 0
                                          ? _timerTargetKey
                                          : null,
                                      answerAreaKey: index == 0
                                          ? _answerAreaKey
                                          : null,
                                      correctAnswerKey: _correctAnswerKey,
                                      questionVisualReady: !_questionVisualReady
                                          ? _handleQuestionVisualReady
                                          : null,
                                      minHeight: fillHeight,
                                      availableHeight: availableCardHeight,
                                    ),
                                    if (selectedAnswer == 'TIMEOUT' &&
                                        !_suspense)
                                      QuizTimeoutNotice(
                                        isKu: _isKu,
                                        correctAnswer: question.correctAnswer,
                                      ),
                                    if (_isMultiplayer &&
                                        answered &&
                                        _mpPhase == _MultiplayerPhase.waiting)
                                      _MultiplayerWaitingOverlay(isKu: _isKu),
                                    if (_isMultiplayer &&
                                        _mpPhase == _MultiplayerPhase.reveal)
                                      _RevealCountdown(
                                        seconds: _revealCountdown,
                                        isKu: _isKu,
                                      ),
                                    if (widget.is1v1 &&
                                        screenHeight >= 800) ...[
                                      const SizedBox(height: 8),
                                      _LiveScoreboard(players: livePlayers),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildActionControls(),
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
  // `_useCompactLandscapeLayout` başında.

  Widget _buildCompactLandscapeLayout() {
    // Portrait ile aynı kural: tur içi açıklama yalnız Öğrenme Bölgesi'nde.
    final showExpl = _isLearningExperience && _showExplanation;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutSize = Size(constraints.maxWidth, constraints.maxHeight);
        return SingleChildScrollView(
          // M-7: landscape iç dolgu — aynı 6px quiz gap sabiti.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            6.0,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Center(
            child: SizedBox(
              key: const ValueKey('quiz-landscape-content'),
              width: min(constraints.maxWidth - 24, 800.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Portrait'taki notla aynı: coach-mark anahtarları
                        // yalnız ilk soruda geçilir (duplicate-GlobalKey).
                        _buildQuestionSwitcher(
                          context,
                          layoutSize: layoutSize,
                          showExplanation: showExpl,
                          timerKey: index == 0 ? _timerTargetKey : null,
                          answerAreaKey: index == 0 ? _answerAreaKey : null,
                          correctAnswerKey: _correctAnswerKey,
                          questionVisualReady: !_questionVisualReady
                              ? _handleQuestionVisualReady
                              : null,
                        ),
                        if (selectedAnswer == 'TIMEOUT' && !_suspense)
                          QuizTimeoutNotice(
                            isKu: _isKu,
                            correctAnswer: question.correctAnswer,
                          ),
                        if (_isMultiplayer &&
                            answered &&
                            _mpPhase == _MultiplayerPhase.waiting)
                          _MultiplayerWaitingOverlay(isKu: _isKu),
                        if (_isMultiplayer &&
                            _mpPhase == _MultiplayerPhase.reveal)
                          _RevealCountdown(
                            seconds: _revealCountdown,
                            isKu: _isKu,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 270),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isLearningExperience) ...[
                            _buildScoreHeader(),
                            const SizedBox(height: 6),
                          ],
                          _buildProgressBar(context),
                          if (!_isLearningExperience) _buildComboRow(),
                          const SizedBox(height: 6),
                          _buildActionControls(),
                          if (widget.is1v1) ...[
                            const SizedBox(height: 8),
                            _LiveScoreboard(players: livePlayers),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Combo rozeti + puan uçuşu satırı. Rozet yokken yükseklik kaplamaz.
  Widget _buildComboRow() {
    return Padding(
      key: _comboKey,
      padding: EdgeInsets.only(top: comboTierFor(streak) != null ? 10 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ComboBadge(streak: streak, isKu: _isKu),
          const SizedBox(width: 10),
          ScoreFlyup(trigger: _flyupTrigger, points: _lastPointsEarned),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    if (widget.is1v1) {
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
    return _ScoreHeader(
      score: score,
      streak: streak,
      coinBalance: _coinBalance,
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final total = widget.questions.length;
    // Uzun setlerde nokta şeridi sıkışır; klasik bara geri dön.
    if (total > 15) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (index + 1) / total),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (_, value, _) => KilimProgressBar(value: value, height: 8),
      );
    }
    // Yarışma şeridi: her soru bir segment — doğru yeşil, yanlış kırmızı
    // dolar; aktif soru vurgulu bekler. Renk anlamı tooltip + semantics
    // ile açıklanır (kırmızı segment "yanlış cevap" demektir).
    return Semantics(
      label: context.t(K.progressLegend),
      child: Tooltip(
        message: context.t(K.progressLegendShort),
        child: Row(
          // Bu satır İLERLEME ÇUBUĞU. Anahtarı bir zamanlar
          // `quiz-wildcard-row`du ve iki test onunla "joker satırı ekranda"
          // diye iddia ediyordu; ilerleme çubuğu her zaman ekranda olduğu
          // için o iki iddia hiçbir şey korumuyordu (2026-08-12 denetimi).
          key: const ValueKey('quiz-progress-bar'),
          children: [
            for (var i = 0; i < total; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: i == index ? 8 : 6,
                  decoration: BoxDecoration(
                    color: i < answerRecords.length
                        ? (answerRecords[i].isCorrect
                              ? AppTheme.correct
                              : AppTheme.wrong)
                        : i == index
                        ? AppTheme.brand
                        : AppTheme.surfaceHiColor(context),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: AppTheme.brand.withValues(alpha: 0.45),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              if (i != total - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionSwitcher(
    BuildContext context, {
    Size? layoutSize,
    bool? showExplanation,
    GlobalKey? timerKey,
    GlobalKey? answerAreaKey,
    GlobalKey? correctAnswerKey,
    VoidCallback? questionVisualReady,
    double? minHeight,
    double? availableHeight,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      // Opaklık yalnız ikinci yarıda yükselir. AnimatedSwitcher giden
      // çocuğu aynı animasyonu ters yönde oynatarak çizdiğinden, düz
      // `opacity: animation` ile iki soru kartı geçiş boyunca aynı anda
      // yarı saydam kalıyor ve metinler üst üste binip okunmuyordu
      // (2026-07-25 canlı denetimi). Bu aralık, giden kart görünmez
      // olduktan SONRA gelenin belirmesini sağlar.
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
      child: KeyedSubtree(
        key: ValueKey(index),
        child: _buildQuestionPanel(
          context,
          layoutSize: layoutSize,
          showExplanation: showExplanation,
          timerKey: timerKey,
          answerAreaKey: answerAreaKey,
          correctAnswerKey: correctAnswerKey,
          questionVisualReady: questionVisualReady,
          minHeight: minHeight,
          availableHeight: availableHeight,
        ),
      ),
    );
  }

  Widget _buildActionControls() {
    final bool showRatingBar =
        widget.practice &&
        answered &&
        answerRecords.any(
          (record) => record.id == question.id && record.isCorrect,
        ) &&
        !completing;

    // Multiplayer'da "Sonraki" butonu devre dışı: geçiş otomatik.
    // Gerilim tutuşu (sonuç bekleniyor) sırasında da kilitli: hızlı dokunuş
    // skor uygulanmadan soruyu ilerletmesin. Tutuş en fazla ~8 sn sürer
    // (submitAnswer zaman aşımı sonrası yerel değerlendirme).
    final bool canPressNext = _isMultiplayer
        ? false
        : (answered && !completing && !_suspense);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isLearningExperience && !_usesServerHiddenAnswers) ...[
          _buildWildcardRow(),
          SizedBox(height: isCompact ? AppSpacing.xxs : AppSpacing.xs),
        ],
        // Çift Cevap ilk denemesi yanlışsa: reveal görüntüsü olmadan
        // ikinci cevap beklenir; kullanıcıya net ipucu verilir.
        if (!answered && _firstAttemptAnswer.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Semantics(
              liveRegion: true,
              label: context.t(K.doubleAnswerHint),
              excludeSemantics: true,
              child: Text(
                context.t(K.doubleAnswerHint),
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        showRatingBar
            ? Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandDeep,
                        foregroundColor: AppColors.onSolid(AppTheme.brandDeep),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(3),
                      child: Text(
                        context.t(K.difficultyHard),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.playCyan,
                        foregroundColor: AppColors.onSolid(AppTheme.playCyan),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(4),
                      child: Text(
                        context.t(K.difficultyMedium),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.correct,
                        foregroundColor: AppColors.onSolid(AppTheme.correct),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(5),
                      child: Text(
                        context.t(K.difficultyEasy),
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            // Coach-mark hedefi (GlobalKey) dış sarmalayıcıda; sabit
            // 'quiz-next-button' anahtarı düğmenin üzerinde korunur.
            : KeyedSubtree(
                key: _nextButtonKey,
                child: FilledButton.icon(
                  key: const ValueKey('quiz-next-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brand,
                    foregroundColor: AppColors.onSolid(AppTheme.brand),
                    // Cevap beklenirken düğme Material'ın varsayılan gri
                    // levhasına düşüyordu: ekranın en büyük öğesi ölü bir
                    // gri blok oluyordu. Pasif hâl artık markanın kendi
                    // renginin soluk tonu — "henüz değil" diyor, "bozuk"
                    // demiyor (2026-07-27, canlı gezinti).
                    disabledBackgroundColor: AppTheme.brand.withValues(
                      alpha: 0.12,
                    ),
                    disabledForegroundColor: AppTheme.brand.withValues(
                      alpha: 0.55,
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isCompact ? AppSpacing.xs : AppSpacing.sm,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                    elevation: 0,
                  ),
                  onPressed: canPressNext ? () => _next() : null,
                  icon: Icon(
                    _isMultiplayer
                        ? AppIcons.hourglassStart
                        : isLastQuestion
                        ? AppIcons.flag
                        : AppIcons.arrowRight,
                  ),
                  label: Text(
                    _isMultiplayer &&
                            answered &&
                            _mpPhase != _MultiplayerPhase.reveal
                        ? context.t(K.waitingOpponent)
                        : isLastQuestion
                        ? context.t(K.finishAction)
                        : context.t(K.next),
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        // IntrinsicHeight + stretch: joker etiketi iki satıra sarabildiği
        // için (Kurmancî'de sarıyor) düğmeler farklı yükseklikte kalıyor ve
        // bar tırtıklı görünüyordu. Hepsi en uzunun boyuna çekilir.
        IntrinsicHeight(
          child: Row(
            key: _wildcardKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < jokers.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xxs),
                Expanded(child: _buildWildcardButton(jokers[i])),
              ],
            ],
          ),
        ),
        // Hiç coini olmayan yeni oyuncuya kilitler "her şey paralı" gibi
        // görünmesin: coinin nereden kazanılacağını tek satırla söyle.
        if (_coinBalance == 0 && index == 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.t(K.finishQuizHint),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppTheme.textMutedColor(context),
                fontWeight: FontWeight.w500,
              ),
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

  /// 148 = joker satırı (~44) + "Piştre" butonu (~52) + alt güvenli alan ve
  /// iç dolgu (~52). Bu değer aksiyon barı sabit yüksekliğine dayanır (M-2).
  static const double _kActionBarClearance = 148.0;
  static const EdgeInsets _quizSnackBarMargin = EdgeInsets.fromLTRB(
    AppSpacing.sm,
    0,
    AppSpacing.sm,
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
          backgroundColor: AppTheme.secondaryAccent,
          behavior: SnackBarBehavior.floating,
          margin: _quizSnackBarMargin,
          duration: const Duration(seconds: 2),
        ),
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
    widget.repository.spendCoins(cost, WildcardType.fiftyFifty.spendReason).catchError((
      error,
      stack,
    ) {
      ErrorReporter.record(error, stack, reason: 'spend_coins_fifty_fifty');
      return false;
    });
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
    widget.repository.spendCoins(cost, WildcardType.audience.spendReason).catchError((
      error,
      stack,
    ) {
      ErrorReporter.record(error, stack, reason: 'spend_coins_audience');
      return false;
    });
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
    widget.repository.spendCoins(cost, WildcardType.doubleAnswer.spendReason).catchError((
      error,
      stack,
    ) {
      ErrorReporter.record(error, stack, reason: 'spend_coins_double_answer');
      return false;
    });
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
    widget.repository.spendCoins(cost, WildcardType.changeQuestion.spendReason).catchError((
      error,
      stack,
    ) {
      ErrorReporter.record(error, stack, reason: 'spend_coins_change_question');
      return false;
    });
  }

  // ─── Soru paneli ─────────────────────────────────────────────────────────

  Widget _buildQuestionPanel(
    BuildContext context, {
    Size? layoutSize,
    bool? showExplanation,
    GlobalKey? timerKey,
    GlobalKey? answerAreaKey,
    GlobalKey? correctAnswerKey,
    VoidCallback? questionVisualReady,
    double? minHeight,
    double? availableHeight,
  }) {
    final promptText = question.promptText;
    // Yerleşim dalını seçen LayoutBuilder'ın gövde ölçüsünü kullan. Tam
    // pencereyi tekrar okumak, AppBar/SafeArea sınırında panelin görsel ve
    // tipografi kararını dış düzenden ayırabiliyordu.
    final size = layoutSize ?? MediaQuery.sizeOf(context);
    // Yerleşim dalıyla AYNI kural. Burada eskiden ayrı bir eşik duruyordu
    // (`width >= 700 && width > height`) ve dal seçimiyle çelişiyordu:
    // 1440×900 masaüstünde ikisi de "yatay" diyor, soru görseli gizleniyor ve
    // punto telefon ölçüsüne düşüyordu; 768×1024 dikey tablette ise dal iki
    // sütun seçerken tipografi masaüstü kalıyordu. Tek kaynak, tek doğru.
    final compactLandscape = _useCompactLandscapeLayout(
      size.width,
      size.height,
    );
    // Sıkışıklık kararı KARTA KALAN alandan verilir; ne cihaz ne de gövde
    // yüksekliğinden.
    //
    // Kusur 1: burada `size.height < 750` yazıyordu. 750 pencere yüksekliği
    // için seçilmiş bir sayıydı, ama ölçü kaynağı sonradan `MediaQuery`den
    // bu dalın `LayoutBuilder` gövdesine çevrildi (yerleşim dalıyla tipografi
    // çelişmesin diye) ve eşik olduğu yerde kaldı. Gövde; durum çubuğu,
    // başlık, ilerleme çubuğu ve alt güvenli alan düşüldükten sonra kalandır
    // — iPhone 17'de 874 değil ~741. Yani **her iPhone "dar ekran"
    // sayılıyordu**: şık dolgusu sabit `AppSpacing.xs`e düşüyor, punto küçük
    // kalıyordu. 2026-07-27'de "uzun ekranda şıklar büyüsün, ekran dolsun"
    // diye yazılan kademeli dolgu bu yüzden hiçbir telefonda çalışmadı ve
    // soru ekranındaki boşluk şikâyeti buradan geliyordu.
    //
    // Kusur 2: gövde yüksekliği iki modda AYNI, oysa karta kalan alan çok
    // farklı. Ders modunda kartın altında yalnız "Sonraki" var (~725pt
    // kalır); yarışma modunda skor başlığı, joker barı ve ipucu satırı da
    // var (~510pt kalır). Gövdeye bakan tek bir eşik ikisini ayıramaz:
    // yarışmada şıklar büyüyünce D şıkkı joker barının altında kalıyordu
    // (2026-08-16 simülatör taraması).
    //
    // Doğru ölçü, kartın gerçekten kullanabildiği yükseklik. 600: ders modu
    // (~725) geniş, yarışma modu (~510) ve iPhone SE dar sayılır.
    final isCompact = (availableHeight ?? size.height) < 600;

    // Soru metni + şıklar (+ açıklama payı) için kartın İÇİNDE kalan
    // yükseklik. Şıklar bu bütçeye göre boyutlanır; amaç her sorunun
    // şıklarıyla birlikte ekrana tam oturması (2026-08-16 kararı).
    //
    // Düşülenler: kartın alt/üst iç dolgusu, üstteki kategori/tip/sayaç
    // satırı ve onun altındaki boşluk. Kategori satırı 34pt'lik rozet
    // etrafında kurulu; 40 onu çiplerle birlikte kapsayan ölçüdür.
    final cardPadding = (isCompact ? 10.0 : 16.0) * 2;
    final headerBlock = 40.0 + (isCompact ? 8.0 : 14.0);
    final double? contentBudget = minHeight == null
        ? null
        : max(0.0, minHeight - cardPadding - headerBlock);

    final questionIcon = CategoryVisuals.icon(question.category);
    // Soru paneli kategori renk kimliğini taşır: hafif zemin tonu,
    // renkli kenarlık/parıltı ve kategori gradyanlı ikon rozeti.
    final catGradient = CategoryVisuals.gradient(question.category);
    final catColor = catGradient.colors.first;
    return Container(
      width: double.infinity,
      // Kart, altında kullanılmayan alan kaldığında oraya kadar uzar.
      //
      // Kusur: dikey düzende kart doğal boyunda kalıyor, "Sonraki" düğmesi
      // ekranın dibine sabitleniyordu ve arada kalan boşluk hiçbir şey
      // göstermiyordu. iPhone 17'de dört şıklı kısa bir soruda ölçülen
      // boşluk ~287pt — ekranın ÜÇTE BİRİ; cevaptan ve açıklama paneli
      // açıldıktan sonra bile ~200pt kalıyordu (2026-08-16 simülatör
      // taraması). Yani boşluk "açıklamaya ayrılmış alan" değildi.
      //
      // Kart yukarıdan başlamaya devam eder (ilerleme çubuğu → soru
      // ilişkisi korunur, düğme başparmak erimindeki yerinde kalır); yalnız
      // artan alan artık kartın İÇİNE düşer ve şıklar o alana yayılır.
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight),
      padding: EdgeInsets.all(isCompact ? 10 : 16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          catColor.withValues(alpha: 0.07),
          AppTheme.surfaceHiColor(context),
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: catColor.withValues(alpha: 0.30), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: -18,
            right: -12,
            child: IgnorePointer(
              child: Icon(
                key: const ValueKey('quiz-question-ghost-icon'),
                questionIcon,
                size: compactLandscape ? 88 : 112,
                color: catColor.withValues(
                  alpha: AppTheme.isLight(context) ? 0.08 : 0.11,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _QuizQuestionIconBadge(
                          icon: questionIcon,
                          gradient: catGradient,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _TinyTag(
                            label: CategoryNames.localized(
                              question.category,
                              context.isKu,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _TinyTag(
                            label: question.typeLabelLocalized(context.isKu),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sayaç yalnızca gerçekten işlediği modlarda gösterilir.
                  // Öğrenme akışında `_usesTimer` false'tur; rozet yine de
                  // çizildiğinde donmuş bir geri sayım görüntüsü veriyordu.
                  if (_usesTimer) ...[
                    const SizedBox(width: 8),
                    // Coach-mark hedefi (GlobalKey) dış sarmalayıcıda kalır ki
                    // sabit 'quiz-circular-timer' anahtarı widget üzerinde korunsun.
                    KeyedSubtree(
                      key: timerKey,
                      child: QuizTimerWidget(
                        key: const ValueKey('quiz-circular-timer'),
                        animation: _timerController,
                        // Gerçek kaynak room.secondsPerQuestion'dır; sabit 15
                        // lobi çipiyle (örn. 30 sn) çelişiyordu.
                        maxSeconds: widget.room.secondsPerQuestion,
                        isPaused: answered,
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: isCompact ? 8 : 14),
              if (compactLandscape && question.hasImage)
                Row(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuestionTextAndAnswers(
                        promptText: promptText,
                        promptFontSize: 20,
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
                        answerAreaKey: answerAreaKey,
                        correctAnswerKey: correctAnswerKey,
                        explanationKey: _explanationKey,
                        contentHeight: contentBudget,
                        reserveExplanation:
                            // Pay YALNIZ cevaptan sonra ayrılır. Baştan ayrılsaydı
                            // cevap verilmeden önce kartın altında açıklama boyunda
                            // bir boşluk dururdu; hedef ise her iki durumda da
                            // boşluksuz ve kaydırmasız bir ekran. Şık yükseklikleri
                            // `AnimatedContainer` ile değiştiği için geçiş sıçrama
                            // gibi değil, yer açılıyormuş gibi görünür.
                            _isLearningExperience &&
                            answered &&
                            contentBudget != null,
                        onAnswer: _answer,
                        onListen: _listenCurrentQuestion,
                        canListen: _ttsCanListen,
                      ),
                    ),
                  ],
                )
              else ...[
                if (question.hasImage) ...[
                  _QuestionImage(
                    url: question.imageUrl!,
                    alt: question.imageAltFor(isKu: context.isKu),
                    isCompact: isCompact,
                    layoutSize: size,
                    onReady: questionVisualReady,
                  ),
                  SizedBox(height: isCompact ? 8 : 14),
                ],
                _QuestionTextAndAnswers(
                  promptText: promptText,
                  promptFontSize: compactLandscape ? 21 : (isCompact ? 21 : 25),
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
                  answerAreaKey: answerAreaKey,
                  correctAnswerKey: correctAnswerKey,
                  explanationKey: _explanationKey,
                  contentHeight: contentBudget,
                  reserveExplanation:
                      // Pay YALNIZ cevaptan sonra ayrılır. Baştan ayrılsaydı
                      // cevap verilmeden önce kartın altında açıklama boyunda
                      // bir boşluk dururdu; hedef ise her iki durumda da
                      // boşluksuz ve kaydırmasız bir ekran. Şık yükseklikleri
                      // `AnimatedContainer` ile değiştiği için geçiş sıçrama
                      // gibi değil, yer açılıyormuş gibi görünür.
                      _isLearningExperience &&
                      answered &&
                      contentBudget != null,
                  onAnswer: _answer,
                  onListen: _listenCurrentQuestion,
                  canListen: _ttsCanListen,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
