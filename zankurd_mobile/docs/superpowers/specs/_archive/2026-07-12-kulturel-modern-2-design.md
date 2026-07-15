# ZanKurd Kültürel Modern 2.0 Tasarımı

> **SÜPERSEDE EDİLDİ (2026-07-12).** Görsel/renk kararları
> [2026-07-12-bubblegum-arcade-redesign-design.md](2026-07-12-bubblegum-arcade-redesign-design.md)
> ile geçersiz kılındı. Bu dosya yalnızca tarihsel referans için tutuluyor.

## Amaç

Claude artefaktındaki dört ana ekranı ve beş tasarım hamlesini mevcut Flutter uygulamasına taşımak; oyun akışlarını, erişilebilirliği ve açık tema seçeneğini korumak.

## Tasarım kararları

- İlk kurulum koyu orman temasıyla açılır; kullanıcı ayarlardan açık temaya geçebilir.
- Ana sayfa tek baskın `1vs1` eylemi, iki ikincil oda eylemi, 2x2 hızlı oyun alanı ve Zana çağrısı kullanır.
- Kilim deseni dekor olmaktan çıkar; quiz/XP ilerlemesi ve önemli kart çerçevelerinde ortak görsel dil olur.
- Kategori kartları kategori rengini, mastery unvanını ve doğru cevap sayacını birlikte gösterir.
- Quiz açıklaması `Şîrove · Zana` kimliğiyle mini ders olarak sunulur.
- Sonuç ekranı kupa, doğru/yanlış/coin metrikleri, XP ilerlemesi, Zana unvan takdimi ve birincil tekrar eylemini aynı sahnede toplar.

## Sınırlar

- Yeni paket eklenmeyecek.
- Mevcut navigasyon, oda, quiz, joker, mastery ve ödül davranışları korunacak.
- Kurmancî metinler artefakttaki karakterlerle yazılacak.
- Telefon ve tablet yerleşimleri taşma üretmeyecek.

## Doğrulama

- Widget testleri görsel sözleşmenin ana işaretlerini doğrular.
- `dart analyze` temiz geçer.
- İlgili Flutter testleri ve tam test paketi geçer.
- Web ekranı Playwright ile telefon ve tablet boyutlarında gözle kontrol edilir.
