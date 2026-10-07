import 'learner_lexicon.dart';

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
/// (2026-10-02'ye dek `hejmar`, `lekera-bun`, `dengbeji`, `demsal`) için yerel
/// bankada o konuyu ölçen soru yoktur; geniş kategori havuzuyla doldurmak ilgisiz soruyu "ders
/// sorusu" diye göstermek olurdu (bkz. `loadLearningQuizQuestions`). Bu
/// dersler [unmapped] içinde ADIYLA durur: yeni sunucu dersi eklendiğinde
/// bekçi (`learning_lesson_aliases_test`) onu ya eşlemeye ya da buraya
/// yazmaya zorlar.
class LearningLessonAliases {
  const LearningLessonAliases._();

  /// Sunucu slug'ı -> yerel ölçme bankası ders kimlikleri.
  ///
  /// Kaynak: üretim `lessons` tablosu (2026-10-02, 15 satır; 2026-10-06'dan sonra +4 başlangıç dersi).
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
    // 2026-10-02: son dört sunucu dersi için `ders_2026_10_02` kendi sorularını
    // yazdı. Bu kimlikler yerel katalogda ders DEĞİL, yalnız ölçme bankası
    // etiketidir (yerel dersin sözlük kaynağı da yoktur).
    'hejmar': ['numbers_1'],
    'lekera-bun': ['grammar_bun'],
    'dengbeji': ['culture_dengbeji'],
    'demsal': ['time_seasons'],
    // 2026-10-06: başlangıç yolu (2.0.1). Sunucu dersleri
    // `supabase/2026-10-06_baslangic_lessons.sql` ile açılır; yerel katalogda
    // aynı dersler `id == slug` olarak durur (`alphabet_1`...), bu yüzden
    // etiketli soru ve sözlük kimliği yerel kimliktir.
    'alfabe': ['alphabet_1'],
    'silav-u-rezdari': ['greetings_2'],
    'xwe-nasandin': ['intro_1'],
    'malbat': ['family_1'],
  };

  /// Yerel bankada konusunu ölçen soru bulunmayan sunucu dersleri.
  ///
  /// 2026-10-02: `hejmar`, `lekera-bun`, `dengbeji`, `demsal` artık
  /// [bySlug] içinde (`ders_2026_10_02_questions.json`); şu an boş. Yeni bir
  /// sunucu dersi sorusuz eklenirse adı buraya yazılır.
  static const Set<String> unmapped = {};

  /// [lessonKey] (yerel kimlik ya da sunucu slug'ı) için ölçme bankası
  /// kimlikleri. Eşlenmeyen anahtar kendisine döner: yerel kimlikler (id ==
  /// slug) olduğu gibi çalışır, bilinmeyen sunucu dersi ise bankada karşılığı
  /// olmadığı için boş sonuç verir.
  static List<String> bankIdsFor(String lessonKey) =>
      bySlug[lessonKey] ?? [lessonKey];

  /// [lessonKey] (yerel kimlik ya da sunucu slug'ı) dersinin sözlük çiftleri.
  ///
  /// Hatırlama ve dinleme kartları bunu kullanır. Eskiden ders ekranı
  /// `LearnerLexicon.entriesForSource(lesson.id)` çağırıyordu; sunucu
  /// dersinde `id` bir UUID olduğundan kartlar sessizce hiç görünmüyordu
  /// (aynı eşleşmezlik kısa testte de vardı, bkz. [bankIdsFor]). Birden çok
  /// bankalı derste (`silav-u-nasin`) çiftler banka sırasıyla birleşir.
  ///
  /// [fallbackKey] (dersin `id`'si) yalnız slug hiçbir çift vermediğinde
  /// denenir: yerel katalogda `id == slug` olmayan dersler (ör. `id:
  /// everyday_1`, `slug: selamlasma`) kendi kimlikleriyle de bulunabilsin.
  static List<LearnerLexiconEntry> lexiconEntriesFor(
    String lessonKey, {
    String? fallbackKey,
  }) {
    final bySlugKey = [
      for (final bankId in bankIdsFor(lessonKey))
        ...LearnerLexicon.entriesForSource(bankId),
    ];
    if (bySlugKey.isNotEmpty || fallbackKey == null) {
      return List.unmodifiable(bySlugKey);
    }
    return LearnerLexicon.entriesForSource(fallbackKey);
  }
}
