# ZanKurd beta / mağaza öncesi kontrol listesi

Bu liste kod testlerinin yerine geçmez; gerçek cihazda, temiz kurulumla
uygulanacak son kabul kapısıdır. Her madde iki platformda da sonucu ve tarihi
ile işaretlenmelidir.

## Derleme ve yapılandırma

- [ ] Android release derlemesi gerçek `SUPABASE_URL` ve publishable key ile
  açılıyor; demo/veri varsayılanı kullanılmıyor.
- [ ] iOS release derlemesi gerçek Supabase yapılandırmasıyla açılıyor.
- [ ] Android ve iOS RevenueCat ürünleri test satın alımıyla geri yükleniyor.
- [ ] Gizlilik politikası, kullanım koşulları ve destek adresi internette
  erişilebilir.
- [ ] Deep link ile e-posta/Google/Apple oturum dönüşü doğru uygulamaya geliyor.

## Temiz kullanıcı ilk üç dakikası

- [ ] Android ve iOS'ta uygulama verisi temizleniyor; onboarding iki dilde
  taşma olmadan tamamlanıyor.
- [ ] Misafir girişinden sonra oyuncu adı isteniyor ve ana ekrana dönülüyor.
- [ ] İlk ana ekran eylemi “Küçük başlangıç” olarak 5 soruluk, yaklaşık 3
  dakikalık tur açıyor.
- [ ] İlk tur sonucu XP, seri, görev, rozet ve açıklamalar doğru görünüyor.
- [ ] İkinci girişte günlük ders yeniden 10 soruya dönüyor.

## Öğrenme ve içerik

- [ ] Kategoriler → alt kategori → seviye → quiz akışında geri dönüşler doğru.
- [ ] Kurmancî ve Türkçe metinlerde eksik karakter, yanlış çeviri ve kırpılma
  yok.
- [ ] Görselli sorularda görsel yüklenemezse soru akışı kilitlenmiyor.
- [ ] Hatalı soruyu bildirme eylemi görünür ve kullanıcıya sonucu anlatıyor.
- [ ] Gizli, inceleme bekleyen veya oynanamaz sorular oyuna girmiyor.

## 1v1 ve oda kurma

- [ ] Hızlı düelloda gerçek rakip, bot yedeği ve iptal akışları çalışıyor.
- [ ] 1v1'de hazır kapısı, soru ilerlemesi, son soru ve sonuç ekranı iki cihazda
  aynı kalıyor.
- [ ] Oda kurma, oda koduyla katılma, oda sahibi ayarları ve başlatma çalışıyor.
- [ ] Ağ kopup geldiğinde bağlantı durumu görünür; polling/realtime yedeğiyle
  ekran kilitlenmiyor.
- [ ] Oda sohbeti yalnız üyeler arasında çalışıyor; kötüye kullanım bildirimi
  ayarlardan erişilebilir.

## Hesap, gizlilik ve bildirim

- [ ] Analitik izni kapalıyken olay gönderilmiyor; açılınca yalnız anonim akış
  olayları ölçülüyor.
- [ ] Günlük bildirim izni reddedildiğinde kullanıcıya açıklama gösteriliyor;
  hatırlatıcı kapatılınca planlanmış bildirim iptal oluyor.
- [ ] Hesap silme onay, hata ve başarılı çıkış senaryoları çalışıyor.
- [ ] Android yedekleme/cihaz aktarımı hesap ilerlemesini yanlış hesaba
  taşımıyor.

## Profil, mağaza ve paylaşım

- [ ] Profil fotoğrafı, avatar çerçevesi, unvan ve liderlik tablosu doğru.
- [ ] Mağazadaki ürünler yalnız kozmetik veya ek oyun içi kolaylık; doğru
  cevabı satın aldıran/pay-to-win ürün yok.
- [ ] Satın alma başarısız, iptal, tekrar açılış ve geri yükleme durumları
  kullanıcıya anlaşılır görünür.
- [ ] Beta geri bildirimi satırı doğru e-posta uygulamasını açıyor.

## Son doğrulama

- [ ] `dart analyze` temiz.
- [ ] Tüm Flutter testleri temiz.
- [ ] Android debug/release benzeri derleme temiz.
- [ ] iOS simulator derlemesi temiz.
- [ ] Android fiziksel cihaz ve iOS fiziksel cihazda son smoke turu yapıldı.
- [ ] Mağaza ekran görüntüleri gerçek son arayüzden alındı; test kullanıcıları,
  debug metinleri ve gizli anahtarlar pakette yok.
