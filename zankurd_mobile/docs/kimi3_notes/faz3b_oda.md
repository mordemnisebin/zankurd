
---

# FAZ 3B — Oda (Room) akışı canlı denetim (2026-07-19, iki context: A=Denetmen host, B=DenetmenB guest, viewport 390x844)

## Kurulum / giriş
- A: kalıcı profil, misafir "Denetmen" (200-A-home).
- B: temiz context. Onboarding'de "Derbas bike" (skip) butonu 2 denemede de TEPKİ VERMEDİ; "Piştre" ile ilerlemek zorunda kaldım (201/202-B). [tek context — doğrulanmadı, ama 2 tık denemesiyle]
- B misafir girişi "Wek mêvan bidomîne" + isim "DenetmenB" sorunsuz (204-207-B).

## 1. Oda oluşturma (A)
- Hub > "Odeyek Ava Bike" tıklayınca ARA ADIM OLMADAN oda direkt oluştu: kategori "Ziman", 30 sn, zorluk "Mêvandar" (209-A-create). Kategori/süre/zorluk SEÇİM ekranı yok — görevde beklenen "kategori seç" adımı mevcut değil.
- Oda kodu: **ZK-PF5V**. Kod lobide büyük/sarı ve üst app bar'da tekrar gösteriliyor; yanında kopyala ikonu var. Paylaş (share) butonu yok, sadece kopyala.
- Lobi: oyuncu listesi, host rozeti ("Host"), "Amade" durumu, "Amade Me" toggle (açık), "Pêşbirkê Dest Pê Bike" butonu 2 kişi olmadan disabled. Bilgi: "herî kêm 2 listikvan pêwîst e".

## 2. Koda katılma (B)
- Boş kod: inline validasyon "Kod pêwîst e", input kırmızı çerçeve (212-B). İyi.
- Geçersiz kod "XXXXXX": diyalog KAPANIYOR, snackbar "Odeya bi vê kodê nehat(e) dît..." (213-B). Hata mesajı doğru ama diyalog kapanıp input siliniyor — kullanıcı kodu tekrar yazmak zorunda. Küçük UX sorunu.
- Küçük harf "zk-pf5v": KABUL EDİLDİ, odaya katıldı (214-B). Case-insensitive çalışıyor. (Boşluk testi küçük harf başarılı olunca gereksiz kaldı, atlandı.)

## 3. Lobi senkronu (A + B)
- B katılınca A lobisinde anında 2 oyuncu göründü (215-A). Host rozeti sadece Denetmen'de, iki tarafta da doğru.
- Her iki tarafta liste kendi kullanıcısını 1. sırada gösteriyor (A: Denetmen 1., B: DenetmenB 1.) — tutarlı tasarım.
- Hazır toggle senkronu ÇALIŞIYOR: B "Amade Me" kapattı → A'da B "Li bendê" oldu (216-A/B); geri açınca senkronize.
- B (guest) tarafında başlat butonu YOK, "Li benda mêvandar e..." bilgisi var — guest başlatamıyor, doğru.
- A host tarafında B "Li bendê" iken bile "Pêşbirkê Dest Pê Bike" AKTİF kalıyor (216-A) — host hazır olmayan guest ile başlatabilir mi, test edilmedi.
- Küçük fark: B'nin lobi header'ında "Mêvandar" zorluk çipi görünmüyor (A'da 3 çip, B'de 2 çip) (214-B vs 215-A). Bilgi eksikliği guest tarafında.

## 4. Oyun akışı (A host başlattı, ZK-PF5V)
- Host "Pêşbirkê Dest Pê Bike" → iki context de aynı anda oyuna düştü: AYNI kategori (Ziman), AYNI soru metni ("Hevwateya 'ay'...", sonra "ezafe" Rast/Xelet) (218-A/B). Soru senkronu KANITLI.
- B tarafında oyun başında "Demjimêr" tutorial overlay'ı (1/5) çıktı ve sayaç ARKADA İŞLEMEYE devam etti — tutorial okurken süre yiyor (218-B). İlk katılan oyuncu dezavantajlı. P2.
- SÜRE TUTARSIZLIĞI: lobi çipi "30 sn" diyor, oyun içi sayaç 15 sn ve tutorial "15 saniyede bersivê bide" diyor. Lobi ≤> oyun içi uyuşmuyor. P2 (iki context'te de doğrulandı).
- Reveal senkronu: A doğru (heyv) +170 pûan, Rêz 1; B yanlış. Sonuç ekranları tutarlı: A "TU BI SER KETÎ" 170 puan rêz 1, B "TE WINDA KIR" 0 puan rêz 2; iki tarafta da sıralama aynı (Denetmen 170 / DenetmenB 0) (220-A/B). Skor tutarlılığı KANITLI.
- Ara ekranda soru ilerleme çubuğu segment pozisyonu A ve B'de farklı göründü (A 7. segment, B 6.) — zamanlamaya denk gelmiş olabilir, DOĞRULANMADI.
- Oyun 10 soru; cevaplanmayan sorular otomatik "Şaş" sayılıyor (analiz sırasında süreler doldu, oyun kendiliğinden tamamlandı) — bu beklenen tasarım.
- YANLIŞ ROZET: A'ya "Bot Têk Bir — Di pêşbirka botan de serketî" rozeti verildi; rakip gerçek insan (B) idi, bot değil. P2.
