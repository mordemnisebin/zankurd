# ZanKurd Soru Kalitesi Regresyon Kapısı Tasarımı — 2026-07-15

## 1. Hedefler

Bu faz, repository içindeki soru kaynaklarını değiştirmeden envanterleyen, ortak bir denetim modeline okuyan, teknik ve editoryal riskleri ölçen ve yalnız yeni kötüleşmelerde CI'ı durduran deterministik bir araç kurar. Araç fiziksel kayıt sayısını kanonik tekil kayıttan ayırır, aynı içeriğin farklı kopyalarını uzlaştırır ve manuel editoryal düzeltme dalgaları için kanıt üretir.

## 2. Kapsam dışı konular

Soru, seçenek, doğru cevap, açıklama, ID, kategori, zorluk, görsel veya production CSV/JSON/SQL/Dart kaynağı değiştirilmez. Supabase'e bağlanılmaz veya yazılmaz. Otomatik çeviri, duplicate silme, runtime model/repository/quiz davranışı, yeni paket, deploy, push ve merge bu fazın dışındadır.

## 3. Kaynak rolleri

`tool/question_quality/source_manifest.json` tek sınıflandırma kaynağıdır. Roller:

- `runtime_primary`: Gerçek runtime bankası; report ve gate kapsamındadır, en yüksek kanonik önceliktedir.
- `runtime_secondary`: Runtime'a katılan ikincil banka; report ve gate kapsamındadır, primary ile sapması ölçülür.
- `publish_candidate`: Doğrudan yayına hazırlanmış veri; report ve gate kapsamındadır.
- `import_candidate`: Aktif runtime import girdisi; report ve gate kapsamındadır.
- `historical_snapshot`: Eski SQL/veri kopyası; report kapsamındadır, gate toplamına girmez.
- `candidate_pool`: Henüz yayın kararı olmayan aday; yalnız report kapsamındadır.
- `quarantine`: Reddedilmiş veya inceleme bekleyen kayıt; yalnız report kapsamındadır.
- `test_fixture`: Yalnız araç testlerinde kullanılır, production metriğine girmez.
- `mock`: Runtime dışı sentetik/mock veri; yalnız envanterde ve report bağlamında görünür.
- `generated_report`: Aracın veya önceki süreçlerin rapor çıktısı; soru input'u olarak yeniden okunmaz.
- `ignored_non_question`: İsim/içerik sinyali taşısa da soru kaynağı olmayan dosya.

Her manifest girdisi `id`, `description`, `path` veya `glob`, `role`, `parser`, `canonicalGroup`, `reportIncluded`, `gateIncluded`, `productionLike`, `precedence`, `expectedRecordCount` ve `notes` taşır.

## 4. Manifest çözümleme kuralları

Repository içindeki olası soru kaynakları yol, uzantı, dosya adı ve hafif içerik sinyalleriyle deterministik olarak keşfedilir. Her aday manifestle eşleştirilir. Birden fazla eşleşmede en yüksek `precedence` kazanır ve çakışma raporlanır; eşit precedence gate hatasıdır. Sınıflandırılmamış aday `unknown_sources.csv` dosyasına yazılır ve gate `Unclassified question source detected.` mesajıyla exit 1 verir.

Manifestte bulunmayan kaynak production toplamına otomatik alınmaz. Eksik `productionLike` veya `gateIncluded` kaynak gate hatasıdır; opsiyonel tarihsel kaynak yalnız warning üretir. `docs/audit/question_quality/**`, `test/question_quality/**` ve manifestteki `generated_report` girdileri yeniden production input'u sayılmaz.

## 5. Parser mimarisi

Reader registry manifestteki parser adına göre çalışır. İlk sürüm Dart sabit `QuizQuestion` listelerini, RFC 4180 uyumlu CSV'leri, bilinen JSON kayıt dizilerini ve bilinen SQL `INSERT ... VALUES` şekillerini salt okunur ayrıştırır. Her reader okunan, atlanan, yorum/header, boş ve parse edilemeyen kayıt sayılarını döndürür; production-like kaynakta sessiz kayıt atlama yoktur.

Yeni dependency eklenmez. CSV state machine ve SQL değer lexer'ı Dart standart kütüphanesiyle uygulanır. Reader yalnız manifestte açıkça tanımlanmış şemayı/kolon eşlemesini kullanır; bulunmayan alan `null` kalır, tahmin edilmez.

## 6. Kanonik model

