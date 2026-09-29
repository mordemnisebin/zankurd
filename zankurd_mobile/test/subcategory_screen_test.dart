import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_panel.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

/// 2026-09-28: `SubcategoryScreen` artık kartları
/// `SubcategoryConfig.visibleFor` ile süzüyor — bir alt kategori ancak
/// kategorisinde en az `kMinSubcategoryQuestions` anahtar-kelime-eşleşmeli
/// GERÇEK soru varsa görünür. 'Siyaset' ve 'Paradigma' kategorileri ise
/// (bkz. `category_visibility.dart`) tamamen gizli: `playableQuestions`
/// bu kategorilerden hiçbir soru döndürmez, dolayısıyla 'tevger' ve
/// 'jineoloji' kartları GERÇEK depoyla asla görünmez — bu, ikonun yanlış
/// olmasından değil, kategorinin ürün kararıyla kapalı olmasından kaynaklanır.
///
/// Bu dosyanın 'tevger'/'jineoloji' testleri ise ikon eşlemesinin
/// (`_iconForId`) regresyonunu (paylaşılan 'pen' ikonuna geri dönüş)
/// yakalamak için var — kategori açık olsaydı da aynı ikonu almalı. Bu
/// yüzden `playableQuestions`ı doğrudan override eden küçük bir sahte depo
/// kullanılır: kategori gizleme politikasına hiç dokunmadan, yalnızca "bu
/// alt kategorinin yeterli gerçek içeriği var" senaryosunu kurar.
class _FixedPlayableRepository extends MockZanKurdRepository {
  _FixedPlayableRepository(this._fixed);

  final List<QuizQuestion> _fixed;

  @override
  List<QuizQuestion> get playableQuestions => _fixed;
}

