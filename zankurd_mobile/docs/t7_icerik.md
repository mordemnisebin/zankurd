# T7 — tur 5 içerik ve Kurmancî değişiklik kaydı

## Kapsam ve kayıt eşleşmesi

16_eslesme_A.png karedeki sözcük anlamı sorusu `curated_movement_0006` kaydıdır.
Uygulamanın gerçek kaynağı `lib/src/data/curated_question_bank.dart`; JSON kopyası
yoktur. Bu tek kaydın kategorisi `Paradigma` (görünen adı Bilim) yerine `Ziman`
yapıldı. Kök, şıklar, açıklamalar ve doğru cevap korunur. Aynı sözcüğü içeren
`editorial_questions.json / edit_cand_0017` farklı sorudur; değiştirilmedi.

28_q9_A.png karedeki düşünür sorusu geçmiş ithal bankasında `offline_2326`,
sunucu kimliği `1ddad401-4ea2-4d31-94ac-0d81549d2bdf` olarak eşleşir. Güncel
`assets/data/*.json` ve aktif Dart soru bankalarında bu kayıt/kök yoktur.
`explanation_overrides.dart` içindeki aynı kimlik yalnız açıklamadır, şık içermez.
`source_manifest.json`, eski CSV kaynaklarını karantina/tarihsel kopya olarak
işaretler; geçmiş SQL/CSV değiştirilmedi, çıkarılmış kayıt yeniden etkinleştirilmedi.
Bu soru için değişiklik yalnız aşağıdaki TR/KU taslak ve yeni SQL dosyasındadır.

## İçerik kararı ve kaynaklar

Öcalan doğru cevap olarak korunur. Bookchin'in sosyal ekolojisi/komünalizmi ile
demokratik konfederalizm arasındaki düşünsel ilişki nedeniyle, geniş anlamlı
“geliştiren düşünür” kökünde Bookchin gereksiz tartışma doğurabilir. Bu bir
editoryal belirsizlik kararıdır; Bookchin'in kesin ikinci doğru olduğu iddia edilmez.
Yerine siyaset düşünürü Thomas Hobbes seçildi; böylece şıkların kişi/düşünür türü
korunur. Kök veya doğru cevabın anlamı değişmez.

- [ISE üyesi Eleanor Finley: Bookchin–Öcalan ilişkisi](https://democraticmodernity.com/democracy-is-an-open-door-analyzing-the-bookchin-ocalan-connection/): iki düşünsel geleneğin temasını ve ayrımını ele alan doğrudan söyleşi; 2026-10-30 okundu.
- [Newcastle University: Hobbes ve Leviathan](https://digitalshowcase.ncl.ac.uk/showcases/connecting-collections-leviathan-and-the-history-of-the-grecian-war/): Hobbes'un 1588–1679 yaşam aralığını, siyaset düşünürü kimliğini ve güçlü merkezi egemenlik yaklaşımını doğrular; 2026-10-30 okundu.

## TR / KU taslak

| Alan | KU | TR |
|---|---|---|
| Kök (değişmez) | Ramanerê ku feraseta konfederalîzma demokratîk pêşxist kî ye? | Demokratik konfederalizm kavramını geliştiren düşünür kimdir? |
| Çeldirici 1 (değişmez) | Frantz Fanon | Frantz Fanon |
| Çeldirici 2 (değişir) | Thomas Hobbes | Thomas Hobbes |
| Çeldirici 3 (değişmez) | Antonio Gramsci | Antonio Gramsci |
| Doğru (değişmez) | Abdullah Öcalan | Abdullah Öcalan |

Şık sırası tabloda sunum içindir; SQL sunucudaki sırayı varsaymaz, yalnız
`Murray Bookchin` bulunan tek alanı değiştirir.

## KU değişiklik / inceleme tablosu

| Kimlik, alan | Eski | Yeni | Gemini 3.8 Flash | Grok 4.7 | Gemini 4 Argon (hakem) |
|---|---|---|---|---|---|
| `curated_movement_0006`, category | Paradigma | Ziman | ONAY | Kota sınırı; yanıt yok | ONAY |
| `1ddad401-4ea2-4d31-94ac-0d81549d2bdf`, Bookchin bulunan seçenek | Murray Bookchin | Thomas Hobbes | ONAY | Kota sınırı; yanıt yok | ONAY |
| `K.linkGoogle`, KU | Bi Google girêde | Bi Google re bidomîne | Bu biçimi önerdi | Kota sınırı; yanıt yok | Bu biçimi önerdi |
| `K.continueGoogle`, KU | Bi Google bidomîne | Bi Google re bidomîne | Aynı kalıp önerisi | Kota sınırı; yanıt yok | Aynı kalıp önerisi |

Google için ilk öneri `Bi Google bidomîne` iki model tarafından DÜZELT aldı;
ikisi de Apple ile aynı `bi … re` kalıbındaki `Bi Google re bidomîne` biçimini
önerdi. Son uygulama bu ortak öneriyi izler. Türkçe karşılık her iki butonda
`Google ile devam et`; Apple dizesi değişmez.

İçerik için iki bağımsız model onayı alındı. Kullanıcının tercih ettiği
Gemini+Grok çifti sağlanamadı: Cursor `ActionRequiredError: You've hit your usage
limit` verdi. Talimatta hakem olarak belirtilen Gemini 4 Argon kullanıldı;
Grok onayı varmış gibi raporlanmaz. Araçsız istemler boş `/tmp/t7-content-review`
klasöründe çalıştırıldı; yalnız hedef metinler gönderildi.

## SQL ve doğrulama

`supabase/2026-10-30_anlam_kategori_celdirici.sql` yeni, idempotent taslaktır.
`applied.md` kaydı ⏳. Canlı bağlantı/uygulama yapılmadı.
İki satır kimlikle kilitlenir; eksik kayıt, beklenmedik kök/kategori/şık/cevapta
işlem hata verir. İkinci çalıştırmada hedef değerler kabul edilir, veri değişmez.
Son blok kategori, yeni çeldirici ve korunan cevap anahtarını doğrular.
Sunucu fonksiyonuna müdahale yoktur. SQL gerçek PostgreSQL üzerinde çalıştırılmış
olarak sunulmaz; canlı ön kontrol ve kuru çalışma uygulayacak kişiye kalır.

- Bekçi `test/t7_content_category_test.dart`: önce `Paradigma` nedeniyle kırmızı;
  tek kayıt düzeltmesinden sonra yeşil. Kök ve doğru cevap sabitliği de doğrulanır.
- `dart analyze lib/src/data/curated_question_bank.dart test/t7_content_category_test.dart`: No issues found.
- Hedef + mevcut curated banka testleri: 6/6 yeşil.
- Kalite taban izi: `blockers 0->0, criticals 0->0, issues 0->0`; `unknown=0`.
