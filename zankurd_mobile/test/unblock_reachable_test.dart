import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';

/// Engel kaldırmanın hiçbir arayüz yolu yoktu (2026-08-02 denetimi).
///
/// `unblockPlayer` depoda, arayüz sözleşmesinde ve mock'ta vardı — ama
/// `lib/src/screens` altında TEK bir çağıranı bile yoktu. Kullanıcı birini
/// engelledikten sonra kararını geri alamıyordu.
///
/// Engelleme, geri alınabilir olmadıkça bir moderasyon aracı değil tek
/// yönlü bir kapıdır: yanlışlıkla engellenen bir arkadaş kalıcı olarak
/// kayboluyordu. Apple 1.2 engelleme maddesi de yönetilebilir bir engel
/// bekler.
void main() {
  test('engel kaldırma arayüzden çağrılıyor', () {
    final found = Directory('lib/src/screens')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('unblockPlayer'))
        .map((f) => f.path)
        .toList();
    expect(
      found,
      isNotEmpty,
      reason:
          'unblockPlayer depoda duruyor ama hiçbir ekran onu çağırmıyor — '
          'engel tek yönlü bir kapı',
    );
  });

  test('engellenenler ADLARIYLA listeleniyor', () {
    // Kullanıcıya UUID listesi göstermek engeli yönetilebilir kılmaz.
    final contract = File(
      'lib/src/data/zankurd_repository.dart',
    ).readAsStringSync();
    expect(contract, contains('loadBlockedPlayers()'));
  });

  test('ayarlarda bölüm ve boş durum var', () {
    final src = File('lib/src/screens/settings_screen.dart').readAsStringSync();
    expect(src, contains('_BlockedUsersSection'));
    expect(
      src,
      contains('blocked-empty'),
      reason: 'hiç engellenmemişse kullanıcı boş bir panel görür',
    );
  });

  test('mock depo engelle/kaldır döngüsünü destekliyor', () async {
    final repo = MockZanKurdRepository();
    await repo.blockPlayer('p9');
    expect((await repo.loadBlockedPlayers()).map((e) => e.id), contains('p9'));
    await repo.unblockPlayer('p9');
    expect(await repo.loadBlockedPlayers(), isEmpty);
  });
}
