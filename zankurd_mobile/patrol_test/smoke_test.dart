import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';

void main() {
  patrolTest('ZanKurd Patrol native smoke', ($) async {
    // Patrol testleri `test/` dışında yaşadığı için analyzer bu test-only API'yi
    // üretim çağrısı sanıyor; burada deterministik yerel tercih durumu kuruyoruz.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.lang': 'ku',
    });
    final repository = MockZanKurdRepository();

    await $.pumpWidgetAndSettle(
      ZanKurdApp(
        repository: repository,
        authProvider: AuthProvider.test(authenticated: true),
        home: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-play')), findsOneWidget);

    if (Platform.isIOS || Platform.isAndroid) {
      await $.platform.mobile.pressHome();
    }
  });
}
