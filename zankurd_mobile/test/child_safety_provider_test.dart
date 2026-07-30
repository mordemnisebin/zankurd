import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('varsayılan kapalı; denetlenen özellikler açık', () async {
    final p = await ChildSafetyProvider.load();
    expect(p.enabled, isFalse);
    expect(p.allowFriendSearch, isTrue);
    expect(p.allowFriendRequests, isTrue);
    expect(p.allowPublicProfile, isTrue);
    expect(p.allowExternalShare, isTrue);
  });

  test('açıldığında mevcut sosyal/paylaşım kapıları kapanır', () async {
    final p = await ChildSafetyProvider.load();
    await p.setEnabled(true);
    expect(p.allowFriendSearch, isFalse);
    expect(p.allowFriendRequests, isFalse);
    expect(p.allowPublicProfile, isFalse);
    expect(p.allowExternalShare, isFalse);
  });

  test('ayar kalıcıdır', () async {
    final p = await ChildSafetyProvider.load();
    await p.setEnabled(true);

    final reloaded = await ChildSafetyProvider.load();
    expect(reloaded.enabled, isTrue);
    expect(reloaded.allowFriendSearch, isFalse);
  });

  test('kapatınca denetlenen özellikler geri gelir (veri kaybı yok)', () async {
    final p = await ChildSafetyProvider.load();
    await p.setEnabled(true);
    await p.setEnabled(false);
    expect(p.allowFriendSearch, isTrue);
    expect(p.allowPublicProfile, isTrue);
    expect(p.allowExternalShare, isTrue);
  });

  test('güvenli görünen ad yalnız mod açıkken devreye girer', () async {
    final p = await ChildSafetyProvider.load();
    expect(p.safeDisplayName('Berfîn'), 'Berfîn');
    await p.setEnabled(true);
    expect(p.safeDisplayName('Berfîn'), isNot('Berfîn'));
  });

  test('açıklama yalnız gerçekten denetlenen özellikleri söyler', () {
    final tr = Tr.of(K.childSafeBody, AppLanguage.tr);
    final ku = Tr.of(K.childSafeBody, AppLanguage.ku);

    expect(tr, contains('herkese açık profil'));
    expect(tr, isNot(contains('oda sohbetini')));
    expect(tr, isNot(contains('her şey geri gelir')));
    expect(ku, contains('profîla giştî'));
    expect(ku, isNot(contains('sohbeta odeyê')));
    expect(ku, isNot(contains('her tişt vedigere')));
  });

  test('notifyListeners tetiklenir', () async {
    final p = await ChildSafetyProvider.load();
    var count = 0;
    p.addListener(() => count++);
    await p.setEnabled(true);
    expect(count, 1);
  });
}
