import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profil avatar varsayılanı geçerli palet rengine alınır', () {
    final migration = File(
      'supabase/2026-08-01_profile_avatar_default_fix.sql',
    );

    expect(migration.existsSync(), isTrue);
    if (!migration.existsSync()) return;

    final source = migration.readAsStringSync().toLowerCase();
    expect(source, contains('alter table public.profiles'));
    expect(source, contains("alter column avatar_color set default '#2e9e93'"));
    expect(source, contains("where lower(btrim(avatar_color)) = '#177a56'"));
  });
}
