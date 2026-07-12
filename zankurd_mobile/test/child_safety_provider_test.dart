import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('varsayılan kapalı; tüm özellikler açık', () async {
    final p = await ChildSafetyProvider.load();
    expect(p.enabled, isFalse);
    expect(p.allowFriendSearch, isTrue);
    expect(p.allowFriendRequests, isTrue);
    expect(p.allowRoomChat, isTrue);
    expect(p.allowPublicProfile, isTrue);
    expect(p.allowExternalShare, isTrue);
  });

  test('açıldığında tüm sosyal/paylaşım kapıları kapanır', () async {
    final p = await ChildSafetyProvider.load();
    await p.setEnabled(true);
    expect(p.allowFriendSearch, isFalse);
    expect(p.allowFriendRequests, isFalse);
    expect(p.allowRoomChat, isFalse);
    expect(p.allowPublicProfile, isFalse);
    expect(p.allowExternalShare, isFalse);
  });

  test('ayar kalıcıdır', () async {
    final p = await ChildSafetyProvider.load();
    await p.setEnabled(true);

    final reloaded = await ChildSafetyProvider.load();
    expect(reloaded.enabled, isTrue);
    expect(reloaded.allowRoomChat, isFalse);
  });

  test('kapatınca özellikler geri gelir (veri kaybı yok)', () async {
    final p = await ChildSafetyProvider.load();
    await p.setEnabled(true);
    await p.setEnabled(false);
    expect(p.allowFriendSearch, isTrue);
    expect(p.allowRoomChat, isTrue);
    expect(p.allowExternalShare, isTrue);
  });

  test('güvenli görünen ad yalnız mod açıkken devreye girer', () async {
    final p = await ChildSafetyProvider.load();
    expect(p.safeDisplayName('Berfîn'), 'Berfîn');
    await p.setEnabled(true);
    expect(p.safeDisplayName('Berfîn'), isNot('Berfîn'));
    expect(ChildSafetyProvider.safeQuickMessages, isNotEmpty);
  });

  test('notifyListeners tetiklenir', () async {
    final p = await ChildSafetyProvider.load();
    var count = 0;
    p.addListener(() => count++);
    await p.setEnabled(true);
    expect(count, 1);
  });
}
