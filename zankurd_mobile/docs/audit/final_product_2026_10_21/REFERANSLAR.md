# Ürün karşılaştırması — 21 Ekim 2026

Kaynaklar güncel resmî web sayfalarından okundu. Bu bir rakip uygulama hesabında uçtan uca kullanım testi değildir. Reklamdaki başarı iddiaları bağımsız etkililik kanıtı sayılmadı. Özetler Claude ve Gemini'ye gerçek ZanKurd kaynaklarıyla verildi; danışmanların web taradığı iddia edilmedi.

| Referans | Yapı ve yoğunluk | Etkileşim / ton | ZanKurd kararı |
|---|---|---|---|
| [Duolingo Practice](https://blog.duolingo.com/guide-to-duolingo-practice-hub/) | Yanlışlar, kelimeler, konuşma, dinleme ayrı hedefler; başlıklar kısa | Kullanıcı tekrar becerisini seçer; teşvik edici anlatım | Ders yolu ve tekrar zaten var. Tekrar girişini güvenilir kıl; yinelenen oturum ve bayat sayacı düzelt |
| [Busuu aralıklı tekrar](https://www.busuu.com/en/languages/spaced-repetition) | Konu başlıkları altında açıklama ve örnek tekrar aralıkları; daha metin yoğun | Zorluk ve hatırlamaya göre uyarlanan tekrar anlatılır; öğretici ton | Mevcut SM-2 ve 12 soruluk sınırı koru; yeni bir algoritma eklemeye gerek yok |
| [Drops](https://www.languagedrops.com/) | Kısa günlük ders vaadi; görsel sözcük ilişkilendirmesi ve konu grupları | Düşük başlama eşiği; daha oyuncu ve görsel anlatım | Mevcut kısa oturum ve sözlük/dinleme araçlarını koru; marka görsellerini veya ücret kurgusunu kopyalama |

Tipografi için yalnız resmî sayfalardaki başlık/gövde hiyerarşisi gözlendi; font ailesi ve uygulama içi piksel ölçüleri ölçülmedi. ZanKurd'un mevcut Şahnê tipografisi ve yeşil/antrasit/krem kimliği korunuyor. Bu tur yeni görsel sistem veya rakip ekran kopyası üretmiyor.

## Seçilen uygulama ilkeleri

- Başlamak kolay olmalı; hızlı çift dokunuş kullanıcıyı iki oturuma götürmemeli.
- Hata ile gerçek boş içerik ayrı gösterilmeli ve hata yeniden denenebilmeli.
- Tamamlandığı söylenen ders bağlantı gelince güvenilir şekilde eşitlenmeli.
- Zaten var olan sözlük, ders yolu, dinleme, kısa tekrar ve yerleştirme yeniden üretilmemeli.

## Orkestra kanıtı

- or-code: bir ücretsiz çağrı, 60 sn zaman aşımı; karar üretmedi.
- Claude + agy-gemini4: iki paralel abonelik/kota çağrısı, ikisi tamamlandı; tekrar kartındaki çift başlatma ve bayat sayaç sorunu üzerinde uzlaştı. Kaynak ve testle ayrıca doğrulandı.
- or-lightning: dar kod kontrolü, çıktı sınırında eksik yanıt; karar olarak kullanılmadı.
- Yeni ücretli API veya hesap açılmadı. Ücretsiz kanalın bu görevde güvenilir son yanıt üretememesi raporlandı; otomatik sınırsız yeniden deneme yapılmadı.

Tam danışman kayıtları aynı klasördeki orkestra-*.json dosyalarında; token/gizli anahtar kopyalanmadı.

Son bağımsız Orkestra denetimi (Claude, bir çağrı): açık izinlistesi ve parity testlerinde P1/P2 bulgu yok. Mock'ta ayrı UUID kullanma P3 önerisi şu turda eklenmedi; mevcut testler beklenen slug lookup dizisini zaten ayrı sabitliyor. Kaynak sınırlı review, canlı veri kanıtı değildir.
