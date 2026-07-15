# Üretilen Tüm Sorular — Birleşik Paket Raporu

## Kapsam

Bu paket, bu çalışma sürecinde hazırlanmış 18 soru dalgasını tek dosyada birleştirir. Eski 10.000 satırlık `editorial_kurmanci_question_wave_2_for_ai_review.csv` inceleme havuzu pakete dahil edilmemiştir; bu rapor yalnızca bu süreçte üretilen ve editoryal statüsü belirlenmiş dalgaları kapsar.

Toplam soru: **285**

Kaynak URL’si: **85**

Kategori dağılımı:

- Dîrok: 45
- Çand: 43
- Paradigma: 41
- Ziman: 38
- Siyaset: 35
- Cografya: 34
- Edebiyat: 28
- Muzîk: 21

## Birleştirme ve doğrulama

- 285/285 ID benzersiz.
- 285/285 soru metni benzersiz.
- 285/285 SQL satırı CSV ile eşleşiyor.
- Kurmancî içerikte bozuk karakter bulunmadı.
- Tüm kayıtlar `ku-kmr` dil kodunda.
- Tüm kayıtlar `PENDING_EDITORIAL_APPROVAL` durumunda.
- SQL kayıtlarında `is_approved=false` kullanıldı.

## Yayın durumu

Master SQL canlı veritabanına uygulanmadı. Önce insan/AI son editoryal denetimi yapılmalı; ardından bu tek SQL paketi içe aktarılabilir.
