# Final release-candidate ekran kanıtları — 2026-07-15

Görüntüler, `codex/final-release-candidate-polish-2026-07-15` branch'indeki yerel standart web build'inden Playwright ile alındı. Akış; onboarding, misafir girişi, günlük quiz, doğru/yanlış/timeout cevapları, sonuç, liderlik ve ayarlar ekranlarını gerçek kullanıcı etkileşimleriyle kapsar.

| Dosya | Görünüm | Tema / durum |
|---|---:|---|
| `home_dark_390x844.png` | 390×844 | Ana sayfa, koyu |
| `home_light_390x844.png` | 390×844 | Ana sayfa, açık |
| `home_dark_320x568.png` | 320×568 | Ana sayfa, dar ekran |
| `home_dark_768x1024.png` | 768×1024 | Ana sayfa, tablet |
| `home_dark_1440x900.png` | 1440×900 | Ana sayfa, masaüstü |
| `game_modes_dark_390x844.png` | 390×844 | Oyun merkezi / mod kartları |
| `quiz_normal_dark_390x844.png` | 390×844 | Quiz, normal durum |
| `quiz_correct_dark_390x844.png` | 390×844 | Quiz, doğru cevap |
| `quiz_wrong_dark_390x844.png` | 390×844 | Quiz, yanlış cevap |
| `quiz_timeout_dark_390x844.png` | 390×844 | Quiz, görünür timeout bildirimi |
| `result_dark_390x844.png` | 390×844 | Sonuç, koyu |
| `result_light_390x844.png` | 390×844 | Sonuç, açık |
| `result_dark_844x390.png` | 844×390 | Sonuç, landscape |
| `leaderboard_light_390x844.png` | 390×844 | Liderlik, açık |
| `leaderboard_dark_390x844.png` | 390×844 | Liderlik, koyu |
| `settings_light_390x844.png` | 390×844 | Ayarlar, açık |
| `settings_dark_390x844.png` | 390×844 | Ayarlar, koyu |

Kontrol sonucu: overflow veya Flutter hata şeridi görülmedi; Kurmancî karakterler bozulmadı; tema durumları doğru; Playwright konsolunda 0 hata ve 0 uyarı vardı. Önceki sürüm için sentetik ekran üretmek yerine, doğrulanmış final durumları aynı dizinde indekslendi.
