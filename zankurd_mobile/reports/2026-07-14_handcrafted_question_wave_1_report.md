# El yazımı soru paketi – Dalga 1

Bu paket 16 sorudan oluşur. Her sekiz kategoriye iki soru ayrıldı:

- Ziman, Edebiyat, Dîrok, Cografya
- Çand, Muzîk, Siyaset, Paradigma

## Editoryal kararlar

- Sorular eski 10.000'lik üretim dalgasından seçilmedi; her biri ayrı amaçla yeniden yazıldı.
- Soru kökleri tanım, kronoloji, karşılaştırma, bağlam ve uygulama biçimlerine dağıtıldı.
- Çeldiriciler aynı bilgi alanından seçildi; rastgele, alaycı veya konu dışı seçenek kullanılmadı.
- Her satırda kaynak başlığı ve doğrudan URL bulunuyor.
- Kurmancî içerikte Türkçe karakter bulaşığı için tarama yapıldı.
- Tüm sorular `PENDING_EDITORIAL_APPROVAL` durumunda; SQL dosyasında `is_approved = false`.

## Kontrol sonuçları

- Satır sayısı: 16
- Kategori dağılımı: 8 kategori × 2 soru
- Benzersiz soru kökü: 16/16
- Geçerli doğru seçenek: 16/16
- Kaynak URL'si: 16/16
- CSV örnek aralığı artifact-tool ile okundu: başarılı
- SQL satır sayısı: 16

Bu paket canlı veritabanına uygulanmadı. Önce ikinci bir insan/AI editoryal okumasından geçmesi için beklemede bırakıldı.
