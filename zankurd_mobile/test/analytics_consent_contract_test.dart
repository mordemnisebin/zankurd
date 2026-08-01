import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';

void main() {
  test('consent is off by default and persists when enabled', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = await AnalyticsConsentProvider.load();
    expect(provider.enabled, isFalse);

    await provider.setEnabled(true);
    final reloaded = await AnalyticsConsentProvider.load();
    expect(reloaded.enabled, isTrue);
  });

  test('analytics consent defaults to off and persists a user choice', () {
    final provider = File(
      'lib/src/providers/analytics_consent_provider.dart',
    ).readAsStringSync();

    expect(provider, contains("prefs.getBool(_storageKey) ?? false"));
    expect(provider, contains('setBool(_storageKey, value)'));
  });

  test('analytics initialization is gated by consent', () {
    final main = File('lib/main.dart').readAsStringSync();
    final settings = File(
      'lib/src/screens/settings_screen.dart',
    ).readAsStringSync();

    expect(main, contains('if (analyticsConsentProvider.enabled)'));
    expect(settings, contains('analytics-consent-switch'));
    expect(settings, contains('AnalyticsService.instance.initialize()'));
  });
}
