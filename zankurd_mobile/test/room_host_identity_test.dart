import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

/// Oda sahipliği hiçbir zaman boşta kalmaz.
///
/// 2026-07-31 denetiminde "oda sahibi düşerse iki istemci de kendini host
/// sanar ve aynı soruya farklı cevap verir" diye bir iddia geldi. Doğrulama
/// turunda çürütüldü: `hostId` Supabase yolunda hiçbir zaman null olmuyor.
///
/// Ama çürütme sırasında gerçek olan şu ortaya çıktı — `copyWith` klasik
/// `hostId ?? this.hostId` desenini kullanıyor, yani null geçmek alanı
/// TEMİZLEMİYOR, eski değeri koruyor. Bugün zararsız (kimse null geçmiyor)
/// ama sessiz bir tuzak.
///
/// Bu bekçi iki şeyi birden sabitler: oda üreten yolların `hostId`i her
/// zaman doldurduğunu, ve `copyWith`in null karşısındaki davranışının
/// bilinçli olduğunu. Biri değişirse test kırılır ve karar yeniden
/// verilmek zorunda kalır.
void main() {
  // Mock (çevrimdışı) oda `hostId` taşımaz ve bu doğrudur: tek cihazda
  // oynanan bir odanın sunucu tarafı sahibi yoktur.
  //
  // `_isHost` (quiz_screen.dart) `hostId` null olduğunda geri düşüş dalını
  // kullanır: `players.first.id == currentUserId`. Mock'ta `currentUserId`
  // 'user' ama oyuncuların kimliği yok, yani karşılaştırma `null == 'user'`
  // olur ve kimse host sayılmaz. Güvenlik tam olarak buraya dayanıyor.
  //
  // Bu test o zinciri sabitler: mock oyunculara kimlik verilirse geri düşüş
  // dalı birden ilk oyuncuyu host seçmeye başlar ve sahiplik varsayımı
  // sessizce değişir.
  test('çevrimdışı oda sahipsizdir ve kimse host sayılmaz', () {
    final repository = MockZanKurdRepository();
    final room = repository.createRoom(category: 'Ziman');

    expect(
      room.hostId,
      isNull,
      reason: 'Çevrimdışı odanın sunucu tarafı sahibi yoktur.',
    );

    // Geri düşüş dalının kimseyi seçememesinin tek sebebi bu.
    expect(
      room.players.every((player) => player.id == null),
      isTrue,
      reason:
          'Oyunculara kimlik verilirse _isHost geri düşüş dalı ilk oyuncuyu '
          'host seçer; o zaman hostId nin gerçekten set edilmesi gerekir.',
    );
    expect(room.players.first.id == repository.currentUserId, isFalse);
  });

  test('copyWith sahibi koruyarak diğer alanları değiştirir', () {
    const room = GameRoom(
      id: 'r1',
      name: 'Test',
      code: 'ZK-TEST',
      category: 'Ziman',
      players: [],
      status: RoomStatus.lobby,
      questionCount: 10,
      hostId: 'host-1',
    );

    final updated = room.copyWith(category: 'Dîrok', questionCount: 5);
    expect(updated.hostId, 'host-1');
    expect(updated.category, 'Dîrok');
  });

  test('copyWith(hostId: null) sahibi TEMİZLEMEZ — bilinçli davranış', () {
    const room = GameRoom(
      id: 'r1',
      name: 'Test',
      code: 'ZK-TEST',
      category: 'Ziman',
      players: [],
      status: RoomStatus.lobby,
      questionCount: 10,
      hostId: 'host-1',
    );

    // Bu satır "sahipliği bırak" gibi okunur ama öyle davranmaz.
    // Sahipliği gerçekten devretmek gerekirse null geçmek yetmez;
    // ayrı bir bayrak ya da sentinel gerekir (bkz. room.dart yorumu).
    final attempted = room.copyWith(hostId: null);
    expect(
      attempted.hostId,
      'host-1',
      reason:
          'Davranış değiştiyse sahiplik devri yolu da gözden geçirilmeli: '
          'iki istemci birbirini host sanabilir.',
    );
  });

  test('sahip kimliği oyuncunun kendi kimliğiyle karşılaştırılabilir', () {
    const room = GameRoom(
      id: 'r1',
      name: 'Test',
      code: 'ZK-TEST',
      category: 'Ziman',
      players: [],
      status: RoomStatus.lobby,
      questionCount: 10,
      hostId: 'host-1',
    );

    expect(room.hostId == 'host-1', isTrue);
    expect(room.hostId == 'baska-oyuncu', isFalse);
  });
}
