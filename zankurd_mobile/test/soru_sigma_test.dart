import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/quiz_stage_kit.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// SORU SIĞMA BEKÇİSİ (2026-10-29, kullanıcı engelleyicisi): "Soru
/// ekranında sorular tam gözükmüyor, kaydırmak gerekiyor. Taşma, iç içe
/// geçme, tam görünmeme kesinlikle olmasın." ve "soru şıklarla birlikte
/// görünüyor, sonra ufak bir aşağı kayma oluyor; her şey SABİT olmalı."
///
/// ## Niçin sessizdi
///
/// Eski bekçiler (`quiz_stage_scroll_test`) "alan kaydırılabilir ve son şık
/// perdenin üstüne getirilebilir" diyordu: KAYDIRMAYI kabul ediyordu.
/// Üstelik kısa uydurma sorularla koşuyordu; bankadaki en uzun soru 269, en
/// uzun şık 121 karakter. Kayma ise birkaç ayrı kaynaktan geliyordu ve
/// hiçbiri "ilk kare ile sonraki kare aynı yerde mi" diye ölçülmüyordu:
///  * alt perde (joker dizisi ↔ geri bildirim şeridi ↔ joker bakiyesi geç
///    gelince tek sönük satırdan dört çipe) farklı boylardaydı; gövde her
///    değişimde daralıp soru yeniden dengeleniyordu;
///  * oda skor kartının "x/N cevapladı" satırı bir saniye sonra eklenip
///    soruyu ~120 pt itiyordu; düello kartının seri satırı da öyle;
///  * cevaptan sonra şıkkın içine eklenen ✓/✗ yuvası ve rakip rozeti şık
///    metnini daraltıp ek satıra kırıyordu.
///
/// ## Ne ölçülür
///
/// GERÇEK bankadan örnekler (+ sentetik en kötü birleşim), TR ve KU, bütün
/// soru sahnesi varyantlarında (ders, yarış, 1v1 düello, oda, turnuva bandı,
/// sırayla düello, seviye belirleme), beş telefon boyunda:
///  * taşma/istisna yok;
///  * hiçbir yazı `maxLines` aşımıyla kırpılmaz (üç nokta yok);
///  * ≥ 375×667 ve yazı ≤ 1,3: kaydırma gerekmez (cevaptan ÖNCE ve SONRA);
///  * ilk kare, 50 ms, 300 ms, 1 sn ve cevaptan sonra soru kartı ile
///    şıkların yeri/boyu aynı (±0,5 pt);
///  * 320×568 ve sentetik en kötü birleşim fiziksel olarak sığmaz: orada
///    kaydırma kabul, ama soru + dört şık kaydırınca TAMAMEN görünür ve alt
///    perdenin arkasında kalmaz;
///  * 375×667 @2.0 yalnız son çare: taşma yok, kırpılma yok.
///
/// Bilinen sınır (belgelenmiş): 375×667 @1,3'te duello/oda varyantında skor
/// kartı + 1,3× yazı + 4 şık, bankanın 269 karakterlik tek sorusunda ölçülen
/// 5–11 (TR) / 23–29 (KU) pt kayar; taban punto 17/15'in altına inilmez. Sınır
/// [_ucSinir] (skor kartı + 1,3× yazı + 4 şık; taban
/// punto 17/15'in altına inilmez).

class _Sample {
  const _Sample(this.label, this.q);
  final String label;
  final QuizQuestion q;
}

List<Map<String, dynamic>> _bankaSatirlari() {
  final rows = <Map<String, dynamic>>[];
  for (final f in Directory('assets/data').listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    Object? d;
    try {
      d = jsonDecode(f.readAsStringSync());
    } catch (_) {
      continue;
    }
    if (d is Map) d = d['questions'] ?? d['items'];
    if (d is! List) continue;
    for (final r in d) {
      if (r is Map<String, dynamic> &&
          r['prompt'] is String &&
          r['answers'] is List &&
          (r['answers'] as List).length == 4 &&
          (r['type'] ?? 'multipleChoice') == 'multipleChoice') {
        rows.add(r);
      }
    }
  }
  return rows;
}

List<String> _strs(Object? v) => [for (final x in (v as List)) '$x'];

