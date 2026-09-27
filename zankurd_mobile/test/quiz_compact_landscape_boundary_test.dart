import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

void main() {
  test('compact landscape width sınırı 699/700 nettir', () {
    expect(useCompactLandscapeLayoutForTesting(699, 390), isFalse);
    expect(useCompactLandscapeLayoutForTesting(700, 390), isTrue);
  });

  test('compact landscape height sınırı 600/601 nettir', () {
    expect(useCompactLandscapeLayoutForTesting(844, 600), isTrue);
    expect(useCompactLandscapeLayoutForTesting(844, 601), isFalse);
  });

  test('dikey, sonsuz veya kare constraint compact dala girmez', () {
    expect(useCompactLandscapeLayoutForTesting(700, 700), isFalse);
    expect(useCompactLandscapeLayoutForTesting(700, 844), isFalse);
    expect(useCompactLandscapeLayoutForTesting(844, double.infinity), isFalse);
  });
}
