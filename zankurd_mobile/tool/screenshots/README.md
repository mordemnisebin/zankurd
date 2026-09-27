Bu dosyalar test değil, `docs/screenshots/` altına PNG üreten scriptlerdir.
`flutter test` her koşuda çalışma ağacını kirletmesin diye `test/`ten buraya
taşındılar (2026-07-21 denetimi).

Çalıştırmak için:

```bash
flutter test tool/screenshots/screen_tour_test.dart
```

Geçici QA çıktısını dokümantasyon klasörüne dokunmadan başka bir hedefe almak
için aynı turu ortam değişkeniyle çalıştır:

```bash
ZANKURD_SCREEN_TOUR_OUT_DIR=.tmp/screen_tour_current \
  flutter test tool/screenshots/screen_tour_test.dart
```

Tek komutluk tasarım kalite kapısı için:

```bash
./tool/design_qa.sh
```

Ekran turunu da eklemek için:

```bash
./tool/design_qa.sh --visual
```

Boot edilmiş bir iOS Simulator üzerinde gerçek uygulama Patrol smoke'u ve
native liderlik/çark görsel kanıtını da eklemek için:

```bash
./tool/design_qa.sh --visual --native
```

Görsel tur çıktısı varsayılan olarak `.tmp/design_qa/tour`, native kanıtlar
`.tmp/design_qa/native` altına yazılır.

Tek bir yüzeyi yenilemek için aynı klasördeki ilgili `*_test.dart` üreticisini
çalıştırabilirsin.
