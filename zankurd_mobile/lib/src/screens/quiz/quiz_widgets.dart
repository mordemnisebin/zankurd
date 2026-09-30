part of '../quiz_screen.dart';

// ─── Şahnê parçaları (2026-09-29) ───────────────────────────────────────────
//
// Soru sahnesinin gövdesindeki bütün parçalar Şahnê belirteçleriyle
// çizilir: renk `SahneTokens` (sahne her zaman gece), şekil `SahneShape`
// (kesik köşe), yazı `SahneType`, aralık `SahneSpace`. Yuvarlak köşe,
// bulanık gölge ve palet dışı renk (mor, camgöbeği) kalmadı.

// ─── Canlı skor tablosu ──────────────────────────────────────────────────────

/// Düelloda canlı sıralama: yüzey kartı (Perde, L pah) + sıra satırları.
class _LiveScoreboard extends StatelessWidget {
  const _LiveScoreboard({required this.players});

  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final sortedPlayers = [...players]
      ..sort((a, b) => b.score.compareTo(a.score));
    final shown = sortedPlayers.take(4).toList();
    // 2026-07-23 M25b: aynı skor tablosunda hash çakışması varsa
    // round-robin ile çözülür (bkz. leaderboard_screen.dart ile aynı desen).
    final colorOverrides = resolveAvatarColors(
      shown.map(
        (p) =>
            (id: p.id ?? p.name, displayName: p.name, colorHex: p.avatarColor),
      ),
    );

    return SahneSurfaceCard(
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.x4,
        SahneSpace.x3,
        SahneSpace.x4,
        SahneSpace.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.chartColumn, size: 20, color: t.goldTx),
              const SizedBox(width: SahneSpace.x2),
              Expanded(
                child: Text(
                  context.t(K.liveScore),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x2),
          for (var i = 0; i < shown.length; i++)
            _LiveScoreRow(
              rank: i + 1,
              player: shown[i],
              colorOverride: colorOverrides[shown[i].id ?? shown[i].name],
            ),
        ],
      ),
    );
  }
}

class _LiveScoreRow extends StatelessWidget {
  const _LiveScoreRow({
    required this.rank,
    required this.player,
    this.colorOverride,
  });

