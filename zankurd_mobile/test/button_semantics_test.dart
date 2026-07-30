import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';

import 'support/widget_test_helpers.dart';

/// Her düğmenin ekran okuyucuya söyleyecek bir adı olmalı.
///
/// 2026-07-26: mağazadaki satın alma düğmesinin etiketi `ExcludeSemantics`
/// içine alınmıştı. Düğmenin başka bir ad kaynağı yok — ne üstünde bir
/// `Semantics(label:)`, ne `tooltip` — dolayısıyla ekran okuyucu yalnız
/// "düğme" diyordu, neyi satın alacağını söylemeden. Değişikliğin yanındaki
/// açıklama "erişilebilirlik düzeltmesi" diyordu; ölçünce tersi çıktı.
///
/// `ExcludeSemantics` yalnız **ad başka yerden geliyorsa** doğrudur: aynı
/// metni iki kez okutmamak için. Tek ad kaynağını gizlemek düğmeyi
/// adsız bırakır.
void main() {
  late MockZanKurdRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
    repository = MockZanKurdRepository();
  });

  /// [child] içindeki etkin düğmelerden adsız olanları döndürür.
  Future<List<String>> namelessButtons(
    WidgetTester tester,
    Widget child,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(testShell(child: child));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final nameless = <String>[];
    for (final type in const [
      FilledButton,
      TextButton,
      OutlinedButton,
      ElevatedButton,
    ]) {
      for (final element in find.byType(type).evaluate()) {
        final button = element.widget as ButtonStyleButton;
        // Devre dışı düğme zaten dokunulamaz; adsızlığı kullanıcıya
        // ulaşmaz ve yükleme sırasındaki geçici durumları raporlamak
        // bekçiyi gürültüye boğar.
        if (button.onPressed == null && button.onLongPress == null) continue;
        final node = tester.getSemantics(find.byWidget(button));
        if (node.label.trim().isEmpty) {
          nameless.add('$type @ ${child.runtimeType}');
        }
      }
    }
    handle.dispose();
    return nameless;
  }

  testWidgets('mağazadaki düğmelerin adı var', (tester) async {
    expect(
      await namelessButtons(tester, ShopScreen(repository: repository)),
      isEmpty,
    );
  });

  testWidgets('çark ekranındaki düğmelerin adı var', (tester) async {
    expect(
      await namelessButtons(tester, SpinWheelScreen(repository: repository)),
      isEmpty,
    );
  });

  testWidgets('arkadaşlar ekranındaki düğmelerin adı var', (tester) async {
    expect(
      await namelessButtons(tester, FriendsScreen(repository: repository)),
      isEmpty,
    );
  });

  testWidgets('oyun merkezindeki düğmelerin adı var', (tester) async {
    expect(
      await namelessButtons(tester, PlayHubScreen(repository: repository)),
      isEmpty,
    );
  });

  testWidgets('kayıt ekranındaki düğmelerin adı var', (tester) async {
    expect(await namelessButtons(tester, const SignUpScreen()), isEmpty);
  });

  testWidgets('ayarlar ekranındaki düğmelerin adı var', (tester) async {
    expect(
      await namelessButtons(tester, SettingsScreen(repository: repository)),
      isEmpty,
    );
  });

  testWidgets('favoriler ekranındaki düğmelerin adı var', (tester) async {
    expect(
      await namelessButtons(
        tester,
        FavoriteQuestionsScreen(repository: repository),
      ),
      isEmpty,
    );
  });

  testWidgets('profil ekranındaki düğmelerin adı var', (tester) async {
    expect(
      await namelessButtons(
        tester,
        Scaffold(body: ProfileScreen(repository: repository)),
      ),
      isEmpty,
    );
  });
}
