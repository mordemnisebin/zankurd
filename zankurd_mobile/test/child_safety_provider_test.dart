import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('çocuk modu sosyal ve paylaşım kapılarını kapatır', () async {
    final provider = await ChildSafetyProvider.load();

    expect(provider.enabled, isFalse);
    expect(provider.allowFriendSearch, isTrue);
    expect(provider.allowExternalShare, isTrue);

    await provider.setEnabled(true);

    expect(provider.enabled, isTrue);
    expect(provider.allowFriendSearch, isFalse);
    expect(provider.allowExternalShare, isFalse);
  });

  test('çocuk modu tercihi yeniden yüklenebilir', () async {
    final provider = await ChildSafetyProvider.load();
    await provider.setEnabled(true);

    final reloaded = await ChildSafetyProvider.load();

    expect(reloaded.enabled, isTrue);
  });
}
