import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// `test/widget_test.dart` bölünmeden önce burada özel (private, `_` önekli)
/// olan ortak test kurulumu — birden fazla test dosyası tarafından
/// paylaşıldığı için public'e taşındı. Yalnız TEK dosyada kullanılan sahte
/// repository'ler (ör. `_FailingRoomRepository`) kendi dosyalarında kalır.

class FakeAuthProvider extends AuthProvider {
  FakeAuthProvider() : super.test();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;
}

class GateAuthProvider extends AuthProvider {
  GateAuthProvider() : super.test();

  bool _authenticated = false;
  bool _loading = false;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  bool get isLoading => _loading;

  set isLoadingForTest(bool value) {
    _loading = value;
    notifyListeners();
  }

  @override
  Future<bool> signInAsGuest() async {
    _authenticated = true;
    notifyListeners();
    return true;
  }
}

class NeedsNameRepository extends MockZanKurdRepository {
  String savedName = '';

  @override
  Future<String> getProfileName() async => savedName;

  @override
  Future<void> updateProfileName(String name) async {
    savedName = name;
  }
}

LanguageProvider turkishLang() => LanguageProvider()..setLang('tr');

Widget testShell({
  required Widget child,
  AuthProvider? authProvider,
  LanguageProvider? languageProvider,
  ThemeProvider? themeProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => languageProvider ?? turkishLang(),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => authProvider ?? FakeAuthProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => themeProvider ?? ThemeProvider(),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
      ChangeNotifierProvider<ReducedMotionProvider>(
        create: (_) => ReducedMotionProvider(),
      ),
      ChangeNotifierProvider<ChildSafetyProvider>(
        create: (_) => ChildSafetyProvider(),
      ),
    ],
    child: Consumer<ThemeProvider>(
      builder: (context, theme, _) => MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: theme.mode,
        home: child,
      ),
    ),
  );
}

/// Her testten önce çağrılır: taze repository + deterministik
/// SharedPreferences/store durumu. `MockZanKurdRepository` mutable state
/// tuttuğu için testler arasında paylaşılan bir örnek sıra bağımlılığı
/// yaratır — bu yüzden her `setUp` yeni bir örnek döndürür.
MockZanKurdRepository freshMockRepository() {
  SharedPreferences.setMockInitialValues({
    'zankurd.onboarding.seen': true,
    'zankurd.profileName.completed': true,
    'zankurd.navTour.seen': true,
    'zankurd.quiz_tutorial.seen': true,
  });
  AchievementStore.resetInstance();
  SeenQuestionStore.resetInstance();
  StreakStore.resetInstance();
  MistakeStore.resetInstance();
  return MockZanKurdRepository();
}
