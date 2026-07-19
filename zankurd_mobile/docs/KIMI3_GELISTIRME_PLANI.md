# KIMI3 — ZanKurd Güvenli Geliştirme Planı (6 Faz)

Kaynak: `KIMI3_ZANKURD_LIVE_VISUAL_PRODUCT_AUDIT.md` (2026-07-19, canlı denetim).
İlkeler: her madde küçük, bağımsız, geri alınabilir. Logic-sensitive alanlarda (subscribeRoomPlayers, matchmaking RPC, coin/XP RPC, economy, auth, route isimleri, migration) kod değişikliği önerisi yüzeyseldir; önce plan + regression testi yazılır, değişiklik test koruması altında yapılır. Her faz sonunda `dart analyze` + ilgili widget test + canlı smoke koşusu.

---

## Faz 1 — Güven kıran sorunlar (P0 + kritik P1)

Amaç: kullanıcının "bozuk" diyeceği şeyleri kaldırmak.

1. **P0 — Piştre takılması (quiz state machine, logic-sensitive)**
   - Önce reprodüksiyon: 139–144 koşusunun koşullarını (hangi quiz modu, hangi soru indeksi, timeout sonrası mı) belirle; state transition debug logu ekle.
   - Düzeltme minimal kalsın; reveal→next geçişinde guard/enable koşulunu gözden geçir.
   - Regression: 20 koşuluk otomasyon (solo + oda + turnuva), her reveal sonrası Piştre'nin ilerlediğini doğrula.
   - Geri alma: tek commit, flag'siz UI davranışı değişmez.
2. **Pêşbirka Rojê ölü kartı (UI-only)**
   - Kısa vade: kartı "Sibê were" / "yakında" durumuna çevir VEYA generic 10 soruluk günlük quiz'e bağla.
   - Kart↔ekran isim eşleşmesi (Pêşbirka Rojê ≠ Çalakî).
   - Kabul: karta tıklayan kullanıcı ya oynanabilir içerik ya da net "kapalı" mesajı + geri yolu görür.
3. **Teknolojî kategorisini yayından gizle (veri/feature flag)**
   - 23 meta/test sorusu yayına hazır içerikle dolana dek kategori kartı listede gösterilmesin.
   - Kod değişikliği yok; kategori görünürlük bayrağı/admin tarafı. Geri alma: bayrağı aç.
4. **Tarayıcı Geri → beyaz sayfa (routing, logic-sensitive: route isimleri)**
   - Plan: web'de `history.back()` sonrası boş stack durumunda ana sayfaya düşen guard ekle (route isimleri değişmeden).
   - Regression test: her ana sekmeden ileri/geri 3 tur; beyaz ekran assert'i.
5. **Rêz filtre loading takılması (UI + sorgu timeout)**
   - Filtre geçişinde 2 sn timeout + skeleton/empty-state fallback; sonsuz gri ekran yasak.
   - Liderlik sorgusu logic-sensitive: sorgu değişmez, sadece UI yükleme durumu yönetimi.
   - Test: Heval↔Heft 10 hızlı geçiş, hiçbirinde >3 sn boş ekran.

Faz 1 çıkış kriteri: canlıda 20 dk'lık smoke turunda "bozuk" hissi veren ekran kalmaması.

---

## Faz 2 — İçerik güvenilirliği (soru bankası)

Amaç: canlı soru içeriği denetim bulgularını kapatmak. UI koduna dokunmaz; mevcut soru bankası/adjudication akışıyla yürür.

