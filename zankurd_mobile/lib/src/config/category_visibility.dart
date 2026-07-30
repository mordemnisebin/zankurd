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
/// 2026-07-29: Topluluk bankasındaki kaynaklandırılmamış sorular inceleme
/// kuyruğuna alınınca Sînema 40 soruluk yayın tabanının altına düştü. Kaynaklı
/// içerik tamamlanana kadar kategori kullanıcıya gösterilmez.
library;

const Set<String> hiddenCategoryIds = <String>{'Sînema'};

/// Kategori listede/quiz seçiminde gösterilebilir mi?
bool isCategoryVisible(String categoryId) =>
    !hiddenCategoryIds.contains(categoryId);

/// Görünür kategorileri filtreler (liste sırasını korur).
List<String> visibleCategories(Iterable<String> categories) =>
    categories.where(isCategoryVisible).toList(growable: false);
