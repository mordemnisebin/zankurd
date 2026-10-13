// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';
import 'support/widget_test_helpers.dart';

class _SignOutTrackingAuthProvider extends AuthProvider {
  _SignOutTrackingAuthProvider() : super.test();

  bool _authenticated = true;
  int signOutCalls = 0;
  bool? discardPendingRewards;
  String? discardedRewardsOwnerId;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  bool get isLoading => false;

  @override
  Future<void> signOut({
    bool discardPendingRewards = false,
    String? pendingRewardsOwnerId,
  }) async {
    signOutCalls += 1;
    this.discardPendingRewards = discardPendingRewards;
    discardedRewardsOwnerId = pendingRewardsOwnerId;
    _authenticated = false;
    notifyListeners();
  }
}

class _CleanupFailingAuthProvider extends _SignOutTrackingAuthProvider {
  @override
  Future<void> signOut({
    bool discardPendingRewards = false,
    String? pendingRewardsOwnerId,
  }) async {
    await super.signOut(
      discardPendingRewards: discardPendingRewards,
      pendingRewardsOwnerId: pendingRewardsOwnerId,
    );
    throw const AccountLocalCleanupException();
  }
}

class _DeleteTrackingRepository extends MockZanKurdRepository {
  _DeleteTrackingRepository({this.shouldFail = false});

  final bool shouldFail;
  int deleteCalls = 0;

  @override
  Future<void> deleteMyAccount() async {
    deleteCalls += 1;
    if (shouldFail) {
      throw StateError('delete failed');
    }
  }
}

class _DeferredDeleteRepository extends _DeleteTrackingRepository {
  final Completer<void> deleteStarted = Completer<void>();
  final Completer<void> allowDelete = Completer<void>();

  @override
  Future<void> deleteMyAccount() async {
    deleteCalls += 1;
    deleteStarted.complete();
    await allowDelete.future;
  }
}

