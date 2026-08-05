import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// İkilideki her gizlilik API'sinin bir amaç dizesi olmalı.
///
/// ## Kusur
///
/// Uygulama kamerayı hiç açmıyor: `avatar_editor_screen.dart` tek çağrı
/// yeri ve orada yalnız `ImageSource.gallery` kullanılıyor. Buna rağmen
/// `image_picker_ios` `GeneratedPluginRegistrant` ile koşulsuz kaydediliyor
/// ve podspec bütün `.m` dosyalarını topluca derliyor
/// (`source_files = '.../**/*.{h,m}'`); kamera dosyasını dışarıda bırakan
/// bir anahtar yok.
///
/// 2026-08-06'da no-codesign release derlemesinin İKİLİSİNDEN doğrulandı:
///
///     nm -mu Runner.app/Runner
///       (undefined) external _OBJC_CLASS_$_AVCaptureDevice (from AVFoundation)
///       (undefined) external _OBJC_CLASS_$_UIImagePickerController (from UIKit)
///     strings -a Runner.app/Runner
///       authorizationStatusForMediaType:
///       requestAccessForMediaType:completionHandler:
///
/// Apple'ın taraması İKİLİYE bakar, Dart çağrı yerine değil. Dize yokken
/// yükleme sonrası ITMS-90683 gelir — yani sorun yayın günü, build
/// yüklendikten sonra ortaya çıkar.
///
/// Kamerayı derlemeden çıkarmak `image_picker`ı tamamen bırakmak demekti
/// ve avatar fotoğrafı özelliğini kaldırırdı; bu yüzden dize eklendi.
///
/// ## Bekçi
///
/// Eklenti listesi ile amaç dizeleri birlikte değişmeli: yarın kamera
/// gerçekten kullanılırsa ya da `image_picker` kaldırılırsa bu test
/// hatırlatır.
void main() {
  late String plist;
  late String pubspec;

  setUpAll(() {
    plist = File('ios/Runner/Info.plist').readAsStringSync();
    pubspec = File('pubspec.yaml').readAsStringSync();
  });

  test('image_picker duruyorsa kamera amaç dizesi de durmalı', () {
    if (!pubspec.contains('image_picker:')) {
      // Eklenti kaldırılmışsa dize de gereksizdir; bekçi susar.
      return;
    }
    expect(
      plist,
      contains('<key>NSCameraUsageDescription</key>'),
      reason:
          'image_picker_ios AVCaptureDevice sembollerini ikiliye bağlıyor; '
          'amaç dizesi olmadan ITMS-90683 gelir',
    );
  });

  test('fotoğraf arşivi dizesi duruyor', () {
    expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
  });

  test('amaç dizeleri boş veya yer tutucu değil', () {
    for (final key in [
      'NSCameraUsageDescription',
      'NSPhotoLibraryUsageDescription',
    ]) {
      final match = RegExp(
        '<key>$key</key>\\s*<string>(.*?)</string>',
        dotAll: true,
      ).firstMatch(plist);
      expect(match, isNotNull, reason: '$key bulunamadı');
      final value = match!.group(1)!.trim();
      expect(value.length, greaterThan(20), reason: '$key çok kısa');
      expect(
        value.toUpperCase(),
        isNot(contains('TODO')),
        reason: '$key yer tutucu kalmış',
      );
      expect(
        value,
        contains('ZanKurd'),
        reason: 'Apple amaç dizesinde uygulamanın ne yaptığını bekler',
      );
    }
  });

  test('kamera gerçekten kullanılmıyor — dize yalnız derleme gereği', () {
    final editor = File(
      'lib/src/screens/avatar_editor_screen.dart',
    ).readAsStringSync();
    expect(editor, contains('ImageSource.gallery'));
    expect(
      editor,
      isNot(contains('ImageSource.camera')),
      reason:
          'Kamera gerçekten kullanılmaya başlandıysa amaç dizesi de '
          'kullanıcıya doğruyu söyleyecek biçimde güncellenmeli',
    );
  });

  test('mikrofon istenmediği için dizesi de yok', () {
    // Bekçinin kendi kör noktası: "her izin için dize ekle" diye
    // genelleştirilirse istenmeyen izinler beyan edilmiş olurdu.
    expect(plist, isNot(contains('NSMicrophoneUsageDescription')));
  });
}
