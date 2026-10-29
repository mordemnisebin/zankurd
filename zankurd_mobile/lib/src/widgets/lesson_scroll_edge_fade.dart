import 'package:flutter/material.dart';

/// Ders slaydının kaydırılan içeriği, altta sabit gezinme düğmeleri var.
///
/// Kurul 1 (C1/C28, 2026-10-29): sonraki kartın yalnız üst şeridi düğmelerin
/// hemen üstünde YARIM görünüyor, içerik kesik/bozuk sanılıyordu. Altta daha
/// içerik varken son 28 pt soluklaşır; içeriğin devam ettiği okunur. En
/// sona kaydırınca solma kalkar (son satır tam görünür).
@visibleForTesting
class LessonScrollEdgeFade extends StatefulWidget {
  const LessonScrollEdgeFade({required this.child, super.key});

  final Widget child;

  static const double fadeExtent = 28;

  @override
  State<LessonScrollEdgeFade> createState() => LessonScrollEdgeFadeState();
}

@visibleForTesting
class LessonScrollEdgeFadeState extends State<LessonScrollEdgeFade> {
  bool _moreBelow = false;

  /// Altta görünmeyen içerik var mı (solma açık mı)?
  @visibleForTesting
  bool get moreBelow => _moreBelow;

  bool _onMetrics(ScrollMetrics m) {
    final more = m.extentAfter > 0.5;
    if (more != _moreBelow) setState(() => _moreBelow = more);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Yalnız doğrudan altındaki DİKEY kaydırma sayılır (tur 3, 2026-10-30:
    // ana sayfa ve profil sekmelerinde de kullanılır; oradaki yatay
    // şeritler ve iç içe listeler solmayı açıp kapatmasın).
    bool relevant(int depth, ScrollMetrics m) =>
        depth == 0 && m.axis == Axis.vertical;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) =>
          relevant(n.depth, n.metrics) ? _onMetrics(n.metrics) : false,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) =>
            relevant(n.depth, n.metrics) ? _onMetrics(n.metrics) : false,
        // ShaderMask'a durumla değişen anahtar VERİLMEZ: anahtar değişince
        // altındaki kaydırma yeniden kurulur ve konum başa döner.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            if (!_moreBelow || rect.height <= LessonScrollEdgeFade.fadeExtent) {
              return const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
              ).createShader(rect);
            }
            final stop = 1 - LessonScrollEdgeFade.fadeExtent / rect.height;
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0, stop, 1],
            ).createShader(rect);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
