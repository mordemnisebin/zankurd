
# FAZ3C — Liderlik / Profil / Mağaza / Ayarlar (2026-07-19, canlı zankurd.com, mobil 390×844, misafir "Denetmen")

## Aşama 16 — Liderlik (Rêz)
- Başlık: "Tabloya Pêşderîyan", alt bilgi "Her 30 çirkeyî nûve dibe" (30 saniyede bir yenilenir iddiası). Sağ üstte manuel yenileme ikonu var. (302)
- Filtreler: **Roj / Heft / Meh / Heval** — "Tüm zamanlar (Hemû dem)" filtresi YOK. (302)
- Heft: podyum (1. Baweroooo 6560, 2. Şevîn 3880, 3. Ranakêêê 3660) + liste 4-10. satırlar; satırda "X ode · Y zincir" bilgisi. Uzun isimler ("Codex Canli B 2815", "Darayenili") taşmadan sığıyor. (302-304)
- Roj: podyumda sadece 2 kişi (Denetmen 170 #1, DenetmenB 0 #2), liste boş — az kullanıcılı dönemde podyum tek/iki kişiyle de render oluyor, çökme yok. (306)
- Meh: podyum + liste normal. (307)
- **P0/P1 — Heval filtresi: tamamen GRİ BOŞ EKRAN** (308). Ne boş-durum mesajı ("arkadaşın yok") ne liste ne hata; başlık/lig bandı da kayboluyor.
- **P1 — Yenileme ikonu sonrası ekran gri boş kalıyor** (309): Heft'te refresh tıklandıktan sonra içerik geri gelmedi (3sn beklemede). Doğrulama devam ediyor.
- Kendi sıram: misafir kullanıcı (skor düşük) ilk 10'da yok; listede "senin sıran" sabit bandı/göstergesi görünmüyor — kendi sırasını bulamıyor. (P2)
- Lig bandı: "Lîga Bronz — Vê heftê bilîze û bikeve lîgê!" görünüyor. (302)
- Doğrulama: Heval'a geçişte 8 sn beklemeye rağmen gri ekran (310); Heft'e geri dönüşte de gri kaldı (311). Refresh sonrası içerik geldi ve Heval boş-durum kartı düzgün: "Heval tune — Arkadaş ekleyerek sıralamanı gör!" (312). Yani: **filtre değişiminde loading takılıyor / çok uzun (P1)**; empty state'in kendisi iyi tasarlanmış. Refresh ikonu tooltip'i "Nû bike".
- Not: empty state mesajı karışık dil (Kurmanci başlık + Türkçe açıklama "Arkadaş ekleyerek...") — tutarsız (P3).

## Aşama 17 — Profil (light tema)
- Üst kart: avatar (kırmızı halka, rozet ikonu), isim "Denetmen", alt yazı "Di tabloya pêşderûne de ev nav xuya dike" (misafir uyarısı), "Ast 1 · 190/1000 XP" + ilerleme çubuğu. Seviye/XP net. (313)
- Dil kartı "Ziman — Kurdî/Tirkî" KU/TR toggle profil içinde de var. (313)
- Statistîkên Min 2×2: Rêze (boş "—"), Tevayî Xal 190, Baştirîn Zincir 0, Listik 0. **Coin (Xeruz) ve doğruluk yüzdesi bu kartlarda YOK**; seri (zincir) var. En önemli 3 metrik (XP, seri, oyun sayısı) görünür ama Rêze boş gösteriliyor "—" (P3). (313)
- "Analiza Berfireh" katlanabilir bölüm (kapalı). Rozet bölümü: kazanılan 2/8 ("Lîstika Yekem", "Bot Tek Bir" — Türkçe rozet adı karışmış, P3) + Koleksiyona Rozetên 0/5 kilitli rozetler yatay kaydırma. (314)
- FÊRBÛN menüsü: Pirsên Tomarkirî, Şaşiyên Min (0/14), Pirs Pêşniyar Bike. HESAB: Dukan, Miheng (ayarlar), Derkeve (çıkış, kırmızı). (315-317)
- Kart kalabalığı yok, hiyerarşi iyi; ama coin/doğruluk gibi metrikler eksik (P2).

## Aşama 18 — Mağaza (Dukan)
- Bakiye bandı: "Bakîyeya Te — 55 coin" net. Geri ok + başlık var. (321)
- Sadece 3 ürün: Rozeta VIP (1000c, "BABETÊ HERÎ BABET" rozeti), Carçoveya Zêrîn (750c), "Zivirîna Zêde ya Ç…" (200c) — **ürün adı ellipsis ile kesiliyor, tam adı görmenin yolu yok (P3)**. Ürün önizlemeleri basit ikon/emoji; açıklamalar Kurmanci.
- Katalog çok küçük (3 ürün), scroll yok; "sahip olunan/aktif" işareti görünmüyor (henüz alınan ürün yok — doğrulanamadı).
- Satın alma diyaloğu: ürün adı, fiyat, "Bakîyeya te: 55 coin" kırmızı uyarı, Batal/Bikire butonları (325). "Bikire" yetersiz coinde → diyalog kapanıyor + kırmızı snackbar "Bakîyeya te kêm e!" — doğru davranış, satın alma gerçekleşmedi, bakiye 55'te kaldı (329). Ancak Bikire butonu yetersiz coinde disabled değil; tıklanabilir kalıyor (P3, kabul edilebilir).
- Ürün kartına tıklamak da aynı diyaloğu açıyor (327). Önizleme (avatar üzerinde çerçeve vb. canlı önizleme) yok.

## Aşama 19 — Ayarlar (Miheng) envanteri
- Bölümler: HESAP (Navê lîstikê + Tomar Bike; Karên Hesabê → "Hesabê Min Jê Bibe"), HÎNBÛN ("Asta xwe ji nû ve diyar bike" seviye sınavı), EWLEKARÎ ("Moda zaroka ewle" çocuk modu toggle), DÎMEN (Zimanê sepanê KU/TR, Modê tarî/ronahî, Tevgerê kêm bike), DENG Û AGAHDARÎ (Deng û mûzîk açık; Bîranîna rojane 19:00 kapalı), DERBARÊ SEPANÊ (Çawa tê lîstin?, Nepenî accordion), sürüm kartı. (330-334)
- Sürüm: **Guherto 1.9.1+13 — pubspec ile birebir aynı** (332). ✓
- Eksik ayarlar: ayrı titreşim toggle'ı YOK, ayrı animasyon toggle'ı YOK (sadece "Tevgerê kêm bike" reduced motion var), ses ve müzik tek birleşik toggle. Destek/şartlar linki ilk bakışta yok (accordion içinde bakılacak).
- Dil TR: anında tüm UI Türkçe'ye döndü ("Ayarlar", "Uygulama dili", "Ses efektleri", "Sürüm 1.9.1+13") (337); KU'ya geri alındı (338). Dil geçişi sorunsuz. ✓
- Tema: dark'a geçiş anında ve oturumlar arası kalıcı; dark tema ayarlar ve profilde tutarlı, kontrast iyi (341, 342). Light'a geri alındı (343). ✓
- "Çawa tê lîstin?" accordion: oyun modları açıklamaları madde madde, Kurmanci, düzgün (344).