1. Günlük quiz deterministik tekrarını kır (soru seçimi logic-sensitive → önce seçim algoritması testi: art arda 3 gün farklı Q1).
2. Meta/test sorularını ayıkla (q21, q22, q24 ve benzerleri) — Teknolojî'yi gerçek içerikle doldur.
3. En-uzun-şık bias'ı: ~10 soruda çeldiricileri doğru cevap uzunluk/üslubuna yaklaştır.
4. T/F kalıplarına iki yönlü varyantlar ("were nirxandin" hem Rast hem Şaş olabilecek formlar).
5. Çeldirici tekrarlarını çeşitle (q35/q48/q50-A grubu; q13/q15 grubu).
6. Kategori↔içerik uyumsuzluklarını taşı/yeniden etiketle (Rêziman↔kelime, Paradîgma↔kimya, Çand↔müzik).
7. Tek tek şüpheliler: q10 (çift doğru), q39 (sil/yeniden yaz), q37, q34, q27, q36, q47, q12.
8. Tamamen Türkçe soruları Kurmancî'ye çevir veya kaldır (q33, q49; tasarım gereği vocab istisnalarını dokümante et).

Faz 2 çıkış kriteri: 50 soruluk örneklem tekrarında meta içerik 0, uyumsuzluk <%5, en-uzun-şık <%40.

---

## Faz 3 — Multiplayer ve oyun modu tutarlılığı

Logic-sensitive ağırlıklı faz; her madde önce iki-context regression testiyle korunur.

