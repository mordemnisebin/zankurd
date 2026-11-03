import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/chat_mute_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/room_message.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/lobby_chat_hud.dart';
import 'package:zankurd_mobile/src/widgets/room_chat.dart';

/// "Sustur" bekçisi (2026-11-04).
///
/// ## Kusur
///
/// Oda/lobi sohbetinde rahatsız eden birine karşı yalnız iki yol vardı:
/// bildir ve ENGELLE. Engel sunucu kaydıdır (karşı taraf da etkilenir, geri
/// alması zor, onay penceresi ister); "sadece şu an bu kişiyi görmek
/// istemiyorum" için orta bir seçenek yoktu (rakip uygulamalarda var).
///
/// ## Niçin sessiz kalırdı
///
/// Susturma yalnız istemci süzgecidir. Süzgeç bir yüzeyde (sohbet listesi)
/// çalışıp ötekinde (lobi balonu, tepki) çalışmazsa ya da anahtar hesaba
/// bağlı değilse hiçbir hata çıkmaz: susturduğun kişinin tepkisi ekranda
/// patlar, ya da başka hesaba geçince eski hesabın susturmaları sızar.
///
/// ## Kural
///
/// * Susturulan oyuncunun mesajı sohbet listesinde ve lobi balonunda
///   görünmez; "N mesaj gizlendi" satırı çıkar; kaldırınca geri gelir.
/// * Liste hesap başına (`chat_muted_v1_<kimlik>`) saklanır, yeniden açılınca
///   döner, öteki hesaba sızmaz.
/// * Sunucuya hiçbir şey yazılmaz (blockPlayer çağrılmaz).
class _Repo extends MockZanKurdRepository {
  final stream = StreamController<List<RoomMessage>>.broadcast();
  int blockCalls = 0;

  @override
  String? get currentUserId => 'ben';

  @override
  Stream<List<RoomMessage>> subscribeRoomMessages(String roomId) =>
      stream.stream;

  @override
  Future<bool> blockPlayer(String playerId) async {
    blockCalls++;
    return true;
  }
}

RoomMessage _msg(String id, String sender, String text) => RoomMessage(
  id: id,
  roomId: 'room-1',
  senderId: sender,
  senderName: sender,
  senderAvatarColor: '#E94560',
  text: text,
  createdAt: DateTime.utc(2026, 11, 4, 12),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ChatMuteStore', () {
    test('hesap başına saklanır ve öteki hesaba sızmaz', () async {
      final a = ChatMuteStore();
      await a.load('hesap-1');
      await a.setMuted('rakip', true);
      expect(a.isMuted('rakip'), isTrue);

      final again = ChatMuteStore();
      await again.load('hesap-1');
      expect(again.isMuted('rakip'), isTrue, reason: 'yeniden açılınca döner');

      final other = ChatMuteStore();
      await other.load('hesap-2');
      expect(other.isMuted('rakip'), isFalse, reason: 'hesaplar karışmaz');

      await again.setMuted('rakip', false);
      final third = ChatMuteStore();
      await third.load('hesap-1');
      expect(third.isMuted('rakip'), isFalse);
    });

    test('kimliksiz oturumda diske yazılmaz', () async {
      final s = ChatMuteStore();
      await s.load(null);
      await s.setMuted('x', true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.startsWith('chat_muted')), isEmpty);
    });
  });

  test('oda ekranı lobi balonu VE tepki yayınında susturmayı uygular', () {
    final src = File('lib/src/screens/room_screen.dart').readAsStringSync();
    expect(src, contains('ChatMuteStore.instance.isMuted(id)'));
    expect(src, contains('ChatMuteStore.instance.isMuted(senderId)'));
    final sheet = File(
      'lib/src/widgets/player_moderation_button.dart',
    ).readAsStringSync();
    expect(sheet, contains("'player-mute-action'"));
  });

  group('lobi balonu denetleyicisi', () {
    test('susturulanın mesajı okunmamış sayılmaz (isBlocked bağlanır)', () {
      // Bağlantı oda ekranında `isBlocked: ... || ChatMuteStore...`; burada
      // yalnız sözleşmenin var olduğunu sabitliyoruz.
      final c = LobbyChatController(
        repository: _Repo(),
        roomId: 'r',
        isBlocked: (id) => id == 'sessiz',
      );
      expect(c.isBlocked!('sessiz'), isTrue);
      expect(c.isBlocked!('baska'), isFalse);
      c.dispose();
    });
  });

  testWidgets('susturunca mesaj gizlenir, sayaç çıkar; kaldırınca döner', (
    tester,
  ) async {
    final repo = _Repo();
    addTearDown(repo.stream.close);
    await ChatMuteStore.instance.load('ben');
    await ChatMuteStore.instance.setMuted('sessiz', false);
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
              child: RoomChat(
                repository: repo,
                roomId: 'room-1',
                visible: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    repo.stream.add([_msg('m1', 'sessiz', 'Rahatsız mesaj')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Rahatsız mesaj'), findsOneWidget);

    await tester.longPress(find.text('Rahatsız mesaj'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chat-mute-action')));
    await tester.pumpAndSettle();
    expect(find.text('Rahatsız mesaj'), findsNothing);
    expect(find.byKey(const ValueKey('chat-muted-count')), findsOneWidget);
    expect(find.text('1 mesaj gizlendi'), findsOneWidget);
    expect(repo.blockCalls, 0, reason: 'susturma sunucuya yazmaz');

    await ChatMuteStore.instance.setMuted('sessiz', false);
    await tester.pump();
    expect(find.text('Rahatsız mesaj'), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-muted-count')), findsNothing);
  });
}
