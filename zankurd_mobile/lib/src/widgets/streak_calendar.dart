import 'package:flutter/material.dart';

import '../data/streak_store.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Ay takvimi: oynanan günler turuncu dolu, dondurulan/onarılan günler mavi
/// (kalkan), kaçırılan günler kesik çizgili halka.
///
/// ## Niçin renk tek kanal değil
///
/// Üç durum yalnız tonla ayrılsaydı renk körü oyuncu "oynadım" ile
/// "dondurdum" arasını göremezdi. Her durumun ayrıca bir biçimi vardır:
/// oynanan dolu zemin + ✓, dondurulan mavi zemin + kalkan, kaçırılan KESİK
/// çizgili boş halka, bugün Zêr halka. Ekran okuyucu her hücreyi
/// "12: Hate temamkirin" diye okur.
///
/// Bileşen sunumsaldır: günün durumunu [markFor]dan alır (depo ya da test
/// sahtesi). Ay gezintisi kendi içindedir; bugünün ayından ileriye ve
/// [maxMonthsBack] aydan geriye gidilmez.
class StreakCalendar extends StatefulWidget {
  const StreakCalendar({
    required this.markFor,
    required this.today,
    this.maxMonthsBack = 12,
    super.key,
  });

  final StreakCalendarMark Function(DateTime day) markFor;

  /// Bugün (yerel gün); testte enjekte edilir.
  final DateTime today;

  final int maxMonthsBack;

  @override
  State<StreakCalendar> createState() => _StreakCalendarState();
}

class _StreakCalendarState extends State<StreakCalendar> {
  /// Bugünün ayına göre kaydırma: 0 = bu ay, -1 = geçen ay.
  int _offset = 0;

  DateTime get _month =>
      DateTime(widget.today.year, widget.today.month + _offset);

  /// Pazartesi başlangıçlı ilk hücrenin boşluk sayısı (0..6).
  static int leadingBlanks(DateTime firstOfMonth) => firstOfMonth.weekday - 1;

  /// Ayın gün sayısı (ay 0. günüyle bir önceki ayın son günü).
  static int daysIn(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final month = _month;
    final names = context.t(K.streakMonthNames).split(',');
    final weekdays = context.t(K.streakWeekdays).split(',');
    final monthName = names.length == 12 ? names[month.month - 1] : '';
    final blanks = leadingBlanks(month);
    final days = daysIn(month);
    final cells = <Widget>[
      for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) _cell(context, month, d),
    ];

    return Semantics(
      container: true,
      label: context.t(K.streakCalendarTitle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                key: const ValueKey('streak-calendar-prev'),
                tooltip: context.t(K.streakCalPrevMonth),
                onPressed: _offset > -widget.maxMonthsBack
                    ? () => setState(() => _offset -= 1)
                    : null,
                icon: Icon(AppIcons.arrowLeft, size: 18, color: t.tx2),
              ),
              Expanded(
                child: Text(
                  '$monthName ${month.year}',
                  key: const ValueKey('streak-calendar-month'),
                  textAlign: TextAlign.center,
                  style: SahneType.headline.copyWith(color: t.tx),
                ),
              ),
              IconButton(
                key: const ValueKey('streak-calendar-next'),
                tooltip: context.t(K.streakCalNextMonth),
                onPressed: _offset < 0
                    ? () => setState(() => _offset += 1)
                    : null,
                icon: Icon(AppIcons.arrowRight, size: 18, color: t.tx2),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x2),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      i < weekdays.length ? weekdays[i] : '',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: SahneType.caption.copyWith(color: t.tx3),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SahneSpace.x1),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: SahneSpace.x1,
            crossAxisSpacing: SahneSpace.x1,
            children: cells,
          ),
          const SizedBox(height: SahneSpace.x3),
          const _Legend(),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, DateTime month, int d) {
    final mark = widget.markFor(DateTime(month.year, month.month, d));
    return _DayCell(day: d, mark: mark, stateLabel: _stateLabel(context, mark));
  }

  static String _stateLabel(BuildContext context, StreakCalendarMark mark) =>
      switch (mark) {
        StreakCalendarMark.played => context.t(K.streakDayStateCompleted),
        StreakCalendarMark.frozen => context.t(K.streakDayStateFrozen),
        StreakCalendarMark.missed => context.t(K.streakDayStateMissed),
        StreakCalendarMark.today => context.t(K.streakDayStateToday),
        StreakCalendarMark.upcoming => context.t(K.streakDayStateUpcoming),
        StreakCalendarMark.blank => '',
      };
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.mark,
    required this.stateLabel,
  });

  final int day;
  final StreakCalendarMark mark;
  final String stateLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final (Color? fill, Color fg, IconData? icon) = switch (mark) {
      StreakCalendarMark.played => (t.act, t.onAct, null),
      StreakCalendarMark.frozen => (t.nilFill, Colors.white, AppIcons.shield),
      StreakCalendarMark.today => (t.goldTint, t.goldTx, null),
      StreakCalendarMark.missed => (null, t.tx2, null),
      StreakCalendarMark.upcoming => (null, t.tx3, null),
      StreakCalendarMark.blank => (null, t.tx3, null),
    };

    final number = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text('$day', style: SahneType.captionStrong.copyWith(color: fg)),
    );

    Widget body = Center(
      child: icon == null
          ? number
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 10, color: fg),
                number,
              ],
            ),
    );

    body = switch (mark) {
      StreakCalendarMark.missed => CustomPaint(
        foregroundPainter: _DashedRing(color: t.tx3),
        child: body,
      ),
      StreakCalendarMark.today => DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shape: SahneShape.withSide(
            SahneShape.forSize(36),
            t.goldTx,
            width: SahneRing.r2,
          ),
        ),
        child: body,
      ),
      _ => DecoratedBox(
        decoration: ShapeDecoration(color: fill, shape: SahneShape.forSize(36)),
        child: body,
      ),
    };

    return Semantics(
      label: stateLabel.isEmpty ? '$day' : '$day: $stateLabel',
      child: ExcludeSemantics(child: body),
    );
  }
}

/// Kaçırılan günün kesik çizgili halkası.
class _DashedRing extends CustomPainter {
  const _DashedRing({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(8)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 3), paint);
        distance += 6;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    Widget item(Widget swatch, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: SahneSpace.x1),
        Flexible(
          child: Text(text, style: SahneType.caption.copyWith(color: t.tx2)),
        ),
      ],
    );
    Widget dot(Color color) => SizedBox.square(
      dimension: 12,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: color,
          shape: SahneShape.forSize(12),
        ),
      ),
    );
    return Wrap(
      spacing: SahneSpace.x4,
      runSpacing: SahneSpace.x1,
      children: [
        item(dot(t.act), context.t(K.streakDayStateCompleted)),
        item(dot(t.nilFill), context.t(K.streakDayStateFrozen)),
        item(
          SizedBox.square(
            dimension: 12,
            child: CustomPaint(foregroundPainter: _DashedRing(color: t.tx3)),
          ),
          context.t(K.streakDayStateMissed),
        ),
      ],
    );
  }
}
