import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/league_tier.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

void main() {
  group('LeagueTier.forRank', () {
    test('ilk 10 Zêr, 11-25 Zîv, gerisi Bronz', () {
      expect(LeagueTier.forRank(1), LeagueTier.zer);
      expect(LeagueTier.forRank(10), LeagueTier.zer);
      expect(LeagueTier.forRank(11), LeagueTier.ziv);
      expect(LeagueTier.forRank(25), LeagueTier.ziv);
      expect(LeagueTier.forRank(26), LeagueTier.bronz);
      expect(LeagueTier.forRank(100), LeagueTier.bronz);
    });

    test('sıralamada olmayan oyuncu Bronz başlar', () {
      expect(LeagueTier.forRank(null), LeagueTier.bronz);
      expect(LeagueTier.forRank(0), LeagueTier.bronz);
      expect(LeagueTier.forRank(-3), LeagueTier.bronz);
    });

    test('etiketler iki dilde de dolu', () {
      for (final tier in LeagueTier.values) {
        expect(tier.label(true), isNotEmpty);
        expect(tier.label(false), isNotEmpty);
      }
    });
  });

  group('RojMascot', () {
    testWidgets('her ruh hâlinde hatasız çizilir', (tester) async {
      for (final mood in RojMood.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(child: RojMascot(size: 96, mood: mood)),
          ),
        );
        expect(find.byKey(const ValueKey('roj-mascot')), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
