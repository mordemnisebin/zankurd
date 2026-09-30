import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne_topic_marks.dart';

/// Kategori bazlı görsel kaynak (ikon + arka plan görseli + renk) için tek
/// doğruluk kaynağı.
///
/// Renkler daha önce `AppTheme.categoryGradient(index)` ile **sıraya** göre
/// veriliyordu: kategori listesi `widget.index`, alt kategori/quiz ekranları
/// ise `repository.categories.indexOf(...)` kullanıyordu. İki sıralama
/// örtüşmediği için aynı kategori ekrandan ekrana renk değiştiriyordu —
/// Muzîk listede hardal, detayda bordo; Dîrok listede bordo, düelloda
/// lacivert (2026-07-22 canlı UX denetimi). Artık renk kategorinin *adına*
/// bağlıdır ve her yüzeyde aynıdır.
class CategoryVisuals {
  const CategoryVisuals._();

  /// Türkçe çeviri veya alternatif gösterim etiketlerini ana kategori kimliğine eşler.
  static const Map<String, String> _aliases = {
    'Dil': 'Ziman',
    'Kültür': 'Çand',
    'Tarih': 'Dîrok',
    'Wêje': 'Edebiyat',
    'Coğrafya': 'Cografya',
    'Erdnîgarî': 'Cografya',
    'Müzik': 'Muzîk',
    'Paradîgma': 'Paradigma',
    'Teknoloji': 'Teknolojî',
    'Sinema': 'Sînema',
    'Film': 'Sînema',
  };

  /// Tanınan takma adlar. Bekçiler bu listeyi kendi kopyasından değil
  /// kaynağın kendisinden okur; yoksa yeni bir takma ad eklendiğinde ölçüm
  /// onu hiç görmez.
  static Iterable<String> get knownAliases => _aliases.keys;

  static String _resolveKey(String category) {
    if (SahneCategoryTone.byCategory.containsKey(category)) return category;
    return _aliases[category] ?? category;
  }

  /// Kategori adını canonical (ana) kategori kimliğine eşler.
  static String canonicalName(String category) => _resolveKey(category);

  /// Kategori renkleri artık YALNIZ Şahnê'den gelir ([SahneCategoryTone]).
  ///
  /// 2026-09-29 doğallık (K1): burada Şahnê'den bağımsız bir renk tablosu
  /// vardı ("Rengîn Editorial Arena", 2026-08-03: altı hue ailesi, doygun
  /// dolgu). Şahnê'ye geçişte kategori renkleri palet dışı kalmıştı; iki
  /// tablo yan yana durdukça aynı kategori iki renk taşıyabilirdi. Tek
  /// kaynak `theme/sahne.dart`; bu sınıf yalnız adı kanonik kimliğe çevirir.
  /// Tanımlı kategoriler — yeni bir kategori [SahneCategoryTone.byCategory]
  /// tablosuna eklenir; eklenmezse sahne gecesi tonuna düşer.
  static Iterable<String> get colorDefinedCategories =>
      SahneCategoryTone.byCategory.keys;

  /// Kategorinin Şahnê tonu: çizimsiz karonun zemini ve ayrıntısı.
  static SahneCategoryTone tone(String category) =>
      SahneCategoryTone.of(_resolveKey(category));

  /// Kategorinin renk çifti: düz zemin ve bir basamak koyusu (adına göre,
  /// sıradan bağımsız).
  static List<Color> gradientColors(String category) {
    final t = tone(category);
    return [t.ground, t.deep];
  }

  /// Kategorinin baskın rengi (düz zemin).
  static Color color(String category) => tone(category).ground;