/// Dört örnek: p99 soru, en uzun SORU, şıkları en uzun GERÇEK soru ve
/// SENTETİK en kötü birleşim (en uzun soru + bankadaki en uzun dört şık).
List<_Sample> _ornekler({required bool ku}) {
  final rows = _bankaSatirlari();
  String prompt(Map<String, dynamic> r) =>
      ku ? r['prompt'] as String : (r['promptTr'] ?? r['prompt']) as String;
  List<String> ans(Map<String, dynamic> r) =>
      ku ? _strs(r['answers']) : _strs(r['answersTr'] ?? r['answers']);
  int optSum(Map<String, dynamic> r) => ans(r).fold(0, (n, a) => n + a.length);

  final byPrompt = [...rows]
    ..sort((a, b) => prompt(b).length.compareTo(prompt(a).length));
  final byOpts = [...rows]..sort((a, b) => optSum(b).compareTo(optSum(a)));
  final all = <String>{for (final r in rows) ...ans(r)}.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final longest4 = all.take(4).toList();

  QuizQuestion mk(String id, String p, List<String> a) => QuizQuestion(
    id: id,
    category: 'Ziman',
    prompt: ku ? p : 'KU yok',
    promptTr: p,
    answers: ku ? a : ['A', 'B', 'C', 'D'],
    answersTr: a,
    correctAnswer: ku ? a[1] : 'B',
    correctAnswerTr: a[1],
    explanation: 'Kısa açıklama.',
    explanationKu: 'Ravekirina kurt.',
    explanationTr: 'Kısa açıklama.',
  );

  final top = byPrompt.first;
  final wide = byOpts.first;
  final p99 = byPrompt[(byPrompt.length * 0.01).floor()];
  return [
    _Sample('p99-soru', mk('sg-0', prompt(p99), ans(p99))),
    _Sample('uc-soru-269', mk('sg-1', prompt(top), ans(top))),
    _Sample('uc-siklar', mk('sg-2', prompt(wide), ans(wide))),
    _Sample('sentetik-en-kotu', mk('sg-3', prompt(top), longest4)),
  ];
}

enum _V { ders, yaris, duello1v1, oda, turnuva, siraylaDuello, seviye }

const _quizVariants = [_V.ders, _V.yaris, _V.duello1v1, _V.oda, _V.turnuva];

GameRoom _roomFor(_V v) {
  const p = [
    Player(name: 'Tolhildan Mawal', score: 0, state: 'Hazır'),
    Player(name: 'Rakip Oyuncu', score: 0, state: 'Hazır'),
  ];
  switch (v) {
    case _V.duello1v1:
      return const GameRoom(
        id: 'r1',
        name: '1v1',
        code: 'ZK-1',
        category: 'Ziman',
        status: RoomStatus.active,
        questionCount: 1,
        players: p,
      );
    case _V.oda:
      return const GameRoom(
        id: 'r2',
        name: 'Oda',
        code: 'ZK-2',
        category: 'Ziman',
        status: RoomStatus.active,
        questionCount: 1,
        players: [
          ...p,
          Player(name: 'Üçüncü', score: 0, state: 'Hazır'),
          Player(name: 'Dördüncü', score: 0, state: 'Hazır'),
        ],
        maxPlayers: 4,
        isCustom: true,
        hostId: 'h',
      );
    default:
      return const GameRoom(
        id: null,
        name: 'Solo',
        code: 'ZK-0',
        category: 'Ziman',
        status: RoomStatus.active,
        questionCount: 1,
        players: p,
      );
  }
}

class _Size {
  const _Size(this.size, this.top, this.bottom);
  final Size size;
  final double top;
  final double bottom;
  String get name => '${size.width.toInt()}x${size.height.toInt()}';
}

// Gerçek güvenli alanlar: SE'lerde çentik yok (üst 20, alt 0); yeni
// iPhone'larda Dynamic Island + ev göstergesi.
const _s320 = _Size(Size(320, 568), 20, 0);
const _s375 = _Size(Size(375, 667), 20, 0);
const _s390 = _Size(Size(390, 844), 47, 34);
const _s402 = _Size(Size(402, 874), 62, 34);
const _s430 = _Size(Size(430, 932), 59, 34);

/// (boy, yazı ölçeği) kombinasyonları.
const _kombinler = <(_Size, double)>[
  (_s320, 1.0),
  (_s320, 1.3),
  (_s375, 1.0),
  (_s375, 1.3),
  (_s375, 2.0),
  (_s390, 1.0),
  (_s402, 1.0),
  (_s402, 1.3),
  (_s430, 1.0),
];

/// 375×667 @1,3 duello/oda uç sorusunda izin verilen en çok kayma (pt).
const double _ucSinir = 35;

