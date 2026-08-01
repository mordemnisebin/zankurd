/// Uygulamanın yüklediği JSON soru bankalarının TEK listesi.
///
/// ## Niçin var
///
/// Bu liste üç yerde ayrı ayrı yazılıydı: üretim yükleyicisinde
/// (`question_bank_loader.dart`), test yükleyicisinde
/// (`question_bank_loader_io.dart`) ve denetim araçlarında
/// (`tool/audit_*.dart`). Zamanla ayrıştılar — araçlar iki bankayı
/// tarıyordu, uygulama dördünü yüklüyordu.
///
/// Sonuç, sessiz bir kör nokta: `audit_option_languages.dart` tam da
/// "şıklardan biri doğru cevabın dilinde değil" kusurunu aramak için
/// yazılmıştı ve `editorial_questions.json`ı hiç açmıyordu — oysa
/// uygulama o bankayı yüklüyor. Denetim "temiz" diyordu çünkü baktığı
/// yerde kusur yoktu (2026-08-01).
///
/// Yeni bir banka eklendiğinde tek yer burasıdır; yükleyiciler ve araçlar
/// buradan okur, bir bekçi de üçünün ayrışmadığını doğrular.
library;

/// Yükleme sırası anlamlıdır: aynı `id` birden çok bankada varsa SONRAKİ
/// kazanır. Curated (Dart sabiti) her zaman en önde durur ve bu listede
/// yer almaz — o bir asset değil.
const questionBankAssets = <String>[
  'assets/data/sentence_building_questions.json',
  'assets/data/community_questions.json',
  'assets/data/editorial_questions.json',
  'assets/data/offline_questions.json',
];
