import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import 'coach_mark.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// İlk quiz deneyiminde kullanıcıya arayüzü tanıtan rehber turu bindirmesi.
///
/// [child] ana quiz içeriğidir; overlay yalnızca ilk kez quiz açıldığında
/// gösterilir ve SharedPreferences üzerinden `zankurd.quiz_tutorial.seen`
/// anahtarıyla takip edilir. Kullanıcı adımları geçebilir veya atlayabilir.
class QuizTutorialOverlay extends StatefulWidget {
  const QuizTutorialOverlay({
    required this.child,
    required this.isKu,
    required this.timerKey,
    required this.comboKey,
    required this.wildcardKey,
    required this.nextButtonKey,
    this.onReady,
    this.timerSeconds = 15,
    this.timed = true,
    super.key,
  });

  /// Bindirmenin altında kalan ana quiz içeriği.
  final Widget child;

  /// Dil seçimi: Kürtçe (true) / Türkçe (false).
  final bool isKu;

  /// Dairesel sayaç hedef anahtarı. Süresiz derste Zana üst şeridindedir.
  final GlobalKey timerKey;

  /// Seri/kombo rozeti hedef anahtarı.
  final GlobalKey comboKey;

  /// Joker butonları satırı hedef anahtarı.
  final GlobalKey wildcardKey;

  /// Sonraki soru butonu hedef anahtarı.
  final GlobalKey nextButtonKey;

  /// Rehber gösterilmeyecekse hemen, gösterilecekse rehber kapanınca çağrılır.
  ///
  /// Quiz timer'ı bu sinyalden önce başlamamalı; aksi halde ilk kez quiz açan
  /// kullanıcı rehberi okurken süre biter ve doğru cevap otomatik açılır.
  final VoidCallback? onReady;

  /// Soru başına süre (sn) — Demjimêr adımındaki açıklama metni bunu gösterir.
  final int timerSeconds;

  /// Bu akışta geri sayım var mı? Öğrenme akışında sayaç çizilmediği için
  /// ilk adım sayacı değil cevap alanını hedefler ve metni süreden söz etmez.
  final bool timed;

  @override
  State<QuizTutorialOverlay> createState() => _QuizTutorialOverlayState();
}

class _QuizTutorialOverlayState extends State<QuizTutorialOverlay> {
  static const _seenKey = 'zankurd.quiz_tutorial.seen';

  final GlobalKey _stackKey = GlobalKey();
  bool _checking = true;
  bool _show = false;
  bool _readyNotified = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldShow = prefs.getBool(_seenKey) != true;
    if (!mounted) return;
    setState(() {
      _show = shouldShow;
      _checking = false;
    });
    if (!shouldShow) {
      _notifyReady();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    if (!mounted) return;
    setState(() => _show = false);
    _notifyReady();
  }

  void _notifyReady() {
    if (_readyNotified) return;
    _readyNotified = true;
    widget.onReady?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) return widget.child;

    return Stack(
      key: _stackKey,
      children: [
        widget.child,
        if (_show)
          CoachMarkOverlay(
            isKu: widget.isKu,
            onFinished: _finish,
            onBeforeStep: (nextIndex) async {
              if (nextIndex != 1) return;
              final targetContext = widget.nextButtonKey.currentContext;
              if (targetContext == null) return;
              await Scrollable.ensureVisible(
                targetContext,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
              await WidgetsBinding.instance.endOfFrame;
            },
            ancestorKey: _stackKey,
            // Dalga 5: 5 adım 2'ye indirildi. Sayaç + cevaplama tek
            // balonda; joker öğretimi ilk kullanımda contextual ipucu
            // olarak quiz içinde gösterilir (bkz. _maybeShowWildcardHint).
            steps: [
              if (widget.timed)
                CoachMarkStep(
                  targetKey: widget.timerKey,
                  icon: AppIcons.stopwatch,
                  title: context.t(K.quizTutorialTimerTitle),
                  description: context.t(K.quizTutorialTimerBody, {
                    'seconds': '${widget.timerSeconds}',
                  }),
                )
              else
                CoachMarkStep(
                  targetKey: widget.timerKey,
                  icon: AppIcons.bullseye,
                  title: context.t(K.quizTutorialUntimedTitle),
                  description: context.t(K.quizTutorialUntimedBody),
                ),
              CoachMarkStep(
                targetKey: widget.nextButtonKey,
                icon: AppIcons.arrowRight,
                title: context.t(K.quizTutorialNextTitle),
                description: context.t(K.quizTutorialNextBody),
              ),
            ],
          ),
      ],
    );
  }
}
