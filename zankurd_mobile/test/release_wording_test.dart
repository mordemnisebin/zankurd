import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// Kullanıcıya görünen hiçbir metin uygulamayı beta/deneme sürümü ilan etmez.
///
/// ## Kusur
///
/// Ayarlar ekranında "Beta geri bildirimi gönder — **Bu erken sürümde** neyi
/// daha iyi yapabiliriz?" yazıyordu ve bu metin App Store'a gönderilen 1.9.2
/// üretim sürümünün içindeydi (2026-08-16 simülatör taraması).
///
/// App Review Kılavuzu 2.2 beta, deneme ve demo sürümlerini reddeder. Metin
/// bir kod kusuru olmadığı için hiçbir test görmüyordu: derleniyor,
/// çeviriliyor, ekranda düzgün duruyordu — yalnızca uygulamayı yayına
/// uygunsuz ilan ediyordu.
///
/// ## Kural
///
/// Bekçi çeviri tablosunun tamamını tarar; yeni bir "beta" metni eklenirse
/// gönderimden önce burada yakalanır. Kurmancî'de "betal" (iptal) kelimesi
/// meşrudur ve "beta" ile karışmaması için tam kelime araması yapılır.
void main() {
  // Aramanın kapsamadığı meşru kullanımlar: Kurmancî "betal/betalkirin"
  // (iptal etmek) ve şık metni olarak Yunan harfi "Beta".
  final forbidden = RegExp(
    r'\b(beta|erken sürüm|guhertoya pêşîn|deneme sürümü|demo sürüm)\b',
    caseSensitive: false,
  );

  test('çeviri tablosunda beta/erken sürüm ilanı yok', () {
    final offenders = <String>[];

    for (final language in AppLanguage.values) {
      for (final key in Tr.keys) {
        final value = Tr.of(key, language);
        if (forbidden.hasMatch(value)) {
          offenders.add('$key [${language.name}]: $value');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu metinler uygulamayı beta/deneme sürümü gibi gösteriyor ve App '
          'Review Kılavuzu 2.2 buna takılır:\n${offenders.join('\n')}',
    );
  });
}
