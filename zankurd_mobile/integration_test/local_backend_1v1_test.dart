// Gerçek cihazdan GERÇEK backend'e karşı 1v1 sözleşmesi
// (integration_test).
//
// Çalıştırma (yerel Supabase gerekir):
//   flutter test integration_test/local_backend_1v1_test.dart \
//     -d <device> --dart-define-from-file=.env.mobile.local.json \
//     --dart-define=ZK_ROLE=host
//
// Diğer testlerin aksine burada `MockZanKurdRepository` YOKTUR: istemci
// gerçek `SupabaseZanKurdRepository` ile gerçek PostgreSQL'e konuşur.
// Ölçülen şey ekran değil, iki ayrı cihazın aynı sunucu oturumunda
// birbirini görmesi.
//
// Roller ayrı koşumlardır çünkü tek `flutter test` tek cihaza bağlanır:
// `host` odayı kurar ve kodu yazar; `guest` verilen kodla katılır. İki
// koşum EŞZAMANLI çalıştırıldığında gerçek çapraz platform maçı olur.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';

const _role = String.fromEnvironment('ZK_ROLE', defaultValue: 'host');
const _joinCode = String.fromEnvironment('ZK_ROOM_CODE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late SupabaseZanKurdRepository repository;

  setUpAll(() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    );
    repository = SupabaseZanKurdRepository(Supabase.instance.client);
  });

  testWidgets('Senaryo: gercek backend ile anonim oturum', (tester) async {
    final user = await repository.signInAnonymously();
    expect(user.id, isNotEmpty);
    await repository.ensureProfile();
    // İki cihaz iki AYRI kimlik almalı; aynı olurlarsa maç tek kişilik olur.
    // ignore: avoid_print
    print('ZK_USER_ID=${user.id}');
  });

  testWidgets(
    'Senaryo: rol=$_role ile oda akisi',
    (tester) async {
      await repository.signInAnonymously();
      await repository.ensureProfile();

      if (_role == 'host') {
        final room = await repository.createOnlineRoom(
          category: 'Ziman',
          secondsPerQuestion: 30,
        );
        expect(room.code, isNotEmpty);
        expect(room.id, isNotNull);
        // ignore: avoid_print
        print('ZK_ROOM_CODE=${room.code}');

        // Guest'i bekle: gerçek realtime/polling yolu.
        //
        // İki koşul birden aranır — katılım VE hazır olma. Yalnız oyuncu
        // sayısına bakıp başlatmak gerçek akışı taklit etmez: sunucu
        // "All players must be ready" ile reddeder ve guest'in `ready`
        // çağrısı odayı `active` bulup "Room is not in the lobby" alır.
        // Yarış test kurgusunun kendisinden doğar.
        var players = <Player>[];
        for (var i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          players = await repository.loadRoomPlayers(room);
          if (players.length >= 2 &&
              players.every((p) => p.state == Player.readyState)) {
            break;
          }
        }
        expect(players.length, 2, reason: 'guest odaya katilmadi');
        expect(
          players.every((p) => p.state == Player.readyState),
          isTrue,
          reason: 'oyuncular hazir olmadi',
        );

        await repository.startGame(room);
        final questions = await repository.loadRoomQuestions(room);
        expect(questions, isNotEmpty);
        // ignore: avoid_print
        print('ZK_HOST_QUESTIONS=${questions.length}');
        // ignore: avoid_print
        print('ZK_HOST_Q0=${questions.first.id}');
      } else {
        expect(_joinCode, isNotEmpty, reason: 'ZK_ROOM_CODE verilmedi');
        final room = await repository.joinOnlineRoom(_joinCode);
        expect(room.id, isNotNull);

        // `join_room_by_code` katılanı zaten hazır ekliyor. Koşulsuz bir
        // `updateReady` çağrısı yalnız gereksiz değil, zararlı: host tüm
        // oyuncular hazır olur olmaz başlatır ve bu çağrı odayı `active`
        // bulup "Room is not in the lobby" ile döner. Gerçek uygulamada
        // anahtar kullanıcı dokunuşuna bağlıdır; burada da yalnız gerçekten
        // gerekiyorsa çağrılır.
        final me = repository.currentUserId;
        final joined = await repository.loadRoomPlayers(room);
        final alreadyReady = joined.any(
          (p) => p.id == me && p.state == Player.readyState,
        );
        if (!alreadyReady) {
          await repository.updateReady(room, true);
        }

        // Host'un baslatmasini bekle.
        GameRoom? live;
        for (var i = 0; i < 300; i++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          live = await repository.loadRoomSnapshot(room.id!);
          if (live.status == RoomStatus.active) break;
        }
        expect(live?.status, RoomStatus.active, reason: 'host baslatmadi');

        final questions = await repository.loadRoomQuestions(room);
        expect(questions, isNotEmpty);
        // ignore: avoid_print
        print('ZK_GUEST_QUESTIONS=${questions.length}');
        // ignore: avoid_print
        print('ZK_GUEST_Q0=${questions.first.id}');
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
