import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../widgets/sahne/sahne.dart';
import '../contest_screen.dart' show kDailyEventSecondsPerQuestion;

/// Ana ekranın tek günlük oyunu: "Günün turu".
///
/// 2026-10-24 sahibin kararı: ana ekranda iki ayrı günlük giriş vardı —
/// kahraman kart ("Günün dersi", 5–10 soruluk süresiz açıklamalı oturum) ve
/// Yarış sekmesindeki "Günün soruları" (10 soruluk, süreli günlük tur).
/// Oyuncu hangisinin "günün" oyunu olduğunu bilemiyordu. Artık günün oyunu
/// TEKTİR ve adı "Günün turu"dur; kahraman kart ona açılan kapıdır.
///
/// İki durum:
/// * Oynanmadı: "Günün turu · 10 soru · 20 sn/soru" + tek birincil
///   "Başla" (turu açar).
/// * Bugün bitirildi: "Bugünkü turu bitirdin" + "Yeni tur 3 sa 12 dk
///   sonra" + ikincil "Pratik yap" (eski süresiz, açıklamalı oturum).
///
/// "Sıralamaya gir" vaadi BİLEREK yok: günlük tur bugün sıralama
/// hesaplamıyor (bkz. `ContestScreen` notu — `contestId` yok, ödül yok);
/// ürünün veremeyeceği sözü kartta yazmak yalan olurdu. Skor da saklı
/// değil, o yüzden bitmiş durum sıra/skor yerine yalnız bitişi söyler.
///
/// "Bitti" günü `AchievementStore.dailyQuizDoneOn` ile aynı yerel takvim
/// günüdür; yeni tur ertesi yerel gün başında açılır, geri sayım oradan.
class DailyTourCard extends StatelessWidget {
  const DailyTourCard({
    required this.isKu,
    required this.loading,
    required this.doneToday,
    required this.onStart,
    required this.onPractice,
    this.questionCount = 10,
    this.now,
    super.key,
  });

  final bool isKu;
  final bool loading;
  final bool doneToday;
  final VoidCallback onStart;
  final VoidCallback onPractice;
  final int questionCount;

  /// Testte sabit saat; verilmezse [DateTime.now].
  final DateTime? now;

  /// Bir sonraki yerel gün başına kalan süre ([now] gece yarısıysa 24 saat).
  static Duration untilNextTour(DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    final left = untilNextTour(now ?? DateTime.now());
    final eyebrow = Tr.forKu(K.bugununGorevi, isKu);
    final title = Tr.forKu(
      doneToday ? K.homeTourDoneTitle : K.dailyEvent,
      isKu,
    );
    final count = Tr.forKu(K.questionCount, isKu, {'count': '$questionCount'});
    final seconds = Tr.forKu(K.contestSeconds, isKu);
    final meta = doneToday
        ? Tr.forKu(K.homeTourNext, isKu, {
            'h': '${left.inHours}',
            'm': '${left.inMinutes % 60}',
          })
        : '$count · $kDailyEventSecondsPerQuestion $seconds';

    return KeyedSubtree(
      key: const ValueKey('home-daily-task'),
      child: SahneStageCard(
        role: SahneRole.race,
        child: Builder(
          builder: (context) {
            final t = SahneTokens.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  eyebrow,
                  style: SahneType.captionStrong.copyWith(color: t.raceTx),
                ),
                const SizedBox(height: SahneSpace.x1),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ),
                const SizedBox(height: SahneSpace.x1),
                Text(meta, style: SahneType.caption.copyWith(color: t.tx2)),
                const SizedBox(height: SahneSpace.x4),
                if (doneToday)
                  _action(
                    keyName: 'home-daily-task-practice',
                    label: Tr.forKu(K.homePractice, isKu),
                    onTap: onPractice,
                    primary: false,
                  )
                else
                  _action(
                    keyName: 'home-daily-task-start',
                    label: Tr.forKu(K.start, isKu),
                    onTap: onStart,
                    primary: true,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Ekran okuyucu düğümü ve yükleniyor hâli ana ekranın sözleşmesidir
  /// (eski `TodayTaskCard` düğmesiyle aynı).
  Widget _action({
    required String keyName,
    required String label,
    required VoidCallback onTap,
    required bool primary,
  }) {
    final enabled = !loading;
    final callback = enabled ? onTap : null;
    return Semantics(
      key: ValueKey(keyName),
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: callback,
      child: primary
          ? SahneButton.primary(label: label, onPressed: callback, expand: true)
          : SahneButton.secondary(
              label: label,
              onPressed: callback,
              expand: true,
            ),
    );
  }
}
