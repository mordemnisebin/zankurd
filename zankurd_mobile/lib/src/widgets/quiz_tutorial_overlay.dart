import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coach_mark.dart';

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

  @override
  State<QuizTutorialOverlay> createState() => _QuizTutorialOverlayState();
}

class _QuizTutorialOverlayState extends State<QuizTutorialOverlay> {
  static const _seenKey = 'zankurd.quiz_tutorial.seen';

  final GlobalKey _stackKey = GlobalKey();
  bool _checking = true;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _show = prefs.getBool(_seenKey) != true;
      _checking = false;
    });
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    if (!mounted) return;
    setState(() => _show = false);
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
            ancestorKey: _stackKey,
            steps: [
              CoachMarkStep(
                targetKey: widget.timerKey,
                icon: Icons.timer_outlined,
                titleKu: 'Demjimêr',
                titleTr: 'Zamanlayıcı',
                descriptionKu:
                    '15 saniyede bersivê bide. Berî ku dem biqede bersiva xwe hilbijêre.',
                descriptionTr:
                    '15 saniyede cevap ver. Süre dolmadan şıkkını seç.',
              ),
              CoachMarkStep(
                targetKey: widget.answerAreaKey,
                icon: Icons.touch_app_outlined,
                titleKu: 'Bersiv Hilbijêre',
                titleTr: 'Cevap Seç',
                descriptionKu:
                    'Bersiva rast hilbijêre. Her bersiva rast pûanan qezenc dike.',
                descriptionTr:
                    'Doğru şıkkı seç. Her doğru cevap puan kazandırır.',
              ),
              CoachMarkStep(
                targetKey: widget.comboKey,
                icon: Icons.local_fire_department_outlined,
                titleKu: 'Rêz / Kombo',
                titleTr: 'Seri / Kombo',
                descriptionKu:
                    'Rêz çêke û bonûs pûanan qezenc bike! Bi bersivên rast ên li pey hev rêza xwe mezin bike.',
                descriptionTr:
                    'Seri yaptıkça bonus puan kazan! Peş peşe doğru cevaplarla serini büyüt.',
              ),
              CoachMarkStep(
                targetKey: widget.wildcardKey,
                icon: Icons.auto_awesome_outlined,
                titleKu: 'Joker',
                titleTr: 'Jokerler',
                descriptionKu:
                    'Bi jokeran pirsên zor derbas bike. Ji %50, temaşevan, bersiva ducarî alîkariyan bikar bîne.',
                descriptionTr:
                    'Jokerlerle zor soruları aş. %50, seyirci, çift cevap gibi yardımcıları kullan.',
              ),
              CoachMarkStep(
                targetKey: widget.nextButtonKey,
                icon: Icons.arrow_forward_outlined,
                titleKu: 'Pirsa Din',
                titleTr: 'Sonraki Soru',
                descriptionKu:
                    'Piştî bersivê derbasî pirsa din bibe. Di pirsa dawî de pêşbirkê biqedîne.',
                descriptionTr:
                    'Cevap verdikten sonra sonraki soruya geç. Son soruda yarışmayı bitir.',
              ),
            ],
          ),
      ],
    );
  }
}
