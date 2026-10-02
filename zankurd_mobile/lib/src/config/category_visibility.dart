/// Yayına hazır olmayan kategorilerin uygulama içi gizleme listesi.
///
/// Canlıya veri yazılmaz (migration/flag yok): içerik hazır olana kadar
/// kategori, kategori listelerinde gösterilmez ve soruları oynanabilir
/// sayılmaz. Geri açmak için id'yi listeden kaldırmak yeterli.
///
/// Geçmiş (kısa):
/// - 2026-07-19: Teknolojî, Türkçe meta/test içeriği taşıyan sorular yüzünden
///   gizlendi; 2026-07-26'da kusurlu sorular ayıklanıp 28 yeni soru yazılınca
///   açıldı.
/// - 2026-07-30: Sînema, kaynaksız topluluk soruları yüzünden sayılabilir
///   tabanı 40'ın altında kaldığı için gizlendi; aynı gün 20 kaynaklı soru
///   yazılınca açıldı.
/// - 2026-09-27: Paradigma ve Siyaset (sorular bilgi değil, tek bir siyasi
///   hareketin öğretisini "doğru cevap" olarak sunuyordu; Türkiye pazarında
///   hukuki/erişim riski; kalıpla üretilmiş D/Y maddeleri) ile Teknolojî
///   (217 sorunun 198'i Kürtlerle bağı olmayan genel bilgi) gizlendi.
///
/// 2026-09-30: ürün sahibi üçünü de yeniden açtı ve tam uygulamanın
/// yayınlanmasına karar verdi. Gerekçelerin çözümü artık kategori bazında
/// değil SORU bazında: tartışmalı bir siyasi görüşü doğru şık diye sunan
/// sorular `retired_question_ids.dart` ile tek tek emekliye ayrılır (sunucuda
/// bir göçle eşlenir). Teknolojî'nin genel bilgi soruları tutuldu, çünkü
/// bunlar tarafsız bilgidir; ideolojik bir yük taşımazlar. Kürt siyasi TARİHİ
/// (olaylar, kişiler, tarihler) zaten Dîrok'ta duruyor.
///
/// Liste boş. Mekanizma yerinde duruyor: bir sonraki hazır olmayan kategori
/// için id'yi eklemek yeterli.
library;

const Set<String> hiddenCategoryIds = <String>{};

/// Kategori listede/quiz seçiminde gösterilebilir mi?
bool isCategoryVisible(String categoryId) =>
    !hiddenCategoryIds.contains(categoryId);

/// Görünür kategorileri filtreler (liste sırasını korur).
List<String> visibleCategories(Iterable<String> categories) =>
    categories.where(isCategoryVisible).toList(growable: false);
