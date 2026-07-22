# ZanKurd bulgu indeksi — 22 Temmuz 2026

Bu indeks yalnız güncel yerel doğrulamayı gösterir. Gizli anahtar veya parola
içermez.

| Öncelik | Bulgu | Durum | Kanıt |
|---|---|---|---|
| P0 | Proje derlenmiyor / analyzer kapsamı yanıltıcı | Kapandı | `dart analyze`: 0 bulgu; web ve debug APK üretildi |
| P0 | Online odada doğru cevabın istemciye erken gelmesi | Canlıda kapandı | Cevapsız oda RPC'si, cevap sonrası reveal ve tablo erişim daraltması canlıda doğrulandı |
| P0 | Oda puanı ve hazır durumu istemciden manipüle edilebilir | Canlıda kapandı | Atomik `submit_answer`, `set_room_ready` ve oda-soru doğrulaması canlıda doğrulandı |
| P1 | iOS galeri izin açıklaması eksik | Kapandı | `NSPhotoLibraryUsageDescription` ve release yapılandırma testi |
| P1 | 1.35 metin ölçeği sınırı | Kapandı | Üst sınır 2.0; erişilebilirlik testleri geçti |
| P1 | Gizli sekmeler başlangıçta yükleniyor | Kapandı | Sekmeler ilk ziyaret edilene kadar oluşturulmuyor |
| P1 | Dar web kabında yanlış masaüstü menüsü | Kapandı | AppShell gerçek `LayoutBuilder` genişliğini kullanıyor |
| P1 | Runtime soru tekrarı ve dengesiz doğru şık | Kapandı | 2.347 benzersiz soru; dağılım 396/396/395/395 |
| P1 | Riskli 10 binlik import bankası yanlışlıkla kullanılabilir | Kapandı | Kaynak `quarantine`; runtime/gate/import akışından çıkarıldı |
| P2 | Kurmancî ekranda Türkçe turnuva/çevrimiçi terimleri | Kapandı | `Kûpa`, `Serhêl`, `Ne li serhêl` sözleşmesi testli |
| P2 | Kullanılmayan JSON runtime asset'i | Kapandı | Bundle kaydı kaldırıldı; web artefaktında eşleşme 0 |
| P2 | Derlenmeyen stale Widgetbook ve ters yönlü exporter | Kapandı | Alt paket ve `export_questions_json.dart` kaldırıldı |
| P2 | Kalite gate'i her seferinde tam raporu hesaplıyor | Kapandı | Gate yalnız iki aktif runtime kaynağını tarıyor |
| P3 | Eski ilerleme ve release iddiaları | Kapandı | Kanıta dayalı doğrulama komutları ve bu raporlar yazıldı |

## Dış uygulama gerektirenler

- İki gerçek cihaz/hesapla uçtan uca multiplayer smoke testi yapılmalıdır.
- Android release imzası ve mağaza yüklemesi yapılmadı; yalnız debug APK üretildi.
- iOS build Windows'ta çalıştırılmadı; izin/plist sözleşmesi yerel testle doğrulandı.
- Karantinadaki import/publish adayları uzman editoryal onay olmadan yayımlanmamalı.
