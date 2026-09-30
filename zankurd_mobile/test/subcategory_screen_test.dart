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
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_panel.dart';
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

  // 2026-09-29 doğallık (K1): Ziman'ın çizimi kalktı (çizimsiz ton + ikon).
  // 2026-09-30 kimlik: başlıkta artık hiçbir kategori resim çizmez, hepsi
  // kilim bandı kurar; Ziman'da başlıkta hiç resim olmamalı.
  testWidgets('çizimi kalkan kategori başlıkta resim çizmez', (tester) async {
    await tester.pumpWidget(
      wrap(
        SubcategoryScreen(
          repository: MockZanKurdRepository(),
          category: 'Ziman',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
  });

  // 2026-09-30 kimlik: başlık artık fotoğraf benzeri çizimle (Çand'ın hero
  // görseli) değil, K1 kilim deseniyle kurulur. Eski bekçi "hero görseli
  // semantics ağacına girmez" diyordu; görsel kalktı, kural kilim bandına
  // taşındı: dekoratif bant ekran okuyucuya adsız durak olmamalı.
  testWidgets('kilim bandı dekoratiftir: resim yok, semantics ağacına girmez', (
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
    final band = find.byKey(const ValueKey('subcategory-kilim-band'));
    expect(band, findsOneWidget);
    expect(
      find.ancestor(of: band, matching: find.byType(ExcludeSemantics)),
      findsOneWidget,
    );
    final painter =
        tester.widget<CustomPaint>(band).painter! as SahneKilimBandPainter;
    expect(painter.mark, SahneTopicMark.cand);
    expect(painter.tone, SahneCategoryTone.cand);
  });

  // 2026-09-30 kimlik: yedi konunun HEPSİ (eskiden çizimi olanlar ve
  // olmayanlar iki ayrı dilde konuşuyordu) kendi motifini taşır; motifsiz
  // konu düz tonda kalır ve çökmez. 320 px, %200 yazıda taşma yok.
  for (final category in [...CategoryVisuals.markedCategories, 'Bilinmeyen']) {
    testWidgets('$category başlığı 320 px ve %200 yazıda taşmaz', (
      tester,
    ) async {
      // 2026-09-30 bant: `setSurfaceSize` MediaQuery'yi 800 px bırakıyordu;
      // gerçek 320 px görünümü kurulur (bkz. [_phone]).
      _phone(tester, 320);
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
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: SubcategoryScreen(
              repository: _FixedPlayableRepository(
                _keywordMatchedQuestions(
                  category: category,
                  keyword: 'x',
                  count: 3,
                ),
              ),
              category: category,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: category);
      final band = find.byKey(const ValueKey('subcategory-kilim-band'));
      expect(
        band,
        CategoryVisuals.mark(category) == null ? findsNothing : findsOneWidget,
        reason: category,
      );
    });
  }

  // 2026-09-30 bant: bant eskiden çubuğun altına 88 px boş bant ekliyordu,
  // desen köşede küçük bir blok kalıyordu. Kusur sessizdi: yükseklik ve desen
  // konumu hiçbir testte ölçülmüyordu, taşma da yoktu, yalnız dengesiz
  // görünüyordu. Bekçi: desen bandın üst ve alt kenarına değer (tam
  // yükseklik), hücre tam sayı pikseldir, desen başlığın ve alt satırın
  // sınır kutusuyla kesişmez, alt satırın altında 16-25 px boşluk kalır;
  // 320 px ve %200 yazıda da (bant uzar, hücre yeniden hesaplanır).
  for (final scale in [1.0, 2.0, 2.35]) {
    for (final width in [320.0, 390.0]) {
      for (final category in CategoryVisuals.markedCategories) {
        testWidgets('$category bandı: desen tam yükseklikte, metinle çakışmaz '
            '(${width.round()} px, x$scale)', (tester) async {
          _phone(tester, width);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => LanguageProvider()..setLang('tr'),
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
                home: SubcategoryScreen(
                  repository: MockZanKurdRepository(),
                  category: category,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: category);

          final bandFinder = find.byKey(
            const ValueKey('subcategory-kilim-band'),
          );
          final band = tester.getRect(bandFinder);
          final painter =
              tester.widget<CustomPaint>(bandFinder).painter!
                  as SahneKilimBandPainter;
          final cell = SahneKilimBandPainter.cellFor(band.height);
          expect(cell, cell.roundToDouble(), reason: 'hücre tam sayı');
          expect(band.height % 9, 0, reason: 'yükseklik 9 katı');
          expect(cell * 9, band.height, reason: 'hücre = yükseklik / 9');

          final pattern = SahneKilimBandPainter.patternRect(
            band.size,
            painter.reservedWidth,
          ).shift(band.topLeft);
          expect(pattern.top, band.top, reason: 'desen bandın üstüne değer');
          expect(pattern.bottom, band.bottom, reason: 'altına değer');
          final visible = pattern.intersect(band);
          expect(visible.width, greaterThan(0), reason: 'desen görünür');

          final title = tester.getRect(
            find.text(CategoryNames.localized(category, false)),
          );
          final subtitle = tester.getRect(
            find.text(Tr.of(K.birAltAlanSecerek, AppLanguage.tr)),
          );
          expect(
            visible.overlaps(title),
            isFalse,
            reason: 'desen başlıkla çakışıyor: $visible / $title',
          );
          expect(
            visible.overlaps(subtitle),
            isFalse,
            reason: 'desen alt satırla çakışıyor: $visible / $subtitle',
          );
          // Bant içeriğe oturur: alt satırın altında boş blok kalmaz.
          final gap = band.bottom - subtitle.bottom;
          expect(gap, greaterThanOrEqualTo(16), reason: 'alt boşluk $gap');
          // 9'a yuvarlama en çok 9 px ekler; durum payı artık desenli kısmın
          // dışında (2026-09-30 simülatör) olduğundan üst sınır 16 + 9.
          expect(gap, lessThanOrEqualTo(25), reason: 'alt boşluk $gap');
        });
      }
    }
  }

  // 2026-09-30 simülatör: en büyük yazıda (iPhone 17e, %235) alt satır iki
  // satırda "…" ile kesiliyordu ("Barekî hilbijêre û dest bi lîsti…"); kusur
  // sessizdi çünkü çubuk yüksekliği de iki satırla ölçülüyor, taşma ya da
  // çakışma yoktu, yalnız cümle yarım kalıyordu. Bekçi: %235'te iki dilde,
  // iki genişlikte alt satır ve başlık kesilmez, çubuk ve bant taşmaz.
  for (final lang in ['tr', 'ku']) {
    for (final width in [320.0, 390.0]) {
      testWidgets('alt satır ve başlık x2.35 yazıda kesilmez '
          '($lang, ${width.round()} px)', (tester) async {
        _phone(tester, width);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => LanguageProvider()..setLang(lang),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2.35)),
                child: child!,
              ),
              home: SubcategoryScreen(
                repository: MockZanKurdRepository(),
                category: 'Ziman',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final ku = lang == 'ku';
        for (final text in [
          Tr.forKu(K.birAltAlanSecerek, ku),
          CategoryNames.localized('Ziman', ku),
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(text).first,
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '"$text" kesiliyor',
          );
        }
      });
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
