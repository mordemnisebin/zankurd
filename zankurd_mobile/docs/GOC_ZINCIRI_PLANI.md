# Göç zincirini yeniden üretilebilir yapma planı (G-08)

Durum: PLAN. Bu not kodu değiştirmez; canlıya da bağlanmaz.

## Sorun

`supabase/migrations/` yalnız 8 göç içerir (sonuncusu Ağustos 2026). Ekim–Kasım
2026 şeması (`app_runtime_config`, haftalık lig, ölçek turları, yönetim paneli,
doğrulanmış solo/günlük oturumlar...) kök dizindeki `supabase/2026-*.sql`
dosyalarındadır ve elle `supabase db query --linked -f ...` ile uygulanır
(`supabase/applied.md` kaydı tutar). Sonuç: temiz bir `supabase db reset`
canlıdaki şemayı ÜRETMEZ; yerel/staging ortamı eksik kalır, CI'da şema
doğrulaması yapılamaz.

(Canlının eksik olduğu iddia edilmiyor: kök dosyalar canlıda uygulanmış ve
`applied.md` ✅ ile kayıtlıdır. Eksik olan yeniden üretilebilirliktir.)

## Neden körlemesine çözülmüyor

* Kök dosyaların çoğu tek seferlik, sırayla bağımlı, bazıları `CONCURRENTLY`
  (transaction dışı), bazıları içerik (soru) yüklemesi, bazıları md5 ön koşullu
  yama: tekrar çalıştırmak canlıda zarar verebilir.
* Yamalar canlı gövdenin tam md5'ine bağlıdır; sıra bozulursa göç kendisi durur.
* `supabase db push` geçmiş tablosuna (supabase_migrations.schema_migrations)
  bu dosyalar kaydedilmemiştir; `db push` hepsini yeniden uygulamaya kalkar.

## Önerilen yol (sırayla; HİÇBİRİ canlıya yazmaz)

1. **Salt-okur şema dökümü.** `tool/sema_karsilastir_taslak.sql` (bu planla
   birlikte) canlıda YALNIZ katalog okur: tablo/sütun, indeks, işlev gövdesi md5,
   tetikleyici, politika, cron işi listesi. Çıktı `docs/` dışında (repo'ya değil)
   saklanır.
2. **Birleştirilmiş baz göç.** Canlı dökümden (`supabase db dump --schema public`
   salt-okur) tek bir `20261106000000_canli_taban.sql` üretilir; yalnız yapı
   (tablo/işlev/politika/indeks/tetikleyici), veri ve içerik yok. Mevcut 8
   göçün YERİNE değil SONRASINA konur; kök dosyalar `arsiv/` altına taşınmaz,
   `applied.md` kaynak kayıt olarak kalır.
3. **Geçmiş tablosu eşitleme.** Canlıda `supabase migration repair --status
   applied 20261106000000` (yalnız geçmiş satırı yazar, şemaya dokunmaz) —
   bu adım ana ajan/sahip tarafından, tek seferlik ve izinle.
4. **CI: temiz `db reset` testi.** Docker'lı Postgres'te `supabase db reset` +
   `tool/sema_karsilastir_taslak.sql` çıktısının canlı dökümle karşılaştırması
   (tablo/sütun/işlev md5 eşitliği). Fark = CI kırmızı.
5. **Yeni göçler** bundan sonra `supabase/migrations/` altına zaman damgalı
   dosya olarak girer (`supabase migration new`); kök dizindeki elle düzen
   emekli edilir. Md5 ön koşullu yama kalıbı korunur.

## Riskler

* Taban dökümünde `pg_cron` işleri ve Vault sırları yoktur (eklenti/sır):
  ayrı `cron_isleri.sql` ve elle sır adımı gerekir.
* `supabase/functions/` (Edge) göçle ilgisizdir; ayrı dağıtılır.
* Döküm sırasında canlı şemada elle yapılmış, kayda geçmemiş değişiklik
  bulunabilir: bu, planın BULMAK istediği şeydir; fark raporlanır, sessizce
  düzeltilmez.
