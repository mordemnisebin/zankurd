# ZanKurd ürün geliştirme planı

Amaç: 5 Eylül ürün değerlendirmesindeki önerileri küçük, doğrulanabilir adımlarla uygulamak.
Yetki: Kullanıcı tüm önerilerin uygulanmasını ve soru sorulmadan karar verilmesini istedi.
Çalışma: Mevcut dosyaların başlangıç kopyası /tmp/zankurd-product-before altında. Git/GitHub kullanılmaz. Üretim verisi, sırlar, mağaza ve dağıtım değiştirilmez. Kurmancî metinler iki dilli ve karakterleri korunarak geliştirilir.

## İşler ve kabul ölçütleri
- [ ] Öğrenme niyeti: kalıcı dil/kültür hedefi; ana ekran önerisi tercihe uyar; eski kullanıcının ilerlemesi korunur; ayarlardan değişir.
- [ ] Öğrenme sonucu: doğru/yanlış konulara dayalı somut özet ve sonraki çalışma/tekrar; online sonuç protokolü korunur.
- [ ] İçerik derinliği: günlük yaşam hikâyeleri ve mini rehberlerle birbirine bağlı öğrenme; mevcut hikâye ilerlemesi korunur.
- [ ] Kalite izlenebilirliği: yüklenen bankalar için inceleme/kaynak/görsel/ses eksiklerini kayıt bazında rapor; metadata otomatik onaylanmaz; yapısal ve editoryal doğruluk ayrılır.
- [ ] Ses doğruluğu: Kurmancî metin için Soranî/Türkçe yanlış ses seçimini önle; mevcut destek yok durumunu kullanıcıya doğru aktar; gerçek konuşur kaydı olmadan doğrulanmış ses iddiası üretme.
- [ ] Tasarım: mevcut yeşil/krem/turuncu kimliği korunur; öğrenme içeriklerinde okunabilirlik ve ikincil eylemlerin ağırlığı iyileştirilir; mobil/tablet/web ve iki tema kontrol edilir.
- [ ] Erişilebilirlik: görsel soruların betimleme kapsamını artır; görmeden betimleme üretme; büyük yazı ve düğme erişimi doğrula.
- [ ] Sosyal: eşleşme bekleme/terk ölçümü; mevcut bot açıklığı korunur; asenkron meydan okuma ihtiyacı veri olmadan canlı şema değişimine dönüşmez.
- [ ] Premium: mevcut faydalarla doğru vaat; geliştirilmeyen özellik satılmaz; satın alma ve restore testleri.
- [ ] Operasyon: banka yükleme hatalarını görünür raporla; etkinlik ölçümü kişisel veri taşımaz.
- [ ] Doğrulama: dart format, dart analyze, ilgili testler ardından tam test, güncel ekran üretimi, uygun build/runtime.

## Kararlar
- Yeni bilgi/telaffuz insan tarafından doğrulanmış gibi işaretlenmeyecek; gerçek kayıt ve insan editör onayı dış bağımlılık olarak açık kalır.
- Mevcut çalışma korunur, Git yasağı nedeniyle worktree/commit kullanılmaz; dosya kopyaları üzerinden inceleme yapılır.
- Beceri iş akışına göre sınırlı alt işler bağımsız ajanlara verilir; tarayıcı kontrolünü ana ajan yapar.

## Kanıt ve ilerleme
- Başlangıç: önceki tur dart analyze temiz, seçili 69 test başarılı. Yeni değişiklikler için yeniden çalıştırılacak.
