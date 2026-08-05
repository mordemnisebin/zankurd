# Ekran görüntüsü üreticileri

Bu dosyalar test değil, `docs/screenshots/` altına PNG üreten scriptlerdir.
`flutter test` her koşuda çalışma ağacını kirletmesin diye `test/`ten buraya
taşındılar (2026-07-21 denetimi).

Çalıştırmak için:

```bash
flutter test tool/screenshots/screen_tour_test.dart
```

Tek bir yüzeyi yenilemek için aynı klasördeki ilgili `*_test.dart` üreticisini
çalıştırabilirsin.
