import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

/// 2026-09-03 simülatör: gece selamı «İyi Geceler» iken maskot hâlâ
/// gülen güneşti. Ruh hâli saate bağlanmazsa çelişki her açılışta durur.
void main() {
  test('gece selamında maskot kutlamaz, düşüncelidir', () {
    expect(greetingMascotMood(hour: 23, streak: 0), RojMood.thinking);
    expect(greetingMascotMood(hour: 2, streak: 0), RojMood.thinking);
  });

  test('gündüz ve seri kutlama ruh hâlleri korunur', () {
    expect(greetingMascotMood(hour: 9, streak: 0), RojMood.happy);
    expect(greetingMascotMood(hour: 18, streak: 0), RojMood.happy);
    expect(greetingMascotMood(hour: 23, streak: 3), RojMood.celebrate);
  });
}
