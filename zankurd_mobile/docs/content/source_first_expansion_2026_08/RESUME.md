# Kesin devam noktası (2026-08-06)

Havuz: **53 / 100** — Sînema 27, Cografya 18, Teknolojî 8.
Runtime dokunulmadı: 2050. Aktivasyon yok (eşik dolmadı).

## Çalışan yöntem

1. Kurumsal sayfayı **doğrudan aç**, olguları birebir çıkar.
2. Gereken Kurmancî terimi **ku.wiktionary (Wîkîferheng)** üzerinden aç.
3. Soruyu yaz, kapılardan geçir, `build_verified_pool.py` ile havuza ekle.

Wîkîferheng bu oturumda sekiz terim açtı: `okyanûs`, `dane`, `nermalav`,
`înternet`, `hilm`, `gerstêrk`, `oksîjen`, `nîtrojen`.

## Sıradaki somut adımlar

**Terim açılacaklar** (her biri bekleyen olguyu serbest bırakır):
`sepan` (application), `şîfre` (password/encryption ayrımıyla),
`pêşkêşker` veya `rajekar` (server), `gerok` (browser), `hewa` (weather).

**Hazır bekleyen kaynaklar:** MDN "How the web works" — server/client/browser
olguları terim açılınca doğrudan soruya döner.

**Terim gerektirmeyen en hızlı yol:** BFI film künyeleri. Arama ile
`bfi.org.uk/film/<uuid>/<slug>` bul, künyeyi aç, film başına **iki** soru
(yönetmen + yıl). Özel adlar lexeme onayı istemez.

## Her batch sonrası zorunlu

`python3 tool/content_authoring/build_verified_pool.py` (iki kez, byte-identical
olmalı) · `dart analyze` · `git diff --check` · question-quality gate ·
`flutter test test/terminology_enforcement_test.dart test/glossary_contract_test.dart
test/distractor_integrity_test.dart test/question_quality/manifest_and_normalization_test.dart`

Cevap konumu: her pozisyon kullanılmalı, hiçbiri %40'ı geçmemeli.
Uzunluk: strict uniquely-longest %33'ü geçmemeli (naive max-tie ile karıştırma).

## Kapanmış konular — yeniden açma

* Ziman: `DEFERRED_LOW_MARGINAL_YIELD` (320 soru, 376 lexical item doygun,
  wordOrdering tek doğru string tuttuğu için güvenli değil)
* Teknolojî terminolojisi: 9 kavram için insan editörü paketi hazır,
  `reviewerDecision` alanları boş
* NOAA hava/iklim: `REJECTED_LANGUAGE_CONCEPT_MISMATCH` — Kurmancî bu ayrımı
  yapmıyor, terim bulunsa da soru yazılmayacak
* Dış havuz (Grok/DeepSeek): kararlar donduruldu, kurtarma yapılmayacak

## Kürt sineması

Hâlâ **0**. Risk-A çıtası doğrudan akademik/arşiv kaynağı istiyor; hiçbiri
açılamadı. Plan: `docs/content/plans/yilmaz_guney_kurdish_cinema_content_plan.md`
Kaynaksız yazılmayacak.
