import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';

/// 2026-09-03 simülatör: yeşil «Yarış / rakibini bul ~2 dk» kartı ile
/// pembe hızlı düello aynı CTA'yı iki kez satıyordu.
void main() {
  test('kimlik alt başlığı hızlı düello vaadini tekrarlamaz', () {
    for (final lang in AppLanguage.values) {
      final subtitle = Tr.of(K.playSubtitle, lang).toLowerCase();
      expect(subtitle, isNot(contains('2 dak')));
      expect(subtitle, isNot(contains('2 deq')));
      expect(subtitle, isNot(contains('rakibini bul')));
      expect(subtitle, isNot(contains('hevrikekî bibîne')));
    }
  });
}
