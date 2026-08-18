import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// 214 sorunun GERÇEKTEN oyuncuya ulaştığının bekçisi.
///
/// (2026-08-18: dış inceleme `tech_invent_0053`ü belirsiz bulup çıkardı;
/// aileron ile flap ayrımı yapılmıyordu; sonra Ziman incelemesi üç zayıf
/// çeldiricili kaydı daha aldı. Sayı 218 → 214.)
///
/// ## Kusur
///
/// Bir bankayı "aktive etmek" dosyayı yazmak değildir. `expansion_2026_08`
/// bankası eklenirken üç ayrı yerde kaydedildi (`questionBankAssets`,
/// `source_manifest.json`, testlerin kendi listeleri) ve her biri "tamam"
/// dedi — ama hiçbiri **uygulamanın yükleyicisine** sormadı.
///
/// Bu ayrım teoriden ibaret değil: aynı hafta `rebalance_answer_positions
/// .py` bankayı kendi yol deseni yüzünden hiç görmemişti, yani "kayıtlı"
/// olmak "görünür" olmayı garanti etmiyor. Dahası yükleyici id çakışmasında
/// SONRAKİ bankayı kazandırır (`question_bank_loader.dart`); yeni bir id
/// mevcut bir soruyla çakışırsa dosya yüklenir, soru sayısı artar, ama
/// çakışan kayıt sessizce gölgede kalır ve oyuncu onu asla görmez.
///
/// Bu bekçi yükleyicinin çıktısını sayar: fiziksel toplam, id bazında
/// kanonik toplam ve 218 kaydın tek tek erişilebilirliği. Sayılar burada
/// sabitlenir ki bir sonraki banka sessizce eksik gelmesin.
void main() {
  late List<QuizQuestion> loaded;

  setUpAll(() {
    loaded = QuestionBankLoader.instance.allQuestions;
  });

  test('yükleyici beklenen fiziksel ve tekil toplamı veriyor', () {
    // Kalite kapısının bildirdiği "canonical 1989" BAŞKA bir ölçüdür ve
    // yükleyicinin sayısı değildir: kapı fiziksel kaydı kendi
    // canonicalization'ıyla 1989'a indirir. Bu −61'lik fark bu batch'ten
    // önce de vardı (1832 fiziksel → 1771 kanonik, yine −61); genişletme
    // her iki sayıya da +218 ekledi, yani 218 kaydın tamamı kanonik olarak
    // ayrıdır. Yükleyici düzeyinde doğru ölçü id bazında TEKİLLİK'tir ve
    // orada kayıp yoktur.
    //
    // 2026-08-07: 2151 → 2118 → 2138. Önce otuz üç kayıt çıkarıldı; gerekçesi
    // `tool/content_authoring/repair_manifest_2026_08_07.json` içinde kayıt
    // kayıt yazılıdır. Otuz biri kendi kategorisini soran döngüsel «kategori
    // eşleştirme» sorusuydu ve sınıf kendi içinde çelişiyordu: «dengbêj» bir
    // soruda Çand, bir başkasında Muzîk sayılıyordu. İkisi ise yanlış
    // seçeneği hiçbir koşulda savunulabilir olmayan önemsiz önermelerdi.
    // Sonra bu kayıtların öksüz bıraktığı görsellere yirmi yeni görsel soru
    // yazıldı (`visual_2026_08_07_questions.json`), dolayısıyla 2118 → 2138.
    final uniqueIds = loaded.map((q) => q.id).toSet();
    expect(
      loaded.length,
      3078,
      reason:
          'Fiziksel kayıt sayısı değişti. Banka eklendi/çıkarıldıysa bu sayı '
          'bilerek güncellenmeli; kendiliğinden kaymışsa bir asset '
          'yüklenmiyor demektir.',
    );
    expect(
      uniqueIds.length,
      loaded.length,
      reason:
          'Yükleyici id çakışmasında SONRAKİ bankayı kazandırır; tekil sayı '
          'fiziksel sayının altına düştüyse bir soru gölgede kalıyor ve '
          'oyuncuya hiç gösterilmiyor demektir.',
    );
  });

  test('214 genişletme sorusunun tamamı yükleyiciden erişilebilir', () {
    // Gölgelenme kontrolü: id'nin var olması yetmez, KAZANAN kaydın
    // genişletme bankasından gelmesi gerekir. Genişletme en son yüklenir,
    // dolayısıyla çakışma olsaydı o kazanırdı — ama o zaman da ESKİ soru
    // kaybolurdu ve kanonik sayı düşerdi (üstteki test).
    const families = ['cinema_', 'tech_core_', 'tech_invent_', 'ziman_x_'];
    final expansion = loaded
        .where((q) => families.any(q.id.startsWith))
        .toList();
    expect(
      expansion.length,
      214,
      reason:
          'Genişletme bankasından yükleyiciye ulaşan soru sayısı 214 değil. '
          'Asset listede olsa bile parse hatası tek bankayı sessizce boş '
          'bırakır (`_loadBank` catch bloğu).',
    );
    final ids = expansion.map((q) => q.id).toSet();
    expect(ids.length, 214, reason: 'Genişletme içinde id tekrarı var.');
  });

  test('genişletme soruları her iki dilde de tam oynanabilir', () {
    const families = ['cinema_', 'tech_core_', 'tech_invent_', 'ziman_x_'];
    final expansion = loaded.where((q) => families.any(q.id.startsWith));
    final offenders = <String>[];
    for (final q in expansion) {
      for (final isKu in [true, false]) {
        final answers = q.answersFor(isKu: isKu);
        final correct = q.correctAnswerFor(isKu: isKu);
        if (answers.length != 4) {
          offenders.add('${q.id}: isKu=$isKu şık sayısı ${answers.length}');
        }
        if (!answers.contains(correct)) {
          offenders.add('${q.id}: isKu=$isKu doğru cevap şıklarda yok');
        }
        if (answers.toSet().length != answers.length) {
          offenders.add('${q.id}: isKu=$isKu şıklar tekrar ediyor');
        }
        final explanation = q.getLocalizedExplanation(isKu);
        if (explanation.trim().isEmpty) {
          offenders.add('${q.id}: isKu=$isKu açıklama boş');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(15).join('\n'));
  });

  test('genişletme sorularının görünen sırası iki dilde de aynı yerde', () {
    // `displayAnswers` id'den türeyen sabit bir kaydırma uygular. İki dilin
    // şık listesi aynı devrişimle taşınmazsa Türkçe oyuncu dengelenmemiş
    // bir dağılım görür — dengeleyici 2026-08-06'ya kadar yalnız `answers`ı
    // taşıyordu.
    const families = ['cinema_', 'tech_core_', 'tech_invent_', 'ziman_x_'];
    final expansion = loaded.where((q) => families.any(q.id.startsWith));
    final offenders = <String>[];
    for (final q in expansion) {
      final ku = q
          .answersFor(isKu: true)
          .indexOf(q.correctAnswerFor(isKu: true));
      final tr = q
          .answersFor(isKu: false)
          .indexOf(q.correctAnswerFor(isKu: false));
      if (ku != tr) offenders.add('${q.id}: ku=$ku tr=$tr');
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Doğru cevap iki dilde farklı konumda; dengeleme yalnız bir dile '
          'uygulanmış:\n${offenders.take(15).join("\n")}',
    );
  });
}
