import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';

import 'support/widget_test_helpers.dart';

/// Kategori takma adları alt kategoriyi düşürmemeli.
///
/// ## Kusur
///
/// `CategoryVisuals` on bir takma ad tanır ('Dil'→'Ziman', 'Tarih'→'Dîrok',
/// 'Film'→'Sînema', …) çünkü kategori adı her yerden kanonik biçimde
/// gelmiyor. `SubcategoryConfig.subcategories` haritasının anahtarları ise
/// yalnız kanonik biçimdir.
///
/// Seviye ekranı haritaya HAM erişiyordu:
/// `SubcategoryConfig.subcategories[category] ?? const []`. Kategori adı bir
/// takma ad olarak geldiğinde harita null döner, liste boş kalır, aranan alt
/// kategori bulunamaz ve ekran başlığı sessizce genel hâline düşer: kullanıcı
/// "Rêziman"ı seçmiştir ama başlıkta yalnız "Ziman" ve genel alt metin yazar.
/// Hata yok, boş ekran yok — yalnız kaybolmuş bir bağlam.
///
/// ## Niçin sessiz kaldı
///
/// Kusur bir kez yaşanmış ve TEK VAKALIK yamalanmıştı: haritada `'Sînema'`
/// ile birebir aynı listeyi taşıyan ikinci bir `'Sinema'` anahtarı duruyordu.
/// Kopya anahtar o bir takma adı kurtarıyor, kalan onunu bırakıyordu — ve
/// kopya olduğu için ölçüm de yapılmıyordu: `subcategory_pool_width_test`
/// havuz genişliğini ölçer, `subcategory_screen_test` kartları çizer, ikisi
/// de kanonik adlarla çalışır. Takma adla çağıran hiçbir test yoktu
/// (2026-08-17).
///
/// Çözüm kopya anahtar değil, kanonikleştiren tek erişimci
/// (`SubcategoryConfig.forCategory`); bu dosya onun bütün takma adlar için
/// çalıştığını ölçer, yalnız kurtarılmış olan için değil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Ürünün tanıdığı takma adlar. Liste burada tekrar YAZILMAZ — kaynağın
  /// kendisinden türetilir, yoksa yeni bir takma ad eklendiğinde bekçi onu
  /// hiç görmez ve kusur yeniden sessizleşir.
  final aliasPairs = <String, String>{
    for (final alias in CategoryVisuals.knownAliases)
      alias: CategoryVisuals.canonicalName(alias),
  };

  test('ürün en az on takma ad tanıyor (bekçi boş kümede geçmesin)', () {
    expect(aliasPairs.length, greaterThanOrEqualTo(10));
  });

  test('her takma ad kanonik adla aynı alt kategori listesini verir', () {
    final broken = <String>[];
    aliasPairs.forEach((alias, canonical) {
      final viaAlias = SubcategoryConfig.forCategory(alias);
      final viaCanonical = SubcategoryConfig.forCategory(canonical);
      if (viaCanonical.isEmpty) return; // kanonik kategorinin alt kırılımı yok
      if (viaAlias.length != viaCanonical.length) {
        broken.add(
          '$alias → $canonical: takma adla ${viaAlias.length}, kanonikle '
          '${viaCanonical.length} alt kategori',
        );
      }
    });

    expect(
      broken,
      isEmpty,
      reason:
          'Bu takma adlarla girildiğinde alt kategoriler kayboluyor; ekran '
          'başlığı sessizce genel hâline düşer:\n${broken.join('\n')}',
    );
  });

  test('alt kategori id\'leri iki kategoriye birden ait değil', () {
    // Kopya `'Sinema'` anahtarı üç id'yi iki kategoriye birden yazıyordu.
    // Aynı id iki kategoride durursa `firstWhere` ile yapılan aramalar
    // hangisini bulacağını harita sırasına bırakır.
    final owners = <String, List<String>>{};
    SubcategoryConfig.subcategories.forEach((category, list) {
      for (final sub in list) {
        owners.putIfAbsent(sub.id, () => []).add(category);
      }
    });

    final shared = owners.entries
        .where((e) => e.value.length > 1)
        .map((e) => '${e.key} → ${e.value.join(", ")}')
        .toList();

    expect(shared, isEmpty, reason: 'Paylaşılan alt kategori id\'leri:\n'
        '${shared.join('\n')}');
  });

  test('haritanın her anahtarı kanonik biçimdedir', () {
    final nonCanonical = SubcategoryConfig.subcategories.keys
        .where((key) => CategoryVisuals.canonicalName(key) != key)
        .toList();

    expect(
      nonCanonical,
      isEmpty,
      reason:
          'Bu anahtarlar takma ad: $nonCanonical. Takma adlar haritaya '
          'kopyalanmaz, `forCategory` zaten çözer — kopya anahtar yalnız '
          'kendi vakasını kurtarır ve iki kategoriye ait id üretir.',
    );
  });

  test('bankadaki her kategori alt kırılımını buluyor', () {
    final categories = MockZanKurdRepository().playableQuestions
        .map((q) => q.category)
        .toSet();
    expect(categories.length, greaterThanOrEqualTo(8));

    final missing = categories
        .where((c) => SubcategoryConfig.forCategory(c).isEmpty)
        .toList();

    expect(
      missing,
      isEmpty,
      reason:
          'Bu kategorilerde alt kategori yok; kullanıcı yalnız "Tüm Sorular" '
          'kartını görür: $missing',
    );
  });

  testWidgets('takma adla açılan seviye ekranı alt kategori başlığını taşır', (
    tester,
  ) async {
    // Kullanıcının gördüğü şey ölçülür: harita doğru olsa bile ekran ham
    // erişime dönerse başlık yine kaybolur.
    await tester.pumpWidget(
      testShell(
        child: LevelScreen(
          repository: MockZanKurdRepository(),
          category: 'Dil',
          subCategory: 'reziman',
        ),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final expected = SubcategoryConfig.forCategory('Dil')
        .firstWhere((s) => s.id == 'reziman')
        .nameTr;

    expect(
      find.textContaining(expected),
      findsWidgets,
      reason:
          '"Dil" takma adıyla girilince alt kategori adı ("$expected") '
          'başlıkta yok; ekran genel başlığa düşmüş.',
    );
  });
}
