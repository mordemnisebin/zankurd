import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('başlangıçta boş kimlik döner', () async {
    final repo = MockZanKurdRepository();
    final identity = await repo.loadAvatarIdentity();
    expect(identity.iconId, isNull);
    expect(identity.photoUrl, isNull);
    expect(identity.showcaseTitle, isNull);
  });

  test('update sonrası load aynı kimliği döner', () async {
    final repo = MockZanKurdRepository();
    const identity = AvatarIdentity(
      iconId: 'newroz',
      colorHex: '#F59E0B',
      frameId: 'bronze',
      showcaseTitle: 'Xwendekar · Muzîk',
    );
    await repo.updateAvatarIdentity(identity);
    final loaded = await repo.loadAvatarIdentity();
    expect(loaded.iconId, 'newroz');
    expect(loaded.colorHex, '#F59E0B');
    expect(loaded.frameId, 'bronze');
    expect(loaded.showcaseTitle, 'Xwendekar · Muzîk');
  });

  test('uploadAvatarPhoto mock URL döner', () async {
    final repo = MockZanKurdRepository();
    final url = await repo.uploadAvatarPhoto(
      Uint8List.fromList([1, 2, 3]),
      'image/jpeg',
    );
    expect(url, startsWith('mock://'));
  });

  test('kimlik SharedPreferences üzerinden kalıcıdır', () async {
    final repo1 = MockZanKurdRepository();
    await repo1.updateAvatarIdentity(const AvatarIdentity(iconId: 'roj'));
    final repo2 = MockZanKurdRepository();
    final loaded = await repo2.loadAvatarIdentity();
    expect(loaded.iconId, 'roj');
  });
}
