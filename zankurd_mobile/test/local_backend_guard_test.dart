import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/local_backend_guard.dart';

/// Yerel-arka uç cihaz testlerinin üretim projesine yazmasını önleyen
/// korumanın davranış sınaması (kaynak taraması değil).
void main() {
  test('yerel ve özel ağ adresleri kabul edilir', () {
    for (final h in [
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '192.168.1.20',
      '172.20.0.5',
      'mac.local',
    ]) {
      expect(isLocalBackendHost(h), isTrue, reason: h);
    }
  });

  test('üretim Supabase ve boş ana makine reddedilir', () {
    for (final h in [
      'hupivnxgjtsfafulzspo.supabase.co',
      'evil.example.com',
      '172.32.0.1',
      '8.8.8.8',
      '',
    ]) {
      expect(isLocalBackendHost(h), isFalse, reason: h);
    }
  });
}
