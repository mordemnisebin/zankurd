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
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Center(
            child: SizedBox(
              width: contentWidth,
              child: Column(
                children: [
                  if (!_isLearningExperience) ...[
                    _buildScoreHeader(),
                    const SizedBox(height: 8),
                  ],
                  _buildProgressBar(context),
                  if (!_isLearningExperience) _buildComboRow(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const ValueKey('quiz-portrait-scroll'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Coach-mark GlobalKey'leri yalnız ilk soruda: panel
                          // AnimatedSwitcher içinde olduğundan geçiş sırasında
                          // eski ve yeni panel aynı anda yaşar; anahtar her
                          // soruda geçilirse duplicate-GlobalKey hatası oluşur.
                          // Eğitim turu zaten sadece ilk soruda gösterilir.
                          _buildQuestionSwitcher(
                            context,
                            showExplanation: showExpl,
                            timerKey: index == 0 ? _timerTargetKey : null,
                            answerAreaKey: index == 0 ? _answerAreaKey : null,
                            questionVisualReady: index == 0
                                ? _handleQuestionVisualReady
                                : null,
                          ),
                          if (selectedAnswer == 'TIMEOUT')
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
                          if (widget.is1v1 && screenHeight >= 800) ...[
                            const SizedBox(height: 8),
                            _LiveScoreboard(players: livePlayers),
                          ],
                        ],
                      ),
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

  // ─── Landscape layout ──────────────────────────────────────────────────

  Widget _buildLandscapeLayout() {
    // Portrait ile aynı kural: tur içi açıklama yalnız Öğrenme Bölgesi'nde.
    final showExpl = _isLearningExperience && _showExplanation;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
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
                        showExplanation: showExpl,
                        timerKey: index == 0 ? _timerTargetKey : null,
                        answerAreaKey: index == 0 ? _answerAreaKey : null,
                        questionVisualReady: index == 0
                            ? _handleQuestionVisualReady
                            : null,
                      ),
                      if (selectedAnswer == 'TIMEOUT')
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
                SizedBox(
                  width: 270,
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
              ],
            ),
          ),
        ),
      ),
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
      final myName = widget.room.id != null ? _myName : QuizStrings.you(_isKu);
      final player = livePlayers.firstWhere(
        (p) => _myId != null ? p.id == _myId : p.name == myName,
        orElse: () => Player(
          id: _myId,
          name: myName,
          score: score,
          state: '',
          streak: streak,
        ),
      );
      final opponent = livePlayers.firstWhere(
        (p) => _myId != null ? p.id != _myId : p.name != myName,
        orElse: () =>
            Player(name: QuizStrings.opponent(_isKu), score: 0, state: ''),
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
      label: context.s(
        'Pêşkeftin: kesk rast, sor şaş',
        'İlerleme: yeşil doğru, kırmızı yanlış',
      ),
      child: Tooltip(
        message: context.s(
          'Kesk = rast, sor = şaş',
          'Yeşil = doğru, kırmızı = yanlış',
        ),
        child: Row(
          key: const ValueKey('quiz-wildcard-row'),
          children: [
            for (var i = 0; i < total; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  height: i == index ? 8 : 6,
                  decoration: BoxDecoration(
                    color: i < answerRecords.length
                        ? (answerRecords[i].selectedAnswer ==
                                  answerRecords[i].correctAnswer
                              ? AppTheme.correct
                              : AppTheme.wrong)
                        : i == index
                        ? AppTheme.brand
                        : AppTheme.surfaceHiColor(context),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: AppTheme.brand.withValues(
                                alpha: 0.45,
                              ),
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
    bool? showExplanation,
    GlobalKey? timerKey,
    GlobalKey? answerAreaKey,
    VoidCallback? questionVisualReady,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
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
          showExplanation: showExplanation,
          timerKey: timerKey,
          answerAreaKey: answerAreaKey,
          questionVisualReady: questionVisualReady,
        ),
      ),
    );
  }

  Widget _buildActionControls() {
    final bool showRatingBar =
        widget.practice &&
        answered &&
        selectedAnswer == question.correctAnswer &&
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
        if (!_isLearningExperience) ...[
          _buildWildcardRow(),
          SizedBox(height: isCompact ? AppSpacing.xxs : AppSpacing.xs),
        ],
        // Çift Cevap ilk denemesi yanlışsa: reveal görüntüsü olmadan
        // ikinci şık beklenir; kullanıcıya net ipucu verilir.
        if (!answered && _firstAttemptAnswer.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              context.s(
                'Bersiva ducarî: şıkka din hilbijêre',
                'Çift cevap: bir şık daha seç',
              ),
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
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
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(3),
                      child: Text(
                        context.s('Zor', 'Zor'),
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
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(4),
                      child: Text(
                        context.s('Navîn', 'Orta'),
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
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      onPressed: () => _submitPracticeRating(5),
                      child: Text(
                        context.s('Hêsan', 'Kolay'),
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
                    foregroundColor: Colors.white,
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
                        ? context.s('Li benda hevrik...', 'Rakip bekleniyor...')
                        : isLastQuestion
                        ? context.s('Qediya', 'Bitir')
                        : context.s('Piştre', 'Sonraki'),
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
    final jokers = [
      WildcardType.fiftyFifty,
      WildcardType.audience,
      WildcardType.doubleAnswer,
      if (_isSoloMode) WildcardType.changeQuestion,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          key: _wildcardKey,
          children: [
            for (var i = 0; i < jokers.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xxs),
              Expanded(child: _buildWildcardButton(jokers[i])),
            ],
          ],
        ),
        // Hiç coini olmayan yeni oyuncuya kilitler "her şey paralı" gibi
        // görünmesin: coinin nereden kazanılacağını tek satırla söyle.
        if (_coinBalance == 0 && index == 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              context.s(
                'Quizê biqedîne, coin qezenc bike û jokeran veke',
                'Quizi bitir, coin kazan ve jokerleri aç',
              ),
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
      WildcardType.fiftyFifty => context.s(
        'Du bersivên şaş tên jêbirin',
        'İki yanlış şık kaldırılır',
      ),
      WildcardType.audience => context.s(
        'Temaşevan bersivan dinirxînin',
        'Seyirci oy dağılımını görürsün',
      ),
      WildcardType.doubleAnswer => context.s(
        'Hêlka du bersivan: carinan şaş jî qebûl e',
        'Çift cevap: ilk deneme yanlışsa bir hak daha',
      ),
      WildcardType.changeQuestion => context.s(
        'Pirs bi pirsa nû tê guhertin',
        'Soru yenisiyle değiştirilir',
      ),
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

  /// Aksiyon barı (joker satırı + "Piştre") ekranın altına sabitlendiği için
  /// yüzen SnackBar'lar varsayılan konumlarında birincil eylemi örter.
  /// Bu margin bildirimi barın üstüne kaldırır (2026-07-22 UX denetimi).
  static const EdgeInsets _quizSnackBarMargin = EdgeInsets.fromLTRB(
    12,
    0,
    12,
    148,
  );

  // ─── Joker mekanikleri ───────────────────────────────────────────────────

  Future<void> _trackWildcardMission() async {
    final store = await DailyMissionStore.load();
    final completed = await store.reportWildcardUsed();
    if (completed == null || !mounted) return;

    await widget.repository.claimMissionReward(
      missionKey: completed.missionKey,
      fallbackReward: completed.coinReward,
    );

    final xpStore = await XPStore.load();
    final leveledUp = await xpStore.addXP(100);
    try {
      await widget.repository.updateProfileXP(xpStore.totalXP);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz_queue_xp_sync');
      SyncManager.instance.queueXP(xpStore.totalXP);
    }

    if (!mounted) return;
    MissionToast.show(context, completed);
    if (leveledUp) {
      final isKu = context.isKu;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKu
                ? 'Asta Te Bilind Bû! Ast Nû: ${xpStore.currentLevel}'
                : 'Tebrikler, seviye atladın! Yeni Seviye: ${xpStore.currentLevel}',
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
    if (_wildcard.fiftyFiftyUsed || _coinBalance < cost || answered) return;
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
    widget.repository.spendCoins(cost, 'wildcard_fifty_fifty').catchError((
      error,
      stack,
    ) {
      ErrorReporter.record(error, stack, reason: 'spend_coins_fifty_fifty');
      return false;
    });
  }

  void _useAudience() {
    final cost = WildcardType.audience.coinCost;
    if (_wildcard.audienceUsed || _coinBalance < cost || answered) return;
    HapticFeedback.selectionClick();
    context.read<SoundProvider>().playWildcard();
    _trackWildcardMission();
    setState(() {
      _coinBalance -= cost;
      _wildcard = _wildcard.copyWith(audienceUsed: true);
      _audiencePoll = _buildAudiencePoll();
    });
    widget.repository.spendCoins(cost, 'wildcard_audience').catchError((
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
    if (_wildcard.doubleAnswerActivated ||
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
    widget.repository.spendCoins(cost, 'wildcard_double_answer').catchError((
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

    // Önce aynı kategori + zorlukta aday ara
    var candidates = widget.repository.questions
        .where(
          (q) =>
              q.category == category &&
              q.difficulty == difficulty &&
              !usedIds.contains(q.id),
        )
        .toList();

    // Yeterli yoksa aynı kategoride herhangi bir zorluk
    if (candidates.isEmpty) {
      candidates = widget.repository.questions
          .where((q) => q.category == category && !usedIds.contains(q.id))
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
      _questions[index] = replacement;
      hiddenAnswers = const {};
      _audiencePoll = null;
      favorite = false;
      _favoriteTouched = false;
    });
    _markQuestionSeen();
    _loadFavoriteState();
    _startTimer();
    widget.repository.spendCoins(cost, 'wildcard_change_question').catchError((
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
    bool? showExplanation,
    GlobalKey? timerKey,
    GlobalKey? answerAreaKey,
    VoidCallback? questionVisualReady,
  }) {
    final promptText = question.promptText;
    final size = MediaQuery.sizeOf(context);
    final compactLandscape = size.width >= 700 && size.width > size.height;
    final isCompact = size.height < 750;
    final questionIcon = CategoryVisuals.icon(question.category);
    // Soru paneli kategori renk kimliğini taşır: hafif zemin tonu,
    // renkli kenarlık/parıltı ve kategori gradyanlı ikon rozeti.
    final catGradient = CategoryVisuals.gradient(question.category);
    final catColor = catGradient.colors.first;
    return Container(
      width: double.infinity,
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
                        isCompact: isCompact,
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
                        answered: answered,
                        hiddenAnswers: hiddenAnswers,
                        firstAttemptAnswer: _firstAttemptAnswer,
                        audiencePoll: _audiencePoll,
                        showExplanation: showExplanation ?? _showExplanation,
                        suspense: _suspense,
                        opponentSelectedAnswers: _opponentSelectedAnswers,
                        isCompact: isCompact,
                        answerAreaKey: answerAreaKey,
                        onAnswer: _answer,
                      ),
                    ),
                  ],
                )
              else ...[
                if (question.hasImage) ...[
                  _QuestionImage(
                    url: question.imageUrl!,
                    isCompact: isCompact,
                    onReady: questionVisualReady,
                  ),
                  SizedBox(height: isCompact ? 8 : 14),
                ],
                _QuestionTextAndAnswers(
                  promptText: promptText,
                  promptFontSize: compactLandscape ? 21 : (isCompact ? 21 : 25),
                  question: question,
                  selectedAnswer: selectedAnswer,
                  answered: answered,
                  hiddenAnswers: hiddenAnswers,
                  firstAttemptAnswer: _firstAttemptAnswer,
                  audiencePoll: _audiencePoll,
                  showExplanation: showExplanation ?? _showExplanation,
                  suspense: _suspense,
                  opponentSelectedAnswers: _opponentSelectedAnswers,
                  isCompact: isCompact,
                  answerAreaKey: answerAreaKey,
                  onAnswer: _answer,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
