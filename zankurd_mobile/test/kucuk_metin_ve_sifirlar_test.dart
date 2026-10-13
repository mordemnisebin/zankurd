/// 2026-10-01 tasarım denetimi, küçük düzeltmeler (1/3): metin ve sıfırlar.
///
/// Kurmancî kısa metinler, cümle düzeni etiketler/ders başlıkları, anlamsız
/// sıfırlar ve soru künyesinin konu işareti. Her grup bir kusuru, kusurun
/// NİÇİN sessiz kaldığını ve onu neyin geri getireceğini anlatır. Büyük
/// yeniden tasarımlar (ızgara etiketleri, kilim bantları, form alanı, bölüm
/// şablonu …) bu dosyanın konusu değildir.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/category_kicker_mark.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

Widget _themed(Widget child, {String lang = 'tr'}) {
  return ChangeNotifierProvider<LanguageProvider>(
    create: (_) => LanguageProvider()..setLang(lang),
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

void main() {
  // ───────────────────────────────────────────────────────────────────────
  // 1) Kurmancî metin taşması
  // ───────────────────────────────────────────────────────────────────────
  //
  // KUSUR: yedi Kurmancî metin dar yerlerinde (karo etiketi, yarım genişlikli
  // düğme, soru künyesi, ad kapısı başlığı) iki satıra kırılıyor ya da
  // taşıyordu: "Li pey hev", "Bi kodê tevlî bibe", "Pirsan bibersivîne" …
  // NİÇİN SESSİZ: Türkçe karşılıkları kısaydı, testler ve tur Türkçe ile
  // koşuyordu; Kurmancî uzunluğu yalnız simülatörde, gözle görüldü. İki model
  // aynı kısaltmalarda uyuştu; bu test onları sabitler, geri uzatan olursa
  // düşer. 2026-10-02 dil denetimi (Gemini 3.1 Pro + Grok 4.7, Flash üçüncü
  // oy): "Bi kod" -> "Bi kodê" (bi'den sonra bükümlü hâl), "bo dijwar" ->
  // "ber bi dijwar ve", "kom ke" -> "kom bike", "alîkarî" -> "alîkariyan"
  // (jokerler çoğul). Uzunluk sınırı korunarak düzeltildi.
  group('1) Kurmancî kısa metinler', () {
    const ku = <String, String>{
      K.streakLabel: 'Zincîr',
      K.joinByCode: 'Bi kodê têkeve',
      K.soruCoz: 'Bersiv bide',
      K.kolaydanZoraDogruIlerle:
          'Ji hêsan ber bi dijwar ve biçe, pûan kom bike.',
      K.nameGateQuestion: 'Navê te çi be?',
      K.finishQuizHint: 'Pêşbirkê qedîne, zêr bigire, alîkariyan veke',
      K.recommendedForYou: 'Dersa dorê',
    };

    test('kısaltılmış Kurmancî değerler yerinde', () {
      ku.forEach((key, value) {
        expect(Tr.of(key, AppLanguage.ku), value, reason: key);
      });
    });

    test('bitirme ipucunun Türkçesi "quiz" demez (sözlükte yasak)', () {
      expect(
        Tr.of(K.finishQuizHint, AppLanguage.tr),
        'Yarışı bitir, jeton kazan, jokerleri aç',
      );
      expect(
        Tr.of(K.finishQuizHint, AppLanguage.tr).toLowerCase(),
        isNot(contains('quiz')),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 3) Büyük harf etiketler ve Başlık Düzeni dersler
  // ───────────────────────────────────────────────────────────────────────
  //
  // KUSUR: soru künyesi ("SİYASET • SORU 1/5"), inceleme rozetleri ("DOĞRU",
  // "YANLIŞ"), hikâye künyesi ("HİKÂYE") yalnız süs için büyük harfti; ders
  // başlıkları da Başlık Düzeniydi ("Günlük Pratik İfadeler"). Ekranın geri
  // kalanı cümle düzeniyle yazılı olduğundan bu etiketler bağırıyordu.
  // NİÇİN SESSİZ: metinler sözlükte ya DOĞRU büyük yazılmıştı ya da çizim
  // sırasında `toUpperCase` ile büyütülüyordu; hiçbir test "bu etiket nasıl
  // görünür" diye sormadı, testler tam da büyük hâli bekliyordu.
  group('3) Cümle düzeni', () {
    test('sözlükte tümü büyük harf metin yok (yazılan sözcük hariç)', () {
      // `K.deleteWord` hesap silmede OYUNCUNUN yazacağı onay sözcüğüdür;
      // büyük olması anlam taşır.
      const semantic = {K.deleteWord};
      final offenders = <String>[];
      for (final key in Tr.keys) {
        if (semantic.contains(key)) continue;
        for (final lang in AppLanguage.values) {
          final value = Tr.of(key, lang);
          final letters = value.runes
              .map(String.fromCharCode)
              .where((c) => c.toLowerCase() != c.toUpperCase())
              .toList();
          if (letters.length >= 3 &&
              letters.every((c) => c == c.toUpperCase())) {
            offenders.add('$key (${lang.name}): $value');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('lib/ içinde süs için büyük harfe çevirme yok', () {
      // Meşru kullanımlar: kod/etiket normalleştirme (oda kodu, ZK- etiketi,
      // doğru şık harfi), avatar baş harfi, renk onaltılığı, dil politikası.
      const allowed = {
        'lib/src/l10n/lang.dart',
        'lib/src/theme/sahne.dart',
        'lib/src/utils/join_deep_link.dart',
        'lib/src/utils/player_identity.dart',
        'lib/src/models/room.dart',
        'lib/src/models/quiz_question.dart',
        'lib/src/screens/friends_screen.dart',
        'lib/src/screens/profile/profile_widgets.dart',
        'lib/src/data/mock_zankurd_repository.dart',
        'lib/src/data/supabase_zankurd_repository.dart',
        'lib/src/services/question_language_policy.dart',
        'lib/src/widgets/tournament_bracket_widget.dart',
      };
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (allowed.contains(f.path)) continue;
        if (f.readAsStringSync().contains('toUpperCase(')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
      // Künye için yerele duyarlı büyütücü artık yok.
      expect(
        File('lib/src/widgets/sahne/sahne_foundation.dart').readAsStringSync(),
        isNot(contains('sahneUpper')),
      );
    });

    test('künye yazı stilinde harf aralığı yok (büyük harf stili değil)', () {
      expect(SahneType.eyebrow.letterSpacing, isNull);
    });

    testWidgets('inceleme rozetleri cümle düzeniyle çizilir', (tester) async {
      const records = [
        AnswerRecord(
          id: 'q1',
          category: 'Ziman',
          prompt: 'Soru 1',
          answers: ['A', 'B'],
          correctAnswer: 'A',
          selectedAnswer: 'B',
          explanation: '',
        ),
      ];
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _themed(
          const ReviewScreen(
            records: records,
            room: GameRoom(
              name: 'Oda',
              code: 'ZK-TEST',
              category: 'Ziman',
              players: [],
              status: RoomStatus.finished,
              questionCount: 1,
            ),
          ),
        ),
      );
      expect(find.text('YANLIŞ'), findsNothing);
      expect(find.text('Yanlış'), findsWidgets);
    });

    test('ders, hikâye ve rehber başlıkları cümle düzeninde', () {
      // İlk sözcükten sonra büyük harfle başlayan sözcük yok; özel ad
      // (Kurdistan) ve kısaltma (VIP) hariç.
      const proper = {'Kurdistanê', 'Kurdistan'};
      final titles = <String>[
        for (final s in LearnerLexicon.sources.values) ...[
          s.titleKu,
          s.titleTr,
        ],
        for (final s in everydayStories) ...[s.titleKu, s.titleTr],
        for (final g in everydayGuides.values) ...[g.titleKu, g.titleTr],
      ];
      expect(titles, isNotEmpty);
      final offenders = <String>[];
      for (final title in titles) {
        final words = title.split(' ');
        for (final w in words.skip(1)) {
          if (w.isEmpty || proper.contains(w)) continue;
          final first = w.runes.first;
          final ch = String.fromCharCode(first);
          if (ch.toLowerCase() != ch.toUpperCase() && ch == ch.toUpperCase()) {
            offenders.add(title);
            break;
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 4) Anlamsız sıfırlar
  // ───────────────────────────────────────────────────────────────────────
  //
  // KUSUR: salon satırlarında oyun başlamadan "0" ve "0 üst üste", tur
  // başında soru ekranında "★ 0", incelemede "0 Boş" karosu ve başlıkta üç
  // karoyu tekrarlayan özet satırı. NİÇİN SESSİZ: sıfırlar HATA değildi —
  // doğru sayıyı gösteriyorlardı; ama bilgi taşımayan sayı gürültüdür ve
  // "henüz hiçbir şeyin yok" der. Yalnız ekrana bakan biri fark eder.
  group('4) Sıfırlar', () {
    testWidgets('salon satırlarında oyun başlamadan puan/seri sütunu yok', (
      tester,
    ) async {
      final repository = freshMockRepository();
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: RoomScreen(
            repository: repository,
            initialRoom: repository.createRoom(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('room-player-tile-1')), findsOneWidget);
      expect(find.textContaining('üst üste'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('room-player-tile-1')),
          matching: find.text('0'),
        ),
        findsNothing,
      );
    });

    testWidgets('soru ekranında puan 0 iken yıldız çipi yok', (tester) async {
      final repository = freshMockRepository();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: [repository.questions.first],
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is SahneGlyph && w.kind == SahneGlyphKind.star,
        ),
        findsNothing,
      );
    });

    testWidgets('incelemede sıfır karo çizilmez, özet satırı yok', (
      tester,
    ) async {
      const records = [
        AnswerRecord(
          id: 'q1',
          category: 'Ziman',
          prompt: 'Soru 1',
          answers: ['A', 'B'],
          correctAnswer: 'A',
          selectedAnswer: 'A',
          explanation: '',
        ),
        AnswerRecord(
          id: 'q2',
          category: 'Ziman',
          prompt: 'Soru 2',
          answers: ['A', 'B'],
          correctAnswer: 'A',
          selectedAnswer: 'B',
          explanation: '',
        ),
      ];
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _themed(
          const ReviewScreen(
            records: records,
            room: GameRoom(
              name: 'Oda',
              code: 'ZK-TEST',
              category: 'Ziman',
              players: [],
              status: RoomStatus.finished,
              questionCount: 2,
            ),
          ),
        ),
      );

      // Boş cevap yok → "Boş" karosu yok (sıfır).
      expect(find.text('Boş'), findsNothing);
      // Başlık altındaki tekrar eden özet kalktı.
      expect(find.textContaining('1 doğru · 1 yanlış'), findsNothing);
      // Karolar yine de var.
      expect(find.text('Doğru'), findsWidgets);
      expect(find.text('Yanlış'), findsWidgets);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 9) Künyedeki konu işareti
  // ───────────────────────────────────────────────────────────────────────
  //
  // KUSUR: soru künyesinde Siyaset için genel bir Material "terazi" ikonu
  // vardı; ana sayfa karosu ise çizilmiş sandık silüetini kullanıyordu —
  // aynı konu iki ayrı çizimle anlatılıyordu. NİÇİN SESSİZ: ikon "doğru
  // kategori ikonu"ydu, test yalnız bir ikonun VAR olduğuna baktı.
  group('9) Künye işareti', () {
    testWidgets('silüeti olan her konu karodaki çizimi kullanır', (
      tester,
    ) async {
      for (final category in CategoryVisuals.markedCategories) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: CategoryKickerMark(
                category: category,
                fallbackColor: Colors.black,
              ),
            ),
          ),
        );
        expect(
          find.byType(SahneTopicMarkBadge),
          findsOneWidget,
          reason: category,
        );
        expect(find.byType(Icon), findsNothing, reason: category);
      }
    });

    testWidgets('silüetsiz kategori eski ikona düşer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: CategoryKickerMark(
              category: 'Bilinmeyen konu',
              fallbackColor: Colors.black,
            ),
          ),
        ),
      );
      expect(find.byType(SahneTopicMarkBadge), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
