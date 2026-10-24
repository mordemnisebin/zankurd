// Bekçi: hazır tepkiler karşıya gitmiyordu ve oda sohbeti ters akıyordu
// (2026-10-21, iki oyunculu gerçek denemede).
//
// Kusur 1: `RealtimeChannel.send` (realtime_client 2.13) verilen yük
// haritasına `type = 'broadcast'` yazar; ekranların `{'type': 'reaction'}`
// anahtarı telde ezilir, alıcıda `payload['type'] == 'reaction'` hiç
// tutmaz. Gönderim "başarılı" görünür, hata yoktur — bu yüzden sessizdi.
// Çözüm: `kind` anahtarı ezilmez, alıcı geri yazar.
//
// Kusur 2: `.stream(...).order('created_at')` varsayılan AZALANDIR; liste
// yeniden-eskiye geliyor, ListView'in en altı en ESKİ mesajı gösteriyordu.
// Çözüm: `ascending: true` ve arayüzde ayrıca kararlı sıralama.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/room_message.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/room_chat.dart';

class _Repo extends MockZanKurdRepository {
  final messages = StreamController<List<RoomMessage>>.broadcast();
  @override
  String? get currentUserId => 'me';
  @override
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId) =>
      messages.stream;
}

RoomMessage _m(String id, String sender, int minute, String text) =>
    RoomMessage(
      id: id,
      roomId: 'r',
      senderId: sender,
      senderName: sender == 'me' ? 'Ben' : 'Heval',
      text: text,
      createdAt: DateTime.utc(2026, 10, 21, 12, minute),
    );

void main() {
  test('tepki yükü kütüphanenin type ezmesinden sağ çıkar', () {
    final sent = encodeRoomBroadcast({
      'type': 'reaction',
      'text': 'Bravo',
      'sender_id': 'a',
    });
    // Kütüphanenin yaptığını taklit et.
    sent['type'] = 'broadcast';
    sent['event'] = 'game_event';
    final received = decodeRoomBroadcast(sent);
    expect(received['type'], 'reaction');
    expect(received['text'], 'Bravo');
    expect(received['sender_id'], 'a');
  });

  test('REST yedeğinin iç içe yükü düzleştirilir', () {
    final received = decodeRoomBroadcast({
      'type': 'broadcast',
      'event': 'game_event',
      'payload': {'kind': 'reaction', 'text': 'x', 'type': 'broadcast'},
    });
    expect(received['type'], 'reaction');
    expect(received['text'], 'x');
  });

  test('type taşımayan yük (hazır/cevap) olduğu gibi kalır', () {
    final enc = encodeRoomBroadcast({'ready': true, 'sender': 'Ben'});
    expect(enc.containsKey('kind'), isFalse);
    expect(decodeRoomBroadcast(enc)['ready'], true);
  });

  test('depo yayını kodlayıp çözüyor, akış sırası artan', () {
    final src = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    expect(src, contains('payload: encodeRoomBroadcast(payload)'));
    expect(src, contains('controller.add(decodeRoomBroadcast(payload))'));
    expect(src, contains(".order('created_at', ascending: true)"));
  });

  test('orderChatMessages eski üstte yeni altta dizer', () {
    final sorted = orderChatMessages([
      _m('c', 'me', 3, 'üç'),
      _m('a', 'x', 1, 'bir'),
      _m('b', 'x', 2, 'iki'),
    ]);
    expect(sorted.map((m) => m.text), ['bir', 'iki', 'üç']);
  });

  testWidgets('yeniden-eskiye gelen akış ekranda eski üstte çizilir', (
    tester,
  ) async {
    final repo = _Repo();
    addTearDown(repo.messages.close);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider()..setLang('tr'),
          ),
          ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              height: 320,
              child: RoomChat(repository: repo, roomId: 'r', visible: true),
            ),
          ),
        ),
      ),
    );
    repo.messages.add([
      _m('3', 'me', 3, 'EN-YENI'),
      _m('2', 'x', 2, 'ORTA'),
      _m('1', 'x', 1, 'EN-ESKI'),
    ]);
    await tester.pumpAndSettle();
    final old = tester.getTopLeft(find.text('EN-ESKI')).dy;
    final mid = tester.getTopLeft(find.text('ORTA')).dy;
    final fresh = tester.getTopLeft(find.text('EN-YENI')).dy;
    expect(old < mid && mid < fresh, isTrue);
    // Kendi mesajın sağda, ötekinin solda.
    expect(
      tester.getTopLeft(find.text('EN-YENI')).dx >
          tester.getTopLeft(find.text('EN-ESKI')).dx,
      isTrue,
    );
  });
}