  /// Kategorinin zemin gradyanı (zemin → koyusu).
  static LinearGradient gradient(String category) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: gradientColors(category),
  );

  static const Map<String, IconData> _icons = {
    'Ziman': AppIcons.language,
    'Çand': AppIcons.peopleGroup,
    'Dîrok': AppIcons.buildingColumns,
    'Edebiyat': AppIcons.bookOpen,
    'Cografya': AppIcons.globe,
    'Muzîk': AppIcons.music,
    // Onay kutusu siyasetle ilgisiz bir metafordu (2026-07-22 UX denetimi);
    // terazi hem siyaset hem hukuk/yönetişim için okunur bir simge.
    'Siyaset': AppIcons.scaleBalanced,
    'Paradigma': AppIcons.brain,
    'Teknolojî': AppIcons.mobileScreen,
    'Sînema': AppIcons.clapperboard,
  };

  static const Map<String, String> _imagePaths = {
    'Ziman': 'assets/question_images/cat_ziman.webp',
    'Çand': 'assets/question_images/cat_cand.webp',
    'Dîrok': 'assets/question_images/cat_dirok.webp',
    'Edebiyat': 'assets/question_images/cat_edebiyat.webp',
    'Cografya': 'assets/question_images/cat_cografya.webp',
    'Muzîk': 'assets/question_images/cat_muzik.webp',
    'Siyaset': 'assets/question_images/cat_siyaset.webp',
    'Paradigma': 'assets/question_images/cat_paradigma.webp',
    // Henüz ayrı teknoloji görseli yok; mevcut soyut paradigma görseli
    // kategori kartında güvenli geçici kaynak olarak kullanılır.
    'Teknolojî': 'assets/question_images/cat_paradigma.webp',
    // Sînema için henüz ayrı görsel yok; kültür görseli geçici kaynaktır.
    'Sînema': 'assets/question_images/cat_cand.webp',
  };

  /// Konunun görsel dili: ana sayfa karosundaki K3 silüeti ve alt konu
  /// bandındaki K1 kilim motifi TEK yerden eşlenir (2026-09-30 kimlik).
  ///
  /// Görünür her konunun kendi işareti var. Siyaset, Paradigma ve Teknolojî
  /// önce işaretsizdi ve yan yana yedi silüetin yanında tek başına eski ikon
  /// + eğik köşe hâline düşüyordu; 2026-09-30'da dördüncü ailesi geldi.
  /// 'Cîhan' (dünya sineması, coğrafyası, edebiyatı: Kürde özgü olmayan genel
  /// kültür) henüz kategori değil; ad tabloya şimdiden yazıldı ki eklendiği
  /// gün silüetsiz kalmasın. Bilinmeyen kategori `null` döner ve çağıran eski
  /// ikon + ton hâline düşer (silüet uydurulmaz).
  static const Map<String, SahneTopicMark> _marks = {
    'Ziman': SahneTopicMark.ziman,
    'Çand': SahneTopicMark.cand,
    'Dîrok': SahneTopicMark.dirok,
    'Edebiyat': SahneTopicMark.edebiyat,
    'Cografya': SahneTopicMark.cografya,
    'Muzîk': SahneTopicMark.muzik,
    'Sînema': SahneTopicMark.sinema,
    'Siyaset': SahneTopicMark.siyaset,
    'Paradigma': SahneTopicMark.paradigma,
    'Teknolojî': SahneTopicMark.teknoloji,
    'Cîhan': SahneTopicMark.cihan,
  };

  /// İşareti (silüet + motif) olan kategoriler, kanonik kimlikle.
  static Iterable<String> get markedCategories => _marks.keys;

  static SahneTopicMark? mark(String category) => _marks[_resolveKey(category)];

  static IconData icon(String category) {
    final key = _resolveKey(category);
    return _icons[key] ?? AppIcons.tableCells;
  }

  static String imagePath(String category) {
    final key = _resolveKey(category);
    return _imagePaths[key] ?? 'assets/question_images/cat_ziman.webp';
  }

  /// Kendi kimlik fotoğrafı olan kategoriler.
  ///
  /// `_imagePaths` içinde Sînema ve Teknolojî BAŞKA bir kategorinin
  /// görselini ödünç alır (Sînema, Çand'ın çay/kilim fotoğrafını gösterir —
  /// henüz kendi görseli çekilmedi). Bir kimlik karosunda ödünç görsel
  /// yanlış konuyu anlatır; "modern" görünmek için yanlış bilgi vermek
  /// takas değildir. O iki kategori bu yüzden fotoğraf yerine kendi
  /// ikonunu büyük çizer (2026-09-27: sahibi renkli ve modern görünüm
  /// istedi, ama karo kimliği ödünç görsele feda edilmez).
  ///
  /// 2026-09-29 doğallık (K1): Ziman, Siyaset ve Paradigma da çıktı. Üç
  /// çizim üretilmiş görsel izini en çok taşıyanlardı (soyut, konudan
  /// kopuk); o kategoriler çizimsiz karoya ([SahneCategoryTone] zemini +
  /// kendi ikonu) düşer. `cat_ziman`, `cat_siyaset`, `cat_paradigma` hiçbir
  /// yerde çizilmez.
  static const Set<String> _ownImageCategories = {
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
  };

  static bool hasOwnImage(String category) =>
      _ownImageCategories.contains(_resolveKey(category));

  /// Kategorinin KENDİ çizimi; yoksa `null` (çizimsiz karo ya da düz ton).
  ///
  /// [imagePath] her kategoriye bir yol döndürür (ödünç ya da kaldırılmış
  /// çizim dahil); çizimi yalnız bu yolla almak, K1'de çıkarılan
  /// çizimlerin (`cat_ziman`, `cat_siyaset`, `cat_paradigma`) bir ekranda
  /// yeniden belirmesini önler.
  static String? ownImagePath(String category) =>
      hasOwnImage(category) ? imagePath(category) : null;
}