Denetim aracına özel `QuestionRecord`; `sourceId`, `sourceRole`, `sourcePath`, `sourceFormat`, `sourceRow`, `sourceRecordId`, `runtimeId`, `canonicalId`, `canonicalGroup`, `locale`, `dialect`, `category`, `subcategory`, `difficulty`, `prompt`, `options`, `correctOptionIndex`, `correctOptionText`, `explanation`, `tags`, `imagePath`, `sourceTitle`, `sourceUrl`, `sourceDate`, `reviewedAt`, `reviewedBy`, `status`, `rawFingerprint` ve `normalizedFingerprint` alanlarını taşır. Runtime `QuizQuestion` modeli değişmez.

## 7. Physical ve canonical sayım

Physical count, reader'ın başarıyla çıkardığı her kaynak kaydıdır. Canonical unique count şu kimlik sırasını kullanır:

1. Güvenilir/stabil soru ID'si,
2. runtime ID,
3. normalize prompt + sıralamadan bağımsız normalize seçenek seti + kategori fingerprint'i,
4. kaynak yolu + satır numarası.

Aynı ID farklı soru veya doğru cevap taşıyorsa kayıtlar birleştirilmez; ayrı provenance korunur ve BLOCKER üretilir. Aynı içerik farklı dosyalarda physical sayımlarda ayrı, global canonical toplamda bir kez görünür.

## 8. Cross-source reconciliation

Kayıtlar önce stabil ID, sonra normalized fingerprint ile gruplandırılır. En yüksek precedence referans kopyadır. Prompt, seçenek sırası/içeriği, doğru cevap, açıklama, kategori, zorluk, image ve review/status alanları ayrı karşılaştırılır. Kopyalar `cross_source_copies.csv`, sapmalar `cross_source_divergences.csv` içinde provenance ile yazılır.

Gate kapsamındaki aynı ID/fingerprint için farklı doğru cevap veya tamamen farklı prompt BLOCKER; runtime ile aktif import/publish arasında anlamlı prompt/seçenek sapması CRITICAL; yalnız açıklama/metadata/seçenek sırası farkı WARNING'dir. Tarihsel sapma report-only kalır.

## 9. Kalite kontrolleri

Kontrol motoru yapısal alanlar, exact/near duplicate, doğru cevap geçerliliği ve pozisyon dağılımı, answer leak, yüksek güvenli Türkçe kalıpları, açıklama kalitesi, metadata boşlukları, dinamik bilgi, asset varlığı ve generated template sinyallerini üretir. Near duplicate yalnız adaydır; token Jaccard ve kategori/uzunluk bucketing kullanır.

Normalization trim, whitespace birleştirme, case folding, standart tırnak/apostrof ve son noktalama kurallarını uygular. Dart standart kütüphanesinde genel NFC API olmadığı için araç Latin/Kurmancîde kullanılan combining-mark dizilerini deterministik composition tablosuyla normalize eder. `ê`, `î`, `û`, `ş`, `ç` korunur ve ASCII'ye katlanmaz.

Dil kontrolleri heuristiktir; Kurmancî dilbilgisini kesin çözmüş sayılmaz. Kısa cevaplarda answer-leak false positive'ini azaltmak için minimum normalize uzunluk ve token sınırı uygulanır.

## 10. Severity modeli

- `BLOCKER`: Parse edilemeyen gate kaynağı, boş prompt, ikiden az seçenek, geçersiz doğru cevap, aynı ID ile farklı soru/doğru cevap, runtime kıracak eksik zorunlu asset.
- `CRITICAL`: Yüksek güvenli answer leak veya Türkçe/Kurmancî karışımı, gate kaynaklarında kritik divergence, çelişen exact duplicate, kaynaksız/reviewsiz değişken güncel yayın iddiası.
- `WARNING`: Near duplicate, pozisyon/kategori dengesizliği, kısa açıklama, metadata boşluğu, uzunluk riski ve report-only sapma.
- `INFO`: Düşük güvenli dil/stil ve manuel editoryal iyileştirme adayı.

## 11. Report, gate ve baseline modları

- `report`: Sınıflandırılmış report kaynaklarını okur ve mevcut borcu raporlar. Production-like parse hatası dışında mevcut ihlaller yüzünden zorunlu olarak kırmızı olmaz.
- `gate`: Unknown source, manifest hatası, production-like parse/kayıp kaynak hatası ve baseline'a göre yeni/kötüleşen stabil issue fingerprint'lerinde exit 1 verir.
- `baseline --accept-current-debt`: Önce güncel raporu hesaplar, eski-yeni özeti gösterir ve yalnız açık kabul bayrağıyla baseline yazar. Bayraksız çağrı dosya değiştirmez ve açık hata verir.

## 12. Baseline güvenlik modeli

Baseline manifest sürümü, kaynak fingerprintleri, gate physical/canonical sayıları, role/severity/check dağılımları, duplicate/divergence/answer leak/invalid answer/language/asset/unknown metrikleri, A/B/C/D, kategori ve zorluk dağılımlarını içerir. Tam soru metinleri tutulmaz; stabil issue fingerprint setleri ve özet sayılar tutulur.

