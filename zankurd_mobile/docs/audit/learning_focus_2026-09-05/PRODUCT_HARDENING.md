# Ürün denetimi uygulama kaydı

Son güncelleme: 6 Eylül 2026.

## Kapatılan ürün bulguları

- Günlük ders, seçilmiş öğrenme amacına göre soru havuzunu öne alıyor. Onaylı kayıtlar yeterliyse metadata'sız kayıtlar öğrenme turuna alınmıyor; havuz yetersizse tur boş kalmıyor.
- `MasteryStore`, doğru cevap ilerlemesini cevaplanan soru ve doğruluk kanıtından ayrı saklıyor. Profil, eski kayıtlarda doğruluk yüzdesi uydurmuyor.
- Öğrenme sonucu artık yarış tamamlandı başlığını kullanmıyor. Cevap ekranında açıklama otomatik olarak açılmadan tek dokunuşla okunabiliyor.
- Eşleşme ölçümü gerçek insan, bot ve iptal sonlanmalarına bağlandı. Olay yalnız `outcome` ve `wait_seconds` taşır.
- Analitik başlatma varsayılan olarak kapalı. Firebase yalnız açık kullanıcı rızasıyla etkinleşiyor; premium ve eşleşme hunileri kişisel veri göndermiyor.
- TTS desteği olmayan cihazda ses düğmesi ve etkisiz ayarlar kapalı görünür; Soranî/Türkçe ses Kurmancî olarak kullanılmaz.

## Açık editoryal borç

Kalite taraması 12 kaynakta 3.000 benzersiz kayıt buldu. Engelleyici ve kritik hata yok; yayın öncesi insan incelemesi gerektiren 1.846 uyarı var:

| Kuyruk | Adet | Yayın kararı |
|---|---:|---|
| Kaynak künyesi eksik | 1.378 | Kaynak doğrulanmadan `approved` yapılmayacak |
| Yakın kopya adayı | 468 | İnsan karşılaştırması olmadan silinmeyecek |

Bu kayıtlar `content/metadata_gaps.csv`, `content/near_duplicate_candidates.csv` ve `content/warnings.csv` içindedir. Uyarıları otomatik olarak onaylamak ürün güvenilirliğini artırmaz; bu yüzden içerik dosyalarına uydurma kaynak veya toplu silme uygulanmadı.

## Premium hipotezi

Premium şu an yalnız iki mevcut faydayı sunuyor: seri koruması ve ZanKurd'a destek. Paywall görüntülenmesi, satın alma sonucu ve geri yükleme sonucu anonim olaylarla ölçülüyor. Öğrenme içeriği veya başarı garantisi vaat edilmiyor. Yeterli gerçek kullanıcı verisi oluşmadan fiyat, fayda veya dönüşüm iddiası genişletilmeyecek.

## Doğrulama sınırı

Bu kayıt yerel mock/offline akış, analiz ve test sonuçlarını kapsar. RevenueCat canlı satın alma, gerçek cihaz TTS sesi, Supabase canlı eşleşmesi ve mağaza onayı ayrıca canlı ortamda doğrulanmalıdır.