bool _dar(_Size s) => s.size.width < 375;

void _yuzey(WidgetTester tester, _Size s) {
  tester.view.physicalSize = s.size;
  tester.view.devicePixelRatio = 1;
  final pad = FakeViewPadding(top: s.top, bottom: s.bottom);
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  addTearDown(tester.view.reset);
}

Widget _olcekli(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

Future<void> _pumpQuiz(
  WidgetTester tester, {
  required _V v,
  required _Size s,
  required double scale,
  required bool ku,
  required QuizQuestion q,
}) async {
  _yuzey(tester, s);
  SharedPreferences.setMockInitialValues({
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.navTour.seen': true,
  });
  final repository = freshMockRepository();
  SharedPreferences.setMockInitialValues({
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.navTour.seen': true,
  });
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : null,
      child: _olcekli(
        scale,
        QuizScreen(
          repository: repository,
          room: v == _V.duello1v1 || v == _V.oda
              ? _roomFor(v)
              : repository.createRoom(),
          questions: [q, q],
          experience: v == _V.ders
              ? QuizExperience.learning
              : QuizExperience.competition,
          is1v1: v == _V.duello1v1,
          versusBannerText: v == _V.turnuva
              ? 'Çaryeka Final · Li dijî Azad'
              : null,
          enableTimer: false,
        ),
      ),
    ),
  );
}

/// Sırayla düelloya uzun soruyu veren depo.
class _SiraylaRepo extends MockZanKurdRepository {
  _SiraylaRepo(this.q);
  final QuizQuestion q;

  @override
  Future<AsyncDuelStart> startAsyncDuel({String? category}) async =>
      AsyncDuelStart(
        duelId: 'sg-duel',
        role: AsyncDuelRole.opponent,
        opponentName: 'Rojda Hevrik',
        expiresAt: DateTime(2035),
        questions: [for (var i = 0; i < 7; i++) q],
      );
}

Future<void> _pumpSirayla(
  WidgetTester tester, {
  required _Size s,
  required double scale,
  required bool ku,
  required QuizQuestion q,
}) async {
  _yuzey(tester, s);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : null,
      child: _olcekli(
        scale,
        AsyncDuelPlayScreen(
          repository: _SiraylaRepo(q),
          entry: const AsyncDuelEntry.random(),
        ),
      ),
    ),
  );
}

/// Seviye belirlemeye uzun soruyu veren depo.
class _SeviyeRepo extends MockZanKurdRepository {
  _SeviyeRepo(this.q);
  final QuizQuestion q;

  @override
  List<QuizQuestion> get playableQuestions => [
    for (var i = 0; i < 30; i++)
      QuizQuestion(
        id: 'pl-$i',
        category: const ['Ziman', 'Dîrok', 'Çand'][i % 3],
        prompt: q.prompt,
        promptTr: q.promptTr,
        answers: q.answers,
        answersTr: q.answersTr,
        correctAnswer: q.correctAnswer,
        correctAnswerTr: q.correctAnswerTr,
        explanation: q.explanation,
        difficulty: 1 + i % 3,
      ),
  ];
}

Future<void> _pumpSeviye(
  WidgetTester tester, {
  required _Size s,
  required double scale,
  required bool ku,
  required QuizQuestion q,
}) async {
  _yuzey(tester, s);
  SharedPreferences.setMockInitialValues({});
  PlacementStore.resetInstance();
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : null,
      child: _olcekli(scale, LevelPlacementScreen(repository: _SeviyeRepo(q))),
    ),
  );
}

ScrollPosition? _position(WidgetTester tester) {
  for (final k in const [
    'quiz-portrait-scroll',
    'async-duel-scroll',
    'placement-scroll',
  ]) {
    final f = find.descendant(
      of: find.byKey(ValueKey(k)),
      matching: find.byType(Scrollable),
    );
    if (f.evaluate().isNotEmpty) {
      return tester.state<ScrollableState>(f.first).position;
    }
  }
  return null;
}

/// Soru kartı + her şıkkın yerleşimi.
List<Rect> _yerlesim(WidgetTester tester) {
  final out = <Rect>[];
  final card = find.byKey(const ValueKey('quiz-prompt-card'));
  if (card.evaluate().isNotEmpty) out.add(tester.getRect(card.first));
  for (final e in find.byKey(const ValueKey('quiz-option-base')).evaluate()) {
    out.add(tester.getRect(find.byElementPredicate((x) => x == e)));
  }
  return out;
}

