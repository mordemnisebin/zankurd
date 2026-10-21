# Başlangıç dersleri tamamlama eşdeğerliği — 21 Ekim 2026

Bu inceleme salt kaynak karşılaştırmasıdır. Canlı ders tanımları okunmadı; seed dosyası canlı verinin birebir kanıtı değildir. Üretim kodu, ders metinleri, soru bankası, migration ve sürüm değiştirilmedi; Dart/Flutter testleri çalıştırılmadı.

## İki başlangıç dersi

Kaynaklar: `lib/src/data/mock_zankurd_repository.dart:2600-2691`, `supabase/2026-10-06_baslangic_lessons.sql:57-75`. Python ile yerel Dart slaytları ve SQL değerleri ayrıştırıldı; her slaytın `order`, `ku`, `tr`, `example` alanı karşılaştırıldı. Tam değişmeyen ve değişen değerler `starting_lesson_field_comparison.json` içindedir.

| Yerel → SQL | Slayt | Aynı alan | Fark |
| --- | ---: | ---: | --- |
| `greetings_2` → `silav-u-rezdari` | 4 | 15/16 | Yalnız 3. slayt `ku`: yerel başlıkta `gotin` ve ek `Gotin: Söylemek` öğretimi var. SQL'in teşekkür/özür kapsamının tamamı yerelde korunuyor. |
| `intro_1` → `xwe-nasandin` | 5 | 19/20 | Yalnız 3. slayt `tr`: SQL sonu `Stenbolê..`, yerel sonu `Stenbolê.`. Anlamsal kapsam aynı. |

Her iki derste slayt sayısı ve bütün sıralar aynıdır. Yukarıdaki iki alan dışındaki tüm Kurmancî/Türkçe metin ve örnekler birebir aynıdır. `greetings_2` yerelde daha geniştir; `intro_1` yerelde noktalama hatasını giderir.

## En küçük yerel uzlaştırma

Mevcut ders metinleri korunmalı: `Gotin` öğretimi silinmemeli, çift nokta yerel metne taşınmamalı. Genel noktalama normalizer'ı, fuzzy eşleme veya soru bankası aliasından otomatik tamamlama türetme eklenmemeli.

İki dersin tamamlamasını açmanın sınırlı yolu: yalnız yukarıdaki iki **tam literal SQL/yerel alan çifti** testte açık istisna olarak sabitlenir. Ders/slayt/alan kimliği ve her iki beklenen metin ayrı ayrı doğrulanır; bu iki alanda dahi başka değişiklik kabul edilmez. Kalan 34 alan birebir karşılaştırılır. Ardından iki yerel kimlik açık tamamlama izinlistesine alınır. İzinlistesi açıklaması 16 birebir ders + 2 denetlenmiş kapsam eşdeğerliği şeklinde dürüstçe güncellenir. Bu, root'un onayladığı ders bazlı politika kararıdır; henüz uygulanmadı.

## Eski ve birleşik derslerin politikası

Kaynak: `supabase/2026-07-06_lesson_seed.sql` ile yerel aynı adlı bankaların gerçek slaytları.

| Yerel → konu eşlemesi | Eksik/farklı kapsam | Tamamlama |
| --- | --- | --- |
| `grammar_1` → `cinavk` | Yerel 2 slayt yalın tekil/çoğul; SQL 4 slaytta ayrıca bükümlü tekil/çoğul ve kullanım örnekleri var. | Alias eklenmez. |
| `culture_2` → `newroz` | Yerel Newroz özeti + dinî bayramlar; SQL Newroz günü, ateş sembolü, govend/stran ve örneklerini işler. | Alias eklenmez. |
| `geography_1` → `ciya-u-cem` | Yerel dağ/nehir adları; SQL ayrıca Wan Gölü, Şingal, yükseklik ve cümle örnekleri işler. | Alias eklenmez. |
| `everyday_1` + `everyday_2` → `silav-u-nasin` | İki yerel dersi bitirmek dahi SQL vedalaşma slaytı ve örneklerinin tamamını kapsamaz. | Tek ders veya AND tamamlaması eklenmez. |
| `emotions_1` + `emotions_2` → `hesten-bingehin` | Yerelde olumlu/olumsuz/sosyal kavramlar; SQL fiziksel durumlar (yorgun, aç, tok), sevgi ve örnekler içerir. | Tek ders veya AND tamamlaması eklenmez. |

Bu derslerin konu bazlı quiz/sözlük eşlemesi ayrı amaçla kalabilir. Yerel ilerleme korunur; yalnız gerçek sunucu UUID/slug'ı veya denetlenmiş izinlistesi sunucuda tamamlanma oluşturur. Bu inceleme diğer tekli eski bankalara otomatik onay vermez.

## Önerilen test planı

1. Önce mevcut iki dışlama testinin korunmuş kaynaklarda neyi beklediğini kaydet; uygulamadan sonra iki ders için exact alias lookup ve doğru UUID/RPC beklentisine çevir.
2. SQL/yerel slayt paritesi testine iki dersi ekle: 4 ve 5 slayt, bütün alanlar; yalnız iki açık literal çiftine kontrollü izin. SQL veya yerel istisna metni değişirse test kırılmalı.
3. `grammar_1`, `culture_2`, `geography_1` ve birleşik kimliklerde doğrudan lookup dışında alias/RPC yapılmadığını koru.
4. Bir yeni ders için çevrimdışı tamamlama kuyruğu → bağlantı → doğru UUID → bekleyen kaydın düşmesi senaryosunu hedef testle doğrula. Yerel ilerleme korunmalı.
5. Değişiklikten sonra önce `dart analyze`; ardından yalnız ilgili alias/quiz/progress testleri. Tam paket ve UI doğrulaması kök görevin ortak kapısında yürütülsün. Bu rapor için test çalıştırılmadı.
