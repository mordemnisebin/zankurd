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

/// Her abonelikte yeni bir akış veren ve abonelik sayısını tutan depo.
class _ReconnectChatRepository extends MockZanKurdRepository {
  final controllers = <StreamController<List<RoomMessage>>>[];

  int get subscriptions => controllers.length;

  @override
  String? get currentUserId => 'user1';

  @override
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId) {
    final controller = StreamController<List<RoomMessage>>();
    controllers.add(controller);
    return controller.stream;
  }

  Future<void> closeAll() async {
    for (final c in controllers) {
      if (!c.isClosed) await c.close();
    }
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
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: SizedBox(height: 320, child: child)),
    ),
  );
}

/// Sohbet akışı kapanınca ya da hata verince panel donmaz: kısa bir
/// gecikmeyle yeniden abone olunur; widget kaldırıldıysa olunmaz.
void main() {
  Future<void> pumpChat(
    WidgetTester tester,
    _ReconnectChatRepository repository,
  ) async {
    await tester.pumpWidget(
      _shell(RoomChat(repository: repository, roomId: 'room-1', visible: true)),
    );
    await tester.pump();
  }

  testWidgets('akış kapanınca gecikmeyle yeniden abone olur', (tester) async {
    final repository = _ReconnectChatRepository();
    addTearDown(repository.closeAll);
    await pumpChat(tester, repository);
    expect(repository.subscriptions, 1);

    await repository.controllers.first.close();
    await tester.pump();
    // Hemen değil: hızlı döngü olmasın.
    expect(repository.subscriptions, 1);

    await tester.pump(const Duration(seconds: 3));
    expect(repository.subscriptions, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('akış hatası da (hata + kapanış) tek yeniden abonelik açar', (
    tester,
  ) async {
    final repository = _ReconnectChatRepository();
    addTearDown(repository.closeAll);
    await pumpChat(tester, repository);

    final first = repository.controllers.first;
    first.addError(Exception('kanal düştü'));
    unawaited(first.close());
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(repository.subscriptions, 2);

    await tester.pump(const Duration(seconds: 10));
    expect(repository.subscriptions, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('dispose sonrası yeniden abone olunmaz', (tester) async {
    final repository = _ReconnectChatRepository();
    addTearDown(repository.closeAll);
    await pumpChat(tester, repository);

    await repository.controllers.first.close();
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(repository.subscriptions, 1);
  });
}
