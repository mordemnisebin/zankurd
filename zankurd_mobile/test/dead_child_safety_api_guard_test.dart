import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-09-03 canlı denetim: çocuk modu cihaz-içi bir anahtardı, sunucu
/// koruması yoktu; UI tappable kalıp snackbar ile yalan söylüyordu.
/// Ürün kararı: mod tamamen kalkar. Bu bekçi sessizce geri gelmesini önler.
void main() {
  test('çocuk modu sağlayıcısı, anahtarları ve ekran bağları yok', () {
    expect(
      File('lib/src/providers/child_safety_provider.dart').existsSync(),
      isFalse,
    );

    final offenders = <String>[];
    for (final root in ['lib', 'test', 'integration_test']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('dead_child_safety_api_guard_test.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        if (source.contains('ChildSafetyProvider') ||
            source.contains('childSafety') ||
            source.contains('child-safety-switch') ||
            source.contains('allowOnlinePlay') ||
            source.contains('allowFriendSearch') ||
            source.contains('allowExternalShare')) {
          offenders.add(entity.path);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'çocuk modu izi: ${offenders.join(', ')}',
    );
  });
}
