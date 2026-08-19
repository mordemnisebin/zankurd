import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:zankurd_mobile/src/utils/external_link.dart';

import 'support/widget_test_helpers.dart';

/// Görsel künyesindeki kaynak bağlantısı da sessizce ölmemeli.
///
/// ## Kusur
///
/// 2026-08-14'te yasal bağlantılarda bulunup düzeltilen kusurun ikinci
/// örneği künye ekranındaydı (2026-08-17 taraması). Kaynak bağlantısı şöyle
/// çağrılıyordu:
///
/// ```dart
/// onTap: () => launchUrl(Uri.parse(credit.source), mode: ...)
/// ```
///
/// Üç şey birden eksikti: dönen `bool` okunmuyor (cihazda hedefi açacak
/// uygulama yoksa `launchUrl` İSTİSNA FIRLATMAZ, yalnız `false` döner),
/// `Uri.parse` için hiçbir `try` yok (künye adresleri bir asset dosyasından
/// gelir; bozuk bir adres dokunuşu çökertirdi) ve çağrı `await` edilmiyor.
///
/// Künye bir lisans metnidir: CC lisanslı görsellerin atfı çalışan bir
/// kaynak bağlantısı ister. Ölü bağlantı yalnız kullanıcıyı şaşırtmaz, atfı
/// da zayıflatır — `kurmanci_alphabet_test`in künyedeki Türkçe terim için
/// söylediğiyle aynı gerekçe.
///
/// ## Niçin sessiz kaldı
///
/// `legal_link_open_failure_test` düzeltmeyi ölçüyordu ama yalnız
/// `LegalLinksRow` için; düzeltme de o widget'ın içinde özel bir metot
/// olarak durduğu için ikinci çağrı yerine hiç ulaşmadı. İki örnek bir
/// desendir: açma mantığı artık ortak `openExternalLink` kapısında ve bu
/// dosya o kapıyı ölçüyor.
void main() {
  late UrlLauncherPlatform original;

  setUp(() => original = UrlLauncherPlatform.instance);
  tearDown(() => UrlLauncherPlatform.instance = original);

  /// Bağlantıyı ortak kapıdan açan en küçük ekran. Künye ekranının kendisi
  /// kurulmuyor çünkü ölçülen şey o ekranın listesi değil, DOKUNUŞUN
  /// başarısızlıkta görünür sonuç doğurması.
  Widget linkHost(String url) => Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () =>
              openExternalLink(context, url, reason: 'image credit source'),
          child: const Text('Kaynak'),
        ),
      ),
    ),
  );

  testWidgets('açılamayan kaynak bağlantısı görünür uyarı verir', (
    tester,
  ) async {
    UrlLauncherPlatform.instance = _NoAppCanHandleThis();

    await tester.pumpWidget(
      testShell(child: linkHost('https://example.com/a')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaynak'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bağlantı açılamadı.'),
      findsOneWidget,
      reason:
          '`launchUrl` false döndü ve kullanıcı hiçbir şey görmedi; dokunuşun '
          'işe yarayıp yaramadığı belirsiz kaldı.',
    );
  });

  testWidgets('bozuk adres dokunuşu çökertmez, aynı uyarıyı verir', (
    tester,
  ) async {
    UrlLauncherPlatform.instance = _ThrowingLauncher();

    // Künye adresleri `assets/data/image_credits.json`dan gelir; oradaki tek
    // bozuk satır bütün ekranı çökertmemeli.
    await tester.pumpWidget(testShell(child: linkHost(':::bozuk adres')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaynak'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.text('Bağlantı açılamadı.'),
      findsOneWidget,
      reason: 'İstisna yolu da aynı görünür sonuca çıkmalı.',
    );
  });

  testWidgets('açılabilen bağlantı uyarı göstermez', (tester) async {
    // Bekçi yalnız başarısızlığı ölçseydi, her dokunuşta uyarı gösteren bir
    // regresyon da testi geçerdi.
    final launcher = _SucceedingLauncher();
    UrlLauncherPlatform.instance = launcher;

    await tester.pumpWidget(
      testShell(child: linkHost('https://example.com/a')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kaynak'));
    await tester.pumpAndSettle();

    expect(launcher.opened, ['https://example.com/a']);
    expect(find.text('Bağlantı açılamadı.'), findsNothing);
  });

  /// Asıl bekçi bu: üçüncü örnek hiç doğmasın.
  ///
  /// Yukarıdaki testler ortak kapının doğru davrandığını ölçer, ama yeni bir
  /// ekran `launchUrl`ı yine doğrudan çağırırsa hepsi yeşil kalır — kusur
  /// tam olarak böyle iki kez doğdu. Kural mekanik: `launchUrl` çağrısı ve
  /// `url_launcher` importu yalnız ortak kapıda bulunur.
  test('launchUrl yalnız ortak kapıdan çağrılır', () {
    const gateway = 'external_link.dart';
    final offenders = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.endsWith(gateway)) continue;
      final source = file.readAsStringSync();
      if (source.contains('launchUrl(') ||
          source.contains("package:url_launcher/url_launcher.dart")) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosyalar `launchUrl`ı doğrudan çağırıyor. `openExternalLink` / '
          '`openExternalUri` kullanılmalı: dönen `bool` okunmadığında ya da '
          '`Uri.parse` korunmadığında dokunuş sessizce ölür ve kusur her '
          'çağrı yerinde yeniden doğar:\n${offenders.join('\n')}',
    );
  });
}

/// Cihazda hedefi açacak uygulama yokmuş gibi davranır: `false`, istisna yok.
class _NoAppCanHandleThis extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => false;
}

/// Platform kanalının fırlattığı durum.
class _ThrowingLauncher extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    throw Exception('injected: platform kanalı düştü');
  }
}

class _SucceedingLauncher extends UrlLauncherPlatform {
  final List<String> opened = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    opened.add(url);
    return true;
  }
}