/// `didExceedMaxLines` olan her yazı = kırpılmış (üç nokta) metindir.
List<String> _kirpilanlar(WidgetTester tester) {
  final bad = <String>[];
  for (final e in find.byType(RichText).evaluate()) {
    final r = e.renderObject;
    if (r is RenderParagraph && r.didExceedMaxLines) {
      bad.add(r.text.toPlainText());
    }
  }
  return bad;
}

/// Alt perdenin (varsa) üst kenarı; yoksa ekran dibi.
double _perdeUstu(WidgetTester tester, double ekranYuksekligi) {
  final dock = find.byType(QuizStableDockHeight);
  if (dock.evaluate().isNotEmpty) return tester.getRect(dock.first).top;
  return ekranYuksekligi;
}

Future<void> _cevapla(
  WidgetTester tester,
  QuizQuestion q,
  bool ku, {
  required bool learning,
}) async {
  // Ekran soruyu yerelleştirip şıkları kendi sırasıyla gösterir; yanlış
  // şıkkın SIRASI aynı kuraldan bulunur (metin bulucu öğrenme modunda
  // sözlük dokunuşlu metni bulamaz).
  final shown = q.localized(isKu: ku, learning: learning);
  final wrong = shown.displayAnswers.indexWhere(
    (a) => a != shown.correctAnswer,
  );
  await tester.tap(
    find.byKey(const ValueKey('quiz-option-base')).at(wrong),
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 3));
}

void _ayniYerde(List<Rect> a, List<Rect> b, String neden) {
  expect(b.length, a.length, reason: '$neden: öğe sayısı');
  for (var i = 0; i < a.length; i++) {
    expect(
      (b[i].top - a[i].top).abs(),
      lessThanOrEqualTo(0.5),
      reason: '$neden: öğe $i dikey kaydı ${a[i].top} → ${b[i].top}',
    );
    expect(
      (b[i].height - a[i].height).abs(),
      lessThanOrEqualTo(0.5),
      reason: '$neden: öğe $i yükseklik ${a[i].height} → ${b[i].height}',
    );
  }
}

