# Oda seçenekleri — yayın önkoşulu

İstemci aday seçenekleri: 5, 10, 15, 20, 25, 30, 40, 50 soru;
10, 15, 20, 30, 45, 60, 90, 120 saniye. Varsayılanlar değişmez.
Bu istemci, aşağıdaki sunucu kapısı tamamlanmadan yayınlanmamalı.

## 31 Ekim 2026 doğrulaması

Supabase kataloğu yalnızca SELECT ile okundu. Canlıya göç uygulanmadı.
Aday `supabase/2026-10-31_room_limits.sql`, korumalı geri alma dosyası
`supabase/geri_al/2026-10-31_room_limits_geri.sql`.

| Denetim | Sonuç |
|---|---|
| `create_online_room_impl` canlı gövdesi | MD5 `6809d77c75f5688860c57d239a46ca18` |
| Aday gövde | MD5 `405366e5801f29be9663fac468eb3353`. Diff yalnız iki izin listesine 20/25/30/40/50 soru ve 90/120 saniye ekliyor. |
| İlgili tablo kısıtları | `rooms_question_count_check` 3–30 → 3–50; `rooms_seconds_per_question_check` 5–60 → 5–120. |
| Yerel ileri/geri prova | Aynı katalog ve PostgreSQL motoruyla ileri uygulama ve geri alma başarılı. Ek CHECK veya değişmiş gövde işlemi durdurdu. Yeni sınırları kullanan oda varken geri alma veriye dokunmadan reddedildi. |

Yerel PostgreSQL provasında (PGlite) canlıdan okunan oda fonksiyonları, ilgili sütunlar ve
CHECK tanımları, 2 sentetik oyuncu ve en çok 50 sentetik soru kullanıldı. Gerçek kullanıcı
ve soru satırları alınmadı. 5 soru/10 saniye ve 50 soru/120 saniye kabul edildi. 51 soru
veya 121 saniye reddedildi. İkinci oyuncu RPC ile katıldığında aynı sınırları gördü.
49 onaylı soruda başlatma atomik olarak reddedildi ve odada soru satırı kalmadı.

50 soruda oyun başladı. İki istemci kimliği hazır olduğunda sunucu ilk soru için 120 saniye
verdi. Yerel saat koşulları sentetik zaman damgalarıyla sınandı. İlk soruda 90 saniyede erken
ilerleme reddedildi, 121 saniyede iki oyuncu için 120.000 ms'lik zaman aşımı yazıldı.
Etkinliğini sürdüren 95 dakikalık oda temizlik fonksiyonundan sonra açık kaldı.
Kalan 49 soruda iki tarafın cevapları ve soru geçişleri işlendi. İki hesap da sonuç RPC’sinde
50 soru, 50 kendi cevabı ve bitmiş oda durumunu aldı. Bunlar aynı yerel veritabanında iki
oyuncu kimliğiyle RPC testleridir. Gerçek ağ üzerinde iki cihazlı staging denemesi açık.

## Canlı kaynağı al (salt okunur)

Yetkili veritabanı bağlantısında aşağıdaki sorgunun tek JSON sonucunu
geçici `room_limits_live.json` dosyasına kaydet. Kimlik bilgisi ekleme.

```sql
select jsonb_build_object(
  'function_definition', pg_get_functiondef(
    'public.create_online_room_impl(text[],integer,integer,integer,integer,boolean)'::regprocedure),
  'constraints', (
    select jsonb_agg(jsonb_build_object('name', c.conname,
      'definition', pg_get_constraintdef(c.oid)) order by c.conname)
    from pg_constraint c
    where c.conrelid = 'public.rooms'::regclass and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ~ '(question_count|seconds_per_question)'
  )
);
```

```sh
python3 tool/prepare_room_limits.py /tmp/room_limits_live.json > /tmp/room_limits_review.sql
python3 tool/prepare_room_limits.py --rollback /tmp/room_limits_live.json > /tmp/room_limits_geri.sql
```

Araç yalnız beklenen iki sayısal korumayı ve iki CHECK üst sınırını değiştirir.
Bilinmeyen gövde/ek kısıt varsa durur; tahminle eski göç kopyalamaz.
Uygulama sırasında canlı gövdenin hash'i ve kısıtların metni yeniden doğrulanır.

## İnceleme ve uygulama

1. Üretilen işlevi canlı gövdeyle diff et: yalnız izinli sayı listeleri değişmeli.
   Ödül havuzu, kalabalık oda, kimlik/yetki, soru seçimi ve canlılık gövdesi aynen kalmalı.
2. Önce staging/yerel veritabanında: 50 soru/120 saniye, eski 5/10 seçenekleri,
   geçersiz 51/121 ve yetersiz soru havuzu. Katılma/başlatma/sonraki soru/sonuç
   yollarını iki istemciyle doğrula; sunucu tur sonlandırması da 120 saniyeyi korumalı.
3. Canlı uygulamadan önce sahibi onaylamalı. İşlem içinde duman testi yap;
   ilk denemede son `COMMIT` yerine `ROLLBACK` kullan. Test kullanıcıları dışına
   bildirim veya oda daveti gönderme.
4. Onaylı uygulama ve son doğrulamadan sonra yalnız o zaman `supabase/applied.md`
   kaydını gerçek tarih ve kanıtla güncelle. 31 Ekim 2026 tarihinde yalnız katalog okundu, göç uygulanmadı.

Yerel generator davranışı `python3 -m unittest discover -s tool -p test_prepare_room_limits.py`
ile sınanır; bu test PostgreSQL veya iki cihaz duman testinin yerine geçmez.
