# ZanKurd geliştirme notları

Bu değişiklik, mevcut React/Vite web uygulamasını bozmadan quiz akışını daha kullanılabilir hale getirir.

## Yapılanlar

- Soru modeline `difficulty` ve `tags` alanları eklendi.
- Kategori listesi sabit dizi yerine soru verisinden türetilir hale getirildi.
- Kategori butonları artık aktif filtre olarak çalışıyor.
- Soru numarası artık sabit `08` yerine gerçek ilerlemeyi gösteriyor.
- Oda kodu kopyalama butonuna gerçek `navigator.clipboard` davranışı eklendi.
- Cevap sonrası doğru/yanlış geri bildirimi daha açıklayıcı hale getirildi.
- Sağ paneldeki başarı metriği sabit sayı yerine oyuncu serilerinden hesaplanan bir değere bağlandı.

## Neden önemli?

ZanKurd soru bankası büyüdükçe kategori, zorluk ve etiket alanları uygulamanın temel navigasyon noktası olacak. Bu PR, ileride Supabase veya CSV içe aktarma geldiğinde aynı verinin filtrelenebilir ve ölçülebilir şekilde kullanılmasına zemin hazırlar.

## Sonraki mantıklı adımlar

1. `questions` dizisini ayrı bir veri dosyasına taşı.
2. CSV soru bankasını `Question` tipine dönüştüren küçük bir import scripti ekle.
3. Supabase `questions` tablosunu bağla.
4. Yanlış yapılan sorular ve favoriler için kullanıcı ilerleme tablosu ekle.
5. Oda kurma, kodla katılma ve rastgele eşleşme butonlarını gerçek route/state akışına bağla.
