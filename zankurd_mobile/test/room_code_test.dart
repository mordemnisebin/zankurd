import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

// Regression: kodla odaya katılırken girilen kod trim + büyük harfe
// normalize edilmeli; aksi halde " zk-1234 " gibi girişler sunucudaki
// kayıtla eşleşmez ve kullanıcı "odaya katılınamadı" hatası alır.
void main() {
  late MockZanKurdRepository repository;

  setUp(() {
    repository = MockZanKurdRepository();
  });

  group('oda kodu normalizasyonu', () {
    test('boşluklu ve küçük harfli kod normalize edilir', () {
      final room = repository.joinRoom('  zk-abcdef0123  ');
      expect(room.code, 'ZK-ABCDEF0123');
    });

    test('joinOnlineRoom aynı normalizasyonu uygular', () async {
      final room = await repository.joinOnlineRoom('zk-0123456789');
      expect(room.code, 'ZK-0123456789');
    });

    test('zaten normalize kod değişmeden kalır', () {
      final room = repository.joinRoom('ZK-ABCDEF0123');
      expect(room.code, 'ZK-ABCDEF0123');
    });
  });

  group('oda oluşturma', () {
    test('yeni oda 40-bit kanonik kod üretir', () {
      for (var i = 0; i < 100; i++) {
        final room = repository.createRoom(category: 'Ziman');
        expect(room.code, matches(RegExp(r'^ZK-[0-9A-F]{10}$')));
        expect(isCanonicalRoomCode(room.code), isTrue);
        expect(room.code.length, roomCodeLength);
        expect(room.category, 'Ziman');
      }
    });
  });
}
