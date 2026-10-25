import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/room_reactions.dart';

/// Oda yayını sohbet süzgecinden geçmez; değiştirilmiş bir istemci her
/// oyuncunun ekranına serbest metin basabiliyordu (2026-10-25).
void main() {
  test('hazır tepki alıcının dilinde döner', () {
    expect(localizedRoomReaction('Destxweş!', isKu: false), 'Tebrikler!');
    expect(localizedRoomReaction('Tebrikler!', isKu: true), 'Destxweş!');
    expect(localizedRoomReaction('Agir!', isKu: true), 'Agir!');
  });

  test('eski istemcinin emoji önekli tepkisi tanınır', () {
    expect(localizedRoomReaction('👏 Destxweş!', isKu: true), 'Destxweş!');
  });

  test('serbest metin ve bozuk yük çizilmez', () {
    expect(
      localizedRoomReaction('ziyaret et: kötü.example', isKu: true),
      isNull,
    );
    expect(localizedRoomReaction('Destxweş! ama değil', isKu: true), isNull);
    expect(localizedRoomReaction('', isKu: true), isNull);
    expect(localizedRoomReaction(null, isKu: true), isNull);
    expect(localizedRoomReaction(42, isKu: true), isNull);
  });
}
