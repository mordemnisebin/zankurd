# FAZ 1 — Canlı Görsel Denetim: Açılış, Giriş, Ana Sayfa

Tarih: 2026-07-19 · Hedef: https://zankurd.com/ · Yöntem: Playwright + headful Chromium, kalıcı profil, gerçek fare tıklaması, koordinat tabanlı (Flutter web canvas). Ana viewport 390×844; spot: 320×568, 768×1024, 1440×900, 844×390.

## Ortam notu
- Playwright MCP araçları oturumda yoktu; kimi-webbridge daemon'ı çalışıyordu fakat tarayıcı uzantısı bağlı değildi ("no extension connected"). Çözüm: managed Python'a `playwright` + Chromium kuruldu, gerçek tarayıcı ile görsel denetim yapıldı (HTTP/DOM-only değil).
- Yardımcı scriptler: `output/kimi3_live_visual_audit/audit.py`, `_flow1..8.py` (yeniden üretilebilir).
- Baseline: `docs/KIMI3_LIVE_AUDIT_BASELINE.md` (branch main, HEAD ed9a996, 9 değiştirilmiş Dart dosyası, Flutter 3.44.1 / Dart 3.12.1).

## İlk yükleme
- domcontentloaded ≈ 0.4 sn; Flutter engine bootstrap + ilk anlamlı frame ≈ 6–9 sn (soğuk profil, headful). Splash/logo görünür; yükleme hissi kabul edilebilir ama web için uzun sayılabilir.
- Konsol: sadece Firebase init debug logları. **0 JS hatası, 0 pageerror, 0 requestfailed, 0 HTTP≥400, 0 CORS, 0 kırık asset.** Servis worker sorunu görülmedi.

## Onboarding (4 sayfa)
1. "Hîn bibe" (kitap ikonu, yeşil) — 01
2. "Pêşbirkê bike" (kupa, turuncu) — 02
3. "Her roj vegere" (alev, yeşil) — 07
4. "Çima ZanKurd?" (elmas, sarı) + "Dest pê bike" — 08
- "Derbas bike" (skip) sağ üstte her sayfada. Nokta göstergeleri doğru ilerliyor. Puan: 8/10.
- Sorun: sayfa indeksi oturumlar arasında tutarsız — reload sonrası onboarding sayfa 2'den açıldı (persist edilen indeks davranışı şüpheli). P2.

## Giriş ekranı — 12
- KU/TR dil toggle (üstte), "Bi Google têkeve", "Wek mêvan bidomîne" (misafir), e-posta/şifre, "Şifre ji bir kir?", "Tomar bibe" linki. Puan: 9/10.
- Boş submit → snackbar "E-peyam pêwîst e" (13). Geçersiz e-posta → kırmızı border + inline "E-peyameke derbasdar binivîse" + snackbar "Şifre pêwîst e" (14). Validasyon hem inline hem snackbar — iyi.
- Google girişi test edilmedi (gerçek hesap gerekir).

## Misafir isim ekranı — 15
- "Navê te di lîstikê de çi be?" + "Mînak: Zelal" placeholder + "Dest Pê Bike".
- Boş isim → inline kırmızı "Nav divê herî kêm 2 tip be" (16). "Denetmen" yazıldı → başarıyla ana sayfaya (18/19). Puan: 9/10.
- Seviye/placement akışı misafirde çıkmadı (yok ya da sonraki akışta).

## Ana sayfa
- Karşılama "Şevbaş, Denetmen!" + avatar, KU toggle, tema toggle (ay/güneş — çalışıyor).
- Rozetler: Zincir 0, Xeruz 0, Misyon 0/3 — anlaşılır, ikonlu.
- Kartlar: "Dersê rojane — 10 Pirs / Destpêk bike" (ana CTA, kırmızı buton, coin görseli), "Zû bîlize" (→ Pêşbazî sekmesine götürüyor), "Getina Rojê" (günün sözü, Kürtçe+Türkçe), "Lîsteya bilind" top-3 + "Hemûyê bibîne".
- İlk açılışta coach-mark overlay turu ("Bîlize 2/3", Pêş/Derbas bike) — 19/20. Yeni kullanıcı yönlendirmesi iyi.
- CTA hiyerarşisi net: büyük kırmızı "Destpêk bike" ilk bakışta belli. "Öğren/Yarış/İlerle" vaatleri karşılanıyor (Dersê rojane / Zû bîlize+Pêşbazî / Lîsteya bilind+Rêz).
- Dark: 21 (9/10). Light: 23 (8/10 — "Dersê rojane" hero kartı light temada da koyu kalıyor; bilinçli olabilir, P3).
- Alt nav 5 sekme çalışıyor: Sereke, Kategorî (8 kategori, pirs sayıları: Ziman 1083, Siyaset 499, Paradîgma 521, Muzîk 491, Teknolojî 23...), Pêşbazî (Şerê 1vs1, Pêşbirka Rojê, Cerxa Rojê 100 coin, Turnuva Bot kûpa, Odeyek Ava Bike / Kodê tevlî bibe, Dukan û joker), Rêz (Roj/Heft/Meh/Heval sekmeleri, Liga Bronz banner, podyum), Profîl (XP bar Ast 1, dil toggle, istatistikler, Analiza Berfireh akordeonu, ayarlar dişlisi).
- "Odeyek Ava Bike" faz kuralı gereği tıklanmadı (oda oluşturma yok).