  final int rank;
  final Player player;
  final Color? colorOverride;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x2),
      child: Row(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(color: t.s2, shape: SahneShape.s),
            child: SizedBox.square(
              dimension: 28,
              child: Center(
                child: Text(
                  '$rank',
                  style: SahneType.captionStrong.copyWith(
                    color: t.tx,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: SahneSpace.x2),
          PlayerAvatar(
            radius: 14,
            photoUrl: player.avatarUrl,
            iconId: player.avatarIcon,
            colorHex: player.avatarColor,
            frameId: player.avatarFrame,
            displayName: player.name,
            colorOverride: colorOverride,
          ),
          const SizedBox(width: SahneSpace.x2),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SahneType.bodyStrong.copyWith(color: t.tx),
            ),
          ),
          const SizedBox(width: SahneSpace.x2),
          Text(
            '${player.score}',
            style: SahneType.captionStrong.copyWith(
              color: t.goldTx,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Soru görseli ────────────────────────────────────────────────────────────

/// Soru görseli kartı, quiz kütüphanesinin dışından kullanılabilen yüzü.
///
/// 2026-09-29 doğallık (K2): seviye sınavı görselli soruyu ("Görselde
/// Newroz ateşi görünüyor…") görselsiz soruyordu; görsel yalnız sahnenin
/// arkasında %14'lük hayalet kategori çizimi olarak duruyordu ve sorunun
/// sözünü ettiği şey ekranda yoktu. Sınav artık quiz ekranıyla AYNI kartı
/// çizer: aynı yükseklik formülü, aynı pah, aynı alt metin ve aynı hata
/// yüzeyi. İkinci bir görsel kartı yazılmaz.
class QuizQuestionImage extends StatelessWidget {
  const QuizQuestionImage({super.key, required this.url, this.alt});

  final String url;
  final String? alt;

  @override
  Widget build(BuildContext context) => _QuestionImage(url: url, alt: alt);
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({
    required this.url,
    this.alt,
    this.isCompact = false,
    this.layoutSize,
    this.onReady,
  });

  final String url;

  /// Görselin ekran okuyucuya okunan betimlemesi.
  ///
  /// 2026-08-07'ye kadar soru görselleri hiçbir semantik etiket taşımıyordu:
  /// TalkBack/VoiceOver kullanan oyuncu için görsel yok sayılıyordu. Görselin
  /// süs olduğu sorularda bu bir eksiklik, görselin sorunun KENDİSİ olduğu
  /// sorularda ("görseldeki çalgı hangisidir?") soruyu çözülemez yapıyordu.
  ///
  /// `null` ise yerelleştirilmiş genel bir etiket kullanılır — sessiz
  /// kalmaktansa "soru görseli" demek yeğdir, çünkü ekran okuyucu en azından
  /// bir görselin var olduğunu duyurur.
  final String? alt;
  final bool isCompact;
  final Size? layoutSize;
  final VoidCallback? onReady;

  void _notifyReady() {
    final callback = onReady;
    if (callback == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = url.startsWith('asset://')
        ? url.replaceFirst('asset://', '')
        : null;
    final size = layoutSize ?? MediaQuery.sizeOf(context);
    final isLandscapeTablet = _useCompactLandscapeLayout(
      size.width,
      size.height,
    );
    final maxHeight = isLandscapeTablet
        ? (size.height * 0.24).clamp(84.0, 150.0)
        : double.infinity;

    final image = assetPath == null
        ? CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            // Kod çözme genişliği sınırlanmazsa görsel tam
            // çözünürlüğünde belleğe açılır: 2000 px genişliğinde bir
            // JPEG, ekranda 350 px görünse bile ~16 MB RGBA tutar. Soru
            // kartı hiçbir zaman 1080 px'ten geniş çizilmiyor
            // (2026-07-31 denetimi).
            memCacheWidth: 1080,
            placeholder: (context, url) => const _QuestionImagePlaceholder(),
            imageBuilder: (context, imageProvider) {
              _notifyReady();
              return Image(image: imageProvider, fit: BoxFit.contain);
            },
            // Görsel yüklenemezse de "hazır" sinyali verilmeli: aksi halde
            // soru akışını bekleten kapı hiç açılmaz ve ilk sorunun sayacı
            // hiç başlamaz (2026-07-25 canlı denetimi).
            errorWidget: (context, url, error) {
              _notifyReady();
              return const _QuestionImageFallback();
            },
          )
        : Image.asset(
            assetPath,
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) _notifyReady();
              return child;
            },
            errorBuilder: (context, error, stackTrace) {
              _notifyReady();
              return const _QuestionImageFallback();
            },
          );

    // Dar ekranda görsel için ayrılan tavan.
    //
    // Eskiden `%15 → en çok 100pt`ti ve iPhone SE'de (667pt) tam 100'e
    // oturuyordu. Ölçüldüğünde (2026-08-12, SE) aynı ekranda soru kartının
    // ALTINDA ~110pt kullanılmayan boşluk duruyordu: düzen, harcamadığı
    // yeri kısmak için görseli aç bırakıyordu. Bedeli somuttu — «kelaş»
    // sorusu ayakkabıyı sorar, görselde ayakkabı 90pt'lik bir karede
    // seçilemez; görselin sorunun KENDİSİ olduğu sorularda soru
    // cevaplanamaz hâle geliyordu.
    //
    // Tavan o ölçülen boşluğun içinde kalacak kadar açıldı; `BoxFit.contain`
    // korunduğu için görsel taşmaz, yalnız daha çok yer bulur.
    // Formül `quiz_layout_rules.dart`taki `questionImagePortraitHeight`te
    // yaşar — `_buildQuestionPanel` şık bütçesini AYNI sayıyla düşer.
    // Burada kopyalanırsa (eskiden öyleydi) ikisi ayrışabilir; tam da bu
    // yüzden D şıkkı ekranın altında kayboluyordu (bkz. o işlevin yorumu).
    final double? forcedHeight = isCompact
        ? questionImagePortraitHeight(size, isCompact: true)
        : null;
    final portraitHeight = questionImagePortraitHeight(size, isCompact: false);
    final label = (alt != null && alt!.trim().isNotEmpty)
        ? alt!.trim()
        : context.t(K.questionImage);

    return Semantics(
      image: true,
      label: label,
      // Alttaki `Image` widget'ları kendi (boş) semantiklerini üretiyor;
      // dışlanmazsa ekran okuyucu etiketi iki kez ya da eksik okur.
      excludeSemantics: true,
      // Şahnê: görsel L pahlı karede (kesik köşe), yuvarlak köşe yok.
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: SahneShape.l),
        child: (isLandscapeTablet || forcedHeight != null)
            ? SizedBox(
                width: double.infinity,
                height: forcedHeight ?? maxHeight,
                child: image,
              )
            : SizedBox(
                width: double.infinity,
                height: portraitHeight,
                child: image,
              ),
      ),
    );
  }
}

/// Görsel indirilirken gösterilen hafif yükleme yüzeyi (Kulis tonu).
class _QuestionImagePlaceholder extends StatelessWidget {
  const _QuestionImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ColoredBox(
      color: t.s2,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: t.tx2),
        ),
      ),
    );
  }
}

