part of '../quiz_screen.dart';

// ─── Şahnê parçaları (2026-09-29) ───────────────────────────────────────────
//
// Soru sahnesinin gövdesindeki bütün parçalar Şahnê belirteçleriyle
// çizilir: renk `SahneTokens` (sahne her zaman gece), şekil `SahneShape`
// (kesik köşe), yazı `SahneType`, aralık `SahneSpace`. Yuvarlak köşe,
// bulanık gölge ve palet dışı renk (mor, camgöbeği) kalmadı.

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
  const QuizQuestionImage({
    super.key,
    required this.url,
    this.alt,
    this.questionId,
  });

  final String url;
  final String? questionId;
  final String? alt;

  @override
  Widget build(BuildContext context) =>
      _QuestionImage(url: url, alt: alt, questionId: questionId);
}

/// Soru görselinin kod çözme genişliği tavanı (bkz. `_QuestionImage`).
const int _questionImageMemCacheWidth = 1080;

/// `_QuestionImage`'ın çizdiği görselle AYNI önbellek anahtarını veren
/// sağlayıcı: sıradaki sorunun görseli önceden yüklenirken
/// (`_precacheNextQuestionVisual`) çizimde yeniden indirilmesin.
ImageProvider _questionImageProvider(String url) {
  if (url.startsWith('asset://')) {
    return AssetImage(url.replaceFirst('asset://', ''));
  }
  return ResizeImage.resizeIfNeeded(
    _questionImageMemCacheWidth,
    null,
    CachedNetworkImageProvider(url),
  );
}

class _QuestionImage extends StatelessWidget {
  const _QuestionImage({
    super.key,
    required this.url,
    this.questionId,
    this.alt,
    this.isCompact = false,
    this.layoutSize,
    this.onReady,
  });

  final String url;

  /// Görselin ait olduğu soru: tam ekran görünüm soru değişince kapanır
  /// (aynı görseli kullanan iki soru arka arkaya gelse bile).
  final String? questionId;

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
            memCacheWidth: _questionImageMemCacheWidth,
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
            // Uzak görselle aynı çözme sınırı (Codex denetimi 2026-10-29).
            cacheWidth: _questionImageMemCacheWidth,
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

