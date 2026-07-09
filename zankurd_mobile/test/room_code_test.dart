import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';

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
      final room = repository.joinRoom('  zk-1234  ');
      expect(room.code, 'ZK-1234');
    });

    test('joinOnlineRoom aynı normalizasyonu uygular', () async {
      final room = await repository.joinOnlineRoom('zk-9876');
      expect(room.code, 'ZK-9876');
    });

    test('zaten normalize kod değişmeden kalır', () {
      final room = repository.joinRoom('ZK-4821');
      expect(room.code, 'ZK-4821');
    });
  });

  group('oda oluşturma', () {
    test('yeni oda ZK- önekli kod üretir', () {
      final room = repository.createRoom(category: 'Ziman');
      expect(room.code, startsWith('ZK-'));
      expect(room.category, 'Ziman');
    });
  });
}
