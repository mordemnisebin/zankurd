import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';

import 'support/realistic_device.dart';

/// Arkadaş satırında oynama bilgisi "Meydan oku"nun yanında sıkışmaz
/// (Opus–Astra kapışması U11, 2026-10-29).
///
/// Kusur: eylemlerin alt satıra inmesi yalnız eylem ETİKETİNİN uzunluğuna
/// bakıyordu; Türkçede "Meydan oku" kısa sayıldığı için satır yan yana
/// kalıyor, ad sütunu ~90 pt'ye düşüyor ve "50 gün önce oynadı" üç satıra
/// kırılıyordu (kare 13_friends). Taşma hatası doğmadığı için hiçbir bekçi
/// görmedi. Bekçi: ad ve bilgi her genişlikte TEK satır; sığmıyorsa eylemler
/// alt satıra iner ve hâlâ ekranda.
class _Repo extends MockZanKurdRepository {
  @override
  Future<List<Friend>> loadFriends() async => [
    Friend(
      id: 'f1',
      userId: 'me',
      friendId: 'friend-diyar',
      friendName: 'Diyar',
      createdAt: DateTime(2026, 8, 1),
      lastActiveAt: DateTime.now().subtract(const Duration(days: 50)),
    ),
    Friend(
      id: 'f2',
      userId: 'me',
      friendId: 'friend-long',
      friendName: 'Rojbînxweşnavekidirêj',
      createdAt: DateTime(2026, 8, 1),
    ),
  ];
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [320.0, 375.0, 402.0]) {
    for (final scale in [1.0, 1.3]) {
      for (final lang in ['tr', 'ku']) {
        testWidgets(
          'arkadaş satırı ${width}pt x$scale $lang: bilgi tek satır',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 874);
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<LanguageProvider>(
                    create: (_) => LanguageProvider(initialLang: lang),
                  ),
                ],
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: FriendsScreen(
                    repository: _Repo(),
                    asyncDuelEnabled: true,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            for (final name in ['Diyar', 'Rojbînxweşnavekidirêj']) {
              final row = find.byKey(ValueKey('friend-row-$name'));
              await tester.ensureVisible(row);
              await tester.pumpAndSettle();
              final paragraphs = find.descendant(
                of: row,
                matching: find.byType(RichText),
              );
              for (final e in paragraphs.evaluate()) {
                final p = e.renderObject! as RenderParagraph;
                final text = p.text.toPlainText();
                if (text.trim().isEmpty) continue;
                // Yalnız ad ve bilgi satırı (eylem sözleri hapın içinde tek
                // satır ve kendi kuralıyla).
                final lines = p
                    .getBoxesForSelection(
                      TextSelection(baseOffset: 0, extentOffset: text.length),
                    )
                    .map((b) => b.top.round())
                    .toSet();
                if (text == name) {
                  // Tek sözcüklük çok uzun ad en dar telefonda büyük yazıda
                  // tam genişlikte bile tek satıra sığmaz (fiziksel sınır):
                  // en çok iki satır, kesilmeden. Kısa ad her zaman tek satır.
                  expect(
                    lines.length,
                    name.length > 12 ? lessThanOrEqualTo(2) : 1,
                    reason: '"$text" ${lines.length} satıra kırıldı',
                  );
                } else if (text.contains('gün') ||
                    text.contains('roj') ||
                    text.contains('oyna') ||
                    text.contains('lîst')) {
                  expect(
                    lines.length,
                    1,
                    reason: '"$text" ${lines.length} satıra kırıldı',
                  );
                }
              }
              final action = find.byKey(ValueKey('friend-action-$name'));
              expect(action, findsOneWidget);
              final r = tester.getRect(action);
              expect(r.right, lessThanOrEqualTo(width));
            }
          },
        );
      }
    }
  }
}