/// Görsel yüklenemediğinde gösterilen standart geri dönüş yüzeyi:
/// ikon + kısa mesaj (Kulis tonu); boş gri kutu yerine anlamlı bir yüzey.
class _QuestionImageFallback extends StatelessWidget {
  const _QuestionImageFallback();

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ColoredBox(
      color: t.s2,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.image, color: t.tx2, size: 32),
            const SizedBox(height: SahneSpace.x2),
            Text(
              context.t(K.imageLoadFailed),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soru metni + cevap alanı (şıklar, boşluk doldurma, kelime sıralama) +
/// öğrenme notu.
///
/// ## Soru metninin boyu (Şahnê)
///
/// Soru Başlık 28/32'dir; dört satırı aşarsa Manşet 22/28'e iner — ölçerek,
/// karakter sayarak değil (bkz. [QuizQuestionPrompt]).
///
/// ## Şıklar doğal boylarında
///
/// Şık çubuğu en az 52'dir ve içerikle büyür; kalan alanı doldurmak için
/// şişirilmez. Şahnê'de soru ile şıkların altında kalan yer boş bir karta
/// değil sahneye (zemin çizimi, huzme, ufuk) açılır.
class _QuestionTextAndAnswers extends StatelessWidget {
  const _QuestionTextAndAnswers({
    required this.promptText,
    required this.question,
    required this.selectedAnswer,
    required this.adjudicatedCorrect,
    required this.answered,
    required this.hiddenAnswers,
    required this.firstAttemptAnswer,
    required this.showExplanation,
    required this.suspense,
    required this.onAnswer,
    this.forceHeadline = false,
    this.audiencePoll,
    this.opponentSelectedAnswers,
    this.isCompact = false,
    this.twoColumn = false,
    this.answerAreaKey,
    this.correctAnswerKey,
    this.explanationKey,
    this.explanationActionKey,
    this.onListen,
    this.canListen = false,
    this.listeningListenable,
  });

  final String promptText;
  final QuizQuestion question;
  final String selectedAnswer;
  final bool? adjudicatedCorrect;
  final bool answered;
  final Set<String> hiddenAnswers;
  final String firstAttemptAnswer;
  final Map<String, double>? audiencePoll;
  final bool showExplanation;
  final Map<String, _OpponentAnswer>? opponentSelectedAnswers;
  final bool isCompact;

  /// Telefon-yatay: soru hep Manşet 22; dört şık genişse iki sütun.
  final bool forceHeadline;
  final bool twoColumn;

  /// Quiz turu için cevap alanını hedef gösteren GlobalKey.
  final GlobalKey? answerAreaKey;

  /// Doğru şıkkın çubuğuna takılan GlobalKey. Cevap açıklandıktan sonra
  /// quiz ekranı bu çubuğu görünür alana kaydırır: uzun şıklarda doğru
  /// cevap ekranın altında kalıyor ve kullanıcı yanlış yaptığında
  /// doğrusunu hiç göremiyordu (2026-07-25 canlı denetimi).
  final GlobalKey? correctAnswerKey;

  /// Doğru cevap yedek kutusuna takılan GlobalKey. Kutu belirdikten sonra
  /// quiz ekranı onu görünür alana kaydırır; üç satırlık sorularda kutu sabit
  /// "Sonraki" düğmesinin arkasında kalıyordu (2026-08-16).
  final GlobalKey? explanationKey;

  /// "Açıklamayı gör" satırının kaydırma hedefi (bkz.
  /// `_QuizScreenState._revealExplanation`).
  final GlobalKey? explanationActionKey;

  /// Gerilim tutuşu: cevap seçildi ama sonuç henüz açıklanmadı.
  /// True iken doğru/yanlış renkleri gizlenir; seçilen şık "kontrol
  /// ediliyor" hâlinde bekler.
  final bool suspense;
  final ValueChanged<String> onAnswer;

  /// Soru metnini seslendirmek için isteğe bağlı callback.
  final VoidCallback? onListen;

  /// TTS cihazda Kürtçe destekliyor mu? False ise buton gizlenir.
  final bool canListen;

  /// Doğrulanmış kayıt veya TTS oynatma durumunu tek kaynaktan izler.
  final ValueListenable<bool>? listeningListenable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outer) {
        final showListen =
            canListen && onListen != null && listeningListenable != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dinleme düğmesi (48) soru metninin yanında durur; boy
                // kararı metne kalan genişlikte ölçülür.
                Expanded(
                  child: QuizQuestionPrompt(
                    promptText,
                    forceHeadline: forceHeadline,
                  ),
                ),
                if (showListen) ...[
                  const SizedBox(width: SahneSpace.x2),
                  _ListenButton(
                    onTap: onListen!,
                    listeningListenable: listeningListenable!,
                  ),
                ],
              ],
            ),
            SizedBox(height: isCompact ? SahneSpace.x3 : SahneSpace.x4),
            Container(key: answerAreaKey, child: _answerArea(context)),
            _AnswerRevealFallback(
              question: question,
              isKu: context.isKu,
              visible:
                  showExplanation && needsAnswerRevealFallback(question.type),
              revealKey: showExplanation ? explanationKey : null,
            ),
            if (showExplanation && answered)
              _LearningExplanationAction(
                key: explanationActionKey,
                question: question,
              ),
          ],
        );
      },
    );
  }

  Widget _answerArea(BuildContext context) {
    if (question.type == QuestionType.fillInBlank) {
      return FillInBlankWidget(
        key: ValueKey('fill-in-blank-${question.id}'),
        question: question,
        disabled: answered,
        showResult: answered && !suspense,
        adjudicatedCorrect: adjudicatedCorrect,
        excludedAnswer: firstAttemptAnswer.isEmpty ? null : firstAttemptAnswer,
        selectedAnswer: selectedAnswer.isEmpty ? null : selectedAnswer,
        onAnswerSubmitted: onAnswer,
      );
    }

    if (question.type == QuestionType.wordOrdering) {
      return WordOrderingWidget(
        // Soru kimliği key'e girer: aynı tipte bir sonraki soruya
        // geçildiğinde State yeniden kullanılıp önceki kelimeler ekranda
        // kalmasın.
        key: ValueKey('word-ordering-${question.id}'),
        question: question,
        disabled: answered,
        selectedAnswer: selectedAnswer,
        onAnswerSubmitted: onAnswer,
      );
    }

    final answers = question.displayAnswers;
    const gap = SahneSpace.x2;

    Widget item(int index, String answer) {
      final hidden = hiddenAnswers.contains(answer);
      return Padding(
        // Anahtar yalnız cevap verilmiş sorunun doğru şıkkına takılır.
        // [AnimatedSwitcher] geçiş boyunca eski ve yeni paneli birlikte
        // yaşatır; `answered` koşulu olmadan iki panelde aynı GlobalKey
        // bulunur. Gelen soruda `answered` daima false olduğu için çakışma
        // olmaz.
        key: answered && answer == question.correctAnswer
            ? correctAnswerKey
            : null,
        padding: const EdgeInsets.only(bottom: gap),
        // 50/50 ile elenen şık: sönük (Perde + üçüncül metin) ve
        // dokunulmaz. Opaklık değil ton — Şahnê'nin pasif hâli.
        child: IgnorePointer(
          ignoring: hidden,
          child: _buildAnswerButton(index, answer, eliminated: hidden),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, area) {
        final useTwoColumns =
            twoColumn && area.maxWidth >= 520 && answers.length == 4;
        if (!useTwoColumns) {
          return _QuizAnswerBoard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (index, answer) in answers.indexed)
                  item(index, answer),
              ],
            ),
          );
        }
        final itemWidth = (area.maxWidth - gap) / 2;
        return _QuizAnswerBoard(
          child: Wrap(
            spacing: gap,
            children: [
              for (final (index, answer) in answers.indexed)
                SizedBox(width: itemWidth, child: item(index, answer)),
            ],
          ),
        );
      },
    );
  }

  /// Tek bir şık çubuğu üretir; gerilim tutuşu sırasında doğru/yanlış
  /// renkleri gizler, yanlış açıklanan şıkkı sarsıntıyla sarar.
  Widget _buildAnswerButton(
    int index,
    String answer, {
    bool eliminated = false,
  }) {
    final revealed = answered && !suspense;
    final List<String> opps = [];
    if (revealed && opponentSelectedAnswers != null) {
      opponentSelectedAnswers!.forEach((_, selection) {
        if (selection.answer == answer) {
          opps.add(selection.name);
        }
      });
    }

    final button = QuizOptionTile(
      index: index,
      answer: answer,
      selected: selectedAnswer == answer,
      correct: revealed && answer == question.correctAnswer,
      disabled: answered || answer == firstAttemptAnswer || eliminated,
      firstAttemptWrong: !answered && answer == firstAttemptAnswer,
      suspense: suspense,
      audiencePercent: audiencePoll?[answer],
      opponentNamesWhoSelected: opps,
      isCompact: isCompact,
      optionCount: question.displayAnswers.length,
      // Açıklanmada renk yalnız anlam taşır: doğru Rast, seçilen yanlış
      // Şaş; geri kalan şıklar söner.
      dimmed:
          eliminated ||
          (revealed &&
              answer != question.correctAnswer &&
              selectedAnswer != answer),
      onTap: () => onAnswer(answer),
    );
    final isWrongSelected =
        revealed &&
        answer == selectedAnswer &&
        answer != question.correctAnswer;
    if (isWrongSelected) {
      return ShakeWrapper(trigger: 1, child: button);
    }
    return button;
  }
}

