/// Yetişkin beyanının sahip anahtarı yazımı doğrulanmıyordu (son sürüm incelemesi).
///
/// ## Kusur
///
/// `AgeGate.declare` ve `AgeGate.bindUser` sahip kimliğini `setString` ile
/// yazıyor ama dönüş değerine bakmıyordu. Yazım `false` dönerse "13+" beyanı
/// sahipsiz kalır; `bindUser` sahipsiz beyanı ilk görünen hesaba verdiğinden
/// AYNI cihazda sonraki hesap önceki kişinin yetişkin beyanını miras alır ve
/// yaş sorusu hiç sorulmadan sohbet/sosyal yüzey açılırdı.
///
/// ## Niçin sessiz kalırdı
///
/// Hata atılmaz, yalnız `false` döner; normal akışta ve sahte depolarda yazım
/// hep başarılıdır. Bekçi sahip anahtarı yazımını başarısız yapan bir depo
/// kullanır: beyan geçersiz sayılmalı (bilinmiyor = yeniden sorulur).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/data/age_gate_store.dart';

class _SahipYazamayanDepo extends InMemorySharedPreferencesStore {
  _SahipYazamayanDepo(Map<String, Object> data) : super.withData(data);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${AgeGate.ownerKey}') return false;
    return super.setValue(valueType, key, value);
  }
}

void _kur(Map<String, Object> veri) {
  SharedPreferencesStorePlatform.instance = _SahipYazamayanDepo({
    for (final e in veri.entries) 'flutter.${e.key}': e.value,
  });
  SharedPreferences.resetStatic();
  AgeGate.debugSet(null);
}

void main() {
  test('declare: sahip yazılamazsa yetişkin beyanı geçersiz sayılır', () async {
    _kur({});
    await AgeGate.bindUser('hesap-a');
    await AgeGate.declare(AgeDeclaration.adult);
    expect(AgeGate.isAdult, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AgeGate.declarationKey), isNull);
    // Sonraki hesaba miras kalmaz; yaş sorusu yeniden çıkar.
    expect(await AgeGate.shouldAsk(), isTrue);
  });

  test(
    'declare: sahip yazılamasa da çocuk beyanı korunur (kısıtlayıcı)',
    () async {
      _kur({});
      await AgeGate.bindUser('hesap-a');
      await AgeGate.declare(AgeDeclaration.minor);
      expect(AgeGate.isMinor, isTrue);
    },
  );

  test(
    'bindUser: sahipsiz beyana sahip yazılamazsa beyan geçersiz sayılır',
    () async {
      _kur({AgeGate.declarationKey: 'adult'});
      await AgeGate.load();
      expect(AgeGate.isAdult, isTrue);
      await AgeGate.bindUser('hesap-b');
      expect(AgeGate.isAdult, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AgeGate.declarationKey), isNull);
      expect(await AgeGate.shouldAsk(), isTrue);
    },
  );
}
