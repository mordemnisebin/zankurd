/// Yayına hazır olmayan kategorilerin uygulama içi gizleme listesi.
///
/// Canlıya veri yazılmaz (migration/flag yok): içerik hazır olana kadar
/// kategori, kategori listelerinde gösterilmez ve soruları oynanabilir
/// sayılmaz. Geri açmak için id'yi listeden kaldırmak yeterli.
///
/// Bağlam: 2026-07-19 canlı denetimde Teknolojî kategorisinin 23 sorusunun
/// Türkçe meta/test içeriği taşıdığı saptandı ve kategori "içerik yayına
/// hazır olana dek" gizlendi.
///
/// 2026-07-26: koşul karşılandı, kategori açıldı. Kusurlu sorular ayıklandı
/// (23 → 12), kalan 12'si tek tek denetlendi ve 28 yeni soru yazıldı; toplam
/// 40, her zorluk gözünde bir tur dolduracak kadar. Sorular yalnız teknoloji
/// kavramını değil o kavramın Kurmancî karşılığını da öğretiyor — uygulamanın
/// öğrenme amacına uygun.
///
/// 2026-07-30: Sînema gizlendi. Ham sayısı 51'di ama bunun 21'i topluluk
/// bankasından geliyordu ve kaynaklandırılmamıştı; sayılabilir taban 30
/// editoryal soruydu, yani 40'ın altı.
///
/// 2026-07-30 (aynı gün, sonra): koşul karşılandı, kategori açıldı. Kurdî
/// sinemanın beş ayrı damarından (Yılmaz Güney öncesi/sonrası, Bahman
/// Ghobadi, kadın yönetmenler, festival dolaşımı, dublaj-altyazı pratiği)
/// 20 kaynaklı soru yazıldı; her biri iki bağımsız doğrulama merceğinden
/// geçti. Sayılabilir taban 30 → 50, ham 51 → 71.
///
/// Liste artık boş. Mekanizma yerinde duruyor: bir sonraki hazır olmayan
/// kategori için id'yi eklemek yeterli.
library;

const Set<String> hiddenCategoryIds = <String>{};

/// Kategori listede/quiz seçiminde gösterilebilir mi?
bool isCategoryVisible(String categoryId) =>
    !hiddenCategoryIds.contains(categoryId);

/// Görünür kategorileri filtreler (liste sırasını korur).
List<String> visibleCategories(Iterable<String> categories) =>
    categories.where(isCategoryVisible).toList(growable: false);
