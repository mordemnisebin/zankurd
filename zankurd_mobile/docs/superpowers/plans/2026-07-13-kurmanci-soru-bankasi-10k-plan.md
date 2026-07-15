# Kurmancî Soru Bankası 10K Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wêje ve Erdnîgarî dahil sekiz kategoride, tekrar ve Türkçe kalıntısı azaltılmış, denetlenebilir 10.000+ Kurmancî soruluk üretim akışını hazırlamak.

**Architecture:** Mevcut SQL üreticisi korunacak; kategori anahtarları veritabanı uyumluluğu için aynı kalırken soru metinlerinde Kurmancî kategori adları kullanılacak. Üretim öncesi kalite kapıları Türkçe kalıntısı, cevap sızıntısı ve prompt tekrarını reddedecek; ilk dalga denetlendikten sonra tam üretim alınacak.

**Tech Stack:** Python üretim araçları, Supabase SQL çıktısı, Dart/Flutter testleri.

## Global Constraints

- Görünen kategori adları `Wêje` ve `Erdnîgarî` olmalı; DB anahtarları `Edebiyat` ve `Cografya` korunmalı.
- Kurmancî metinlerde `ç, ê, î, û, ş` korunmalı; Türkçe karakter ve stopword kalıntıları reddedilmeli.
- Kaynak çeşitliliği tek bir kaynak ailesine bağlanmamalı.
- Dosya değişiklikleri küçük ve test edilebilir olmalı; canlı Supabase yazımı ayrı doğrulama olmadan yapılmamalı.

### Task 1: Üretim kalite kapılarını ve kategori sözlüğünü düzelt

**Files:**
- Modify: `tools/generate_pure_kurdish_questions.py`
- Test: `test/curated_question_bank_test.dart`

- [x] Wêje/Erdnîgarî görünen adlarını kategori sözlüğüyle üretim metinlerine uygula.
- [x] Üretilen promptların normalize edilmiş tekrarını ve doğru cevabın promptta açıkça bulunmasını reddet.
- [x] Üreticiyi 8 kategori ve toplam 10.000 soru hedefi için çalıştır.

### Task 2: İlk dalgayı üret ve bağımsız kalite denetimi yap

**Files:**
- Create: `supabase/2026-07-13_pure_kurmanci_question_wave_1.sql`
- Modify: `reports/question_audit_report.md`

- [x] Üretici çıktısını UTF-8 olarak kaydet.
- [x] Kategori ve kalite sayımlarını raporla.
- [x] Türkçe kalıntı ve prompt tekrarını denetle; canlıya alma.

### Task 3: Dart doğrulaması ve web smoke

**Files:**
- Modify: `test/curated_question_bank_test.dart` only if a focused contract is missing.

- [x] ASCII temp yolu ile hedefli `dart analyze` çalıştır.
- [x] İlgili Dart testlerini çalıştır.
- [ ] Flutter web ekranını Playwright ile açıp kategori adlarını ve başlangıç akışını kontrol et.
