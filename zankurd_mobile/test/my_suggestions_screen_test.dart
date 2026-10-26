import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/my_suggestion.dart';
import 'package:zankurd_mobile/src/screens/my_suggestions_screen.dart';
import 'package:zankurd_mobile/src/screens/suggest_question_screen.dart';

import 'support/widget_test_helpers.dart';

/// "Önerilerim" (2026-10-27).
///
/// Bekçi: öneri gönderen kullanıcı sonucunu görebilir — durum şekil + sözle
/// (İnceleniyor / Onaylandı / Kabul edilmedi), editör notu varsa yazılır;
/// liste yüklenemezse sessizce "boş" denmez, hata ve yeniden dene çıkar.
/// Başarı mesajı tutulmayan ödül (50 jeton, Yazar Rozeti) vaat etmez:
/// sunucuda onayda ödül veren hiçbir şey yoktu.
class _Repo extends MockZanKurdRepository {
  _Repo(this.result);

  List<MySuggestion>? result;
  int loads = 0;

  @override
  Future<List<MySuggestion>?> loadMySuggestions() async {
    loads++;
    return result;
  }
}

MySuggestion _s(String id, MySuggestionStatus status, {String? note}) =>
    MySuggestion(
      id: id,
      category: 'Ziman',
      prompt: 'Soru $id?',
      status: status,
      createdAt: DateTime(2026, 10, 27),
      reviewNote: note,
    );

void main() {
  Future<void> pump(WidgetTester tester, _Repo repo) async {
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        child: MySuggestionsScreen(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('durumlar şekil ve sözle, editör notuyla görünür', (
    tester,
  ) async {
    await pump(
      tester,
      _Repo([
        _s('a', MySuggestionStatus.pending),
        _s('b', MySuggestionStatus.approved),
        _s('c', MySuggestionStatus.rejected, note: 'Cevap iki şıkta da var.'),
      ]),
    );

    expect(find.text('İnceleniyor'), findsOneWidget);
    expect(find.text('Onaylandı'), findsOneWidget);
    expect(find.text('Kabul edilmedi'), findsOneWidget);
    expect(find.text('Soru c?'), findsOneWidget);
    expect(find.text('Cevap iki şıkta da var.'), findsOneWidget);
    expect(find.text('Not'), findsOneWidget);
  });

  testWidgets('hiç öneri yoksa boş durum', (tester) async {
    await pump(tester, _Repo(const []));
    expect(find.byKey(const ValueKey('my-suggestions-empty')), findsOneWidget);
  });

  testWidgets('yüklenemezse hata ve yeniden dene', (tester) async {
    final repo = _Repo(null);
    await pump(tester, repo);
    expect(find.byKey(const ValueKey('my-suggestions-error')), findsOneWidget);

    repo.result = [_s('a', MySuggestionStatus.pending)];
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(repo.loads, 2);
    expect(find.text('Soru a?'), findsOneWidget);
  });

  testWidgets('öneri ekranından Önerilerim açılır; ödül vaadi yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        child: SuggestQuestionScreen(repository: _Repo(const [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('jeton'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('suggest-my-suggestions')));
    await tester.pumpAndSettle();
    expect(find.byType(MySuggestionsScreen), findsOneWidget);
  });
}
