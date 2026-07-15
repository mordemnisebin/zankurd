import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/room_message.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/room_chat.dart';

class _ChatRepository extends MockZanKurdRepository {
  final messages = StreamController<List<RoomMessage>>.broadcast();
  final sent = <String>[];

  @override
  String? get currentUserId => 'user1';

  @override
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId) =>
      messages.stream;

  @override
  Future<void> sendRoomMessage({
    required String roomId,
    required String text,
  }) async {
    sent.add(text);
  }

  void emit(String text, {String senderId = 'opponent'}) {
    messages.add([
      RoomMessage(
        id: 'message-${sent.length}',
        roomId: 'room-1',
        senderId: senderId,
        senderName: senderId == 'user1' ? 'Ben' : 'Heval',
        senderAvatarColor: '#E94560',
        text: text,
        createdAt: DateTime.utc(2026, 7, 13, 12),
      ),
    ]);
  }
}

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void main() {
  testWidgets('oda sohbeti realtime mesajı gösterir ve mesaj gönderebilir', (
    tester,
  ) async {
    final repository = _ChatRepository();
    addTearDown(repository.messages.close);

    await tester.pumpWidget(
      _shell(
        Scaffold(
          body: SizedBox(
            height: 320,
            child: RoomChat(
              repository: repository,
              roomId: 'room-1',
              visible: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    repository.emit('Slav heval!');
    await tester.pump();
    await tester.pump();
    expect(find.text('Slav heval!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ez baş im');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(repository.sent, ['Ez baş im']);
    expect(tester.takeException(), isNull);
  });
}
