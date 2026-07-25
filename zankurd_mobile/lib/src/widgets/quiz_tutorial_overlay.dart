import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    required this.answerAreaKey,
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

  /// Dairesel sayaç hedef anahtarı.
  final GlobalKey timerKey;

  /// Cevap şıklarının bulunduğu alan hedef anahtarı.
  final GlobalKey answerAreaKey;

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
                  titleKu: 'Demjimêr + Bersiv',
                  titleTr: 'Süre + Cevap',
                  descriptionKu:
                      '${widget.timerSeconds} saniyeyê de bersiva rast hilbijêre; her bersiva rast pûanan qezenc dike.',
                  descriptionTr:
                      '${widget.timerSeconds} saniyede doğru şıkkı seç; her doğru cevap puan kazandırır.',
                )
              else
                CoachMarkStep(
                  targetKey: widget.answerAreaKey,
                  icon: AppIcons.bullseye,
                  titleKu: 'Bersivê hilbijêre',
                  titleTr: 'Cevabı seç',
                  descriptionKu:
                      'Li vir demjimêr tune — bi rehetî bifikire û bersiva rast hilbijêre. Piştî her bersivê ravekirin tê nîşandan.',
                  descriptionTr:
                      'Burada süre yok — acele etmeden düşün ve doğru şıkkı seç. Her cevaptan sonra açıklama gösterilir.',
                ),
              CoachMarkStep(
                targetKey: widget.nextButtonKey,
                icon: AppIcons.arrowRight,
                titleKu: 'Rêz + Pirsa Din',
                titleTr: 'Seri + Sonraki Soru',
                descriptionKu:
                    'Bersivên rast ên li pey hev rêzê mezin dikin û bonûs tînin. Piştî bersivê vir bitikîne û derbasî pirsa din bibe.',
                descriptionTr:
                    'Peş peşe doğru cevaplar serini büyütür, bonus kazandırır. Cevapladıktan sonra buradan sonraki soruya geç.',
              ),
            ],
          ),
      ],
    );
  }
}
