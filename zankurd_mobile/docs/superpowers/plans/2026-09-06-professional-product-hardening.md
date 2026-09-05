# ZanKurd ürün denetimi sonrası sağlamlaştırma planı

## Amaç

Öğrenme deneyimini ölçülebilir, güvenilir ve ticari iddiaları sınırlı bir ürüne dönüştürmek. Değişiklikler küçük, geri alınabilir ve her biri test edilebilir tutulacak.

## Uygulama adımları

1. Günlük ders soru seçimini kullanıcının seçtiği öğrenme hedefine bağla; ilk oturumdaki beş soruluk giriş akışını koru.
2. Doğru cevap sayısını etkinlik kaydından ayıran cevap kanıtı sakla ve profil göstergesini bu ayrımı açıkça anlatacak şekilde güncelle.
3. Öğrenme sonuç ekranında yarış dili yerine öğrenme dili kullan; cevap açıklamasını öğrenme modunda soruya yakınlaştır ve yarış modunun yoğunluğunu koru.
4. Eşleşme bekleme/sonuç ölçümünü gerçek akışa bağla; iptal, bot ve insan eşleşmesini aynı olay sözleşmesiyle kaydet.
5. Analitik toplamayı açık rıza olmadan başlatma; premium ekranında yalnız mevcut faydaları ölç ve raporla.
6. TTS desteği olmayan cihazda durumun açıkça gösterildiğini ve içerik kalite kuyruğunun güncel bulgularla çalıştırılabildiğini doğrula.
7. Dart analizini, ilgili testleri, web derlemesini ve Playwright ile gerçek ekran akışını çalıştır; her doğrulama çıktısını denetim klasörüne yaz.

## Kabul ölçütleri

- Günlük öğrenme soruları seçilen hedefle uyumlu ve hedef verisi yoksa deterministik güvenli geri dönüş var.
- Profilde doğru cevap ilerlemesi, cevap sayısı ve doğruluk sinyali birbirine karıştırılmıyor.
- Öğrenme sonucu “pêşbirk”/“yarış” tamamlanması gibi görünmüyor; açıklama ve gözden geçirme yolu erişilebilir.
- Matchmaking ölçümü yalnızca kişisel veri içermeyen olaylarla ve tüm sonlanma yollarında çalışıyor.
- Analitik kapalı başlangıçta Firebase veya Supabase olay çağrısı yapmıyor.
- İçerik kuyruğundaki metadata ve yakın kopya bulguları yayın öncesi engel olarak görünür durumda.

## Doğrulama

Değişiklikler sonrasında `dart analyze`, ilgili Flutter testleri, web debug build ve gerçek tarayıcı akışı birlikte çalıştırılacak. Git işlemi kullanılmayacak.
