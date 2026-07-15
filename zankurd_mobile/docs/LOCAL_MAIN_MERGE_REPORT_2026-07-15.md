# ZanKurd yerel main merge doğrulaması — 2026-07-15

## 1. Merge öncesi main commit'i

`f590566bc07cf46d5ea14d3db58ad20e96a0e1bb`

## 2. Yerel backup branch

`local/pre-final-merge-backup-2026-07-15` → `f590566bc07cf46d5ea14d3db58ad20e96a0e1bb`

## 3. Merge edilen final commit

`43e23641f8c19c1d4cd7c3f1fe5523c4277da8d6`

## 4. Merge commit'i

`c8541b5ea0875ce5d171adc54dde6231f78a6fef` — `merge: integrate final release candidate polish`

Main checkout'a özgü ignored `release_packages/**` ve `node_modules/**` false-positive'lerini gideren dar takip commit'i: `cc4546665b1f0733ed69a450bafe0f593a7a5817`.

## 5. Conflict durumu

Conflict oluşmadı; `ort` stratejisiyle `--no-ff` merge başarılı oldu.

## 6. Analyzer sonucu

Uygulama kökünde `dart analyze`: `No issues found`.

## 7. Widgetbook analyzer sonucu

Widgetbook `flutter pub get` ve `dart analyze`: başarılı, `No issues found`.

## 8. Question gate sonucu

Question-quality testleri `51/51`. Gate exit `0`; sources `44`, gate physical/canonical `13571/13571`, unknown source `0`. Baseline Git blob'u değiştirilmedi.

## 9. Test sayısı

`flutter test --exclude-tags preview`: `612/612`, tüm testler geçti.

## 10. Web build sonucu

`flutter build web`: ilk denemede başarılı.

## 11. WASM build sonucu

`flutter build web --wasm`: ilk denemede başarılı; clean/retry gerekmedi. `main.dart.wasm`: 4.493.068 bayt.

## 12. Debug APK sonucu

`flutter build apk --debug`: başarılı. Artifact: `build/app/outputs/flutter-apk/app-debug.apk` (167.190.728 bayt). Release AAB üretilmedi.

## 13. Runtime smoke-test sonucu

Merged main'in yerel WASM çıktısı Playwright ile kontrol edildi: ana sayfa açık/koyu, oyun merkezi, quiz normal/doğru/yanlış/timeout, sonuç açık/koyu ve `844×390`, liderlik ve ayarlar açık/koyu. Overflow veya Flutter hata şeridi görülmedi; timeout metni görünür, sonuçta iki baskın CTA mevcut, Kurmancî karakterler sağlam, konsol `0` hata / `0` uyarı.

## 14. git status --short

Rapor commit'i öncesinde çalışma ağacı temizdi; final kapanışta yeniden doğrulanır.

## 15. Korunan branch ve worktree'ler

- `codex/final-release-candidate-polish-2026-07-15` korunuyor.
- `C:\src\zankurd_audit_2026-07-15` worktree'si korunuyor.
- `local/pre-final-merge-backup-2026-07-15` korunuyor.

## 16. Push/deploy durumu

GitHub, push, Pull Request, deploy, Supabase yazımı veya production veri değişikliği yapılmadı.

## 17. Yerel main durumu

Yerel `main`, final release-candidate çalışmasını ve checkout discovery düzeltmesini içeriyor; zorunlu analiz, gate, test, build ve runtime kontrolleri başarılı.
