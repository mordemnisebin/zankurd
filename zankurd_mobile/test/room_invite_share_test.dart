/// Oda lobisinden tek dokunuşla davet.
///
/// ## Kusur
///
/// Odaya arkadaş çağırmanın tek yolu kodu kopyalamaktı. Kod `ZK-` + on
/// karakterdir; oyuncu onu panodan bir mesajlaşma uygulamasına kendisi
/// taşımalı, karşı taraf da uygulamayı açıp elle yazmalıydı. Benzer
/// uygulamalarda (TRT Bil Bakalım'ın "karşılıklı" modu, Kahoot) arkadaş
/// oyununu yaşatan şey tam da bu çağrının zahmetsiz olmasıdır.
///
/// ## Niçin sessiz kalırdı
///
/// `JoinDeepLink.shareUrl` zaten yazılıydı ve web sürümü
/// `zankurd.com/join/<kod>` yolunu açınca odaya doğrudan katılıyordu —
/// ama uygulamada bu bağlantıyı üreten tek bir düğme yoktu. Kod ve
/// bağlantı ayrı ayrı doğruydu; aradaki köprü hiçbir testin konusu değildi.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/utils/join_deep_link.dart';

import 'support/widget_test_helpers.dart';

void main() {
  // share_plus'ın platform kanalı; paylaşım sayfası yerine çağrıyı yakalar.
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  testWidgets('davet düğmesi oda bağlantısını ve kodu paylaşır', (
    tester,
  ) async {
    final shared = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          if (call.method == 'share') {
            shared.add(call.arguments as Map<Object?, Object?>);
          }
          return 'dev.fluttercommunity.plus/share/unavailable';
        });

    final repository = freshMockRepository();
    final room = repository.createRoom();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: RoomScreen(repository: repository, initialRoom: room),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final invite = find.byKey(const ValueKey('room-invite-share'));
    expect(invite, findsOneWidget);
    expect(find.text('Arkadaşlarını davet et'), findsOneWidget);

    await tester.ensureVisible(invite);
    await tester.tap(invite);
    await tester.pump();

    expect(shared, hasLength(1));
    final text = shared.single['text'] as String;
    expect(text, contains(JoinDeepLink.shareUrl(room.code)));
    expect(text, contains(room.code));
    // Bağlantının kendisi web sürümünde odaya giden yoldur; yol biçimi
    // değişirse davetler sessizce ana sayfaya düşer.
    expect(JoinDeepLink.parse('/join/${room.code}'), room.code);
  });
}
