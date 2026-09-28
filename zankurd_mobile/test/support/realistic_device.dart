/// Widget testlerini gerçek bir telefona benzeten yardımcılar.
/// Ayrıntılı gerekçe aşağıdaki belge yorumundadır.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget testlerini gerçek bir telefona benzeten iki ayar: **çentik dolgusu**
/// ve **gerçek yazı tipi**.
///
/// ## Niçin var
///
/// `flutter test` varsayılan olarak 800×600'lük, güvenli alanı SIFIR ve yazı
/// tipi ölçü fontu olan bir cihaz taklit eder. Bu, testlerin çoğu için doğru
/// tercihtir — deterministiktir ve hızlıdır. Ama geometrinin kendisi ölçülen
/// şey olduğunda iki kusur sınıfını görünmez kılar:
///
/// 1. **Güvenli alan yok sayıldığı için üst üste binmeler görünmez.** 2273
///    testin hiçbiri, sekme içeriğinin durum çubuğunun altına girdiğini
///    göremedi; iPhone 17'de "Ders yolu" başlığı Dynamic Island'ın arkasında
///    kayboluyordu (2026-08-16 simülatör taraması).
/// 2. **Ölçü fontu gerçek metrikleri taşımaz.** Her harfi kare olan bu fontta
///    11pt bir harf 11px yer kaplar; Rubik'te ~6px. Kırpma, taşma ve
///    "sığıyor mu" testleri ölçü fontuyla koştuğunda anlamsız sonuç verir —
///    Türkçe "Soru Değiştir" bile kırpılmış sayılır.
///
/// ## Kullanım
///
/// ```dart
/// setUpAll(loadAppFonts);
///
/// testWidgets('...', (tester) async {
///   await tester.pumpWidget(
///     withDeviceInsets(testShell(child: const SomeScreen())),
///   );
/// });
/// ```
///
/// Bu yardımcıyı HER teste serpiştirmeyin: yavaşlatır ve çoğu test için
/// gereksizdir. Yalnız ölçtüğü şey yerleşim/geometri olan testlerde kullanın.
/// iPhone 17 sınıfı bir cihazın ölçüleri: 402×874 punto, üstte Dynamic
/// Island, altta ev göstergesi.
const kPhoneSize = Size(402, 874);
const kPhoneInsets = EdgeInsets.only(top: 59, bottom: 34);

/// [child]'ı gerçek bir telefonun güvenli alan dolgularıyla sarar.
Widget withDeviceInsets(
  Widget child, {
  Size size = kPhoneSize,
  EdgeInsets insets = kPhoneInsets,
}) {
  return MediaQuery(
    data: MediaQueryData(size: size, padding: insets, viewPadding: insets),
    child: child,
  );
}

/// Uygulamanın yazı tipini test koşucusuna yükler.
///
/// `flutter test` pubspec'teki aileleri kendiliğinden yüklemez ve bilinmeyen
/// aileyi ölçü fontuna düşürür. Metin genişliği/yüksekliği ölçen her test
/// bunu `setUpAll` içinde çağırmalıdır.
Future<void> loadAppFonts() async {
  // Şahnê: metin ailesi Onest, başlık ailesi Bricolage Grotesque.
  const families = {
    'Onest': [
      'assets/fonts/Onest-Regular.ttf',
      'assets/fonts/Onest-Medium.ttf',
      'assets/fonts/Onest-SemiBold.ttf',
      'assets/fonts/Onest-Bold.ttf',
    ],
    'BricolageGrotesque': [
      'assets/fonts/BricolageGrotesque-Bold.ttf',
      'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(
        File(path).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();
  }
}
