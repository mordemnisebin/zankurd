import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

/// Oda sahipliği tahmin edilmez; bilinmiyorsa "değilim" denir.
///
/// ## 2026-07-31: iddia çürütüldü sanıldı
///
/// "Oda sahibi düşerse iki istemci de kendini host sanar" diye bir iddia
/// gelmişti ve doğrulama turunda çürütüldü: "`hostId` Supabase yolunda
/// hiçbir zaman null olmuyor."
///
/// ## 2026-08-01: çürütme yanlıştı
///
/// Canlı logda katılan istemci ev sahibine özel çağrıyı yaptı:
///
///     quiz finish game failed: PostgrestException(
///       message: Only the room host can finish the game, code: P0001)
///
/// Çürütme yalnız mock yolunu ölçmüştü. Eski `joinOnlineRoom`, RPC'nin zaten
/// döndürdüğü `host_id` yerine ikinci ve hata yutulan bir rooms sorgusu
/// yapıyordu; o sorgu düşünce katılan `hostId: null` ile odaya giriyordu.
/// `_isHost`in yedek dalı da "oyuncu listesinin ilki benim miyim?" diye
/// soruyordu — ve liste sırası ev sahipliği garantisi taşımıyor.
///
/// Artık create/join RPC snapshotındaki `host_id` zorunlu parse edilir;
/// eksik kimlik sessiz null yerine sözleşme hatasıdır.
///
/// Yedek dal kaldırıldı. Bilinmiyorsa cevap "hayır"dır: yapılmayan iş
/// zararsız, yapılmaması gereken iş zararlı — iki istemcinin birden ev
/// sahibi sanması soruyu iki kez ilerletebilir, ve gerçek ev sahibi
/// çıkmışsa oda hiç bitmeyebilir.
void main() {
  // Mock (çevrimdışı) oda `hostId` taşımaz ve bu doğrudur: tek cihazda
  // oynanan bir odanın sunucu tarafı sahibi yoktur. `_isHost` artık yedek
  // dal taşımadığı için orada kimse host sayılmaz — eskiden güvenlik
  // "oyuncuların kimliği yok" tesadüfüne dayanıyordu.
  test('çevrimdışı oda sahipsizdir ve kimse host sayılmaz', () {
    final repository = MockZanKurdRepository();
    final room = repository.createRoom(category: 'Ziman');

    expect(
      room.hostId,
      isNull,
      reason: 'Çevrimdışı odanın sunucu tarafı sahibi yoktur.',
    );

    // Geri düşüş dalının kimseyi seçememesinin tek sebebi bu.
    expect(room.players.first.id == repository.currentUserId, isFalse);
  });

  test('ev sahipliği liste sırasından tahmin edilmiyor', () {
    final code = File('lib/src/screens/quiz_screen.dart')
        .readAsStringSync()
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .where((line) => !line.trimLeft().startsWith('///'))
        .join('\n')
        .replaceAll(RegExp(r'\s+'), ' ');

    expect(
      code,
      isNot(contains('widget.room.players.first.id == uid')),
      reason:
          'Liste sırası ev sahipliği garantisi taşımıyor; katılan "ilk" '
          'olabilir ve kendini ev sahibi sanar.',
    );
    expect(
      code,
      contains('return uid == widget.room.hostId;'),
      reason: 'Karar yalnız hostId karşılaştırmasıyla verilmeli.',
    );
  });

  test('online oda hostId değerini yetkili RPC snapshotından zorunlu okur', () {
    // Tekrar çağrılan create RPC mevcut bir odayı döndürebilir ve çağıran o
    // odanın misafiri olabilir; bu yüzden local user id host diye varsayılmaz.
    final repository = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final create = repository.substring(
      repository.indexOf('Future<GameRoom> createOnlineRoom'),
    );
    final createBody = create.substring(0, create.indexOf('\n  @override'));
    expect(
      createBody,
      contains("_requiredString(snapshot, const ['host_id'])"),
      reason:
          'Eksik host kimliği sessiz null yerine bozuk RPC sözleşmesi olmalı.',
    );
    expect(createBody, contains('hostId: hostId'));
    expect(createBody, isNot(contains('hostId: user.id')));
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
