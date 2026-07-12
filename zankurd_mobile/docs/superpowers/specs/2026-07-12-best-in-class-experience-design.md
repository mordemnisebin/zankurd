# ZanKurd En İyi Sınıf Deneyim Tasarımı

## Hedef

ZanKurd'u yönlendirilmiş öğrenme, canlı oyun ve Kürt kültürel kimliğini tek sade ürün mimarisinde birleştiren bir uygulamaya dönüştürmek.

## Bilgi mimarisi

Alt navigasyon `Sereke · Fêr Bibe · Bilîze · Civak · Profîl` olur. Kategoriler öğrenmenin içine, liderlik ve arkadaşlar Civak içine, bütün rekabetçi modlar Bilîze içine taşınır. Mevcut ekranlar kaldırılmaz; yeni merkezlerden açılır.

## Öğrenme yolu

Her ders kategorisi yatay sekmeyle seçilir ve dersler dikey yol üzerinde sıralanır. Tamamlanan düğüm yeşil, sıradaki düğüm turuncu, kilitli düğüm soluk görünür. Yolun sonunda kategori mastery hedefi bulunur.

## Quiz deneyimleri

`learning` deneyimi zamanlayıcı, skor ve joker baskısı olmadan açıklamayı öne çıkarır. `competition` deneyimi zamanlayıcı, skor, seri ve jokerleri korur. Derslerden açılan quizler öğrenme deneyimini; günlük yarışma, 1vs1 ve turnuvalar rekabet deneyimini kullanır.

## Günlük odak

Sereke'nin ilk içerik kartı Zana'nın tek günlük hedefidir. Hedef bir mini ders veya en az üç doğru cevap gibi öğrenme kalitesine bağlıdır; kart doğrudan ilgili öğrenme yolunu açar.

## Civak ve ligler

Civak ekranı `Ligler` ve `Heval` bölümlerini bir araya getirir. Ligler kategori filtresi sunar; rekabet istemeyen kullanıcı için profil ayarındaki görünürlük tercihi korunur.

## Görsel sistem

Turuncu yalnız ana eylem, altın ödül/mastery, kategori renkleri yalnız kategori bağlamında kullanılır. Başlık, boşluk ve radius tokenları mevcut `AppTheme` sisteminden gelir. Zana yalnız günlük hedef, açıklama ve ödül anlarında görünür.

## Başarı koşulları

- Beş yeni navigasyon etiketi telefon ve tablette taşmaz.
- Öğrenme yolu tamamlanma/kilit durumunu doğru gösterir.
- Öğrenme quizinde baskı elemanları görünmez; yarışmada görünür.
- Bilîze ve Civak mevcut özelliklere ulaşır.
- `dart analyze`, tam test paketi ve web ekran kontrolü temiz geçer.
