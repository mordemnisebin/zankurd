import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';

import 'support/widget_test_helpers.dart';

/// Favoriden çıkarma başarısız olursa kullanıcı bunu görmeli.
///
/// ## Kusur
///
/// `_removeFavorite` şöyleydi:
///
/// ```dart
/// await widget.repository.toggleFavoriteQuestion(question, false);
/// if (!mounted) return;
/// ScaffoldMessenger.of(context).showSnackBar(... K.questionRemoved ...);
/// _reload();
/// ```
///
/// Hiçbir `try` yok. `toggleFavoriteQuestion` sunucu tarafında FIRLATIR —
/// `SupabaseZanKurdRepository`de silme sorgusunun etrafında hiçbir yakalama
/// yoktur. Ağ yokken, oturum düşmüşken ya da RLS reddettiğinde `await`
/// fırlar, gövdenin geri kalanı hiç çalışmaz ve hata ekranda hiçbir iz
/// bırakmaz: kullanıcı çöp kutusuna dokunur, hiçbir şey olmaz, soru listede
/// kalır ve niçin olduğunu söyleyen tek kelime yoktur (2026-08-17).
///
/// ## Niçin sessiz kaldı
///
/// Aynı işi yapan `quiz_screen._toggleFavorite` bunu ZATEN doğru yapıyordu:
/// `try/catch`, `ErrorReporter` ve görünür bir hata mesajı. Yani desen
/// projede vardı ve doğruydu; ayrışan yalnız bu ekrandı. İki uygulamayı
/// karşılaştıran hiçbir test olmadığı için ayrışma da görünmedi — favori
/// testleri (`favorites_flow_test` ve kardeşleri) mutlu yolu sürüyor.
///
/// ## Ölçülen şey
///
/// Mesajın varlığı değil, ÜÇÜ birden: hata mesajı çıkar, "çıkarıldı" mesajı
/// ÇIKMAZ (yoksa kullanıcıya olmamış bir şey olmuş denir) ve soru listede
/// kalır (yoksa ekran sunucuyla çelişen bir liste gösterir).
class _RemoveFailsRepository extends MockZanKurdRepository {
  int removeAttempts = 0;

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async => [
    playableQuestions.first,
  ];

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    if (favorite) return super.toggleFavoriteQuestion(question, favorite);
    removeAttempts++;
    throw Exception('injected: silme sorgusu reddedildi');
  }
}

/// Silme çağrısı geçen depo — başarı yolunun hâlâ çalıştığını ölçmek için.
class _RemoveSucceedsRepository extends MockZanKurdRepository {
  bool removed = false;

  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async =>
      removed ? const [] : [playableQuestions.first];

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    if (!favorite) removed = true;
    return favorite;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpFavorites(
    WidgetTester tester,
    MockZanKurdRepository repository,
  ) async {
    await tester.pumpWidget(
      testShell(child: FavoriteQuestionsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('silme başarısızsa hata görünür ve soru listede kalır', (
    tester,
  ) async {
    final repository = _RemoveFailsRepository();
    await pumpFavorites(tester, repository);

    // Satır sayısı, soru METNİNDEN daha sağlam bir ölçü: kart metni kırpar
    // ve dile göre değişir, "Kaldır" düğmesi ise satır başına tam bir tane.
    expect(find.byTooltip('Kaldır'), findsOneWidget);

    await tester.tap(find.byTooltip('Kaldır').first);
    await tester.pumpAndSettle();

    expect(repository.removeAttempts, 1);
    expect(
      find.text('Soru kayıtlardan çıkarılamadı.'),
      findsOneWidget,
      reason:
          'Silme fırladı ve ekranda hiçbir iz kalmadı; kullanıcı dokunuşun '
          'işe yarayıp yaramadığını bilemiyor.',
    );
    expect(
      find.text('Soru kayıtlardan çıkarıldı.'),
      findsNothing,
      reason:
          'Sunucu reddettiği hâlde kullanıcıya "çıkarıldı" denirse olmamış '
          'bir şey olmuş sayılır.',
    );
    expect(
      find.byTooltip('Kaldır'),
      findsOneWidget,
      reason: 'Soru listeden düştüyse ekran sunucuyla çelişiyor.',
    );
  });

  testWidgets('silme başarılıysa onay çıkar ve liste tazelenir', (
    tester,
  ) async {
    // Bekçi yalnız hata dalını ölçseydi, her silmede hata gösteren bir
    // regresyon da testi geçerdi.
    final repository = _RemoveSucceedsRepository();
    await pumpFavorites(tester, repository);

    await tester.tap(find.byTooltip('Kaldır').first);
    await tester.pumpAndSettle();

    expect(repository.removed, isTrue);
    expect(find.text('Soru kayıtlardan çıkarıldı.'), findsOneWidget);
    expect(find.text('Soru kayıtlardan çıkarılamadı.'), findsNothing);
  });
}