## Quiz smoke (izinli)
- "Destpêk bike" → Ziman quiz'i açıldı; quiz içi tutorial overlay ("Demjimêr 1/5", "Bersiv Hilbjêre 2/5") gösterildi; soru "Di Kurmancî de peyva \"pîr\" bi Tirkî çi ye?" + 4 şık doğru render. 37/38. Derin quiz denetimi sonraki faza.

## Responsive spot
- 320×568 (33): taşma yok, metin kırpmaları ellipsis ile zarif ("Amadeyî yanga n…"). 8/10.
- 768×1024 (34): 2 sütun grid, ferah. 9/10.
- 1440×900 (35): içerik ~1000px'e sınırlı, dengeli. 9/10.
- 844×390 landscape (36): çalışıyor; "Destpêk bike" butonu alt nav'a yapışık/kesik hissi, içerik scroll ile erişiliyor. 7/10, P3.

## Bulunan sorunlar
| # | Öncelik | Ekran/Durum | Açıklama | Kanıt |
|---|---------|-------------|----------|-------|
| 1 | P1 | Pêşbazî → tarayıcı Geri | `history.back()` sonrası tamamen beyaz boş sayfa; reload gerekli. SPA route stack web'de kırılıyor. | 27-back-home.png |
| 2 | P2 | Onboarding reload | Sayfa indeksi oturumlar arasında tutarsız (sayfa 2'den yeniden başlıyor); ilerleme persist mantığı şüpheli. | 02→_flow1 davranışı |
| 3 | P3 | Ana sayfa light tema | "Dersê rojane" hero kartı light temada koyu kalıyor (tema tutarlılığı). | 23-home-light-mobile.png |
| 4 | P3 | Landscape 844×390 | Ana CTA butonu alt nav ile çakışıyor/kesiliyor. | 36-home-landscape-844.png |
| 5 | P3 | Giriş ekranı | "123" şifre yazımı sonrası "Şifre pêwîst e" snackbar'ı — alan temizlenmiş ya da min-length mesajı "pêwîst" olarak görünüyor; mesaj ayrıştırması iyileştirilebilir. | 14-signin-invalid-submit.png |

## Açılamayan ekran
- Yok. Tüm hedef ekranlar açıldı. Google girişi ve oda oluşturma kapsam dışı bırakıldı (bilinçli).

## Screenshot listesi (output/kimi3_live_visual_audit/2026-07-19/)
01-onboarding-1-mobile, 02-onboarding-2-mobile, 07-onboarding-3-herroj-mobile, 08-onboarding-4-cima-mobile, 10-onboarding-3-check, 11-onboarding-4-check, 12-sign-in-mobile, 13-signin-empty-submit, 14-signin-invalid-submit, 15-guest-name-mobile, 16-guest-name-empty, 17-guest-name-filled, 18-after-guest-login, 19-after-guest-login-2, 20-home-coachmark-check, 21-home-dark-mobile, 22-home-after-theme-click, 23-home-light-mobile, 24-home-dark-scroll1, 25-home-dark-scroll2, 26-zubilize-click, 27-back-home (BOŞ SAYFA kanıtı), 28-home-after-reload, 29-tab-kategori, 30-tab-rez, 31-tab-profil, 32-tab-sereke-back, 33-home-small-320, 34-home-tablet-768, 35-home-desktop-1440, 36-home-landscape-844, 37-quiz-start, 38-quiz-mid, _console_network_log.jsonl