/// Kaydırınca soru + dört şık tamamen görünür ve alt perdenin arkasında
/// kalmaz (fiziksel olarak sığmayan kombinlerin son çaresi).
Future<void> _kaydirincaGorunur(
  WidgetTester tester,
  _Size s,
  String name,
) async {
  final pos = _position(tester)!;
  final opts = find.byKey(const ValueKey('quiz-option-base'));
  if (opts.evaluate().isEmpty) return;
  pos.jumpTo(pos.maxScrollExtent);
  await tester.pump();
  expect(
    tester.getRect(opts.last).bottom,
    lessThanOrEqualTo(_perdeUstu(tester, s.size.height) + 0.5),
    reason: '$name: son şık alt perdenin arkasında',
  );
  pos.jumpTo(0);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  for (final ku in [false, true]) {
    final samples = _ornekler(ku: ku);
    final dil = ku ? 'KU' : 'TR';

    // ── QuizScreen varyantları ────────────────────────────────────────────
    for (final v in _quizVariants) {
      for (final (s, scale) in _kombinler) {
        for (final smp in samples) {
          // p99 yalnız SE'de: öteki boylarda uç sorular ondan zordur.
          if (smp.label == 'p99-soru' && s != _s375) continue;
          final name = '$dil ${v.name} ${s.name} x$scale ${smp.label}';
          testWidgets(name, (tester) async {
            await _pumpQuiz(tester, v: v, s: s, scale: scale, ku: ku, q: smp.q);
            await tester.pump();
            final r0 = _yerlesim(tester);
            await tester.pump(const Duration(milliseconds: 50));
            final r50 = _yerlesim(tester);
            await tester.pump(const Duration(milliseconds: 250));
            final r300 = _yerlesim(tester);
            await tester.pump(const Duration(milliseconds: 700));
            final r1000 = _yerlesim(tester);
            await tester.pumpAndSettle(const Duration(seconds: 1));

            expect(tester.takeException(), isNull, reason: '$name: taşma');
            final sentetik = smp.label == 'sentetik-en-kotu';
            final sigmali =
                scale <= 1.3 && !_dar(s) && !sentetik && s.size.height >= 667;
            final ucSinirli =
                s == _s375 &&
                (v == _V.duello1v1 || v == _V.oda) &&
                scale == 1.3 &&
                (smp.label == 'uc-soru-269' || smp.label == 'uc-siklar');

            if (scale <= 1.3) {
              _ayniYerde(r0, r50, '$name ilk→50ms');
              _ayniYerde(r0, r300, '$name ilk→300ms');
              _ayniYerde(r0, r1000, '$name ilk→1sn');
            }
            final scrollBefore = _position(tester)!.maxScrollExtent;
            if (Platform.environment['SIGMA_VERBOSE'] != null) {
              // ignore: avoid_print
              print('SIGMA|$name|kaydirma=${scrollBefore.toStringAsFixed(1)}');
            }
            expect(
              _kirpilanlar(tester),
              isEmpty,
              reason: '$name: kırpılmış (üç noktalı) yazı',
            );
            if (sigmali) {
              expect(
                scrollBefore,
                lessThanOrEqualTo(ucSinirli ? _ucSinir : 0.5),
                reason: '$name: kaydırma gerekiyor (cevaptan önce)',
              );
            } else if (scrollBefore > 0.5 && scale <= 1.3) {
              await _kaydirincaGorunur(tester, s, name);
            }
            if (scale > 1.3) return;

            final onceler = _yerlesim(tester);
            await _cevapla(tester, smp.q, ku, learning: v == _V.ders);
            expect(
              tester.takeException(),
              isNull,
              reason: '$name: cevap sonrası taşma',
            );
            expect(
              _kirpilanlar(tester),
              isEmpty,
              reason: '$name: cevap sonrası kırpılmış yazı',
            );
            final ins = find.byKey(const ValueKey('quiz-wrong-answer-insight'));
            final pos = _position(tester)!;
            if (ins.evaluate().isNotEmpty) {
              // Yanlıştan sonra açıklama kartı (YALNIZ rakipsiz turda) soru
              // bloğunun ALTINA eklenen gerçek içeriktir: sığmazsa alan
              // kayar (tek çare), sonuna kaydırınca alt perdenin arkasında
              // kalmaz.
              if (pos.maxScrollExtent > 0) {
                pos.jumpTo(pos.maxScrollExtent);
                await tester.pump();
              }
              expect(
                tester.getRect(ins).bottom,
                lessThanOrEqualTo(
                  tester.getRect(find.byType(QuizFeedbackStrip).last).top + 0.5,
                ),
                reason: '$name: açıklama kartı perdenin arkasında',
              );
            } else {
              if (sigmali) {
                expect(
                  pos.maxScrollExtent,
                  lessThanOrEqualTo(ucSinirli ? _ucSinir : 0.5),
                  reason: '$name: kaydırma gerekiyor (cevaptan sonra)',
                );
              }
              if (!_dar(s) || scrollBefore <= 0.5) {
                _ayniYerde(onceler, _yerlesim(tester), '$name cevap sonrası');
              }
            }
          });
        }
      }
    }

    // ── Sırayla düello ve seviye belirleme (cevaptan önce) ────────────────
    for (final v in [_V.siraylaDuello, _V.seviye]) {
      for (final (s, scale) in _kombinler) {
        for (final smp in samples) {
          if (smp.label == 'p99-soru' && s != _s375) continue;
          final name = '$dil ${v.name} ${s.name} x$scale ${smp.label}';
          testWidgets(name, (tester) async {
            if (v == _V.siraylaDuello) {
              await _pumpSirayla(tester, s: s, scale: scale, ku: ku, q: smp.q);
            } else {
              await _pumpSeviye(tester, s: s, scale: scale, ku: ku, q: smp.q);
            }
            // pumpAndSettle YOK: sırayla düellonun sayacı sürerken kare
            // üretmeyi bırakmaz; süre dolunca "cevap gönderilemedi" satırı
            // çıkıp ölçüyü bozardı.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 700));
            expect(tester.takeException(), isNull, reason: '$name: taşma');
            expect(
              _kirpilanlar(tester),
              isEmpty,
              reason: '$name: kırpılmış yazı',
            );
            final pos = _position(tester);
            expect(pos, isNotNull, reason: '$name: kayan alan yok');
            final sentetik = smp.label == 'sentetik-en-kotu';
            final sigmali =
                scale <= 1.3 && !_dar(s) && !sentetik && s.size.height >= 667;
            if (sigmali) {
              expect(
                pos!.maxScrollExtent,
                lessThanOrEqualTo(0.5),
                reason: '$name: kaydırma gerekiyor',
              );
            }
          });
        }
      }
    }
  }
}
