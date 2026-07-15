# Dalga 2 AI Görüşü Sonrası Küratörlü Adaylar

- Kaynak AI görüşü: `supabase/wave2_reviewed.csv`
- Başlangıç satırı: 10.000
- Küratörlü yayın adayı: 49
- Karantina: 9.951
- Yayın adayında aynı kavram/açıklama tekrarı: 0
- Yayın adayı durumu: `CURATED_CANDIDATE`
- SQL onayı: `is_approved=false`

## Seçim kuralı

Her benzersiz düzeltilmiş açıklama için yalnızca bir `PASS` satırı tutuldu. Kaynak güveni ve AI güven puanı daha yüksek olan satır tercih edildi. `FIX`, `UNCERTAIN` ve aynı kavramın diğer varyasyonları karantinaya alındı.

Siyaset ve Paradigma satırları, AI incelemesinde yeterli kaynak güveni bulunmadığı için yayın adayına alınmadı.
