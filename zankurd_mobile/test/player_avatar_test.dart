import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

// 1x1 şeffaf PNG — ağ olmadan Image testi için.
final _tinyPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  Widget shell(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('photoUrl doluyken Image gösterilir', (tester) async {
    await tester.pumpWidget(
      shell(
        PlayerAvatar(
          radius: 30,
          photoUrl: 'https://example.com/a.jpg',
          displayName: 'Test',
          imageProviderFactory: (_) => MemoryImage(_tinyPng),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('T'), findsNothing);
  });

  // Codex denetimi 2026-10-29 (performans #7): avatar sağlayıcısında çözme
  // boyutu sınırı yoktu; büyük kaynak fotoğraf küçük çizilse de tam
  // çözünürlükte belleğe açılıyordu.
  testWidgets('avatar fotoğrafı çizilen boyuta göre küçültülerek çözülür', (
    tester,
  ) async {
    await tester.pumpWidget(
      shell(
        PlayerAvatar(
          radius: 30,
          photoUrl: 'https://example.com/a.jpg',
          displayName: 'Test',
          imageProviderFactory: (_) => MemoryImage(_tinyPng),
        ),
      ),
    );
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    final resize = image.image as ResizeImage;
    expect(resize.width, isNotNull);
    expect(resize.width!, lessThanOrEqualTo(512));
  });

  testWidgets('photoUrl yok, iconId varsa Icon gösterilir', (tester) async {
    await tester.pumpWidget(
      shell(
        const PlayerAvatar(radius: 30, iconId: 'tembur', displayName: 'Test'),
      ),
    );
    expect(find.byIcon(AppIcons.music), findsOneWidget);
    expect(find.text('T'), findsNothing);
  });

  testWidgets('ikisi de yoksa baş harf gösterilir', (tester) async {
    await tester.pumpWidget(
      shell(const PlayerAvatar(radius: 30, displayName: 'Rojda')),
    );
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('bilinmeyen iconId harf fallback yapar', (tester) async {
    await tester.pumpWidget(
      shell(
        const PlayerAvatar(radius: 30, iconId: 'gecersiz', displayName: 'Zana'),
      ),
    );
    expect(find.text('Z'), findsOneWidget);
  });

  testWidgets('frameId doluysa çerçeve halkası çizilir', (tester) async {
    await tester.pumpWidget(
      shell(
        const PlayerAvatar(
          radius: 34,
          iconId: 'roj',
          frameId: 'gold',
          displayName: 'Test',
        ),
      ),
    );
    expect(find.byKey(const ValueKey('avatar-frame-ring')), findsOneWidget);
  });

  testWidgets('çerçevesizken halka yok', (tester) async {
    await tester.pumpWidget(
      shell(const PlayerAvatar(radius: 34, iconId: 'roj', displayName: 'T')),
    );
    expect(find.byKey(const ValueKey('avatar-frame-ring')), findsNothing);
  });

  testWidgets('yer tutucu ad O harfi değil kişi ikonu gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      shell(const PlayerAvatar(radius: 30, displayName: 'Oyuncu')),
    );
    expect(find.text('O'), findsNothing);
    expect(find.byIcon(AppIcons.user), findsOneWidget);
  });

  // 2026-10-19 sadeleşme: `SahneShape.m/l` yuvarlak oldu; avatar marka
  // aksanı olarak pahlı kalır (`chamferM/chamferL`, `forSize`).
  // 2026-09-29 doğallık (K5): avatar elmas değil, boyuna uygun pahlı kare.
  // Elmas yalnız soru ilerlemesi ve ders sayacında kalır; avatar da elmas
  // olunca şekil hiçbir şey anlatmıyordu ve fotoğrafın yarısı kesiliyordu.
  for (final (radius, shape) in [
    (12.0, SahneShape.s),
    (20.0, SahneShape.chamferM),
    (48.0, SahneShape.chamferL),
  ]) {
    testWidgets('avatar ${radius * 2} px: pahlı kare, elmas değil', (
      tester,
    ) async {
      await tester.pumpWidget(
        shell(
          Center(
            child: PlayerAvatar(radius: radius, displayName: 'Ali'),
          ),
        ),
      );
      final clip = tester.widget<ClipPath>(
        find.descendant(
          of: find.byType(PlayerAvatar),
          matching: find.byType(ClipPath),
        ),
      );
      final border =
          (clip.clipper! as ShapeBorderClipper).shape as BeveledRectangleBorder;
      expect(border.borderRadius, shape.borderRadius);
      expect(
        border.borderRadius,
        isNot(BorderRadius.all(Radius.circular(radius))),
        reason: 'yarı kenar pahı elmastır',
      );
    });
  }

  // 2026-10-25: arkadaş VIP ve neon çerçeve aldı, başkalarının gözünde
  // hiçbir şey değişmedi — çerçeve bronzla aynı 3 px kenardı, VIP yalnız
  // profil metniydi.
  group('satın alınan görünüm', () {
    for (final id in ['gold', 'neon']) {
      testWidgets('$id çerçeve çift kontur çizer', (tester) async {
        await tester.pumpWidget(
          shell(PlayerAvatar(radius: 18, frameId: id, displayName: 'Zana')),
        );
        expect(
          find.byKey(const ValueKey('avatar-frame-premium')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('avatar-frame-ring')), findsOneWidget);
      });
    }

    testWidgets('bronz çerçeve tek halka kalır', (tester) async {
      await tester.pumpWidget(
        shell(
          const PlayerAvatar(
            radius: 18,
            frameId: 'bronze',
            displayName: 'Zana',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('avatar-frame-premium')), findsNothing);
      expect(find.byKey(const ValueKey('avatar-frame-ring')), findsOneWidget);
    });

    testWidgets('büyük avatarda VIP yazılı rozet', (tester) async {
      await tester.pumpWidget(
        shell(
          const PlayerAvatar(
            radius: 32,
            showcaseTitle: 'VIP',
            displayName: 'Zana',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('avatar-vip-badge')), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
    });

    testWidgets('küçük avatarda yazısız VIP mührü', (tester) async {
      await tester.pumpWidget(
        shell(
          const PlayerAvatar(
            radius: 14,
            showcaseTitle: 'VIP',
            displayName: 'Zana',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('avatar-vip-badge')), findsOneWidget);
      expect(find.text('VIP'), findsNothing);
      expect(find.byIcon(AppIcons.gem), findsOneWidget);
    });

    testWidgets('başka unvanda VIP rozeti yok', (tester) async {
      await tester.pumpWidget(
        shell(
          const PlayerAvatar(
            radius: 32,
            showcaseTitle: 'Pispor',
            displayName: 'Zana',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('avatar-vip-badge')), findsNothing);
    });

    testWidgets('çok küçük premium avatar tek halkaya düşer', (tester) async {
      for (final r in [1.0, 4.0, 9.0]) {
        await tester.pumpWidget(
          shell(PlayerAvatar(radius: r, frameId: 'gold', displayName: 'Z')),
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('avatar-frame-premium')),
          findsNothing,
        );
      }
    });

    testWidgets('fromIdentity VIP unvanını taşır', (tester) async {
      await tester.pumpWidget(
        shell(
          PlayerAvatar.fromIdentity(
            radius: 18,
            identity: const AvatarIdentity(
              frameId: 'neon',
              showcaseTitle: 'VIP',
            ),
            displayName: 'Zana',
          ),
        ),
      );
      expect(find.byKey(const ValueKey('avatar-vip-badge')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('avatar-frame-premium')),
        findsOneWidget,
      );
    });
  });
}
