# KIMI3 Live Audit — Baseline (Aşama 0)

Tarih: 2026-07-19 · Denetçi: FAZ 1 alt ajanı (KIMI3)

## Repo durumu

- Proje: `zankurd_mobile/` (Flutter/Dart, Kurmancî quiz uygulaması)
- Aktif branch: `main`
- HEAD: `ed9a996d7a6176941d51de95cda2bb681898e5e6` — "chore: sürüm 1.9.1+13"

## git status --short

```
 M ../CLAUDE.md
 D ../CODEX_HANDOFF.md
 M ../CURRENT_STATUS.md
 D ../DEVELOPMENT_SUMMARY.md
 D ../SESSION_2_COMPLETE.md
 M lib/src/l10n/explanation_ku.dart
 M lib/src/screens/matchmaking_screen.dart
 M lib/src/screens/profile_screen.dart
 M lib/src/screens/quiz/quiz_widgets.dart
 M lib/src/screens/quiz_result_screen.dart
 M lib/src/screens/review_screen.dart
 M lib/src/screens/settings_screen.dart
 M lib/src/screens/shop_screen.dart
 M lib/src/services/notification_service.dart
?? ../arsiv/
?? ../fix_soru_bankasi.py
?? ../fix_zk122_141.py
?? ../supabase_import_2026-07-19.sql
?? ../supabase_work/
?? ../zankurd_soru_bankasi_cevapli_DUZELTILMIS.csv
```

Not: Workspace kökü (`pirs kurmanci/`) tek bir git repo'su; repo kökü `zankurd_mobile`'ın üst dizini. Değiştirilmiş 9 Dart dosyası + commit'lenmemiş üst-dizin değişiklikleri mevcut. Denetim sırasında hiçbir dosya değiştirilmedi, `flutter clean` çalıştırılmadı.

## git log -10

```
ed9a996 chore: sürüm 1.9.1+13
a57bbab fix: ilk-kullanım denetimi 5 UX düzeltmesi
e278aa4 docs: CLAUDE.md sürüm durumunu 1.9.0+12'ye güncelle
e42803c chore: sürüm 1.9.0+12
6d580ba feat: içerik ve odak sağlamlaştırma paketi
ea93d25 docs: UX sağlamlaştırma uygulama planını ekle
fae6e3a docs: UX responsive ve içerik sağlamlaştırma tasarımını ekle
cf90cb3 fix: zcode redesign işini stabilize et, Pirs karşılaştırmasıyla iyileştir
2e6983a fix: quiz üst başlığındaki tekrar eden ilerleme göstergesini kaldır
d9c0256 feat: mağazaya mockup-11 tarzı öne çıkan ürün kartı eklendi
```

## Araç sürümleri

- Flutter SDK yolu: `C:\src\flutter` (PATH'te değil; `flutter` komutu bash PATH'inde bulunamadı, PowerShell PATH'e eklenerek çalıştırıldı)
- Flutter: 3.44.1 • channel stable • revision 924134a44c (2026-05-29)
- Dart: 3.12.1 (stable) windows_x64

## Notlar

- Canlı hedef: https://zankurd.com/ (Flutter web, canvas tabanlı)
- Tarayıcı otomasyonu: Playwright MCP araçları bu oturumda mevcut değil; kimi-webbridge skill'i (daemon `http://127.0.0.1:10086`) kullanıldı. Canvas tabanlı UI'da CDP `Emulation.setDeviceMetricsOverride` + koordinat tıklama + screenshot yaklaşımı uygulandı.
