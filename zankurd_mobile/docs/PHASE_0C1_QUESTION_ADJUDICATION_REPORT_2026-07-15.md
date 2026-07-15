# Faz 0C.1 — Soru Adjudication Kapanış Raporu — 2026-07-15

## Branch ve HEAD

- Başlangıç: `codex/phase0b-question-quality-gate-2026-07-15` / `b8919fef7ffef871871721d4396eb45f90cc2c11`
- Yeni branch: `codex/phase0c1-question-adjudication-2026-07-15`
- Araç/test commitleri: `1c2131e`, `63ae9fb`

## Değişen dosyalar

Yalnız `tool/question_quality/adjudication/**`, `test/question_quality/adjudication_core_test.dart`, adjudication audit çıktıları, bu iki rapor ve yeni komut nedeniyle küçük README bölümü değişti.

## Doğrulama sonuçları

- Invalid correct-answer: 31/31 incelendi; gerçek invalid `0`, parser FP 15, copy artifact 16.
- Answer leak: 62/62 incelendi; confirmed 13, factual review 13, parser FP 3, copy artifact 33.
- Duplicate option: 200 deterministik örnek; 197 gerçek (%98,5), 3 punctuation FP.
- Cross-source correct-answer farkı: 0.
- Orijinal kaynağı bulunamayan: 0/293.
- `safeForAutomaticFix=true`: 0.
- Strict recommended fix wave: 0.

## Test sayısı

- Yeni adjudication çekirdek testleri: 16/16 geçti.
- `flutter test test/question_quality`: 46/46 geçti.
- `flutter test --exclude-tags preview`: 597/597 geçti.

## Analyzer sonucu

- Dar format: 11 dosya, 0 değişiklik.
- Kök `dart analyze`: No issues found.
- Widgetbook `dart analyze`: No issues found.

## Gate sonucu

Faz 0B gate'i exit 1 verdi: `unknown=2` ve `Unclassified question source detected.` Unknown yollar başlangıç commit'i `b8919fe` ile eklenen:

- `docs/PHASE_0B_QUESTION_QUALITY_GATE_REPORT_2026-07-15.md`
- `docs/ZANKURD_QUESTION_QUALITY_GATE_REPORT_2026-07-15.md`

Bu pre-existing discovery regresyonu Faz 0C.1 dosyalarından kaynaklanmaz. Source manifest, discovery ve baseline bu fazda yasak olduğundan düzeltilmedi. Gate'in yeniden yazdığı Faz 0B çıktı dosyaları HEAD'e geri alındı.

## Determinizm sonucu

Adjudication iki kez üretildi; 11 sabit dosyada değişen SHA-256 sayısı 0'dır.

## Production soru dosyaları

Production soru/veri diff'i sıfırdır. Baseline, manifest, CI, Supabase, runtime, platform ve asset dosyaları değişmedi.

## Ana checkout kanıtı

Ana checkout'ta yalnız önceden var olan ` M macos/Flutter/GeneratedPluginRegistrant.swift` korunmuştur.

## Commit listesi

- `1c2131e feat: add read-only question adjudication tooling`
- `63ae9fb test: cover question adjudication workflow`
- Bu raporlar/çıktılar `docs: add question adjudication results` commit'iyle kapanacaktır.

## Git status kabul kriteri

Doküman commit'i sonrasında audit worktree status'u boş olmalıdır. Ana checkout yalnız izin verilen Swift değişikliğini göstermelidir.

## Önerilen Faz 0C.2 kapsamı

İlk adım production veri düzeltmesi değil, ayrı ve onaylı bir auditor-fix paketidir:

1. Yönetici Markdown raporlarını discovery inputundan çıkar.
2. Geçerli correct index ile duplicate seçenek kontrolünü ayır.
3. Anlamlı terminal punctuation seçeneklerini koru.
4. Answer-leak doğal bağlam istisnalarını testle daralt.

Bundan sonra 10 runtime visual leak ve 58 active-import duplicate distractor için insan editörlü veri düzeltme dalgası ayrıca onaylanmalıdır.

## Yayın işlemleri

Push, merge, deploy, Supabase yazma, migration, seed, baseline güncelleme veya production veri düzeltmesi yapılmadı.
