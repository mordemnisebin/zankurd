import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

/// Kusur: `joinOnlineRoom` başarısız olduğunda GERÇEK SEBEP ne olursa olsun
/// (oda dolu, kullanıcı zaten başka bir odada, ağ hatası...) ekran tek bir
/// `K.roomNotFound` ("Bu kodla oda bulunamadı.") metnine düşüyordu.
///
/// Sunucu tarafı (`join_room_by_code`, bkz.
/// `supabase/2026-08-02_multiplayer_session_hardening.sql`) farklı
/// sebepler için farklı düz metin istisnalar fırlatıyor ama istemci hiçbirini
/// okumuyordu. Düzeltme iki parçalı:
///
///   1. `roomJoinFailureReasonForMessage` (repository katmanı, saf fonksiyon)
///      ham RPC mesajını bir `RoomJoinFailureReason`a çevirir.
///   2. `joinRoomErrorKey` (UI katmanı, saf fonksiyon) o sebebi gösterilecek
///      K.* anahtarına çevirir; `RoomJoinException` DEĞİLSE (ağ/bilinmeyen
///      hata) KASITLI olarak "bulunamadı" DEMEZ — jenerik bir metne düşer,
///      çünkü oda gerçekten var olabilir.
void main() {
  group('roomJoinFailureReasonForMessage', () {
    test('dolu oda mesajını full olarak tanır', () {
      expect(
        roomJoinFailureReasonForMessage('Room is full'),
        RoomJoinFailureReason.full,
      );
    });

    test(
      'zaten başka odada olma mesajını alreadyInAnotherRoom olarak tanır',
      () {
        expect(
          roomJoinFailureReasonForMessage(
            'Player is already in another live room',
          ),
          RoomJoinFailureReason.alreadyInAnotherRoom,
        );
      },
    );

    test('bulunamadı/başlamış mesajını notFound olarak tanır', () {
      expect(
        roomJoinFailureReasonForMessage('Room not found or already started'),
        RoomJoinFailureReason.notFound,
      );
    });

    test('tanınmayan bir mesaj unknown döner', () {
      expect(
        roomJoinFailureReasonForMessage('Not authenticated'),
        RoomJoinFailureReason.unknown,
      );
    });
  });

  group('joinRoomErrorKey', () {
    test('RoomJoinException(full) → K.roomFull', () {
      expect(
        joinRoomErrorKey(
          const RoomJoinException(RoomJoinFailureReason.full, 'Room is full'),
        ),
        K.roomFull,
      );
    });

    test(
      'RoomJoinException(alreadyInAnotherRoom) → K.roomAlreadyInAnotherRoom',
      () {
        expect(
          joinRoomErrorKey(
            const RoomJoinException(
              RoomJoinFailureReason.alreadyInAnotherRoom,
              'Player is already in another live room',
            ),
          ),
          K.roomAlreadyInAnotherRoom,
        );
      },
    );

    test('RoomJoinException(notFound) → K.roomNotFound', () {
      expect(
        joinRoomErrorKey(
          const RoomJoinException(
            RoomJoinFailureReason.notFound,
            'Room not found or already started',
          ),
        ),
        K.roomNotFound,
      );
    });

    test(
      'RoomJoinException(unknown) → K.roomJoinFailed (yanlış kesinlik YOK)',
      () {
        expect(
          joinRoomErrorKey(
            const RoomJoinException(RoomJoinFailureReason.unknown, 'huh?'),
          ),
          K.roomJoinFailed,
        );
      },
    );

    test('RoomJoinException OLMAYAN bir hata (ör. ağ) → K.roomJoinFailed, '
        'ASLA K.roomNotFound değil', () {
      expect(
        joinRoomErrorKey(StateError('network unreachable')),
        K.roomJoinFailed,
      );
      expect(
        joinRoomErrorKey(StateError('network unreachable')),
        isNot(K.roomNotFound),
      );
    });
  });
}