1. **Oda süre tutarsızlığı (30↔15 sn)**: süre sabiti tek kaynaktan okunsun (lobi çipi = oyun içi sayaç = tutorial metni). Test: iki context'te sayaç eşleşmesi.
2. **Tutorial sayacı yemesin**: oda/1v1'de tutorial overlay açıkken sayaç duraklasın veya tutorial oda modunda gösterilmesin. Test: B context'te tutorial süresince sayaç sabit.
3. **Host hazırsız guest ile başlatma**: başlat butonu yalnızca tüm oyuncular "Amade" iken aktif (veya bilinçli uyarı diyaloğu). `subscribeRoomPlayers` dokunulmadan UI enable koşulu. Test: hazırsız guest senaryosu.
4. **"Bot Têk Bir" rozeti**: rozet koşulu rakip tipini kontrol etsin (insan rakibe bot rozeti verilmez). Achievement koşulu logic-sensitive → test: insan vs insan ve insan vs bot koşuları.
5. **submit_answer 400 fırtınası**: retry/idempotency davranışını logla; gereksiz tekrar isteklerini sustur. RPC değişikliği yok; client tarafı gözlem + throttle.
6. **Turnuva versus katmanı (UI-only)**: maç ekranına rakip adı + skor + tur göstergesi; bracket satırlarına "(bot)" ibaresi; ödül satırına somut coin/puan.
7. **Oda kurma ara adımı**: kategori/süre/zorluk seçim ekranı (UI-only; mevcut default'lar ön-seçili gelir).
8. **Çark hak göstergesi**: kalan hak / "sibê were" geri sayımı; kart vaadi "100 coin'e kadar" olarak yumuşat.

Faz 3 çıkış kriteri: faz3b iki-context senaryosu + turnuva maçı uçtan uca yeşil regression.

---

## Faz 4 — Öğrenme döngüsü ve profil (Pirs ilkeleri 2–3)

Yeni modüller, UI-only; mevcut akışlara dokunmaz.

1. **Öğrenme alanı (LearningZone)**: kategori bazlı kısa ders kartları + ders sonu mini quiz. İlk sürüm: 1 kategori (Ziman) pilot. Ana sayfaya "Hîn bibe" kartı.
2. **Yanlış tekrarı bağımsız modu**: Şaşiyên Min listesinden "tekrar oyna" akışı; sonuç ekranına "yanlışları tekrar et" CTA'sı.
3. **Profil metrikleri**: coin (Xeruz) + doğruluk yüzdesi kartları; Rêze "—" yerine anlamlı gösterim.
4. **Liderlik "kendi sıram" bandı**: liste altına sabit kullanıcı satırı (ilk 10 dışında da).
5. **Rozet adları dil temizliği** ("Bot Tek Bir" → Kurmancî).
6. **Seviye ilerlemesi görünürlüğü**: kategori kartlarındaki ilerleme hep 0 görünüyor; ilerleme yazımı logic-sensitive → önce okuma tarafını düzelt, yazımı testle doğrula.

Faz 4 çıkış kriteri: pilot kategoride "öğren → quiz → yanlış tekrarı" döngüsü uçtan uca çalışıyor.

---

## Faz 5 — İçerik/ürün cilası ve ekonomi görünürlüğü (P2/P3 paketi)

Her madde bağımsız tek commit'lik UI işi:

1. Light temada hero kart (Dersê rojane) tema yüzeyine bağla.
2. Landscape'te CTA safe-area padding.
3. Onboarding reload indeksini sıfırla/persist mantığını düzelt; "Derbas bike" tek tıkta çalıştığını doğrula.
4. Şifre hata mesajlarını ayır (boş ≠ min-length).
5. Heval empty-state tek dil; "Hemû dem" filtresi ekle (opsiyonel).
6. Mağaza: ürün adı tam gösterim (ellipsis kaldır), "BABETÊ HERÎ BABET" rozeti anlamlı metin, sahip olunan işareti, canlı önizleme (opsiyonel).
7. Geçersiz oda kodunda diyalog açık kalsın + input korunsun; koda "paylaş" butonu.
8. Guest lobide zorluk çipi eksikliği.
9. Ayarlara ayrı ses/müzik toggle'ları (mevcut birleşik korunarak).
10. 1v1 "Zindî" etiketi: "Bi lîstikvan an bot re" gibi dürüst etiket; bekleme ekranında bot fallback'i önceden belirt.
11. favorite_questions offline id 400'leri: offline id'lerde favori sorgusunu atla (client tarafı guard).

Faz 5 çıkış kriteri: denetim P3 listesi kapanmış; dark/light + 5 sekme görsel regression geçiyor.

---

## Faz 6 — Web performansı ve erişilebilirlik

1. **İlk yük ~13 MB → ≤6 MB hedefi**:
   - canvaskit lite / HTML renderer değerlendirmesi (A/B build, canvas kalitesi karşılaştırması).
   - `--tree-shake-icons` doğrulaması; Rubik Black kaldır/subset; 4 ağırlık → 2–3.
   - Deferred loading: oyun modları ayrı deferred parçalar.
   - Ölçüm: 3G throttling'de ilk anlamlı frame <3 sn.
2. **Route geçişleri 2–2,5 sn → <1 sn**: sekme verilerini önbelleğe al; tekrar ziyarette anında render. Sorgu davranışı logic-sensitive → önce ölçüm (hangi fetch'ler), sonra cache katmanı.
3. **Auto semantics**: `flt-semantics` varsayılan etkin veya klavye/fareyle ulaşılabilir görünür "Enable accessibility". Test: ilk yüklemede semantik node >0.
4. **Kategori kartları button rolü** + aria etiketleri ("Ziman, 1083 pirs, 5 ast").
5. **Dokunma hedefleri ≥44 px**: "Hemûyê bibîne ›", misyon satırı.
6. **Focus halkası 2–3 px**, ölü FLUTTER-VIEW tab duraklarını kaldır.
7. **İkon buton aria-label'ları** (üst bar).
8. Zoom %200 ve 320 px görsel regression'ı CI'a al.

Faz 6 çıkış kriteri: Lighthouse/ölçüm raporu + semantik ağaç ilk yüklemede aktif; NVDA ile ana akış okunabilir (manuel doğrulama).

---

## Regression testi envanteri (fazlar boyunca biriken)

- Quiz: 20 koşu Piştre ilerleme (Faz 1).
- Navigasyon: sekme bazlı ileri/geri 3 tur (Faz 1).
- Liderlik: 10 hızlı filtre geçişi (Faz 1).
- Günlük quiz: 3 gün farklı Q1 (Faz 2).
- Oda: iki-context senkron senaryosu (Faz 3) — mevcut faz3b driver'ı temel alınır.
- Turnuva: bracket → maç → sonuç (Faz 3).
- Öğrenme döngüsü pilot akışı (Faz 4).
- Görsel: 5 sekme × dark/light × 320/390/768/1440 (Faz 5–6).
- Erişilebilirlik: semantik node sayısı, tab sırası, dokunma hedefleri (Faz 6).
