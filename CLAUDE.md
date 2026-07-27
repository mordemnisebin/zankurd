# ZanKurd — AI başlangıç noktası

- Çalışma kuralları için önce kökteki `AGENTS.md` dosyasını oku.
- Ana ürün `zankurd_mobile/` içindeki Flutter uygulamasıdır.
- Kurulum ve komutlar için `zankurd_mobile/README.md`; mimari için
  `zankurd_mobile/ARCHITECTURE.md` kullanılır.
- Uygulanan veritabanı göçleri ve doğrulama durumu
  `zankurd_mobile/supabase/applied.md` dosyasındadır.
- Eski handoff, tamamlanmış plan, ekran görüntüsü ve üretilmiş audit ayrıntıları
  bilerek silinmiştir. Bunları güncel kaynak gibi yeniden oluşturma.
- Kaynak kod, testler ve migration dosyaları gerçek kaynaktır; raporla
  çelişirse kodu ve güncel doğrulamayı esas al.

## Bulguların yaşadığı yer

Bu dosya bir zamanlar üç `GEMINI_*.md` raporuna işaret ediyordu; o dosyalar
silindi ve işaret öksüz kaldı (2026-07-27'de düzeltildi). Bulgular artık
üretilmiş raporlarda değil, üç canlı yerde durur:

1. **Testler.** Her düzeltmenin yanında onu koruyan bir bekçi vardır ve
   bekçinin belgesinde kusurun ne olduğu, niçin sessiz kaldığı yazılıdır.
   `test/` altındaki dosya başlıkları okunmak için yazılmıştır.
2. **Commit gövdeleri.** Her commit *neyin* değiştiğini değil *niçin*
   değiştiğini anlatır; `git log` bu projenin denetim günlüğüdür.
3. **Kod yorumları.** Bir kararın niçin öyle olduğu (ör. şık harflerinin
   niçin renksiz kaldığı) sabitin başında yazılıdır.

Yeni bir rapor dosyası üretme; bulguyu düzelt, bekçisini yaz, commit
gövdesine niçinini koy.

## Ekranı gözle görmek

`flutter test tool/screenshots/screen_tour_test.dart` bütün ana ekranları
`docs/screenshots/tour/` altına basar — açık/karanlık tema, Türkçe/Kurmancî
ve boş durumlar dahil. Emoji ve `CustomPainter` metni test koşucusunda kutu
çıkar; o ikisi simülatörden doğrulanır.
