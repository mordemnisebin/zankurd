import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// 1v1 sonuç başlığı her üç sonuçta da okunur ve sonuçlar birbirinden
/// ayrışır.
///
/// ## Kusur (tarih)
///
/// Başlığın içeriği sabit `Colors.white` ile çiziliyordu. Kazanan ve
/// kaybeden gradyanları tema-bağımsız KOYU tonlardı; berabere gradyanı ise
/// `surfaceHiColor(context)` / `surfaceColor(context)` idi — açık temada
/// neredeyse beyaz. Beyaz metin beyaz zeminde kayboluyordu. Kusur ancak iki
/// oyuncu AYNI skorla bitirdiğinde doğuyordu (2026-08-01, canlı 0-0 oda
/// maçı).
///
/// ## 2026-09-29 Şahnê
///
/// Sonuç artık C iskeletinde, her temada GECE sahnesinde çizilir; başlık
/// kartı ve yeşil/kırmızı gradyanlar kalktı. Kazanmak bir "doğru cevap"
/// değildir: 1v1 sonucu Rast/Şaş (durum) ailesiyle boyanmaz. Kazanma Zêr
/// taç + altın başlık; berabere ve kaybetme nötr (birincil metin + ikincil
/// ikon). Bekçi aynı iki güvenceyi yeni dilde tutar: (1) üç sonucun başlığı
/// gündüz temasında da gece zemininde AA okunur, (2) üç sonuç birbirinden
/// ayırt edilir; ayrıca (3) 1v1 dalı durum renklerine geri dönmez.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    // Gündüz teması: sahne yine gece çizilmeli.
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );

  QuizResultScreen duel({required int mine, required int theirs}) {
    final repository = MockZanKurdRepository();
    return QuizResultScreen(
      repository: repository,
      room: repository.createRoom(),
      score: mine,
      correctCount: 2,
      wrongCount: 1,
      totalQuestions: 3,
      bestStreak: 1,
      coinsAwarded: 0,
      answerRecords: const [],
      opponents: [
        Player(id: 'opp', name: 'Hevrik', score: theirs, state: 'Bot'),
      ],
    );
  }

  const outcomes = <String, (int, int, String)>{
    'kazandı': (300, 100, K.youWon),
    'kaybetti': (100, 300, K.youLost),
    'berabere': (0, 0, K.draw),
  };

  final headlineColors = <String, Color>{};
  final hasCrown = <String, bool>{};

  outcomes.forEach((outcome, spec) {
    testWidgets('$outcome başlığı gece sahnesinde okunuyor', (tester) async {
      await tester.pumpWidget(wrap(duel(mine: spec.$1, theirs: spec.$2)));
      await tester.pump(const Duration(seconds: 1));

      final header = find.byKey(const ValueKey('result-score-header'));
      final title = tester.widget<Text>(
        find.descendant(
          of: header,
          matching: find.text(Tr.forKu(spec.$3, false)),
        ),
      );
      final color = title.style!.color!;
      headlineColors[outcome] = color;
      hasCrown[outcome] = tester
          .widgetList<SahneGlyph>(
            find.descendant(of: header, matching: find.byType(SahneGlyph)),
          )
          .any((glyph) => glyph.kind == SahneGlyphKind.crown);

      expect(
        _contrast(color, SahneTokens.night.bg),
        greaterThanOrEqualTo(4.5),
        reason: '$outcome başlığı gece zemininde okunmuyor ($color).',
      );
      for (final status in [
        SahneTokens.night.okTx,
        SahneTokens.night.okFill,
        SahneTokens.night.errTx,
        SahneTokens.night.errFill,
      ]) {
        expect(
          color,
          isNot(status),
          reason: '1v1 sonucu durum (Rast/Şaş) rengiyle boyanmamalı.',
        );
      }
    });
  });

  test('üç sonuç birbirinden ayırt edilebiliyor', () {
    // Hepsini aynı görünüme indirmek okunurluğu çözer ama bilgiyi siler:
    // kazanma altın başlık + taçla, ötekiler nötr başlıkla ve kendi
    // amblemleriyle ayrışır (başlık sözü de farklı).
    expect(headlineColors, hasLength(3));
    expect(headlineColors['kazandı'], SahneTokens.night.goldTx);
    expect(headlineColors['kaybetti'], SahneTokens.night.tx);
    expect(headlineColors['berabere'], SahneTokens.night.tx);
    expect(hasCrown, {'kazandı': true, 'kaybetti': false, 'berabere': false});
  });

  test('1v1 dalı durum renklerine ve eski gradyanlara dönmemiş', () {
    final source = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    for (final legacy in [
      'correctHeader',
      'wrongHeader',
      'correctDeep',
      'wrongDeep',
      'surfaceHiColor(context)',
    ]) {
      expect(
        code,
        isNot(contains(legacy)),
        reason:
            '$legacy eski yeşil/kırmızı başlık kartına aitti; Şahnê '
            'sonucu gece sahnesinde çizer.',
      );
    }
  });
}
