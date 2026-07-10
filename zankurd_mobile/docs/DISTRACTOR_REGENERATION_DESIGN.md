# Kategori-Havuzlu Çeldirici Yeniden Üretimi

**Tarih:** 2026-07-10 · **Durum:** tasarım + saf Dart altyapısı hazır

## Sorun

Şablon üretimde bazı çoktan seçmeli sorularda çeldiriciler kategori dışı karışıyor
(ör. Ziman sorusunda "Yumurta", "Kırmızı"). Bu, hem zorluğu hem de güveni düşürür.

## Kural

1. **Doğru cevaba dokunulmaz.**
2. Çeldiriciler **aynı kategorideki** diğer soruların doğru cevap metinlerinden seçilir.
3. Case-varyant ve birebir kopya elenir (`lower(trim)`).
4. Havuz yetersizse eski çeldirici doldurma olarak kalır (eksik şık bırakılmaz).
5. True/false sorulara dokunulmaz.

## Algoritma

`lib/src/utils/category_distractor_pool.dart` → `CategoryDistractorPool`

1. Tüm bankadan kategori → doğru-cevap havuzu.
2. Her soru için: doğru cevabı koru, `targetCount-1` çeldirici seç.
3. Tercih: doğru cevaba yakın uzunluk (hafif benzerlik).
4. Deterministik seed (`id.hashCode ^ seed`) → yeniden üretilebilir.

## Uygulama yolları

| Katman | Nasıl |
|---|---|
| Offline bank | Tool dry-run → diff → elle/otomatik patch |
| Canlı DB | SQL UPDATE batch (doğru cevap kolonuna dokunma) |
| Kalite metriği | `categoryCohesionScore` (0–1); hedef ≥ 0.8 |

## Çalıştırma (plan)

```text
# (ileride) dart run tool/regenerate_distractors.dart --dry-run
# cohesion < 0.5 olanları listele / SQL üret
```

v1: birim testler algoritmayı kilitler; toplu banka yazımı ayrı onaylı adımdır
(büyük diff — 1000+ soru).

## Doğrulama

- `flutter test test/category_distractor_pool_test.dart`
- Mevcut `question_bank_test.dart` (unique answers, correct in list) yeşil kalmalı
