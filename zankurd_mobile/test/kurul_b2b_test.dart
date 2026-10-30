/// Kurul 1 (Opus 5.5 + GPT-6 Astra, Terra, Sol; 2026-10-29) öğrenme / profil
/// / sosyal / turnuva / belge bulguları (B2b).
///
/// Hepsi simülatör turunda (tur2 kareleri) en az iki modelin gördüğü ya da
/// Opus'un doğruladığı kusurlardı; işlev çalıştığı için hiçbir test
/// "oyuncu ne gördüğünü ve neyin doğru olduğunu anlıyor mu?" diye sormadı:
/// - C21 web gizlilik sayfası çökme kayıtlarına "anonim" diyor, tek ayardan
///   söz ediyor, varsayılanın kapalı olduğunu ve derslerin sunucuda
///   tutulduğunu yazmıyordu (uygulamadaki gizlilik metniyle çelişki).
/// - C22 arkadaş satırı, etkinlik zamanı bilinmeyen misafir için
///   "Henüz oynamadı" diye yanlış iddiada bulunuyordu.
/// - C23 seviye testi notu kartın yerini yanlış söylüyordu.
/// - C27 ders sonunda alıştırmaların zorunlu olmadığı ve neyin dersi
///   bitirdiği belirsizdi; sayaçlar etiketsizdi, kaplumbağa simgesi
///   açıklamasızdı.
/// - C28 harf karolarının ne yaptığı yazmıyordu; ders kartı alt düğmelerin
///   üstünde YARIM kesik görünüyordu.
/// - C32 bir finalist belli iken Final iki taraflı "Belirsiz"di; "VS" maçın
///   oynanmadığını söylemiyordu; sıralamadaki sayılar etiketsizdi.
/// - C33 SSS jeton cevabı tek uzun paragraftı.
/// - C34 rıza açıklamaları 14 pt soluk kalıyordu.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/widgets/lesson_listening_card.dart';
import 'package:zankurd_mobile/src/widgets/lesson_recall_card.dart';
import 'package:zankurd_mobile/src/widgets/lesson_scroll_edge_fade.dart';
import 'package:zankurd_mobile/src/widgets/lesson_vocab_tiles.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne_list_row.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

import 'support/widget_test_helpers.dart';

class _Speaker implements LessonListeningSpeaker {
  @override
  bool get available => true;
  @override
  bool availableFor(String text) => true;
  @override
  ValueListenable<bool> get speakingListenable => ValueNotifier(false);
  @override
  Future<bool> speak(String text, {bool slow = false}) async => true;
  @override
  Future<void> stop() async {}
}

const _entries = [
  LearnerLexiconEntry(
    id: 'a',
    termKu: 'Elîfbê',
    meaningTr: 'Alfabe',
    sourceId: 't',
  ),
  LearnerLexiconEntry(id: 'b', termKu: 'Tîp', meaningTr: 'Harf', sourceId: 't'),
];

TournamentMatch _m(
  String id,
  String a,
  String b, {
  String status = 'pending',
  String winner = '',
}) => TournamentMatch(
  id: id,
  playerOneId: a,
  playerOneName: a.toUpperCase(),
  playerTwoId: b,
  playerTwoName: b.toUpperCase(),
  playerOneScore: status == 'completed' ? 265 : 0,
  playerTwoScore: status == 'completed' ? 122 : 0,
  status: status,
  winnerId: winner,
);