/// Öğrenme notu — cevaptan sonra açıklamaya giden kapı (Zimrût ton zemini,
/// L pah, kitap ikonu; maketteki `.sh-note`).
///
/// Açıklama metni TUR SIRASINDA açılmaz: uygulama sahibinin kuralı
/// (2026-07-26) — şık işaretlenir işaretlenmez bir paragraf açılınca tur
/// duruyordu; açıklamaların tamamı sonuç ekranında bir arada gelir
/// (bkz. `lesson_explanation_test`). Not yalnız kapıdır: oyuncu isterse
/// tek dokunuşla alttan okur.
class _LearningExplanationAction extends StatelessWidget {
  const _LearningExplanationAction({super.key, required this.question});

  final QuizQuestion question;

  void _open(BuildContext context, String explanation) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      // Ku modda engel-kapatma etiketi Türkçe Material varsayılanından
      // ("Kapat") gelmesin diye açıkça yerelleştirildi (2026-09-25 web turu).
      barrierLabel: context.t(K.close),
      builder: (sheetContext) {
        final t = SahneTokens.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SahneSpace.page,
              SahneSpace.x1,
              SahneSpace.page,
              SahneSpace.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.bookOpen, color: t.learnTx, size: 24),
                    const SizedBox(width: SahneSpace.x2),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          sheetContext.t(K.explanationTitle),
                          style: SahneType.headline.copyWith(color: t.tx),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SahneSpace.x3),
                Text(explanation, style: SahneType.body.copyWith(color: t.tx)),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final explanation = question.getLocalizedExplanation(context.isKu).trim();
    if (explanation.isEmpty) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final label = context.t(K.viewExplanation);

    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x2),
      child: Semantics(
        button: true,
        label: label,
        onTap: () => _open(context, explanation),
        excludeSemantics: true,
        child: SahneTappable(
          key: const ValueKey('quiz-view-explanation'),
          shape: SahneShape.l,
          color: t.learnTint,
          onTap: () => _open(context, explanation),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SahneSpace.x3,
              SahneSpace.x3,
              SahneSpace.x3,
              SahneSpace.x3,
            ),
            child: Row(
              children: [
                Icon(AppIcons.bookOpen, color: t.learnTx, size: 24),
                const SizedBox(width: SahneSpace.x3),
                Expanded(
                  child: Text(
                    label,
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                ),
                const SizedBox(width: SahneSpace.x2),
                Icon(AppIcons.chevronRight, color: t.learnTx, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Düello kartı ────────────────────────────────────────────────────────────

/// İki oyuncu yan yana: avatar + ad + puan, ortada tur ve "VS", altında
/// halat çekme çubuğu ve seriler. Yüzey kartı (Perde, L pah).
class _DuelScoreHeader extends StatelessWidget {
  const _DuelScoreHeader({
    required this.player,
    required this.opponent,
    required this.progress,
  });

  final Player player;
  final Player opponent;
  final String progress;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // 2026-07-23 M25b: sadece 2 oyuncu olsa da hash çakışması mümkün
    // (iki isim aynı palet dilimine düşebilir) — aynı desenle çözülür.
    final colorOverrides = resolveAvatarColors([
      (
        id: player.id ?? player.name,
        displayName: player.name,
        colorHex: player.avatarColor,
      ),
      (
        id: opponent.id ?? opponent.name,
        displayName: opponent.name,
        colorHex: opponent.avatarColor,
      ),
    ]);
    final playerColor = colorOverrides[player.id ?? player.name];
    final opponentColor = colorOverrides[opponent.id ?? opponent.name];

    // Avatarlar ayrı ayrı kurulur (oyuncu ve rakibin kendi kimliği;
    // `supabase_repository_test` avatar alanlarının ikisini de arar).
    final playerAvatar = PlayerAvatar(
      radius: 16,
      photoUrl: player.avatarUrl,
      iconId: player.avatarIcon,
      colorHex: player.avatarColor,
      frameId: player.avatarFrame,
      displayName: player.name,
      colorOverride: playerColor,
    );
    final opponentAvatar = PlayerAvatar(
      radius: 16,
      photoUrl: opponent.avatarUrl,
      iconId: opponent.avatarIcon,
      colorHex: opponent.avatarColor,
      frameId: opponent.avatarFrame,
      displayName: opponent.name,
      colorOverride: opponentColor,
    );

    Widget side(Player p, Widget avatar, {required bool end}) {
      final info = Expanded(
        child: Column(
          crossAxisAlignment: end
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SahneType.captionStrong.copyWith(color: t.tx),
            ),
            Text(
              '${p.score} pts',
              style: SahneType.captionStrong.copyWith(
                color: t.goldTx,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
      return Expanded(
        child: Row(
          children: end
              ? [info, const SizedBox(width: SahneSpace.x2), avatar]
              : [avatar, const SizedBox(width: SahneSpace.x2), info],
        ),
      );
    }

    Widget streakOf(Player p, {required bool end}) {
      if (p.streak <= 0) return const SizedBox.shrink();
      const glyph = SahneGlyph(SahneGlyphKind.flame, size: 16);
      final label = Text(
        'x${p.streak}',
        style: SahneType.captionStrong.copyWith(color: t.goldTx),
      );
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: end
            ? [label, const SizedBox(width: SahneSpace.x1), glyph]
            : [glyph, const SizedBox(width: SahneSpace.x1), label],
      );
    }

    return SahneSurfaceCard(
      padding: const EdgeInsets.all(SahneSpace.x3),
      child: Column(
        children: [
          Row(
            children: [
              side(player, playerAvatar, end: false),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
                child: Column(
                  children: [
                    Text(
                      progress,
                      style: SahneType.captionStrong.copyWith(
                        color: t.tx2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'VS',
                      style: SahneType.eyebrow.copyWith(color: t.raceTx),
                    ),
                  ],
                ),
              ),
              side(opponent, opponentAvatar, end: true),
            ],
          ),
          // Halat çekme: puan FARKI okunmadan görülsün. Rakip puan
          // aldığında sınır KAYAR — rakibin varlığı hareketle hissedilir.
          const SizedBox(height: SahneSpace.x3),
          _DuelTugBar(playerScore: player.score, opponentScore: opponent.score),
          if (player.streak > 0 || opponent.streak > 0) ...[
            const SizedBox(height: SahneSpace.x2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                streakOf(player, end: false),
                streakOf(opponent, end: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Cevaptan hemen sonra **yalnız doğru cevabı** gösteren kutu.
///
/// Burada bir zamanlar açıklama metni de duruyordu. Uygulama sahibinin
/// tekrarlanan geri bildirimi (2026-07-26): şık işaretlenir işaretlenmez
/// altında bir paragraf açılıyor, tur duruyor ve okuma yükü akışı kesiyordu.
/// Karar net: tur sırasında yalnız doğru cevap görünür; açıklamaların
/// tamamı sorular bittikten sonra sonuç ekranında bir arada gelir
/// (bkz. `_AllExplanationsCard`).
///
/// Şablon/boş açıklamada kutu yine hiç açılmaz.
/// Bu soru türünde doğru cevabı açan YEDEK bir kutu gerekir mi?
///
/// Türlerin çoğu cevabı kendi gösterir ve yedek gereksizdir:
///
/// * çoktan seçmeli / doğru-yanlış / görsel — doğru şık yeşile döner ve
///   üzerine tik gelir, seçilen yanlış şık kırmızıya döner ve çarpı alır;
/// * boşluk doldurma — bileşen sonucun altına "Doğru cevap: X" yazar.
///
/// Kelime sıralama göstermez: cevap verilince girdi kilitlenir ve doğru
/// dizilim hiçbir yerde görünmez. Yedek kutu yalnız orada çizilir.
///
/// `switch` TÜKENMİŞ yazılır, `default` ya da `!=` zinciriyle değil.
/// Gerekçe: enum'a yeni bir soru türü eklendiğinde analizör burada
/// derlemeyi durdurur ve ekleyeni "bu tür cevabını kendi gösteriyor mu?"
/// sorusuna cevap vermeye zorlar. Varsayılanı olan bir ifade, yeni türü
/// sessizce bir tarafa atardı — `de45f05` sonrası tam olarak bu oldu ve
/// 15 soru geri bildirimsiz kaldı; hepsi topluluk bankasındaydı, ekran
/// turu onları basmıyor, kimse görmedi.
bool needsAnswerRevealFallback(QuestionType type) => switch (type) {
  QuestionType.multipleChoice ||
  QuestionType.trueFalse ||
  QuestionType.visual ||
  QuestionType.fillInBlank => false,
  QuestionType.wordOrdering => true,
};

/// Doğru cevabı, cevap alanı onu göstermiyorsa gösteren YEDEK not.
///
/// ## Niçin çoğu soruda artık görünmüyor
///
/// Kutu bir zamanlar açıklama METNİNİ basıyordu. Açıklamalar 2026-07-26'da
/// tur sonuna alındı (bkz. `lesson_explanation_test`) ve metin kaldırıldı;
/// geriye doğru cevabı TEKRAR eden bir kabuk kaldı. Çoktan seçmelide
/// oyuncu zaten Rast şıkkı ve üzerindeki ✓'yi görüyor (2026-08-19,
/// uygulama sahibinin bildirimi).
///
/// Not SİLİNMEDİ çünkü kelime sıralama sorularında doğru dizilimi açan
/// tek yer burası; silinseydi o türde oyuncu yanlış yaptığında doğrusunu
/// hiç göremezdi.
///
/// Şahnê: Rast ton zemini, L pah, ✓ + "Doğru cevap" etiketi + cevap.
class _AnswerRevealFallback extends StatelessWidget {
  const _AnswerRevealFallback({
    required this.question,
    required this.isKu,
    required this.visible,
    this.revealKey,
  });

  final QuizQuestion question;
  final bool isKu;
  final bool visible;

  /// Kutuyu görünür alana getirmek için kullanılan çapa
  /// (bkz. `_QuizScreenState._revealExplanation`). Yalnız kutu GÖRÜNÜRKEN
  /// takılır: `AnimatedSwitcher` geçiş boyunca eski ve yeni paneli birlikte
  /// yaşatır ve koşulsuz takılan bir `GlobalKey` duplicate hatası verirdi.
  final GlobalKey? revealKey;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final reduceMotion = sahneMotionReduced(context);
    return AnimatedSize(
      key: revealKey,
      duration: reduceMotion ? Duration.zero : SahneMotion.answerReveal,
      curve: Curves.easeOutCubic,
      child: visible
          ? Padding(
              padding: const EdgeInsets.only(top: SahneSpace.x2),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.okTint,
                  shape: SahneShape.l,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SahneSpace.x3,
                    SahneSpace.x3,
                    SahneSpace.x4,
                    SahneSpace.x3,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(AppIcons.check, color: t.okTx, size: 24),
                      const SizedBox(width: SahneSpace.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Tr.forKu(K.correctAnswerLabel, isKu),
                              style: SahneType.captionStrong.copyWith(
                                color: t.okTx,
                              ),
                            ),
                            const SizedBox(height: SahneSpace.x1),
                            Text(
                              question.correctAnswer,
                              style: SahneType.bodyStrong.copyWith(color: t.tx),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

/// Çok oyunculuda cevap kaydedildi, öteki oyuncu bekleniyor.
class _MultiplayerWaitingOverlay extends StatelessWidget {
  const _MultiplayerWaitingOverlay({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x3),
      child: SahneSurfaceCard(
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: t.tx2),
            ),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Tr.forKu(K.cevabinKaydedildi, isKu),
                    style: SahneType.bodyStrong.copyWith(color: t.tx),
                  ),
                  Text(
                    Tr.forKu(K.digerOyuncuBekleniyor, isKu),
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SahneSpace.x2),
            Icon(AppIcons.hourglassStart, color: t.tx2, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Reveal Countdown ──────────────────────────────────────────────────────

/// "Sonraki soru N sn" — Kulis tonlu M pahlı çip, ortada.
class _RevealCountdown extends StatelessWidget {
  const _RevealCountdown({required this.seconds, required this.isKu});

  final int seconds;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x3),
      child: Center(
        child: DecoratedBox(
          decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x3,
              vertical: SahneSpace.x2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.forward, color: t.tx2, size: 16),
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    Tr.forKu(K.sonrakiSoruPS, isKu, {'p0': '$seconds'}),
                    style: SahneType.captionStrong.copyWith(color: t.tx2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Turnuva maçı bandı: tur + rakip bilgisi (salt görüntü). Zêr kupa +
/// açıklama; hap biçimli şerit yok.
class _VersusBanner extends StatelessWidget {
  const _VersusBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      children: [
        Icon(AppIcons.trophy, size: 16, color: t.goldTx),
        const SizedBox(width: SahneSpace.x2),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SahneType.captionStrong.copyWith(color: t.tx2),
          ),
        ),
      ],
    );
  }
}

/// Soru sesini oynatan düğme (48'lik dokunma kutusu, 24'lük ikon).
/// Doğrulanmış kayıt veya TTS oynatma durumunu [listeningListenable]
/// üzerinden izler; çalarken ikon Zêr.
class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.onTap, required this.listeningListenable});

  final VoidCallback onTap;
  final ValueListenable<bool> listeningListenable;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: listeningListenable,
      builder: (context, isListening, _) {
        final actionLabel = isListening
            ? context.t(K.stopAction)
            : context.t(K.listenQuestion);
        return Semantics(
          button: true,
          enabled: true,
          label: actionLabel,
          hint: actionLabel,
          onTap: onTap,
          excludeSemantics: true,
          child: Tooltip(
            message: actionLabel,
            child: SahneTappable(
              shape: SahneShape.m,
              color: t.s1,
              onTap: onTap,
              child: SizedBox.square(
                dimension: 48,
                child: Icon(
                  isListening ? AppIcons.volumeXmark : AppIcons.volumeHigh,
                  size: 24,
                  color: isListening ? t.goldTx : t.tx,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 1v1 online eşleşmede karşı taraf henüz bu ekrana ulaşmadığında
/// gösterilir; soru sayacının erken başlamasını görsel olarak da
/// engeller (dokunuşları yutar). Sahnenin zemin rengiyle örtü (%92).
class _OpponentWaitingOverlay extends StatelessWidget {
  const _OpponentWaitingOverlay({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Positioned.fill(
      child: AbsorbPointer(
        child: ColoredBox(
          color: t.bg.withValues(alpha: 0.92),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: t.gold),
                const SizedBox(height: SahneSpace.x4),
                Text(
                  Tr.forKu(K.rakipBekleniyor, isKu),
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kaybedenin payı hiç sıfırlanmaz.
///
/// Ham oran kullanılsaydı 0-0'da çubuk tanımsız, ezici galibiyette ise
/// TEK renk olurdu; tek renkli çubuk "rakip yok" diye okunur ve tam da
/// göstermek istediği şeyi siler. Uçlarda ince bir şerit bırakmak
/// "eziliyorsun" ile "yalnızsın" arasındaki farkı korur.
const double duelTugFloor = 0.08;

/// Halat çekme çubuğunda oyuncunun payı (0..1).
///
/// Ayrı bir işlev: kural (uçlarda taban, berabere başlangıçta orta)
/// çizimden bağımsız olarak denetlenebilsin.
double duelTugShare(int playerScore, int opponentScore) {
  final total = playerScore + opponentScore;
  if (total <= 0) return 0.5;
  return (playerScore / total).clamp(duelTugFloor, 1 - duelTugFloor);
}

/// Düelloda öndeliği gösteren halat çekme çubuğu (8 px, S pah).
///
/// Oyuncu Zêr (skor ailesi), rakip Boyax (yarış ailesi): iki rol, iki
/// taraf. Sınır puan payına göre kayar; ortadaki çentik başabaş çizgisidir
/// — onun solunda kalırsan gerisin, sağında kalırsan öndesin.
class _DuelTugBar extends StatelessWidget {
  const _DuelTugBar({required this.playerScore, required this.opponentScore});

  final int playerScore;
  final int opponentScore;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final share = duelTugShare(playerScore, opponentScore);
    final reduceMotion = sahneMotionReduced(context);

    return SizedBox(
      key: const ValueKey('duel-tug-bar'),
      height: 12,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: const ShapeBorderClipper(shape: SahneShape.s),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: share),
              duration: reduceMotion ? Duration.zero : SahneMotion.scoreFlight,
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Row(
                children: [
                  Expanded(
                    flex: (value * 1000).round(),
                    child: ColoredBox(
                      color: t.gold,
                      child: const SizedBox(height: 8),
                    ),
                  ),
                  Expanded(
                    flex: ((1 - value) * 1000).round(),
                    child: ColoredBox(
                      color: t.race,
                      child: const SizedBox(height: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Başabaş çentiği.
          SizedBox(width: 2, height: 12, child: ColoredBox(color: t.tx)),
        ],
      ),
    );
  }
}

/// Şıkların oturduğu tahta: yalnız bir kimlik çapası, arkasında desen yok.
///
/// 2026-09-10'dan 2026-09-27'ye kadar burada şıkların ARKASINA altın bir
/// kilim baklava dokusu örülüyordu; cevaptan sonra sönen şıkların içinden
/// görünüp okumayı zorlaştırıyordu. Şahnê'de kilim yalnız göz şerididir
/// (sahne kartı üst kenarı, sonuç puanı). Bekçisi: `quiz_accent_test`.
class _QuizAnswerBoard extends StatelessWidget {
  const _QuizAnswerBoard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: const ValueKey('quiz-answer-board'), child: child);
  }
}

/// Joker dizisinin üstündeki jeton satırı: Zêr jeton glifi + bakiye, ve
/// bakiye sıfırken jetonun nereden kazanılacağı.
///
/// Jokerler adlarını değil fiyatlarını gösterir; oyuncunun hangisini
/// alabileceğini bilmesi için bakiye aynı bakışta görünmeli. Ekran
/// okuyucu "120 jeton" okur.
class _CoinBalanceLine extends StatelessWidget {
  const _CoinBalanceLine({
    required this.balance,
    this.hint,
    this.showHint = true,
  });

  final int balance;
  final String? hint;

  /// İpucu ekranda mı? `false` ise yalnız ekran okuyucuya gider.
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      label:
          '$balance ${context.t(K.coinWord)}${hint == null ? '' : '. $hint'}',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SahneGlyph(SahneGlyphKind.coin, size: 16),
          const SizedBox(width: SahneSpace.x1),
          Text(
            '$balance',
            style: SahneType.captionStrong.copyWith(
              color: t.goldTx,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (hint != null && showHint) ...[
            const SizedBox(width: SahneSpace.x2),
            Flexible(
              child: Text(
                hint!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
