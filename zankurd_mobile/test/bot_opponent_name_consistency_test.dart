import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

/// Kusur: bot düellosunda `matchmaking_screen.dart` rakip için bir bot adı
/// seçip kullanıcıya "X ile eşleştin" diye duyuruyor VE `room.players`e o
/// adı yazıyordu. Ama `quiz_screen.dart` bu odayı `_isMultiplayer == false`
/// (room.id == null) olarak görünce kendi rastgele bot adını yeniden
/// çekiyordu — duyurulan isimle yarış boyunca görünen isim FARKLI oluyordu.
///
/// Düzeltme: `botOpponentDisplayName`, oda oyuncularının ikinci girdisini
/// (matchmaking'in kurduğu sabit sıra: [sen, bot]) varsa onu kullanır;
/// yoksa (bu ekranı doğrudan kuran testler gibi) eski rastgele seçime düşer.
void main() {
  test('oda ikinci oyuncusunun adı varsa o kullanılır, yeniden seçilmez', () {
    final players = [
      const Player(name: 'Tu', score: 0, state: 'Hazır'),
      const Player(name: 'Şêrko', score: 0, state: 'Hazır'),
    ];
    final random = Random(1);

    final name = botOpponentDisplayName(players, const [
      'Baran',
      'Rojda',
      'Dilan',
    ], random);

    expect(name, 'Şêrko');
  });

  test('ikinci oyuncu yoksa havuzdan rastgele seçilir (eski davranış)', () {
    final random = Random(42);
    const pool = ['Baran', 'Rojda', 'Dilan'];

    final name = botOpponentDisplayName(const [], pool, random);

    expect(pool, contains(name));
  });

  test('ikinci oyuncunun adı boşsa havuzdan seçime düşülür', () {
    final players = [
      const Player(name: 'Tu', score: 0, state: 'Hazır'),
      const Player(name: '  ', score: 0, state: 'Hazır'),
    ];
    final random = Random(7);
    const pool = ['Baran', 'Rojda'];

    final name = botOpponentDisplayName(players, pool, random);

    expect(pool, contains(name));
  });
}
