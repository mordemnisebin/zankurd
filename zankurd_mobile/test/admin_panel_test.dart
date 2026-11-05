// Yönetim bölümü (2.2) — maket aşaması bekçisi.
//
// Korunan sözleşme:
//  * Giriş YALNIZ yönetici deposu kayıtlıysa VE `isAdmin()` true ise görünür.
//    Yönetici olmayan hesapta ya da depo hiç yokken (üretim) hiçbir iz
//    çizilmez. Bu vitrin kapısıdır; asıl yetki sunucudadır
//    (supabase/2026-11-12_yonetim_paneli.sql, tool/test_yonetim_paneli_local.mjs).
//  * Her bölüm hem dolu hem boş durumda çizilir ve işlemler depoya gider.
//  * Hem Türkçe hem Kurmancî çizilir (anahtar eksikse Tr.of atar).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:zankurd_mobile/src/data/admin_repository.dart';
import 'package:zankurd_mobile/src/data/mock_admin_repository.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/admin.dart';
import 'package:zankurd_mobile/src/screens/admin/admin_entry_row.dart';
import 'package:zankurd_mobile/src/screens/admin/admin_home_screen.dart';
import 'package:zankurd_mobile/src/screens/admin/admin_notify_screen.dart';
import 'package:zankurd_mobile/src/screens/admin/admin_content_screen.dart';
import 'package:zankurd_mobile/src/screens/admin/admin_rewards_screen.dart';
import 'package:zankurd_mobile/src/screens/admin/admin_users_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool ku = false,
  double height = 1800,
}) async {
  await tester.binding.setSurfaceSize(Size(390, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(child: child, languageProvider: ku ? kurmanciLang() : null),
  );
  await tester.pumpAndSettle();
}

String _t(String key, [Map<String, String>? params]) =>
    Tr.of(key, AppLanguage.tr, params);

Widget _settings(AdminRepository? admin) {
  final settings = SettingsScreen(repository: freshMockRepository());
  if (admin == null) return settings;
  return Provider<AdminRepository>.value(value: admin, child: settings);
}

void main() {
  group('giriş görünürlüğü', () {
    testWidgets('yönetici deposu yoksa Ayarlar\'da Yönetim yok', (t) async {
      await _pump(t, _settings(null));
      expect(find.byKey(const ValueKey('settings-admin-entry')), findsNothing);
      expect(find.text(_t(K.adminEntry)), findsNothing);
    });

    testWidgets('admin değilse (isAdmin=false) giriş görünmez', (t) async {
      await _pump(t, _settings(MockAdminRepository(admin: false)));
      expect(find.byKey(const ValueKey('settings-admin-entry')), findsNothing);
      expect(find.text(_t(K.adminEntry)), findsNothing);
    });

    testWidgets('isAdmin hata verirse giriş görünmez', (t) async {
      await _pump(t, _settings(_ThrowingAdminRepository()));
      expect(find.byKey(const ValueKey('settings-admin-entry')), findsNothing);
    });

    testWidgets('admin ise giriş görünür ve panoyu açar', (t) async {
      await _pump(t, _settings(MockAdminRepository()));
      final entry = find.byKey(const ValueKey('settings-admin-entry'));
      expect(entry, findsOneWidget);
      await t.tap(entry);
      await t.pumpAndSettle();
      expect(find.text(_t(K.adminOverviewTitle)), findsOneWidget);
      expect(find.text('1284'), findsOneWidget);
    });
  });

  group('pano', () {
    testWidgets('dolu: toplam sayılar, bölüm girişleri, son işlemler', (
      t,
    ) async {
      await _pump(t, AdminHomeScreen(repository: MockAdminRepository()));
      for (final value in ['1284', '96', '412', '7', '63', '—']) {
        expect(find.text(value), findsWidgets, reason: value);
      }
      expect(
        find.byKey(const ValueKey('admin-open-questions')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('admin-open-rewards')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-open-users')), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-open-notify')), findsOneWidget);
      expect(find.text(_t(K.adminActApprove)), findsOneWidget);
    });

    testWidgets('boş: sıfırlar ve "henüz işlem yok"', (t) async {
      await _pump(
        t,
        AdminHomeScreen(repository: MockAdminRepository(empty: true)),
      );
      expect(find.text('1284'), findsNothing);
      expect(find.text(_t(K.adminNoActions)), findsOneWidget);
    });

    testWidgets('Kurmancî çizilir', (t) async {
      await _pump(
        t,
        AdminHomeScreen(repository: MockAdminRepository()),
        ku: true,
      );
      expect(
        find.text(Tr.of(K.adminOverviewTitle, AppLanguage.ku)),
        findsOneWidget,
      );
    });
  });

  group('soru yönetimi', () {
    testWidgets('önerilen: onayla öneriyi kuyruktan düşürür', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminQuestionsScreen(repository: repo));
      expect(find.text('Şerefname kê nivîsandiye?'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-approve-s1')));
      await t.pumpAndSettle();
      expect(find.text('Şerefname kê nivîsandiye?'), findsNothing);
      expect(repo.auditCount, 4);
    });

    testWidgets('önerilen: reddet onay ister, vazgeçince kalır', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminQuestionsScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-reject-s2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-cancel')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-reject-s2')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-reject-s2')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-reject-s2')), findsNothing);
    });

    testWidgets('önerilen: düzelt ekranı kaydedince öneri onaylanır', (
      t,
    ) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminQuestionsScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-fix-s3')));
      await t.pumpAndSettle();
      await t.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('admin-edit-prompt')),
          matching: find.byType(EditableText),
        ),
        'Newroz kîjan roj tê pîrozkirin?',
      );
      await t.tap(find.byKey(const ValueKey('admin-edit-correct-1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-edit-save')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-fix-s3')), findsNothing);
    });

    testWidgets('bildirilen: emekli et ve bildirimi kapat', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminQuestionsScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-tab-reported')));
      await t.pumpAndSettle();
      expect(
        find.text('Çiyayê herî bilind ê Kurdistanê kîjan e?'),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('admin-retire-r1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('admin-retire-r1')), findsNothing);
      await t.tap(find.byKey(const ValueKey('admin-dismiss-r2')));
      await t.pumpAndSettle();
      expect(find.text(_t(K.adminEmptyReported)), findsOneWidget);
    });

    testWidgets('boş: üç sekme de boş durumu çizer', (t) async {
      final repo = MockAdminRepository(empty: true);
      await _pump(t, AdminQuestionsScreen(repository: repo));
      expect(find.text(_t(K.adminEmptySuggested)), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-tab-reported')));
      await t.pumpAndSettle();
      expect(find.text(_t(K.adminEmptyReported)), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-tab-people')));
      await t.pumpAndSettle();
      expect(find.text(_t(K.adminEmptyPeople)), findsOneWidget);
    });

    testWidgets('katkıcı ödüllendirme onaydan sonra jeton yazar', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminQuestionsScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-tab-people')));
      await t.pumpAndSettle();
      expect(find.text('Baran'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-reward-u-baran')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      final people = await repo.loadContributors();
      expect(people.firstWhere((p) => p.name == 'Baran').rewardedCoins, 100);
    });
  });

  group('ödüller', () {
    testWidgets('günlük: ilk 3 görünür, jeton ver onaydan sonra "Verildi"', (
      t,
    ) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminRewardsScreen(repository: repo));
      expect(find.text('Berfin'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-grant-coins-u-berfin')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      expect(find.text(_t(K.adminRewardGiven)), findsOneWidget);
      expect(
        find.byKey(const ValueKey('admin-grant-coins-u-berfin')),
        findsNothing,
      );
    });

    testWidgets('haftalık sekme ve otomatik ödül anahtarı', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminRewardsScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-period-weekly')));
      await t.pumpAndSettle();
      expect(find.text('Rojda'), findsOneWidget);
      expect(find.text('2026-11-09'), findsOneWidget);
      expect(await repo.loadAutoReward(), isFalse, reason: 'varsayılan KAPALI');
      await t.tap(find.byKey(const ValueKey('admin-auto-reward-switch')));
      await t.pumpAndSettle();
      expect(await repo.loadAutoReward(), isTrue);
    });

    testWidgets('boş: katılan yok', (t) async {
      await _pump(
        t,
        AdminRewardsScreen(repository: MockAdminRepository(empty: true)),
      );
      expect(find.text(_t(K.adminEmptyRewards)), findsOneWidget);
    });
  });

  group('kullanıcılar ve şikâyetler', () {
    testWidgets('uyar → durum rozeti değişir, kısıtı kaldır geri alır', (
      t,
    ) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminUsersScreen(repository: repo));
      expect(find.text('Oyuncu4821'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('admin-user-warn-u-x1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admin-user-lift-u-x1')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('admin-user-lift-u-x1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admin-user-warn-u-x1')),
        findsOneWidget,
      );
    });

    testWidgets('askıya al süreyi rozete yazar', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminUsersScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-user-suspend-u-x1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      expect(
        find.text(_t(K.adminStateSuspended, {'days': '7'})),
        findsOneWidget,
      );
    });

    testWidgets('boş: açık şikâyet yok', (t) async {
      await _pump(
        t,
        AdminUsersScreen(repository: MockAdminRepository(empty: true)),
      );
      expect(find.text(_t(K.adminEmptyUsers)), findsOneWidget);
    });
  });

  group('yeni soru formu', () {
    testWidgets('boş form kaydedilemez; doldurunca depoya gider', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminQuestionsScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-new-question')));
      await t.pumpAndSettle();
      _Save save() => _Save(
        t.widget<SahneButton>(find.byKey(const ValueKey('admin-new-save'))),
      );
      expect(save().enabled, isFalse);
      await t.tap(find.byKey(const ValueKey('admin-new-category-Dîrok')));
      await t.enterText(
        find.byKey(const ValueKey('admin-new-prompt')),
        'Şerefname kê nivîsand?',
      );
      for (var i = 0; i < 4; i++) {
        await t.enterText(
          find.byKey(ValueKey('admin-new-option-$i')),
          'Şık $i',
        );
      }
      await t.pump();
      expect(save().enabled, isFalse, reason: 'açıklama yok');
      await t.enterText(
        find.byKey(const ValueKey('admin-new-explanation-ku')),
        'Ravekirin',
      );
      await t.tap(find.byKey(const ValueKey('admin-new-correct-2')));
      await t.pump();
      expect(save().enabled, isTrue);
      await t.ensureVisible(find.byKey(const ValueKey('admin-new-save')));
      await t.tap(find.byKey(const ValueKey('admin-new-save')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      expect(repo.added, hasLength(1));
      final q = repo.added.single;
      expect(q.category, 'Dîrok');
      expect(q.correctIndex, 2);
      expect(q.options, ['Şık 0', 'Şık 1', 'Şık 2', 'Şık 3']);
      expect(q.explanationKu, 'Ravekirin');
      expect(q.explanationTr, isNull);
      // Form kapandı, soru ekranına dönüldü.
      expect(find.byKey(const ValueKey('admin-new-save')), findsNothing);
    });

    testWidgets('aynı şık iki kez yazılırsa kaydedilemez', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminNewQuestionScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-new-category-Ziman')));
      await t.enterText(
        find.byKey(const ValueKey('admin-new-prompt')),
        'Soru?',
      );
      for (var i = 0; i < 4; i++) {
        await t.enterText(
          find.byKey(ValueKey('admin-new-option-$i')),
          i == 3 ? ' ABC' : (i == 0 ? 'abc' : 'x$i'),
        );
      }
      await t.enterText(
        find.byKey(const ValueKey('admin-new-explanation-tr')),
        'Açıklama',
      );
      await t.pump();
      expect(
        t
            .widget<SahneButton>(find.byKey(const ValueKey('admin-new-save')))
            .onPressed,
        isNull,
      );
    });
  });

  group('pano: çökme bilinmiyor', () {
    testWidgets('çökme sayısı null ise "—" çizilir, 0 uydurulmaz', (t) async {
      await _pump(t, AdminHomeScreen(repository: MockAdminRepository()));
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('anlık bildirimler', () {
    testWidgets('anahtar tercihi depoya yazar', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminNotifyScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-notify-suggestion')));
      await t.pumpAndSettle();
      final prefs = await repo.loadNotifyPrefs();
      expect(prefs[AdminNotifyKind.suggestion], isFalse);
      expect(prefs[AdminNotifyKind.report], isTrue);
    });
  });

  group('2.1.2 W8: yönetim düzeltmeleri', () {
    testWidgets('#7: uyarılmış oyuncuya engelle/askıya al hâlâ sunulur', (
      t,
    ) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminUsersScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-user-warn-u-x1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      // Uyarı sonrası: uyar yok, askıya al + engelle + kaldır var.
      expect(find.byKey(const ValueKey('admin-user-warn-u-x1')), findsNothing);
      expect(
        find.byKey(const ValueKey('admin-user-suspend-u-x1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-user-block-u-x1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('admin-user-lift-u-x1')),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('admin-user-block-u-x1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pumpAndSettle();
      // Engelli: yalnız kaldır.
      expect(find.byKey(const ValueKey('admin-user-block-u-x1')), findsNothing);
      expect(
        find.byKey(const ValueKey('admin-user-lift-u-x1')),
        findsOneWidget,
      );
    });

    testWidgets('#5: geçmiş döneme gidilir ve son döneme dönülür', (t) async {
      final repo = MockAdminRepository();
      await _pump(t, AdminRewardsScreen(repository: repo));
      expect(find.text('2026-11-12'), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-period-next')), findsNothing);
      await t.tap(find.byKey(const ValueKey('admin-period-prev')));
      await t.pumpAndSettle();
      expect(find.text('2026-11-11'), findsOneWidget);
      expect(find.byKey(const ValueKey('admin-period-prev')), findsNothing);
      await t.tap(find.byKey(const ValueKey('admin-period-next')));
      await t.pumpAndSettle();
      expect(find.text('2026-11-12'), findsOneWidget);
      // Tür değişince son döneme döner.
      await t.tap(find.byKey(const ValueKey('admin-period-prev')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-period-weekly')));
      await t.pumpAndSettle();
      expect(find.text('2026-11-09'), findsOneWidget);
    });

    testWidgets('#14: ödül verilmediyse "Kaydedildi" denmez, neden söylenir', (
      t,
    ) async {
      final repo = _RefusingRewardRepository(AdminGrantOutcome.alreadyRewarded);
      await _pump(t, AdminRewardsScreen(repository: repo));
      await t.tap(find.byKey(const ValueKey('admin-grant-coins-u-berfin')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pump();
      expect(find.text(_t(K.adminRewardAlready)), findsOneWidget);
      expect(find.text(_t(K.adminDone)), findsNothing);
    });

    testWidgets('#17: aynı derece başka birine verilmişse nedeni söylenir', (
      t,
    ) async {
      final taken = _RefusingRewardRepository(AdminGrantOutcome.rankTaken);
      await _pump(t, AdminRewardsScreen(repository: taken));
      await t.tap(find.byKey(const ValueKey('admin-grant-coins-u-berfin')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('admin-confirm-ok')));
      await t.pump();
      expect(find.text(_t(K.adminRewardRankTaken)), findsOneWidget);
    });

    testWidgets('#27: hesap değişince yönetici yetkisi yeniden sorulur', (
      t,
    ) async {
      final auth = _SwitchableAuthProvider('a');
      final repo = _PerUserAdminRepository(adminId: 'a', auth: auth);
      await t.pumpWidget(
        testShell(
          authProvider: auth,
          child: Provider<AdminRepository>.value(
            value: repo,
            child: const Scaffold(body: AdminEntryRow()),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-admin-entry')),
        findsOneWidget,
      );
      auth.switchTo('b'); // yönetici olmayan başka hesap
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-admin-entry')), findsNothing);
      expect(repo.queries, 2, reason: 'her hesap için yeniden soruldu');
      auth.switchTo('a');
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-admin-entry')),
        findsOneWidget,
      );
    });
  });

  group('hata dayanıklılığı', () {
    testWidgets('yükleme hatasında "yüklenemedi" + yeniden dene', (t) async {
      await _pump(t, AdminHomeScreen(repository: _ThrowingAdminRepository()));
      expect(find.text(_t(K.adminLoadFailed)), findsOneWidget);
      expect(find.text(_t(K.retry)), findsOneWidget);
    });
  });
}

class _ThrowingAdminRepository extends MockAdminRepository {
  @override
  Future<bool> isAdmin() async => throw StateError('ağ yok');

  @override
  Future<AdminStats> loadStats() async => throw StateError('ağ yok');
}

class _RefusingRewardRepository extends MockAdminRepository {
  _RefusingRewardRepository(this.outcome);
  final AdminGrantOutcome outcome;

  @override
  Future<AdminGrantOutcome> grantReward(
    AdminRewardPeriodKind kind,
    String periodKey, {
    required String userId,
    required int coins,
  }) async => outcome;
}

class _SwitchableAuthProvider extends FakeAuthProvider {
  _SwitchableAuthProvider(String id) : _id = id;
  String _id;

  @override
  User? get currentUser => User(
    id: _id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-11-01T00:00:00Z',
  );

  void switchTo(String id) {
    _id = id;
    notifyListeners();
  }
}

class _PerUserAdminRepository extends MockAdminRepository {
  _PerUserAdminRepository({required this.adminId, required this.auth});
  final String adminId;
  final _SwitchableAuthProvider auth;
  int queries = 0;

  @override
  Future<bool> isAdmin() async {
    queries++;
    return auth.currentUser?.id == adminId;
  }
}

class _Save {
  _Save(this.button);
  final SahneButton button;
  bool get enabled => button.onPressed != null;
}