Gate yeni fingerprint'i, artan kritik metriği, yeni exact duplicate/answer leak/asset kaybını, source fingerprint değiştiği hâlde baseline'ın güncellenmemesini veya production-like kaynak kaybını durdurur. Mevcut aynı borç ve azalan ihlal başarılıdır. Bir sorunun ID değiştirmesiyle borç saklanmasın diye issue fingerprint check ID + normalize içerik + canonical group temellidir.

## 13. Determinizm

Input yolları, kayıtlar, issue'lar ve CSV satırları açık comparator'larla sıralanır. JSON anahtarları sabit sırada yazılır. Stable çıktılarda wall-clock timestamp ve süre bulunmaz; çalışma zamanı bilgisi yalnız `run_metadata.json` dosyasındadır ve deterministik hash karşılaştırmasına dahil edilmez. Aynı checkout'ta iki report koşusunun stable SHA-256 manifesti aynı olmalıdır.

## 14. Test stratejisi

Küçük sentetik fixture'lar production verisinden ayrı tutulur. Manifest precedence/çakışma/unknown, output recursion, production exclusion, parser başarı-hata sayaçları, physical/canonical ayrımı, copy/divergence, normalization, duplicate, dil/answer leak, correct-answer, CSV injection, issue fingerprint, baseline karşılaştırması ve deterministik sıralama unit/integration testleriyle kapsanır. TDD ile önce başarısız test, sonra minimum implementasyon uygulanır.

## 15. CI davranışı

Faz 0A sırası korunur; Widgetbook analyze sonrasında ve tam testten önce `dart run tool/question_quality/question_quality_audit.dart gate` eklenir. CI report üretmez, baseline yenilemez ve soru metinlerini topluca loglamaz. Commitlenmiş baseline ile mevcut borç exit 0; yalnız regresyon exit 1 verir.

## 16. Hata yönetimi

CLI kısa, kaynak yolu ve check kimliği içeren hata verir; secret, query parametresi veya tüm soru metnini loglamaz. Parser hatası kaynak/satır bağlamıyla rapora girer. Production-like kaynakta parse kaybı veya unknown source güvenli biçimde fail-closed davranır. Report-only opsiyonel kayıp warning'dir.

## 17. Performans sınırları

Dosyalar sırayla okunur; çıktı kayıtları bellekte tutulur. Near duplicate karşılaştırması kategori, token prefix ve uzunluk bucket'larıyla sınırlandırılır; bütün kayıtlar arasında O(n²) tarama yapılmaz. Kaynak ve issue fingerprintleri yeni dependency olmadan araç içinde yer alan deterministik SHA-256 uygulamasıyla hesaplanır; kanonik birleştirme kararı yalnız hash'e değil alan karşılaştırmasına da dayanır.

## 18. Çıktı dosyaları

`docs/audit/question_quality/2026-07-15/` altında summary, inventory, unknown, physical/canonical, role, severity, structural, duplicate, copy/divergence, language, answer, explanation, metadata, dynamic fact, asset, category, difficulty ve template CSV/JSON/Markdown çıktıları üretilir. CSV hücresi `=`, `+`, `-` veya `@` ile başlıyorsa başına tek tırnak eklenir. Büyük metinler CSV'de; Markdown özetinde kısa örnek/ID kullanılır.

## 19. Gelecekteki editoryal düzeltme fazları

Faz 0B hiçbir içeriği düzeltmez. Sonraki manuel dalgalar sırasıyla: geçersiz doğru cevap/ID divergence blocker'ları; yüksek güvenli dil ve answer-leak critical'ları; runtime-import sapmaları; exact/near duplicate kümeleri; metadata/dinamik bilgi; kategori-zorluk ve generated-template borcu. Her dalga kendi branch'inde, kaynak doğrulaması ve hedefli testle yapılmalıdır.

## Tasarım self-review sonucu

- Roller ve precedence tek manifestte; eşit precedence fail-closed.
- Physical ve canonical sayım ayrıldığı için aynı 10.000 kayıt kopyalarla şişmez.
- Unknown source envantere girer ve gate'i durdurur.
- Stabil issue fingerprint'leri sayısal baseline atlatmasını önler.
- Mevcut borç baseline ile CI'ı sürekli kırmızı bırakmaz; yeni/kötüleşen borç kırmızıdır.
- Quarantine, candidate pool, fixture, mock ve generated report gate toplamına sızmaz.
- Output dizini yeniden input sayılmaz.
- Production parser kaybı sessizce geçmez.
- Spec içinde placeholder veya açık mimari karar kalmamıştır.
