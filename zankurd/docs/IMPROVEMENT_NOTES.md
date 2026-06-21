# ZanKurd geliştirme notları

Bu değişiklik, mevcut React/Vite web uygulamasını bozmadan quiz akışını daha kullanılabilir, daha modern ve daha büyütülebilir hale getirir.

## Yapılanlar

- Soru modeline `difficulty`, `dialect`, `learningNote` ve `tags` alanları eklendi.
- Kategori listesi sabit dizi yerine soru verisinden türetilir hale getirildi.
- Kategori butonları artık aktif filtre olarak çalışıyor.
- Soru numarası artık sabit değer yerine gerçek ilerlemeyi gösteriyor.
- Oda kodu kopyalama butonuna gerçek `navigator.clipboard` davranışı eklendi.
- Cevap sonrası doğru/yanlış geri bildirimi daha açıklayıcı hale getirildi.
- Sağ paneldeki başarı metriği sabit sayı yerine kullanıcının cevap durumuna bağlandı.
- `App.tsx` içindeki veri ve arayüz parçaları ayrı dosyalara taşındı.
- `Topbar`, `HeroSection`, `RoomPanel`, `QuizCard`, `InsightPanel` ve `BottomNavigation` componentleri eklendi.
- Daha premium bir görsel dil için glass kartlar, yumuşak gölgeler, büyük radius, gradient arka plan ve hover animasyonları eklendi.
- Mobil deneyim için alt navigasyon, tek sütun akış ve daha büyük cevap kartları eklendi.
- Global tasarım tokenları ve sistem dark mode desteği `index.css` içine alındı.

## Neden önemli?

ZanKurd soru bankası büyüdükçe kategori, zorluk, lehçe ve etiket alanları uygulamanın temel navigasyon noktası olacak. Component ayrımı sayesinde yeni modlar, Supabase bağlantısı, admin paneli ve kullanıcı ilerleme sistemi daha az riskle eklenebilir.

## Dosya yapısı

```txt
src/
  components/
    BottomNavigation.tsx
    HeroSection.tsx
    InsightPanel.tsx
    QuizCard.tsx
    RoomPanel.tsx
    Topbar.tsx
  data/
    questions.ts
  types/
    quiz.ts
  App.tsx
  App.css
  index.css
```

## Sonraki mantıklı adımlar

1. Supabase `questions`, `profiles`, `rooms`, `scores` tablolarını bağla.
2. Admin panelden soru ekleme/düzenleme akışı oluştur.
3. Yanlış yapılan sorular ve favoriler için kullanıcı ilerleme tablosu ekle.
4. Oda kurma, kodla katılma ve rastgele eşleşme butonlarını gerçek route/state akışına bağla.
5. CSV soru bankasını `Question` tipine dönüştüren küçük bir import scripti ekle.
6. GitHub Actions ile `npm run build` ve `npm run lint` kontrolü ekle.
