/// Yayına hazır olmayan kategorilerin uygulama içi gizleme listesi.
///
/// Canlıya veri yazılmaz (migration/flag yok): içerik hazır olana kadar
/// kategori, kategori listelerinde gösterilmez ve soruları oynanabilir
/// sayılmaz. Geri açmak için id'yi listeden kaldırmak yeterli.
///
/// Bağlam: 2026-07-19 canlı denetimde Teknolojî kategorisinin 23 sorusunun
/// Türkçe meta/test içeriği taşıdığı saptandı; içerik yayına hazır olana
/// dek gizli kalır.
library;

const Set<String> hiddenCategoryIds = {'Teknolojî'};

/// Kategori listede/quiz seçiminde gösterilebilir mi?
bool isCategoryVisible(String categoryId) =>
    !hiddenCategoryIds.contains(categoryId);

/// Görünür kategorileri filtreler (liste sırasını korur).
List<String> visibleCategories(Iterable<String> categories) =>
    categories.where(isCategoryVisible).toList(growable: false);
