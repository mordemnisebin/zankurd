import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';

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

  testWidgets('photoUrl yok, iconId varsa Icon gösterilir', (tester) async {
    await tester.pumpWidget(
      shell(
        const PlayerAvatar(radius: 30, iconId: 'tembur', displayName: 'Test'),
      ),
    );
    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('avatar-frame-ring')),
      findsOneWidget,
    );
  });

  testWidgets('çerçevesizken halka yok', (tester) async {
    await tester.pumpWidget(
      shell(const PlayerAvatar(radius: 34, iconId: 'roj', displayName: 'T')),
    );
    expect(find.byKey(const ValueKey('avatar-frame-ring')), findsNothing);
  });
}
