/// `zankurd.com/join/<KOD>` bağlantısı uygulamayı açan statik sayfaya düşsün.
///
/// ## Kusur
///
/// `web/.htaccess` var olmayan her yolu Flutter web'e (`index.html`)
/// yolluyordu. Android App Links doğrulaması tutmazsa ya da uygulama hiç
/// kurulu değilse davet bağlantısı tarayıcıda 13 MB'lık Flutter web'de
/// kalıyordu; kullanıcı ise bağlantının doğrudan uygulamada odayı açmasını
/// istiyor.
///
/// ## Niçin sessiz kalırdı
///
/// Flutter web davet kodunu da işlediği için bağlantı "çalışıyor" görünür;
/// yalnız uygulamaya hiç geçmezdi ve bunu ölçen bir şey yoktu. Bu dosya
/// sayfanın, CSP'ye uyduğunu (satır içi script yok), iki platform şemasını
/// taşıdığını, dil sözlüklerinin eşit kaldığını ve yeniden yazma kuralının
/// SPA düşüşünden ÖNCE geldiğini sabitler.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final html = File('web/join.html').readAsStringSync();
  final js = File('web/join.js').readAsStringSync();
  final htaccess = File('web/.htaccess').readAsStringSync();

  test('join.html satır içi script taşımaz ve join.js bağlıdır', () {
    final inline = RegExp(
      r'<script(?![^>]*\bsrc=)[^>]*>',
      caseSensitive: false,
    );
    expect(inline.hasMatch(html), isFalse);
    expect(html, contains('src="/join.js"'));
  });

  test('join.js iki platform bağlantısını ve mağaza adreslerini taşır', () {
    expect(js, contains('intent://'));
    expect(js, contains('com.zankurd.app://'));
    expect(js, contains('apps.apple.com/app/id6797175984'));
    expect(
      js,
      contains('play.google.com/store/apps/details?id=com.zankurd.app'),
    );
  });

  test('ku ve tr sözlükleri aynı anahtarlara sahip', () {
    Set<String> keys(String lang) {
      final block = RegExp(
        '$lang: \\{(.*?)\\n    \\}',
        dotAll: true,
      ).firstMatch(js)!.group(1)!;
      return RegExp(
        r"^\s*(\w+):",
        multiLine: true,
      ).allMatches(block).map((m) => m.group(1)!).toSet();
    }

    expect(keys('ku'), isNotEmpty);
    expect(keys('ku'), keys('tr'));
  });

  test('.htaccess join kuralı SPA düşüşünden önce gelir ve web=1 hariçtir', () {
    final join = htaccess.indexOf('^join/');
    final spa = htaccess.indexOf('RewriteRule ^ index.html');
    expect(join, greaterThan(0));
    expect(join, lessThan(spa));
    expect(htaccess, contains('web=1'));
    expect(htaccess, contains('join.html [L]'));
  });
}
