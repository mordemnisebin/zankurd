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

    test('6 rakamlı kod boşluklu, tireli ve bağlantıyla da katılır', () {
      for (final typed in [
        '482913',
        '482 913',
        ' 482-913 ',
        'https://www.zankurd.com/join/482913',
      ]) {
        expect(repository.joinRoom(typed).code, '482913', reason: typed);
      }
    });

    test('zaten normalize kod değişmeden kalır', () {
      final room = repository.joinRoom('ZK-ABCDEF0123');
      expect(room.code, 'ZK-ABCDEF0123');
    });
  });

  group('oda oluşturma', () {
    test('yeni oda 6 rakamlı kanonik kod üretir', () {
      for (var i = 0; i < 100; i++) {
        final room = repository.createRoom(category: 'Ziman');
        expect(room.code, matches(RegExp(r'^[1-9][0-9]{5}$')));
        expect(isCanonicalRoomCode(room.code), isTrue);
        expect(room.code.length, roomCodeLength);
        expect(room.category, 'Ziman');
      }
    });
  });
}