/// Hesap silme kartı 2026-07-22 UX denetiminden sonra ayarların en altına
/// taşındı (en yıkıcı eylem en üstte duruyordu). Testler artık ona
/// kaydırarak ulaşır.
Future<Finder> _scrollToDeleteAction(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey('delete-account-action'));
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return finder.first;
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  // 2026-09-29 Şahnê: bu iki bekçi eski görünüşü (Forest degrade + gölge)
  // sabitliyordu. Dil seçici artık ortak `LanguageToggle`dır (seçim rayının
  // sığan çeşidi); "ZK" degrade karosu logo işareti plakasına döndü.
  // Korunan şey: etkin dil görünür biçimde VE ekran okuyucuda seçili;
  // hakkında kartı marka işaretini ve sürümü birlikte taşır.
  testWidgets('ayarlar dil seçimi etkin dili seçili çiple gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('TR'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    SahneRailChip chip(String key) => tester.widget<SahneRailChip>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(SahneRailChip),
      ),
    );
    expect(chip('settings-language-tr').selected, isTrue);
    expect(chip('settings-language-ku').selected, isFalse);
  });

  testWidgets('ayarlar hakkında kartı marka işaretini ve sürümü taşır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byType(BrandMarkPlate),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(BrandMarkPlate), findsOneWidget);
    expect(find.text('ZK'), findsNothing);
    final plate = tester.getRect(find.byType(BrandMarkPlate));
    final brand = tester.getRect(find.text('ZanKurd'));
    expect(
      (plate.center.dy - brand.center.dy).abs(),
      lessThan(plate.height),
      reason: 'marka adı plakanın yanında durmalı',
    );
  });

  testWidgets('settings does not delete account before final confirmation', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final deleteAction = await _scrollToDeleteAction(tester);
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Hesabı kalıcı olarak sil?'), findsOneWidget);
    expect(repository.deleteCalls, 0);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
  });

  // 2026-10-02 uçtan uca QA: hesap silme onayının yıkıcı düğmesi "Devam et"
  // adıyla turuncu birincil (Agir) dolguydu. Silmeyi söylemiyordu ve göz
  // güvenli eylemi değil onu varsayılan sanıyordu. Niçin sessiz kalıyordu:
  // testler düğmeyi METNİYLE ("Devam et") tıklıyordu; renk ve ad hiçbir
  // yerde sabitlenmemişti. İki adımlı akış korunur.
  testWidgets('hesap silme onayı: yıkıcı eylem hata tonunda ve adı silmeyi '
      'söyler, güvenli eylem varsayılandır', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _DeleteTrackingRepository();

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(await _scrollToDeleteAction(tester));
    await tester.pumpAndSettle();

    final scheme = Theme.of(
      tester.element(find.byType(AlertDialog)),
    ).colorScheme;
    expect(find.text('Devam et'), findsNothing);
    final destructive = tester.widget<TextButton>(
      find.byKey(const ValueKey('delete-continue')),
    );
    expect(
      destructive.style!.foregroundColor!.resolve({}),
      scheme.error,
      reason: 'yıkıcı eylem hata tonunda olmalı',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('delete-continue')),
        matching: find.text('Hesabımı sil'),
      ),
      findsOneWidget,
    );
    // Güvenli eylem dolgulu varsayılan düğme.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('delete-keep')),
        matching: find.text('Vazgeç'),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget(find.byKey(const ValueKey('delete-keep'))),
      isA<FilledButton>(),
    );

    // İkinci adım: kalıcı silme de hata tonunda.
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    final forever = tester.widget<FilledButton>(
      find.byKey(const ValueKey('delete-forever')),
    );
    expect(forever.style!.backgroundColor!.resolve({}), scheme.error);
    expect(repository.deleteCalls, 0);
  });

  testWidgets('settings separates dangerous account actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: _DeleteTrackingRepository())),
    );
    await tester.pumpAndSettle();

    await _scrollToDeleteAction(tester);
    expect(find.text('Hesap işlemleri'), findsOneWidget);
    expect(find.text('Bu alandaki işlemler geri alınamaz.'), findsOneWidget);
    expect(find.text('Hesabımı sil'), findsOneWidget);
  });

  testWidgets('settings shows the package version in light and dark themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        testShell(
          themeProvider: ThemeProvider(initialMode: themeMode),
          child: SettingsScreen(
            repository: repository,
            packageInfoLoader: () async => PackageInfo(
              appName: 'ZanKurd',
              packageName: 'com.zankurd.app',
              version: '9.8.7',
              buildNumber: '654',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sürüm 9.8.7+654'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final versionText = find.text('Sürüm 9.8.7+654');
      expect(versionText, findsOneWidget);
      expect(
        Theme.of(tester.element(versionText)).brightness,
        themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('settings uses a neutral version when package info fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(
          repository: repository,
          packageInfoLoader: () async => throw StateError('unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Sürüm —'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sürüm —'), findsOneWidget);
    expect(find.textContaining('1.8.0+10'), findsNothing);
  });

  testWidgets('successful account deletion signs out to the auth gate', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository();
    final authProvider = _SignOutTrackingAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(repository: repository),
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    final deleteAction = await _scrollToDeleteAction(tester);
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'SIL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı olarak sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.deleteCalls, 1);
    expect(authProvider.signOutCalls, 1);
    expect(authProvider.discardPendingRewards, isTrue);
    expect(authProvider.discardedRewardsOwnerId, 'user');
  });

  testWidgets('deleted account reports local cleanup failure accurately', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository();
    final authProvider = _CleanupFailingAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(repository: repository),
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    final deleteAction = await _scrollToDeleteAction(tester);
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'SIL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı olarak sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.deleteCalls, 1);
    expect(authProvider.signOutCalls, 1);
    expect(find.textContaining('Hesap silindi ancak'), findsOneWidget);
    expect(find.textContaining('Hesap silinemedi'), findsNothing);
  });

  testWidgets('failed account deletion keeps the user in settings', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository(shouldFail: true);
    final authProvider = _SignOutTrackingAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(repository: repository),
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    final deleteAction = await _scrollToDeleteAction(tester);
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'SIL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı olarak sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.deleteCalls, 1);
    expect(authProvider.signOutCalls, 0);
    expect(authProvider.discardPendingRewards, isNull);
    // Silme başarısızsa ekrandan çıkılmamalı. Bu, "Ayarlar" metnini arayarak
    // doğrulanıyordu; başlık AppBar'dan kimlik kartına taşınınca (çift
    // başlık düzeltmesi) metin, listeyle birlikte kaydırılıp ağaçtan
    // düşebiliyor. Asıl iddia gezinme: ekran hâlâ yerinde mi?
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Hesap silinemedi. Tekrar dene.'), findsOneWidget);
  });

  testWidgets('account cleanup continues if settings unmounts after deletion', (
    tester,
  ) async {
    final repository = _DeferredDeleteRepository();
    final authProvider = _SignOutTrackingAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        authProvider: authProvider,
        child: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(repository: repository),
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    final deleteAction = await _scrollToDeleteAction(tester);
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'SIL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı olarak sil'));
    await tester.pump();
    await repository.deleteStarted.future;

    await tester.tap(find.byType(ZkBackButton));
    await tester.pumpAndSettle();
    repository.allowDelete.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(authProvider.signOutCalls, 1);
    expect(authProvider.discardPendingRewards, isTrue);
    expect(authProvider.discardedRewardsOwnerId, 'user');
  });

  // 2026-09-29 doğallık: bu iki bekçi çevrilmiş yer tutucuyu ("Lîstikvan",
  // "Oyuncu") kutunun DEĞERİ olarak sabitliyordu. Adını hiç seçmemiş oyuncu
  // "Oyuncu" adlı biri gibi görünüyordu ve yazmadan önce kutuyu silmesi
  // gerekiyordu. Şimdi kutu boştur, dile göre ipucu (`K.playerNameHint`)
  // görünür. Asıl kusur (Kurmancî arayüzde Türkçe ham yer tutucu) hâlâ
  // bekçide: `ZanKurd Oyuncusu` hiçbir biçimde görünmez.
  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('settings-player-name-field')),
          matching: find.byType(TextField),
        ),
      )
      .controller!
      .text;

  testWidgets('Kurmancî arayüzde yer tutucu ad kutuya yazılmaz', (
    tester,
  ) async {
    // Depo, gerçek bir seçim olmayan `ZanKurd Oyuncusu` yer tutucusunu
    // döndürür. Ayarlar ekranı ham değeri kutuya yazıyor ve Kurmancî
    // arayüzde oyuncu kendi adını Türkçe görüyordu (2026-07-26).
    await tester.pumpWidget(
      testShell(
        child: SettingsScreen(repository: MockZanKurdRepository()),
        languageProvider: kurmanciLang(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ZanKurd Oyuncusu'), findsNothing);
    expect(fieldText(tester), isEmpty);
    expect(find.text('Navê xwe binivîse…'), findsOneWidget);
  });

  testWidgets('Türkçe arayüzde kutu boş, ipucu Türkçe', (tester) async {
    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ZanKurd Oyuncusu'), findsNothing);
    expect(fieldText(tester), isEmpty);
    expect(find.text('Oyundaki adını gir…'), findsOneWidget);
  });

  testWidgets('Kaydet ad değişmeden kapalı, değişince birincil ve açık', (
    tester,
  ) async {
    // 2026-09-30 denetimi: ikincil çerçeveli "Kaydet" ad değişse de
    // değişmese de aynı görünüyordu; yazan kişi kaydedilecek bir şey olduğunu
    // fark etmiyordu. Şimdi değişmemişken kapalı, değişince Agir.
    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final saveFinder = find.widgetWithText(SahneButton, 'Kaydet');
    expect(saveFinder, findsOneWidget);
    FilledButton button() => tester.widget<FilledButton>(
      find.descendant(of: saveFinder, matching: find.byType(FilledButton)),
    );
    expect(button().onPressed, isNull);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('settings-player-name-field')),
        matching: find.byType(TextField),
      ),
      'Rojda',
    );
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });
}
