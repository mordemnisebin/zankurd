# App Privacy reconciliation — ZanKurd iOS 1.9.2 (15)

Bu belge kaynak kod ile App Store Connect App Privacy ekranını aynı binary
üzerinde eşleştirmek içindir. Kaynak manifestteki bilgi otomatik olarak App
Store Connect'e gönderilmez; yüklemeden önce alanlar elle doğrulanmalıdır.

## Kaynakta doğrulananlar

`ios/Runner/PrivacyInfo.xcprivacy` şu veri sınıflarını içerir:

- kullanıcı kimliği, e-posta adresi ve oyuncu adı;
- oda mesajları ve soru önerileri gibi kullanıcı içeriği;
- oyun/öğrenme ilerlemesi;
- kullanıcı seçerse avatar fotoğrafı;
- ürün etkileşimi, çökme verisi ve performans verisi;
- analitik için cihaz kimliği;
- RevenueCat abonelik durumu için satın alma geçmişi.

Manifestte reklam takibi kapalıdır.

> **DÜZELTME (2026-11-04, GPT-6 Pro alan 9):** Bu belgenin önceki hâli "konum
> izni/API'si yok, bu yüzden konum veri sınıfı bulunmamalı" diyordu. Bu çıkarım
> YANLIŞTI. Kullanım analizi açıkken Firebase Analytics, olayların geldiği IP
> adresinden **yaklaşık coğrafi konum** (ülke/bölge/şehir) türetir; bunun için
> işletim sistemi konum izni gerekmez. App Privacy ve Play Data Safety
> yanıtları yalnız izinlere değil, SDK'ların topladığı veriye göre doldurulur:
> **Konum → Kaba konum (Coarse Location)** (Analytics amacıyla, kullanıcıya
> bağlı olabilir, izleme için kullanılmıyor) bu envantere dahildir. Gizlilik
> politikası (`web/privacy.html`, TR+KU) bu maddeyi "Yaklaşık konum (IP
> adresinden)" olarak açıklar. Canlı mağaza formlarının bu envanterle
> uzlaştırılması elle yapılır (aşağıdaki liste).

## App Store Connect'te yüklemeden önce

1. App Privacy cevaplarını yukarıdaki veri envanteriyle ve yayınlanacak build
   15'in binary davranışıyla karşılaştır.
2. Kaba konum (Coarse Location) işaretli OLMALI: Firebase Analytics IP'den
   yaklaşık konum türetir (yukarıdaki düzeltme). Kullanım analizi kapalı
   başladığı ve yalnız açık 13+ beyanıyla açılabildiği için "isteğe bağlı"
   notu düşülebilir; ama veri sınıfı işaretsiz bırakılmaz. Kodda olmayan bir
   veri türünü binary manifestine ekleyerek metadata uyuşmazlığını gizleme.
3. Avatar yükleme, sohbet, analitik tercihi, Crashlytics ve RevenueCat
   davranışlarının App Privacy amaçlarıyla eşleştiğini kontrol et.
4. Privacy Policy ve Account Deletion URL'lerinin erişilebilir olduğunu,
   review notes içindeki URL'lerle aynı olduğunu kontrol et.
5. App Store Connect'te yüklenen build numarasının tam olarak `15` olduğunu
   doğrulamadan incelemeye gönderme.

Bu belge bir App Store Connect hesabına yazma işlemi yapmaz; hesap erişimi ve
Apple'ın gerçek metadata ekranı görülmeden “uyumlu” sonucu varsayılmaz.
