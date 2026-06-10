# ZanKurd Play Store Internal Test Hazirligi

Bu dosya yerelde hazirlanan paketlerin Play Console tarafinda nasil
kullanilacagini netlestirmek icin tutulur.

## Hazir paketler

- `release_packages/zankurd-playstore-release.aab`: Play Console icin ana paket.
- `release_packages/zankurd-android-release.apk`: Dogrudan cihaz testi icin APK.
- `release_packages/privacy_policy.html`: Gizlilik politikasi kopyasi.
- `release_packages/SHA256SUMS.txt`: Paket hash kontrol listesi.

## Play Console tarafinda kullanilacak bilgiler

- Uygulama adi: `ZanKurd`
- Paket adi: `com.zankurd.app`
- Kategori: `Education` veya `Trivia`
- Hedef kitle: Dil/quiz uygulamasi; cocuklara yonelik olarak isaretlenmemeli.
- Gizlilik politikasi: `privacy_policy.html` bir web adresinde yayinlanip URL olarak girilmeli.
- Veri toplama ozeti: e-posta ile kayit yapilirsa e-posta, Supabase anonim/kayitli
  kullanici kimligi, oyun skoru, coin hareketleri ve soru raporlari islenir.

## Internal testing sirasi

1. `zankurd-playstore-release.aab` dosyasini Internal testing kanalina yukle.
2. Release notes alanina `docs/release_notes_internal.md` icerigini koy.
3. Test kullanicilarini ekle.
4. Link uzerinden en az bir gercek Android cihaza kur.
5. Su akislari kontrol et:
   - Misafir girisi
   - Gunluk yarisma
   - Gunluk cark
   - Kategori/seviye yarisma
   - Oda kurma ve oda kodu ekrani
   - Profil adi guncelleme
   - Liderlik ekrani

## Supabase SQL sirasi

Canli backend icin SQL Editor'de sirasiyla calistirilmasi gereken ek dosyalar:

1. `supabase/daily_spin_rpc.sql`
2. `supabase/quiz_reward_rpc.sql`
3. `supabase/coin_policies.sql`

Bu sira onemli: once RPC fonksiyonlari olusur, sonra direct client insert
politikasi sikilastirilir.

Soru bankasi kalite temizligi icin ayrica `supabase/dedupe_and_fix_questions.sql`
calistirilabilir. Bu dosya satir silmez; tekrarlanan veya cevap sizintisi
tespit edilen sorulari `is_approved=false` yapar.
