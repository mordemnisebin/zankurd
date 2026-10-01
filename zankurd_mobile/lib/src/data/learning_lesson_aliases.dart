/// Sunucudaki ders kimliklerini (slug) yerel ölçme bankasının ders
/// kimliklerine bağlar.
///
/// ## Kusur
///
/// "Kısa test" soruları derse `learningLessonId` ile bağlanır ve bu etiketler
/// YEREL ders kimlikleridir (`everyday_1`, `grammar_1`...). Sunucudaki
/// `lessons` tablosu ise farklı bir katalogtur: kimlik UUID, slug
/// `silav-u-nasin`, `cinavk`... (`supabase/2026-07-06_lesson_seed.sql`).
/// Sunucu dersinde mini quiz `lesson.id` (UUID) ile aranıyordu; yerel
/// bankada o kimlikle etiketli tek soru ve sözlük kaydı olmadığından
/// "Selamlaşma ve Tanışma" ile "Zamirler" gibi dersler boş kalıyordu.
///
/// ## Niçin sessiz kalıyordu
///
/// Testler ve geliştirme yerel ders kimlikleriyle koşar (`MockZanKurd...`
/// dersleri `id == slug`); sunucu kataloğuyla bir kez bile koşulmuyordu.
/// Ders ekranı "soru yok" durumunu da bir hata gibi ("Quiz yüklenemedi")
/// yazdığı için kusur bir veri eşleşmesizliği değil geçici ağ hatası gibi
/// görünüyordu.
///
/// ## Kural
///
/// Yalnız konusu AÇIKÇA örtüşen dersler eşlenir. Eşleşmeyen sunucu dersi
/// (`hejmar`, `lekera-bun`, `dengbeji`, `demsal`) için yerel bankada o konuyu
/// ölçen soru yoktur; geniş kategori havuzuyla doldurmak ilgisiz soruyu "ders
/// sorusu" diye göstermek olurdu (bkz. `loadLearningQuizQuestions`). Bu
/// dersler [unmapped] içinde ADIYLA durur: yeni sunucu dersi eklendiğinde
/// bekçi (`learning_lesson_aliases_test`) onu ya eşlemeye ya da buraya
/// yazmaya zorlar.
class LearningLessonAliases {
  const LearningLessonAliases._();

  /// Sunucu slug'ı -> yerel ölçme bankası ders kimlikleri.
  ///
  /// Kaynak: üretim `lessons` tablosu (2026-10-02, 15 satır).
  static const Map<String, List<String>> bySlug = {
    'silav-u-nasin': ['everyday_1', 'everyday_2'],
    'cinavk': ['grammar_1'],
    'newroz': ['culture_2'],
    'xwarinen-kurdi': ['food_1'],
    'feki-u-sebze': ['food_2'],
    'ajalen-male': ['animals_1'],
    'ajalen-kovi': ['animals_2'],
    'ciya-u-cem': ['geography_1'],
    'cih-u-war': ['geography_2'],
    'hesten-bingehin': ['emotions_1', 'emotions_2'],
    'rojen-hefteye': ['time_1'],
  };

  /// Yerel bankada konusunu ölçen soru bulunmayan sunucu dersleri.
  static const Set<String> unmapped = {
    'hejmar',
    'lekera-bun',
    'dengbeji',
    'demsal',
  };

  /// [lessonKey] (yerel kimlik ya da sunucu slug'ı) için ölçme bankası
  /// kimlikleri. Eşlenmeyen anahtar kendisine döner: yerel kimlikler (id ==
  /// slug) olduğu gibi çalışır, bilinmeyen sunucu dersi ise bankada karşılığı
  /// olmadığı için boş sonuç verir.
  static List<String> bankIdsFor(String lessonKey) =>
      bySlug[lessonKey] ?? [lessonKey];
}
