import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Görselli soruların ekran-okuyucu alt metni bekçisi.
///
/// ## Kusur
///
/// 2026-09-28 denetiminde bankada 126 görselli soru vardı (124'ü JSON, 2'si
/// kod içi `curatedQuestionBank`), ama yalnız 20'si (`visual_2026_08_07_*`)
/// `imageAltKu`/`imageAltTr` taşıyordu. Diğer 104 JSON sorusu
/// (`assets/data/offline_questions.json` içindeki resim-kelime eşleştirme
/// soruları) ve iki kod içi soru alt metinsizdi: `_QuestionImage` semantics etiketini
/// `question.imageAltFor(isKu: ...)`dan alır (bkz.
/// `lib/src/screens/quiz/quiz_screen_ui.dart`), o da boşsa arayüz genel bir
/// yerelleştirilmiş etikete düşer. Yani TalkBack/VoiceOver kullanan bir
/// oyuncu bu 104 sorunun HİÇBİRİNDE görselin ne gösterdiğini duymuyordu —
/// kimi soruda görsel süstür, ama "av" gibi resim-kelime sorularında görsel
/// SORUNUN KENDİSİDİR; alt metnin yokluğu soruyu görme engelli bir oyuncu
/// için çözülemez kılıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbir bekçi görselli bir sorunun semantics etiketini kontrol etmiyordu.
/// `image_credits_test.dart` ve `question_bank_test.dart` yalnız görsel
/// DOSYASININ var olduğunu doğruluyor (bkz. `imageUrl` + `asset://`
/// taraması); `imageAltKu`/`imageAltTr` alanlarının doldurulup
/// doldurulmadığına hiç bakmıyorlardı. Alanlar nullable ve zorunlu
/// olmadığı için (bkz. `QuizQuestion.imageAltKu` dokümantasyonu — uydurma
/// betimleme, betimlemenin yokluğundan kötüdür) derleyici de susardı.
///
/// ## Bekçinin üç kuralı
///
/// 1. Boş olamaz — `imageAltFor` boşsa arayüz sessiz kalır.
/// 2. 110 karakteri geçemez — kısa ve somut kalmalı, ekran okuyucu bir
///    paragraf değil bir cümle okumalı. Bu sınır yalnız 2026-09-28'de veya
///    sonra yazılan metinlere uygulanır: `visual_2026_08_07_*` künyeli 20
///    kayıt bu sözleşmeden ÖNCE yazıldı ve incelendi; onları yalnız sızıntı
///    (kural 3) için gözden geçirmek görev kapsamındaydı, yeniden yazmak
///    değil — o yüzden bekçi onları uzunluk kuralına tabi TUTMAZ.
/// 3. Doğru cevabı sızdıramaz — `correctAnswer`/`correctAnswerTr` metni
///    (büyük/küçük harf duyarsız) alt metinde geçemez, MECBUR OLMADIKÇA:
///    soru zaten `prompt`/`promptTr` içinde o metni söylüyorsa (ör. "av"
///    kavramını gösteren görsel sorusunda "av" prompt'ta zaten yazılı)
///    istisna uygulanır. Görselde görüneni betimlemek serbesttir (ör.
///    `visual_2026_08_07_0016` defi betimler; cevap ise "zilin çıkardığı
///    ses"tir); yasak olan, cevap metninin alt metne kopyalanmasıdır —
///    `visual_2026_08_07_0003`teki "şûtik" tam böyle bir sızıntıydı.
///
/// ## Kapsam: bütün bankalar
///
/// `allQuestions` yalnız JSON asset'lerini değil, kod içi
/// `curatedQuestionBank`'ı da taşır (bkz. `question_bank_loader.dart`'daki
/// `[...curatedQuestionBank, ...]` birleşimi); oradaki iki görselli soru
/// (`curated_movement_0008`, `curated_movement_0010`) da aynı gün alt metin
/// aldı. Bekçi hiçbir bankayı dışarıda tutmaz: yeni bir görselli soru
/// nereye eklenirse eklensin alt metinsiz gelemez.
void main() {
  late List<QuizQuestion> imageQuestions;

  setUpAll(() {
    // `load()` DEĞİL `allQuestions`: test koşucusunda rootBundle yok, yükleyici
    // `load()` ile her asset'i sessizce boş döndürür ve yalnız curated 45 soru
    // kalır — bu bekçi o hâlde 104 sorunun hiçbirini görmeden yeşil kalırdı.
    // `allQuestions` senkron test yüklemesini (`question_bank_loader_io.dart`)
    // tetikler ve gerçek JSON dosyalarını okur (bkz. `subcategory_pool_width_test.dart`).
    imageQuestions = QuestionBankLoader.instance.allQuestions
        .where((q) => q.hasImage && q.imageUrl!.startsWith('asset://'))
        .toList();
  });

  test('banka gerçekten yüklendi ve görselli sorular içeriyor', () {
    // Yükleyici sessizce boş dönerse (ör. asset yolu bozulursa) aşağıdaki
    // döngü hiç soru gezmez ve bekçi anlamsızca yeşil kalır. 2026-09-28
    // denetiminde 126 görselli soru vardı; eşik onu delmeyecek kadar
    // yüksek, gelecekteki büyümeyi engellemeyecek kadar gevşek.
    expect(imageQuestions.length, greaterThan(100));
  });

  test(
    'her görselli sorunun ku/tr alt metni var, kısa ve cevabı sızdırmıyor',
    () {
      final missingAlt = <String>[];
      final tooLong = <String>[];
      final leaks = <String>[];

      for (final q in imageQuestions) {
        final ku = q.imageAltKu?.trim() ?? '';
        final tr = q.imageAltTr?.trim() ?? '';

        if (ku.isEmpty) missingAlt.add('${q.id}: imageAltKu boş');
        if (tr.isEmpty) missingAlt.add('${q.id}: imageAltTr boş');
        if (ku.isEmpty || tr.isEmpty) continue;

        // Kural 2: `visual_2026_08_07_*` künyeli 20 kayıt 110 karakter
        // sözleşmesinden (2026-09-28) önce yazıldı; sınır onlardan sonrakilere
        // uygulanır (bkz. dosya başlığındaki not).
        final isLegacyEntry = q.id.startsWith('visual_2026_08_07_');
        if (!isLegacyEntry) {
          if (ku.length > 110) {
            tooLong.add('${q.id}: imageAltKu ${ku.length} karakter');
          }
          if (tr.length > 110) {
            tooLong.add('${q.id}: imageAltTr ${tr.length} karakter');
          }
        }

        // Kural 3: doğru cevap metni alt metinde sızmasın — soru zaten
        // prompt'ta o metni söylüyorsa istisna uygulanır.
        final bothPrompts = '${q.prompt} ${q.promptTr ?? ''}'.toLowerCase();
        final forbidden = <String>{
          q.correctAnswer.trim(),
          (q.correctAnswerTr ?? '').trim(),
        }..removeWhere((s) => s.isEmpty);

        for (final answer in forbidden) {
          final lower = answer.toLowerCase();
          if (bothPrompts.contains(lower)) continue;
          if (ku.toLowerCase().contains(lower)) {
            leaks.add('${q.id}: imageAltKu "$answer" cevabını sızdırıyor');
          }
          if (tr.toLowerCase().contains(lower)) {
            leaks.add('${q.id}: imageAltTr "$answer" cevabını sızdırıyor');
          }
        }
      }

      expect(
        missingAlt,
        isEmpty,
        reason: 'Boş alt metin:\n${missingAlt.join('\n')}',
      );
      expect(
        tooLong,
        isEmpty,
        reason: '110 karakteri aşan alt metin:\n${tooLong.join('\n')}',
      );
      expect(leaks, isEmpty, reason: 'Cevap sızıntısı:\n${leaks.join('\n')}');
    },
  );
}
