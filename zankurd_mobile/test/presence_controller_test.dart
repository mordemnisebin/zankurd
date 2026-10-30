import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/services/presence_controller.dart';

import 'support/widget_test_helpers.dart';

class _Gateway implements PresenceGateway {
  bool visible = false;
  bool fail = false;
  bool failTouch = false;
  int touches = 0;
  Completer<bool>? pendingRead;
  Completer<void>? pendingWrite;

  @override
  Future<bool> loadVisibility() async {
    if (fail) throw StateError('offline');
    return pendingRead?.future ?? visible;
  }

  @override
  Future<void> setVisibility(bool value) async {
    if (fail) throw StateError('offline');
    await pendingWrite?.future;
    visible = value;
  }

  @override
  Future<void> touch() async {
    if (fail || failTouch) throw StateError('offline');
    touches++;
  }
}

void main() {
  for (final ku in [false, true]) {
    testWidgets('E9 çevrimiçi ve son görülme açıklaması ($ku)', (tester) async {
      freshMockRepository();
      final auth = AuthProvider.test();
      auth.presence.bind(_Gateway(), userId: 'guest');
      auth.presence.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpWidget(
        testShell(
          authProvider: auth,
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          child: SettingsScreen(repository: MockZanKurdRepository()),
        ),
      );
      await tester.pumpAndSettle();
      final text = Tr.forKu(K.presenceVisibilitySub, ku);
      expect(text, contains(ku ? 'serhêl' : 'çevrimiçi'));
      expect(text, contains(ku ? 'dawî' : 'son görülme'));
      expect(text, contains(ku ? 'girtî' : 'kapalı'));
      final subtitle = find.text(text);
      await tester.ensureVisible(subtitle);
      await tester.pumpAndSettle();
      expect(subtitle, findsOneWidget);
      expect(
        tester.widget<Text>(subtitle).style!.fontSize,
        greaterThanOrEqualTo(14),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('T1 gecikmiş okuma arka planda touch başlatmaz; hızlı '
      'yanıt veren testler yaşam döngüsü yarışını gizliyordu', (tester) async {
    final pending = Completer<bool>();
    final gateway = _Gateway()..pendingRead = pending;
    final controller = PresenceController();
    try {
      controller.bind(gateway, userId: 'guest');
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      pending.complete(true);
      await tester.pump();
      expect(gateway.touches, 0);
      gateway.pendingRead = null;
      gateway.visible = true;
      gateway.failTouch = true;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.takeException(), isNull);
      gateway.failTouch = false;
      await tester.pump(const Duration(minutes: 2));
      expect(gateway.touches, 1);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('T1 ayar sunucu onayını bekler ve dar ekrana sığar; eski '
      'ekranda varlık anahtarı ve hata yolu yoktu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = AuthProvider.test();
    final gateway = _Gateway();
    auth.presence.bind(gateway, userId: 'guest');
    auth.presence.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpWidget(
      testShell(
        authProvider: auth,
        child: SettingsScreen(repository: MockZanKurdRepository()),
      ),
    );
    await tester.pumpAndSettle();
    final control = find.byKey(const ValueKey('presence-visibility-switch'));
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(control).value, isFalse);
    gateway.pendingWrite = Completer<void>();
    await tester.tap(control);
    await tester.pump();
    expect(tester.widget<Switch>(control).value, isFalse);
    expect(tester.widget<Switch>(control).onChanged, isNull);
    gateway.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(control).value, isTrue);
    expect(gateway.touches, 1);
    gateway.fail = true;
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(control).value, isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('T1 varsayılan kapalı ve oturumsuz bildirim yok; XP temelli '
      'testler izinsiz paylaşımı ölçmüyordu', (tester) async {
    final gateway = _Gateway();
    final controller = PresenceController();
    try {
      controller.bind(gateway, userId: null);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(minutes: 4));
      expect(controller.enabled, isFalse);
      expect(gateway.touches, 0);
      controller.updateSession('guest');
      await tester.pump();
      expect(gateway.touches, 0);
      expect(await controller.setEnabled(true), isTrue);
      await tester.pump();
      expect(gateway.touches, 1);
      await tester.pump(const Duration(seconds: 119));
      expect(gateway.touches, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(gateway.touches, 2);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('T1 arka planda durur, dönüşte yenilenir, çıkışta susar; '
      'yalnız satır testleri yaşam döngüsünü kaçırıyordu', (tester) async {
    final gateway = _Gateway()..visible = true;
    final controller = PresenceController();
    controller.bind(gateway, userId: 'guest');
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(gateway.touches, 1);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      controller.didChangeAppLifecycleState(state);
      await tester.pump(const Duration(minutes: 4));
      expect(gateway.touches, 1);
    }
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(gateway.touches, 2);
    controller.updateSession(null);
    await tester.pump(const Duration(minutes: 4));
    expect(controller.enabled, isFalse);
    expect(gateway.touches, 2);
    controller.dispose();
    await tester.pump(const Duration(minutes: 4));
    expect(gateway.touches, 2);
  });

  testWidgets('T1 tercih kapanırken kalp atışı durur ve hata sahte başarı '
      'olmaz; önce ayar sunucuya yazılmıyordu', (tester) async {
    final gateway = _Gateway()..visible = true;
    final controller = PresenceController();
    try {
      controller.bind(gateway, userId: 'user');
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      gateway.pendingWrite = Completer<void>();
      final save = controller.setEnabled(false);
      await tester.pump(const Duration(minutes: 2));
      expect(gateway.touches, 1);
      gateway.pendingWrite!.complete();
      // The request timed out: never claim that the server saved it.
      expect(await save, isFalse);
      gateway.pendingWrite = null;
      // Geç yazma tamamlandıktan sonra sunucu tercihi yeniden okunur.
      await tester.pump();
      expect(controller.canChange, isTrue);
      expect(await controller.setEnabled(false), isTrue);
      await tester.pump(const Duration(minutes: 4));
      expect(controller.enabled, isFalse);
      expect(gateway.touches, 1);
      gateway.fail = true;
      expect(await controller.setEnabled(true), isFalse);
      expect(controller.enabled, isFalse);
      await tester.pump(const Duration(minutes: 2));
      expect(tester.takeException(), isNull);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('T1 geç eski hesap yanıtı yeni hesaba sızmaz; tek hesap '
      'örnekleri yarış durumunu gizliyordu', (tester) async {
    final gateway = _Gateway()..pendingRead = Completer<bool>();
    final controller = PresenceController();
    try {
      controller.bind(gateway, userId: 'old');
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      final old = gateway.pendingRead!;
      gateway.pendingRead = null;
      controller.updateSession('new');
      old.complete(true);
      await tester.pump();
      expect(controller.enabled, isFalse);
      expect(gateway.touches, 0);
    } finally {
      controller.dispose();
    }
  });

  testWidgets('T1 başka cihazda kapatılan tercih sonraki turda okunur; '
      'yerel önbellek tek başına mahremiyeti korumaz', (tester) async {
    final gateway = _Gateway()..visible = true;
    final controller = PresenceController();
    try {
      controller.bind(gateway, userId: 'guest');
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      gateway.visible = false;
      await tester.pump(const Duration(minutes: 2));
      expect(controller.enabled, isFalse);
      expect(gateway.touches, 1);
    } finally {
      controller.dispose();
    }
  });
}
