import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';

/// Oyunlaştırma bileşenlerinin kullanıcıya verdiği sözleşmeler.
///
/// Bu testler pikselleri değil KURALLARI sabitler: ekonomilerin birbirine
/// karışmaması, rengin tek bilgi kanalı olmaması ve sunucudan sonuç
/// gelmeden başarı gösterilmemesi.
Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('RewardToken', () {
    test('coin, XP ve streak birbirinden ayrı renk taşır', () {
      // Üçü aynı sarı sayı olarak çizildiğinde oyuncu üç farklı ekonomiyi
      // tek bir şey sanıyordu.
      final tones = {
        RewardKind.coin.color,
        RewardKind.xp.color,
        RewardKind.streak.color,
        RewardKind.level.color,
        RewardKind.rank.color,
      };
      expect(tones, hasLength(5));
    });

    test('her ödül türünün ayrı ikonu vardır', () {
      // Renk tek kanal olamaz: renk körü kullanıcı ikondan ayırmalı.
      final icons = RewardKind.values.map((k) => k.icon).toSet();
      expect(icons, hasLength(RewardKind.values.length));
    });

    testWidgets('değer ve etiket ekran okuyucuya tek parça gider', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const RewardToken(kind: RewardKind.coin, value: '30', label: 'c'),
        ),
      );
      expect(find.bySemanticsLabel('30 c'), findsOneWidget);
    });
  });

  group('ArenaStatusChip', () {
    testWidgets('her durum ayrı ikon taşır — renk tek kanal değil', (
      tester,
    ) async {
      final icons = <IconData>{};
      for (final status in ArenaStatus.values) {
        await tester.pumpWidget(
          _wrap(ArenaStatusChip(status: status, label: 'x')),
        );
        icons.add(tester.widget<Icon>(find.byType(Icon)).icon!);
      }
      expect(
        icons,
        hasLength(ArenaStatus.values.length),
        reason: 'iki durum aynı ikonu paylaşırsa renk tek kanal olur',
      );
    });

    testWidgets('uzun Kurmancî etiketi taşmaz', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 120,
            child: ArenaStatusChip(
              status: ArenaStatus.upcoming,
              label: 'Pêşbirk hîn dest pê nekiriye',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('MissionProgressCard', () {
    testWidgets('ilerleme sayıyla da anlatılır', (tester) async {
      // Yalnız renkli çubuk yeterli değil; oran metin olarak da okunmalı.
      await tester.pumpWidget(
        _wrap(
          const MissionProgressCard(
            title: 'Erk',
            current: 2,
            target: 3,
            accent: Color(0xFF1E4FA6),
            icon: Icons.star,
          ),
        ),
      );
      expect(find.text('2/3'), findsOneWidget);
    });

    testWidgets('claim yükleniyorken düğme kilitlidir', (tester) async {
      // Sunucudan sonuç gelmeden başarı gösterilmemeli.
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          MissionProgressCard(
            title: 'Erk',
            current: 3,
            target: 3,
            accent: const Color(0xFF1E4FA6),
            icon: Icons.star,
            claiming: true,
            onClaim: () => taps++,
          ),
        ),
      );
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(taps, 0);
    });

    testWidgets('tamamlanmamış görev claim düğmesi göstermez', (tester) async {
      await tester.pumpWidget(
        _wrap(
          MissionProgressCard(
            title: 'Erk',
            current: 1,
            target: 3,
            accent: const Color(0xFF1E4FA6),
            icon: Icons.star,
            onClaim: () {},
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('RankMedal', () {
    testWidgets('sıra numarası her zaman yazıyla da görünür', (tester) async {
      // Podyum rengi tek başına sırayı anlatmaz.
      for (final rank in [1, 2, 3, 12]) {
        await tester.pumpWidget(_wrap(RankMedal(rank: rank)));
        expect(find.text('$rank'), findsOneWidget);
      }
    });
  });

  group('ArenaHero', () {
    testWidgets('dark temada taşmadan çizilir', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 320,
            child: ArenaHero(
              title: 'Pêşbirka rojane ya ZanKurdê',
              subtitle: 'Her roj di saet 20:00an de dest pê dike',
              accent: Color(0xFF6A38BE),
              icon: Icons.emoji_events,
              tokens: [
                RewardToken(kind: RewardKind.coin, value: '100', onSolid: true),
                RewardToken(kind: RewardKind.xp, value: '250', onSolid: true),
              ],
            ),
          ),
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% yazıda taşmaz', (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(390, 844) * 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: ArenaHero(
                title: 'Turnuva',
                subtitle: 'Gerçek oyuncularla eleme',
                accent: Color(0xFF0E7A57),
                icon: Icons.emoji_events,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
