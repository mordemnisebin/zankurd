# ZanKurd Soru Bankası Kalite Standardı

Bu standart, mobil uygulamadaki soru içeriklerinin güvenilirliğini ve ürün tutarlılığını korumak için kullanılır.

## 1) Zorunlu Format

Her soru için:

- `id`: benzersiz olmalı.
- `category`: tanımlı kategorilerden biri olmalı.
- `difficulty`: 1-5 aralığında olmalı.
- `prompt`: boş olmamalı, baş/son boşluk içermemeli.
- `answers`: boş şık içermemeli; şıklar aynı soru içinde tekrar etmemeli.
- `correctAnswer`: `answers` içinde bulunmalı ve baş/son boşluk içermemeli.
- `explanation`: boş olmamalı, baş/son boşluk içermemeli.

True/False sorularında:

- `answers` tam olarak `['Rast', 'Şaş']` olmalı.

## 2) İçerik Güvenilirliği

- Prompt içinde doğru cevabı açık eden ifadelerden kaçının.
- Tek doğru cevap prensibini bozacak belirsiz/yoruma açık ifadeleri revize edin.
- Aynı prompt'un çoğaltılmış kopyalarını artırmayın; benzer soru gerekiyorsa prompt ve bağlamı anlamlı biçimde farklılaştırın.

## 3) Dağılım ve Havuz Sağlığı

- Her kategori minimum soru havuzunu korumalı (testlerde alt limit kontrol edilir).
- Olgun kategoriler (tam seviye akışı taşıyanlar) 1..5 zorluk katmanlarını kapsamalı.
- Seviye bazlı quizlerde tekrar riskini azaltmak için prompt-bazlı benzersiz soru sayısı korunmalı.

## 4) Doğrulama Akışı

İçerik değişikliğinden sonra en az:

```bash
flutter test test/question_bank_test.dart
```

Geniş doğrulama için:

```bash
dart analyze
flutter test
```

## 5) Opsiyonel İçerik Metası (önerilen)

Offline bank modelini büyütmeden süreçte tutulabilecek alanlar:

- kaynak (kaynak doküman/link)
- doğrulandı mı? (evet/hayır)
- son doğrulama tarihi
- not/revizyon gerekçesi

Bu meta alanlar süreç dokümanlarında veya yönetim panelinde tutulabilir; uygulama modeline eklemek zorunlu değildir.
