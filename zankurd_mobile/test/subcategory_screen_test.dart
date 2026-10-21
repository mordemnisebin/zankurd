// Tasarım kurulu tüm ekranlar 2026-10-20: az alt konulu kategoride altta
// "Tüm sorular" kısayolu (sayfa yarı boş kalmasın).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_panel.dart';
import 'package:zankurd_mobile/src/widgets/category_band.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

import 'support/realistic_device.dart';

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

/// Ekranı gerçek bir telefon gibi kurar: [width] mantıksal piksel, üstte
/// 59 px durum çubuğu payı. (`setSurfaceSize` yerleşimi daraltır ama
/// `MediaQuery`yi 800 px bırakır; çubuğun ölçümü ve desen yuvaları yanlış
/// genişlikten hesaplanırdı.)
void _phone(WidgetTester tester, double width) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 800)
    ..padding = const FakeViewPadding(top: 59)
    ..viewPadding = const FakeViewPadding(top: 59);
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  // 2026-09-29 Şahnê: alt kategoriler eskiden kategori renkli kenarlı ve
  // gölgeli tek tek kartlardı. Artık tek bir liste grubunda
  // (`SahneListGroup`, Perde yüzeyi) standart satırlardır: öğrenme rolünün
  // ikon karosu, ad, açıklama, rozetler. Bekçi yüzeyin açık temada Perde
  // (beyaz) kaldığını ve satırın öğrenme rolünü taşıdığını ölçer.
  testWidgets('az alt konulu kategori altta "Tüm sorular" satırı taşır', (
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
    expect(find.byKey(const ValueKey('subcategory-card-gisti')), findsOne);
    expect(find.text('Tüm sorular'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('subcategory-card-gisti')));
    await tester.pumpAndSettle();
    expect(find.byType(LevelScreen), findsOneWidget);
    expect(find.text('Tüm sorular'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
  });

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

    // 2026-09-30 izgara: satır ikonu genel Zimrût değil KONUNUN renginde
    // (başlık bandı ve ana ekran karosuyla aynı aile).
    final tile = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(cardKey),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (tile.decoration as ShapeDecoration).color,
      CategoryVisuals.tone('Ziman').fill(night: false),
    );
    final group = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SahneListGroup),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(group.color, SahneTokens.day.s1);
    // 2026-09-29 doğallık (K7): her satırda aynı "5 seviye" rozeti vardı;
    // kalktı. Hiç oynanmamış alt kategoride sağda sayaç yok (sıfır sayaç
    // gösterilmez), yalnız chevron.
    expect(
      find.descendant(of: find.byKey(cardKey), matching: find.text('5 seviye')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byKey(cardKey), matching: find.text('0/5')),
      findsNothing,
    );
  });

  // 2026-09-29 doğallık (K7): rozetin yerini gerçek ilerleme aldı. Seviye
  // yolunun kendi deposu (LevelProgressStore) o alt kategoride iki seviyeyi
  // oynanmış sayıyorsa satır "2/5" der; öteki satırlar sessiz kalır.
  testWidgets('oynanmış seviyesi olan alt kategori ilerlemesini gösterir', (
    tester,
  ) async {
    final subs = SubcategoryConfig.subcategories['Ziman']!;
    final first = subs.first;
    final store = await LevelProgressStore.load();
    await store.markPlayed('Ziman', first.id, 1);
    await store.markPlayed('Ziman', first.id, 2);

    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(ValueKey('subcategory-card-${first.id}')),
        matching: find.text('2/5'),
      ),
      findsOneWidget,
    );
    expect(find.text('2/5'), findsOneWidget);
  });

  // Kurul 2. tur 2026-10-20: başlık koyu kilim bandı değil, standart sayfa
  // başlığıdır (beyaz kare geri düğmesi + ad); kategori rengi yalnız ikon
  // karosunda ve ince çizgide. Eski bant bekçileri (desen, yuva, bant
  // yüksekliği) bu yüzden kalktı.
  testWidgets('başlık standart: resim yok, ince kategori çizgisi var', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Çand',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    final line = find.byKey(CategoryBandScaffold.accentKey);
    expect(line, findsOneWidget);
    expect(tester.getSize(line).height, lessThanOrEqualTo(4));
    // Koyu bant yok: çubuk saydam/zemin renginde, geri düğmesi Perde plaka.
    expect(find.byType(ZkBackButton), findsOneWidget);
    expect(find.byType(SahneKilimBandPainter), findsNothing);
  });

  // Kurmancî "Zanist û Raman" ve büyük yazı: başlık ve alt satır kırpılmaz.
  for (final screen in ['alt kategori', 'seviye']) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('Zanist û Raman başlığı kırpılmaz ($screen, '
            '${width.round()} px, x$scale)', (tester) async {
          _phone(tester, width);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => LanguageProvider()..setLang('ku'),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen == 'alt kategori'
                    ? SubcategoryScreen(
                        repository: MockZanKurdRepository(),
                        category: 'Paradigma',
                      )
                    : LevelScreen(
                        repository: MockZanKurdRepository(),
                        category: 'Paradigma',
                      ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final text in tester.widgetList<Text>(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byType(Text),
            ),
          )) {
            final paragraph = tester.renderObject<RenderParagraph>(
              find.byWidget(text),
            );
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '"${text.data}" kesiliyor',
            );
          }
        });
      }
    }
  }

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

  // 2026-09-30: Paradigma "Bilim ve Düşünce" oldu; üç alt konu yeni kimlik
  // ve ikon alır (eski demokratik/ekoloji/jineoloji kimlikleri kalktı).
  for (final entry in {
    'civak_maf': (AppIcons.scaleBalanced, 'hemwelatî'),
    'raman_felsefe': (AppIcons.lightbulb, 'felsefe'),
    'zanist_jiyan': (AppIcons.leaf, 'zanist'),
  }.entries) {
    testWidgets('Paradigma › ${entry.key} kendi ikonunu alır', (tester) async {
      await expectCardIcon(
        tester,
        category: 'Paradigma',
        id: entry.key,
        expectedIcon: entry.value.$1,
        repository: _FixedPlayableRepository(
          _keywordMatchedQuestions(
            category: 'Paradigma',
            keyword: entry.value.$2,
            count: SubcategoryConfig.kMinSubcategoryQuestions,
          ),
        ),
      );
    });
  }

  // 2026-09-30 izgara: listenin sonundaki "Kolaydan zora doğru ilerle"
  // kartı kalktı. Seviye numaraları, zorluk çubukları ve kilit koşulu (seviye
  // ekranı) aynı şeyi söylüyordu; kart hem yer kaplıyor hem hiçbir yere
  // gitmiyordu (2026-08-14: sahte "dokun" okuyla da yanıltmıştı). Bekçi
  // kartın geri gelmediğini ölçer.
  testWidgets('alt kategori ekranında "kolaydan zora" ipucu kartı yok', (
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
    expect(find.text('Kolaydan zora doğru ilerle, puan topla.'), findsNothing);
    expect(find.byType(AppPanel), findsNothing);
  });

  // Satır ikonu her konuda KONUNUN renginde (eskiden hepsi Zimrût).
  for (final category in ['Ziman', 'Çand', 'Dîrok', 'Cografya', 'Muzîk']) {
    testWidgets('$category satır ikonları konunun renginde', (tester) async {
      await tester.pumpWidget(
        wrap(
          SubcategoryScreen(
            repository: MockZanKurdRepository(),
            category: category,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tiles = tester.widgetList<CategoryIconTile>(
        find.byType(CategoryIconTile),
      );
      expect(tiles, isNotEmpty, reason: category);
      expect(tiles.every((t) => t.category == category), isTrue);
    });
  }

  // Konu akışının ortak başlığı: alt kategori ve seviye ekranı AYNI
  // bileşeni ve aynı kategori çizgisini taşır; üçüncü bir başlık yok.
  for (final category in ['Ziman', 'Çand', 'Paradigma']) {
    testWidgets('$category: alt kategori ve seviye ekranı aynı başlığı '
        'kullanır', (tester) async {
      _phone(tester, 390);
      for (final screen in <Widget>[
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: category,
        ),
        LevelScreen(repository: MockZanKurdRepository(), category: category),
      ]) {
        await tester.pumpWidget(wrap(screen));
        await tester.pumpAndSettle();
        expect(find.byType(CategoryBandScaffold), findsOneWidget);
        expect(find.byKey(CategoryBandScaffold.accentKey), findsOneWidget);
        expect(find.byType(ZkBackButton), findsOneWidget);
      }
    });
  }
}