    // Kurul C18 (Astra + Sol, 2026-10-29): görselin sorunun kendisi olduğu
    // sorularda küçük karedeki ayrıntı seçilemiyordu; dokununca tam ekran,
    // yakınlaştırılabilir görünüm açılır (Duolingo/Quizlet deseni).
    return _ZoomableQuestionImage(
      url: url,
      questionId: questionId,
      label: label,
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

/// Dokununca tam ekran açılan soru görseli. Açık görünüm görselin ait olduğu
/// SORUYA bağlıdır (Astra incelemesi): süre dolup soru değişince, görsel
/// değişince ya da ekran kapanınca kendiliğinden kapanır; eski görsel yeni
/// soruyu ve işleyen sayacı örtmez.
class _ZoomableQuestionImage extends StatefulWidget {
  const _ZoomableQuestionImage({
    required this.url,
    required this.label,
    required this.child,
    this.questionId,
  });

  final String url;
  final String? questionId;
  final String label;
  final Widget child;

  @override
  State<_ZoomableQuestionImage> createState() => _ZoomableQuestionImageState();
}

class _ZoomableQuestionImageState extends State<_ZoomableQuestionImage> {
  Route<void>? _route;

  void _open() {
    if (_route?.isActive ?? false) return;
    final provider = _questionImageProvider(widget.url);
    final label = widget.label;
    final route = DialogRoute<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  image: true,
                  label: label,
                  child: InteractiveViewer(
                    key: const ValueKey('quiz-question-image-zoom-view'),
                    maxScale: 4,
                    child: Center(
                      child: Image(image: provider, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                top: SahneSpace.x2,
                end: SahneSpace.x2,
                child: SahneIconButton(
                  key: const ValueKey('quiz-question-image-zoom-close'),
                  icon: AppIcons.xmark,
                  semanticLabel: dialogContext.t(K.close),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    _route = route;
    Navigator.of(context).push(route);
  }

  /// Açık görünümü kapatır. Yaşam döngüsü çağrıları (didUpdateWidget,
  /// dispose) yerleşim/derleme sırasında gelir; rota kaldırmak Navigator'da
  /// setState tetiklediği için kaldırma sonraki kareye ertelenir ve orada
  /// rotanın hâlâ etkin olduğu yeniden denetlenir (Astra incelemesi).
  void _close() {
    final route = _route;
    _route = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  @override
  void didUpdateWidget(_ZoomableQuestionImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.questionId != widget.questionId) {
      _close();
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      button: true,
      label: widget.label,
      hint: context.t(K.questionImageZoomHint),
      // Alttaki `Image` widget'ları kendi (boş) semantiklerini üretiyor;
      // dışlanmazsa ekran okuyucu etiketi iki kez ya da eksik okur.
      excludeSemantics: true,
      onTap: _open,
      child: GestureDetector(
        key: const ValueKey('quiz-question-image-zoom'),
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: widget.child,
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
/// Soru 24/30'dur (2026-10-19; eskiden Başlık 28/32); dört satırı aşarsa Manşet 22/28'e iner — ölçerek,
/// karakter sayarak değil (bkz. [QuizQuestionPrompt]).
///
/// ## Şıklar doğal boylarında
///
/// Şık çubuğu en az 52'dir ve içerikle büyür; kalan alanı doldurmak için
/// şişirilmez. Şahnê'de soru ile şıkların altında kalan yer boş bir karta
/// değil sahneye (zemin çizimi, huzme, ufuk) açılır.
/// Soru metni ile şık grubu arası (şıklar alta oturan düzende). 24-32 aralığı
/// kurul kararıdır; 28 başparmak bölgesinde soruyu şıklara bağlar ama
/// birbirine yapıştırmaz.
const double quizPromptToAnswersGap = SahneSpace.x4;

/// Şıklar arası dikey boşluk (tur 8: 8 → 12; koyu temada şıklar birbirine
/// yapışık okunuyordu).
const double quizOptionGap = 12;

/// Soru+şık grubunun altında bırakılan pay (48). Eskiden 160'tı: joker ipucu
/// tostu alttan açıldığı için son şıkkı örtmesin diye pay ayrılıyor, grup
/// "yukarıda, altı boş" kalıyordu (8. kurul: Codex + ChatGPT). Tost artık
/// üst çubuğun hemen altında ([_StageToast]); alt pay yalnız nefes boşluğu.
/// Grup, üst çubuk ile bu pay arasındaki alanda DİKEYDE ORTALANIR.
const double quizAnchorNoticeReserve = 48;

/// Soru ekranının üst çubuğun altındaki geçici bildirimi.
class _StageToast extends StatelessWidget {
  const _StageToast({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: t.s3,
          shape: SahneShape.withSide(SahneShape.m, t.tx3, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SahneSpace.x3,
            vertical: SahneSpace.x2,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: SahneType.caption.copyWith(color: t.tx),
          ),
        ),
      ),
    );
  }
}

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
    this.wrongAnswerInsight = false,
    required this.suspense,
    required this.onAnswer,
    this.lexiconEnabled = false,
    this.translationEnabled = false,
    this.forceHeadline = false,
    this.titleLineBudget = QuizQuestionPrompt.maxTitleLines,
    this.audiencePoll,
    this.opponentSelectedAnswers,
    this.isCompact = false,
    this.twoColumn = false,
    this.minBodyHeight,
    this.answerAreaKey,
    this.promptCardKey,
    this.correctAnswerKey,
    this.explanationKey,
    this.explanationActionKey,
    this.onListen,
    this.canListen = false,
    this.listeningListenable,
  });

  final String promptText;

  /// W12: soru kartının anahtarı; cevap sonrası kaydırma kartın ÜSTÜNÜ
  /// kaybetmez ([_revealKeepingPhoto] `topKey`).
  final GlobalKey? promptCardKey;

  /// Sözlük dokunuşu: yalnız öğrenme modunda (günün dersi, ders kısa testi,
  /// alıştırma); yarış, oda ve düelloda KAPALI.
  final bool lexiconEnabled;

  /// Açılır Türkçe çeviri şeridi (bkz. [translationRevealAllowedFor]).
  final bool translationEnabled;
  final QuizQuestion question;
  final String selectedAnswer;
  final bool? adjudicatedCorrect;
  final bool answered;
  final Set<String> hiddenAnswers;
  final String firstAttemptAnswer;
  final Map<String, double>? audiencePoll;
  final bool showExplanation;

  /// Yanlış cevaptan sonra doğru cevap + açıklama kartı (bkz.
  /// [instantExplanationAllowedFor]). Doluyken "Açıklamayı gör" kapısının
  /// yerini alır: aynı açıklama iki yerde durmaz.
  final bool wrongAnswerInsight;
  final Map<String, _OpponentAnswer>? opponentSelectedAnswers;
  final bool isCompact;

  /// Telefon-yatay: soru hep Manşet 22; dört şık genişse iki sütun.
  final bool forceHeadline;
  final bool twoColumn;

  /// Doluysa soru+şık bloğu en az bu boydadır; fazlalık soru ile şıklar
  /// arasına girer (şıklar alta oturur).
  final double? minBodyHeight;

  /// Sorunun Soru 24/30 ile çizilebileceği en çok satır (düelloda 3).
  final int titleLineBudget;

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

        final translation = _revealableTranslation(context);
        final fit0 = QuizFitScope.of(context);
        final promptLine = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dinleme düğmesi (48) soru metninin yanında durur; boy
            // kararı metne kalan genişlikte ölçülür. Soru sığdırma
            // kademesi yalnız bu metnin ölçeğini küçültür.
            Expanded(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: QuizFitScope.scaled(
                    MediaQuery.textScalerOf(context),
                    fit0.questionScale,
                  ),
                ),
                child: Builder(builder: _promptWidget),
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
        );
        // K6 (2026-10-28): soru metni HER modda aynı açık kartta (koyu sahnede
        // yüksek karşıtlık); sahne zemininde yüzen metin okunmuyordu.
        final fit = QuizFitScope.of(context);
        final baseScaler = MediaQuery.textScalerOf(context);
        final Widget promptRow = QuizPromptCard(
          key: promptCardKey,
          padding: fit.promptPad,
          child: translation == null
              ? promptLine
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    promptLine,
                    const SizedBox(height: SahneSpace.x2),
                    PromptTranslationReveal(
                      key: ValueKey('prompt-tr-reveal-${question.id}'),
                      translation: translation,
                    ),
                  ],
                ),
        );
        final rest = <Widget>[
          SizedBox(
            height: fit.isNominal
                ? (isCompact ? SahneSpace.x3 : SahneSpace.x4)
                : fit.sectionGap,
          ),
          Container(
            key: answerAreaKey,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: QuizFitScope.scaled(baseScaler, fit.optionScale),
              ),
              child: Builder(builder: _answerArea),
            ),
          ),
          _AnswerRevealFallback(
            question: question,
            isKu: context.isKu,
            // Yalnız YANLIŞTA (ya da süre dolunca): doğru kuran oyuncunun
            // kutusu zaten ✓ ile yeşil; aynı cümleyi bir daha yazmak gürültü.
            visible:
                showExplanation &&
                needsAnswerRevealFallback(question.type) &&
                question.matchAnswer(selectedAnswer) != FreeTextMatch.exact,
            revealKey: showExplanation ? explanationKey : null,
          ),
          if (wrongAnswerInsight)
            _WrongAnswerInsight(key: explanationActionKey, question: question)
          else if (showExplanation && answered)
            _LearningExplanationAction(
              key: explanationActionKey,
              question: question,
            ),
        ];
        // Kısa soru: şıklar alt perdenin hemen üstüne (baş parmak bölgesi)
        // oturur, soru üstte kalır (kurul incelemesi 2026-10-19). Min boy
        // Column'a verilir: içerik daha uzunsa hiçbir şey olmaz, kayar.
        final minHeight = minBodyHeight;
        if (minHeight != null && minHeight > 0) {
          return ConstrainedBox(
            key: const ValueKey('quiz-answers-anchored'),
            constraints: BoxConstraints(minHeight: minHeight),
            // Soru + şıklar TEK dikey grup, alanda ORTALANIR (tur 8b): artan
            // boşluk grubun üstüne ve altına eşit bölünür; soru şıkların
            // hemen üstünde durur. Eskiden spaceBetween boşluğu soru üstü ve soru-şık arası
            // eşit bölüyordu: soru ekranın ortasında yüzüyor, şıklardan
            // ~150 pt uzakta kalıyordu (kurul, 2026-10-20).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                promptRow,
                SizedBox(
                  height: fit.isNominal
                      ? quizPromptToAnswersGap
                      : fit.sectionGap,
                ),
                // `rest[0]` bitişik düzenin 16'lık aralığıdır; burada yerini
                // yukarıdaki sabit aralık alır.
                ...rest.skip(1),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [promptRow, ...rest],
        );
      },
    );
  }

  /// Kurmancî oynayana açılır Türkçe çeviri (2026-10-23, kullanıcı geri
  /// bildirimi: "hiç bilmeyen birine altta kapalı, basınca çevirisini
  /// gösteren bir şey"). Yalnız rakipsiz tek kişilik turda
  /// ([translationEnabled]). Yalnız soru metni çevrilir: şık çevirisi
  /// kelime sorularında cevabı ele verir.
  /// Boşluk doldurma ve kelime sıralama kendi çevirisini zaten taşır.
  String? _revealableTranslation(BuildContext context) {
    if (!translationEnabled || !context.isKu) return null;
    if (question.type == QuestionType.fillInBlank ||
        question.type == QuestionType.wordOrdering) {
      return null;
    }
    final tr = question.promptTr?.trim();
    if (tr == null || tr.isEmpty || tr == promptText.trim()) return null;
    return tr;
  }

  /// Soru başlığı. Boşluk doldurma ve kelime sıralama `Yönerge: "cümle"
  /// ("çeviri")` kalıbındaysa dört role ayrılır; kalıba uymayan her soru
  /// (ve her şıklı soru) eski tek parça başlıkla çizilir.
  Widget _promptWidget(BuildContext context) {
    final lexicon = LexiconTapPolicy.forQuestion(
      enabled: lexiconEnabled,
      isKu: context.isKu,
      answered: answered,
      type: question.type.name,
      promptText: promptText,
      correctAnswer: question.correctAnswer,
    );
    return QuestionPromptBlock.tryBuild(
          question: question,
          promptText: promptText,
          lexicon: lexicon,
          forceHeadline: forceHeadline,
          titleLineBudget: titleLineBudget,
        ) ??
        QuizQuestionPrompt(
          promptText,
          lexicon: lexicon,
          forceHeadline: forceHeadline,
          titleLineBudget: titleLineBudget,
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
    final fit = QuizFitScope.of(context);
    final gap = fit.isNominal ? quizOptionGap : fit.optionGap;

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
        padding: EdgeInsets.only(bottom: gap),
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

/// Yanlış cevaptan HEMEN sonra: doğru cevap + 1–2 cümlelik açıklama.
///
/// ## Kural değişikliği (2026-10-24, ürün sahibi onayı)
///
/// 2026-07-26 kuralı "tur sırasında açıklama yok, hepsi sonuçta" idi ve
/// ritmi korumak içindi. Yanlış yapan oyuncu ise tam o anda öğrenmeye en
/// açıktır; sonuçta aynı soruya dönmek zorunda kalıyordu. Yeni kural dardır:
/// yalnız YANLIŞTA, yalnız rakipsiz turda ([instantExplanationAllowedFor]);
/// doğru cevapta ritim aynen sürer.
///
/// Açıklaması olmayan soruda (3750 sorudan 12'si) yalnız doğru cevap yazılır.
/// Sıralama türlerinde doğru cevabı zaten [_AnswerRevealFallback] basar; burada
/// tekrar edilmez.
class _WrongAnswerInsight extends StatelessWidget {
  const _WrongAnswerInsight({super.key, required this.question});

  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final explanation = question.getLocalizedExplanation(context.isKu).trim();
    // Yazılı (boşluk doldurma) soruda doğru cevabı alanın kendisi zaten
    // yazar; sıralamada yedek kutu yazar. İkisinde de tekrar edilmez.
    final showAnswer =
        !needsAnswerRevealFallback(question.type) &&
        question.type != QuestionType.fillInBlank;
    if (!showAnswer && explanation.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x4),
      // Vay 2A: sahnenin CAM kartı (gri Perde mor sahneden kopuyordu).
      // Son kurul tur 3 (2026-10-29, üç model): saydam camdan gece dağı
      // açıklama yazısının arkasından görünüyordu; kart aynı tonda OPAK.
      child: SahneGlassCard(
        key: const ValueKey('quiz-wrong-answer-insight'),
        solid: true,
        padding: const EdgeInsets.all(SahneSpace.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAnswer)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${context.t(K.correctAnswerLabel)}: ',
                      style: SahneType.captionStrong.copyWith(color: t.learnTx),
                    ),
                    TextSpan(
                      text: question.correctAnswer,
                      style: SahneType.bodyStrong.copyWith(color: t.tx),
                    ),
                  ],
                ),
                key: const ValueKey('quiz-wrong-answer-correct'),
              ),
            if (showAnswer && explanation.isNotEmpty)
              const SizedBox(height: SahneSpace.x2),
            if (explanation.isNotEmpty)
              Text(
                explanation,
                key: const ValueKey('quiz-wrong-answer-explanation'),
                style: SahneType.body.copyWith(color: t.tx),
              ),
          ],
        ),
      ),
    );
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
    // Kurul 3. tur (2026-10-20): ortak alt sayfa kabuğu (tutamaç + başlık
    // + kapat). Ku modda engel-kapatma etiketi de kabuktan yerelleşir.
    showSahneSheet<void>(
      context: context,
      title: context.t(K.explanationTitle),
      builder: (sheetContext) {
        final t = SahneTokens.of(sheetContext);
        return Text(explanation, style: SahneType.body.copyWith(color: t.tx));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final explanation = question.getLocalizedExplanation(context.isKu).trim();
    if (explanation.isEmpty) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final label = context.t(K.viewExplanation);

    // Kurul 2. tur (2026-10-20, ekran 84): koyu yeşil dolgulu tam genişlik
    // düğme beşinci bir şık ya da "doğru cevap" gibi okunuyordu. Artık
    // ÇERÇEVELİ, dolgusuz, ortalı metin düğmesi: şıklardan (dolgulu çubuk)
    // biçimce ayrılır ve üstündeki boşluk daha geniştir.
    return Padding(
      padding: const EdgeInsets.only(top: SahneSpace.x4),
      child: Semantics(
        button: true,
        label: label,
        onTap: () => _open(context, explanation),
        excludeSemantics: true,
        child: SahneTappable(
          key: const ValueKey('quiz-view-explanation'),
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(SahneShape.lValue),
            ),
            side: BorderSide(color: t.learnTx, width: 1.5),
          ),
          color: Colors.transparent,
          onTap: () => _open(context, explanation),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x3,
              vertical: SahneSpace.x3,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(AppIcons.bookOpen, color: t.learnTx, size: 20),
                const SizedBox(width: SahneSpace.x2),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: SahneType.bodyStrong.copyWith(color: t.learnTx),
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

// ─── Kalabalık oda kartı ─────────────────────────────────────────────────────

/// Kalabalık odada (3+ kişi) soru ekranının başlık kartı: sol üstte kendi
/// avatarın ve puanın, sağ üstte sıran ("#3/12"), altta ilk üç şeridi.
///
/// Düello kartı (`_DuelScoreHeader`) iki kişiyi yan yana koyar; 50 kişiyi
/// yan yana koymak olmaz. Burada herkesin puanı değil, oyuncunun bilmek
/// istediği iki şey vardır: nerede olduğu ve önünde kimlerin olduğu.
/// Sıra, eşit puanda aynı numarayı paylaşır (bkz. `crowdStandings`).
class _CrowdScoreHeader extends StatelessWidget {
  const _CrowdScoreHeader({
    required this.player,
    required this.rank,
    required this.total,
    required this.top,
    this.progress,
  });

  final Player player;

  /// Oyuncunun sırası; sıralamaya henüz girmediyse (liste yüklenmedi) null.
  final int? rank;

  /// Sıralamadaki (ayrılmayan) oyuncu sayısı.
  final int total;

  /// İlk dört satır (eşitlikte aynı numara görünür).
  final List<CrowdStanding> top;

  /// Mevcut sorunun "x/N cevapladı" sayısı; sunucu vermiyorsa null.
  final RoomAnswerProgress? progress;

  static const progressKey = ValueKey('quiz-crowd-progress');
  static const rankKey = ValueKey('quiz-crowd-rank');
  static const topKey = ValueKey('quiz-crowd-top3');

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Kurul C9 (Astra + Sol): herkes aynı puandayken (ör. ilk soruda 0)
    // "#1/4" tek başına liderlik gibi okunuyordu; eşitlikte "Eşit" yazar.
    final allTied =
        top.length > 1 &&
        top.every((s) => s.player.score == top.first.player.score);
    final rankText = rank == null
        ? '—'
        : allTied
        ? context.t(K.crowdAllTied)
        : '#$rank/$total';
    // Kartın içi %115 tavanlı ölçekle çizilir; bu `context` tavanın ÜSTÜNDE
    // olduğundan boylar aynı tavanla buradan hesaplanır.
    final cardScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: quizCrowdMaxScale);
    final progressStyle = SahneType.captionStrong.copyWith(
      color: t.tx2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String answeredText(int answered, int active) => context.t(
      K.crowdAnsweredCount,
      {'answered': '$answered', 'active': '$active'},
    );

    // Dört oyuncunun hepsi her zaman görünür: tek satırlık kompakt çipler
    // (sıra + ad + puan). Kendi çipin Zêr tonlu.
    Widget chip(CrowdStanding standing) {
      final isMe = playersShareIdentity(standing.player, player);
      final tabular = SahneType.captionStrong.copyWith(
        color: isMe ? t.goldTx : t.tx2,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      return DecoratedBox(
        decoration: ShapeDecoration(
          color: isMe ? t.goldTint : t.s2,
          shape: SahneShape.s,
        ),
        child: SizedBox(
          // a11y-tap-target: noninteractive — salt görüntü çipi. Boy SABİT ve
          // sığdırma bütçesiyle aynı formül (sapma soruyu kaydırırdı).
          height: _QuizHeaderHeights.chipHeight(cardScaler),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x1),
            child: Row(
              children: [
                // Tur 1 (I3, 2026-10-29): çipte ad yoktu, yalnız baş harf +
                // 12 pt puan; test adları aynı harfle başlayınca kimin hangi
                // puanı aldığı anlaşılmıyordu (Opus + Astra). Artık kısa ad
                // (ilk sözcük) + büyük puan; avatar düştü (baş harf ad kadar
                // bilgi taşımıyor, yeri ada kalır). Sütun sayısı ikisinin en
                // kötü genişliğiyle ölçülür ([quizCrowdColumns]).
                Expanded(
                  child: Semantics(
                    label:
                        '${standing.rank}. ${context.playerDisplayName(standing.player.name, tag: standing.player.tag)}, ${standing.player.score}',
                    excludeSemantics: true,
                    // Ad okunur alt sınırda (14) ve KÜÇÜLMEZ (kapışma U13/
                    // U15; önce 12'den 11'e küçülüyordu). Sütun sayısı
                    // sekiz harflik adı 14 pt'de sığdıracak biçimde seçilir.
                    child: Text(
                      quizCrowdShortName(
                        context.playerDisplayName(
                          standing.player.name,
                          tag: standing.player.tag,
                        ),
                      ),
                      key: ValueKey('quiz-crowd-name-${standing.rank}'),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: tabular.copyWith(color: isMe ? t.goldTx : t.tx),
                    ),
                  ),
                ),
                const SizedBox(width: SahneSpace.x1),
                ExcludeSemantics(
                  child: Text(
                    groupThousands(standing.player.score),
                    maxLines: 1,
                    style: tabular.copyWith(
                      color: t.goldTx,
                      fontSize: quizCrowdScorePt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Dört çip sığmıyorsa (ölçülür) 2×2 dizilir.
    final strip = Semantics(
      label: context.t(K.crowdTopThree),
      container: true,
      child: KeyedSubtree(
        key: topKey,
        child: LayoutBuilder(
          builder: (context, c) {
            final cols = quizCrowdColumns(
              MediaQuery.textScalerOf(context),
              c.maxWidth,
            );
            final w = (c.maxWidth - SahneSpace.x1 * (cols - 1)) / cols;
            return Wrap(
              spacing: SahneSpace.x1,
              runSpacing: SahneSpace.x1,
              children: [
                for (final standing in top)
                  SizedBox(width: w, child: chip(standing)),
              ],
            );
          },
        ),
      ),
    );

    // Üst satır: solda sıran, sağda "x/N cevapladı". Kendi adın ve puanın
    // aşağıdaki çiplerde (Zêr tonlu) zaten var; tekrar etmez.
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          context.t(K.crowdRankLabel),
          maxLines: 1,
          style: SahneType.eyebrow.copyWith(color: t.tx2),
        ),
        const SizedBox(width: SahneSpace.x1),
        Text(
          rankText,
          key: rankKey,
          maxLines: 1,
          style: SahneType.captionStrong.copyWith(
            color: t.raceTx,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: SahneSpace.x2),
        Expanded(
          // Sayı gelmeden de yer AYNI: görünmez yer tutucu en geniş hâliyle
          // (hepsi cevapladı) satırı baştan ayırır.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: progress != null
                ? Text(
                    answeredText(progress!.answered, progress!.active),
                    key: progressKey,
                    maxLines: 1,
                    style: progressStyle,
                  )
                : ExcludeSemantics(
                    child: Opacity(
                      opacity: 0,
                      child: Text(
                        answeredText(total, total),
                        maxLines: 1,
                        style: progressStyle,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );

    return MediaQuery.withClampedTextScaling(
      // Skor şeridi bilgi bandıdır; büyük yazıda %115'te durur ki soru ve
      // şıklar (asıl içerik) büyük yazının alanını alsın. Bütçe aynı sınırı
      // kullanır ([_QuizHeaderHeights.crowd]).
      maxScaleFactor: quizCrowdMaxScale,
      child: Semantics(
        container: true,
        label:
            '${context.t(K.crowdRankLabel)}: $rankText, '
            '${player.score} ${context.t(K.scoreWord).toLowerCase()}',
        child: SahneSurfaceCard(
          key: const ValueKey('quiz-crowd-header'),
          padding: const EdgeInsets.all(SahneSpace.x1),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                // a11y-tap-target: noninteractive — salt görüntü satırı (dokunma
                // yok; oda şeridi artık tıklanmaz). Boy SABİT, bütçeyle aynı.
                height: _QuizHeaderHeights.headerRowHeight(cardScaler),
                child: header,
              ),
              if (top.isNotEmpty) ...[
                const SizedBox(height: SahneSpace.x1),
                strip,
              ],
            ],
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
    this.showTug = true,
  });

  final Player player;
  final Player opponent;
  final String progress;

  /// Halat çekme çubuğu; kısa ekranda (< 700 pt) düşer, puanlar yine yazılıdır.
  final bool showTug;

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
      showcaseTitle: player.showcaseTitle,
      displayName: player.name,
      colorOverride: playerColor,
    );
    final opponentAvatar = PlayerAvatar(
      radius: 16,
      photoUrl: opponent.avatarUrl,
      iconId: opponent.avatarIcon,
      colorHex: opponent.avatarColor,
      frameId: opponent.avatarFrame,
      showcaseTitle: opponent.showcaseTitle,
      displayName: opponent.name,
      colorOverride: opponentColor,
    );

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

    Widget side(Player p, Widget avatar, {required bool end}) {
      final info = Expanded(
        child: Column(
          crossAxisAlignment: end
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Ad + (botsa) "Bot" rozeti: dar kartta (320 dp, büyük yazı)
            // rozet taşmaz, alt satıra iner (2026-10-29, X4).
            Row(
              mainAxisAlignment: end
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Flexible(
                  // Okunur tabana (11 pt) kadar küçülür, sonra iki satıra
                  // sarar (üç nokta yalnız son çare).
                  child: QuizFitLine(
                    context.playerDisplayName(p.name, tag: p.tag),
                    maxLines: 2,
                    alignment: end
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
                ),
              ],
            ),
            // Seri (🔥xN) puanın yanındadır: eskiden kartın altında AYRI bir
            // satırdı ve rakip puan alıp seri başlayınca kart ~28 pt uzayıp
            // soruyu aşağı itiyordu (2026-10-29, "soru gelince her şey sabit").
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: end
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Bot" rozeti puan satırında (ad satırı dar kalır; ad, rozetle
                  // yarışıp üç noktaya düşmesin).
                  if (p.isBot && end) ...[
                    SahneBadge(
                      key: const ValueKey('duel-bot-chip'),
                      label: context.t(K.botChip),
                      tone: SahneBadgeTone.soon,
                    ),
                    const SizedBox(width: SahneSpace.x2),
                  ],
                  if (end && p.streak > 0) ...[
                    streakOf(p, end: true),
                    const SizedBox(width: SahneSpace.x2),
                  ],
                  Text(
                    // 2026-09-30 canlı: "pts" İngilizce kısaltmaydı; terim
                    // sözlüğü puan/pûan der, kelime `K.scoreWord`tan gelir.
                    '${groupThousands(p.score)} ${context.t(K.scoreWord).toLowerCase()}',
                    maxLines: 1,
                    style: SahneType.captionStrong.copyWith(
                      color: t.goldTx,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (p.isBot && !end) ...[
                    const SizedBox(width: SahneSpace.x2),
                    SahneBadge(
                      key: const ValueKey('duel-bot-chip'),
                      label: context.t(K.botChip),
                      tone: SahneBadgeTone.soon,
                    ),
                  ],
                  if (!end && p.streak > 0) ...[
                    const SizedBox(width: SahneSpace.x2),
                    streakOf(p, end: false),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
      // Çok büyük yazıda (> 1,5×) avatar düşer: ad yuvası 40 pt'e iniyordu.
      final big = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
      return Expanded(
        child: big
            ? Row(children: [info])
            : Row(
                children: end
                    ? [info, const SizedBox(width: SahneSpace.x2), avatar]
                    : [avatar, const SizedBox(width: SahneSpace.x2), info],
              ),
      );
    }

    return SahneSurfaceCard(
      padding: const EdgeInsets.all(SahneSpace.x2),
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
          if (showTug) ...[
            const SizedBox(height: SahneSpace.x2),
            _DuelTugBar(
              playerScore: player.score,
              opponentScore: opponent.score,
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

/// Soru türü cevabı KENDİ düğmesiyle mi gönderir ("Kontrol et")?
///
/// Tur 1 (I12, 2026-10-29): cümle sıralamada gövdede "Kontrol bike" dururken
/// alt perdede pasif "Bir cevap seç" de görünüyordu: aynı anda iki eylem,
/// biri yanlış yönerge. Kendi gönderme düğmesi olan türlerde alt perde
/// cevaptan önce boş kalır (boyu sabit; bkz. `quizDockHeight`).
bool hasOwnSubmit(QuestionType type) => switch (type) {
  QuestionType.multipleChoice ||
  QuestionType.trueFalse ||
  QuestionType.visual => false,
  QuestionType.fillInBlank || QuestionType.wordOrdering => true,
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
    this.doubleAnswerHint,
    this.hint,
    this.showHint = false,
  });

  final int balance;

  /// Çift cevap ilk denemesi yanlışsa bakiye satırının YERİNE geçen ipucu
  /// (aynı yuva: alt perde uzamaz).
  final String? doubleAnswerHint;

  /// Açıklayıcı cümle. 2026-10-19 sadeleşme: ekranda YAZILMAZ (iki satırlık
  /// "Yarışı bitir, jeton kazan, jokerleri aç" alt perdeyi büyütüyor, her
  /// soruda aynı cümleyi tekrar okutuyordu); yalnız ekran okuyucuya gider ve
  /// jetonu yetmeyen jokere dokununca tost olarak açılır.
  final String? hint;

  /// İpucu ekranda da yazılsın mı? Yalnız günlük bedava joker ipucu için
  /// `true`: kısa ("Bugün 1 joker bedava"), tek bilgi ve oyuncunun jetonu
  /// yetmese bile jokerin açık olmasının TEK nedeni; yazılmazsa kilitsiz
  /// jokerler açıklamasız kalır.
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final dbl = doubleAnswerHint;
    if (dbl != null) {
      return Semantics(
        liveRegion: true,
        label: dbl,
        excludeSemantics: true,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              dbl,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: SahneType.captionStrong.copyWith(color: t.goldTx),
            ),
          ),
        ),
      );
    }
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
            groupThousands(balance),
            style: SahneType.captionStrong.copyWith(
              color: t.goldTx,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (showHint && hint != null) ...[
            const SizedBox(width: SahneSpace.x2),
            Flexible(
              // Üç nokta yerine sığacak kadar küçülür (soru sığma bekçisi).
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '· $hint',
                  key: const ValueKey('quiz-free-wildcard-hint'),
                  maxLines: 1,
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hiçbir jokere jetonu yetmeyen oyuncunun tek sönük satırı (kurul 4. tur
/// 2026-10-20): kilit + jeton + bakiye + "Yetersiz bakiye". Dört kilitli çip
/// yerine geçer; dokunulabilir (48 yüksek) ve nedenini tostla söyler.
class _CollapsedWildcardLine extends StatelessWidget {
  const _CollapsedWildcardLine({required this.balance, required this.onTap});

  final int balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final label = context.t(K.wildcardNoCoins);
    return Semantics(
      button: true,
      label: '$balance ${context.t(K.coinWord)}. $label',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: sahneTapTarget),
          child: Center(
            // Hap: koyu zeminde yalın satır kayboluyordu (tur 7, Gemini).
            // Hafif saydam dolgu + 1 px kenar satırı okunur bir nesne yapar.
            child: DecoratedBox(
              key: const ValueKey('quiz-collapsed-wildcard-pill'),
              decoration: ShapeDecoration(
                color: t.optionFill.withValues(alpha: 0.7),
                shape: StadiumBorder(side: BorderSide(color: t.optionEdge)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SahneSpace.x3,
                  vertical: SahneSpace.x1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.lock, size: 16, color: t.tx2),
                    const SizedBox(width: SahneSpace.x2),
                    const SahneGlyph(SahneGlyphKind.coin, size: 16),
                    const SizedBox(width: SahneSpace.x1),
                    Text(
                      groupThousands(balance),
                      style: SahneType.captionStrong.copyWith(
                        color: t.goldTx,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: SahneSpace.x2),
                    Flexible(
                      // Üç nokta yok: sığmazsa metin küçülür.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: SahneType.captionStrong.copyWith(color: t.tx),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soru bloğunun ÜSTÜNDEKİ bantların (skor kartları, çeviri şeridi) tahmini
/// boyları. Sığdırma bütçesi bunları düşer ([QuizFit]); bekçi
/// (`soru_sigma_test`) sapmayı yakalar.
class _QuizHeaderHeights {
  const _QuizHeaderHeights._();

  /// Düello kartı: 16 iç boşluk + iki 20'lik satır (ad / puan) + 8 + halat 12.
  static double duel(TextScaler s, {bool tug = true}) =>
      16 + 2 * s.scale(20) + (tug ? 8 + 12 : 0);

  /// Oda şeridi: 16 iç boşluk + üst satır + 4 + dört kompakt çip.
  static double crowd(TextScaler s, double contentWidth) {
    // Kart iç boşluğu 4+4, çerçeve 2 (bkz. `_CrowdScoreHeader`).
    final c = s.clamp(maxScaleFactor: quizCrowdMaxScale);
    final rows = (4 / quizCrowdColumns(c, contentWidth - 10)).ceil();
    return 2 * SahneSpace.x1 +
        headerRowHeight(c) +
        rows * (SahneSpace.x1 + chipHeight(c));
  }

  /// Kompakt oyuncu çipinin en az yüksekliği.
  static const double chip = 22;

  /// Çipin SABİT boyu: en az [chip], büyük yazıda puan satırı kadar.
  static double chipHeight(TextScaler s) =>
      max(chip, s.scale(quizCrowdScorePt) * 1.3 + 4);

  /// Sıra + "x/N cevapladı" satırının en az yüksekliği.
  static const double headerRow = 20;

  /// Satırın SABİT boyu (bütçe ve çizim aynı formülü kullanır).
  static double headerRowHeight(TextScaler s) => max(headerRow, s.scale(18));

  /// Kapalı çeviri şeridi.
  static double translation(TextScaler s) => max(32, s.scale(20) + 8);
}
