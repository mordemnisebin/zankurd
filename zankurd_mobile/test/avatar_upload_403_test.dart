// Kullanıcı (2026-10-21): kendi görselini avatar olarak yüklemek hep
// hata veriyordu. Kök neden: `uploadAvatarPhoto` `upsert: true` ile
// yüklüyordu; Storage upsert'te RLS SELECT politikası da ister ve
// 2026-08-01 sertleştirmesi avatars için SELECT'i kaldırdı → her yükleme
// 403. Yol zaten her yüklemede benzersiz, upsert gereksiz.
// Ayrıca içerik türü dosya adından tahmin ediliyordu; artık baytlardan.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';

void main() {
  test('avatar yüklemesi upsert kullanmaz (SELECT politikası gerekmez)', () {
    final src = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final start = src.indexOf('Future<String> uploadAvatarPhoto(');
    final end = src.indexOf('getPublicUrl', start);
    final body = src.substring(start, end);
    expect(body, contains('upsert: false'));
    expect(body, isNot(contains('upsert: true')));
  });

  test('içerik türü baytlardan: PNG imzası png, gerisi jpeg', () {
    expect(avatarContentTypeFor([0x89, 0x50, 0x4E, 0x47, 0x0D]), 'image/png');
    expect(avatarContentTypeFor([0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
    expect(avatarContentTypeFor([]), 'image/jpeg');
  });
}
