import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/services/pronunciation_recorder.dart';
import 'package:zankurd_mobile/src/widgets/pronunciation_sheet.dart';

import 'support/widget_test_helpers.dart';

/// Telaffuz atölyesi (2026-10-26, ücretsiz).
///
/// Bekçi: izin reddinde kayıt başlamaz ve neden söylenir; kayıt durunca
/// kendi sesini dinlemek açılır ve aynı dosya çalınır; kayıt 4 saniyede
/// kendiliğinden durur; sayfa kapanınca kayıt dosyası silinir (kayıt
/// cihazda kalır sözü); mikrofon düğmesi yalnız referans sesi olan sözcükte
/// görünür (karşılaştırılacak bir şey olmalı); başlamayan kaydın yarım
/// dosyası ve önceki oturumdan kalan kayıt da silinir.
class _FakeSpeaker implements LessonListeningSpeaker {
  _FakeSpeaker({this.has = true});

  final bool has;
  final spoken = <String>[];
  final slows = <bool>[];

  @override
  bool get available => has;

  @override
  bool availableFor(String text) => has;

  @override
  ValueListenable<bool> get speakingListenable => ValueNotifier(false);

  @override
  Future<bool> speak(String text, {bool slow = false}) async {
    spoken.add(text);
    slows.add(slow);
    return true;
  }

  @override
  Future<void> stop() async {}
}

class _FakeRecorder implements PronunciationRecorder {
  _FakeRecorder({this.allowed = true, this.hangOnStart = false});

  final bool allowed;
  final bool hangOnStart;
  String? started;
  String? hungPath;
  int starts = 0;
  int stops = 0;

  @override
  Future<bool> hasPermission() async => allowed;

  @override
  Future<void> start(String path) async {
    if (hangOnStart) {
      starts++;
      // Gerçek kaydedici dosyayı açıp takılabilir: yarım dosya bırakır.
      File(path).writeAsStringSync('yarım');
      hungPath = path;
      return Completer<void>().future;
    }
    starts++;
    started = path;
    File(path).writeAsStringSync('ses');
  }

  @override
  Future<String?> stop() async {
    stops++;
    return started;
  }

  @override
  Future<void> dispose() async {}
}

class _FakePlayback implements PronunciationPlayback {
  final played = <String>[];

  @override
  Future<void> play(String path) async => played.add(path);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required _FakeRecorder recorder,
    required _FakePlayback playback,
    _FakeSpeaker? speaker,
  }) async {
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        child: Scaffold(
          body: SingleChildScrollView(
            child: PronunciationSheet(
              text: 'Rojbaş',
              speaker: speaker ?? _FakeSpeaker(),
              recorder: recorder,
              playback: playback,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.runAsync(() async {
      await tester.tap(find.byKey(ValueKey(key)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  testWidgets('izin reddinde kayıt başlamaz ve neden söylenir', (tester) async {
    final recorder = _FakeRecorder(allowed: false);
    await pumpSheet(tester, recorder: recorder, playback: _FakePlayback());

    await tapKey(tester, 'pronunciation-record');

    expect(recorder.starts, 0);
    expect(find.byKey(const ValueKey('pronunciation-denied')), findsOneWidget);
    expect(find.byKey(const ValueKey('pronunciation-recording')), findsNothing);
  });

  // Simülatörde ses girişi açılmayınca start hiç dönmüyordu ve düğme
  // sonsuza kadar dönüyordu (2026-10-26). Zaman aşımında vazgeçilir.
  testWidgets('kayıt başlamazsa düğme döner ve hata söylenir', (tester) async {
    final recorder = _FakeRecorder(hangOnStart: true);
    await pumpSheet(tester, recorder: recorder, playback: _FakePlayback());

    await tester.tap(find.byKey(const ValueKey('pronunciation-record')));
    await tester.pump();
    expect(recorder.starts, 1);
    await tester.pump(PronunciationSheet.startTimeout);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('pronunciation-start-failed')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('pronunciation-recording')), findsNothing);
    expect(File(recorder.hungPath!).existsSync(), isFalse);
  });

  // Uygulama kayıt sırasında kapatılırsa dispose çalışmaz; sonraki açılışta
  // eski kayıt süpürülür.
  testWidgets('önceki oturumdan kalan kayıt açılışta silinir', (tester) async {
    final stale = File(
      '${Directory.systemTemp.path}/zankurd_telaffuz_eski_test.m4a',
    )..writeAsStringSync('eski');
    await pumpSheet(
      tester,
      recorder: _FakeRecorder(),
      playback: _FakePlayback(),
    );
    expect(stale.existsSync(), isFalse);
  });

  testWidgets('dinle referans sesi çalar', (tester) async {
    final speaker = _FakeSpeaker();
    await pumpSheet(
      tester,
      recorder: _FakeRecorder(),
      playback: _FakePlayback(),
      speaker: speaker,
    );
    await tapKey(tester, 'pronunciation-listen');
    await tapKey(tester, 'pronunciation-listen-slow');
    expect(speaker.spoken, ['Rojbaş', 'Rojbaş']);
    expect(speaker.slows, [false, true]);
  });

  testWidgets('kaydet, durdur, sonra kendi sesini aynı dosyadan dinle', (
    tester,
  ) async {
    final recorder = _FakeRecorder();
    final playback = _FakePlayback();
    await pumpSheet(tester, recorder: recorder, playback: playback);

    await tapKey(tester, 'pronunciation-record');
    expect(recorder.starts, 1);
    expect(find.text('Kaydediliyor…'), findsOneWidget);

    await tapKey(tester, 'pronunciation-record');
    expect(recorder.stops, 1);
    expect(find.text('Kaydediliyor…'), findsNothing);

    await tapKey(tester, 'pronunciation-play-mine');
    expect(playback.played, [recorder.started]);
    File(recorder.started!).deleteSync();
  });

  testWidgets('kayıt 4 saniyede kendiliğinden durur', (tester) async {
    final recorder = _FakeRecorder();
    await pumpSheet(tester, recorder: recorder, playback: _FakePlayback());

    // Sayaç sahte saatte kurulsun diye gerçek zaman bölgesi kullanılmaz.
    await tester.tap(find.byKey(const ValueKey('pronunciation-record')));
    await tester.pump();
    expect(recorder.starts, 1);
    expect(recorder.stops, 0);
    await tester.pump(PronunciationSheet.maxRecording);
    await tester.pump();
    expect(recorder.stops, 1);
    expect(find.text('Kaydediliyor…'), findsNothing);
    File(recorder.started!).deleteSync();
  });

  testWidgets('sayfa kapanınca kayıt dosyası silinir', (tester) async {
    final recorder = _FakeRecorder();
    await pumpSheet(tester, recorder: recorder, playback: _FakePlayback());
    await tapKey(tester, 'pronunciation-record');
    await tapKey(tester, 'pronunciation-record');
    final path = recorder.started!;
    expect(File(path).existsSync(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(File(path).existsSync(), isFalse);
  });

  testWidgets('mikrofon düğmesi yalnız referans sesi olan sözcükte', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        child: Scaffold(
          body: Row(
            children: [
              PronunciationButton(text: 'Rojbaş', speaker: _FakeSpeaker()),
              PronunciationButton(
                text: 'Sesi yok',
                speaker: _FakeSpeaker(has: false),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('pronunciation-open')), findsOneWidget);
  });
}