/// [count] adet, [category] kategorisinde [keyword] anahtar kelimesiyle
/// eşleşen sentetik soru üretir — `SubcategoryConfig.visibleFor`in eşiğini
/// (`kMinSubcategoryQuestions`) aşmak için yeterli gerçek eşleşme sağlar.
List<QuizQuestion> _keywordMatchedQuestions({
  required String category,
  required String keyword,
  required int count,
}) {
  return [
    for (var i = 0; i < count; i++)
      QuizQuestion(
        id: '${category}_${keyword}_$i',
        category: category,
        prompt: 'Pirsa ceribandinê ya $keyword, hejmar $i.',
        answers: ['Bersiv $i', 'X1-$i', 'X2-$i', 'X3-$i'],
        correctAnswer: 'Bersiv $i',
        explanation: 'Ravekirina ceribandinê ji bo testê têra xwe dirêj e.',
      ),
  ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  // 2026-09-29 Şahnê: alt kategoriler eskiden kategori renkli kenarlı ve
  // gölgeli tek tek kartlardı. Artık tek bir liste grubunda
  // (`SahneListGroup`, Perde yüzeyi) standart satırlardır: öğrenme rolünün
  // ikon karosu, ad, açıklama, rozetler. Bekçi yüzeyin açık temada Perde
  // (beyaz) kaldığını ve satırın öğrenme rolünü taşıdığını ölçer.
  testWidgets('alt kategoriler açık yüzeyli liste grubunda satır olur', (
    tester,
  ) async {
    final first = SubcategoryConfig.subcategories['Ziman']!.first;

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardKey = ValueKey('subcategory-card-${first.id}');
    expect(find.byKey(cardKey), findsOneWidget);
    expect(find.text(first.nameTr), findsOneWidget);

    final row = tester.widget<SahneListRow>(find.byKey(cardKey));
    expect(row.role, SahneRole.learn);
    final group = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SahneListGroup),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(group.color, SahneTokens.day.s1);
    // Rozetler: "5 seviye" ve "Yarış" (Etiket biçemi: büyük harf).
    expect(
      find.descendant(of: find.byKey(cardKey), matching: find.text('5 SEVİYE')),
      findsOneWidget,
    );
  });

  testWidgets('dekoratif kategori hero görseli semantics ağacına girmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heroImage = find.byType(Image);
    expect(heroImage, findsOneWidget);
    expect(
      find.ancestor(of: heroImage, matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
      reason:
          'Dekoratif hero görseli ekran okuyucuya adsız image durağı olmamalı.',
    );
  });

  testWidgets('kart dokunuşu LevelScreen açar', (tester) async {
    final first = SubcategoryConfig.subcategories['Ziman']!.first;

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('subcategory-card-${first.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(LevelScreen), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // 2026-07-23: M15 devamı — sinor_duma/amur/tevger/jineoloji artık
  // "Yazım & Sanat" grubunun pen ikonunu miras almıyor, kendi anlamına
  // uygun ikon alıyor. Bu test regresyonu (pen'e geri dönüşü) yakalar.
  Future<void> expectCardIcon(
    WidgetTester tester, {
    required String category,
    required String id,
    required IconData expectedIcon,
    MockZanKurdRepository? repository,
  }) async {
    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: repository ?? MockZanKurdRepository(),
          category: category,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cardKey = ValueKey('subcategory-card-$id');
    expect(find.byKey(cardKey), findsOneWidget);

    final icons = tester
        .widgetList<Icon>(
          find.descendant(of: find.byKey(cardKey), matching: find.byType(Icon)),
        )
        .map((w) => w.icon)
        .toSet();
    expect(icons, contains(expectedIcon));
    expect(icons, isNot(contains(AppIcons.pen)));
  }

  testWidgets('sinor_duma anlamına uygun konum ikonu alır', (tester) async {
    // 2026-09-28: eşleştirme artık çeldiricilere bakmıyor; sinor_duma'nın
    // gerçek bankadaki eşleşmesi eşiğin altına indi ve kart gizlendi. Burada
    // ölçülen ikon eşlemesi olduğu için kart, yeterli içerik VARMIŞ GİBİ bir
    // depoyla görünür kılınır.
    await expectCardIcon(
      tester,
      category: 'Cografya',
      id: 'sinor_duma',
      expectedIcon: AppIcons.locationDot,
      repository: _FixedPlayableRepository(
        _keywordMatchedQuestions(
          category: 'Cografya',
          keyword: 'sînor',
          count: SubcategoryConfig.kMinSubcategoryQuestions,
        ),
      ),
    );
  });

  testWidgets('amur anlamına uygun müzik ikonu alır', (tester) async {
    await expectCardIcon(
      tester,
      category: 'Muzîk',
      id: 'amur',
      expectedIcon: AppIcons.music,
    );
  });

  testWidgets('tevger anlamına uygun bayrak ikonu alır', (tester) async {
    // 'Siyaset' kategorisi ürün kararıyla tamamen gizli (bkz. yukarıdaki
    // sınıf yorumu); kart yalnızca yeterli gerçek içerik VARMIŞ GİBİ bir
    // depoyla görünür hâle gelir. Ölçülen şey ikon eşlemesi, kategori
    // görünürlüğü değil.
    await expectCardIcon(
      tester,
      category: 'Siyaset',
      id: 'tevger',
      expectedIcon: AppIcons.flag,
      repository: _FixedPlayableRepository(
        _keywordMatchedQuestions(
          category: 'Siyaset',
          keyword: 'tevger',
          count: SubcategoryConfig.kMinSubcategoryQuestions,
        ),
      ),
    );
  });

  testWidgets('jineoloji anlamına uygun venus ikonu alır', (tester) async {
    // 'Paradigma' kategorisi de tamamen gizli — bkz. yukarıdaki yorum.
    await expectCardIcon(
      tester,
      category: 'Paradigma',
      id: 'jineoloji',
      expectedIcon: AppIcons.venus,
      repository: _FixedPlayableRepository(
        _keywordMatchedQuestions(
          category: 'Paradigma',
          keyword: 'jineolojî',
          count: SubcategoryConfig.kMinSubcategoryQuestions,
        ),
      ),
    );
  });

  // Listenin sonundaki bilgilendirme kartı ("Kolaydan zora doğru ilerle")
  // hiçbir hedefe gitmiyordu ama sağ ucundaki `chevronRight` ikonu, listedeki
  // her TIKLANABİLİR alt kategori satırıyla aynı görsel dili taşıyordu —
  // kullanıcı dokunuyor, hiçbir şey olmuyordu (2026-08-14 denetimi).
  // Düzeltme sahte "buraya dokun" ipucunu kaldırdı; bu bekçi ikonun geri
  // gelmediğini doğrular.
  testWidgets('ilerleme ipucu kartı sahte "dokun" oku taşımıyor', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 2026-09-29 Şahnê: B çubuğu 64 (56'ydı); ipucu kartı tembel listenin
    // önbellek sınırının dışına düştü. Kullanıcı gibi kaydırarak bulunur.
    await tester.scrollUntilVisible(
      find.text('Kolaydan zora doğru ilerle, puan topla.'),
      120,
      scrollable: find.byType(Scrollable).last,
    );

    final hintPanel = find.ancestor(
      of: find.text('Kolaydan zora doğru ilerle, puan topla.'),
      matching: find.byType(AppPanel),
    );
    expect(hintPanel, findsOneWidget);

    final icons = tester
        .widgetList<Icon>(
          find.descendant(of: hintPanel, matching: find.byType(Icon)),
        )
        .map((w) => w.icon)
        .toSet();
    expect(
      icons,
      isNot(contains(AppIcons.chevronRight)),
      reason:
          'Kart hiçbir yere gitmiyor; ok ikonu "buraya dokun" derken '
          'yalan söylüyordu',
    );
  });
}
