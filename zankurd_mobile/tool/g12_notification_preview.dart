// G12 yerel web kontrolü; production main, Firebase veya Supabase başlatmaz.
// flutter run -d web-server -t tool/g12_notification_preview.dart --web-port 8187
// ?offline=true&lang=tr|ku&scale=2
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart' show ZanKurdApp;
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';

class _PreviewRepository extends MockZanKurdRepository {
  @override
  Future<bool> setPushPreferences({
    bool? duel,
    bool? social,
    String? expectedUserId,
  }) async {
    if (Uri.base.queryParameters['offline'] == 'true') return false;
    return super.setPushPreferences(
      duel: duel,
      social: social,
      expectedUserId: expectedUserId,
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'zankurd.notifications.enabled': true,
    'zankurd.notifications.pref.serverDirty': true,
  });
  final query = Uri.base.queryParameters;
  final repository = _PreviewRepository();
  runApp(
    ZanKurdApp(
      repository: repository,
      authProvider: AuthProvider.test(authenticated: true),
      languageProvider: LanguageProvider(initialLang: query['lang'] ?? 'tr'),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              double.tryParse(query['scale'] ?? '') ?? 1,
            ),
          ),
          child: SettingsScreen(repository: repository),
        ),
      ),
    ),
  );
}