void _surface(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  group('C21 web gizlilik sayfası uygulamayla aynı gerçekleri söyler', () {
    final html = File('web/privacy.html').readAsStringSync();
    test('çökme kaydı "anonim" değil, ayrı ayar, başlangıçta kapalı', () {
      expect(html, isNot(contains('anonim teknik kayıt')));
      expect(html, isNot(contains('tomarên teknîkî yên anonîm')));
      expect(html, contains('Hesap ve gizlilik › Hata raporları'));
      expect(html, contains('Hesap ve gizlilik › Kullanım analizi'));
      expect(html, contains('Bu ayar başlangıçta kapalıdır'));
      expect(html, contains('Ragihandinên çewtiyan'));
      expect(html, contains('Ev mîheng di destpêkê de girtî ye'));
      expect(html, isNot(contains('çökme kayıtlarını Ayarlar › Kullanım')));
    });
    test('tamamlanan dersler sunucuda, cihazda değil', () {
      expect(html, contains('tamamladığın dersler ise sunucuda'));
      expect(html, contains('dersên qedandî li ser serverê'));
      expect(html, isNot(contains('ji serverên me re nayên şandin')));
    });
  });

  test('C22 etkinlik bilinmiyorsa "Henüz oynamadı" iddiası yok', () {
    final src = File(
      'lib/src/widgets/friend_activity_label.dart',
    ).readAsStringSync();
    expect(src, contains('if (days == null) return null;'));
    expect(Tr.keys, isNot(contains('friends.neverPlayed')));
    expect(Tr.of(K.friendPlayedDaysAgo, AppLanguage.tr), contains('etkindi'));
  });

  test('C23 seviye testi notu kartın gerçek yerini söyler', () {
    final tr = Tr.of(K.placementSkippedNote, AppLanguage.tr);
    expect(tr, contains('Kurmancî öğren'));
    expect(tr, contains('Seviyeni bul'));
    expect(tr, contains('Ayarlar'));
    expect(tr, isNot(contains('ana sayfadaki')));
  });

  group('C27 ders sonu: neyin bitirdiği ve neyin isteğe bağlı olduğu', () {
    test('not alıştırmalardan önce, alıştırmalar başlık altında', () {
      final src = File(
        'lib/src/screens/learning_screen.dart',
      ).readAsStringSync();
      final hint = src.indexOf('const LessonFinishHint()');
      final header = src.indexOf('const LessonOptionalPracticeHeader()');
      final listening = src.indexOf('LessonListeningCard(\n');
      expect(hint, greaterThan(0));
      expect(header, greaterThan(hint));
      expect(listening, greaterThan(header));
    });

    testWidgets('son slayt birincil düğmesi "Dersi tamamla"', (tester) async {
      _surface(tester, const Size(320, 640));
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: LessonSlideNavigation(
              showBack: true,
              isLast: true,
              onBack: () {},
              onNext: () {},
              onMiniQuiz: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Dersi tamamla'), findsOneWidget);
    });

    testWidgets('başlık, sayaç etiketi, yavaş dinle yazısı', (tester) async {
      _surface(tester, const Size(375, 1400));
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const LessonOptionalPracticeHeader(),
                  LessonListeningCard(entries: _entries, speaker: _Speaker()),
                  const LessonRecallCard(entries: _entries),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('İsteğe bağlı alıştırma'), findsOneWidget);
      expect(find.text('Kart 1/2'), findsNWidgets(2));
      expect(find.text('Yavaş'), findsOneWidget);
      expect(find.text('1/2'), findsNothing);
    });
  });

  group('C28 harf karoları ve kesik kart', () {
    testWidgets('harf karolarının üstünde ne yaptıkları yazar', (tester) async {
      await tester.pumpWidget(
        testShell(
          child: const Scaffold(
            body: SingleChildScrollView(
              child: LessonContentBlocks(
                text: 'Alfabe:\n\nA B C Ç D E Ê F G H\n\nHeşt tîp dengdêr in.',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.text('Bir harfe dokun: örnek sözcüğü gör ve dinle.'),
        findsOneWidget,
      );
    });

    testWidgets('altta içerik varken solma, en sonda yok', (tester) async {
      _surface(tester, const Size(375, 667));
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: LessonScrollEdgeFade(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 60, child: Text('satır $i')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      LessonScrollEdgeFadeState fade() => tester
          .state<LessonScrollEdgeFadeState>(find.byType(LessonScrollEdgeFade));
      expect(fade().moreBelow, isTrue);
      final pos = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            ),
          )
          .position;
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(fade().moreBelow, isFalse);
      expect(pos.pixels, pos.maxScrollExtent, reason: 'konum korunur');
    });
  });

  group('C32 turnuva şeması', () {
    final bracket = TournamentBracket(
      tournamentId: 't',
      userId: 'me',
      size: 4,
      entryCount: 4,
      rounds: [
        TournamentRound(
          roundNumber: 1,
          status: 'active',
          matches: [
            _m('m1', 'qabero', 'qacano', status: 'completed', winner: 'qabero'),
            _m('m2', 'me', 'qali'),
          ],
        ),
      ],
      createdAt: DateTime(2026, 10, 29),
    );
    final started = TournamentBracket(
      tournamentId: 't',
      userId: 'me',
      size: 4,
      entryCount: 4,
      rounds: const [
        TournamentRound(
          roundNumber: 1,
          status: 'active',
          matches: [
            TournamentMatch(
              id: 'm1',
              playerOneId: 'me',
              playerOneName: 'ME',
              playerTwoId: 'qali',
              playerTwoName: 'QALI',
              playerOneScore: 134,
              playerTwoScore: 0,
              status: 'active',
              winnerId: '',
            ),
          ],
        ),
      ],
      createdAt: DateTime(2026, 10, 29),
    );

    for (final width in [320.0, 402.0]) {
      testWidgets('bilinen finalist yazılır, öteki "2. maçın kazananı" '
          '($width)', (tester) async {
        _surface(tester, Size(width, 1400));
        TournamentMatch? tapped;
        await tester.pumpWidget(
          testShell(
            child: Scaffold(
              body: SingleChildScrollView(
                child: TournamentBracketWidget(
                  bracket: bracket,
                  userId: 'me',
                  ku: false,
                  onTapMatch: (m, _) => tapped = m,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('2. maçın kazananı'), findsOneWidget);
        expect(find.text('QABERO'), findsNWidgets(2));
        expect(find.text('Sonuç bekleniyor'), findsWidgets);
        expect(find.text('VS'), findsNothing);
        await tester.tap(find.text('2. maçın kazananı'));
        await tester.pumpAndSettle();
        expect(tapped, isNull, reason: 'Yer tutucu Final dokunulamaz.');
      });
    }

    testWidgets('tamamlanmamış maç her durumda "Sonuç bekleniyor" (0 puanlı '
        'gönderim hiç oynanmamıştan ayrılamaz)', (tester) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: TournamentBracketWidget(
                bracket: started,
                userId: 'me',
                ku: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sonuç bekleniyor'), findsOneWidget);
      expect(find.text('Oynanmadı'), findsNothing);
    });

    test('sıralama notu sağdaki sayının ne olduğunu söyler', () {
      expect(
        Tr.of(K.cupStandingsNote, AppLanguage.tr),
        contains('sağdaki toplam puana'),
      );
      expect(
        Tr.of(K.cupStandingActive, AppLanguage.tr),
        'Turnuvada devam ediyor',
      );
    });
  });

  test('C33 SSS jeton cevabı maddeli', () {
    final tr = Tr.of(K.faqCoinsA, AppLanguage.tr);
    final ku = Tr.of(K.faqCoinsA, AppLanguage.ku);
    expect('\n•'.allMatches(tr).length, 3);
    expect('\n•'.allMatches(ku).length, 3);
    expect(tr, contains('Yanlış tekrarı turu jeton vermez'));
    expect(tr, contains('45'));
  });

  group('C34 rıza açıklamaları gövde boyunda', () {
    test('üç rıza satırının her biri belirgin alt metin kullanır', () {
      final src = File(
        'lib/src/screens/settings_screen.dart',
      ).readAsStringSync();
      // Varlık paylaşımı üçüncü açık rıza oldu; önceki iki açıklamanın
      // belirginliğini korurken yeni açıklamayı da aynı ölçütle denetle.
      expect('subtitleProminent: true'.allMatches(src).length, 3);
      for (final key in [
        'presenceVisibility',
        'analyticsConsent',
        'crashReportsConsent',
      ]) {
        final row = src
            .split('title: context.t(K.$key),')[1]
            .split('trailing: Switch(')[0];
        expect(row, contains('subtitleProminent: true'), reason: key);
      }
    });

    testWidgets('belirgin alt metin 16 pt', (tester) async {
      await tester.pumpWidget(
        testShell(
          child: const Scaffold(
            body: SahneListRow.plain(
              title: 'Kullanım analizi',
              subtitle: 'açıklama',
              subtitleProminent: true,
            ),
          ),
        ),
      );
      await tester.pump();
      final text = tester.widget<Text>(find.text('açıklama'));
      expect(text.style?.fontSize, 16);
    });
  });
}
