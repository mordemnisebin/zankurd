import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

/// Bankanın GERÇEK cihazda, gerçek `rootBundle` üzerinden yüklendiğinin
/// kanıtı.
///
/// ## Niçin widget testi yetmiyor
///
/// `test/` altındaki bekçiler JSON'ı `File` ile diskten okur; `flutter
/// test` masaüstünde koşar ve asset paketleme adımını hiç görmez. Bir
/// banka `pubspec.yaml`'a eklenmeyi unutulsa bütün o testler yine yeşil
/// kalır, uygulama ise cihazda o bankayı boş yükler — `_loadJson` tek
/// asset hatasını yutar ve diğer bankalarla devam eder, yani hata sessiz
/// olur.
///
/// Bu test paketlenmiş uygulamanın içinde koşar ve üretim yolunu
/// (`QuestionBankLoader.load()` → `rootBundle.loadString`) kullanır.
///
/// Ağ yok, oturum açma yok: yükleyici yalnız asset okur. Bu bilinçli bir
/// sınırdır — üretim Supabase'ine yazmadan cihaz doğrulaması yapılabilsin
/// diye.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paketlenmiş uygulamada bütün bankalar yükleniyor', (
    tester,
  ) async {
    await QuestionBankLoader.instance.load();
    final questions = QuestionBankLoader.instance.allQuestions;

    expect(
      questions.length,
      2050,
      reason:
          'Cihazda yüklenen kayıt sayısı beklenenden farklı. Bir asset '
          'pubspec üzerinden paketlenmemişse `_loadJson` hatayı yutar ve '
          'banka sessizce boş gelir.',
    );

    const families = ['cinema_', 'tech_core_', 'tech_invent_', 'ziman_x_'];
    final expansion = questions
        .where((q) => families.any(q.id.startsWith))
        .toList();
    expect(
      expansion.length,
      218,
      reason: 'expansion_2026_08 bankası cihazda çözülemedi ya da eksik geldi.',
    );

    // İki dilin de cihazda okunabildiğini doğrula: alan eksikse burada
    // görünür, çünkü paketlenen JSON masaüstündekinden farklı olabilir
    // (kodlama, kırpılma).
    for (final q in expansion) {
      expect(q.answersFor(isKu: true).length, 4, reason: '${q.id} KU şık');
      expect(q.answersFor(isKu: false).length, 4, reason: '${q.id} TR şık');
      expect(
        q.getLocalizedExplanation(true).trim(),
        isNotEmpty,
        reason: '${q.id} KU açıklama',
      );
      expect(
        q.getLocalizedExplanation(false).trim(),
        isNotEmpty,
        reason: '${q.id} TR açıklama',
      );
    }
  });
}
