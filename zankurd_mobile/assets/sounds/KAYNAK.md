# Efekt seslerinin kaynağı

| Dosya | Olay | Kaynak |
|---|---|---|
| correct.mp3 | doğru cevap, mağaza satın alma | proje başından beri depoda (2026 öncesi) |
| wrong.mp3 | yanlış cevap | proje başından beri depoda |
| coin.mp3 | jeton kazanımı | proje başından beri depoda |
| win.mp3 | tur/maç kazanma, çark ödülü, günlük hedef | `tool/sounds/sentez.py` ile üretildi (2026-10-29) |
| wildcard.mp3 | joker kullanımı | `tool/sounds/sentez.py` ile üretildi (2026-10-29) |
| tick.mp3 | geri sayımın son 5/3/1. saniyesi (≤150 ms) | `tool/sounds/sentez.py` ile üretildi (2026-10-29) |

Üretilen sesler yalnız Python standart kitaplığıyla sentezlenir (sinüs
tonları + kısa gürültü vuruşu); dışarıdan ses örneği kullanılmaz, lisans
yükümlülüğü yoktur. Yeniden üretmek için betiğin başındaki komutlara bak.

Kapışma U17 (2026-10-29): `win.mp3` `correct.mp3`'ün, `wildcard.mp3`
`coin.mp3`'ün bayt bayt kopyasıydı ve tık 2 saniyelik jeton sesini
çalıyordu. `test/ses_baglami_ve_dosyalari_test.dart` her efektin ayrı içerik
taşıdığını ve bu tabloda anıldığını denetler.
